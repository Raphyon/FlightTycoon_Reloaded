class_name ApronLayout
extends RefCounted

# Every area is placed with the in-game apron editor (see ApronLayer.gd),
# each apron just an exact clicked screen position - no grid snapping.
# Not every apron-shaped tile in the art sits on one consistent lattice (the
# original Zone1/Zone2 measurements turned out to overlap, and tiles further
# out from Zone1 land on a half-tile phase offset), so forcing everything
# through one rigid grid fights the actual art. Free placement sidesteps
# that: click exactly where the tile is, regardless of which lattice phase
# it happens to be on.
#
# IDs are assigned gap-free across all areas in this order (Zone1 1..N,
# then Zone2 continues right after, etc.) - see compute_id_starts. Areas used
# to get a reserved 20-id block each so mid-placement edits never renumbered
# a different area, but once everything's placed that just leaves ugly gaps
# for no benefit, so it's plain sequential now. The tradeoff: adding or
# removing an apron anywhere now does renumber every area after it.
# Homeland's areas. Kept for reference and as the migration target for legacy
# save files; anything that needs "the areas I can place into right now" must
# ask Maps.areas_for() instead, since that depends on which airport you're in.
const AREA_NAMES: Array[String] = [
	"Zone1", "Zone2", "DarkZone", "Forest", "Desert", "Beach", "Snow"
]
const SAVE_PATH := "res://data/apron_layout.json"

# Zone1's known-good positions, measured directly from
# source-assets/background/airport001.png via connected-component analysis
# (back when it was still grid-based) - origin (752.5, 1290.4), 256x128
# tile spacing. Converted once to raw screen positions here so Zone1 is
# pre-filled instead of needing all 10 re-clicked by hand. The first one is
# the plane's home position.
static func default_zone1_points() -> Array:
	var origin := Vector2(752.5, 1290.4)
	var points := []
	for gy in [1, 0]:
		for gx in range(5):
			var pos: Vector2 = IsoGrid.grid_to_screen(Vector2(gx, gy), origin)
			points.append([pos.x, pos.y])
	return points


# Pre-fills what shouldn't have to be clicked by hand: homeland's Zone1 from
# the measured positions above, and the robot airport's single zone as a copy
# of it - the robot is deliberately a mirror of airport1, so re-placing the
# same 20 pads there would be busywork.
#
# Seeded once each. Editing homeland's Zone1 afterwards does not propagate to
# the robot, and vice versa; they're independent from that point on.
static func ensure_seeded() -> void:
	var all_data := load_all()
	var changed := false

	var home: Dictionary = all_data.get(Maps.DEFAULT_MAP, {})
	if not home.has("Zone1"):
		home["Zone1"] = default_zone1_points()
		all_data[Maps.DEFAULT_MAP] = home
		changed = true

	var robot: Dictionary = all_data.get("robot", {})
	if not robot.has("RobotZone1"):
		var source: Array = (all_data[Maps.DEFAULT_MAP] as Dictionary).get("Zone1", [])
		robot["RobotZone1"] = source.duplicate(true)
		all_data["robot"] = robot
		changed = true

	if changed:
		save_all(all_data)


# Parsed once and held, because this is now read a lot: robot_apron_for walks
# the destination's pads and is asked per aircraft on every fleet refresh, and
# with five destinations that was five file reads and five JSON parses deep
# inside a UI update. Handing out a copy rather than the cache itself keeps the
# old contract - ApronLayer mutates what it gets back before saving it.
static var _cache: Dictionary = {}
static var _cache_valid := false


# {map_key: {area_name: [[x,y], ...]}} for every airport at once.
static func load_all() -> Dictionary:
	if _cache_valid:
		return _cache.duplicate(true)
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	_cache = Maps.unwrap_layout(parsed) if parsed is Dictionary else {}
	_cache_valid = true
	return _cache.duplicate(true)


static func save_all(all_data: Dictionary) -> void:
	# A bot run writes nothing to disk - see SaveGame.is_bot_run().
	if SaveGame.is_bot_run():
		return
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(all_data, "\t"))
	f.close()
	_cache = all_data.duplicate(true)
	_cache_valid = true


# {area_name: [[x,y], ...]} for one airport - the current one unless told
# otherwise. Written by ApronLayer.
static func load_area_data(map_key: String = "") -> Dictionary:
	var key := map_key if map_key != "" else Maps.current
	return load_all().get(key, {})


static func save_area_data(data: Dictionary, map_key: String = "") -> void:
	var key := map_key if map_key != "" else Maps.current
	var all_data := load_all()
	all_data[key] = data
	save_all(all_data)


# What gameplay should actually draw and land on. Normally the map's own pads,
# but a map declaring "aprons_from" borrows another's - the four further robot
# destinations are the same airport seen from further away, so re-clicking 110
# pads for each of them would be busywork.
#
# The borrowed points come back under THIS map's area names, matched by
# position: both lists are the same seven regions in the same order, so index i
# means the same region in both. That renaming is the whole trick - ids are
# handed out per area name (compute_id_starts), so each destination still gets
# its own block and an aircraft parked at one is not parked at another.
#
# Deliberately separate from load_area_data, which stays the map's OWN data:
# ApronLayer writes back whatever it was given, and handing it borrowed points
# would fork 110 pads into a second copy on the first click. See PathLayout,
# which draws the same line for the same reason.
static func effective_area_data(map_key: String = "") -> Dictionary:
	var key := map_key if map_key != "" else Maps.current
	var own := load_area_data(key)
	var source: String = str(Maps.entry(key).get("aprons_from", ""))
	if source == "":
		return own
	var src := load_area_data(source)
	var src_areas: Array = Maps.areas_for(source)
	var dst_areas: Array = Maps.areas_for(key)
	var out := {}
	for i in mini(src_areas.size(), dst_areas.size()):
		# Anything genuinely placed here wins, so borrowing is a default and
		# not a cage: give a destination its own pads and they take over.
		out[dst_areas[i]] = own.get(dst_areas[i], src.get(src_areas[i], []))
	return out


# {area_name: starting_id}, gap-free across EVERY map's areas in Maps order.
# Ids have to be globally unique, not per-map: ApronProgress records built
# aprons by id and FleetAircraft.assigned_apron_id points at one, so two
# airports both owning an "apron 1" would share build state and park the same
# aircraft in both places.
#
# The cost is that inserting or removing an apron renumbers everything after
# it, which is why Maps lists homeland first - its aprons are already placed
# and referenced, so placing in the newer maps can't disturb them.
static func compute_id_starts() -> Dictionary:
	var starts := {}
	var next_id := 1
	for map_key in Maps.MAPS:
		# Effective, not own: a borrowing map has no pads of its own, and
		# reserving nothing for it would put every destination's aircraft on
		# the same ids.
		var map_data: Dictionary = effective_area_data(map_key)
		for area_name in Maps.MAPS[map_key]["areas"]:
			starts[area_name] = next_id
			next_id += (map_data.get(area_name, []) as Array).size()
	return starts


# Numbered purely in click order: whatever was placed first is the lowest
# id, rising by one for each point after it. No spatial sorting - the order
# you clicked them in is the order they're numbered in. Removing one just
# shifts everything placed after it down by one id, same as before.
static func build_area_aprons(points: Array, start_id: int, area_name: String) -> Array[Apron]:
	var result: Array[Apron] = []
	for i in range(points.size()):
		var pos := Vector2(float(points[i][0]), float(points[i][1]))
		var apron := Apron.new(start_id + i, Vector2i.ZERO, pos)
		apron.area_name = area_name
		# Only Zone1's first 5 are free from the start - every other apron,
		# including the rest of Zone1, has to be built (see ApronProgress).
		# `built` itself is computed live off ApronProgress, so this is the
		# only piece of build state actually stored on the apron.
		#
		# The robot airport is the exception: its pads are landing slots for
		# aircraft you dispatch, not something you construct, so they all start
		# built. Left buildable they'd show the "needs building" cone and the
		# aircraft would land on an unbuilt pad.
		apron.free_by_default = (Maps.is_robot_area(area_name)
			or (area_name == "Zone1" and i < 5))
		result.append(apron)
	return result
