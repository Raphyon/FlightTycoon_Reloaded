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
