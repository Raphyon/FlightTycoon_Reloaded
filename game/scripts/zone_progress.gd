extends Node

signal unlocked_changed

const SAVE_PATH := "res://data/zone_progress.json"

# Exact numbers from the user - level + one-time money cost to unlock each
# zone (separate from the per-apron build costs in ApronProgress). Zone1
# isn't listed here - it's the start zone, always unlocked.
const ZONE_REQUIREMENTS := {
	"Zone2": {"level": 10, "cost": 10000},
	"DarkZone": {"level": 20, "cost": 20000},
	"Forest": {"level": 40, "cost": 100000},
	"Desert": {"level": 60, "cost": 250000},
	"Beach": {"level": 80, "cost": 500000},
	"Snow": {"level": 100, "cost": 1000000},
}

var unlocked_zones: Dictionary = {}  # area_name -> true, persisted


func _ready() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		unlocked_zones = parsed


func is_unlocked(area_name: String) -> bool:
	return area_name == "Zone1" or unlocked_zones.has(area_name)


func requirement_for(area_name: String) -> Dictionary:
	return ZONE_REQUIREMENTS.get(area_name, {})


func unlock(area_name: String) -> bool:
	if is_unlocked(area_name):
		return false
	var req: Dictionary = requirement_for(area_name)
	if req.is_empty():
		return false
	if Progression.level < req.level:
		return false
	if not Economy.spend_money(req.cost):
		return false
	unlocked_zones[area_name] = true
	_save()
	unlocked_changed.emit()
	return true


func _save() -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(unlocked_zones, "\t"))
	f.close()
