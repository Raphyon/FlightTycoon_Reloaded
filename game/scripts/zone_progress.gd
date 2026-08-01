extends Node

signal unlocked_changed

const SAVE_PATH := "res://data/zone_progress.json"

# Level + one-time money cost to unlock each zone (separate from the per-apron
# build costs in ApronProgress). Zone1 is free - it's where you start.
#
# LEVELS are the user's, unchanged. COSTS are set against what you can actually
# afford when the level gate opens, which is NOT the same as what the zone is
# worth: an earlier pass priced these off income rate and got Zone2 badly
# wrong - level 10 arrives around 12 minutes in with about 9,900 to your name,
# against a 25,000 price. The gate opened and then you waited.
#
# Measured with the full economy (buying pads and aircraft too, which is where
# the money really goes), these give no wait at all on the first three and a
# real but bounded save on the last three.
const ZONE_REQUIREMENTS := {
	"Zone2": {"level": 10, "cost": 8000},
	"DarkZone": {"level": 20, "cost": 12000},
	"Forest": {"level": 40, "cost": 30000},
	"Desert": {"level": 60, "cost": 75000},
	"Beach": {"level": 80, "cost": 130000},
	"Snow": {"level": 100, "cost": 210000},
	# Dreamland and the carrier - PLACEHOLDER level/cost, not from the user,
	# continuing the homeland curve past Snow.
	"Dreamland1": {"level": 110, "cost": 300000},
	"Dreamland2": {"level": 130, "cost": 450000},
	"Dreamland3": {"level": 150, "cost": 650000},
	"Carrier": {"level": 175, "cost": 950000},
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


# Zone1 alone is free - it's where the game starts. Every other zone on every
# map is bought in the expansion shop, including the first zone of Dreamland
# and the carrier, both of which have their own card (see ZoneCatalog). So
# arriving somewhere new means arriving with nothing buildable until you buy
# in, which is the intended progression rather than an oversight.
# Zones that never need buying: homeland's start zone, and the robot airport's
# single zone - its pads are landing slots for aircraft you dispatch, not
# something you purchase, and a locked robot would strand your fleet.
const ALWAYS_UNLOCKED := ["Zone1"]


func is_robot_area(area_name: String) -> bool:
	return area_name in Maps.ROBOT_AREAS


func is_unlocked(area_name: String) -> bool:
	# The robot's pads are landing slots for aircraft you dispatched, not
	# something you buy - all of them, not just its first zone.
	return (area_name in ALWAYS_UNLOCKED or is_robot_area(area_name)
		or unlocked_zones.has(area_name))


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
