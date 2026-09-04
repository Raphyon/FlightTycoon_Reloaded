extends Node

signal unlocked_changed

# Progress, so it lives in user:// - see SavePaths.
const SAVE_FILE := "zone_progress.json"

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
	# LIVE. The original's zone pages were photographed end to end: a level, a
	# price, and roughly every other one priced in COINS instead of cash. Ten
	# coin prices came off those pages - 20, 30, 40, 50, 60, 70, 100, 100, 150,
	# 200 - which is exactly the number of zones we have to unlock, so they are
	# used in order rather than fitted.
	#
	# The cash column is theirs too, and it is enormous next to what was here:
	# the last zone went from $1.9M to $300M. Its own gap is Beach, whose card
	# fell between two screenshots; $5M continues the run either side of it.
	#
	# THE LEVELS DROP HARD - the carrier was level 70 and is now 50. This
	# reverses what the old note here said, that levels pace the game and costs
	# do not. At these prices the cost is the gate, and the level is barely one.
	"Zone2": {"level": 5, "cost": 50000, "coins": 20},
	"DarkZone": {"level": 10, "cost": 100000, "coins": 30},
	"Forest": {"level": 15, "cost": 500000, "coins": 40},
	"Desert": {"level": 20, "cost": 1000000, "coins": 50},
	"Beach": {"level": 25, "cost": 5000000, "coins": 60},
	"Snow": {"level": 30, "cost": 10000000, "coins": 70},
	"Dreamland1": {"level": 35, "cost": 50000000, "coins": 100},
	"Dreamland2": {"level": 40, "cost": 100000000, "coins": 100},
	"Dreamland3": {"level": 45, "cost": 200000000, "coins": 150},
	"Carrier": {"level": 50, "cost": 300000000, "coins": 200},
}

var unlocked_zones: Dictionary = {}  # area_name -> true, persisted


func _ready() -> void:
	if not SavePaths.read_path(SAVE_FILE) != "":
		return
	var f := FileAccess.open(SavePaths.read_path(SAVE_FILE), FileAccess.READ)
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


# TEMPORARY: one purchase opens the whole of Dreamland.
#
# Dreamland has three zones and the expansion shop sells all three, but the map
# is not built out enough for them to be three separate steps yet - so buying
# Dreamland2 opens the lot. Delete this table and they go back to being bought
# one at a time; nothing else depends on it.
const OPENED_BY := {
	"Dreamland1": "Dreamland2",
	"Dreamland3": "Dreamland2",
}


func is_unlocked(area_name: String) -> bool:
	# The robot's pads are landing slots for aircraft you dispatched, not
	# something you buy - all of them, not just its first zone.
	if area_name in ALWAYS_UNLOCKED or is_robot_area(area_name):
		return true
	if unlocked_zones.has(area_name):
		return true
	var opener: String = str(OPENED_BY.get(area_name, ""))
	return opener != "" and unlocked_zones.has(opener)


func requirement_for(area_name: String) -> Dictionary:
	return ZONE_REQUIREMENTS.get(area_name, {})


# EITHER CURRENCY OPENS A ZONE. The original prices every zone twice, and the
# coin figure is small enough - 20 to 200 against a cash price up to $300M -
# that it is the way through for a player who has been saving them rather than
# spending them on aircraft. The level gate applies to both.
func unlock(area_name: String, with_coins: bool = false) -> bool:
	if is_unlocked(area_name):
		return false
	var req: Dictionary = requirement_for(area_name)
	if req.is_empty():
		return false
	if Progression.level < req.level:
		return false
	if with_coins:
		if not Coins.spend(int(req.get("coins", 0))):
			return false
	elif not Economy.spend_money(req.cost):
		return false
	unlocked_zones[area_name] = true
	_save()
	unlocked_changed.emit()
	return true


func _save() -> void:
	# Never over a real playthrough - see SaveGame.save().
	if OS.get_cmdline_user_args().has("--bot"):
		return
	var f := FileAccess.open(SavePaths.write_path(SAVE_FILE), FileAccess.WRITE)
	f.store_string(JSON.stringify(unlocked_zones, "\t"))
	f.close()
