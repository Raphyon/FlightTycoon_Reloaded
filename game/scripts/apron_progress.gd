extends Node

signal built_changed

const SAVE_PATH := "res://data/apron_progress.json"

# What one apron costs to build, per zone. Set at roughly a fifth of the best
# aircraft you can buy at the level that zone unlocks - the aircraft is the
# investment, the pad it stands on is the lesser half of it. That ratio is
# what keeps a pad meaningful without ever being the thing you're saving for.
#
# Dreamland and the carrier used to be absent here, so they fell through to
# the 1000 default: at level 110, earning ~210k an hour, Dreamland's sixteen
# pads cost 1000 each. They are priced now.
#
# Zone1 stays at 1000 - it's the zone you learn in.
const ZONE_BASE_COST := {
	"Zone1": 1000,
	"Zone2": 2500,
	"DarkZone": 6000,
	"Forest": 12000,
	"Desert": 40000,
	"Beach": 100000,
	"Snow": 150000,
	"Dreamland1": 170000,
	"Dreamland2": 250000,
	"Dreamland3": 300000,
	"Carrier": 350000,
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
