extends Node

signal built_changed

# What the player has built, and where. Keyed by the plot ids BuildingLayout
# authors, per airport:
#
#     {map_key: {"3": "cafe", "7": "grand_hotel"}}
#
# The layout says where the construction sites are; this says what stands on
# them. Same split as apron_layout / apron_progress, and for the same reason -
# one is level data that ships with the game, the other is somebody's save.
#
# Ids are strings here because JSON keys always are; helpers below take ints so
# callers don't have to think about it.
const SAVE_PATH := "res://data/building_progress.json"

# PLACEHOLDER prices. Ordered by size, which is the only ordering the art gives
# us - the walkthrough says businesses "earn rent for you which can be collected
# after a certain amount of time", and none of the real figures are known, so
# these are a scaffold for testing the loop rather than a balanced ladder.
#
# Deliberately NOT tied to the aircraft economy yet: buildings pay rent on a
# timer and multiply popularity, and how those two interact with flight income
# is the open design question. Balance them once that is decided.
const COSTS := {
	"cafe": 8000,
	"roadside_hotel": 15000,
	"residential_building": 30000,
	"tv_tower": 60000,
	"office_building": 90000,
	"business_center": 140000,
	"garden_hotel": 200000,
	"grand_hotel": 300000,
	# The one landmark rather than a rent earner - see the walkthrough's
	# popularity system. Priced as a trophy until that exists.
	"eifel_tower": 500000,
}

var built: Dictionary = {}  # map_key -> {plot_id_string: building_key}


func _ready() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		built = parsed


func cost_of(building_key: String) -> int:
	return int(COSTS.get(building_key, 0))


func _map(map_key: String) -> Dictionary:
	var key := map_key if map_key != "" else Maps.current
	var got: Variant = built.get(key, {})
	return got if got is Dictionary else {}


# What stands on this plot, or "" if it's still an empty site.
func building_at(plot_id: int, map_key: String = "") -> String:
	return str(_map(map_key).get(str(plot_id), ""))


func is_built(plot_id: int, map_key: String = "") -> bool:
	return building_at(plot_id, map_key) != ""


func built_count(map_key: String = "") -> int:
	return _map(map_key).size()


# Buys and places in one step. Refuses a plot that already has something on it
# rather than silently replacing it - demolishing is a separate decision and
# doesn't exist yet.
func build(plot_id: int, building_key: String, map_key: String = "") -> bool:
	if not COSTS.has(building_key):
		return false
	if is_built(plot_id, map_key):
		return false
	if not Economy.spend_money(cost_of(building_key)):
		return false
	var key := map_key if map_key != "" else Maps.current
	var m := _map(key)
	m[str(plot_id)] = building_key
	built[key] = m
	_save()
	built_changed.emit()
	return true


func _save() -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(built, "\t"))
	f.close()
