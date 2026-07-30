class_name ApronLayout
extends RefCounted

# Every area is placed with the in-game apron editor (see ApronEditor.gd),
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


# {map_key: {area_name: [[x,y], ...]}} for every airport at once.
static func load_all() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return Maps.unwrap_layout(parsed) if parsed is Dictionary else {}


static func save_all(all_data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(all_data, "\t"))
	f.close()


# {area_name: [[x,y], ...]} for one airport - the current one unless told
# otherwise. Written by ApronEditor.
static func load_area_data(map_key: String = "") -> Dictionary:
	var key := map_key if map_key != "" else Maps.current
	return load_all().get(key, {})


static func save_area_data(data: Dictionary, map_key: String = "") -> void:
	var key := map_key if map_key != "" else Maps.current
	var all_data := load_all()
	all_data[key] = data
	save_all(all_data)


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
	var all_data := load_all()
	var starts := {}
	var next_id := 1
	for map_key in Maps.MAPS:
		var map_data: Dictionary = all_data.get(map_key, {})
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
		apron.free_by_default = area_name == "Zone1" and i < 5
		result.append(apron)
	return result
