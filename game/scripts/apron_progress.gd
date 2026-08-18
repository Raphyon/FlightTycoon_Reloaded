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


# Each pad in an area costs more than the last one there.
#
# Flat pricing was the runaway. Pads are the ONLY thing limiting fleet size, an
# early aircraft pays for itself in about three legs (six minutes), and pad #20
# cost the same $500 as pad #2 - so past the first hour every dollar bought
# another money printer at a price that never moved. The simulator has the
# economy tight for thirteen days and then vertical in three: $374 on day 12,
# $1.9M on day 16, everything owned by day 30.
#
# Geometric rather than linear, because the thing it has to keep up with is
# itself geometric: each pad adds an aircraft, which adds income, which buys the
# next pad. A flat surcharge is outrun immediately; a ratio is not.
#
# 1.35 is set so the FIRST few stay affordable - Zone1's second pad is 675, not
# a wall in front of a new player - while the twentieth costs about 118,000,
# which is real money against a fleet that size. Tuned in tools/econ_sim.py.
const PAD_COST_GROWTH := 1.35


# Rounded, because 1.35^n does not produce numbers anybody would choose - the
# ladder read $500, $675, $911, $1,230, $1,661 and now reads $500, $700, $900,
# $1,200, $1,700. Same curve, legible rungs.
func cost_for_area(area_name: String) -> int:
	var base: int = ZONE_BASE_COST.get(area_name, 1000)
	return NiceNumber.cash(int(round(base * pow(PAD_COST_GROWTH, built_in_area(area_name)))))


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
