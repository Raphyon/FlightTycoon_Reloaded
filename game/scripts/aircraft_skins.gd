extends Node

# Aircraft liveries: a coin purchase that makes ONE aircraft faster.
#
# Same shape as apron skins, deliberately - bought with coins, and bought for a
# single thing rather than for the model. Two Black Hawks are two purchases;
# painting one leaves the other exactly as it was. Ownership therefore lives on
# the aircraft (FleetAircraft.owned_liveries), not here.
#
# What it buys is a speed grade. A livery moves the aircraft one step up the
# S-A-B-C-D-E ladder, which is worth 20-33% of its income depending where it
# starts, because the grade is what sets flight time (Fleet.SPEED_FACTOR).
# An S-class is already top of the ladder and gains nothing - it has no livery
# on offer, and wouldn't benefit from one.
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
