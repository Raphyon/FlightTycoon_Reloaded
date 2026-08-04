extends Node2D

# Original enhancement (no reference shows the real game animating this at
# all - it just removes the sprite instantly). Conventional (runway) models:
# 1) startup wobble then fade out in place at the apron, 2) teleport + flip
# to the runway entry, 3) fade in and travel along the runway as one
# continuously accelerating curve, 4) disappear off-canvas (no fade-out).
# Body and shadow move along their own separately traced paths (arbitrary
# point count) so the shadow can stay on the ground while the body climbs
# away from it - all placed by hand with PathEditor (press T in-game), not
# guessed - see PathLayout.
#
# Arrivals mirror that: fly in along the separately traced approach paths,
# then fade out and reappear parked at the apron - the same teleport
# convention departures use, in reverse, so one traced approach serves
# every apron instead of needing a path per apron.
#
# VTOL models (tiltrotors, helicopters, UFOs - see Fleet.WORLD_SPRITES
# "vtol") skip the runway track entirely and lift straight up from the
# apron instead - see _play_vertical_liftoff / _play_vertical_landing.
const STARTUP_DURATION := 0.4
const STARTUP_WOBBLE_DISTANCE := 2.0  # px, diagonal shift not rotation
const STARTUP_WOBBLE_REPEATS := 2
# Engine-idle vibration while queued for the runway - tighter and quicker
# than the startup wobble so it reads as ticking over, not taxiing.
const IDLE_SHAKE_DISTANCE := 1.0
const IDLE_SHAKE_DURATION := 0.11
const FADE_OUT_DURATION := 0.3

const FADE_IN_DURATION := 0.3
const TRAVEL_DURATION := 5.0  # start -> end, continuously accelerating
const ARRIVAL_TRAVEL_DURATION := 5.0  # approach -> touchdown, decelerating
const BODY_BASE_OFFSET := Vector2(0, -6)
const ROTOR_FRAME_DURATION := 0.15

const VTOL_RISE_DISTANCE := 220.0  # px straight up before it's gone
const VTOL_RISE_DURATION := 2.8
# Seconds the downwash takes to fade out over the climb (and to build up
# over the descent, timed to peak at touchdown). Bump this to make the wash
# linger longer on the pad; it's clamped to the climb so it can't outlast
# the manoeuvre itself.
const GROUND_EFFECT_FADE_DURATION := 2.4

# How far through the runway run a departing plane hands the strip to the
# next in line. Holding it for the full run out means a queue of four
# crawls; by half way it's airborne and clear of the ground anyway.
const RUNWAY_RELEASE_FRACTION := 0.5

var _shadow: Sprite2D
var _shadow_parked: Texture2D
var _shadow_spinning: Texture2D
var _body: Sprite2D
var _body_parked: Texture2D
var _body_spinning: Texture2D
var _rotors_idle: Array[Sprite2D] = []
var _rotors_spin: Array[Sprite2D] = []
var _is_vtol := false
var _ground_effect: Sprite2D
var _home_position := Vector2.ZERO
var _animating := false
var _holds_runway := false
# Kept so a livery change can repaint an EXISTING node. Without them the only
# way the hull art ever got chosen was setup(), which runs once when the node
# is created - so painting an aircraft already standing on a pad changed
# nothing you could see.
var _model_key := ""
var _livery := ""


# Repaints an aircraft that is already on a pad. Only the hull changes: shadow,
# rotors and offsets belong to the airframe, and paint does not change shape.
#
# Returns false when nothing needed doing, so the caller can skip the work.
func set_livery(livery: String) -> bool:
	if livery == _livery:
		return false
	_livery = livery
	var sprites: Dictionary = Fleet.WORLD_SPRITES.get(_model_key, {})
	var body_path := str(sprites.get("body", ""))
	var spin_path := str(sprites.get("body_spin", ""))
	if livery != "":
		var entry: Dictionary = AircraftSkins.entry(_model_key, livery)
		if entry.has("body"):
			body_path = str(entry["body"])
		if entry.has("body_spin"):
			spin_path = str(entry["body_spin"])
	if is_instance_valid(_body) and body_path != "" and ResourceLoader.exists(body_path):
		_body_parked = load(body_path)
		# Mid-takeoff the spin hull is showing, so don't yank it back to parked.
		if _body.texture == _body_spinning or _animating:
			pass
		else:
			_body.texture = _body_parked
	if spin_path != "" and ResourceLoader.exists(spin_path):
		_body_spinning = load(spin_path)
	return true


# `livery` is the one this particular aircraft is wearing (AircraftSkins), not
# the model's default - two Black Hawks on neighbouring pads can differ.
func setup(model_key: String, screen_pos: Vector2, livery: String = "") -> void:
	position = screen_pos
	_home_position = screen_pos
	_model_key = model_key
	_livery = livery
	var sprites: Dictionary = Fleet.WORLD_SPRITES.get(model_key, {}).duplicate()
	# A livery replaces the hull art only. Shadow, rotors and offsets are the
	# airframe's and stay exactly as they were - the paint doesn't change shape.
	if livery != "":
		var entry: Dictionary = AircraftSkins.entry(model_key, livery)
		if entry.has("body"):
			sprites["body"] = entry["body"]
		if entry.has("body_spin"):
			sprites["body_spin"] = entry["body_spin"]
	_is_vtol = sprites.get("vtol", false)
	if sprites.has("shadow"):
		_shadow = Sprite2D.new()
		_shadow.texture = load(sprites["shadow"])
		add_child(_shadow)
		# Helicopters ship two shadows: one casting the static rotor blades and
		# one without them, for when the rotor has blurred into a disc. Keeping
		# both lets the shadow follow the rotor state instead of showing a
		# stopped rotor's blades under a spinning one.
		_shadow_parked = _shadow.texture
		if sprites.has("shadow_spin"):
			_shadow_spinning = load(sprites["shadow_spin"])
	if sprites.has("body"):
		_body = Sprite2D.new()
		_body.texture = load(sprites["body"])
		_body.position = BODY_BASE_OFFSET
		add_child(_body)
		# A model whose whole hull changes on takeoff rather than just a rotor -
		# the UFO's six thrusters fire - ships a second body. Both frames are
		# padded to a common canvas with the hull on the same spot (see
		# sheet_derive.align_into), so swapping the texture on a centered
		# Sprite2D doesn't shift the aircraft.
		_body_parked = _body.texture
		if sprites.has("body_spin"):
			_body_spinning = load(sprites["body_spin"])
	if sprites.has("rotor_spin_frames") or sprites.has("rotors"):
		_add_rotors(model_key, sprites)
	# Parented to self, not the body, so it stays on the pad rather than
	# riding up with the aircraft.
	if sprites.has("ground_effect_frames"):
		_ground_effect = _add_flipbook(sprites["ground_effect_frames"], Vector2.ZERO, 0.0, self)
		_ground_effect.visible = false
		# The source art is a soft glow that peaks around a third opacity -
		# straight alpha blending makes it vanish against the pale apron, so
		# it needs to add light like the glow it is.
		var glow := CanvasItemMaterial.new()
		glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_ground_effect.material = glow
		# Underneath the shadow and body - it's dust on the ground, and
		# drawing it over the shadow washed the shadow out.
		move_child(_ground_effect, 0)


# Which idle/spin frames hub `index` uses. Most models share one set across
# every hub (a tiltrotor's two nacelles, a turboprop's four engines), so those
# just set rotor_idle_frames/rotor_spin_frames once. A helicopter can't: its
# tail rotor is entirely different art from its main rotor, so it lists one
# entry per hub under "rotors" instead, parallel to rotor_offsets.
#
# Static so RotorEditor can resolve the same art for its preview without
# duplicating the rule.
static func hub_frames(sprites: Dictionary, index: int) -> Dictionary:
	var per_hub: Array = sprites.get("rotors", [])
	if index < per_hub.size():
		var entry: Dictionary = per_hub[index]
		return {"idle": entry.get("idle", []), "spin": entry.get("spin", [])}
	return {
		"idle": sprites.get("rotor_idle_frames", []),
		"spin": sprites.get("rotor_spin_frames", []),
	}


# Propeller/rotor models only - two alternate states per hub, not layered:
# a stationary "idle" sprite shown while parked, swapped for a "spin"
# flipbook while taking off (a static single frame for a tiltrotor's glow,
# or an alternating multi-frame blur for a classic prop). Both are children
# of the body so they inherit its position/flip automatically. Hub offsets
# come from AircraftRig (placed by hand with RotorEditor, press R in-game),
# not the hardcoded fallback in Fleet.WORLD_SPRITES, so edits take effect
# without a code change.
func _add_rotors(model_key: String, sprites: Dictionary) -> void:
	var offsets := AircraftRig.get_rotor_offsets(model_key)
	# Hubs flagged as behind the fuselage. show_behind_parent draws the sprite
	# before its parent, so a flagged rotor lands between the shadow and the
	# body (the shadow is an earlier sibling of _body, so its whole subtree is
	# already done by then) - which is what an inboard far-wing prop needs.
	# Reparenting to self would work too but would lose the body's position
	# and flip, which these inherit for free as its children.
	var behind := AircraftRig.get_rotor_behind(model_key)
	# The propliners share the A400M's disc art at their own sizes - see
	# AircraftRig.get_rotor_scales.
	var scales := AircraftRig.get_rotor_scales(model_key)
	for i in range(offsets.size()):
		var frames := hub_frames(sprites, i)
		var spin_frames: Array = frames["spin"]
		if spin_frames.is_empty():
			continue
		var offset: Vector2 = offsets[i]
		var phase_delay := i * ROTOR_FRAME_DURATION * 0.5
		var draw_behind: bool = i < behind.size() and behind[i]
		var disc_scale: float = scales[i] if i < scales.size() else 1.0
		var idle_frames: Array = frames["idle"]
		if not idle_frames.is_empty():
			var idle := _add_flipbook(idle_frames, offset, phase_delay, null, disc_scale)
			idle.show_behind_parent = draw_behind
			_rotors_idle.append(idle)
		var spin := _add_flipbook(spin_frames, offset, phase_delay, null, disc_scale)
		spin.show_behind_parent = draw_behind
		_rotors_spin.append(spin)
	for rotor in _rotors_spin:
		rotor.visible = false


# 1 frame = static sprite, no tween needed. 2+ frames = an infinite looping
# flipbook, phase-delayed per rotor so multiple rotors don't blink in
# lockstep. Parents to the body by default so rotors inherit its
# position/flip; the ground effect passes self instead, to stay on the pad
# while the body climbs away.
func _add_flipbook(frame_paths: Array, offset: Vector2, phase_delay: float, parent: Node2D = null,
		disc_scale: float = 1.0) -> Sprite2D:
	var textures: Array[Texture2D] = []
	for path in frame_paths:
		textures.append(load(path))

	var sprite := Sprite2D.new()
	sprite.texture = textures[0]
	sprite.position = offset
	if not is_equal_approx(disc_scale, 1.0):
		sprite.scale = Vector2.ONE * disc_scale
	(parent if parent else _body).add_child(sprite)

	if textures.size() > 1:
		var tween := sprite.create_tween()
		tween.set_loops()
		tween.tween_interval(phase_delay)
		for texture in textures:
			tween.tween_callback(func() -> void: sprite.texture = texture)
			tween.tween_interval(ROTOR_FRAME_DURATION)

	return sprite


func _show_spin_rotors() -> void:
	for rotor in _rotors_idle:
		rotor.visible = false
	for rotor in _rotors_spin:
		rotor.visible = true
	if _shadow and _shadow_spinning:
		_shadow.texture = _shadow_spinning
	if _body and _body_spinning:
		_body.texture = _body_spinning


# Idempotent, and called from _exit_tree as well - a plane freed mid-run
# (scene rebuild, reassignment) must not leave the runway flagged busy
# forever, which would stall every aircraft behind it.
func _release_runway() -> void:
	if not _holds_runway:
		return
	_holds_runway = false
	RunwayControl.release()


func _exit_tree() -> void:
	_release_runway()


func _show_idle_rotors() -> void:
	for rotor in _rotors_idle:
		rotor.visible = true
	for rotor in _rotors_spin:
		rotor.visible = false
	if _shadow and _shadow_parked:
		_shadow.texture = _shadow_parked
	if _body and _body_parked:
		_body.texture = _body_parked


# Keeps the parked position current (aprons can be re-placed with the apron
# editor) without re-running setup() - setup() adds fresh child sprites on
# every call, so re-running it per rebuild would stack duplicates. Leaves a
# plane that's mid-arrival/departure alone rather than snapping it back.
func sync_position(screen_pos: Vector2) -> void:
	_home_position = screen_pos
	if not _animating:
		position = screen_pos


func play_arrival() -> void:
	_animating = true
	if _is_vtol:
		_play_vertical_landing()
		return
	_play_runway_arrival()


# Flies the traced approach, then fades out and reappears parked at the
# apron. Nothing traced yet -> stays put at the apron, same as before.
func _play_runway_arrival() -> void:
	var path_data := PathLayout.load_effective()
	var body_points := PathLayout.points_to_vectors(path_data.get("plane_arrival_body", []))
	if body_points.is_empty():
		_settle_at_home()
		return
	var shadow_points := PathLayout.points_to_vectors(path_data.get("plane_arrival_shadow", []))
	if shadow_points.is_empty():
		shadow_points = body_points

	_show_spin_rotors()

	# Jump to the start of the approach, invisible. Sprite art faces left
	# unflipped, so flip only when actually heading right.
	position = body_points[0]
	scale.x = -1.0 if body_points[-1].x >= body_points[0].x else 1.0
	modulate.a = 0.0
	if _shadow:
		_shadow.global_position = shadow_points[0]

	# Holds off the approach until the strip is clear - invisible, so it
	# reads as still being out on the inbound leg. Landings jump the queue
	# ahead of departures (see RunwayControl.acquire).
	await RunwayControl.acquire(self, true)
	if not is_instance_valid(self):
		return
	_holds_runway = true

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION) \
		.set_trans(Tween.TRANS_LINEAR)
	# Decelerating - the mirror of the departure's accelerating climb.
	tween.parallel().tween_method(
		func(u: float) -> void: _on_travel_progress(u, body_points, shadow_points),
		0.0, 1.0, ARRIVAL_TRAVEL_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(_settle_at_home)
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION) \
		.set_trans(Tween.TRANS_LINEAR)


# Descends straight down onto the apron - the mirror of
# _play_vertical_liftoff, for models that never touch the runway.
func _play_vertical_landing() -> void:
	_show_spin_rotors()
	position = _home_position
	if not _body:
		_settle_at_home()
		return

	_body.position = BODY_BASE_OFFSET + Vector2(0, -VTOL_RISE_DISTANCE)
	_body.modulate.a = 0.0
	if _shadow:
		_shadow.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(_body, "position:y", BODY_BASE_OFFSET.y, VTOL_RISE_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_body, "modulate:a", 1.0, VTOL_RISE_DURATION * 0.4) \
		.set_trans(Tween.TRANS_LINEAR)
	if _shadow:
		tween.parallel().tween_property(_shadow, "modulate:a", 1.0, VTOL_RISE_DURATION) \
			.set_trans(Tween.TRANS_LINEAR)
	# Downwash builds as it drops in - it's only near the ground that the
	# rotor wash actually hits the pad. Timed to peak exactly at touchdown
	# (delay + duration == the descent), so it neither finishes early nor
	# drags the sequence out past the landing.
	if _ground_effect:
		_ground_effect.visible = true
		_ground_effect.modulate.a = 0.0
		var wash_in := minf(GROUND_EFFECT_FADE_DURATION, VTOL_RISE_DURATION)
		tween.parallel().tween_property(_ground_effect, "modulate:a", 1.0, wash_in) \
			.set_delay(VTOL_RISE_DURATION - wash_in) \
			.set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(_settle_at_home)


# Parked state - everything back to the neutral pose the apron expects.
func _settle_at_home() -> void:
	_animating = false
	# A landing holds the strip right through touchdown (no-op for VTOLs,
	# which never took it).
	_release_runway()
	position = _home_position
	scale.x = 1.0
	modulate.a = 1.0
	if _body:
		_body.position = BODY_BASE_OFFSET
		_body.modulate.a = 1.0
	if _shadow:
		_shadow.position = Vector2.ZERO
		_shadow.modulate.a = 1.0
	if _ground_effect:
		_ground_effect.visible = false
	_show_idle_rotors()


# Small diagonal shift (up-left, then down-right, repeated
# STARTUP_WOBBLE_REPEATS times, then back to start) instead of rotating in
# place - reads as the aircraft settling/bracing before it moves, not
# spinning on the spot.
# Same diagonal axis as the startup wobble, just smaller/faster. Meant to
# be driven by a looping tween, so it has no settle-back step - whoever
# kills the loop restores the resting position.
func _add_idle_shake(tween: Tween, origin: Vector2) -> void:
	var up_left := origin + Vector2(-1, -1).normalized() * IDLE_SHAKE_DISTANCE
	var down_right := origin + Vector2(1, 1).normalized() * IDLE_SHAKE_DISTANCE
	tween.tween_property(self, "position", up_left, IDLE_SHAKE_DURATION) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position", down_right, IDLE_SHAKE_DURATION) \
		.set_trans(Tween.TRANS_SINE)


func _add_startup_wobble(tween: Tween) -> void:
	var start_pos := position
	var up_left := start_pos + Vector2(-1, -1).normalized() * STARTUP_WOBBLE_DISTANCE
	var down_right := start_pos + Vector2(1, 1).normalized() * STARTUP_WOBBLE_DISTANCE
	for i in range(STARTUP_WOBBLE_REPEATS):
		tween.tween_property(self, "position", up_left, STARTUP_DURATION * 0.4) \
			.set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "position", down_right, STARTUP_DURATION * 0.4) \
			.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position", start_pos, STARTUP_DURATION * 0.2) \
		.set_trans(Tween.TRANS_SINE)


# `delay` staggers a mass departure. Dispatching a full airport sends every
# aircraft on the same tick, and 110 takeoffs igniting on one frame - each
# spinning up tweens, rotors and a downwash - is a visible hitch. Spreading
# them over a few frames costs nothing and looks better besides: an airport
# emptying in sequence reads as traffic, all at once reads as a glitch.
func play_departure(delay: float = 0.0) -> void:
	_animating = true
	if delay > 0.0:
		# Bound to this node, so freeing it mid-wait cancels cleanly rather
		# than firing into a freed object.
		await get_tree().create_timer(delay).timeout
		if not is_instance_valid(self):
			return
	if _is_vtol:
		_play_vertical_liftoff()
		return
	_play_runway_departure()


# Straight up from wherever it's currently parked - no runway track, no
# shadow movement. The shadow stays behind on the ground (self never moves,
# and the shadow has no offset of its own) and fades out quickly while the
# body climbs away on its own local offset.
func _play_vertical_liftoff() -> void:
	_show_spin_rotors()

	# Fades across the whole climb, starting only once it actually leaves
	# the pad - a short fixed fade from t=0 had the shadow gone before the
	# aircraft had climbed a third of the way, which just read as a missing
	# shadow.
	if _shadow:
		var shadow_tween := _shadow.create_tween()
		shadow_tween.tween_interval(STARTUP_DURATION)
		shadow_tween.tween_property(_shadow, "modulate:a", 0.0, VTOL_RISE_DURATION) \
			.set_trans(Tween.TRANS_LINEAR)

	# Downwash on the pad, fading out as it climbs out of ground effect. On
	# its own tween, like the shadow - chaining it onto the main sequence
	# with parallel() made its delay extend that step, which held the climb
	# back until the fade had finished.
	if _ground_effect:
		_ground_effect.visible = true
		_ground_effect.modulate.a = 1.0
		var wash_tween := _ground_effect.create_tween()
		wash_tween.tween_interval(STARTUP_DURATION)
		wash_tween.tween_property(_ground_effect, "modulate:a", 0.0, minf(GROUND_EFFECT_FADE_DURATION, VTOL_RISE_DURATION)) \
			.set_trans(Tween.TRANS_LINEAR)

	var tween := create_tween()

	# 1. Startup wobble (rotor/engine spin-up), same flavor as a runway
	# departure's warm-up.
	_add_startup_wobble(tween)

	# 2. Rise straight up (the body's own local offset, not self.position,
	# so the shadow - a separate child - is unaffected), accelerating away
	# and fading out near the top of the climb.
	tween.tween_property(_body, "position:y", BODY_BASE_OFFSET.y - VTOL_RISE_DISTANCE, VTOL_RISE_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_body, "modulate:a", 0.0, VTOL_RISE_DURATION * 0.4) \
		.set_delay(VTOL_RISE_DURATION * 0.6) \
		.set_trans(Tween.TRANS_LINEAR)

	tween.tween_callback(queue_free)


func _play_runway_departure() -> void:
	var path_data := PathLayout.load_effective()
	# Falls back to staying put (and the shadow falls back to riding glued
	# to the body) if these haven't been traced yet with PathEditor (press T
	# in-game) - harmless no-op instead of a crash. Read with .get(): paths
	# are per-airport now, so an airport nobody has traced yet has no keys at
	# all, not empty ones.
	var body_points := PathLayout.points_to_vectors(path_data.get("plane_body", []))
	if body_points.is_empty():
		body_points = [position]
	var shadow_points := PathLayout.points_to_vectors(path_data.get("plane_shadow", []))
	if shadow_points.is_empty():
		shadow_points = body_points
	var facing_right := body_points[-1].x >= body_points[0].x

	_show_spin_rotors()

	# 1. Startup wobble, held at the apron until the runway is clear. Waiting
	# here (visible, rotors turning) rather than after the fade-out means a
	# queued plane reads as holding for clearance instead of vanishing.
	var warmup := create_tween()
	_add_startup_wobble(warmup)
	await warmup.finished
	if not is_instance_valid(self):
		return

	# Keeps idling on the spot for as long as it's queued - a plane sitting
	# perfectly still with its rotors turning looks frozen, so it holds a
	# smaller, faster version of the wobble until it gets the runway.
	var hold_pos := position
	var idle := create_tween()
	idle.set_loops()
	_add_idle_shake(idle, hold_pos)

	await RunwayControl.acquire(self)
	if not is_instance_valid(self):
		return
	idle.kill()
	position = hold_pos
	_holds_runway = true

	var tween := create_tween()

	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION) \
		.set_trans(Tween.TRANS_LINEAR)

	# 2. Teleport + flip to the runway entry, still invisible. Sprite's
	# unflipped art faces left, so flip only when actually heading right.
	tween.tween_callback(func() -> void:
		position = body_points[0]
		scale.x = -1.0 if facing_right else 1.0
		if _shadow:
			_shadow.global_position = shadow_points[0]
	)

	# 3. Fade in while travelling body and shadow along their own separately
	# traced paths, speeding up the whole way (reference footage shows it
	# visibly accelerating over the runway - measured centroid deltas
	# roughly double by the last third).
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.parallel().tween_method(
		func(u: float) -> void: _on_travel_progress(u, body_points, shadow_points),
		0.0, 1.0, TRAVEL_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Hand the runway over once it's airborne and clear, rather than holding
	# it for the full flight out - otherwise a queue of four crawls.
	var handover := create_tween()
	handover.tween_interval(FADE_IN_DURATION + TRAVEL_DURATION * RUNWAY_RELEASE_FRACTION)
	handover.tween_callback(_release_runway)

	# 4. Off-canvas - remove it, no fade-out at the far end.
	tween.tween_callback(queue_free)


func _on_travel_progress(u: float, body_points: Array[Vector2], shadow_points: Array[Vector2]) -> void:
	position = PathLayout.position_along_path(body_points, u)
	if _shadow:
		_shadow.global_position = PathLayout.position_along_path(shadow_points, u)
