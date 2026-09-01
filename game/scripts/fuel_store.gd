extends Node

signal fuel_changed(new_amount: int)
# Ordered, not yet landed. The panel wants to show what is on its way.
signal delivery_changed
signal price_changed(new_price: int)
# Carries the UNIT PRICE PAID as well as the size, so a quest can ask you to buy
# cheaply or to buy in bulk - the two things the market and the batch
# multipliers are for, and neither is visible from the fuel total alone.
signal fuel_bought(units: int, unit_price: float)

# Placeholder economy - not real game data. Price swings up to 50% above or
# below the base each time the market moves.
const BASE_PRICE := 10
const PRICE_SWING := 0.5

# The market moves ONCE AN HOUR, on the hour, and the price is a FUNCTION OF
# WHICH HOUR IT IS rather than something that ticks while the game is open.
# Two consequences, both the point:
#
#   * A price you don't like is one you wait out or eat. At the old ten-second
#     re-roll there was no decision in it - the correct play was always to
#     stand in the fuel shop for a few seconds until a cheap roll came up, so
#     the market was noise wearing the costume of a market.
#   * Quitting cannot reshuffle it. Accumulating a timer in _process meant the
#     price re-rolled on every launch, which is the same exploit with an extra
#     step. Derived from wall-clock time, the hour you are in gives the price
#     it gives no matter how many times you relaunch.
const PRICE_PERIOD := 3600.0
# Fixed, so the sequence is reproducible: the same hour always yields the same
# price. There is nothing here worth randomising per install, and a stable
# sequence makes a reported price something we can actually reproduce.
const PRICE_SEED := 24593
const PRICE_HISTORY_LENGTH := 20

# Enough for two full round trips in the starting 328 Jet, which burns its
# own 15 a leg (see ShopCatalog) and pays to depart and to refuel at home.
# It used to be 20, from back when every aircraft burned a flat 5 - that is
# now less than one round trip, so a fresh game stranded its own starter
# aircraft at home with no way to earn the money to fuel it.
# WHAT A BATCH COSTS PER UNIT, relative to the market price. Buying small is a
# premium and buying big is a discount, so the size of the purchase is a
# decision rather than a question of how many times you are willing to press the
# button.
#
# It also gives the hourly market something to bite on. A flat per-unit price
# made stockpiling free - there was never a reason to hold more than the next
# leg needed, so a bad price slot could always be waited out at no cost. Now a
# cheap slot is worth backing up the truck for, and topping up 50 at a time is
# the expensive habit it looks like.
#
# The early game feels this as a squeeze: 50 units is all a new player can
# afford and it is the dearest fuel in the game. That is deliberate - it is the
# first thing the economy asks you to grow out of - but see the note on the
# minimum purchase in the readme, because it stacks with an existing trap.
const BATCH_MULTIPLIER := {
	50: 1.20,
	500: 1.10,
	5000: 1.00,
	50000: 0.90,
}

# FUEL ARRIVES, IT DOES NOT APPEAR.
#
# Price and burn were tried first and neither makes anybody run dry: at 41% of
# income the bot was stopped four times in sixty days, and capping the tank at
# 3,000 units stopped it once. Fuel bought on demand out of money that is never
# short can be made expensive but not scarce - so the thing to take away is not
# the money, it is the INSTANT.
#
# The wait scales with the batch, which keeps the discount honest: topping up
# 50 units is a minute, backing up the truck for 50,000 is an hour. Buying big
# is still cheaper per unit and now costs foresight instead of nothing, and the
# hourly market finally has something to bite on - a cheap slot you cannot use
# for an hour is a different decision from a cheap slot you can.
const DELIVERY_SECONDS := {
	50: 60.0,
	500: 300.0,
	5000: 1200.0,
	50000: 3600.0,
}

const STARTING_AMOUNT := 60

var amount: int = STARTING_AMOUNT:
	set(value):
		amount = value
		fuel_changed.emit(amount)

var current_price: int = BASE_PRICE:
	set(value):
		if value == current_price:
			return
		current_price = value
		price_changed.emit(current_price)

# The last PRICE_HISTORY_LENGTH hours, oldest first, ending with the one we are
# in. DERIVED, not accumulated: the graph used to start empty on every launch
# and grow a point at a time while you watched it, which is a picture of how
# long the app has been open rather than of the market.
var price_history: Array[int]:
	get:
		var slot := _slot_now()
		var out: Array[int] = []
		for i in range(PRICE_HISTORY_LENGTH - 1, -1, -1):
			out.append(price_for_slot(slot - i))
		return out

# Which hour we last told anybody about, so _process only does work when the
# market actually moves.
var _slot := -1
var _check_timer := 0.0


func _ready() -> void:
	_apply_slot()


# Checked once a second rather than every frame - the thing being watched
# changes once an hour.
var pending: Array = []


func _process(delta: float) -> void:
	land_deliveries()
	_check_timer += delta
	if _check_timer < 1.0:
		return
	_check_timer = 0.0
	if _slot_now() != _slot:
		_apply_slot()


func _apply_slot() -> void:
	_slot = _slot_now()
	current_price = price_for_slot(_slot)


func _slot_now() -> int:
	return int(floor(GameClock.now() / PRICE_PERIOD))


# The price during a given hour. Seeded through a string so neighbouring hours
# land nowhere near each other - feeding sequential ints straight to an RNG
# gives a market that drifts smoothly, which is not what a market does.
func price_for_slot(slot: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d" % [PRICE_SEED, slot])
	return roundi(rng.randf_range(BASE_PRICE * (1.0 - PRICE_SWING),
		BASE_PRICE * (1.0 + PRICE_SWING)))


# How long the current price has left. The shop shows this, because "wait it
# out" is only a real choice if you can see what you would be waiting for.
func seconds_until_next_price() -> float:
	var elapsed := GameClock.now() - float(_slot_now()) * PRICE_PERIOD
	return maxf(0.0, PRICE_PERIOD - elapsed)


func consume(units: int) -> bool:
	if units > amount:
		return false
	amount -= units
	return true


# What this batch actually costs, multiplier included. ONE PLACE, because the
# shop displays a price and the purchase charges one, and those two drifting
# apart is the kind of bug nobody reports - they just quietly feel cheated.
func cost_of(units: int) -> int:
	return roundi(units * current_price * multiplier_for(units))


# Batches that are not one of the four offered sizes pay the flat rate. Nothing
# in the shop can ask for one; this only keeps the function total.
func multiplier_for(units: int) -> float:
	return float(BATCH_MULTIPLIER.get(units, 1.0))


func delivery_seconds(units: int) -> float:
	return float(DELIVERY_SECONDS.get(units, 60.0))


# Paid for now, in the tank later. fuel_bought still fires on the ORDER, because
# that is when the player spent the money and it is what the daily tasks count.
func buy(units: int) -> bool:
	var cost := cost_of(units)
	if not Economy.spend_money(cost):
		return false
	pending.append({"units": units, "at": GameClock.now() + delivery_seconds(units)})
	delivery_changed.emit()
	fuel_bought.emit(units, float(cost) / maxf(1.0, float(units)))
	return true


# Everything whose time has come, in one pass. Driven off GameClock, so an order
# placed before closing the game is waiting in the tank on the next launch
# rather than starting its clock again.
func land_deliveries() -> void:
	if pending.is_empty():
		return
	var now := GameClock.now()
	var still: Array = []
	var landed := 0
	for order in pending:
		if float(order.get("at", 0.0)) <= now:
			landed += int(order.get("units", 0))
		else:
			still.append(order)
	pending = still
	if landed > 0:
		amount += landed
	delivery_changed.emit()


# Units on the way, and how long until the next lot lands.
func pending_units() -> int:
	var n := 0
	for order in pending:
		n += int(order.get("units", 0))
	return n


func seconds_until_delivery() -> float:
	var best := -1.0
	for order in pending:
		var left: float = float(order.get("at", 0.0)) - GameClock.now()
		if left > 0.0 and (best < 0.0 or left < best):
			best = left
	return maxf(best, 0.0)


func to_save() -> Array:
	return pending.duplicate(true)


func load_save(data: Array) -> void:
	pending = data.duplicate(true)
	land_deliveries()


# NOTE: buy_with_coins() lived here until the fuel shop's fourth tier stopped
# being a coin purchase (see FuelPanel). Nothing else ever called it, so it went
# with the button rather than sitting here as an entry point to a payment method
# the shop no longer offers.
