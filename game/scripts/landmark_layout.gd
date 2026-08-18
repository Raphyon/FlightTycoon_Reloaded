class_name LandmarkLayout
extends RefCounted

# Fixed scenery that is placed once per airport and never bought - the terminal
# to begin with.
#
# NOT a building plot. A plot is a site the player buys something for, and what
# stands on it is their save (BuildingProgress); this is level data, the same
# class of thing as where the aprons are. The terminal is THE airport - one per
# map, no price, no rent, nothing to collect - so putting it in the Prop Shop
# catalogue would have made the building every flight departs from a thing you
# could forget to buy, or demolish.
#
# One entry per landmark per map:
#
#     {map_key: [{"key": "terminal", "x": 1490.0, "y": 980.0, "scale": 1.0}]}
#
# "scale" is there because the right size for a landmark is a judgement made by
# looking at it in the world, not one derivable from the art. The terminal's own
# palm trees measure against the background's palms one way and against the
# sprite sheet's another - so the tool sizes it by eye and records the answer.
#
# Position is the point where the building meets the ground, matching
# BuildingSlot - the sprite hangs up and left from it.
const SAVE_PATH := "res://data/landmark_layout.json"

# key -> art. Everything placeable lives here; the editor cycles this list, so
# adding a second landmark is one line and no new code.
const LANDMARKS := {
	"terminal": "res://assets/buildings/terminal_2x.png",
}


static func texture_path(key: String) -> String:
	return str(LANDMARKS.get(key, ""))


static func keys() -> Array:
	return LANDMARKS.keys()


# {map_key: [entry, ...]} for every airport at once.
static func load_all() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


static func save_all(all_data: Dictionary) -> void:
	# A bot run writes nothing to disk - see SaveGame.is_bot_run().
	if SaveGame.is_bot_run():
		return
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(all_data, "\t"))
	f.close()


# What stands on one airport - the current one unless told otherwise.
static func load_data(map_key: String = "") -> Array:
	var key := map_key if map_key != "" else Maps.current
	var got: Variant = load_all().get(key, [])
	return got if got is Array else []


static func save_data(data: Array, map_key: String = "") -> void:
	var key := map_key if map_key != "" else Maps.current
	var all_data := load_all()
	all_data[key] = data
	save_all(all_data)
