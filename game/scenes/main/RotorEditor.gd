extends Node2D

# Manual placement tool for propeller/rotor hubs and afterburner nozzles - no more guessing
# pixel positions off the source art. Drops a full-size live preview of the
# model (body + every rotor overlay, using the current offsets) wherever
# the camera is currently centered, so you can see exactly what you're
# aligning while you place it.
#
#   Switched on from the F1 menu - no toggle key. Turning it on drops the
#   preview at the current camera centre.
#   Escape     leave the tool. It used to be the F1 menu or nothing, and
#              reaching the menu means clicking, which this reads before the
#              GUI does - so closing it placed one last thing on the way out.
#   E          switch between ROTOR hubs and EXHAUST nozzles. The same tool
#              pointed at a different list on the same model - a nozzle and a
#              rotor both want a position, a size and a z-order placed against
#              a live preview.
#   M          cycle which aircraft model you're rigging
#   1-9        select which rotor hub you're placing (models with a single
#              prop, like the P-51, only use 1)
#   click      set the selected rotor's position - preview updates live
#   B          toggle whether the selected rotor draws behind the fuselage
#              (an inboard prop on the far wing is partly hidden by the hull,
#              so its disc must not paint over it)
#   - / +      shrink/grow the selected rotor's disc (also , and .). The propliners borrow the
#              A400M's prop art at four different airframe sizes, so a disc
#              placed perfectly can still be the wrong size - without this the
#              guessing would just move from position to scale.
#
# Saves immediately to res://data/aircraft_rig.json, one entry per model.

const WorldAircraftScript := preload("res://scenes/main/WorldAircraft.gd")
const MARKER_RADIUS := 5.0
const SCALE_STEP := 0.05
const SCALE_MIN := 0.2
const SCALE_MAX := 3.0
# One distinct colour per hub. Needs to cover the largest rotor count in the
# fleet - the A400M's four turboprops wrapped a three-colour list, giving
# rotors 1 and 4 the same marker with no way to tell them apart while placing.
const ROTOR_COLORS := [
	Color(1, 0.3, 0.3, 0.9),      # 1 red
	Color(0.3, 0.6, 1, 0.9),      # 2 blue
	Color(0.3, 1, 0.5, 0.9),      # 3 green
	Color(1, 0.85, 0.25, 0.9),    # 4 yellow
	Color(0.85, 0.45, 1, 0.9),    # 5 violet
	Color(0.3, 0.95, 0.95, 0.9),  # 6 cyan
]

# A SETTER, not a plain flag. The F1 menu switches editors by assigning to this
# directly (DebugMenu._on_editor_toggled), so anything that has to happen when
# the tool goes away has to hang off the assignment.
#
# Without it the tool DID switch off - every handler is guarded on `editing` -
# but nothing redrew, so its on-screen readout stayed up and it looked like the
# thing would not close. It bit the cloud tool first and was fixed piecemeal;
# every remaining tool carries the setter now.
var editing := false:
	set(value):
		if editing == value:
			return
		editing = value
		if is_inside_tree():
			# THE PREVIEW BELONGS TO THE TOOL, so it arrives and leaves with it.
			# _drop_preview was only ever called by the M key, which meant the
			# tool opened showing nothing until you cycled a model, and - worse -
			# closing it left a full-size aircraft parked in the world with no
			# way to get rid of it. The header has claimed this behaviour since
			# it was written; now it is true.
			if editing:
				_drop_preview()
			else:
				_clear_preview()
			_update_hud()
			queue_redraw()
var model_index := 0
var selected := 0
# Discovered from Fleet.WORLD_SPRITES rather than hardcoded: a fixed list left
# the A400M unreachable here the moment it joined the fleet, which is exactly
# the failure that makes a manual placement tool useless.
var _model_keys: Array[String] = []
var _offsets: Array[Vector2] = []
var _behind: Array[bool] = []
var _scales: Array[float] = []
# EXHAUST MODE. The same tool, pointed at a different list on the same model: a
# nozzle and a rotor hub both want a position, a size and a z-order placed
# against a live preview, so they share the editor rather than growing a second
# one. E switches.
var _exhaust_mode := false
var _reference_pos := Vector2.ZERO
var _preview_body: Sprite2D
var _preview_rotors: Array[Sprite2D] = []
var _hud: EditorHud


func _ready() -> void:
	for key in Fleet.WORLD_SPRITES:
		var s: Dictionary = Fleet.WORLD_SPRITES[key]
		if s.has("rotor_spin_frames") or s.has("rotors") or s.has("exhaust_offsets"):
			_model_keys.append(key)
	_model_keys.sort()
	_hud = EditorHud.create(self)


# -1, 0 or +1 step from what was actually typed. Brackets still work for anyone
# whose layout has them somewhere reachable.
func _scale_step(event: InputEventKey) -> float:
	match char(event.unicode):
		"-", "_", ",":
			return -SCALE_STEP
		"+", "=", ".":
			return SCALE_STEP
	if event.keycode == KEY_BRACKETLEFT:
		return -SCALE_STEP
	if event.keycode == KEY_BRACKETRIGHT:
		return SCALE_STEP
	return 0.0


func _model_key() -> String:
	return _model_keys[model_index] if model_index < _model_keys.size() else ""


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# NO TOGGLE KEY. Every tool was holding a letter hostage across the
		# whole game - P, O, T, R, G, L, Z - and two of them collided (G was
		# both this and the grid overlay). They are switched on from the F1
		# menu now, which is the only debug key left. The keys BELOW still
		# work, but only while this tool is on, so they cost nothing.
		if editing and event.keycode == KEY_ESCAPE:
			# A WAY OUT THAT IS NOT A CLICK. Every tool was left only through
			# the F1 menu, and reaching the menu means pressing the mouse,
			# which these tools read before the GUI does. Escape costs no
			# letter - it is not a placement key in any of them.
			editing = false
			return
		if editing and event.keycode == KEY_E:
			_exhaust_mode = not _exhaust_mode
			selected = 0
			_drop_preview()
			_update_hud()
			return
		if editing and event.keycode == KEY_M:
			model_index = wrapi(model_index + 1, 0, _model_keys.size())
			selected = 0
			_drop_preview()
			_update_hud()
		elif editing and event.keycode == KEY_B:
			if selected < _behind.size():
				_behind[selected] = not _behind[selected]
				_apply_behind()
				_save()
				_update_hud()
		elif editing and _scale_step(event) != 0.0:
			# Matched on the CHARACTER rather than the keycode: keycode is what
			# the key means under the current keyboard layout, and on a Nordic
			# one the key that types "-" is not KEY_MINUS and "[" is Alt+8. The
			# bracket bindings this replaced worked on a US layout and nowhere
			# else.
			if selected < _scales.size():
				var step := _scale_step(event)
				_scales[selected] = clampf(_scales[selected] + step, SCALE_MIN, SCALE_MAX)
				_apply_scales()
				_save()
				_update_hud()
		elif editing and event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx: int = event.keycode - KEY_1
			if idx < _offsets.size():
				selected = idx
				_update_hud()

	if not editing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if EditorHud.over_gui(self):
			return
		get_viewport().set_input_as_handled()
		_place(get_global_mouse_position())


func _drop_preview() -> void:
	_clear_preview()
	var sprites: Dictionary = Fleet.WORLD_SPRITES.get(_model_key(), {})
	if not sprites.has("body") or not (sprites.has("rotor_spin_frames") or sprites.has("rotors")):
		return
	var cam := get_viewport().get_camera_2d()
	_reference_pos = cam.get_screen_center_position() if cam else Vector2.ZERO

	if _exhaust_mode:
		_offsets = AircraftRig.get_exhaust_offsets(_model_key())
		_scales = AircraftRig.get_exhaust_scales(_model_key())
		_behind = []
	else:
		_offsets = AircraftRig.get_rotor_offsets(_model_key())
		_behind = AircraftRig.get_rotor_behind(_model_key())
		_scales = AircraftRig.get_rotor_scales(_model_key())
	if _offsets.is_empty():
		_offsets = [Vector2.ZERO]
	while _behind.size() < _offsets.size():
		_behind.append(false)
	while _scales.size() < _offsets.size():
		_scales.append(1.0)

	_preview_body = Sprite2D.new()
	_preview_body.texture = load(sprites["body"])
	_preview_body.position = _reference_pos
	add_child(_preview_body)

	# Each hub previews its own art, resolved through the same rule the game
	# uses (WorldAircraft.hub_frames) - a helicopter's tail rotor must not
	# preview as a second main rotor, or you'd be aligning the wrong sprite.
	# Prefer the stationary "idle" look since that's what's visible while
	# parked; hubs with no idle art (the P-51, the A400M) fall back to the
	# first spin frame just so there's something to align.
	_preview_rotors.clear()
	for i in range(_offsets.size()):
		var paths: Array = []
		if _exhaust_mode:
			paths = WorldAircraftScript.EXHAUST_FRAMES
		else:
			var frames: Dictionary = WorldAircraftScript.hub_frames(sprites, i)
			var idle: Array = frames["idle"]
			var spin: Array = frames["spin"]
			paths = idle if not idle.is_empty() else spin
		if paths.is_empty():
			continue
		var rotor := Sprite2D.new()
		rotor.texture = load(paths[0])
		rotor.position = _offsets[i]
		if _exhaust_mode:
			# Previewed exactly as the game draws it: rotated to the airframe's
			# own slope, and anchored at the NOZZLE rather than at the middle of
			# the flame, or you would be aligning the centre of a plume that is
			# half inside the hull.
			rotor.rotation = deg_to_rad(-float(sprites.get("exhaust_angle", 0.0)))
			rotor.offset = Vector2(
				rotor.texture.get_width() * 0.5 - WorldAircraftScript.EXHAUST_ANCHOR.x, 0.0)
			var glow := CanvasItemMaterial.new()
			glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			rotor.material = glow
		_preview_body.add_child(rotor)
		_preview_rotors.append(rotor)
	_apply_behind()
	_apply_scales()


func _clear_preview() -> void:
	if _preview_body:
		_preview_body.queue_free()
	_preview_body = null
	_preview_rotors.clear()


func _place(pos: Vector2) -> void:
	_offsets[selected] = pos - _reference_pos
	_preview_rotors[selected].position = _offsets[selected]
	_save()
	queue_redraw()
	_update_hud()


# Mirrors the flag onto the live preview so B shows its effect immediately.
func _apply_behind() -> void:
	for i in range(_preview_rotors.size()):
		_preview_rotors[i].show_behind_parent = i < _behind.size() and _behind[i]


# Same, for [ and ].
func _apply_scales() -> void:
	for i in range(_preview_rotors.size()):
		var s: float = _scales[i] if i < _scales.size() else 1.0
		_preview_rotors[i].scale = Vector2.ONE * s


func _save() -> void:
	var data := AircraftRig.load_data()
	var stored: Array = []
	for i in range(_offsets.size()):
		# Always written as [x, y, behind, scale] - a shorter entry means that
		# field was never set, which AircraftRig reads as deferring to the
		# model default rather than overriding it with a neutral value.
		stored.append([
			_offsets[i].x, _offsets[i].y,
			1 if (i < _behind.size() and _behind[i]) else 0,
			_scales[i] if i < _scales.size() else 1.0,
		])
	data[AircraftRig.rig_key(_model_key(), _exhaust_mode)] = stored
	AircraftRig.save_data(data)


func _draw() -> void:
	if not editing:
		return
	for i in range(_offsets.size()):
		var p := _reference_pos + _offsets[i]
		var color: Color = ROTOR_COLORS[i % ROTOR_COLORS.size()]
		if i != selected:
			color = Color(color.r, color.g, color.b, 0.4)
		draw_circle(p, MARKER_RADIUS, color)


func _update_hud() -> void:
	if not editing:
		_hud.set_lines(false, [])
		return
	var what := "EXHAUST" if _exhaust_mode else "ROTOR"
	var noun := "nozzle" if _exhaust_mode else "rotor"
	var lines: Array[String] = [
		"%s EDITOR - %s  [%d/%d]  (Escape to exit, M model, E rotors/exhaust)"
			% [what, _model_key(), model_index + 1, _model_keys.size()],
		"",
		"Selected: %s %d" % [noun, selected + 1],
	]
	for i in range(_offsets.size()):
		var tag := "" if _exhaust_mode else (
			"  BEHIND hull" if (i < _behind.size() and _behind[i]) else "")
		var s: float = _scales[i] if i < _scales.size() else 1.0
		lines.append("  %s %d offset: (%.1f, %.1f)  scale %.2f%s"
			% [noun, i + 1, _offsets[i].x, _offsets[i].y, s, tag])
	lines.append("")
	if _exhaust_mode:
		lines.append("1-%d = select nozzle   click = place it   - + = size"
			% _offsets.size())
	else:
		lines.append("1-%d = select rotor   click = place it   B = behind/front   - + = size"
			% _offsets.size())
	_hud.set_lines(true, lines)
