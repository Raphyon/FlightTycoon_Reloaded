extends Node

# THE FUEL DEPOT: fuel arrives on its own, and the upgrades are what you buy.
#
# The store this sits beside (FuelStore) sells fuel by the batch, and BALANCE
# measures the result as inert - 0.3% to 0.8% of income, one blocked pass in
# four full runs. FuelStore's own note reached the same conclusion from the
# other side: "fuel bought on demand out of money that is never short can be
# made expensive but not scarce". Pricing cannot make a resource scarce while
# money is abundant. A RATE can, because it is not denominated in money at all.
#
# So fuel fills by itself, at a rate you own, into a depot with a ceiling you
# own. Buying stays - see FuelPanel - as the way to get past a shortage in a
# hurry, which keeps the hourly market meaningful and keeps a sink for cash.
# What changes is that doing nothing now produces fuel, and that there is a
# ceiling on how fast you can fly regardless of how rich you are.

const SAVE_FILE := "fuel_depot.json"

# TWO LEVERS, AND THEY DO DIFFERENT JOBS. Three were considered - truck size,
# truck count, depot size - but the first two are the same number wearing two
# hats: both raise barrels an hour, so a player just buys whichever is cheaper
# per point and the choice is arithmetic rather than a decision.
#
#   tankers  buys THROUGHPUT - barrels an hour, so how much you can fly.
#   depot    buys ABSENCE - measured in HOURS of production rather than in
#            barrels, so it says how long you can be away before the tanks are
#            full and everything after that is wasted.
#
# Capacity is hours x rate rather than a number of its own, which is the point
# of measuring it in hours: the two cannot drift apart, and buying throughput
# raises the ceiling with it instead of quietly making the depot too small for
# the fleet it feeds.
const BASE_RATE := 200.0
const BASE_HOURS := 4.0

# GEOMETRIC, BECAUSE THE FLEET IS. One aircraft burns about 120 an hour and a
# late fleet of sixty burns some thousands, so the ladder has about 30x to
# cover; ten steps of 1.42 covers it and no step feels like a rounding error.
# Additive steps would have to be either uselessly small early or absurd late.
const RATE_GROWTH := 1.42
const MAX_TANKERS := 10
# Hours are additive because they are read as hours: "6 hours banked" means
# something to a player in a way that "1.42x hours" does not. Eight is the top
# because past a full night's sleep the upgrade stops buying anything real.
const HOURS_STEP := 1.0
const MAX_DEPOT := 4

# Cost climbs faster than the benefit, so the last tanker is a decision rather
# than a formality. Anchored on the early game: 12,000 is a few DC-3 round
# trips at the point the first upgrade becomes worth having.
const TANKER_BASE_COST := 12000
const TANKER_COST_GROWTH := 2.2
const DEPOT_BASE_COST := 18000
const DEPOT_COST_GROWTH := 2.6

var tankers := 0
var depot := 0

# Fuel accrues in real numbers and is spent in whole ones, so the fraction has
# to live somewhere or a slow depot rounds its way to producing nothing.
var _carry := 0.0
# When production was last accounted for. Persisted, because the depot fills
# while the game is CLOSED - that is most of what a depot is for in a game you
# put down. See _catch_up.
var _last_tick := 0.0

signal depot_changed


func _ready() -> void:
	var data := _load()
	tankers = clampi(int(data.get("tankers", 0)), 0, MAX_TANKERS)
	depot = clampi(int(data.get("depot", 0)), 0, MAX_DEPOT)
	_carry = float(data.get("carry", 0.0))
	_last_tick = float(data.get("last_tick", 0.0))
	_catch_up()


# Barrels an hour, and the only thing that decides how much you can fly.
func rate() -> float:
	return BASE_RATE * pow(RATE_GROWTH, float(tankers))


# How long the depot can run unattended before it is full and producing waste.
func hours() -> float:
	return BASE_HOURS + HOURS_STEP * float(depot)


# The ceiling, derived rather than owned - see the note on the two levers.
func capacity() -> int:
	return int(round(rate() * hours()))


func tanker_cost() -> int:
	return int(round(TANKER_BASE_COST * pow(TANKER_COST_GROWTH, float(tankers))))


func depot_cost() -> int:
	return int(round(DEPOT_BASE_COST * pow(DEPOT_COST_GROWTH, float(depot))))


func tankers_maxed() -> bool:
	return tankers >= MAX_TANKERS


func depot_maxed() -> bool:
	return depot >= MAX_DEPOT


func buy_tanker() -> bool:
	if tankers_maxed() or not Economy.spend_money(tanker_cost()):
		return false
	tankers += 1
	_save()
	depot_changed.emit()
	return true


func buy_depot() -> bool:
	if depot_maxed() or not Economy.spend_money(depot_cost()):
		return false
	depot += 1
	_save()
	depot_changed.emit()
	return true


# WHAT A CLOSED GAME PRODUCED. Everything else in this project reads the clock
# to answer "how long is left"; this is the one thing that has to answer "how
# long was I gone", so it is the one place that needs a timestamp written down.
#
# Capped at the depot's own hours, which is what makes the depot upgrade mean
# anything: a four-hour depot left overnight has been full since 4am and the
# rest of the night produced nothing. Buying hours is buying the right to be
# away longer, and that is the whole of it.
func _catch_up() -> void:
	var now := GameClock.now()
	if _last_tick <= 0.0:
		_last_tick = now
		return
	var elapsed := maxf(0.0, now - _last_tick)
	_last_tick = now
	_produce(minf(elapsed, hours() * 3600.0))


func _process(delta: float) -> void:
	_last_tick = GameClock.now()
	_produce(delta)


# Fuel is an int in FuelStore, so production is banked as a float here and
# handed over a barrel at a time. Overfilling is silently dropped rather than
# clamped-and-carried: a full depot has stopped producing, and carrying the
# overflow would let a night away arrive as a burst the ceiling was meant to
# prevent.
func _produce(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var room := capacity() - FuelStore.amount
	if room <= 0:
		_carry = 0.0
		return
	_carry += rate() * seconds / 3600.0
	var whole := int(floor(_carry))
	if whole <= 0:
		return
	_carry -= float(whole)
	FuelStore.amount = FuelStore.amount + mini(whole, room)


func to_save() -> Dictionary:
	return {"tankers": tankers, "depot": depot, "carry": _carry, "last_tick": _last_tick}


func _load() -> Dictionary:
	var text := SavePaths.read_text(SAVE_FILE)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _save() -> void:
	# Never over a real playthrough - see SaveGame.save().
	if OS.get_cmdline_user_args().has("--bot"):
		return
	var f := FileAccess.open(SavePaths.write_path(SAVE_FILE), FileAccess.WRITE)
	if not f:
		return
	f.store_string(JSON.stringify(to_save(), "\t"))
	f.close()


func reset() -> void:
	tankers = 0
	depot = 0
	_carry = 0.0
	_last_tick = GameClock.now()
	depot_changed.emit()
