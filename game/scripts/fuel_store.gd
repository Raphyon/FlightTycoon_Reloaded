extends Node

signal fuel_changed(new_amount: int)
signal price_changed(new_price: int)

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
func _process(delta: float) -> void:
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


func buy(units: int) -> bool:
	if not Economy.spend_money(units * current_price):
		return false
	amount += units
	return true


# NOTE: buy_with_coins() lived here until the fuel shop's fourth tier stopped
# being a coin purchase (see FuelPanel). Nothing else ever called it, so it went
# with the button rather than sitting here as an entry point to a payment method
# the shop no longer offers.
