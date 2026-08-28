extends Node

signal built_changed

const SAVE_PATH := "res://data/apron_progress.json"

# What one apron costs to build, per zone.
#
# These are the biggest sink in the game and they set the pace of everything
# else: money spent on pads is money not saved toward the next zone. At the
# old figures (Snow at 150,000 a pad) pad-building swallowed roughly four
# fifths of late-game income, so a zone's level gate opened up to 108 minutes
# before you could afford the zone itself - the gate meant nothing, and the
# price tag was never the reason. Simulated across the whole curve, these
# figures put the early gates at zero wait and keep the late ones to a real
# but bounded save.
#
# Zone1 stays at 1000 - it's the zone you learn in.

var built_ids: Dictionary = {}  # str(apron_id) -> true, persisted


func _ready() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		built_ids = parsed


func is_built(apron_id: int) -> bool:
	return built_ids.has(str(apron_id))


# Each pad in an area costs more than the last one there.
#
# A PAD COSTS A TENTH OF ITS ZONE'S UNLOCK PRICE, and every pad in a zone
# costs the same. No curve.
#
# The curve it replaces was 1.35 compounding, which was set against a flat
# price that let an early player buy a money printer every three legs. It
# solved that and then ran away in the other direction: the Carrier's 32-pad
# ramp came to about $2.58bn on its own, the last pad alone near $658M, and a
# measured run stopped finishing the board at all.
#
# Deriving the price from the zone instead of from a ratio ties it to the one
# number that already says how far along the game a zone is - what it cost to
# open. It also means a zone can be re-priced in one place and its pads follow.
#
# Zone1 has no unlock price to take a tenth of, since it is where you start, so
# it keeps its own figure below.
const ZONE1_PAD_COST := 500
const PAD_SHARE_OF_ZONE := 0.1


# Rounded, because a tenth of a zone price is not always a number anybody would
# choose to write down.
func cost_for_area(area_name: String) -> int:
	var zone: Dictionary = ZoneProgress.ZONE_REQUIREMENTS.get(area_name, {})
	if zone.is_empty():
		return NiceNumber.cash(ZONE1_PAD_COST)
	return NiceNumber.cash(int(round(float(zone.get("cost", 0)) * PAD_SHARE_OF_ZONE)))


# How many pads are already standing in this area. Counted off the layout rather
# than tracked separately, so it cannot drift from what is actually built.
func built_in_area(area_name: String) -> int:
	var starts: Dictionary = ApronLayout.compute_id_starts()
	if not starts.has(area_name):
		return 0
	var map_key := Maps.map_of_area(area_name)
	var points: Array = ApronLayout.effective_area_data(map_key).get(area_name, [])
	var start: int = starts[area_name]
	var n := 0
	for i in range(points.size()):
		if is_built(start + i):
			n += 1
	return n


func can_build(apron_id: int, area_name: String) -> bool:
	return not is_built(apron_id) and ZoneProgress.is_unlocked(area_name)


func build(apron_id: int, area_name: String) -> bool:
	if is_built(apron_id):
		return false
	# Zones are bought as a whole in the expansion shop before any of their
	# aprons can be built. This used to be enforced only by the cloud
	# overlay swallowing the click, which is not the same thing as a rule.
	if not ZoneProgress.is_unlocked(area_name):
		return false
	if not Economy.spend_money(cost_for_area(area_name)):
		return false
	built_ids[str(apron_id)] = true
	_save()
	built_changed.emit()
	return true


func _save() -> void:
	# Never over a real playthrough - see SaveGame.save().
	if OS.get_cmdline_user_args().has("--bot"):
		return
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(built_ids, "\t"))
	f.close()
