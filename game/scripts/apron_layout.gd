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


# {area_name: [[x,y], ...]} - the actual placed points, written by ApronEditor.
static func load_area_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


static func save_area_data(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


# {area_name: starting_id} - gap-free, in AREA_NAMES order.
static func compute_id_starts(data: Dictionary) -> Dictionary:
	var starts := {}
	var next_id := 1
	for area_name in AREA_NAMES:
		starts[area_name] = next_id
		next_id += (data.get(area_name, []) as Array).size()
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
