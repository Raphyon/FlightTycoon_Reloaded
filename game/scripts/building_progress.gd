extends Node

signal built_changed
signal rent_changed

# What the player has built, where, and when its rent was last taken. Keyed by
# the plot ids BuildingLayout authors, per airport:
#
#     {map_key: {"3": {"key": "cafe", "since": 1754300000.0}}}
#
# "since" is a wall-clock unix time, not accumulated play time, so rent builds
# up while the game is SHUT - which is the whole point of a four-hour Grand
# Hotel cycle. Same principle as SaveGame advancing flights while you are away.
#
# The layout says where the construction sites are; this says what stands on
# them. Same split as apron_layout / apron_progress, and for the same reason -
# one is level data that ships with the game, the other is somebody's save.
#
# Ids are strings here because JSON keys always are; helpers below take ints so
# callers don't have to think about it.
const SAVE_PATH := "res://data/building_progress.json"


var built: Dictionary = {}  # map_key -> {plot_id_string: building_key}


func _ready() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		built = parsed
		_migrate_bare_strings()


# Buildings saved before rent existed are a bare key with no "since", which
# reads as an elapsed time of decades and leaves them permanently collectable.
# Stamp them as starting their first cycle now: a save from before the feature
# should begin earning, not hand over a free payout per building.
func _migrate_bare_strings() -> void:
	var now := Time.get_unix_time_from_system()
	var touched := false
	for map_key in built:
		var m: Variant = built[map_key]
		if not m is Dictionary:
			continue
		for plot_key in (m as Dictionary):
			if (m as Dictionary)[plot_key] is String:
				(m as Dictionary)[plot_key] = {"key": (m as Dictionary)[plot_key], "since": now}
				touched = true
	if touched:
		_save()


# Buildings arrive with Zone2, not at level 1.
#
# Starting with no aircraft means the Prop Shop could take the money you needed
# to buy your first one: 5,000 start, a 3,000 Coffee House, and you are left at
# 2,000 against a 3,000 DC-3 with nothing to fly and one building to tap for
# twenty-five minutes. The original never has this hole because it hands you a
# DC-3; we ask you to buy one.
#
# Gating on the ZONE rather than a level, because Zone2 costs money as well as
# a level - being level 10 and broke is exactly the state that made the trap
# possible, and it should not open the shop.
func buildings_unlocked() -> bool:
	return ZoneProgress.is_unlocked("Zone2")


func cost_of(building_key: String) -> int:
	return BuildingLayout.price_of(building_key)


# Unlocked by level, except the coin building - same rule the aircraft shop
# uses, where paying real money skips the earned ladder.
func is_unlocked(building_key: String) -> bool:
	if not buildings_unlocked():
		return false
	if BuildingLayout.currency_of(building_key) == "coins":
		return true
	return Progression.level >= BuildingLayout.level_of(building_key)


func can_afford(building_key: String) -> bool:
	if BuildingLayout.currency_of(building_key) == "coins":
		return Coins.amount >= cost_of(building_key)
	return Economy.money >= cost_of(building_key)


# How much of the airport's population it takes to add 1% to what a flight
# pays. The walkthrough's popularity system: "as you add more businesses... you
# will become more popular. This causes your Airport to earn more money."
#
# 800, set against the SIZE OF THE AIRPORT rather than against a feel for what
# one building is worth. Homeland has 41 plots; filling them all with the best
# cash building is 164,000 inhabitants, which at this rate is +205% - the city
# roughly triples what the fleet earns, for $1.64M and 41 purchases.
#
# It was 250, chosen when I was picturing a handful of sites. At 41 plots that
# came to +656%, seven times the +91% the original's level-32 account showed,
# and made the city worth several times the entire fleet.
#
# The cost of the fix is the other end: three buildings is now +0.9% rather
# than +2.9%, so the early game barely feels it. ONE LINEAR RATE CANNOT make
# three buildings matter and forty-one not be absurd. If the opening needs to
# feel it, that wants a curve - more per head early, diminishing after - which
# is a different mechanic, not a different constant.
#
# CASH ONLY, never XP (see Fleet._grant_reward). Levelling is calibrated
# against flights alone, and letting the city accelerate it would drag every
# unlock forward as a side effect of decorating.
const PEOPLE_PER_PERCENT := 800.0


# Multiplier on flight cash from the population, as a plain factor: 1.0 with no
# buildings at all. Deliberately uncapped - the ceiling is the number of plots
# an airport has, which is authored.
func popularity_multiplier(map_key: String = "") -> float:
	return 1.0 + float(total_people(map_key)) / (PEOPLE_PER_PERCENT * 100.0)


func popularity_percent(map_key: String = "") -> float:
	return float(total_people(map_key)) / PEOPLE_PER_PERCENT


# Every inhabitant your buildings have brought in. Cumulative and permanent -
# unlike rent it is never collected, it is just a number that goes up as the
# airport grows.
func total_people(map_key: String = "") -> int:
	var total := 0
	for id_str in _map(map_key):
		total += BuildingLayout.people_of(building_at(int(id_str), map_key))
	return total


func _map(map_key: String) -> Dictionary:
	var key := map_key if map_key != "" else Maps.current
	var got: Variant = built.get(key, {})
	return got if got is Dictionary else {}


# What stands on this plot, or "" if it's still an empty site.
func building_at(plot_id: int, map_key: String = "") -> String:
	var e: Variant = _map(map_key).get(str(plot_id), null)
	if e == null:
		return ""
	# Tolerates the plain-string form this used before rent existed, so a save
	# from then still reads rather than showing an empty airport.
	if e is String:
		return e
	return str((e as Dictionary).get("key", ""))


func _since(plot_id: int, map_key: String = "") -> float:
	var e: Variant = _map(map_key).get(str(plot_id), null)
	if e is Dictionary:
		return float((e as Dictionary).get("since", 0.0))
	return 0.0


# Seconds until this building's rent is ready. 0 means it is waiting for you.
func seconds_until_ready(plot_id: int, map_key: String = "") -> float:
	var key := building_at(plot_id, map_key)
	if key == "":
		return 0.0
	var cycle := BuildingLayout.cycle_seconds(key)
	var elapsed := Time.get_unix_time_from_system() - _since(plot_id, map_key)
	return maxf(0.0, cycle - elapsed)


func is_rent_ready(plot_id: int, map_key: String = "") -> bool:
	return building_at(plot_id, map_key) != "" and seconds_until_ready(plot_id, map_key) <= 0.0


# Rent does NOT stack. One cycle completes and then the building waits to be
# collected - leaving for a day does not bank twelve Grand Hotel payouts, it
# banks one. That is what the walkthrough describes ("can be collected after a
# certain amount of time"), and it is also what stops going away being strictly
# better than playing.
# A lottery on every rent collection, and the first way coins ENTER the game -
# until now the only coins in existence were the starting float, with aprons,
# skins, liveries and the coin aircraft all draining a pool that never refilled.
#
# On rent rather than on flights deliberately: it gives the city a job the fleet
# cannot do, and it is the reward for a thing you already tap.
#
# THE RATE IS THE WHOLE DESIGN. Rent does not stack, so collections are bounded
# by how often you open the game, not by how many buildings you own - a full 42
# plots collected four times a day is 168 rolls, and no more. See the table in
# tools/econ_sim.py --coins for what a given chance actually pays out.
# PER MINUTE OF THE BUILDING'S CYCLE, not per collection. A flat per-collection
# chance pays out fastest on whatever cycles fastest, and the fastest cycles are
# the cheapest buildings - a 5-minute Coffee House would roll four times as
# often as a 16-minute Office. That makes the coin lottery push players to fill
# all 42 plots with the cheapest thing available, which is the exact trap
# demolish() was added to let them escape. Scaling by cycle length makes
# coins-per-hour identical across the catalogue, so what you build is a
# decision about rent and inhabitants and nothing else.
#
# 0.00083 puts a 12-minute building - about the catalogue average - at 1% a
# collection, which measures at roughly 5 coins a month for a casual player and
# 36 for a regular one against a 5-coin Paper Plane and a 70-coin Ark. See
# tools/econ_sim.py --coins.
const COIN_CHANCE_PER_CYCLE_MINUTE := 0.00083
const COIN_DROP_AMOUNT := 1


func coin_chance_for(building_key: String) -> float:
	return COIN_CHANCE_PER_CYCLE_MINUTE * float(BuildingLayout.entry(building_key).get("minutes", 0))

# So a drop can be shown. Without it the only feedback is the HUD counter
# ticking up, which nobody is looking at while tapping a building.
signal coin_found(plot_id: int, amount: int)


func collect_rent(plot_id: int, map_key: String = "") -> int:
	if not is_rent_ready(plot_id, map_key):
		return 0
	var key := building_at(plot_id, map_key)
	var amount := BuildingLayout.rent_of(key)
	Economy.add_money(amount)
	if randf() < coin_chance_for(key):
		Coins.add(COIN_DROP_AMOUNT)
		coin_found.emit(plot_id, COIN_DROP_AMOUNT)
	var mk := map_key if map_key != "" else Maps.current
	var m := _map(mk)
	m[str(plot_id)] = {"key": key, "since": Time.get_unix_time_from_system()}
	built[mk] = m
	_save()
	rent_changed.emit()
	return amount


# Everything waiting to be collected here, for a "collect all" and for the HUD.
func ready_plots(map_key: String = "") -> Array:
	var out: Array = []
	for id_str in _map(map_key):
		var id := int(id_str)
		if is_rent_ready(id, map_key):
			out.append(id)
	out.sort()
	return out


func collect_all(map_key: String = "") -> int:
	var total := 0
	for id in ready_plots(map_key):
		total += collect_rent(id, map_key)
	return total


func is_built(plot_id: int, map_key: String = "") -> bool:
	return building_at(plot_id, map_key) != ""


func built_count(map_key: String = "") -> int:
	return _map(map_key).size()


# What a demolition hands back, as a fraction of what the building cost. The
# same 0.5 Fleet.RESALE_FRACTION uses for selling an aircraft, because it is the
# same promise: a purchase is reversible at a real but survivable loss.
#
# WHY THIS EXISTS AT ALL. There are 42 plots and nine buildings, and the plots
# fill in the first few hours - the simulator has every archetype at all 42
# inside 3.5 to 16 hours of play, long before the Grand Hotel, Garden Hotel and
# Office Building are affordable. Without a way to clear a site, filling the
# airport with Coffee Houses is a permanent decision that locks the top half of
# the catalogue out of the game for good.
#
# The loss is what stops it being free churn: rebuilding costs you half of what
# the old building cost, so replacing a Cafe with an Office Building is a
# decision rather than an obvious yes.
const DEMOLITION_REFUND := 0.5


# Clears a plot and refunds part of the price, in whatever currency it was
# bought with. Returns what was refunded, or 0 if there was nothing to clear.
#
# The inhabitants go with it, so popularity drops - that is the cost of a
# mistake, and it is what makes filling every plot with the cheapest thing a
# real error rather than a temporary one.
func demolish(plot_id: int, map_key: String = "") -> int:
	var key := building_at(plot_id, map_key)
	if key == "":
		return 0
	var refund := int(floor(cost_of(key) * DEMOLITION_REFUND))
	if BuildingLayout.currency_of(key) == "coins":
		Coins.add(refund)
	else:
		Economy.add_money(refund)
	var mk := map_key if map_key != "" else Maps.current
	var m := _map(mk)
	m.erase(str(plot_id))
	built[mk] = m
	_save()
	built_changed.emit()
	return refund


func refund_for(plot_id: int, map_key: String = "") -> int:
	var key := building_at(plot_id, map_key)
	return 0 if key == "" else int(floor(cost_of(key) * DEMOLITION_REFUND))


# Buys and places in one step. Refuses a plot that already has something on it
# rather than silently replacing it - clearing one is a separate decision, with
# its own price. See demolish.
func build(plot_id: int, building_key: String, map_key: String = "") -> bool:
	if BuildingLayout.entry(building_key).is_empty():
		return false
	if is_built(plot_id, map_key):
		return false
	if not is_unlocked(building_key):
		return false
	var paid := (Coins.spend(cost_of(building_key))
		if BuildingLayout.currency_of(building_key) == "coins"
		else Economy.spend_money(cost_of(building_key)))
	if not paid:
		return false
	var key := map_key if map_key != "" else Maps.current
	var m := _map(key)
	# The cycle starts the moment it's built, so a new building is not
	# immediately collectable - you pay, then you wait, like every other timer.
	m[str(plot_id)] = {"key": building_key, "since": Time.get_unix_time_from_system()}
	built[key] = m
	_save()
	built_changed.emit()
	return true


func _save() -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(built, "\t"))
	f.close()
