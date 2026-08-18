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
# Which pad at the robot airport this aircraft is flying to / sitting on. Held
# from dispatch until it heads home again, so it doubles as the capacity lock -
# see Fleet.claim_robot_apron. -1 = not out on a trip.
var robot_apron_id: int = -1
# Liveries are bought per aircraft, not per model (see AircraftSkins), so both
# what this one wears and what it has paid for live here rather than in a
# central table keyed by model.
# Where this aircraft flies when dispatched. Chosen with the aircraft when the
# route is assigned (see RoutePickerPanel); a friend's airport, keyed the same
# way Maps and Friends key them. Empty means the default destination, which
# keeps aircraft saved before routes existed flying somewhere sensible.
var destination: String = ""
# How long this aircraft holds on the pad before its takeoff run, when a whole
# airport is dispatched at once. The SAME value is added to its flight time, so
# what you see and what the clock does agree: it leaves late and lands late by
# exactly as much. Transient - not saved, and cleared once consumed.
var launch_delay: float = 0.0
# Dispatched by "Run all" rather than tapped off its pad one at a time.
#
# A runway departure holds the strip for about 4.2s, so a bulk dispatch of a full
# airport is four minutes of aircraft idling in a queue - correct by the runway's
# own rules and useless to watch. Bulk departures leave from the pad instead.
#
# Consumed by ApronLayer the moment the animation is chosen, like launch_delay,
# so it never outlives the batch that set it.
var bulk_departure := false
var livery: String = ""
var owned_liveries: Dictionary = {}
var state: int = State.PARKED
var flight_time_left: float = 0.0
# What flight_time_left STARTED at, so a countdown can show how far along the
# leg is. Derived it at first and it drifted: the bulk-dispatch stagger is added
# to flight_time_left after the fact (Fleet.BULK_LAUNCH_STAGGER), so recomputing
# the leg length understates the total and the bar starts part-full.
var flight_time_total: float = 0.0


func _init(p_id: int, p_model_key: String) -> void:
	id = p_id
	model_key = p_model_key


func is_idle() -> bool:
	return assigned_apron_id == -1


# Sitting at the robot airport, waiting to be collected. Distinct from being in
# transit: these are the states where the aircraft physically renders there.
func is_at_robot() -> bool:
	return state == State.AWAITING_DEST_CLAIM or state == State.AWAITING_DEST_REFUEL


# In the air, so it renders at neither airport.
func is_in_transit() -> bool:
	return state == State.FLYING_OUT or state == State.FLYING_BACK
