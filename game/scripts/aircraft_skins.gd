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
	# Derived from full-size renders in source-assets/aircraft/atr_72_*.png
	# rather than from shop icons - cropped to their own alpha and scaled to the
	# stock body's 114x88. Checked against it edge by edge: zero drift on all
	# four sides, so switching paint does not shift the aircraft on its pad.
	"h4": [
		{"key": "gold", "name": "Goldrush",
			"body": "res://assets/aircraft/h4/body_gold_2x.png"},
		{"key": "navy", "name": "U.S. Navy",
			"body": "res://assets/aircraft/h4/body_navy_2x.png"},
		{"key": "forest", "name": "Forest",
			"body": "res://assets/aircraft/h4/body_forest_2x.png"},
	],
	# Four on one sheet, cut by connected alpha like every other livery here and
	# pinned to the stock body's 143x110.
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
	"c17": [
		{"key": "house", "name": "House Blue",
			"body": "res://assets/aircraft/c17/body_house_2x.png"},
		{"key": "military", "name": "Military",
			"body": "res://assets/aircraft/c17/body_military_2x.png"},
		{"key": "globecargo", "name": "GlobeCargo",
			"body": "res://assets/aircraft/c17/body_globecargo_2x.png"},
		{"key": "atlas", "name": "Atlas Air",
			"body": "res://assets/aircraft/c17/body_atlas_2x.png"},
		{"key": "express", "name": "Global Express",
			"body": "res://assets/aircraft/c17/body_express_2x.png"},
	],
	"b777-300er": [
		{"key": "delta", "name": "Delta",
			"body": "res://assets/aircraft/b777-300er/body_delta_2x.png"},
		{"key": "emirates", "name": "Emirates",
			"body": "res://assets/aircraft/b777-300er/body_emirates_2x.png"},
		{"key": "ana", "name": "ANA",
			"body": "res://assets/aircraft/b777-300er/body_ana_2x.png"},
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
	"a340-300": [
		{"key": "celestial", "name": "Celestial",
			"body": "res://assets/aircraft/a340-300/body_celestial_2x.png"},
		{"key": "global", "name": "Global",
			"body": "res://assets/aircraft/a340-300/body_global_2x.png"},
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
	"blackh": [
		{"key": "desert", "name": "Desert",
			"body": "res://assets/aircraft/blackh/body_desert_2x.png"},
	],
	"airship": [
		{"key": "green", "name": "Green",
			"body": "res://assets/aircraft/airship/body_green_2x.png"},
		{"key": "purple", "name": "Purple",
			"body": "res://assets/aircraft/airship/body_purple_2x.png"},
	],
	"ufo": [
		{"key": "stone", "name": "Stone",
			"body": "res://assets/aircraft/ufo/body_stone_2x.png",
			"body_spin": "res://assets/aircraft/ufo/body_stone_spin_2x.png"},
	],
	# From the hand-made fleet (tools/newfleet_derive.py). Until these landed
	# only three models had alternate art and the earliest was level 35, so the
	# whole feature was unreachable for most of a playthrough. These start at
	# level 2 and run to the top of the ladder.
	#
	# The paper plane is A rather than S because a paper plane has no business
	# being the fastest thing in the game, not because of any ceiling - S+ means
	# an S-class model can be painted too, and the UFO's Stone livery below is
	# the one that proves it.
	"paperplane": [
		{"key": "dollar", "name": "Dollar",
			"body": "res://assets/aircraft/paperplane/body_dollar_2x.png"},
	],
	"crj700": [
		{"key": "sas", "name": "SAS",
			"body": "res://assets/aircraft/crj700/body_sas_2x.png"},
	],
	"dc3": [
		{"key": "duggy", "name": "Duggy",
			"body": "res://assets/aircraft/dc3/body_duggy_2x.png"},
	],
	"tu104": [
		{"key": "beard", "name": "Beard",
			"body": "res://assets/aircraft/tu104/body_beard_2x.png"},
	],
	"b727": [
		{"key": "welcome", "name": "Welcome",
			"body": "res://assets/aircraft/b727/body_welcome_2x.png"},
	],
	# The default is the zebra scheme; the firebird is the coin unlock.
	"concorde": [
		{"key": "firebird", "name": "Firebird",
			"body": "res://assets/aircraft/concorde/body_firebird_2x.png"},
	],
	"b787": [
		{"key": "klm", "name": "KLM",
			"body": "res://assets/aircraft/b787/body_klm_2x.png"},
		{"key": "sharky", "name": "Sharky",
			"body": "res://assets/aircraft/b787/body_sharky_2x.png"},
		{"key": "flash", "name": "Flash",
			"body": "res://assets/aircraft/b787/body_flash_2x.png"},
	],
	"b747": [
		{"key": "yellow", "name": "Yellow",
			"body": "res://assets/aircraft/b747/body_yellow_2x.png"},
	],
	# The A380 arrived as a second airframe and turned out to be the same one
	# in different paint, so it's a livery of the model we already had rather
	# than a new entry in the shop. The default keeps the airline scheme; this
	# is the blue-and-magenta one.
	"a380-300": [
		{"key": "midnight", "name": "Midnight",
			"body": "res://assets/aircraft/a380-300/body_midnight_2x.png"},
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
