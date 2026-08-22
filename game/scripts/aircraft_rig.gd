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
#
# An optional fourth - [x, y, behind, scale] - resizes that hub's disc. The
# propliners all borrow the A400M's prop art, and they are not the A400M's
# size, so without this the disc would be hand-placed but wrongly scaled -
# guessing moved from position to size rather than removed. Per hub rather
# than per model because the near and far wing sit at different depths in an
# isometric view, so their discs do not read at the same size.
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
	# A bot run writes nothing to disk - see SaveGame.is_bot_run().
	if SaveGame.is_bot_run():
		return
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


# EXHAUST NOZZLES live under their own key in the same file - "f14:exhaust"
# beside "f14" - rather than in a second file or a second field per hub. A rotor
# hub and a nozzle want exactly the same three things placed (where, how big,
# behind or in front), so they share the storage and the editor; they are just
# different lists on the same model.
const EXHAUST_SUFFIX := ":exhaust"


static func rig_key(model_key: String, exhaust: bool) -> String:
	return model_key + EXHAUST_SUFFIX if exhaust else model_key


# Where each afterburner plume starts. Same fallback rule as the rotors: the
# model's own exhaust_offsets until the rig has actually been placed.
static func get_exhaust_offsets(model_key: String) -> Array[Vector2]:
	var data := load_data()
	var key := rig_key(model_key, true)
	if data.has(key):
		var out: Array[Vector2] = []
		for p in data[key]:
			out.append(Vector2(float(p[0]), float(p[1])))
		return out
	var sprites: Dictionary = Fleet.WORLD_SPRITES.get(model_key, {})
	var out2: Array[Vector2] = []
	out2.assign(sprites.get("exhaust_offsets", []))
	return out2


static func get_exhaust_scales(model_key: String) -> Array[float]:
	var out: Array[float] = []
	var data := load_data()
	var entries: Array = data.get(rig_key(model_key, true), [])
	var sprites: Dictionary = Fleet.WORLD_SPRITES.get(model_key, {})
	var fallback := float(sprites.get("exhaust_scale", 1.0))
	var placed := false
	for p in entries:
		if (p as Array).size() > 3:
			placed = true
			break
	if placed:
		for p in entries:
			out.append(float(p[3]) if (p as Array).size() > 3 else fallback)
		return out
	for i in range(get_exhaust_offsets(model_key).size()):
		out.append(fallback)
	return out


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


# Disc size per hub, parallel to get_rotor_offsets(). Same deferral rule as the
# behind flag: an entry shorter than four elements has never had a scale placed,
# so it falls back to the model's rotor_scale rather than silently forcing 1.0
# and undoing whatever the model set.
static func get_rotor_scales(model_key: String) -> Array[float]:
	var out: Array[float] = []
	var data := load_data()
	var entries: Array = data.get(model_key, [])

	var rig_has_scales := false
	for p in entries:
		if (p as Array).size() > 3:
			rig_has_scales = true
			break

	if rig_has_scales:
		for p in entries:
			out.append(float(p[3]) if (p as Array).size() > 3 else 1.0)
		return out

	var sprites: Dictionary = Fleet.WORLD_SPRITES.get(model_key, {})
	var fallback := float(sprites.get("rotor_scale", 1.0))
	for i in range(get_rotor_offsets(model_key).size()):
		out.append(fallback)
	return out
