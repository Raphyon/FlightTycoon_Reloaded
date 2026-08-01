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
const ROBOT_MAP := "robot"
const ROBOT_AREA := "RobotZone1"
# The robot's airport IS homeland's, so every area you can build on has a
# counterpart there. A dispatched aircraft flies to the SAME apron it took off
# from - that's what the live game does (a route record shows startApron and
# endApron both airport001_area001_apron0014, for two different users) - so the
# destination can never run out of room, and there is no "robot is full".
const ROBOT_AREAS := ["RobotZone1", "RobotZone2", "RobotDarkZone", "RobotForest",
	"RobotDesert", "RobotBeach", "RobotSnow"]
# Which homeland area each robot area mirrors, for cloud cover: a robot zone is
# under cloud exactly while its homeland counterpart is still locked.
const ROBOT_MIRRORS := {
	"RobotZone1": "Zone1", "RobotZone2": "Zone2", "RobotDarkZone": "DarkZone",
	"RobotForest": "Forest", "RobotDesert": "Desert", "RobotBeach": "Beach",
	"RobotSnow": "Snow",
}

# Area names are globally unique, not per-map, for two reasons: ZoneProgress
# keys its unlocks by area name, and apron ids are handed out across every
# map's areas in one sequence (see ApronLayout.compute_id_starts). A second
# map reusing "Zone1" would share its unlock state and collide on ids.
#
# Map order matters. Apron ids run through the maps in this order, so a map
# listed after another can be placed without renumbering the one before it -
# homeland's aprons are already placed and referenced by ApronProgress and by
# Fleet.assigned_apron_id, so it stays first and the new maps go after.
const MAPS := {
	"homeland": {
		"name": "Home Land",
		"background": "res://assets/background/airport001.png",
		"size": Vector2i(3072, 2304),
		"areas": ["Zone1", "Zone2", "DarkZone", "Forest", "Desert", "Beach", "Snow"],
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
	# One zone only, always unlocked (see ZoneProgress). There are no spare
	# expansion-shop cards for more, and its pads are landing slots rather than
	# something you buy - the capacity limit is the point.
	#
	# Not on the world-map board: you get here by clicking the "Arrived" bubble
	# on the home apron of a plane that's waiting for you.
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
		# How far away this destination is. Shown on the visitor panel as that
		# many cloud icons, and it's what sets the flight time - see
		# Fleet.flight_seconds_to. 1 keeps the robot at the short duration the
		# flat constant used to give, so nothing changes until a further
		# destination exists to contrast with.
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

var current: String = DEFAULT_MAP


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
func visitable_maps() -> Array:
	var out: Array = []
	for key in MAPS:
		if MAPS[key].has("visiting"):
			out.append(key)
	return out


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
