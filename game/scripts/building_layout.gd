class_name BuildingLayout
extends RefCounted

# Where the BUILDING PLOTS are - the empty construction sites, not the
# buildings. Placed by hand with BuildingEditor (press G in game), for the same
# reason every other position in this project is: nothing measured exists for
# them, and working them out from the art has gone badly.
#
# The split matters. A plot is authored level data and lives here, in the repo.
# WHAT IS BUILT on a plot is the player's choice, made in the shop during play,
# and lives in BuildingProgress - exactly the way apron_layout holds where the
# pads are while apron_progress holds which you have bought.
#
# An earlier version of this file stored placed BUILDINGS, which had me
# authoring the player's airport for them.
#
#     {map_key: [{"id": 1, "x": 0.0, "y": 0.0}, ...]}
#
# Ids are stable and are what BuildingProgress keys against, so re-ordering or
# deleting a plot cannot silently move somebody's building to another site.
const SAVE_PATH := "res://data/building_layout.json"

# Everything tools/buildings_derive.py produces - what the shop will offer for
# a plot, and what the editor cycles as a PREVIEW so you can check the biggest
# one still fits where you put the site. Smallest first.
const BUILDINGS := [
	{"key": "cafe", "name": "Cafe"},
	{"key": "roadside_hotel", "name": "Roadside Hotel"},
	{"key": "residential_building", "name": "Residential"},
	{"key": "tv_tower", "name": "TV Tower"},
	{"key": "office_building", "name": "Office"},
	{"key": "business_center", "name": "Business Center"},
	{"key": "garden_hotel", "name": "Garden Hotel"},
	{"key": "grand_hotel", "name": "Grand Hotel"},
	{"key": "eifel_tower", "name": "Eiffel Tower"},
]


static func texture_path(key: String) -> String:
	return "res://assets/buildings/%s_2x.png" % key


static func entry(key: String) -> Dictionary:
	for b in BUILDINGS:
		if b["key"] == key:
			return b
	return {}


static func display_name(key: String) -> String:
	return str(entry(key).get("name", key))


static func load_all() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


static func save_all(all_data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(all_data, "\t"))
	f.close()


# One airport's plots - the current one unless told otherwise.
static func load_data(map_key: String = "") -> Array:
	var key := map_key if map_key != "" else Maps.current
	var got: Variant = load_all().get(key, [])
	return got if got is Array else []


static func save_data(data: Array, map_key: String = "") -> void:
	var key := map_key if map_key != "" else Maps.current
	var all_data := load_all()
	all_data[key] = data
	save_all(all_data)


# Lowest id not already taken, so deleting a plot frees its number instead of
# letting ids climb forever.
static func next_id(data: Array) -> int:
	var used := {}
	for p in data:
		used[int(p.get("id", 0))] = true
	var i := 1
	while used.has(i):
		i += 1
	return i


static func plot_by_id(plot_id: int, map_key: String = "") -> Dictionary:
	for p in load_data(map_key):
		if int(p.get("id", 0)) == plot_id:
			return p
	return {}
