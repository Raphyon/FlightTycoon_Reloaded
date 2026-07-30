extends Node

signal unlocked_changed

const SAVE_PATH := "res://data/zone_progress.json"

# Level + one-time money cost to unlock each zone (separate from the per-apron
# build costs in ApronProgress). Zone1 is free - it's where you start.
#
# LEVELS are the user's, unchanged. COSTS are set at about half what filling
# the zone's pads costs, so unlocking a zone is a real milestone rather than a
# formality - the old numbers had Zone2 at 17% of its own pads, which made the
# gate itself barely noticeable. Snow is the one that had to move furthest
# (1.0M -> 1.4M): the V-22 arrives at level 100 and lifts income by half, so
# the old price made Snow cheaper in real time than Beach twenty levels below.
const ZONE_REQUIREMENTS := {
	"Zone2": {"level": 10, "cost": 25000},
	"DarkZone": {"level": 20, "cost": 40000},
	"Forest": {"level": 40, "cost": 85000},
	"Desert": {"level": 60, "cost": 300000},
	"Beach": {"level": 80, "cost": 700000},
	"Snow": {"level": 100, "cost": 1400000},
	# Dreamland and the carrier - PLACEHOLDER level/cost, not from the user,
	# continuing the homeland curve past Snow (level 100).
	"Dreamland1": {"level": 110, "cost": 1500000},
	"Dreamland2": {"level": 130, "cost": 2500000},
	"Dreamland3": {"level": 150, "cost": 4000000},
	"Carrier": {"level": 175, "cost": 8000000},
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
const ALWAYS_UNLOCKED := ["Zone1", "RobotZone1"]


func is_unlocked(area_name: String) -> bool:
	return area_name in ALWAYS_UNLOCKED or unlocked_zones.has(area_name)


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
