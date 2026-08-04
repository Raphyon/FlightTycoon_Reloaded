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


func cost_of(building_key: String) -> int:
	return BuildingLayout.price_of(building_key)


# Unlocked by level, except the coin building - same rule the aircraft shop
# uses, where paying real money skips the earned ladder.
func is_unlocked(building_key: String) -> bool:
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
# 250 puts a starting airport of a few hundred inhabitants at a couple of
# percent, a mid-game one of 5,000 at +20%, and the ~22,780 the original's
# level-32 account showed at +91% - so buildings begin as a rent trickle and
# end up close to doubling the fleet. That arc is the point of them.
#
# CASH ONLY, never XP (see Fleet._grant_reward). Levelling is calibrated
# against flights alone, and letting the city accelerate it would drag every
# unlock forward as a side effect of decorating.
const PEOPLE_PER_PERCENT := 250.0


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
func collect_rent(plot_id: int, map_key: String = "") -> int:
	if not is_rent_ready(plot_id, map_key):
		return 0
	var key := building_at(plot_id, map_key)
	var amount := BuildingLayout.rent_of(key)
	Economy.add_money(amount)
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


# Buys and places in one step. Refuses a plot that already has something on it
# rather than silently replacing it - demolishing is a separate decision and
# doesn't exist yet.
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
