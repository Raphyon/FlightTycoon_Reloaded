extends Node

# Aircraft liveries: a coin purchase that makes ONE aircraft faster.
#
# Same shape as apron skins, deliberately - bought with coins, and bought for a
# single thing rather than for the model. Two Black Hawks are two purchases;
# painting one leaves the other exactly as it was. Ownership therefore lives on
# the aircraft (FleetAircraft.owned_liveries), not here.
#
# What it buys is a speed grade. A livery moves the aircraft one step up the
# S-A-B-C-D-E ladder, which is worth 20-33% of its income wherever it starts,
# because the grade steps the leg time (Fleet.CLASS_STEP_MINUTES).
#
# S used to be the ceiling, which made a livery on an S-class model a repaint
# with no effect - ten coins for nothing. The ladder now runs one step past it
# to S+, a grade no model ships with and only a paint job reaches, so every
# aircraft in the game gains the same thing from being painted.
signal liveries_changed

const COST := 10

# Only the models we actually have alternate body art for.
const LIVERIES := {
	# EVERY ENTRY BELOW IS DRAWN FROM THE SAME SHEET AS ITS HULL. They used to
	# be a generation apart: the hulls were replaced wholesale by the sheet art
	# and these were left pointing at the old renders, so a painted C-17 was
	# five schemes from an aircraft that no longer existed.
	#
	# Names come from the paint. Each is read off the most saturated tenth of
	# its own pixels - the livery rather than the white fuselage under it -
	# which is why they are colours and not airline names: nothing in the art
	# says who these are meant to be.
	"a300": [
		{"key": "crimson", "name": "Crimson",
			"body": "res://assets/aircraft/a300/body_crimson_2x.png"},
		{"key": "emerald", "name": "Emerald",
			"body": "res://assets/aircraft/a300/body_emerald_2x.png"},
		{"key": "gold", "name": "Gold",
			"body": "res://assets/aircraft/a300/body_gold_2x.png"},
		{"key": "crimson2", "name": "Crimson II",
			"body": "res://assets/aircraft/a300/body_crimson2_2x.png"},
	],
	"a319": [
		{"key": "silver", "name": "Silver",
			"body": "res://assets/aircraft/a319/body_silver_2x.png"},
	],
	"a340-300": [
		{"key": "darkcrimson", "name": "Dark Crimson",
			"body": "res://assets/aircraft/a340-300/body_darkcrimson_2x.png"},
	],
	"a380-300": [
		{"key": "darkcrimson", "name": "Dark Crimson",
			"body": "res://assets/aircraft/a380-300/body_darkcrimson_2x.png"},
		{"key": "darkgold", "name": "Dark Gold",
			"body": "res://assets/aircraft/a380-300/body_darkgold_2x.png"},
		{"key": "azure", "name": "Azure",
			"body": "res://assets/aircraft/a380-300/body_azure_2x.png"},
		{"key": "darkazure", "name": "Dark Azure",
			"body": "res://assets/aircraft/a380-300/body_darkazure_2x.png"},
	],
	"a380-800": [
		{"key": "amber", "name": "Amber",
			"body": "res://assets/aircraft/a380-800/body_amber_2x.png"},
		{"key": "amber2", "name": "Amber II",
			"body": "res://assets/aircraft/a380-800/body_amber2_2x.png"},
	],
	"airship": [
		{"key": "crimson", "name": "Crimson",
			"body": "res://assets/aircraft/airship/body_crimson_2x.png"},
		{"key": "teal", "name": "Teal",
			"body": "res://assets/aircraft/airship/body_teal_2x.png"},
	],
	"b727": [
		{"key": "gold", "name": "Gold",
			"body": "res://assets/aircraft/b727/body_gold_2x.png"},
		{"key": "crimson", "name": "Crimson",
			"body": "res://assets/aircraft/b727/body_crimson_2x.png"},
		{"key": "gold2", "name": "Gold II",
			"body": "res://assets/aircraft/b727/body_gold2_2x.png"},
		{"key": "azure", "name": "Azure",
			"body": "res://assets/aircraft/b727/body_azure_2x.png"},
	],
	"b737": [
		{"key": "crimson", "name": "Crimson",
			"body": "res://assets/aircraft/b737/body_crimson_2x.png"},
	],
	"b747": [
		{"key": "crimson", "name": "Crimson",
			"body": "res://assets/aircraft/b747/body_crimson_2x.png"},
		{"key": "darkazure", "name": "Dark Azure",
			"body": "res://assets/aircraft/b747/body_darkazure_2x.png"},
		{"key": "crimson2", "name": "Crimson II",
			"body": "res://assets/aircraft/b747/body_crimson2_2x.png"},
		{"key": "darkamber", "name": "Dark Amber",
			"body": "res://assets/aircraft/b747/body_darkamber_2x.png"},
	],
	"b777-300er": [
		{"key": "crimson", "name": "Crimson",
			"body": "res://assets/aircraft/b777-300er/body_crimson_2x.png"},
	],
	"b787": [
		{"key": "emerald", "name": "Emerald",
			"body": "res://assets/aircraft/b787/body_emerald_2x.png"},
		{"key": "crimson", "name": "Crimson",
			"body": "res://assets/aircraft/b787/body_crimson_2x.png"},
		{"key": "silver", "name": "Silver",
			"body": "res://assets/aircraft/b787/body_silver_2x.png"},
		{"key": "darkazure", "name": "Dark Azure",
			"body": "res://assets/aircraft/b787/body_darkazure_2x.png"},
	],
	"banshee": [
		{"key": "darkazure", "name": "Dark Azure",
			"body": "res://assets/aircraft/banshee/body_darkazure_2x.png"},
		{"key": "gold", "name": "Gold",
			"body": "res://assets/aircraft/banshee/body_gold_2x.png"},
		{"key": "azure", "name": "Azure",
			"body": "res://assets/aircraft/banshee/body_azure_2x.png"},
		{"key": "darkviolet", "name": "Dark Violet",
			"body": "res://assets/aircraft/banshee/body_darkviolet_2x.png"},
	],
	"blackh": [
		{"key": "darkgold", "name": "Dark Gold",
			"body": "res://assets/aircraft/blackh/body_darkgold_2x.png"},
	],
	"c17": [
		{"key": "darkazure", "name": "Dark Azure",
			"body": "res://assets/aircraft/c17/body_darkazure_2x.png"},
		{"key": "silver", "name": "Silver",
			"body": "res://assets/aircraft/c17/body_silver_2x.png"},
		{"key": "azure", "name": "Azure",
			"body": "res://assets/aircraft/c17/body_azure_2x.png"},
	],
	"c800": [
		{"key": "azure", "name": "Azure",
			"body": "res://assets/aircraft/c800/body_azure_2x.png"},
		{"key": "darkemerald", "name": "Dark Emerald",
			"body": "res://assets/aircraft/c800/body_darkemerald_2x.png"},
		{"key": "darkteal", "name": "Dark Teal",
			"body": "res://assets/aircraft/c800/body_darkteal_2x.png"},
		{"key": "amber", "name": "Amber",
			"body": "res://assets/aircraft/c800/body_amber_2x.png"},
	],
	"camel": [
		{"key": "crimson", "name": "Crimson",
			"body": "res://assets/aircraft/camel/body_crimson_2x.png"},
	],
	"concorde": [
		{"key": "darkcrimson", "name": "Dark Crimson",
			"body": "res://assets/aircraft/concorde/body_darkcrimson_2x.png"},
		{"key": "darkazure", "name": "Dark Azure",
			"body": "res://assets/aircraft/concorde/body_darkazure_2x.png"},
		{"key": "gold", "name": "Gold",
			"body": "res://assets/aircraft/concorde/body_gold_2x.png"},
		{"key": "darkazure2", "name": "Dark Azure II",
			"body": "res://assets/aircraft/concorde/body_darkazure2_2x.png"},
	],
	"crj700": [
		{"key": "darkazure", "name": "Dark Azure",
			"body": "res://assets/aircraft/crj700/body_darkazure_2x.png"},
		{"key": "crimson", "name": "Crimson",
			"body": "res://assets/aircraft/crj700/body_crimson_2x.png"},
		{"key": "amber", "name": "Amber",
			"body": "res://assets/aircraft/crj700/body_amber_2x.png"},
		{"key": "azure", "name": "Azure",
			"body": "res://assets/aircraft/crj700/body_azure_2x.png"},
	],
	"dc10": [
		{"key": "darkazure", "name": "Dark Azure",
			"body": "res://assets/aircraft/dc10/body_darkazure_2x.png"},
	],
	"dc3": [
		{"key": "magenta", "name": "Magenta",
			"body": "res://assets/aircraft/dc3/body_magenta_2x.png"},
		{"key": "crimson", "name": "Crimson",
			"body": "res://assets/aircraft/dc3/body_crimson_2x.png"},
		{"key": "darkgold", "name": "Dark Gold",
			"body": "res://assets/aircraft/dc3/body_darkgold_2x.png"},
		{"key": "darkazure", "name": "Dark Azure",
			"body": "res://assets/aircraft/dc3/body_darkazure_2x.png"},
	],
	"dc4": [
		{"key": "amber", "name": "Amber",
			"body": "res://assets/aircraft/dc4/body_amber_2x.png"},
	],
	"dc6": [
		{"key": "azure", "name": "Azure",
			"body": "res://assets/aircraft/dc6/body_azure_2x.png"},
		{"key": "darkcrimson", "name": "Dark Crimson",
			"body": "res://assets/aircraft/dc6/body_darkcrimson_2x.png"},
		{"key": "amber", "name": "Amber",
			"body": "res://assets/aircraft/dc6/body_amber_2x.png"},
		{"key": "teal", "name": "Teal",
			"body": "res://assets/aircraft/dc6/body_teal_2x.png"},
	],
	"dhc8": [
		{"key": "magenta", "name": "Magenta",
			"body": "res://assets/aircraft/dhc8/body_magenta_2x.png"},
		{"key": "darkazure", "name": "Dark Azure",
			"body": "res://assets/aircraft/dhc8/body_darkazure_2x.png"},
		{"key": "emerald", "name": "Emerald",
			"body": "res://assets/aircraft/dhc8/body_emerald_2x.png"},
		{"key": "amber", "name": "Amber",
			"body": "res://assets/aircraft/dhc8/body_amber_2x.png"},
	],
	"emb120": [
		{"key": "darkazure", "name": "Dark Azure",
			"body": "res://assets/aircraft/emb120/body_darkazure_2x.png"},
		{"key": "darkgold", "name": "Dark Gold",
			"body": "res://assets/aircraft/emb120/body_darkgold_2x.png"},
		{"key": "gold", "name": "Gold",
			"body": "res://assets/aircraft/emb120/body_gold_2x.png"},
		{"key": "azure", "name": "Azure",
			"body": "res://assets/aircraft/emb120/body_azure_2x.png"},
	],
	"erj145": [
		{"key": "silver", "name": "Silver",
			"body": "res://assets/aircraft/erj145/body_silver_2x.png"},
	],
	"erj170": [
		{"key": "silver", "name": "Silver",
			"body": "res://assets/aircraft/erj170/body_silver_2x.png"},
	],
	"f15": [
		{"key": "silver", "name": "Silver",
			"body": "res://assets/aircraft/f15/body_silver_2x.png"},
		{"key": "silver2", "name": "Silver II",
			"body": "res://assets/aircraft/f15/body_silver2_2x.png"},
		{"key": "emerald", "name": "Emerald",
			"body": "res://assets/aircraft/f15/body_emerald_2x.png"},
		{"key": "crimson", "name": "Crimson",
			"body": "res://assets/aircraft/f15/body_crimson_2x.png"},
	],
	"md11": [
		{"key": "darkcrimson", "name": "Dark Crimson",
			"body": "res://assets/aircraft/md11/body_darkcrimson_2x.png"},
	],
	"ncc1701": [
		{"key": "darkazure", "name": "Dark Azure",
			"body": "res://assets/aircraft/ncc1701/body_darkazure_2x.png"},
		{"key": "silver", "name": "Silver",
			"body": "res://assets/aircraft/ncc1701/body_silver_2x.png"},
		{"key": "gold", "name": "Gold",
			"body": "res://assets/aircraft/ncc1701/body_gold_2x.png"},
		{"key": "azure", "name": "Azure",
			"body": "res://assets/aircraft/ncc1701/body_azure_2x.png"},
	],
	"p51": [
		{"key": "crimson", "name": "Crimson",
			"body": "res://assets/aircraft/p51/body_crimson_2x.png"},
	],
	"tu104": [
		{"key": "darkamber", "name": "Dark Amber",
			"body": "res://assets/aircraft/tu104/body_darkamber_2x.png"},
		{"key": "darkemerald", "name": "Dark Emerald",
			"body": "res://assets/aircraft/tu104/body_darkemerald_2x.png"},
		{"key": "darkazure", "name": "Dark Azure",
			"body": "res://assets/aircraft/tu104/body_darkazure_2x.png"},
		{"key": "darkazure2", "name": "Dark Azure II",
			"body": "res://assets/aircraft/tu104/body_darkazure2_2x.png"},
	],
	# Still on the older render set - their hulls were not replaced.
	"h4": [
		{"key": "gold", "name": "Goldrush",
			"body": "res://assets/aircraft/h4/body_gold_2x.png"},
		{"key": "navy", "name": "U.S. Navy",
			"body": "res://assets/aircraft/h4/body_navy_2x.png"},
		{"key": "forest", "name": "Forest",
			"body": "res://assets/aircraft/h4/body_forest_2x.png"},
	],
	"dreamlifter": [
		{"key": "retro", "name": "Retro Cargo",
			"body": "res://assets/aircraft/dreamlifter/body_retro_2x.png"},
		{"key": "waves", "name": "Artistic Waves",
			"body": "res://assets/aircraft/dreamlifter/body_waves_2x.png"},
		{"key": "digital", "name": "D-Lift Digital",
			"body": "res://assets/aircraft/dreamlifter/body_digital_2x.png"},
		{"key": "lcf", "name": "Boeing LCF",
			"body": "res://assets/aircraft/dreamlifter/body_lcf_2x.png"},
	],
	"a350-900": [
		{"key": "global", "name": "Global Alliance",
			"body": "res://assets/aircraft/a350-900/body_global_2x.png"},
		{"key": "arctic", "name": "Arctic Explorer",
			"body": "res://assets/aircraft/a350-900/body_arctic_2x.png"},
		{"key": "safari", "name": "Safari Wings",
			"body": "res://assets/aircraft/a350-900/body_safari_2x.png"},
		{"key": "oceanic", "name": "Oceanic",
			"body": "res://assets/aircraft/a350-900/body_oceanic_2x.png"},
		{"key": "sas", "name": "SAS",
			"body": "res://assets/aircraft/a350-900/body_sas_2x.png"},
	],
	"il62": [
		{"key": "zipped", "name": "Zipped",
			"body": "res://assets/aircraft/il62/body_zipped_2x.png"},
	],
	"atr72": [
		{"key": "cloudy", "name": "Cloudy",
			"body": "res://assets/aircraft/atr72/body_cloudy_2x.png"},
		{"key": "metaliminal", "name": "Metaliminal",
			"body": "res://assets/aircraft/atr72/body_metaliminal_2x.png"},
		{"key": "pinkdreams", "name": "Pink Dreams",
			"body": "res://assets/aircraft/atr72/body_pinkdreams_2x.png"},
	],
	"ufo": [
		{"key": "stone", "name": "Stone",
			"body": "res://assets/aircraft/ufo/body_stone_2x.png",
			"body_spin": "res://assets/aircraft/ufo/body_stone_spin_2x.png"},
	],
	"paperplane": [
		{"key": "dollar", "name": "Dollar",
			"body": "res://assets/aircraft/paperplane/body_dollar_2x.png"},
	],
}


func for_model(model_key: String) -> Array:
	return LIVERIES.get(model_key, [])


func has_any(model_key: String) -> bool:
	return not for_model(model_key).is_empty()


func entry(model_key: String, livery_key: String) -> Dictionary:
	for e in for_model(model_key):
		if e["key"] == livery_key:
			return e
	return {}


func is_owned(aircraft_id: int, livery_key: String) -> bool:
	var a := Fleet.get_aircraft(aircraft_id)
	return a != null and a.owned_liveries.has(livery_key)


# Buys it for this aircraft alone. Owning it once lets you switch back to it
# for nothing, same as apron skins.
func buy(aircraft_id: int, livery_key: String) -> bool:
	var a := Fleet.get_aircraft(aircraft_id)
	if not a or entry(a.model_key, livery_key).is_empty():
		return false
	if a.owned_liveries.has(livery_key):
		return false
	if not Coins.spend(COST):
		return false
	a.owned_liveries[livery_key] = true
	liveries_changed.emit()
	return true


func apply(aircraft_id: int, livery_key: String) -> bool:
	var a := Fleet.get_aircraft(aircraft_id)
	if not a:
		return false
	if livery_key != "" and not a.owned_liveries.has(livery_key):
		return false
	a.livery = livery_key
	liveries_changed.emit()
	Fleet.fleet_changed.emit()
	return true
