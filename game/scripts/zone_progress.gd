extends Node

signal unlocked_changed

const SAVE_PATH := "res://data/zone_progress.json"

# Level + one-time money cost to unlock each zone (separate from the per-apron
# build costs in ApronProgress). Zone1 is free - it's where you start.
#
# THE LEVELS ARE WHAT PACES THE GAME. Not the costs - that was measured, and it
# is worth writing down because a lot of effort went the wrong way first.
#
# Quadrupling every price here moves a casual player from 9.5 hours to 10.0.
# Raising these LEVELS by 1.4x moves them to 26, and a regular player to 44 -
# which is the 40-hour target. Money is never the constraint once a zone's gate
# is level-based: you are always rich enough and never high enough. Pad prices,
# zone prices and the coin float were all tuned before this was understood, and
# all three were absorbed without trace (see tools/econ_sim.py --completion).
#
# So these are the user's original numbers scaled by 1.4, keeping the shape of a
# ladder they set by feel. The alternative was scaling Progression's XP curve
# instead, which reaches the same pacing - but that curve is fitted to two real
# saves from the original game and matches both to 0.00%, and these levels are
# ours. Given a choice between overriding a measurement and rescaling a
# judgement, rescale the judgement.
#
# COSTS are unchanged and were set against what you can actually afford when the
# gate opens, which is not the same as what a zone is worth.
const ZONE_REQUIREMENTS := {
	"Zone2": {"level": 14, "cost": 16000},
	"DarkZone": {"level": 28, "cost": 24000},
	"Forest": {"level": 36, "cost": 60000},
	"Desert": {"level": 42, "cost": 150000},
	"Beach": {"level": 48, "cost": 260000},
	"Snow": {"level": 53, "cost": 420000},
	# Dreamland and the carrier - PLACEHOLDER level/cost, not from the user,
	# continuing the homeland curve past Snow.
	"Dreamland1": {"level": 57, "cost": 600000},
	"Dreamland2": {"level": 62, "cost": 900000},
	"Dreamland3": {"level": 66, "cost": 1300000},
	"Carrier": {"level": 70, "cost": 1900000},
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
	return Maps.is_robot_area(area_name)


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
