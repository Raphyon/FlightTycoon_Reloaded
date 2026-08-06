extends Node

# Which airport the player is standing in. Each entry is a whole separate
# world - its own background art, its own size (so its own camera limits), and
# its own set of areas to place aprons into. Travelling swaps all of it; these
# are not extra zones bolted onto one map.
#
# Keys match the ones WorldMapPanel already emits from map_chosen.
signal map_changed(map_key: String)

const DEFAULT_MAP := "homeland"
# The airport dispatched aircraft fly to, and its single area. Named here
# because both the fleet and the apron layout need them.
#
# ROBOT_MAP is the NEAREST of the five destinations, not the only one - see
# ROBOT_DESTINATIONS. It stays the fallback for a save written before
# destinations were pickable, and for anything that just wants "somewhere to
# fly".
const ROBOT_MAP := "robot"
const ROBOT_AREA := "RobotZone1"
# The robot's airport IS homeland's, so every area you can build on has a
# counterpart there. A dispatched aircraft flies to the SAME apron it took off
# from - that's what the live game does (a route record shows startApron and
# endApron both airport001_area001_apron0014, for two different users) - so the
# destination can never run out of room, and there is no "robot is full".
const ROBOT_AREAS := ["RobotZone1", "RobotZone2", "RobotDarkZone", "RobotForest",
	"RobotDesert", "RobotBeach", "RobotSnow"]
const HOMELAND_AREAS := ["Zone1", "Zone2", "DarkZone", "Forest", "Desert",
	"Beach", "Snow"]
const ROBOT_AVATAR := "res://assets/player_avatar/avatar_robot@2x.png"

# Five destinations, one per distance rating.
#
# Distance is the whole point. It sets the flight time (Fleet.flight_seconds_to,
# 1 minute at the near end to 12 hours at the far one) AND the fare, because the
# original's formula is ticket * seats * CLOUD RATING and the rating that counts
# is the route's - see Fleet.payout_for. With only the distance-1 robot in the
# game both of those collapsed to a constant and an aircraft's range stat did
# nothing but sit on its shop card. Now range is a gate: a rating-2 aircraft can
# reach exactly two of these, and the far ones pay five times the near one.
#
# Each unlocks with a homeland zone rather than a level, so the thing that opens
# a longer route is the same purchase that opens more pads to fly it from. The
# nearest is ungated - it is where the tutorial flight goes.
#
# The names/levels are PLACEHOLDER, same as the original robot's: there is no
# model of other players yet.
const ROBOT_DESTINATIONS := [
	{"key": "robot", "index": 1, "distance": 1, "label": "Robot",
		"name": "robot_222", "level": 2, "unlock": ""},
	{"key": "robot2", "index": 2, "distance": 2, "label": "Robot II",
		"name": "robot_318", "level": 9, "unlock": "Zone2"},
	{"key": "robot3", "index": 3, "distance": 3, "label": "Robot III",
		"name": "robot_451", "level": 18, "unlock": "DarkZone"},
	{"key": "robot4", "index": 4, "distance": 4, "label": "Robot IV",
		"name": "robot_607", "level": 27, "unlock": "Forest"},
	{"key": "robot5", "index": 5, "distance": 5, "label": "Robot V",
		"name": "robot_884", "level": 35, "unlock": "Desert"},
]

# Area names are globally unique, not per-map, for two reasons: ZoneProgress
# keys its unlocks by area name, and apron ids are handed out across every
# map's areas in one sequence (see ApronLayout.compute_id_starts). A second
# map reusing "Zone1" would share its unlock state and collide on ids.
#
# Map order matters. Apron ids run through the maps in this order, so a map
# listed after another can be placed without renumbering the one before it -
# homeland's aprons are already placed and referenced by ApronProgress and by
# Fleet.assigned_apron_id, so it stays first and the new maps go after.
#
# BASE_MAPS is what's authored; MAPS is what the game reads, and it is
# BASE_MAPS with the five destinations filled in - see _build_maps. The robot
# entry below is the template all five are cut from, so they cannot drift apart,
# and rewriting an EXISTING key leaves it where it is in the dictionary. That
# matters: robot2-5 are appended after everything authored here, so adding them
# renumbers nothing that was already placed.
const BASE_MAPS := {
	"homeland": {
		"name": "Home Land",
		"background": "res://assets/background/airport001.png",
		"size": Vector2i(3072, 2304),
		"areas": HOMELAND_AREAS,
	},
	"dreamland": {
		"name": "Dream Land",
		"background": "res://assets/background/airport002.png",
		"size": Vector2i(2560, 2048),
		# Three zones, and these exact keys, because that's what the
		# expansion shop already sells: ZoneCatalog carries cards 17/18/19 for
		# Dreamland1-3. Area names double as ZoneProgress unlock keys, so
		# inventing prettier names here would leave the cards unable to unlock
		# anything.
		"areas": ["Dreamland1", "Dreamland2", "Dreamland3"],
	},
	# The robot's own airport - where aircraft you dispatch actually land, and
	# which you have to travel to in order to collect them. Same art and same
	# Zone1 layout as homeland, deliberately: it reads as a mirror of home.
	#
	# Its pads are landing slots rather than something you buy (see
	# ZoneProgress), so they are all unlocked - the 1:1 mapping to your own
	# aprons is what guarantees there is always somewhere to land.
	#
	# Not on the world-map board: you get here by clicking the "Arrived" bubble
	# on the home apron of a plane that's waiting for you.
	#
	# This entry is also the TEMPLATE for the four further destinations - see
	# ROBOT_DESTINATIONS and _build_maps. Anything that should be true of all
	# five goes here; anything per-destination goes in that list.
	"robot": {
		"name": "Robot",
		"background": "res://assets/background/airport001.png",
		"size": Vector2i(3072, 2304),
		"areas": ROBOT_AREAS,
		# The background is homeland's, so it shows all seven of its regions
		# even though only one is in play here. Everything outside the landing
		# zone is permanently under cloud: not "locked, buy it later" - there is
		# nothing to buy - just out of bounds. Drawn from homeland's own
		# hand-placed cloud positions, so the two airports line up exactly.
		"cloud_cover_from": "homeland",
		# Same reasoning for the traced runway, approach and road paths: this is
		# airport1's layout, so its runway is in the same place and departures
		# should look identical. Without this the robot has no paths at all and
		# a departing aircraft just fades on the spot instead of taxiing out.
		"paths_from": "homeland",
		# Who you're visiting, shown top-left while you're here. PLACEHOLDER
		# values - there's no model of other players yet, so the name and level
		# are literals rather than anything derived.
		"visiting": {
			"name": "robot_222",
			"level": 2,
			"avatar": "res://assets/player_avatar/avatar_robot@2x.png",
			# The robot is where your dispatched aircraft land, so unfriending it
			# would strand them. Not removable, and the friends list disables its
			# remove button rather than hiding it.
			"removable": false,
		},
		# How far away this destination is - overwritten per destination by
		# _build_maps. Shown on the visitor panel as that many cloud icons, and
		# it sets both the flight time (Fleet.flight_seconds_to) and the fare
		# (Fleet.payout_for).
		"distance": 1,
	},
	"carriership": {
		"name": "Carrier Ship",
		"background": "res://assets/background/airport003.png",
		"size": Vector2i(2304, 1792),
		# One zone for the whole deck - ZoneCatalog sells a single Carrier
		# card (20), not one per pad block.
		"areas": ["Carrier"],
	},
}

# Static so it is built once when the class loads, before any autoload's
# _ready - ApronLayout reads MAPS from static functions and can't wait for us.
static var MAPS: Dictionary = _build_maps()

var current: String = DEFAULT_MAP


# BASE_MAPS plus the five destinations, each cut from the authored robot entry.
static func _build_maps() -> Dictionary:
	var out := BASE_MAPS.duplicate(true)
	var template: Dictionary = out[ROBOT_MAP]
	for d in ROBOT_DESTINATIONS:
		var e: Dictionary = template.duplicate(true)
		var index: int = d["index"]
		e["name"] = d["label"]
		e["areas"] = robot_areas(index)
		e["distance"] = d["distance"]
		e["robot_index"] = index
		# Which homeland zone has to be bought before this shows up as a place
		# you can route to. Empty means always available.
		e["unlock_area"] = d["unlock"]
		e["visiting"] = {
			"name": d["name"], "level": d["level"],
			"avatar": ROBOT_AVATAR,
			# Unfriending a destination would strand whatever is parked there.
			"removable": false,
		}
		# All five are the same airport seen from further away, so re-clicking
		# 110 pads four more times would be busywork - they borrow the placed
		# ones. Ids are still their own, because ids are handed out by area
		# NAME and each destination has its own seven (see robot_areas).
		if index > 1:
			e["aprons_from"] = ROBOT_MAP
		out[d["key"]] = e
	return out


# The seven area names belonging to destination `index`. The nearest keeps the
# original RobotZone1... names, because apron ids and every save that references
# them are already written against those.
static func robot_areas(index: int) -> Array:
	if index <= 1:
		return ROBOT_AREAS.duplicate()
	var out: Array = []
	for a in HOMELAND_AREAS:
		out.append("Robot%d%s" % [index, a])
	return out


func has_map(map_key: String) -> bool:
	return MAPS.has(map_key)


func entry(map_key: String = "") -> Dictionary:
	var key := map_key if map_key != "" else current
	return MAPS.get(key, MAPS[DEFAULT_MAP])


func areas_for(map_key: String = "") -> Array:
	return entry(map_key)["areas"]


func size_for(map_key: String = "") -> Vector2i:
	return entry(map_key)["size"]


func background_for(map_key: String = "") -> String:
	return entry(map_key)["background"]


func display_name(map_key: String = "") -> String:
	return entry(map_key)["name"]


# Every area across every map, in map order then area order. This is the
# sequence apron ids are assigned in, so it has to stay stable.
func all_areas() -> Array:
	var out: Array = []
	for key in MAPS:
		out.append_array(MAPS[key]["areas"])
	return out


# Airports belonging to someone else - anything carrying a "visiting" entry.
# That entry is also their friend-list card, so a friend and a visitable
# airport are the same thing and their name/level/avatar live in one place.
#
# Gated ones stay out of the list until their zone is bought, so the route
# picker only ever cycles through destinations you can actually use. They are
# still real maps: travel_to and Maps.entry work on them regardless, which is
# what keeps an aircraft already parked at one reachable.
func visitable_maps() -> Array:
	var out: Array = []
	for key in MAPS:
		if not MAPS[key].has("visiting"):
			continue
		var gate: String = str(MAPS[key].get("unlock_area", ""))
		if gate != "" and not ZoneProgress.is_unlocked(gate):
			continue
		out.append(key)
	return out


# One of the five destinations rather than an airport you live in.
func is_robot_map(map_key: String = "") -> bool:
	return entry(map_key).has("robot_index")


# The landing pads at one destination, or nothing for a map that isn't one.
func robot_areas_for(map_key: String = "") -> Array:
	var e := entry(map_key)
	return e["areas"] if e.has("robot_index") else []


# Whether this area is a landing slot at some destination. Used by ZoneProgress
# (they are never bought) and by ApronLayout (they are never built).
func is_robot_area(area_name: String) -> bool:
	var key := map_of_area(area_name)
	return key != "" and MAPS[key].has("robot_index")


# Which map an area belongs to, or "" if it isn't one of ours.
func map_of_area(area_name: String) -> String:
	for key in MAPS:
		if area_name in MAPS[key]["areas"]:
			return key
	return ""


# The layout files (aprons, clouds, paths) were written when there was only
# one airport, so their top level is the data itself rather than a map key.
# Anything whose top-level keys aren't map keys is therefore a legacy file and
# is read as the default map's data. Saving always writes the namespaced form,
# so the first edit migrates the file in place - no separate migration step to
# run, and nothing is lost if it never happens.
func unwrap_layout(parsed: Dictionary) -> Dictionary:
	if parsed.is_empty():
		return {}
	for key in parsed:
		if not MAPS.has(key):
			return {DEFAULT_MAP: parsed}
	return parsed


func travel_to(map_key: String) -> bool:
	if not has_map(map_key) or map_key == current:
		return false
	current = map_key
	map_changed.emit(map_key)
	return true
