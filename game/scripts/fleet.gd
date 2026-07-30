extends Node

signal fleet_changed

# Model keys disagree between the shop icons and the ingested world sprites
# (shop calls it "p51", the world sprite folder is "p-51mustang" - a known
# mismatch flagged since the very first README). Resolved here, in one
# place, rather than papering over it everywhere that needs a world sprite.
const WORLD_SPRITES := {
	"328jet": {
		"body": "res://assets/aircraft/328jet/body_2x.png",
		"shadow": "res://assets/aircraft/328jet/shadow_2x.png",
	},
	"p51": {
		"body": "res://assets/aircraft/p-51mustang/body_2x.png",
		"shadow": "res://assets/aircraft/p-51mustang/shadow_2x.png",
		# Single nose prop - no distinct stationary art exists for this one
		# (both extracted frames already look like motion blur), so it stays
		# hidden while parked and only shows the spin flipbook while taking
		# off. Hub offset is placed by hand with RotorEditor (press R
		# in-game) - see WorldAircraft._add_rotors.
		"rotor_spin_frames": [
			"res://assets/aircraft/p-51mustang/prop_a_2x.png",
			"res://assets/aircraft/p-51mustang/prop_b_2x.png",
		],
		"rotor_offsets": [Vector2.ZERO],
	},
	"a400m": {
		"body": "res://assets/aircraft/a400m/body_2x.png",
		"shadow": "res://assets/aircraft/a400m/shadow_2x.png",
		# Four turboprops, and unlike the V-22 there's no separate stationary
		# disc: the static props are painted into the body art, so parked
		# needs no overlay at all and only the spin flipbook is layered on
		# during takeoff. Same arrangement as the P-51.
		#
		# Four frames rather than the usual two - the source strip carries a
		# full rotation cycle. They're split hub-aligned (see
		# tools/plane_derive.py split_prop_strip) so the disc spins about a
		# fixed point instead of wandering between frames.
		"rotor_spin_frames": [
			"res://assets/aircraft/a400m/prop_a_2x.png",
			"res://assets/aircraft/a400m/prop_b_2x.png",
			"res://assets/aircraft/a400m/prop_c_2x.png",
			"res://assets/aircraft/a400m/prop_d_2x.png",
		],
		# STARTING POINTS ONLY - place these properly with RotorEditor (press
		# R in-game, M to reach a400m, 1-4 to pick a hub, click to set). These
		# came from clustering the yellow prop tips painted into the body, but
		# three of the four props are partly occluded by the fuselage and wing
		# and the whole signal is only ~55 px, so they land near the right
		# engines rather than on the hubs.
		"rotor_offsets": [
			Vector2(-62, 2), Vector2(-20, 27), Vector2(-1, 39), Vector2(10, 36),
		],
		# Hub 2 (index 1) is the inboard prop on the far wing, which the hull
		# partly covers at this isometric angle - drawn on top, its blur disc
		# reads as floating in front of the aircraft. Only the default: press B
		# in RotorEditor to change it per hub, and the rig file wins once set.
		"rotor_behind_body": [1],
	},
	"v22": {
		"body": "res://assets/aircraft/v22/body_2x.png",
		"shadow": "res://assets/aircraft/v22/shadow_2x.png",
		# Vertical-lift - takes off straight up from the apron instead of
		# taxiing/flying the traced runway track (see
		# WorldAircraft._play_vertical_liftoff). Same will apply to
		# helicopters and UFOs once they're added.
		"vtol": true,
		# Tiltrotor - two rotor mounts. Two alternate states, not layered:
		# a stationary blur disc while parked, swapped for a 2-frame glow
		# flipbook while taking off. Offsets are the wingtip rotor hubs,
		# placed by hand with RotorEditor (press R in-game) - see
		# WorldAircraft._add_rotors.
		"rotor_idle_frames": ["res://assets/aircraft/v22/rotor_blur_2x.png"],
		"rotor_spin_frames": [
			"res://assets/aircraft/v22/rotor_glow_a_2x.png",
			"res://assets/aircraft/v22/rotor_glow_b_2x.png",
		],
		# Rotor downwash kicked up off the pad - an alternating 2-frame ring
		# on the ground, only while hovering low during a vertical takeoff
		# or landing (see WorldAircraft._play_vertical_liftoff/_landing).
		"ground_effect_frames": [
			"res://assets/aircraft/v22/downwash_a_2x.png",
			"res://assets/aircraft/v22/downwash_b_2x.png",
		],
		"rotor_offsets": [Vector2(-48.5, 28.5), Vector2(27.5, -34.5)],
	},
	# ------------------------------------------------------------------
	# TRIAL: derived Black Hawk, no original world art exists for it. The
	# body is the shop icon (shop icons turn out to be the same render at
	# the same iso angle as world bodies - compare p51_white.png against
	# p-51mustang/body_2x.png), and the shadow is generated from that
	# body's own silhouette the way the other shadows are built (flat
	# black, ~80% height). Nothing here is invented art.
	#
	# The spin frames are the helicopter's own blade tips, rotate-accumulated
	# around the hub where their axes converge (un-squashed to a circle
	# first, since the disc is an ellipse in iso view). They overlay the
	# body rather than replacing it, so the blades drawn into the icon stay
	# put as the parked pose - that avoids having to invent fuselage pixels
	# where the blades cross it. There are no rotor_idle_frames for the
	# same reason: the idle state is already painted on.
	#
	# To drop the whole trial: delete assets/aircraft/blackh/, delete this
	# entry, drop "blackh" from RotorEditor.MODEL_KEYS, and set its
	# has_world_sprite back to false in ShopCatalog.
	# ------------------------------------------------------------------
	"blackh": {
		"body": "res://assets/aircraft/blackh/body_2x.png",
		"shadow": "res://assets/aircraft/blackh/shadow_2x.png",
		# Second shadow with the main rotor blades left out, swapped in while
		# the rotor is spinning - a stopped rotor's blades cast a visible
		# 6-blade star, a blurred disc doesn't. See _show_spin_rotors.
		"shadow_spin": "res://assets/aircraft/blackh/shadow_spin_2x.png",
		"vtol": true,
		# Two hubs with *different* art - the main rotor and the tail rotor are
		# separate sprites, not the same disc twice. That's what "rotors" is
		# for: one entry per hub, parallel to rotor_offsets. Hub 1 is the main
		# rotor, hub 2 the tail. Neither is painted into the body art, so the
		# idle frames are what you see while parked.
		"rotors": [
			{
				"idle": ["res://assets/aircraft/blackh/rotor_idle_2x.png"],
				"spin": [
					"res://assets/aircraft/blackh/rotor_spin_a_2x.png",
					"res://assets/aircraft/blackh/rotor_spin_b_2x.png",
				],
			},
			{
				"idle": ["res://assets/aircraft/blackh/tail_idle_2x.png"],
				"spin": [
					"res://assets/aircraft/blackh/tail_spin_a_2x.png",
					"res://assets/aircraft/blackh/tail_spin_b_2x.png",
				],
			},
		],
		# Both hubs need placing with RotorEditor (press R, M to reach blackh,
		# 1 = main rotor, 2 = tail rotor). The main-rotor value is carried over
		# from the old derived sprite and is only roughly right for this art;
		# the tail figure is a placeholder at the far end of the boom.
		"rotor_offsets": [Vector2(5.9, -15.5), Vector2(48, -8)],
		"ground_effect_frames": [
			"res://assets/aircraft/blackh/downwash_a_2x.png",
			"res://assets/aircraft/blackh/downwash_b_2x.png",
		],
	},
	# ------------------------------------------------------------------
	# The jet fleet, derived by tools/plane_derive.py: body is the shop
	# icon with its baked-in cast shadow lifted out, ground shadow is that
	# airframe's own silhouette. Conventional aircraft - no rotors, no
	# vtol, so they queue for the runway like the 328jet and P-51 do.
	# Re-run the tool to regenerate; delete a folder + its entry here +
	# flip has_world_sprite in ShopCatalog to drop one.
	# ------------------------------------------------------------------
	"747": {
		"body": "res://assets/aircraft/747/body_2x.png",
		"shadow": "res://assets/aircraft/747/shadow_2x.png",
	},
	"a300": {
		"body": "res://assets/aircraft/a300/body_2x.png",
		"shadow": "res://assets/aircraft/a300/shadow_2x.png",
	},
	"a318": {
		"body": "res://assets/aircraft/a318/body_2x.png",
		"shadow": "res://assets/aircraft/a318/shadow_2x.png",
	},
	"a319": {
		"body": "res://assets/aircraft/a319/body_2x.png",
		"shadow": "res://assets/aircraft/a319/shadow_2x.png",
	},
	"a380-300": {
		"body": "res://assets/aircraft/a380-300/body_2x.png",
		"shadow": "res://assets/aircraft/a380-300/shadow_2x.png",
	},
	"an-225": {
		"body": "res://assets/aircraft/an-225/body_2x.png",
		"shadow": "res://assets/aircraft/an-225/shadow_2x.png",
	},
	# ------------------------------------------------------------------
	# The oddities - same derivation as the jets above, but they lift
	# straight off the apron instead of taking the runway. The Ark and UFO
	# ride thrusters, so they kick up the downwash rings (rescaled to their
	# much bigger hulls by tools/plane_derive.py); the airship floats on
	# buoyancy and blows nothing at the ground.
	# ------------------------------------------------------------------
	"airship": {
		"body": "res://assets/aircraft/airship/body_2x.png",
		"shadow": "res://assets/aircraft/airship/shadow_2x.png",
		"vtol": true,
	},
	"ark": {
		"body": "res://assets/aircraft/ark/body_2x.png",
		"shadow": "res://assets/aircraft/ark/shadow_2x.png",
		"vtol": true,
		"ground_effect_frames": [
			"res://assets/aircraft/ark/downwash_a_2x.png",
			"res://assets/aircraft/ark/downwash_b_2x.png",
		],
	},
	"ufo": {
		"body": "res://assets/aircraft/ufo/body_2x.png",
		"shadow": "res://assets/aircraft/ufo/shadow_2x.png",
		"vtol": true,
		"ground_effect_frames": [
			"res://assets/aircraft/ufo/downwash_a_2x.png",
			"res://assets/aircraft/ufo/downwash_b_2x.png",
		],
	},
}

# Placeholder route economy - not real game balance data, just enough to
# make the loop testable. Same trip cost to depart and to refuel at home;
# the destination refuel is free (matches the described loop).
const DESTINATION_NAME := "Robot"
const FUEL_PER_TRIP := 5
const REWARD_AT_DESTINATION := 150
const REWARD_AT_HOME := 150
const XP_PER_CLAIM := 20
const FLIGHT_DURATION := 12.0  # seconds - short on purpose so it's testable

var aircraft: Array[FleetAircraft] = []
var _next_id := 1


func _ready() -> void:
	# Starting plane - always aircraft id 1, parked at Zone1's apron id 1
	# (the historical "home" spot). Nothing else assumes id 1 specifically;
	# this is just the one starting fact of a fresh game.
	var starter := FleetAircraft.new(_next_id, "328jet")
	_next_id += 1
	starter.assigned_apron_id = 1
	aircraft.append(starter)


func _process(delta: float) -> void:
	var changed := false
	for a in aircraft:
		if a.state == FleetAircraft.State.FLYING_OUT or a.state == FleetAircraft.State.FLYING_BACK:
			a.flight_time_left = maxf(0.0, a.flight_time_left - delta)
			if a.flight_time_left == 0.0:
				a.state = (
					FleetAircraft.State.AWAITING_DEST_CLAIM
					if a.state == FleetAircraft.State.FLYING_OUT
					else FleetAircraft.State.AWAITING_HOME_CLAIM
				)
				changed = true
	if changed:
		fleet_changed.emit()


func buy(model_key: String, price: int) -> bool:
	if not Economy.spend_money(price):
		return false
	aircraft.append(FleetAircraft.new(_next_id, model_key))
	_next_id += 1
	fleet_changed.emit()
	return true


func count(model_key: String) -> int:
	var n := 0
	for a in aircraft:
		if a.model_key == model_key:
			n += 1
	return n


func idle_aircraft() -> Array[FleetAircraft]:
	return aircraft.filter(func(a: FleetAircraft) -> bool: return a.is_idle())


func assign_to_apron(aircraft_id: int, apron_id: int) -> void:
	var a := get_aircraft(aircraft_id)
	if a:
		a.assigned_apron_id = apron_id
		fleet_changed.emit()


func unassign(aircraft_id: int) -> void:
	var a := get_aircraft(aircraft_id)
	# Only makes sense to pull a parked aircraft back to the hangar - one
	# mid-route would just vanish from the apron it's supposedly flying
	# to/from.
	if a and a.state == FleetAircraft.State.PARKED:
		a.assigned_apron_id = -1
		fleet_changed.emit()


func fuel_and_depart(aircraft_id: int) -> bool:
	var a := get_aircraft(aircraft_id)
	if not a or a.state != FleetAircraft.State.PARKED:
		return false
	if not FuelStore.consume(FUEL_PER_TRIP):
		return false
	a.state = FleetAircraft.State.FLYING_OUT
	a.flight_time_left = FLIGHT_DURATION
	fleet_changed.emit()
	return true


func claim_destination_reward(aircraft_id: int) -> void:
	var a := get_aircraft(aircraft_id)
	if a and a.state == FleetAircraft.State.AWAITING_DEST_CLAIM:
		_grant_reward(REWARD_AT_DESTINATION, a.assigned_apron_id)
		AircraftAffinity.grant_use(a.model_key)
		a.state = FleetAircraft.State.AWAITING_DEST_REFUEL
		fleet_changed.emit()


func refuel_at_destination(aircraft_id: int) -> void:
	# Free, per the loop - the destination supplies fuel for the return leg.
	var a := get_aircraft(aircraft_id)
	if a and a.state == FleetAircraft.State.AWAITING_DEST_REFUEL:
		a.state = FleetAircraft.State.FLYING_BACK
		a.flight_time_left = FLIGHT_DURATION
		fleet_changed.emit()


func claim_home_reward(aircraft_id: int) -> void:
	var a := get_aircraft(aircraft_id)
	if a and a.state == FleetAircraft.State.AWAITING_HOME_CLAIM:
		_grant_reward(REWARD_AT_HOME, a.assigned_apron_id)
		AircraftAffinity.grant_use(a.model_key)
		a.state = FleetAircraft.State.AWAITING_HOME_REFUEL
		fleet_changed.emit()


# Apron skins (see ApronSkins) give a flat bonus to both the cash and XP
# reward for whichever apron the aircraft is parked at.
func _grant_reward(base_amount: int, apron_id: int) -> void:
	var bonus := 1.0 + ApronSkins.bonus_percent_for(apron_id) / 100.0
	Economy.add_money(roundi(base_amount * bonus))
	Progression.add_xp(roundi(XP_PER_CLAIM * bonus))


func refuel_at_home(aircraft_id: int) -> bool:
	var a := get_aircraft(aircraft_id)
	if not a or a.state != FleetAircraft.State.AWAITING_HOME_REFUEL:
		return false
	if not FuelStore.consume(FUEL_PER_TRIP):
		return false
	a.state = FleetAircraft.State.PARKED
	fleet_changed.emit()
	return true


func get_aircraft(aircraft_id: int) -> FleetAircraft:
	for a in aircraft:
		if a.id == aircraft_id:
			return a
	return null


func get_aircraft_at_apron(apron_id: int) -> FleetAircraft:
	for a in aircraft:
		if a.assigned_apron_id == apron_id:
			return a
	return null
