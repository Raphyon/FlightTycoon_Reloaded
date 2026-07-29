class_name FleetAircraft
extends RefCounted

enum State {
	PARKED,                # idle, needs fuel to depart (robot is the only destination)
	FLYING_OUT,
	AWAITING_DEST_CLAIM,   # landed at destination, reward not yet claimed
	AWAITING_DEST_REFUEL,  # reward claimed, needs the free refuel to head home
	FLYING_BACK,
	AWAITING_HOME_CLAIM,   # landed home, reward not yet claimed
	AWAITING_HOME_REFUEL,  # reward claimed, needs a paid refuel to go idle again
}

var id: int
var model_key: String
var assigned_apron_id: int = -1  # -1 = idle/in hangar, otherwise the apron it's parked at
var state: int = State.PARKED
var flight_time_left: float = 0.0


func _init(p_id: int, p_model_key: String) -> void:
	id = p_id
	model_key = p_model_key


func is_idle() -> bool:
	return assigned_apron_id == -1
