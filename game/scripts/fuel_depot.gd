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
# FIFTY, MEASURED, AND THE FIRST VALUE THAT MAKES FUEL COST ANYTHING. At 200
# the depot supplied 100% of every barrel the regular run ever burned - fuel
# was 0.0% of income and blocked four passes in 140 days, which is the inert
# reading BALANCE has carried since before the depot existed, arrived at from
# the opposite direction. A rate that meets demand exactly is not a constraint,
# it is a formality.
#
# Swept against the regular run once capacity stopped being fillable by the
# shop (see the note on _banked), 200 down to 25:
#
#   rate    of income   blocked   depot share
#    200         0.0%         0        100.0%
#    150         0.1%        22         99.2%
#    100         0.0%         2        100.0%
#     75         0.6%       102         92.7%
#     50         3.8%       224         58.4%
#     25         4.9%       326         33.9%
#
# Fifty is where both halves of the design are load-bearing: the depot supplies
# most of the fuel and the shop supplies the rest, so the hourly market has
# something to sell and running dry is a real event rather than a rounding
# error. Twenty-five costs more but hands a third of the supply back to buying,
# which is the economy the depot was added to replace.
#
# IT COSTS PROGRESSION, and that is the point: the regular run ends five levels
# lower than at 100. A constraint that does not slow anything down is not one.
const BASE_RATE := 50.0
const BASE_HOURS := 1.0

# GEOMETRIC, BECAUSE THE FLEET IS. One aircraft burns about 120 an hour and a
# late fleet of sixty burns some thousands, so the ladder has about 30x to
# cover; ten steps of 1.42 covers it and no step feels like a rounding error.
# Additive steps would have to be either uselessly small early or absurd late.
const RATE_GROWTH := 1.42
const MAX_TANKERS := 10
# Hours are additive because they are read as hours: "6 hours banked" means
# something to a player in a way that "1.42x hours" does not. Eight is the top
# because past a full night's sleep the upgrade stops buying anything real.
#
# ONE HOUR AT THE BOTTOM, NOT FOUR. Four made the opening cap 800 barrels -
# 200 DC-3 legs, 6.7 hours of flying for the single aircraft you own at that
# point, and 13x the 60 barrels the game starts you with. The RATE bound at
# 1.7 aircraft, which is the intent; the cap simply never bound at all, so the
# depot upgrade had nothing to sell until the fleet was large. At one hour the
# opening cap is 200 - fifty legs, and a reason to buy the first hour.
#
# The top does not move: max capacity is max rate x max hours, so 1 + 7 steps
# reaches the same 8 hours and the same 53,334 barrels that 4 + 4 did. What
# changes is that the path there is seven decisions instead of four, and the
# first of them is worth making early.
const HOURS_STEP := 1.0
const MAX_DEPOT := 7

# Cost climbs faster than the benefit, so the last tanker is a decision rather
# than a formality. Anchored on the early game: 12,000 is a few DC-3 round
# trips at the point the first upgrade becomes worth having.
const TANKER_BASE_COST := 12000
const TANKER_COST_GROWTH := 2.2
# Gentler than the tankers' 2.2 because there are seven of these against ten,
# and the whole ladder should stay reachable: $18,000 to $2.3M, $2.29M for all
# seven.
const DEPOT_BASE_COST := 18000
const DEPOT_COST_GROWTH := 2.0

var tankers := 0
var depot := 0

# THE LADDER LENGTHS, AS VARIABLES RATHER THAN CONSTANTS. The caps are still
# MAX_TANKERS and MAX_DEPOT by default and nothing in the game changes them;
# they are settable only so a --bot run can lift them and measure what an
# uncapped ladder actually does, which is a question about the cost curve and
# not one anybody should have to answer by guessing.
var tanker_limit := MAX_TANKERS
var depot_limit := MAX_DEPOT

# THE BOTTOM OF THE RATE LADDER, SETTABLE FOR THE SAME REASON. Everything the
# depot produces is BASE_RATE times a power of RATE_GROWTH, so this one number
# sets the whole supply curve - and whether fuel binds at all is a question
# about where it sits relative to demand. A sweep answers that in one run each;
# editing a const and rebuilding answers it in one run each plus a rebuild.
var base_rate := BASE_RATE

# Fuel accrues in real numbers and is spent in whole ones, so the fraction has
# to live somewhere or a slow depot rounds its way to producing nothing.
var _carry := 0.0
# When production was last accounted for. Persisted, because the depot fills
# while the game is CLOSED - that is most of what a depot is for in a game you
# put down. See _catch_up.
var _last_tick := 0.0
# DEPOT-ORIGIN FUEL STILL IN THE TANK, and the reason capacity means anything.
# FuelStore holds one number and does not care where a barrel came from, so
# without this the ceiling was tested against TOTAL stock - and the shop sells
# 50,000 barrels in one press against a capacity of 20,000 at the rates where
# fuel is meant to bite. One bulk purchase put stock above the ceiling and the
# depot stopped producing for the rest of the run: measured, its share of fuel
# used fell from 85.7% to 14.2% between base rates of 100 and 75, with peak
# stock jumping ten-fold across the same step. The depot was not being
# out-produced, it was being switched off by the shop.
#
# Counted down rather than tracked exactly: it is clamped to the tank on every
# pass, so burning fuel frees the depot's own room again while BUYING fuel
# never fills it. Capacity is the depot's ceiling, not the tank's.
var _banked := 0
# The tank as the depot last saw it, so a DROP can be told from a PURCHASE.
# Clamping _banked to the tank is not enough on its own: with 2,000,000 bought
# barrels sitting there the tank never falls below the ceiling, so _banked
# stayed pinned at capacity and the depot still never produced again.
var _seen := -1

signal depot_changed


func _ready() -> void:
	var data := _load()
	tankers = clampi(int(data.get("tankers", 0)), 0, tanker_limit)
	depot = clampi(int(data.get("depot", 0)), 0, depot_limit)
	_carry = float(data.get("carry", 0.0))
	_last_tick = float(data.get("last_tick", 0.0))
	_banked = int(data.get("banked", 0))
	_seen = FuelStore.amount
	# EVERY fall in the tank frees the depot's own room, and every rise that is
	# not the depot's does not. That asymmetry is the whole fix, and it has to
	# see each change individually - netting them off over a tick would let a
	# purchase in the same interval hide the burn it paid for.
	FuelStore.fuel_changed.connect(_on_fuel_changed)
	_catch_up()


# Barrels an hour, and the only thing that decides how much you can fly.
func rate() -> float:
	return base_rate * pow(RATE_GROWTH, float(tankers))


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
	return tankers >= tanker_limit


func depot_maxed() -> bool:
	return depot >= depot_limit


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


# PRODUCTION FOR TIME THAT WAS SKIPPED RATHER THAN LIVED. _process is the only
# thing that credits the depot during play, and it rides the frame loop - so a
# caller that moves GameClock itself (the bot does, and so would any fast-
# forward) advances the world past the depot without producing a barrel. This
# is the same crediting, for a stated number of seconds. See Bot._skip, which
# already does exactly this for quests and for fuel deliveries.
func tick(seconds: float) -> void:
	_last_tick = GameClock.now()
	_produce(seconds)


func _process(delta: float) -> void:
	_last_tick = GameClock.now()
	_produce(delta)


# Fuel is an int in FuelStore, so production is banked as a float here and
# handed over a barrel at a time. Overfilling is silently dropped rather than
# clamped-and-carried: a full depot has stopped producing, and carrying the
# overflow would let a night away arrive as a burst the ceiling was meant to
# prevent.
# Fuel leaving the tank comes out of the depot's own stock first, which is what
# gives its ceiling back. Fuel ARRIVING is ignored unless the depot put it
# there - a shop purchase must not fill a ceiling it does not draw from.
func _on_fuel_changed(new_amount: int) -> void:
	if _seen >= 0 and new_amount < _seen:
		_banked = maxi(0, _banked - (_seen - new_amount))
	_seen = new_amount


func _produce(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var room := capacity() - _banked
	if room <= 0:
		_carry = 0.0
		return
	_carry += rate() * seconds / 3600.0
	var whole := int(floor(_carry))
	if whole <= 0:
		return
	_carry -= float(whole)
	var added := mini(whole, room)
	_banked += added
	FuelStore.amount = FuelStore.amount + added


func to_save() -> Dictionary:
	return {"tankers": tankers, "depot": depot, "carry": _carry,
		"last_tick": _last_tick, "banked": _banked}


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
	_banked = 0
	_seen = FuelStore.amount
	_last_tick = GameClock.now()
	depot_changed.emit()
