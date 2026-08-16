extends Node

# Jump the save straight to a named point in the game, so mid and late content
# can be looked at without playing three hours to reach it.
#
# WHY THESE EXIST. Every balance decision past the first hour has been made
# against a simulation, because getting there by hand takes longer than anyone
# will do repeatedly - and a simulation cannot tell you that a panel is cramped,
# that a bubble is unreachable, or that forty aircraft on one screen is
# unreadable. These are for LOOKING at the game, not for measuring it; the
# numbers each one sets are taken from tools/econ_sim.py so they are at least a
# plausible shape rather than round figures picked by hand. The levels track the
# 1.4x stretch of the zone gates - a scenario has to clear the gates of the zones
# it claims to have bought.
#
# DEBUG ONLY. Reachable from the F1 menu, never from normal play. Each applies
# on top of a full reset, so a scenario is always the same scenario and never
# whatever you happened to be holding.

# level, cash, coins, fuel, zones bought, pads built per unlocked area,
# aircraft (model -> how many), buildings to raise.
const SCENARIOS := {
	"early": {
		"label": "Early  (~15 min in)",
		"level": 13, "money": 6000, "coins": 15, "fuel": 120,
		"zones": [], "pads": 8,
		"fleet": {"dc3": 3, "dhc6": 2, "atr72": 2},
		"buildings": 0,
	},
	"mid": {
		"label": "Mid  (~1.5 hrs in)",
		"level": 28, "money": 180000, "coins": 60, "fuel": 900,
		"zones": ["Zone2", "DarkZone"], "pads": 14,
		"fleet": {"crj700": 6, "an140": 5, "328jet": 5, "dc6": 4, "tu104": 3},
		"buildings": 14,
	},
	"late": {
		"label": "Late  (~3 hrs in)",
		"level": 42, "money": 2500000, "coins": 40, "fuel": 4000,
		"zones": ["Zone2", "DarkZone", "Forest", "Desert"], "pads": 18,
		"fleet": {"a319": 8, "b727": 8, "b707": 6, "a300": 6, "dc10": 5, "b787": 4},
		"buildings": 30,
	},
	"endgame": {
		"label": "Endgame  (everything)",
		# LEVEL 72, NOT 56. "Everything" has to clear every gate, and the
		# highest is the Carrier at 70 - at 56 this scenario could not even open
		# Dreamland1 at 57, so the two extra airports stayed shut in the one
		# scenario whose whole job is having them.
		"level": 72, "money": 50000000, "coins": 250, "fuel": 50000,
		"zones": ["Zone2", "DarkZone", "Forest", "Desert", "Beach", "Snow",
			"Dreamland1", "Dreamland2", "Dreamland3", "Carrier"],
		"pads": 999,
		"fleet": {"747": 10, "b747": 10, "a380-300": 10, "an-225": 8,
			"a400m": 8, "concorde": 4, "ark": 4, "x37b": 4},
		"buildings": 999,
	},
}


func names() -> Array:
	return SCENARIOS.keys()


func label_for(key: String) -> String:
	return str(SCENARIOS.get(key, {}).get("label", key))


# Wipes and rebuilds. Deliberately destructive - a scenario you have half
# played is not the scenario any more, and quietly merging into an existing
# save is how "it worked on mine" starts.
func apply(key: String) -> bool:
	var s: Dictionary = SCENARIOS.get(key, {})
	if s.is_empty():
		return false

	SaveGame.reset_to_defaults()
	# reset_to_defaults hands out the starter DC-3; the scenario's own fleet
	# replaces it rather than sitting alongside as a stray extra.
	Fleet.aircraft.clear()
	Fleet.reset_ids()

	Economy.money = int(s["money"])
	Coins.amount = int(s["coins"])
	FuelStore.amount = int(s["fuel"])
	Progression.level = int(s["level"])
	Progression.xp = Progression.xp_for_level(int(s["level"]))

	for area in s["zones"]:
		ZoneProgress.unlocked_zones[area] = true

	_build_pads(int(s["pads"]))
	_grant_fleet(s["fleet"])
	_raise_buildings(int(s["buildings"]))

	Progression.xp_changed.emit(Progression.xp)
	Progression.level_changed.emit(Progression.level)
	ZoneProgress.unlocked_changed.emit()
	ApronProgress.built_changed.emit()
	BuildingProgress.built_changed.emit()
	Fleet.fleet_changed.emit()
	SaveGame.save()
	return true


# `per_area` pads in every area that is unlocked, capped by what is actually
# placed there - so a scenario cannot invent aprons the level does not have.
# EVERY AIRPORT YOU OWN, not just homeland. A scenario that unlocked Dreamland
# and the carrier but only built pads at home left you standing on two empty
# decks - which is exactly what "Endgame (everything)" is for.
func _build_pads(per_area: int) -> void:
	# Ids are globally unique across every airport, so one call covers the lot.
	var starts: Dictionary = ApronLayout.compute_id_starts()
	for map_key in Maps.MAPS:
		if not Maps.is_owned(map_key) or Maps.MAPS[map_key].has("visiting"):
			continue
		var data: Dictionary = ApronLayout.effective_area_data(map_key)
		for area_name in Maps.areas_for(map_key):
			if not ZoneProgress.is_unlocked(area_name) or not starts.has(area_name):
				continue
			var placed: int = (data.get(area_name, []) as Array).size()
			var start: int = starts[area_name]
			for i in range(mini(per_area, placed)):
				ApronProgress.built_ids[str(start + i)] = true


# Parked on real pads, in id order, so the airport looks lived in rather than
# holding a hangar full of idle aircraft nothing can see.
func _grant_fleet(counts: Dictionary) -> void:
	var pads: Array = ApronProgress.built_ids.keys()
	pads.sort_custom(func(a, b): return int(a) < int(b))
	var next := 0
	for model_key in counts:
		for _i in range(int(counts[model_key])):
			if next >= pads.size():
				return
			var a := FleetAircraft.new(Fleet._next_id, str(model_key))
			Fleet._next_id += 1
			a.assigned_apron_id = int(pads[next])
			# Matched to the aircraft's rating, same rule the route screen
			# defaults to - otherwise a late-game airport of rating-5 flagships
			# all sits flying the 1-cloud tutorial hop.
			a.destination = Fleet.best_destination_for(str(model_key))
			next += 1
			Fleet.aircraft.append(a)


# The best building the scenario's level can reach, on the first N plots.
func _raise_buildings(count: int) -> void:
	var best := ""
	for b in BuildingLayout.BUILDINGS:
		if str(b.get("currency", "cash")) == "coins":
			continue
		if int(b["level"]) > Progression.level:
			continue
		if best == "" or int(b["rent"]) > BuildingLayout.rent_of(best):
			best = str(b["key"])
	if best == "":
		return
	var now := GameClock.now()
	var m: Dictionary = {}
	var n := 0
	for plot in BuildingLayout.load_data():
		if n >= count:
			break
		# Staggered into the past so their rent is at different points in the
		# cycle - all forty ready at once is not a state play ever produces.
		m[str(int(plot.get("id", 0)))] = {
			"key": best,
			"since": now - float(n % 10) * BuildingLayout.cycle_seconds(best) * 0.1,
		}
		n += 1
	BuildingProgress.built[Maps.DEFAULT_MAP] = m
