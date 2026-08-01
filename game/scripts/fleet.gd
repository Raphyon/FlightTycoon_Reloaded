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
	# Real sheet art (tools/sheet_derive.py). This was previously a TRIAL
	# reconstruction from the shop icon - a hue-separated shadow and a rotor
	# blur built by rotate-accumulating the blade tips - because no world art
	# existed. The sheet turned up, so all of that is gone and so is the
	# stand-in's wrong proportions.
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
	# Real sheet art (tools/sheet_derive.py), not the old shop-icon derivation.
	# Three liveries on the sheet; body_green/body_purple are cut and waiting on
	# a skin system. The default matches the shop icon, which is the livery
	# carrying the original developer's brand name on the hull - the one to
	# replace first if this ever goes public.
	"airship": {
		"body": "res://assets/aircraft/airship/body_2x.png",
		"shadow": "res://assets/aircraft/airship/shadow_2x.png",
		"vtol": true,
	},
	# Real sheet art. The sheet is body-only, so the ground shadow is
	# synthesised from its silhouette, and it keeps the V-22's downwash rings
	# (rescaled to its hull) since it has no thruster art of its own.
	"ark": {
		"body": "res://assets/aircraft/ark/body_2x.png",
		"shadow": "res://assets/aircraft/ark/shadow_2x.png",
		"vtol": true,
		"ground_effect_frames": [
			"res://assets/aircraft/ark/downwash_a_2x.png",
			"res://assets/aircraft/ark/downwash_b_2x.png",
		],
	},
	# Real sheet art, and the one model whose whole hull changes on takeoff
	# rather than a rotor: body_spin is the same hull with all six thrusters
	# firing. Both frames are padded to a common canvas with the hull on the
	# same spot, so the swap doesn't shift it (see sheet_derive.align_into).
	#
	# No ground_effect_frames on purpose - it used to borrow the V-22's
	# downwash rings because it had no thruster art. It has its own now, and
	# layering a helicopter's rotor wash under a thruster craft was always the
	# stand-in rather than the intent.
	#
	# body_stone / body_stone_spin are the second livery, cut and waiting on a
	# skin system.
	"ufo": {
		"body": "res://assets/aircraft/ufo/body_2x.png",
		"body_spin": "res://assets/aircraft/ufo/body_spin_2x.png",
		"shadow": "res://assets/aircraft/ufo/shadow_2x.png",
		"vtol": true,
	},
}

# Route economy. What a leg is worth is the aircraft's business now, not a
# flat number: see ShopCatalog for the per-model stats and how they were set.
#
#   payout  = capacity * fare   (distance is time, not money)
#   fuel    = the model's own burn, charged to depart and to refuel at home;
#             the destination refuel stays free (matches the described loop).
#
# Both legs pay the same, so a round trip is worth twice the figure above.
const DESTINATION_NAME := "Robot"

# XP tracks what the leg was worth, so a 700-seat A380 doesn't hand out the
# same XP the 50-seat starter did. One XP per this much earned.
#
# 25, giving 16 XP a leg for the starter against the live game's 5. Solved
# from the pacing target, not the record: level 10 by the time Zone1 is full
# needs roughly three times the live XP rate, because our Zone1 fills in a
# quarter of an hour rather than over an evening.
const MONEY_PER_XP := 25


func xp_for_claim(model_key: String) -> int:
	return maxi(1, roundi(float(payout_for(model_key)) / MONEY_PER_XP))

# A leg pays capacity * fare. Distance does NOT come into it - a further
# destination costs you time, not money.
#
# The fare is a flat 10 for anything with a normal cabin, so the 50-seat 328
# Jet earns 500 a leg and 1000 for the round trip it flies out and back.
# Aircraft that carry almost nobody override it (ShopCatalog "ticket"), which
# is the only way a 2-seat P-51 can be worth owning - the reference does the
# same, charging 2000 a head on an F-15 and 200 on a balloon.
# 8. The live game pays 200 a leg for a 50-seat 328 Jet, i.e. a fare of 4 -
# but that pace can't fill Zone1 in fifteen minutes, which is the opening this
# game wants. Doubled deliberately, and the aircraft ladder is repriced to
# match. Fuel, flight time and the level curve are still the live values.
const TICKET_PRICE := 8


func ticket_price(model_key: String) -> int:
	return int(ShopCatalog.entry_for(model_key).get("ticket", TICKET_PRICE))

# Flight time multiplier per force grade, best to worst. S is the top class -
# an S-class aircraft flies a cloud in the flat SECONDS_PER_DISTANCE, and
# every grade below it takes proportionally longer, up to 3x for an E.
const SPEED_FACTOR := {"S": 1.0, "A": 1.25, "B": 1.5, "C": 2.0, "D": 2.5, "E": 3.0}
# Worst to best. A livery moves an aircraft one place along it.
const GRADE_LADDER := ["E", "D", "C", "B", "A", "S"]


# The grade this particular aircraft flies at: its model's, moved one step up
# if it's wearing a livery. S is the top - nothing to gain, and no livery is
# offered for an S-class model.
func grade_for(a: FleetAircraft) -> String:
	var base := str(ShopCatalog.stat(a.model_key, "force"))
	if a.livery.is_empty():
		return base
	var i := GRADE_LADDER.find(base)
	if i == -1 or i >= GRADE_LADDER.size() - 1:
		return base
	return GRADE_LADDER[i + 1]


# Flight time for a specific aircraft, livery included. flight_seconds_to()
# below is the model-level estimate the shop and routes table use, where there
# is no particular aircraft to ask about.
func flight_seconds_for(a: FleetAircraft, map_key: String) -> float:
	var base := SECONDS_PER_DISTANCE * maxf(1.0, float(Maps.entry(map_key).get("distance", 1)))
	return base * float(SPEED_FACTOR.get(grade_for(a), 1.0))


# How many passengers a leg carries: all of them.
func passengers(model_key: String) -> int:
	return int(ShopCatalog.stat(model_key, "seats"))


func fuel_cost(model_key: String) -> int:
	return int(ShopCatalog.stat(model_key, "fuel"))


# What one leg pays, wherever it goes. map_key is accepted and ignored so the
# call sites read the same as the flight-time ones.
func payout_for(model_key: String, _map_key: String = "") -> int:
	return passengers(model_key) * ticket_price(model_key)


func in_range(model_key: String, map_key: String) -> bool:
	return int(ShopCatalog.stat(model_key, "range")) >= distance_to(map_key)


# Seconds of flight per cloud of distance, for an S-class aircraft - so the
# S-class 328 Jet reaches a 1-cloud destination in exactly one minute, and
# slower grades take their SPEED_FACTOR multiple of that. Distance is the
# destination's own property (Maps "distance", drawn as cloud icons on the
# visitor panel), so a further airport is a longer trip without touching this.
#
# This is the only thing distance changes: it costs time, never money.
const SECONDS_PER_DISTANCE := 60.0

var aircraft: Array[FleetAircraft] = []
var _next_id := 1
# Bulk operations (advance_all) touch every aircraft and would otherwise fire
# fleet_changed once per action per aircraft - and ApronEditor rebuilds every
# apron slot and world sprite on that signal. With 110 aircraft that was
# hundreds of full rebuilds of 220 nodes in one press, which exhausted Godot's
# 32MB deferred-call queue outright. One signal at the end instead.
var _batching := false
var _changed_while_batching := false


func _emit_changed() -> void:
	if _batching:
		_changed_while_batching = true
		return
	fleet_changed.emit()


func _ready() -> void:
	# Starting plane - always aircraft id 1, parked at Zone1's apron id 1
	# (the historical "home" spot). Nothing else assumes id 1 specifically;
	# this is just the one starting fact of a fresh game.
	var starter := FleetAircraft.new(_next_id, "328jet")
	_next_id += 1
	starter.assigned_apron_id = 1
	aircraft.append(starter)


func _process(delta: float) -> void:
	if _advance_flights(delta):
		_emit_changed()


# Ticks every in-flight aircraft forward and lands the ones that arrive.
# Returns whether anything changed. Shared with the save loader, which calls it
# once with however long the game was closed - so the two can never disagree
# about what "arriving" means.
func _advance_flights(delta: float) -> bool:
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
	return changed


func to_save() -> Dictionary:
	var out := []
	for a in aircraft:
		out.append({
			"id": a.id, "model": a.model_key, "apron": a.assigned_apron_id,
			"robot_apron": a.robot_apron_id, "state": a.state,
			"left": a.flight_time_left,
			"livery": a.livery, "owned_liveries": a.owned_liveries.keys(),
			"destination": a.destination,
		})
	return {"aircraft": out, "next_id": _next_id}


# `elapsed` is real seconds since the save was written. Flights carry on while
# the game is shut: coming back to an aircraft still frozen 20 seconds from
# home would read as a bug, not as a rule. Rewards are NOT collected for you -
# aircraft only advance as far as the awaiting-claim states, so time passing
# saves you the wait but never earns you anything unattended.
func load_save(data: Dictionary, elapsed: float) -> void:
	aircraft.clear()
	for d in data.get("aircraft", []):
		var a := FleetAircraft.new(int(d.get("id", 0)), str(d.get("model", "328jet")))
		a.assigned_apron_id = int(d.get("apron", -1))
		a.robot_apron_id = int(d.get("robot_apron", -1))
		a.state = int(d.get("state", FleetAircraft.State.PARKED))
		a.flight_time_left = float(d.get("left", 0.0))
		a.livery = str(d.get("livery", ""))
		a.destination = str(d.get("destination", ""))
		for key in d.get("owned_liveries", []):
			a.owned_liveries[str(key)] = true
		aircraft.append(a)
	_next_id = int(data.get("next_id", aircraft.size() + 1))
	if elapsed > 0.0:
		_advance_flights(elapsed)
	_emit_changed()


# Exotics are sold for coins rather than cash (see ShopCatalog), so which
# wallet to charge is the catalog entry's business, not the caller's.
func buy(model_key: String, price: int, currency: String = ShopCatalog.CASH) -> bool:
	# Gated on pilot level as well as money - checked here rather than only on
	# the shop button, so nothing can buy past the gate.
	if not ShopCatalog.unlocked(model_key):
		return false
	var paid := Coins.spend(price) if currency == ShopCatalog.COINS else Economy.spend_money(price)
	if not paid:
		return false
	aircraft.append(FleetAircraft.new(_next_id, model_key))
	_next_id += 1
	_emit_changed()
	return true


# What an aircraft fetches back. Half of what it cost, rounded - enough that
# replacing a hangar full of starters with something better is worth doing,
# not so much that churning aircraft is free.
const RESALE_FRACTION := 0.5


func sell_value(model_key: String) -> int:
	var entry := ShopCatalog.entry_for(model_key)
	if ShopCatalog.currency_of(entry) == ShopCatalog.COINS:
		return 0
	return int(round(int(entry.get("price", 0)) * RESALE_FRACTION))


# Coin-bought aircraft are never sellable: they cost real money, so turning
# them back into cash would be a laundering route out of the premium currency.
# Nor is anything mid-route - it isn't yours to scrap while it's in the air or
# sitting at someone else's airport.
func can_sell(a: FleetAircraft) -> bool:
	if not a:
		return false
	if ShopCatalog.currency_of(ShopCatalog.entry_for(a.model_key)) == ShopCatalog.COINS:
		return false
	return a.state == FleetAircraft.State.PARKED or a.is_idle()


func sell(aircraft_id: int) -> bool:
	var a := get_aircraft(aircraft_id)
	if not can_sell(a):
		return false
	Economy.add_money(sell_value(a.model_key))
	aircraft.erase(a)
	_emit_changed()
	return true


# Sells one idle aircraft of this model - what the hangar offers, since it
# groups by type rather than listing individuals.
func sell_one_idle(model_key: String) -> bool:
	for a in aircraft:
		if a.model_key == model_key and a.is_idle() and can_sell(a):
			return sell(a.id)
	return false


func idle_count(model_key: String) -> int:
	var n := 0
	for a in aircraft:
		if a.model_key == model_key and a.is_idle():
			n += 1
	return n


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
		_emit_changed()


func unassign(aircraft_id: int) -> void:
	var a := get_aircraft(aircraft_id)
	# Only makes sense to pull a parked aircraft back to the hangar - one
	# mid-route would just vanish from the apron it's supposedly flying
	# to/from.
	if a and a.state == FleetAircraft.State.PARKED:
		a.assigned_apron_id = -1
		_emit_changed()


# How long a one-way leg to this destination takes. Clamped at 1 so a map that
# forgets to declare a distance still flies rather than arriving instantly.
# model_key is optional so callers that only want the destination's baseline
# (the routes table's estimate, tests) don't have to name an aircraft.
func flight_seconds_to(map_key: String, model_key: String = "") -> float:
	var base := SECONDS_PER_DISTANCE * maxf(1.0, float(Maps.entry(map_key).get("distance", 1)))
	if model_key == "":
		return base
	var grade: String = ShopCatalog.stat(model_key, "force")
	return base * float(SPEED_FACTOR.get(grade, 1.0))


func distance_to(map_key: String) -> int:
	return maxi(1, int(Maps.entry(map_key).get("distance", 1)))


func fuel_and_depart(aircraft_id: int) -> bool:
	var a := get_aircraft(aircraft_id)
	if not a or a.state != FleetAircraft.State.PARKED:
		return false
	# Claim the landing pad before spending anything: with the robot airport
	# full there is nowhere to land, and taking the fuel first would charge for
	# a trip that can't happen.
	var pad := robot_apron_for(a)
	if pad == -1:
		return false
	# Range is a real gate, not a number on a card: a short-legged aircraft
	# can't reach a distant airport at all. Checked before the fuel is spent,
	# same as the pad.
	if not in_range(a.model_key, destination_of(a)):
		return false
	if not FuelStore.consume(fuel_cost(a.model_key)):
		return false
	a.robot_apron_id = pad
	a.state = FleetAircraft.State.FLYING_OUT
	a.flight_time_left = flight_seconds_for(a, destination_of(a))
	_emit_changed()
	return true


func claim_destination_reward(aircraft_id: int) -> void:
	var a := get_aircraft(aircraft_id)
	if a and a.state == FleetAircraft.State.AWAITING_DEST_CLAIM:
		_grant_reward(payout_for(a.model_key), a.assigned_apron_id, a.model_key)
		AircraftAffinity.grant_use(a.model_key)
		a.state = FleetAircraft.State.AWAITING_DEST_REFUEL
		_emit_changed()


func refuel_at_destination(aircraft_id: int) -> void:
	# Free, per the loop - the destination supplies fuel for the return leg.
	var a := get_aircraft(aircraft_id)
	if a and a.state == FleetAircraft.State.AWAITING_DEST_REFUEL:
		# Releasing the pad here, not on touchdown at home: the aircraft has
		# physically left the robot airport, so holding its slot for the whole
		# return leg would halve the airport's usable capacity.
		a.robot_apron_id = -1
		a.state = FleetAircraft.State.FLYING_BACK
		a.flight_time_left = flight_seconds_for(a, destination_of(a))
		_emit_changed()


func claim_home_reward(aircraft_id: int) -> void:
	var a := get_aircraft(aircraft_id)
	if a and a.state == FleetAircraft.State.AWAITING_HOME_CLAIM:
		_grant_reward(payout_for(a.model_key), a.assigned_apron_id, a.model_key)
		AircraftAffinity.grant_use(a.model_key)
		a.state = FleetAircraft.State.AWAITING_HOME_REFUEL
		_emit_changed()


# Apron skins (see ApronSkins) give a flat bonus to both the cash and XP
# reward for whichever apron the aircraft is parked at.
func _grant_reward(base_amount: int, apron_id: int, model_key: String) -> void:
	var bonus := 1.0 + ApronSkins.bonus_percent_for(apron_id) / 100.0
	Economy.add_money(roundi(base_amount * bonus))
	Progression.add_xp(roundi(xp_for_claim(model_key) * bonus))


func refuel_at_home(aircraft_id: int) -> bool:
	var a := get_aircraft(aircraft_id)
	if not a or a.state != FleetAircraft.State.AWAITING_HOME_REFUEL:
		return false
	if not FuelStore.consume(fuel_cost(a.model_key)):
		return false
	a.state = FleetAircraft.State.PARKED
	_emit_changed()
	return true


# Where this aircraft is routed. Falls back to the robot so an aircraft from a
# save written before destinations existed still has somewhere to go.
func destination_of(a: FleetAircraft) -> String:
	return a.destination if a.destination != "" else Maps.ROBOT_MAP


# Whether there is anything to do for this aircraft right now. False while
# it's in the air - that's a wait, not a decision.
func has_pending_action(a: FleetAircraft) -> bool:
	return not (a.state == FleetAircraft.State.FLYING_OUT
		or a.state == FleetAircraft.State.FLYING_BACK)


# Why this aircraft can't move, in words a player can act on. Empty when it
# can. "Stuck" on its own tells you something is wrong but not what to do
# about it - and the four causes want four different responses.
func block_reason(a: FleetAircraft) -> String:
	match a.state:
		FleetAircraft.State.PARKED:
			if not in_range(a.model_key, destination_of(a)):
				return "out of range"
			if robot_apron_for(a) == -1:
				return "no pad at %s" % DESTINATION_NAME
			if FuelStore.amount < fuel_cost(a.model_key):
				return "needs %d fuel" % fuel_cost(a.model_key)
		FleetAircraft.State.AWAITING_HOME_REFUEL:
			if FuelStore.amount < fuel_cost(a.model_key):
				return "needs %d fuel" % fuel_cost(a.model_key)
	return ""


# One step of whatever this aircraft needs next. The state machine lives here
# rather than in the routes table, because two callers drive it now: the
# per-row button and the bulk one.
#
# Returns whether anything actually happened. False means it's flying, or it's
# blocked - out of fuel, out of range, or the destination has no free pad.
func advance(aircraft_id: int) -> bool:
	var a := get_aircraft(aircraft_id)
	if not a:
		return false
	var before := a.state
	match a.state:
		FleetAircraft.State.PARKED:
			fuel_and_depart(a.id)
		FleetAircraft.State.AWAITING_DEST_CLAIM:
			claim_destination_reward(a.id)
		FleetAircraft.State.AWAITING_DEST_REFUEL:
			refuel_at_destination(a.id)
		FleetAircraft.State.AWAITING_HOME_CLAIM:
			claim_home_reward(a.id)
		FleetAircraft.State.AWAITING_HOME_REFUEL:
			refuel_at_home(a.id)
	return a.state != before


# A full round trip is five separate actions per aircraft - depart, collect,
# send home, collect, refuel - so a fleet of five costs twenty-five presses to
# go round once. This runs every aircraft as far forward as it will go in one
# press: collect what has landed, send it home, refuel it and put it back in
# the air.
#
# Six steps is one full lap plus slack; the loop ends on its own as soon as an
# aircraft reaches a flying state or an action refuses.
const MAX_ADVANCE_STEPS := 6

# Dispatching a full airport sends every aircraft on one tick: 110 takeoff
# animations on a single frame, and - since they share a model and destination
# - 110 landings resolving on a single tick later too.
#
# One value fixes both. Each aircraft in a bulk dispatch gets a small holding
# delay, added BOTH to its flight time and to when its takeoff plays, so it
# behaves exactly as though it had departed that much later. Applied only in
# bulk; a single departure is untouched.
#
# The step SHRINKS as the batch grows, so the whole fleet always fits inside
# the window. A flat step with a cap bunched everything past the ceiling back
# onto one tick - 110 aircraft gave 41 distinct times and a 70-plane pile-up
# at the end, which is the problem this exists to solve.
const BULK_LAUNCH_STAGGER := 0.15
const BULK_LAUNCH_WINDOW := 6.0


func advance_all() -> Dictionary:
	_batching = true
	_changed_while_batching = false
	# How many could leave this pass - sets the spacing before any of them do.
	var launching := 0
	for a in aircraft:
		if not a.is_idle() and a.state == FleetAircraft.State.PARKED:
			launching += 1
	var step := BULK_LAUNCH_STAGGER
	if launching > 1:
		step = minf(BULK_LAUNCH_STAGGER, BULK_LAUNCH_WINDOW / float(launching - 1))
	var money_before := Economy.money
	var fuel_before := FuelStore.amount
	var moved := 0
	var departed := 0
	var blocked := 0
	var reasons := {}
	for a in aircraft:
		if a.is_idle():
			continue
		var steps := 0
		while steps < MAX_ADVANCE_STEPS and advance(a.id):
			steps += 1
		if steps > 0:
			moved += 1
			if a.state == FleetAircraft.State.FLYING_OUT:
				a.launch_delay = departed * step
				a.flight_time_left += a.launch_delay
				departed += 1
		# Stuck is measured AFTER the pass, not before: an aircraft that
		# collected its reward and then couldn't afford the fuel to leave has
		# moved AND is still waiting on you. Counting only the ones that did
		# nothing reported "0 stuck" with the whole fleet grounded.
		if has_pending_action(a):
			blocked += 1
			var why := block_reason(a)
			if why != "":
				reasons[why] = int(reasons.get(why, 0)) + 1
	_batching = false
	if _changed_while_batching:
		fleet_changed.emit()
	return {
		"moved": moved,
		"departed": departed,
		"blocked": blocked,
		"reasons": reasons,
		"earned": Economy.money - money_before,
		"fuel_spent": fuel_before - FuelStore.amount,
	}


# How many in-service aircraft are waiting on you.
func pending_count() -> int:
	var n := 0
	for a in aircraft:
		if not a.is_idle() and has_pending_action(a):
			n += 1
	return n


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


# Whoever is sitting on this robot pad right now. Only counts aircraft actually
# there, not ones still inbound - an inbound plane holds the pad (so nothing
# else is sent to it) but there's nothing to draw or click on yet.
func get_aircraft_at_robot_apron(apron_id: int) -> FleetAircraft:
	for a in aircraft:
		if a.robot_apron_id == apron_id and a.is_at_robot():
			return a
	return null


# Every pad at the robot airport, in id order.
# Every pad at the robot, across all seven mirrored areas, in id order.
func robot_apron_ids() -> Array:
	var starts: Dictionary = ApronLayout.compute_id_starts()
	var data: Dictionary = ApronLayout.load_area_data(Maps.ROBOT_MAP)
	var ids: Array = []
	for area in Maps.ROBOT_AREAS:
		if not starts.has(area):
			continue
		var start: int = starts[area]
		for i in range((data.get(area, []) as Array).size()):
			ids.append(start + i)
	return ids


# The destination pad for an aircraft: the SAME one it flies from.
#
# The robot's airport mirrors homeland pad for pad, so apron 14 at home has a
# counterpart there, and a route occupies both ends. That's what the live game
# does - a real route record carries startApron and endApron both reading
# airport001_area001_apron0014, for two different users - and it means capacity
# cannot run out: you can't have more aircraft in the air than you have aprons,
# and each one's slot is reserved by definition.
#
# This replaced claiming the first unclaimed pad from a pool of twenty, which
# quietly capped the whole game at twenty aircraft - past that, dispatching
# just refused.
func robot_apron_for(a: FleetAircraft) -> int:
	if a.assigned_apron_id < 1:
		return -1
	var ids := robot_apron_ids()
	# Homeland is the first map, so its aprons are ids 1..n and the index of
	# this one is simply id - 1.
	var offset: int = a.assigned_apron_id - 1
	return ids[offset] if offset < ids.size() else -1


# RETIRED. With 1:1 apron mapping there is no pool to allocate from and no
# "full" state - see robot_apron_for. Kept as a thin shim so any caller that
# still asks gets a sensible answer rather than an error.
func free_robot_apron() -> int:
	var ids := robot_apron_ids()
	return ids[0] if ids.size() > 0 else -1
