class_name AircraftRig
extends RefCounted

# Per-model rotor hub offsets (local to the body sprite's own center),
# placed by hand with RotorEditor instead of measured/guessed off the
# source art. {model_key: [[x,y], [x,y], ...]}
const SAVE_PATH := "res://data/aircraft_rig.json"


static func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


static func save_data(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


# Falls back to the hardcoded Fleet.WORLD_SPRITES offsets until the rig has
# actually been placed with RotorEditor.
static func get_rotor_offsets(model_key: String) -> Array[Vector2]:
	var data := load_data()
	if data.has(model_key):
		var out: Array[Vector2] = []
		for p in data[model_key]:
			out.append(Vector2(float(p[0]), float(p[1])))
		return out
	var sprites: Dictionary = Fleet.WORLD_SPRITES.get(model_key, {})
	var fallback: Array = sprites.get("rotor_offsets", [])
	var out: Array[Vector2] = []
	out.assign(fallback)
	return out
