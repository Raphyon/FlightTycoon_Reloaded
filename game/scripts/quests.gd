extends Node

# DAILY TASKS. Three a day, drawn from a pool, and the coin comes from finishing
# ALL THREE rather than from any one of them.
#
# WHY THIS EXISTS. The coin catalogue is 238 coins for the seven coin aircraft,
# before liveries and apron skins. A sixty-hour playthrough earns 35, on top of
# the 15 you start with. Seven aircraft and every livery are authored, shipped,
# and unreachable. Quests are the faucet - and they pay for PLAYING, which is
# what separates them from a login reward.
#
# THE COIN IS THE SET, NOT THE TASK. One coin per task is a trickle you collect
# without noticing; five for the day's three is a thing you go and finish. The
# individual tasks pay cash and fuel instead.
#
# THE CONSTRAINT EVERYTHING HERE IS SHAPED AROUND: coin aircraft ignore the
# level gate. That is why the starting float went from 100 to 15 - the old float
# bought an Ark earning 150x the starter on the same two-minute hop. So no coins
# below COIN_MIN_LEVEL, and any change to this faucet gets measured with
#
#     godot --headless --path game -- --bot --who regular
#
# If it pulls the fleet ladder forward, that milestone lands earlier and the run
# will say so.

signal quests_changed
signal set_completed(coins: int)

const SET_COIN_REWARD := 3
const COIN_MIN_LEVEL := 10

# FIVE DEALT, THREE NEEDED. The coin used to want all three of three, so a
# single row the player could not or would not do cost the whole day - which is
# what a measured run showed: 10 sets in 90 days.
#
# Dealing five and asking for three fixes that by SHAPE rather than by me
# predicting which rows are impossible. A bad row is now something you skip
# rather than something that ends your day, and the player picks which three
# they want, which is a decision where there was none.
const DAILY_COUNT := 5
const SET_REQUIRED := 3

# One reroll a day, on any task not already finished. The point is agency over a
# row you do not fancy - not an infinite hunt for the three cheapest, which is
# what an unlimited button would become.
const REFRESHES_PER_DAY := 1

const DAY_SECONDS := 86400.0

# --- reward scaling ---------------------------------------------------------
#
# A flat reward is a gift at level 1 and an insult at level 50. At the bottom a
# DC-3 leg pays 400; at the top the bot earns $173M across a run, so a day is
# worth millions and $4,000 would not be worth the tap.
#
# Cash rides level^1.1, which is ~74x from level 1 to 50 - close to the real
# spread in earning power. Fuel rides level^0.6, a gentler ~10x: a fleet lap
# burns about 10,000 units late on, so the reward has to grow, but fuel is worth
# most exactly where the game is meanest (the minimum purchase is 50 units at a
# +20% premium, the early trap in the readme) and should not lose that.
# Sized for a day of FIVE dealt tasks, not three. Dealing five without touching
# this handed out up to 5 rewards a day where 3 was the budget, and a measured
# run moved the whole game 4.7 hours forward - 38.7 h to 34.0 h to all six
# zones. 0.7x puts a typical three-task day slightly under the old three-task
# day, and an all-five day only modestly over it.
const CASH_BASE := 4000.0
const CASH_EXPONENT := 1.1
const FUEL_BASE := 120.0
const FUEL_EXPONENT := 0.6

# HOW HARD THE TASK IS, as a multiplier on the level-scaled reward. Without it
# every task paid the same - "Fly 40 routes" and "Buy fuel 500 units at a time"
# were worth identical money, which makes the set a hunt for the cheapest row
# rather than a day's work. Roughly: 1.2-1.3 for things that cost a lot of taps
# or a long leg, 0.6-0.8 for a single purchase.

# What a task is measured in.
const KIND_CASH := "cash"
const KIND_FUEL := "fuel"

# THE POOL.
#
# Every entry declares a TYPE, and the type decides which signal drives it -
# so adding a task is adding a row here, not writing a handler. Several rows can
# share a type (fly_routes and fly_far both count claimed flights) and the
# difference lives in the row.
#
#   count      target reached by counting a thing
#   condition  a single event that qualifies, target 1
#   state      polled, because nothing emits when it becomes true
#
# SCALE decides the target: "fleet" and "buildings" ride what you own, "fixed"
# does not. Both are clamped, so a one-aircraft player still has something to do
# and a full airport is not asked for 440 of anything.
const DAILY_POOL := [
	# --- the loop -----------------------------------------------------------
	{
		"key": "fly_routes", "weight": 1.2, "type": "flights", "title": "Fly %d routes",
		"reward": KIND_CASH, "scale": "fleet", "per": 4, "min": 4, "max": 40,
	},
	{
		"key": "earn_air", "weight": 1.2, "type": "earn", "title": "Earn $%s in the air",
		"reward": KIND_CASH, "scale": "earn", "per": 3, "min": 2000, "max": 99999999,
	},
	{
		"key": "collect_rent", "weight": 1.0, "type": "rent", "title": "Collect rent from %d buildings",
		"reward": KIND_FUEL, "scale": "buildings", "per": 1, "min": 3, "max": 20,
	},
	{
		"key": "refuel_fleet", "weight": 1.0, "type": "departures", "title": "Send out %d flights",
		"reward": KIND_FUEL, "scale": "fleet", "per": 2, "min": 3, "max": 30,
	},
	{
		"key": "airborne", "weight": 1.0, "type": "concurrent", "title": "Have %d aircraft in the air at once",
		# 35%, not 60. Aircraft are dispatched one at a time and a short leg
		# lands before the next few are away, so 60% of the fleet was never
		# aloft at one moment and the row could not be finished by anyone.
		"reward": KIND_CASH, "scale": "fleet_frac", "per": 35, "min": 2, "max": 25,
	},
	{
		"key": "clear_rent", "weight": 0.8, "type": "clear_rent", "title": "Leave no rent uncollected",
		"reward": KIND_FUEL, "scale": "fixed", "per": 1, "min": 1, "max": 1,
	},
	{
		"key": "fly_model", "weight": 0.6, "type": "model", "title": "Fly the %s twice",
		"reward": KIND_CASH, "scale": "fixed", "per": 2, "min": 2, "max": 2,
	},
	{
		"key": "build_one", "weight": 0.8, "type": "build", "title": "Put up a new building",
		"reward": KIND_CASH, "scale": "fixed", "per": 1, "min": 1, "max": 1,
	},
	{
		"key": "gain_level", "weight": 1.2, "type": "level", "title": "Gain a level today",
		"reward": KIND_CASH, "scale": "fixed", "per": 1, "min": 1, "max": 1,
	},

	# --- tasks that give a dead system a reason -----------------------------
	#
	# Measured, routing everything to the nearest destination and to the
	# furthest land 2.4% apart, and fuel is 1.3% of income. The payout formula
	# cannot justify a long leg and the hourly market rewards nobody for
	# watching it. A quest attaches a reason without touching balance - and if
	# it does not work, you delete a row.
	{
		"key": "fly_far", "weight": 1.3, "type": "destinations", "title": "Fly to %d different destinations",
		# TWO, and never more than the player can actually reach - see
		# _eligible. Three asked a player who flies one destination all day to
		# change their whole routine for one task; two asks for one extra trip.
		"reward": KIND_CASH, "scale": "destinations", "per": 2, "min": 2, "max": 2,
	},
	{
		"key": "cheap_fuel", "weight": 0.8, "type": "cheap_fuel", "title": "Buy fuel at $%d a unit or less",
		"reward": KIND_CASH, "scale": "fixed", "per": 1, "min": 1, "max": 1,
	},
	{
		"key": "bulk_fuel", "weight": 0.6, "type": "bulk_fuel", "title": "Buy fuel %d units at a time",
		"reward": KIND_CASH, "scale": "fixed", "per": 1, "min": 1, "max": 1,
	},
]

# The bulk-fuel task's batch, and the bar for the cheap-fuel one in dollars a
# unit. The price bar sits below the base of 10, so it takes a GOOD slot rather
# than any slot.
const BULK_FUEL_UNITS := 500

const CHEAP_FUEL_PRICE := 8

# Above this, "gain a level today" stops being a day's work - see _eligible.
const LEVEL_TASK_MAX := 40

var day := -1                # which day the current three were drawn for
var active: Array = []       # keys drawn for today
var targets: Dictionary = {} # key -> the number to reach, frozen for the day
var progress: Dictionary = {}
var claimed: Dictionary = {} # key -> the task's own reward has been taken
var set_claimed := false
var refreshes_left := REFRESHES_PER_DAY
# Per-task working state that is not a simple count: the set of destinations
# flown for "fly_far", and which model "fly_model" picked today. Saved with the
# rest, or a reload would hand back a task you had half finished.
var params: Dictionary = {}
var seen: Dictionary = {}
# Rent collected since the day rolled, so "leave no rent uncollected" cannot be
# satisfied by an airport that simply has nothing ready.
var _rent_taps := 0


func _ready() -> void:
	Fleet.flight_claimed.connect(_on_flight_claimed)
	Fleet.flight_departed.connect(_on_flight_departed)
	BuildingProgress.rent_collected.connect(_on_rent_collected)
	BuildingProgress.built_changed.connect(_on_built_changed)
	FuelStore.fuel_bought.connect(_on_fuel_bought)
	Progression.level_changed.connect(_on_level_changed)
	_roll_if_new_day()


func _process(_delta: float) -> void:
	tick()


# Everything that has to happen as time passes, callable BY HAND.
#
# _process is no use to anything that advances the clock without yielding a
# frame - the headless bot runs ninety simulated days inside one call, so
# _process never fires, the day never rolls, and the tasks sit on whatever was
# drawn at boot forever. That reported "0 sets completed" and would have been
# read as "the quest faucet changes nothing", which is a statement about the
# bot. Same reason Fleet exposes advance_by.
func tick() -> void:
	_roll_if_new_day()
	_poll_state()


# --- the day ----------------------------------------------------------------

func today() -> int:
	return int(floor(GameClock.now() / DAY_SECONDS))


func seconds_until_reset() -> float:
	return maxf(0.0, float(today() + 1) * DAY_SECONDS - GameClock.now())


# A MISSED DAY DOES NOT REROLL A FINISHED SET INTO NOTHING - it simply draws a
# new three. Progress does not carry: the point of a daily is that it is today's.
func _roll_if_new_day() -> void:
	var d := today()
	if d == day:
		return
	day = d
	# Seeded on the day, so the same day always draws the same three - a reload
	# must not let you shop for an easier set.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("quests:%d" % d)
	var pool: Array = []
	var fallback: Array = []
	for entry in DAILY_POOL:
		var key := str(entry["key"])
		if _eligible(key):
			pool.append(key)
		else:
			fallback.append(key)
	# If the airport is too young to offer three possible tasks, top up from the
	# rest rather than dealing a short day.
	while pool.size() < DAILY_COUNT and not fallback.is_empty():
		pool.append(fallback.pop_front())
	# Fisher-Yates on a seeded rng, then take the first DAILY_COUNT.
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]; pool[i] = pool[j]; pool[j] = t
	active = pool.slice(0, mini(DAILY_COUNT, pool.size()))
	targets = {}
	progress = {}
	claimed = {}
	set_claimed = false
	refreshes_left = REFRESHES_PER_DAY
	params = {}
	seen = {}
	_rent_taps = 0
	for key in active:
		if _type_of(key) == "model":
			params[key] = _pick_model(rng)
		targets[key] = _target_for(key)
		progress[key] = 0
		claimed[key] = false
	quests_changed.emit()


func _type_of(key: String) -> String:
	return str(entry(key).get("type", ""))


# A model the player actually owns, so the task is never impossible. Falls back
# to the starter, which is granted, so there is always an answer.
func _pick_model(rng: RandomNumberGenerator) -> String:
	var owned: Array = []
	for a in Fleet.aircraft:
		if not owned.has(a.model_key):
			owned.append(a.model_key)
	if owned.is_empty():
		return Fleet.STARTER_MODEL
	return str(owned[rng.randi_range(0, owned.size() - 1)])


# Frozen when the day is drawn, so buying an aircraft cannot move the goalposts
# under a task you are halfway through.
func _target_for(key: String) -> int:
	var e := entry(key)
	if e.is_empty():
		return 1
	var n := 0
	match str(e.get("scale", "fixed")):
		"fleet": n = Fleet.aircraft.size() * int(e.get("per", 1))
		"fleet_frac": n = int(round(Fleet.aircraft.size() * int(e.get("per", 1)) / 100.0))
		"destinations": n = mini(int(e.get("per", 1)), _reachable_destinations())
		"buildings": n = _built_count() * int(e.get("per", 1))
		# Money targets ride what the fleet actually earns a lap, so "earn
		# $40,000" means the same amount of PLAY at every level rather than
		# being a morning's work at 5 and a rounding error at 40.
		"earn": n = Quests.nice(_fleet_lap_value() * int(e.get("per", 1)))
		_: n = int(e.get("per", 1))
	return clampi(n, int(e.get("min", 1)), int(e.get("max", 99)))


# What one lap of the whole fleet pays, roughly - the unit the money tasks are
# priced in.
func _fleet_lap_value() -> int:
	var total := 0
	for a in Fleet.aircraft:
		total += Fleet.reward_cash_for(a, a.assigned_apron_id) * 2
	return maxi(total, 1000)


# How many robot destinations this fleet can actually reach today. A task that
# wants two is impossible with one unlocked, and drawing it anyway is what made
# the pool feel broken.
func _reachable_destinations() -> int:
	var n := 0
	for map_key in Maps.visitable_maps():
		if not Maps.is_robot_map(map_key):
			continue
		for a in Fleet.aircraft:
			if Fleet.in_range(a.model_key, map_key):
				n += 1
				break
	return n


# CAN THIS PLAYER FINISH IT TODAY AT ALL? Checked when the day is drawn, so an
# impossible row is never dealt rather than sitting there all day as a dead
# third of the set - which is what killed the set bonus: the coin needs all
# three, so one unfinishable task costs the whole day's coin.
#
# Deliberately about POSSIBILITY, not difficulty. "Fly 40 routes" is hard and
# stays in the pool; "put up a building" on a full city cannot be done at all
# and does not.
func _eligible(key: String) -> bool:
	match _type_of(key):
		"destinations":
			return _reachable_destinations() >= 2
		"concurrent":
			return Fleet.aircraft.size() >= 3
		"build":
			# Somewhere left to build, or the task is a dead row on a full city.
			return _built_count() < BuildingLayout.load_data().size()
		"rent", "clear_rent":
			return _built_count() > 0
		"level":
			# Levels slow to a crawl late on, and a day is not long enough to
			# gain one at the top of the curve.
			return Progression.level < LEVEL_TASK_MAX
		"model":
			return not Fleet.aircraft.is_empty()
	return true


func _built_count() -> int:
	var n := 0
	for id_str in BuildingProgress.built.get(Maps.DEFAULT_MAP, {}):
		n += 1
	return n


func entry(key: String) -> Dictionary:
	for e in DAILY_POOL:
		if str(e["key"]) == key:
			return e
	return {}


func title_for(key: String) -> String:
	var e := entry(key)
	if e.is_empty():
		return key
	var t := str(e.get("title", key))
	if not t.contains("%"):
		return t
	match _type_of(key):
		"cheap_fuel": return t % CHEAP_FUEL_PRICE
		"bulk_fuel": return t % BULK_FUEL_UNITS
		"earn": return t % FloatingText.grouped(int(targets.get(key, 1)))
		"model":
			var model := str(params.get(key, Fleet.STARTER_MODEL))
			return t % str(ShopCatalog.entry_for(model).get("name", model))
	return t % int(targets.get(key, 1))


# --- counting ---------------------------------------------------------------

func _bump(key: String, by: int = 1) -> void:
	if not active.has(key) or is_complete(key) or by <= 0:
		return
	progress[key] = mini(int(progress.get(key, 0)) + by, int(targets.get(key, 1)))
	quests_changed.emit()


# Bump every ACTIVE task of a given type. Types rather than keys, so two rows
# counting the same event both advance without either knowing about the other.
func _bump_type(task_type: String, by: int = 1) -> void:
	for key in active:
		if _type_of(str(key)) == task_type:
			_bump(str(key), by)


func _set_progress(key: String, value: int) -> void:
	if not active.has(key):
		return
	var capped: int = mini(value, int(targets.get(key, 1)))
	if capped == int(progress.get(key, 0)):
		return
	progress[key] = capped
	quests_changed.emit()


func _on_flight_claimed(model: String, dest: String, cash: int) -> void:
	_bump_type("flights")
	_bump_type("earn", cash)
	for key in active:
		var k := str(key)
		match _type_of(k):
			"model":
				if model == str(params.get(k, "")):
					_bump(k)
			"destinations":
				# DISTINCT destinations, so flying the same hop three times does
				# not finish it - the whole point is to use the range you paid
				# for.
				var flown: Dictionary = seen.get(k, {})
				flown[dest] = true
				seen[k] = flown
				_set_progress(k, flown.size())


func _on_flight_departed(_model: String, _dest: String) -> void:
	_bump_type("departures")


func _on_rent_collected(_plot: int, _amount: int) -> void:
	_rent_taps += 1
	_bump_type("rent")


func _on_built_changed() -> void:
	_bump_type("build")


func _on_level_changed(_level: int) -> void:
	_bump_type("level")


func _on_fuel_bought(units: int, unit_price: float) -> void:
	if unit_price <= float(CHEAP_FUEL_PRICE):
		_bump_type("cheap_fuel")
	if units >= BULK_FUEL_UNITS:
		_bump_type("bulk_fuel")


# THE POLLED ONES. Nothing emits when N aircraft happen to be airborne at the
# same moment, or when the last rent-ready building is cleared, so these are
# checked on the tick instead. Cheap: two loops over the fleet, only while the
# tasks that need them are actually drawn.
func _poll_state() -> void:
	for key in active:
		var k := str(key)
		if is_complete(k):
			continue
		match _type_of(k):
			"concurrent":
				var flying := 0
				for a in Fleet.aircraft:
					if Fleet.is_flying(a):
						flying += 1
				# HIGH WATER MARK, not the current count - landing an aircraft
				# must not undo a peak you already hit.
				_set_progress(k, maxi(int(progress.get(k, 0)), flying))
			"clear_rent":
				# Needs something to have been collected today, or an airport
				# with no buildings would complete it by standing still.
				if _built_count() > 0 and BuildingProgress.ready_plots().is_empty() \
						and _collected_today():
					_set_progress(k, 1)


func _collected_today() -> bool:
	for key in active:
		if _type_of(str(key)) == "rent" and int(progress.get(key, 0)) > 0:
			return true
	# The rent task may not be drawn today; fall back to any building that has
	# been collected since the day rolled.
	return _rent_taps > 0


# --- state ------------------------------------------------------------------

func is_complete(key: String) -> bool:
	return int(progress.get(key, 0)) >= int(targets.get(key, 1))


# Enough of the day's five finished to earn the coin.
func set_ready() -> bool:
	return completed_count() >= SET_REQUIRED


# Kept for callers that mean literally all of them.
func all_complete() -> bool:
	if active.is_empty():
		return false
	for key in active:
		if not is_complete(key):
			return false
	return true


func completed_count() -> int:
	var n := 0
	for key in active:
		if is_complete(key):
			n += 1
	return n


# --- rewards ----------------------------------------------------------------

# ROUNDED, ALWAYS. A reward of $4,237 is a number a formula produced; $4,200 is
# a number somebody decided on. The step grows with the figure so it reads clean
# at every scale rather than carrying five significant digits into the millions.
static func nice(n: int) -> int:
	var v := absi(n)
	var step := 50
	if v >= 1000000: step = 100000
	elif v >= 100000: step = 10000
	elif v >= 10000: step = 1000
	elif v >= 1000: step = 100
	return int(round(float(v) / step)) * step


func weight_of(key: String) -> float:
	return float(entry(key).get("weight", 1.0))


func cash_reward(key := "") -> int:
	return nice(int(CASH_BASE * pow(float(Progression.level), CASH_EXPONENT)
		* (weight_of(key) if key != "" else 1.0)))


func fuel_reward(key := "") -> int:
	return nice(int(FUEL_BASE * pow(float(Progression.level), FUEL_EXPONENT)
		* (weight_of(key) if key != "" else 1.0)))


func reward_kind(key: String) -> String:
	return str(entry(key).get("reward", KIND_CASH))


func reward_amount(key: String) -> int:
	return fuel_reward(key) if reward_kind(key) == KIND_FUEL else cash_reward(key)


func claim(key: String) -> bool:
	if not active.has(key) or not is_complete(key) or bool(claimed.get(key, false)):
		return false
	claimed[key] = true
	if reward_kind(key) == KIND_FUEL:
		FuelStore.amount += reward_amount(key)
	else:
		Economy.add_money(reward_amount(key))
	# No need to poke SaveGame: it already marks itself dirty off money, coin
	# and fuel changes, and a claim is always one of the three.
	quests_changed.emit()
	return true


func set_reward_available() -> bool:
	return set_ready() and not set_claimed and Progression.level >= COIN_MIN_LEVEL


# The coin. Gated on level because coin aircraft skip the level gate entirely -
# see the note at the top. Below COIN_MIN_LEVEL the set still completes and the
# tasks still pay; there is just no coin in it yet.
func claim_set() -> bool:
	if not set_reward_available():
		return false
	set_claimed = true
	Coins.add(SET_COIN_REWARD)
	set_completed.emit(SET_COIN_REWARD)
	quests_changed.emit()
	return true


func can_refresh(key: String) -> bool:
	return refreshes_left > 0 and active.has(key) and not is_complete(key) \
		and not bool(claimed.get(key, false))


# Swap one task for another the player does not already have. Finished tasks are
# not rerollable - that would be a way to bank a reward and take another run at
# the same slot.
func refresh(key: String) -> bool:
	if not can_refresh(key):
		return false
	var choices: Array = []
	for e in DAILY_POOL:
		var k := str(e["key"])
		if not active.has(k) and _eligible(k):
			choices.append(k)
	if choices.is_empty():
		return false
	var rng := RandomNumberGenerator.new()
	# Seeded on the day AND on how many refreshes are left, so the result is
	# fixed for that press rather than rerollable by reloading.
	rng.seed = hash("refresh:%d:%s:%d" % [day, key, refreshes_left])
	var replacement := str(choices[rng.randi_range(0, choices.size() - 1)])

	var i := active.find(key)
	active[i] = replacement
	targets.erase(key)
	progress.erase(key)
	claimed.erase(key)
	seen.erase(key)
	params.erase(key)
	if _type_of(replacement) == "model":
		params[replacement] = _pick_model(rng)
	targets[replacement] = _target_for(replacement)
	progress[replacement] = 0
	claimed[replacement] = false
	refreshes_left -= 1
	quests_changed.emit()
	return true


# --- save -------------------------------------------------------------------

func to_save() -> Dictionary:
	return {
		"day": day, "active": active, "targets": targets,
		"progress": progress, "claimed": claimed, "set_claimed": set_claimed,
		"params": params, "seen": seen, "rent_taps": _rent_taps,
		"refreshes_left": refreshes_left,
	}


func load_save(data: Dictionary) -> void:
	day = int(data.get("day", -1))
	active = data.get("active", [])
	targets = data.get("targets", {})
	progress = data.get("progress", {})
	claimed = data.get("claimed", {})
	set_claimed = bool(data.get("set_claimed", false))
	params = data.get("params", {})
	seen = data.get("seen", {})
	_rent_taps = int(data.get("rent_taps", 0))
	refreshes_left = int(data.get("refreshes_left", REFRESHES_PER_DAY))
	# A save from another day rolls immediately rather than showing yesterday's.
	_roll_if_new_day()
	quests_changed.emit()


func reset() -> void:
	day = -1
	_roll_if_new_day()
