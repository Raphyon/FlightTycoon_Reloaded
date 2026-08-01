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
const ZONE_BASE_COST := {
	"Zone1": 500,
	"Zone2": 800,
	"DarkZone": 1500,
	"Forest": 3000,
	"Desert": 8000,
	"Beach": 15000,
	"Snow": 25000,
	# Dreamland and the carrier used to be absent here entirely, so they fell
	# through to the 1000 default: at level 110, earning ~27k a minute, its
	# sixteen pads cost 1000 each.
	"Dreamland1": 30000,
	"Dreamland2": 40000,
	"Dreamland3": 50000,
	"Carrier": 60000,
}

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


func cost_for_area(area_name: String) -> int:
	return ZONE_BASE_COST.get(area_name, 1000)


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
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(built_ids, "\t"))
	f.close()
