class_name CloudLayout
extends RefCounted

# {area_name: [x,y]} - one placed point per lockable zone, set by hand with
# CloudEditor the same way apron points are (see ApronLayout) - no
# positional data exists anywhere for these cloud crops, so they're placed
# by eye, not measured.
const SAVE_PATH := "res://data/cloud_layout.json"

# Cloud art per area. Area names are globally unique across every airport
# (see Maps), so one flat table still works.
#
# Each map's start area has no cloud - it's always unlocked. Only one crop
# exists for Dreamland so far, so its other areas are simply absent here and
# stay unlocked-by-requirement rather than cloud-covered. The carrier has no
# cloud art at all yet.
const CLOUD_TEXTURES := {
	# homeland
	"Zone2": "res://assets/cloud/airport001_area002_cloud.png",
	"DarkZone": "res://assets/cloud/airport001_area003_cloud.png",
	"Forest": "res://assets/cloud/airport001_area004_cloud.png",
	"Desert": "res://assets/cloud/airport001_area005_cloud.png",
	"Beach": "res://assets/cloud/airport001_area006_cloud.png",
	"Snow": "res://assets/cloud/airport001_area007_cloud.png",
	# dreamland - airport002 is the island (not the carrier). Only one crop
	# exists. Area numbering looks continuous across maps (homeland uses
	# area001-007 for Zone1..Snow), which would make area008/009/010 =
	# Dreamland1/2/3 and put this one on Dreamland2 - inferred from the
	# filename, not confirmed, so move it if the art says otherwise.
	"Dreamland2": "res://assets/cloud/airport002_area009_cloud.png",
}


# An area is coverable exactly when there's cloud art for it - deriving this
# from the table rather than keeping a second hand-maintained list is what
# stops the two disagreeing.
static func lockable_areas(map_key: String = "") -> Array:
	var out: Array = []
	for area_name in Maps.areas_for(map_key):
		if CLOUD_TEXTURES.has(area_name):
			out.append(area_name)
	return out


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


# One airport's clouds - the current one unless told otherwise.
static func load_data(map_key: String = "") -> Dictionary:
	var key := map_key if map_key != "" else Maps.current
	return load_all().get(key, {})


static func save_data(data: Dictionary, map_key: String = "") -> void:
	var key := map_key if map_key != "" else Maps.current
	var all_data := load_all()
	all_data[key] = data
	save_all(all_data)
