extends Node

signal fleet_changed
# EVENTS, not state. fleet_changed says "something moved"; these say what
# happened, which is what quest goals count. Nothing else could tell the
# difference between a flight landing and a flight departing.
signal flight_claimed(model_key: String, map_key: String, cash: int)
signal flight_departed(model_key: String, map_key: String)

# Model keys disagree between the shop icons and the ingested world sprites
# (shop calls it "p51", the world sprite folder is "p-51mustang" - a known
# mismatch flagged since the very first README). Resolved here, in one
# place, rather than papering over it everywhere that needs a world sprite.
# What a fresh game starts with, and the fallback for a save entry missing its
# model. Named because it's referenced in both places and used to be the string
# "328jet" written twice - which is exactly the sort of thing that gets changed
# in one spot when the starter moves. See ShopCatalog for why it's the DC-3.
const STARTER_MODEL := "dc3"

# The A400M's turboprop flipbook, shared by every propeller aircraft in the
# fleet. Split hub-aligned (tools/plane_derive.py split_prop_strip) so the disc
# spins about a fixed point rather than wandering between frames. Named here
# because four other models borrow it - see the propliner block below.
const A400M_PROP := [
	"res://assets/aircraft/a400m/prop_a_2x.png",
	"res://assets/aircraft/a400m/prop_b_2x.png",
	"res://assets/aircraft/a400m/prop_c_2x.png",
	"res://assets/aircraft/a400m/prop_d_2x.png",
]

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
		# full rotation cycle. See A400M_PROP above; the propliners borrow it.
		"rotor_spin_frames": A400M_PROP,
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
	# ------------------------------------------------------------------
	# The hand-made fleet (tools/newfleet_derive.py). Art made FOR this
	# project, so unlike the dump it carries no placeholder-only restriction.
	# It arrived clean and shadowless, so every ground shadow here is derived
	# from the airframe's own silhouette - the same recipe as the jets above.
	#
	# The four propliners (DC-3, DC-6, EMB-120, Dash 8) BORROW the A400M's
	# turboprop disc rather than waiting on prop art of their own. It fits
	# because the disc's shape is set by the viewing angle, not the engine:
	# every wing-mounted prop in this fleet is seen from the same isometric
	# angle, so the A400M's narrow 17x41 disc is the right silhouette for all
	# of them. Only the SIZE differs, which is what rotor_scale is for.
	#
	# The P-51's disc is the other one available and is deliberately not used
	# here - it's a nose prop seen head-on, so it's a much wider ellipse, and
	# none of these four has a nose prop.
	#
	# Like the A400M, their static props are painted into the body art, so
	# there's no idle overlay: parked shows the painted props and the spin
	# flipbook is layered on during takeoff.
	#
	# EVERY offset below is a STARTING POINT, evenly spaced along the wing line
	# the A400M's own placed hubs describe. They are not measured off the art -
	# place them with RotorEditor (R, then M to the model, 1-4 to pick a hub,
	# click to set, [ and ] to size).
	# ------------------------------------------------------------------
	"paperplane": {
		"body": "res://assets/aircraft/paperplane/body_2x.png",
		"shadow": "res://assets/aircraft/paperplane/shadow_2x.png",
	},
	# Floats up off the pad like the airship rather than taxiing - a balloon
	# queuing for a runway would be absurd.
	"balloon": {
		"body": "res://assets/aircraft/balloon/body_2x.png",
		"shadow": "res://assets/aircraft/balloon/shadow_2x.png",
		"vtol": true,
		# THE BASKET SITS ON THE PAD, not the envelope. Every other aircraft is
		# its own footprint, so centring the sprite puts the thing on the ground;
		# a balloon is 132px of envelope above a 14px basket, and centring parked
		# it with the canopy on the tarmac and the basket hanging through it.
		#
		# Measured off the art: the basket runs y 118-132, centre 125, against a
		# sprite centre of 66.
		"body_offset": Vector2(0, -59),
	},
	"dc3": {
		"body": "res://assets/aircraft/dc3/body_2x.png",
		"shadow": "res://assets/aircraft/dc3/shadow_2x.png",
		"rotor_spin_frames": A400M_PROP,
		"rotor_offsets": [Vector2(-40, 8), Vector2(-8, 26)],
		"rotor_scale": 0.88,
	},
	# THREE props, one of them on the NOSE. The P-51 already has a nose hub, so
	# that part is not new - what is new is a nose hub NEXT TO wing hubs, where
	# the fuselage can swallow it. If it disappears when placed, B puts it
	# behind. Same shape as the Ford Trimotor below.
	"ju52": {
		"body": "res://assets/aircraft/ju52/body_2x.png",
		"shadow": "res://assets/aircraft/ju52/shadow_2x.png",
		"rotor_spin_frames": A400M_PROP,
		# PLACEHOLDERS for RotorEditor - M to reach it, 1-3, click, -/+.
		"rotor_offsets": [Vector2(0, 0), Vector2(0, 0), Vector2(0, 0)],
		"rotor_scale": 0.85,
	},
	# ONE nose prop, like the P-51 - the smallest airframe in the game that is
	# not a paper aeroplane.
	"an2": {
		"body": "res://assets/aircraft/an2/body_2x.png",
		"shadow": "res://assets/aircraft/an2/shadow_2x.png",
		"rotor_spin_frames": A400M_PROP,
		# PLACEHOLDER for RotorEditor - M to reach it, 1, click, -/+.
		"rotor_offsets": [Vector2.ZERO],
		"rotor_scale": 0.80,
	},
	# THREE props with one on the nose, same as the Ju 52.
	"trimotor": {
		"body": "res://assets/aircraft/trimotor/body_2x.png",
		"shadow": "res://assets/aircraft/trimotor/shadow_2x.png",
		"rotor_spin_frames": A400M_PROP,
		# PLACEHOLDERS for RotorEditor - M to reach it, 1-3, click, -/+.
		"rotor_offsets": [Vector2(0, 0), Vector2(0, 0), Vector2(0, 0)],
		"rotor_scale": 0.82,
	},
	"emb120": {
		"body": "res://assets/aircraft/emb120/body_2x.png",
		"shadow": "res://assets/aircraft/emb120/shadow_2x.png",
		"rotor_spin_frames": A400M_PROP,
		"rotor_offsets": [Vector2(-32, 6), Vector2(-4, 22)],
		"rotor_scale": 0.71,
	},
	# A regional JET, so no props - it just queues for the runway.
	"crj700": {
		"body": "res://assets/aircraft/crj700/body_2x.png",
		"shadow": "res://assets/aircraft/crj700/shadow_2x.png",
	},
	# TWIN TURBOPROPS, and they had no rotor entry at all - which also kept them
	# out of RotorEditor, since it discovers its model list from whoever
	# declares rotors. So the two aircraft that most obviously need props were
	# the two you could not place props on.
	#
	# The offsets are STARTING POINTS derived from your own Dash 8 rig in
	# data/aircraft_rig.json, scaled by airframe width (114 and 113 against its
	# 107) - the three share a layout, so its hubs land close on these. Place
	# them properly with RotorEditor: R, M to reach the model, 1/2 for the hub,
	# click to set, - and + for the disc.
	"atr72": {
		"body": "res://assets/aircraft/atr72/body_2x.png",
		"shadow": "res://assets/aircraft/atr72/shadow_2x.png",
		"rotor_spin_frames": A400M_PROP,
		"rotor_offsets": [Vector2(-36.5, 1.2), Vector2(-1.6, 19.1)],
		"rotor_scale": 0.78,
	},
	"an140": {
		"body": "res://assets/aircraft/an140/body_2x.png",
		"shadow": "res://assets/aircraft/an140/shadow_2x.png",
		"rotor_spin_frames": A400M_PROP,
		"rotor_offsets": [Vector2(-36.2, 1.2), Vector2(-1.6, 18.9)],
		"rotor_scale": 0.78,
	},
	"dhc8": {
		"body": "res://assets/aircraft/dhc8/body_2x.png",
		"shadow": "res://assets/aircraft/dhc8/shadow_2x.png",
		"rotor_spin_frames": A400M_PROP,
		"rotor_offsets": [Vector2(-34, 6), Vector2(-5, 23)],
		"rotor_scale": 0.74,
	},
	# Twin Otter. Two wing turboprops, so two hubs - and unlike the Dash 8 its
	# props are NOT painted into the body art, they are drawn stopped, which
	# means a badly placed disc is obvious rather than merely wrong.
	#
	# The offsets below are a STARTING POINT copied off the Dash 8 and nudged
	# for a narrower airframe (94px wide against 107) - place them properly
	# with RotorEditor: R, then M to reach dhc6, 1/2 to pick a hub, click to
	# set, [ and ] to size the disc, B if the far prop should sit behind the
	# hull. The rig file wins once anything is saved there.
	"dhc6": {
		"body": "res://assets/aircraft/dhc6/body_2x.png",
		"shadow": "res://assets/aircraft/dhc6/shadow_2x.png",
		"rotor_spin_frames": A400M_PROP,
		"rotor_offsets": [Vector2(-30.1, 1.0), Vector2(-1.3, 15.7)],
		"rotor_scale": 0.70,
	},
	"f15": {
		"body": "res://assets/aircraft/f15/body_2x.png",
		"shadow": "res://assets/aircraft/f15/shadow_2x.png",
		# Only ONE nozzle is actually visible from this camera - the near one
		# sits behind the near tail fin - but both are placed, because the
		# hidden one still lights the air beside the fin and dropping it made
		# the aircraft look like it had one engine.
		#
		# The far nozzle is read off the source render at (655, 178) and scaled
		# by 118/899; the near one is offset by the spacing the F-14's pair
		# turned out to have. RotorEditor's E mode settles both.
		"exhaust_offsets": [Vector2(27.0, -14.6), Vector2(42.0, -5.6)],
		# 24 degrees, against the F-14's 17 - which is the whole reason the
		# angle lives on the aircraft rather than baked into the art.
		"exhaust_angle": 24.0,
		# Smaller airframe than the F-14, 76px against 82.
		"exhaust_scale": 0.9,
	},
	# Four radials, so four hubs - the only one here that uses all four.
	"dc6": {
		"body": "res://assets/aircraft/dc6/body_2x.png",
		"shadow": "res://assets/aircraft/dc6/shadow_2x.png",
		"rotor_spin_frames": A400M_PROP,
		"rotor_offsets": [
			Vector2(-48, 4), Vector2(-34, 12), Vector2(-6, 26), Vector2(8, 33),
		],
		"rotor_scale": 0.89,
		# Same problem the A400M has: the inboard prop on the far wing is partly
		# covered by the hull, so its disc must not paint over the fuselage.
		"rotor_behind_body": [1],
	},
	"tu104": {
		"body": "res://assets/aircraft/tu104/body_2x.png",
		"shadow": "res://assets/aircraft/tu104/shadow_2x.png",
	},
	"b727": {
		"body": "res://assets/aircraft/b727/body_2x.png",
		"shadow": "res://assets/aircraft/b727/shadow_2x.png",
	},
	"b707": {
		"body": "res://assets/aircraft/b707/body_2x.png",
		"shadow": "res://assets/aircraft/b707/shadow_2x.png",
	},
	"a220": {
		"body": "res://assets/aircraft/a220/body_2x.png",
		"shadow": "res://assets/aircraft/a220/shadow_2x.png",
	},
	"a350-900": {
		"body": "res://assets/aircraft/a350-900/body_2x.png",
		"shadow": "res://assets/aircraft/a350-900/shadow_2x.png",
	},
	# The Super Guppy, the one outsize freighter that IS rigged - four
	# turboprops, where the Beluga and the Dreamlifter are plain jets.
	#
	# THREE HUBS FOR FOUR ENGINES. The near wing's inboard propeller is hidden
	# behind the fuselage in this render - the bulge is the whole point of the
	# aeroplane - so a fourth hub had nowhere to sit but the body centre, where
	# it would spin in the middle of the hull. The rig follows the ART, the same
	# call as the H-4 getting six hubs for the real aircraft's eight.
	"guppy": {
		"body": "res://assets/aircraft/guppy/body_2x.png",
		"shadow": "res://assets/aircraft/guppy/shadow_2x.png",
		"rotor_spin_frames": A400M_PROP,
		"rotor_offsets": [Vector2(0, 0), Vector2(0, 0), Vector2(0, 0)],
		"rotor_scale": 0.78,
	},
	# THE TWO OUTSIZE FREIGHTERS. Plain jets - no props, no nozzles - so there
	# is nothing to rig on either of them.
	"beluga-xl": {
		"body": "res://assets/aircraft/beluga-xl/body_2x.png",
		"shadow": "res://assets/aircraft/beluga-xl/shadow_2x.png",
	},
	"dreamlifter": {
		"body": "res://assets/aircraft/dreamlifter/body_2x.png",
		"shadow": "res://assets/aircraft/dreamlifter/shadow_2x.png",
	},
	"be200": {
		"body": "res://assets/aircraft/be200/body_2x.png",
		"shadow": "res://assets/aircraft/be200/shadow_2x.png",
	},
	"us2": {
		"body": "res://assets/aircraft/us2/body_2x.png",
		"shadow": "res://assets/aircraft/us2/shadow_2x.png",
		# Four turboprops painted into the body, like the A400M and the LC-130,
		# so only the spin flipbook layers on and it borrows the A400M's art.
		"rotor_spin_frames": A400M_PROP,
		# PLACEHOLDERS for RotorEditor - M to reach it, 1-4, click, -/+.
		"rotor_offsets": [Vector2(0, 0), Vector2(0, 0), Vector2(0, 0), Vector2(0, 0)],
		"rotor_scale": 0.78,
	},
	"b314": {
		"body": "res://assets/aircraft/b314/body_2x.png",
		"shadow": "res://assets/aircraft/b314/shadow_2x.png",
		"rotor_spin_frames": A400M_PROP,
		"rotor_offsets": [Vector2(0, 0), Vector2(0, 0), Vector2(0, 0), Vector2(0, 0)],
		"rotor_scale": 0.85,
	},
	"f16": {
		"body": "res://assets/aircraft/f16/body_2x.png",
		"shadow": "res://assets/aircraft/f16/shadow_2x.png",
		# ONE engine, one nozzle - the only single-engine aircraft with a
		# burner. Read off f16_default.png at (725, 225), scaled by 101/898.
		# These are the seed. The placed rig overrides them, and did: position
		# landed within 5px, but 20 degrees became 32 and 0.80 became 1.20.
		"exhaust_offsets": [Vector2(34.2, -16.2)],
		"exhaust_angle": 32.0,
		"exhaust_scale": 1.2,
	},
	"harrier": {
		"body": "res://assets/aircraft/harrier/body_2x.png",
		"shadow": "res://assets/aircraft/harrier/shadow_2x.png",
		# It leaves the deck straight up, which is the whole reason it is the
		# Carrier's third aircraft rather than another jet.
		"vtol": true,
		# NO EXHAUST NOZZLE, deliberately. Every other fast jet here has one,
		# but the Pegasus is a non-afterburning turbofan - a Harrier has no
		# reheat to draw. It vectors thrust down through four cold and hot
		# nozzles instead, which is a different effect entirely and not this one.
	},
	"h4": {
		"body": "res://assets/aircraft/h4/body_2x.png",
		"shadow": "res://assets/aircraft/h4/shadow_2x.png",
		# SIX propellers, three a wing. The real H-4 has eight - the art has
		# six, and the rig follows the art, or two hubs would sit in empty space.
		"rotor_spin_frames": A400M_PROP,
		"rotor_offsets": [Vector2(0, 0), Vector2(0, 0), Vector2(0, 0),
			Vector2(0, 0), Vector2(0, 0), Vector2(0, 0)],
		"rotor_scale": 0.78,
	},
	"e2": {
		"body": "res://assets/aircraft/e2/body_2x.png",
		"shadow": "res://assets/aircraft/e2/shadow_2x.png",
		# Two turboprops painted into the body, so only the spin flipbook
		# layers on - borrowed from the A400M like every propliner here.
		"rotor_spin_frames": A400M_PROP,
		# PLACEHOLDERS for RotorEditor: M to reach it, 1/2, click, -/+.
		"rotor_offsets": [Vector2(0, 0), Vector2(0, 0)],
		"rotor_scale": 0.78,
	},
	"f14": {
		"body": "res://assets/aircraft/f14/body_2x.png",
		"shadow": "res://assets/aircraft/f14/shadow_2x.png",
		# TWIN nozzles, which is the thing four rounds of eyeballing a
		# screenshot kept missing - one plume floating between them looks wrong
		# wherever you put it. These are read off the source render at full
		# size and scaled by 126/931, so they are a starting point rather than
		# a guess, but RotorEditor's E mode is what settles them.
		"exhaust_offsets": [Vector2(31.0, -18.0), Vector2(38.0, 5.0)],
		# The fuselage runs about 17 degrees above horizontal, nose to nozzle.
		# The plume art points straight back along +x and is rotated by this,
		# so every aircraft shares one flipbook.
		"exhaust_angle": 17.0,
		"exhaust_scale": 1.0,
	},
	"an74": {
		"body": "res://assets/aircraft/an74/body_2x.png",
		"shadow": "res://assets/aircraft/an74/shadow_2x.png",
	},
	"lc130": {
		"body": "res://assets/aircraft/lc130/body_2x.png",
		"shadow": "res://assets/aircraft/lc130/shadow_2x.png",
		# Four turboprops, painted into the body like the A400M's, so parked
		# needs no overlay and only the spin flipbook layers on - and it borrows
		# the A400M's prop art, the way every propliner here does.
		"rotor_spin_frames": A400M_PROP,
		# PLACEHOLDERS, four of them, so RotorEditor has hubs to select. Set in
		# game: M to reach the LC-130, 1-4 to pick a hub, click, -/+ to size.
		"rotor_offsets": [Vector2(0, 0), Vector2(0, 0), Vector2(0, 0), Vector2(0, 0)],
		"rotor_scale": 0.78,
	},
	"b777-300er": {
		"body": "res://assets/aircraft/b777-300er/body_2x.png",
		"shadow": "res://assets/aircraft/b777-300er/shadow_2x.png",
	},
	"a340-300": {
		"body": "res://assets/aircraft/a340-300/body_2x.png",
		"shadow": "res://assets/aircraft/a340-300/shadow_2x.png",
	},
	"c17": {
		"body": "res://assets/aircraft/c17/body_2x.png",
		"shadow": "res://assets/aircraft/c17/shadow_2x.png",
	},
	"il62": {
		"body": "res://assets/aircraft/il62/body_2x.png",
		"shadow": "res://assets/aircraft/il62/shadow_2x.png",
	},
	"banshee": {
		"body": "res://assets/aircraft/banshee/body_2x.png",
		"shadow": "res://assets/aircraft/banshee/shadow_2x.png",
		# Two ducted lift fans and no wing to speak of, so it leaves the pad
		# straight up like the V-22 rather than taxiing the runway track.
		"vtol": true,
		# ITS OWN, from tools/banshee_rotor.py. It briefly borrowed the Black
		# Hawk's disc, which is the right ELLIPSE and the wrong object: a bare
		# helicopter head feathering out at the edge, where a ducted fan is
		# enclosed, many-bladed and short.
		#
		# NO IDLE FRAMES. The static fans are painted into the body art, the
		# same arrangement as the A400M's parked props, so only the spin
		# flipbook is ever layered on.
		"rotor_spin_frames": [
			"res://assets/aircraft/banshee/rotor_spin_a_2x.png",
			"res://assets/aircraft/banshee/rotor_spin_b_2x.png",
		],
		# PLACEHOLDERS. RotorEditor cannot cycle to a model with no rotor entry,
		# so these two exist to give it a pair of hubs to select - they are a
		# hook to hang the real placement on, not a guess at where the fans are.
		# M to reach the Banshee, 1/2 to pick a hub, click to place, -/+ to size.
		"rotor_offsets": [Vector2(0, 0), Vector2(0, 0)],
		"rotor_scale": 0.82,
	},
	"dc10": {
		"body": "res://assets/aircraft/dc10/body_2x.png",
		"shadow": "res://assets/aircraft/dc10/shadow_2x.png",
	},
	"concorde": {
		"body": "res://assets/aircraft/concorde/body_2x.png",
		"shadow": "res://assets/aircraft/concorde/shadow_2x.png",
		# FOUR engines in two nacelle pairs, and two plumes rather than four:
		# at 155px the pairs are one dark shape each, so a plume per engine
		# would be two overlapping flames pretending to be one.
		#
		# Read off concorde_zebra.png at (810, 275) and (865, 340), scaled by
		# 155/963. Reheat on takeoff is the one thing Concorde genuinely did
		# that the other airliners here did not.
		"exhaust_offsets": [Vector2(52.9, 0.3), Vector2(61.8, 10.7)],
		# A slender delta sits much flatter than a fighter - 9 degrees against
		# the F-15's 26.
		"exhaust_angle": 9.0,
		"exhaust_scale": 0.85,
	},
	"b787": {
		"body": "res://assets/aircraft/b787/body_2x.png",
		"shadow": "res://assets/aircraft/b787/shadow_2x.png",
	},
	# A distinct airframe from "747" above, not a repaint of it.
	"b747": {
		"body": "res://assets/aircraft/b747/body_2x.png",
		"shadow": "res://assets/aircraft/b747/shadow_2x.png",
	},
	# NOT vtol - it has wings and it lands on a runway, so it queues like the
	# rest of the fleet. (It was briefly vtol on the reasoning that a space
	# vehicle should go straight up; the user's call, and the right one.)
	"x37b": {
		"body": "res://assets/aircraft/x37b/body_2x.png",
		"shadow": "res://assets/aircraft/x37b/shadow_2x.png",
		# ONE engine, so one plume. Read off x_37b_default.png at (880, 280),
		# scaled by 111/935. A rocket rather than a turbofan, so there is no
		# reheat to be honest about - but a lit nozzle suits it, and it is the
		# only spacecraft in the game that leaves from a runway.
		"exhaust_offsets": [Vector2(49.0, -13.8)],
		"exhaust_angle": 19.0,
		"exhaust_scale": 0.9,
	},
	# A flying saucer by any other name - straight up off the pad.
	"uss51": {
		"body": "res://assets/aircraft/uss51/body_2x.png",
		"shadow": "res://assets/aircraft/uss51/shadow_2x.png",
		"vtol": true,
	},
	# Leaves the pad straight up, same as the UFO and the Ark.
	"ncc1701": {
		"body": "res://assets/aircraft/ncc1701/body_2x.png",
		"shadow": "res://assets/aircraft/ncc1701/shadow_2x.png",
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
# GONE: XP used to be payout / MONEY_PER_XP, on the assumption that a leg's XP
# tracked its cash. The original disproves it outright - its DC-3 pays 400 for
# 30 XP and its Paper Plane pays 450 for 150. XP is a per-aircraft stat now
# (ShopCatalog "xp"), which is the only way that aircraft makes sense.
#
# The constant is not replaced by another constant, and nothing needs to divide
# anything: the live DC-3's 30 XP a leg lands level 10 at fifteen minutes on its
# own, which is the pacing target it was invented to hit.


# map_key is accepted and ignored, matching payout_for - XP is the aircraft's
# own stat and the route's distance does not enter it.
func xp_for_claim(model_key: String, _map_key: String = "") -> int:
	return maxi(1, int(ShopCatalog.stat(model_key, "xp")))

# The flat fare for anything with a normal cabin. 15, which is the LIVE game's
# own value, read straight off its shop cards - every airliner on every page
# shows a 15 beside the money icon.
#
# This was 8, from a belief that the original charged 4 and that we needed to
# double it to fill Zone1 in fifteen minutes. Both halves of that were wrong:
# the fare is 15, and at 15 the DC-3 earns 750 a leg against its own 3,000
# price - two round trips to pay for itself, which is the fifteen-minute
# opening we were trying to buy by doubling. Every price in ShopCatalog had
# been halved to compensate for the mistake; they are the live prices now.
#
# Aircraft that carry almost nobody override it (ShopCatalog "ticket"), which
# is the only way a 2-seat P-51 can be worth owning - and the original does the
# same, charging 2000 a head on its F-15 and 200 on its balloon.
const TICKET_PRICE := 15


func ticket_price(model_key: String) -> int:
	return int(ShopCatalog.entry_for(model_key).get("ticket", TICKET_PRICE))

# HOW LONG A LEG TAKES.
#
# Set by how far you SEND it - the route's clouds, not the aircraft's rating.
# The walkthrough is explicit that duration comes from "how advanced the plane
# and distance of the flights", and that short hops run "two to fifteen minutes
# for each direction", which is what the first two columns below give.
#
# It was briefly keyed to the aircraft's rating instead. That inverted the
# ladder outright: a rating-5 A380 was gone for 17 hours whatever it did, so it
# earned a ninth of what a level-4 Dash 8 made per hour, and every step up the
# shop was an economic downgrade. Keying it to the ROUTE fixes that at the root
# - at any given distance a bigger aircraft simply earns more.
#
# The force grade is an ADDITIVE step, not a multiplier - which is what makes
# the class a trim rather than a headline. Both ends are anchored:
#
#     rating 1:  S = 1 min,  A = 2 min       (one minute per grade)
#     rating 5:  S = 12 h,   A = 13 h        (one hour per grade)
#
# THE CEILING IS THE LEG, AND IT IS 12 HOURS - which makes the round trip 24,
# and those are the two numbers the original is remembered by. It was 17h a leg
# and 34h the round trip, from anchoring 12h on the S-class leg rather than on
# the slowest one: a 34-hour round trip is not an overnight aircraft, it is a
# skip-a-day aircraft, and nothing in the game is meant to outlast a day.
#
# So the worst case - E-class, five clouds - is 720 minutes exactly, and the
# classes step down from there to 7h for an S. The base is geometric from 1
# minute to that ceiling (x4.53 a cloud) and the per-grade step is geometric to
# an hour (x2.78), both solved rather than picked.
const CLOUD_BASE_MINUTES := [1.0, 5.0, 20.0, 93.0, 420.0]
const CLASS_STEP_MINUTES := [1.0, 3.0, 8.0, 22.0, 60.0]

# Steps along CLASS_STEP_MINUTES. S is the zero point - it pays no penalty at
# all - and S+ (which only a livery reaches, see AircraftSkins) goes half a step
# BELOW it, so painting a top-class aircraft still buys something.
const CLASS_STEPS := {"S+": -0.5, "S": 0.0, "A": 1.0, "B": 2.0, "C": 3.0, "D": 4.0, "E": 5.0}

# Worst to best. A livery moves an aircraft one place along it.
const GRADE_LADDER := ["E", "D", "C", "B", "A", "S", "S+"]

# Minutes for one leg: how far it is going, stepped by the grade flying it.
func _leg_minutes(clouds: int, grade: String) -> float:
	var i := clampi(clouds, 1, CLOUD_BASE_MINUTES.size()) - 1
	return CLOUD_BASE_MINUTES[i] + float(CLASS_STEPS.get(grade, 0.0)) * CLASS_STEP_MINUTES[i]


func grade_for(a: FleetAircraft) -> String:
	var base := str(ShopCatalog.stat(a.model_key, "force"))
	if not a.livery.is_empty():
		var i := GRADE_LADDER.find(base)
		if i != -1 and i < GRADE_LADDER.size() - 1:
			base = GRADE_LADDER[i + 1]
	# A speed card lifts anything below A up to A. AFTER the livery step, so a
	# painted aircraft keeps whatever the paint bought it, and lift_grade only
	# ever raises - an S-class is not dragged down to A by this.
	return Boosts.lift_grade(base)


# Flight time for a specific aircraft, livery included. flight_seconds_to()
# below is the model-level estimate the shop and routes table use, where there
# is no particular aircraft to ask about.
func flight_seconds_for(a: FleetAircraft, map_key: String) -> float:
	return (_leg_minutes(distance_to(map_key), grade_for(a)) * 60.0
		* AircraftAffinity.speed_multiplier(a.model_key))


# How many passengers a leg carries: all of them.
func passengers(model_key: String) -> int:
	return int(ShopCatalog.stat(model_key, "seats"))


# Flat per leg, like pay - it is the number on the card. map_key is accepted and
# ignored to match payout_for.
func fuel_cost(model_key: String, _map_key: String = "") -> int:
	if Boosts.fuel_is_free():
		return 0
	return int(ShopCatalog.stat(model_key, "fuel"))


# What one leg pays, and it is the ORIGINAL'S OWN FORMULA:
#
#     ticket * seats * cloud rating
#
# All three are printed on the shop card, and the game's A400M checks out
# exactly - 100 a head, 500 seats, rating 5, 250,000 a leg.
#
# Range being a straight multiplier is why it is the most guarded stat in the
# shop: a rating-5 aircraft earns five times a rating-1 one of the same cabin,
# before capacity even comes into it.
#
# The original's own formula - ticket * seats * cloud rating - with the rating
# read as the ROUTE'S clouds, which is what "the longer the route the more money
# you will make" means. The shop card's figure is this evaluated at the
# aircraft's MAXIMUM rating, which is why it looks like a property of the
# aircraft; fly it somewhere nearer and it earns proportionally less.
#
# Confirmed against the A400M: 100 a head, 500 seats, at its full 5 clouds is
# the 250,000 a leg the game shows.
func payout_for(model_key: String, map_key: String = "") -> int:
	return passengers(model_key) * ticket_price(model_key) * distance_to(map_key)


# The destination that MATCHES this aircraft's cloud rating - the one it was
# built for. Pay is ticket * seats * the ROUTE's clouds, so anything nearer
# wastes the rating you paid for, and anything further it cannot reach at all.
#
# Falls back to the furthest it can reach when the exact match is still locked,
# and to the nearest when nothing is. Used to pick a sensible default rather
# than leaving every new route pointed at the tutorial hop.
func best_destination_for(model_key: String) -> String:
	var reach := int(ShopCatalog.stat(model_key, "range"))
	var best := Maps.ROBOT_MAP
	var best_d := 0
	for key in Maps.visitable_maps():
		var d := distance_to(key)
		if d == reach:
			return key
		if d < reach and d > best_d:
			best = key
			best_d = d
	return best


func in_range(model_key: String, map_key: String) -> bool:
	return int(ShopCatalog.stat(model_key, "range")) >= distance_to(map_key)




var aircraft: Array[FleetAircraft] = []
var _next_id := 1
# Bulk operations (advance_all) touch every aircraft and would otherwise fire
# fleet_changed once per action per aircraft - and ApronLayer rebuilds every
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
	# A fresh game is HANDED a DC-3, parked on the first apron.
	#
	# It briefly wasn't - buying your own first aircraft was the opening, and
	# STARTING_MONEY was sized for that. Two things were wrong with it.
	#
	# The opening was five minutes of tapping ONE aircraft back and forth: the
	# DC-3 costs 3,000 of a 5,000 start, and the 2,000 left cannot buy a second
	# one. Measured in tools/econ_sim.py, granting the aircraft and keeping the
	# money reaches a second aircraft at minute 1 instead of minute 6, and five
	# aircraft at minute 12 instead of 24. Granting it and NOT keeping the money
	# changes nothing at all, which is what identifies the real wall: whether
	# 3,000 is affordable on the first minute, not whether you own a plane.
	#
	# And it made a dead end reachable. With no aircraft and 5,000 in hand, a
	# 3,000 building leaves 2,000 against a 3,000 aircraft - nothing that flies,
	# and one building to tap. BuildingProgress gates the Prop Shop behind Zone2
	# partly for this reason; owning an aircraft from the first frame removes
	# the hole itself rather than fencing it off.
	# Granted by SaveGame, not here: it is the last autoload to come up, so it
	# is the only one that can tell a brand-new game from a loaded one, and
	# Fleet cannot ask it anything at its own _ready. See SaveGame._load.
	pass


# The free DC-3, on the first apron. Called on a fresh game and on a reset -
# the two are the same thing and must hand out the same thing.
func grant_starter() -> void:
	var a := FleetAircraft.new(_next_id, STARTER_MODEL)
	_next_id += 1
	# Apron 1 is Zone1's first pad, which is one of the five that come free -
	# see ApronLayout.build_area_aprons. A granted aircraft with nowhere to
	# stand would be an idle one in the hangar, which is not the same gift.
	a.assigned_apron_id = 1
	aircraft.append(a)
	_emit_changed()


# Aircraft ids restart from 1 on a reset, so a fresh game reads like a fresh
# game rather than continuing somebody else's numbering.
func reset_ids() -> void:
	_next_id = 1


func _process(delta: float) -> void:
	if _advance_flights(delta):
		_emit_changed()


# Tick the fleet forward by an arbitrary amount. _advance_flights is what the
# save loader already uses to catch up on time the game was closed, so this is
# not a new code path - it is the same one, exposed so the headless bot and the
# fast-forward can drive it in steps rather than a frame at a time.
func advance_by(seconds: float) -> void:
	if seconds <= 0.0:
		return
	if _advance_flights(seconds):
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
			"left": a.flight_time_left, "total": a.flight_time_total,
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
		var a := FleetAircraft.new(int(d.get("id", 0)), str(d.get("model", STARTER_MODEL)))
		a.assigned_apron_id = int(d.get("apron", -1))
		a.robot_apron_id = int(d.get("robot_apron", -1))
		a.state = int(d.get("state", FleetAircraft.State.PARKED))
		a.flight_time_left = float(d.get("left", 0.0))
		# Saves written before the countdown existed have no total; the leg it is
		# on is the best available answer and only affects a progress bar.
		a.flight_time_total = float(d.get("total", 0.0))
		if a.flight_time_total <= 0.0:
			a.flight_time_total = maxf(a.flight_time_left, 1.0)
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
# model_key is optional so callers that only want a baseline (the routes table's
# estimate, tests) don't have to name an aircraft - they get the S-class figure.
func flight_seconds_to(map_key: String, model_key: String = "") -> float:
	var grade := str(ShopCatalog.stat(model_key, "force")) if model_key != "" else "S"
	var affinity := AircraftAffinity.speed_multiplier(model_key) if model_key != "" else 1.0
	return _leg_minutes(distance_to(map_key), grade) * 60.0 * affinity



func distance_to(map_key: String) -> int:
	return maxi(1, int(Maps.entry(map_key).get("distance", 1)))


func fuel_and_depart(aircraft_id: int) -> bool:
	var a := get_aircraft(aircraft_id)
	if not a or a.state != FleetAircraft.State.PARKED:
		return false
	return _launch(a)


# THE TURNAROUND, IN ONE TAP. A landed aircraft used to need three: claim the
# reward, buy fuel, then depart - and the middle one was a button that asked for
# money and gave you back a parked aircraft, which is not a decision anybody was
# making. Two taps a lap is the whole loop: claim what it earned, send it out
# again.
#
# It also fixed a double charge. The destination refuels you for free, so the
# paid top-up on landing at home and the paid tank on departure were two
# payments covering one outbound leg. FUEL IS CHARGED ONCE NOW, AT DEPARTURE -
# which is what _launch does, for both callers.
func refuel_and_depart(aircraft_id: int) -> bool:
	var a := get_aircraft(aircraft_id)
	if not a or a.state != FleetAircraft.State.AWAITING_HOME_REFUEL:
		return false
	return _launch(a)


# Park a landed aircraft without sending it anywhere - and WITHOUT charging it,
# because it is not going anywhere yet. Used when the route is being edited: the
# turnaround tap would launch it at the destination it is being moved off.
func park_at_home(aircraft_id: int) -> bool:
	var a := get_aircraft(aircraft_id)
	if not a or a.state != FleetAircraft.State.AWAITING_HOME_REFUEL:
		return false
	a.state = FleetAircraft.State.PARKED
	_emit_changed()
	return true


# Everything a departure needs, shared by both ways of starting one.
func _launch(a: FleetAircraft) -> bool:
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
	if not FuelStore.consume(fuel_cost(a.model_key, destination_of(a))):
		return false
	a.robot_apron_id = pad
	flight_departed.emit(a.model_key, destination_of(a))
	a.state = FleetAircraft.State.FLYING_OUT
	a.flight_time_left = flight_seconds_for(a, destination_of(a))
	a.flight_time_total = a.flight_time_left
	_emit_changed()
	return true


func claim_destination_reward(aircraft_id: int) -> void:
	var a := get_aircraft(aircraft_id)
	if a and a.state == FleetAircraft.State.AWAITING_DEST_CLAIM:
		_grant_reward(a, a.assigned_apron_id)
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
		a.flight_time_total = a.flight_time_left
		_emit_changed()


func claim_home_reward(aircraft_id: int) -> void:
	var a := get_aircraft(aircraft_id)
	if a and a.state == FleetAircraft.State.AWAITING_HOME_CLAIM:
		_grant_reward(a, a.assigned_apron_id)
		AircraftAffinity.grant_use(a.model_key)
		a.state = FleetAircraft.State.AWAITING_HOME_REFUEL
		_emit_changed()


# Apron skins (see ApronSkins) give a flat bonus to both the cash and XP
# reward for whichever apron the aircraft is parked at.
#
# The city's popularity is a SECOND multiplier, and a cash-only one: every 250
# inhabitants your buildings house adds 1% to what a flight pays (see
# BuildingProgress.PEOPLE_PER_PERCENT). That is what ties the two economies
# together - the buildings are not a side pot, they make the fleet worth more.
#
# It deliberately does NOT touch XP. The level curve is calibrated against
# flights on their own, and letting the city speed it up would pull every
# aircraft and zone unlock forward as a side effect of decorating.
# Takes the aircraft rather than a bare amount so cash and XP are both read
# off the SAME route - paying for a 5-cloud leg while granting a 1-cloud leg's
# XP is exactly the kind of drift two separate lookups invite.
func _grant_reward(a: FleetAircraft, apron_id: int) -> void:
	var dest := destination_of(a)
	var bonus := 1.0 + ApronSkins.bonus_percent_for(apron_id) / 100.0
	var cash := reward_cash_for(a, apron_id)
	Economy.add_money(cash)
	Progression.add_xp(roundi(xp_for_claim(a.model_key, dest) * bonus))
	flight_claimed.emit(a.model_key, dest, cash)


# What claiming this aircraft pays. Split out of _grant_reward so the figure can
# be asked for without granting it - the routes panel and any future preview
# want the same number, and a second copy of this expression is exactly the
# drift this project keeps getting bitten by.
func reward_cash_for(a: FleetAircraft, apron_id: int) -> int:
	if a == null:
		return 0
	var bonus := 1.0 + ApronSkins.bonus_percent_for(apron_id) / 100.0
	return roundi(payout_for(a.model_key, destination_of(a)) * bonus
		* BuildingProgress.popularity_multiplier() * Boosts.cash_multiplier())


func is_flying(a: FleetAircraft) -> bool:
	return a != null and (a.state == FleetAircraft.State.FLYING_OUT
		or a.state == FleetAircraft.State.FLYING_BACK)


# How far along its leg this aircraft is, 0..1. Clamped, because a save from
# before totals existed - or an affinity level gained mid-flight - can put the
# remaining time outside the total it was launched with.
func flight_progress(a: FleetAircraft) -> float:
	if a == null or a.flight_time_total <= 0.0:
		return 0.0
	return clampf(1.0 - a.flight_time_left / a.flight_time_total, 0.0, 1.0)


# "47m 42s", "2h 05m", "38s" - the countdown on the callout. Matches the shape
# the reference game uses rather than a bare seconds count, because a five cloud
# leg is seven hours and "25200s" tells nobody anything.
func time_left_text(seconds: float) -> String:
	var t := int(ceilf(maxf(0.0, seconds)))
	if t >= 3600:
		return "%dh %02dm" % [t / 3600, (t % 3600) / 60]
	if t >= 60:
		return "%dm %02ds" % [t / 60, t % 60]
	return "%ds" % t


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
				return "no pad at %s" % Maps.display_name(destination_of(a))
			if FuelStore.amount < fuel_cost(a.model_key, destination_of(a)):
				return "needs %d fuel" % fuel_cost(a.model_key, destination_of(a))
		# Departs in one tap now, so it is blocked by everything a departure is.
		FleetAircraft.State.AWAITING_HOME_REFUEL:
			if not in_range(a.model_key, destination_of(a)):
				return "out of range"
			if robot_apron_for(a) == -1:
				return "no pad at %s" % Maps.display_name(destination_of(a))
			if FuelStore.amount < fuel_cost(a.model_key, destination_of(a)):
				return "needs %d fuel" % fuel_cost(a.model_key, destination_of(a))
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
			refuel_and_depart(a.id)
	return a.state != before


# A full round trip is four separate actions per aircraft - collect, send home,
# collect, refuel-and-depart - so a fleet of five costs twenty presses to go
# round once. This runs every aircraft as far forward as it will go in one
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
				a.bulk_departure = true
				a.launch_delay = departed * step
				a.flight_time_left += a.launch_delay
				a.flight_time_total = a.flight_time_left
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


# Every pad at one destination, across all seven mirrored areas, in id order.
# Defaults to the nearest, which is where a save with no destination goes.
func robot_apron_ids(map_key: String = "") -> Array:
	var key := map_key if map_key != "" else Maps.ROBOT_MAP
	var starts: Dictionary = ApronLayout.compute_id_starts()
	var data: Dictionary = ApronLayout.effective_area_data(key)
	var ids: Array = []
	for area in Maps.robot_areas_for(key):
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
#
# Each of the five destinations has its own block of ids, so the pad an aircraft
# claims depends on where it is going as well as where it is based.
func robot_apron_for(a: FleetAircraft) -> int:
	if a.assigned_apron_id < 1:
		return -1
	var ids := robot_apron_ids(destination_of(a))
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
