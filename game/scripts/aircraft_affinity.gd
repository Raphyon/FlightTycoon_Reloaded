extends Node

signal affinity_changed

# Placeholder affinity mechanic - no source data exists for this (only
# extracted images, no game logic), so this is invented: affinity is
# per-model (shared across every instance of that model), goes up by a
# fixed amount every time an aircraft of that model claims a reward
# (destination or home leg), leveling up every XP_PER_LEVEL points.
const XP_PER_LEVEL := 50
const XP_PER_USE := 10

const SAVE_PATH := "res://data/aircraft_affinity.json"

var _xp: Dictionary = {}  # model_key -> xp, persisted


func _ready() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_xp = parsed


func xp_for(model_key: String) -> int:
	return _xp.get(model_key, 0)


func level_for(model_key: String) -> int:
	return xp_for(model_key) / XP_PER_LEVEL + 1


func progress_for(model_key: String) -> float:
	return float(xp_for(model_key) % XP_PER_LEVEL) / float(XP_PER_LEVEL)


func grant_use(model_key: String) -> void:
	_xp = _load()
	_xp[model_key] = xp_for(model_key) + XP_PER_USE
	_save()
	affinity_changed.emit()


func _load() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


func _save() -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_xp, "\t"))
	f.close()
