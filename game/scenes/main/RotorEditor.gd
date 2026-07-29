extends Node2D

# Manual placement tool for propeller/rotor hub offsets - no more guessing
# pixel positions off the source art. Drops a full-size live preview of the
# model (body + every rotor overlay, using the current offsets) wherever
# the camera is currently centered, so you can see exactly what you're
# aligning while you place it.
#
#   R          toggle rotor placement mode on/off (drops the preview at the
#              current camera center)
#   M          cycle which aircraft model you're rigging
#   1-9        select which rotor hub you're placing (models with a single
#              prop, like the P-51, only use 1)
#   click      set the selected rotor's position - preview updates live
#
# Saves immediately to res://data/aircraft_rig.json, one entry per model.

const MODEL_KEYS := ["v22", "p51", "blackh"]
const MARKER_RADIUS := 5.0
const ROTOR_COLORS := [Color(1, 0.3, 0.3, 0.9), Color(0.3, 0.6, 1, 0.9), Color(0.3, 1, 0.5, 0.9)]

var editing := false
var model_index := 0
var selected := 0
var _offsets: Array[Vector2] = []
var _reference_pos := Vector2.ZERO
var _preview_body: Sprite2D
var _preview_rotors: Array[Sprite2D] = []
var _hud_layer: CanvasLayer
var _hud_label: Label


func _ready() -> void:
	_build_hud()


func _model_key() -> String:
	return MODEL_KEYS[model_index]


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			editing = !editing
			if editing:
				_drop_preview()
			else:
				_clear_preview()
			_update_hud()
		elif editing and event.keycode == KEY_M:
			model_index = wrapi(model_index + 1, 0, MODEL_KEYS.size())
			selected = 0
			_drop_preview()
			_update_hud()
		elif editing and event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx: int = event.keycode - KEY_1
			if idx < _offsets.size():
				selected = idx
				_update_hud()

	if not editing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_place(get_global_mouse_position())


func _drop_preview() -> void:
	_clear_preview()
	var cam := get_viewport().get_camera_2d()
	_reference_pos = cam.get_screen_center_position() if cam else Vector2.ZERO

	_offsets = AircraftRig.get_rotor_offsets(_model_key())
	if _offsets.is_empty():
		_offsets = [Vector2.ZERO]

	var sprites: Dictionary = Fleet.WORLD_SPRITES.get(_model_key(), {})
	_preview_body = Sprite2D.new()
	_preview_body.texture = load(sprites["body"])
	_preview_body.position = _reference_pos
	add_child(_preview_body)

	# Prefer the stationary "idle" look for the preview since that's what's
	# actually visible while parked; models with no idle art (like the P-51)
	# fall back to the first spin frame just so there's something to align.
	var preview_frames: Array = sprites.get("rotor_idle_frames", sprites["rotor_spin_frames"])
	var preview_texture: Texture2D = load(preview_frames[0])
	_preview_rotors.clear()
	for offset in _offsets:
		var rotor := Sprite2D.new()
		rotor.texture = preview_texture
		rotor.position = offset
		_preview_body.add_child(rotor)
		_preview_rotors.append(rotor)


func _clear_preview() -> void:
	if _preview_body:
		_preview_body.queue_free()
	_preview_body = null
	_preview_rotors.clear()


func _place(pos: Vector2) -> void:
	_offsets[selected] = pos - _reference_pos
	_preview_rotors[selected].position = _offsets[selected]

	var data := AircraftRig.load_data()
	var stored: Array = []
	for o in _offsets:
		stored.append([o.x, o.y])
	data[_model_key()] = stored
	AircraftRig.save_data(data)
	queue_redraw()
	_update_hud()


func _draw() -> void:
	if not editing:
		return
	for i in range(_offsets.size()):
		var p := _reference_pos + _offsets[i]
		var color: Color = ROTOR_COLORS[i % ROTOR_COLORS.size()]
		if i != selected:
			color = Color(color.r, color.g, color.b, 0.4)
		draw_circle(p, MARKER_RADIUS, color)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 50
	_hud_layer.visible = false
	add_child(_hud_layer)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12, 12)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	_hud_layer.add_child(panel)

	_hud_label = Label.new()
	_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_label.add_theme_color_override("font_color", Color.WHITE)
	_hud_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(_hud_label)


func _update_hud() -> void:
	_hud_layer.visible = editing
	if not editing:
		return
	var lines: Array[String] = [
		"ROTOR EDITOR - %s  (R to exit, M to switch model)" % _model_key(),
		"",
		"Selected: rotor %d" % (selected + 1),
	]
	for i in range(_offsets.size()):
		lines.append("  rotor %d offset: (%.1f, %.1f)" % [i + 1, _offsets[i].x, _offsets[i].y])
	lines.append("")
	lines.append("1-%d = select rotor   click = place it" % _offsets.size())
	_hud_label.text = "\n".join(lines)
