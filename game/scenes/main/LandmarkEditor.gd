extends Node2D

# Manual placement for fixed scenery - the terminal to begin with.
#
# Same reason as every other editor in here: nothing measured exists for these
# positions, and working them out from the art has gone badly before.
#
#   L          toggle landmark placement on/off
#   left click place the selected landmark, or MOVE the one already placed
#   M          cycle which landmark you are placing
#   - / +      shrink/grow the placed landmark, saved with it. Also bound to
#              , and . - the rotor editor uses [ and ], which on a Nordic
#              keyboard are Alt+8 and Alt+9 and no use to anybody. The right
#              size is a judgement made by looking at it in the world: the
#              terminal art's own palms measure against the background's palms
#              one way and against the sprite sheet's another, and the two
#              disagree by a factor of 1.6, so it is sized by eye rather than
#              solved.
#   X          delete the placed landmark of the current kind
#
# One of each kind per airport. A second terminal is not a thing, so clicking
# again moves the one that exists rather than stacking another on top of it -
# which is the failure the apron editor's remove-by-clicking exists to undo.
#
# Saves immediately to res://data/landmark_layout.json, per airport.

const GHOST_ALPHA := 0.5
const SCALE_STEP := 0.05
const SCALE_MIN := 0.1
const SCALE_MAX := 3.0
# How far the pointer may travel between press and release and still count as a
# click rather than a pan.
const CLICK_SLOP := 6.0

# A SETTER, not a plain flag: the F1 menu turns editors on by assigning to this
# directly (DebugMenu._on_editor_toggled), so anything that has to happen when
# the tool wakes up - the ghost, the readout, letting clicks through - has to
# hang off the assignment rather than off the L key. Toggling from the menu did
# nothing visible at all until this.
var editing := false:
	set(value):
		if editing == value:
			return
		editing = value
		_pressed = false
		if editing:
			scale_factor = _placed_scale(_kind())
		_sync_ghost()
		_update_hud()
		_set_world_pickable(not editing)
var kind_index := 0
# The working size. Applied to the placed landmark AND to the ghost, so it can
# be set BEFORE anything is placed - resizing used to no-op silently until
# something existed to resize, with no hint that was the reason.
var scale_factor := 1.0

var _ghost: Sprite2D
var _hud: EditorHud
var _press_at := Vector2.ZERO
var _pressed := false


func _ready() -> void:
	_hud = EditorHud.create(self)
	Maps.map_changed.connect(func(_k: String) -> void: _update_hud())


func _kind() -> String:
	var keys := LandmarkLayout.keys()
	return str(keys[kind_index]) if kind_index < keys.size() else ""


# _input, NOT _unhandled_input. A click in the world almost always lands on an
# apron or a building slot, whose Area2D claims it through physics picking
# before an unhandled-input handler ever sees it - so placement silently did
# nothing anywhere there was already something to click. Same reason
# BuildingEditor and the other three use _input.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_L:
				editing = not editing
				return
			KEY_M:
				if editing:
					kind_index = wrapi(kind_index + 1, 0, LandmarkLayout.keys().size())
					scale_factor = _placed_scale(_kind())
					_sync_ghost()
					_update_hud()
			KEY_X:
				if editing:
					_remove()
			_:
				pass
		# MATCHED ON THE CHARACTER, not the keycode. keycode is what the key
		# means under the CURRENT KEYBOARD LAYOUT, and on a Nordic keyboard the
		# key that types "-" does not report KEY_MINUS - so the binding worked
		# on a US layout and nowhere else. event.unicode is what was actually
		# typed, which is what the on-screen help promises.
		if editing:
			match char(event.unicode):
				"-", "_", ",":
					_resize(-SCALE_STEP)
				"+", "=", ".":
					_resize(SCALE_STEP)
	if not editing:
		return
	if event is InputEventMouseMotion and is_instance_valid(_ghost):
		_ghost.position = get_global_mouse_position()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# PLACED ON RELEASE, AND NOTHING IS SWALLOWED.
		#
		# The camera pans by left-drag and listens in _unhandled_input, so
		# marking the press handled - which is what this did - stopped the
		# camera ever seeing it and killed panning outright while the tool was
		# on. Consuming the RELEASE instead is just as bad: the camera sets
		# _dragging=false on release, so eating it leaves the view panning
		# forever.
		#
		# So the press is let through untouched and a placement happens on
		# release only if the pointer barely moved. Drag to pan, click to
		# place, and the aprons are already unpickable (see _set_world_pickable)
		# so there is nothing else under the cursor to fire.
		if event.pressed:
			_pressed = true
			_press_at = event.position
		elif _pressed:
			_pressed = false
			if event.position.distance_to(_press_at) <= CLICK_SLOP:
				_place(get_global_mouse_position())


func _place(pos: Vector2) -> void:
	var key := _kind()
	if key == "":
		return
	var data := LandmarkLayout.load_data()
	var found := false
	for entry in data:
		if str(entry.get("key", "")) == key:
			entry["x"] = pos.x
			entry["y"] = pos.y
			found = true
			break
	if not found:
		data.append({"key": key, "x": pos.x, "y": pos.y, "scale": scale_factor})
	LandmarkLayout.save_data(data)
	print("%s %s at (%d,%d)" % ["Moved" if found else "Placed", key,
		roundi(pos.x), roundi(pos.y)])
	_refresh_world()
	_update_hud()


# Resizes the placed landmark if there is one, and the ghost either way.
func _resize(by: float) -> void:
	var key := _kind()
	scale_factor = clampf(scale_factor + by, SCALE_MIN, SCALE_MAX)
	var data := LandmarkLayout.load_data()
	for entry in data:
		if str(entry.get("key", "")) == key:
			entry["scale"] = scale_factor
			LandmarkLayout.save_data(data)
			_refresh_world()
			break
	if is_instance_valid(_ghost):
		_ghost.scale = Vector2(scale_factor, scale_factor)
	print("%s scale %.2f  (%d px wide)" % [key, scale_factor,
		roundi(_base_width(key) * scale_factor)])
	_update_hud()


# The size this kind is already at, so cycling to it picks up where it was left
# rather than snapping the ghost back to 1.0.
func _placed_scale(key: String) -> float:
	for entry in LandmarkLayout.load_data():
		if str(entry.get("key", "")) == key:
			return float(entry.get("scale", 1.0))
	return scale_factor


func _base_width(key: String) -> float:
	var path := LandmarkLayout.texture_path(key)
	if path == "" or not ResourceLoader.exists(path):
		return 0.0
	return float((load(path) as Texture2D).get_width())


func _remove() -> void:
	var key := _kind()
	var data := LandmarkLayout.load_data()
	var out: Array = []
	for entry in data:
		if str(entry.get("key", "")) != key:
			out.append(entry)
	if out.size() == data.size():
		return
	LandmarkLayout.save_data(out)
	print("Removed %s" % key)
	_refresh_world()
	_update_hud()


# Aprons and building slots stop taking clicks while this is on, so a terminal
# can be placed on top of them. Same thing BuildingEditor does with its slots.
func _set_world_pickable(on: bool) -> void:
	for node_name in ["Aprons", "Buildings"]:
		var layer := get_node_or_null("../%s" % node_name)
		if layer == null:
			continue
		for child in layer.get_children():
			if child.has_method("set_pickable"):
				child.set_pickable(on)


func _refresh_world() -> void:
	var node := get_node_or_null("../Landmarks")
	if node and node.has_method("rebuild"):
		node.rebuild()


# A full-size translucent copy under the cursor, because a 760px building placed
# by its ground point is impossible to aim without seeing where it lands.
func _sync_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
		_ghost = null
	if not editing:
		return
	var path := LandmarkLayout.texture_path(_kind())
	if path == "" or not ResourceLoader.exists(path):
		return
	_ghost = Sprite2D.new()
	_ghost.texture = load(path)
	_ghost.centered = false
	_ghost.offset = Vector2(-_ghost.texture.get_width() * 0.5, -_ghost.texture.get_height())
	_ghost.modulate = Color(1, 1, 1, GHOST_ALPHA)
	_ghost.z_index = 500
	_ghost.scale = Vector2(scale_factor, scale_factor)
	_ghost.position = get_global_mouse_position()
	add_child(_ghost)


func _update_hud() -> void:
	if _hud == null:
		return
	var placed := {}
	for entry in LandmarkLayout.load_data():
		placed[str(entry.get("key", ""))] = [
			Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0))),
			float(entry.get("scale", 1.0))]
	var lines: Array = [
		"LANDMARK EDITOR - %s  (L to exit)" % Maps.display_name(),
		"",
	]
	var keys := LandmarkLayout.keys()
	for i in range(keys.size()):
		var k := str(keys[i])
		var where := "not placed"
		if placed.has(k):
			var pos: Vector2 = placed[k][0]
			var sc: float = placed[k][1]
			where = "(%d,%d)  x%.2f  = %d px" % [pos.x, pos.y, sc,
				roundi(_base_width(k) * sc)]
		lines.append("%s %-12s %s" % [">" if i == kind_index else " ", k, where])
	lines.append("")
	lines.append("click = place/move  ·  M = next  ·  - + = size  ·  X = delete")
	_hud.set_lines(editing, lines)
