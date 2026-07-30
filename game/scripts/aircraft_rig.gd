class_name AircraftRig
extends RefCounted

# Per-model rotor hub offsets (local to the body sprite's own center),
# placed by hand with RotorEditor instead of measured/guessed off the
# source art. {model_key: [[x,y], [x,y], ...]}
#
# Each hub may carry an optional third element - [x, y, behind] - marking it
# as drawing behind the fuselage instead of on top of it. In the isometric
# view an inboard prop on the far wing sits partly *behind* the hull, so
# painting its blur disc over the fuselage reads as floating in front of the
# aircraft. Two-element entries are still valid and mean "in front".
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


# Whether each hub draws behind the fuselage, parallel to get_rotor_offsets().
static func get_rotor_behind(model_key: String) -> Array[bool]:
	var out: Array[bool] = []
	var data := load_data()
	var entries: Array = data.get(model_key, [])

	# A rig saved before the flag existed has only [x, y] per hub. That's
	# "not yet decided", not "all in front", so it defers to the model's
	# default instead of silently overriding it.
	var rig_has_flags := false
	for p in entries:
		if (p as Array).size() > 2:
			rig_has_flags = true
			break

	if rig_has_flags:
		for p in entries:
			out.append((p as Array).size() > 2 and bool(p[2]))
		return out

	var sprites: Dictionary = Fleet.WORLD_SPRITES.get(model_key, {})
	var defaults: Array = sprites.get("rotor_behind_body", [])
	for i in range(get_rotor_offsets(model_key).size()):
		out.append(i in defaults)
	return out
