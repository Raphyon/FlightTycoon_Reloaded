extends Node2D

# Generic click-to-trace path placement, replacing the old fixed 3-point
# RunwayEditor - works like the apron/cloud placement tools, but each click
# appends a point and draws a line back to the previous one instead of
# placing an independent point.
#
#   T          toggle path placement mode on/off
#   1          departure body path (its take-off flight track)
#   2          departure shadow path (its own ground track)
#   3          arrival body path (the landing approach)
#   4          arrival shadow path
#   5          select roads - N starts a brand new road, click appends to
#              whichever road you started/selected most recently
#   N          (roads mode only) start a new road
#   C          (roads mode only) toggle the active road's category between
#              commercial and airport - vehicles never cross between them
#   [ / ]      (roads mode only) cycle which existing road is active
#   X          (roads mode only) delete the whole active road
#   H          hide/show the cloud cover - locked-zone clouds sit right on
#              top of the ground the shadow paths run across, so they have
#              to come off to line a shadow up. Purely visual, stays put
#              until toggled back (it does not touch zone unlock state).
#   click      append a point to whatever's currently selected
#   right click undo the last point on whatever's currently selected
#
# Saves immediately to res://data/paths.json. Markers and the status HUD
# only draw while editing is on, so the normal view stays clean.

signal roads_changed

enum Target { BODY, SHADOW, ARRIVAL_BODY, ARRIVAL_SHADOW, ROAD }

# Everything except ROAD is a single plain point list in PathLayout - keyed
# here so adding another one is a table entry, not four new match arms.
const PLANE_TARGETS := {
	Target.BODY: {"key": "plane_body", "label": "DEPART BODY", "color": Color(0.2, 0.9, 0.4, 0.9)},
	Target.SHADOW: {"key": "plane_shadow", "label": "DEPART SHADOW", "color": Color(0.2, 0.55, 0.9, 0.9)},
	Target.ARRIVAL_BODY: {"key": "plane_arrival_body", "label": "ARRIVE BODY", "color": Color(1.0, 0.4, 0.8, 0.9)},
	Target.ARRIVAL_SHADOW: {"key": "plane_arrival_shadow", "label": "ARRIVE SHADOW", "color": Color(0.65, 0.35, 0.95, 0.9)},
}
const TARGET_KEYS := [Target.BODY, Target.SHADOW, Target.ARRIVAL_BODY, Target.ARRIVAL_SHADOW, Target.ROAD]

const POINT_RADIUS := 6.0
const ROAD_COLORS := {
	"commercial": Color(0.9, 0.85, 0.2, 0.9),
	"airport": Color(0.9, 0.4, 0.2, 0.9),
}
const INACTIVE_ALPHA := 0.35

var editing := false
var target := Target.BODY
var data: Dictionary = {}
var _active_road: String = ""
var _hud_layer: CanvasLayer
var _hud_label: Label


func _ready() -> void:
	data = PathLayout.load_data()
	if data["roads"].size() > 0:
		_active_road = data["roads"].keys()[0]
	_build_hud()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			editing = !editing
			queue_redraw()
			_update_hud()
		elif editing:
			_handle_edit_key(event.keycode)

	if not editing:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_append_point(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			_undo_point()


func _handle_edit_key(keycode: int) -> void:
	if keycode >= KEY_1 and keycode <= KEY_5:
		target = TARGET_KEYS[keycode - KEY_1]
	elif target == Target.ROAD and keycode == KEY_N:
		_active_road = "road_%d" % (data["roads"].size() + 1)
		data["roads"][_active_road] = {"category": "commercial", "points": []}
		PathLayout.save_data(data)
		roads_changed.emit()
		queue_redraw()
	elif target == Target.ROAD and keycode == KEY_C and _active_road != "":
		var road: Dictionary = data["roads"][_active_road]
		road["category"] = "airport" if road["category"] == "commercial" else "commercial"
		PathLayout.save_data(data)
		roads_changed.emit()
		queue_redraw()
	elif target == Target.ROAD and (keycode == KEY_BRACKETLEFT or keycode == KEY_BRACKETRIGHT):
		_cycle_active_road(1 if keycode == KEY_BRACKETRIGHT else -1)
	elif target == Target.ROAD and keycode == KEY_X and _active_road != "":
		_delete_active_road()
	elif keycode == KEY_H:
		var clouds: Node2D = get_node("../Clouds")
		clouds.visible = not clouds.visible
	_update_hud()


func _cycle_active_road(direction: int) -> void:
	var names: Array = data["roads"].keys()
	if names.is_empty():
		return
	var idx := names.find(_active_road)
	idx = wrapi(idx + direction, 0, names.size())
	_active_road = names[idx]
	queue_redraw()


# The one-feature-to-remove-if-necessary case: right-click only undoes the
# last point, so a whole botched road needs its own explicit delete.
func _delete_active_road() -> void:
	data["roads"].erase(_active_road)
	PathLayout.save_data(data)
	roads_changed.emit()
	var names: Array = data["roads"].keys()
	_active_road = names[0] if names.size() > 0 else ""
	queue_redraw()


func _current_points() -> Array:
	if target == Target.ROAD:
		if _active_road == "":
			return []
		return data["roads"][_active_road]["points"]
	return data[PLANE_TARGETS[target]["key"]]


func _append_point(pos: Vector2) -> void:
	var points := _current_points()
	if target == Target.ROAD and _active_road == "":
		_update_hud()
		return
	points.append([pos.x, pos.y])
	PathLayout.save_data(data)
	if target == Target.ROAD:
		roads_changed.emit()
	queue_redraw()
	_update_hud()


func _undo_point() -> void:
	var points := _current_points()
	if points.is_empty():
		return
	points.remove_at(points.size() - 1)
	PathLayout.save_data(data)
	if target == Target.ROAD:
		roads_changed.emit()
	queue_redraw()
	_update_hud()


func _draw() -> void:
	if not editing:
		return
	for plane_target in PLANE_TARGETS:
		var spec: Dictionary = PLANE_TARGETS[plane_target]
		_draw_path(data[spec["key"]], spec["color"], target == plane_target)
	for road_name in data["roads"].keys():
		var road: Dictionary = data["roads"][road_name]
		var is_active: bool = target == Target.ROAD and road_name == _active_road
		_draw_path(road["points"], ROAD_COLORS[road["category"]], is_active)


func _draw_path(points: Array, color: Color, active: bool) -> void:
	if not active:
		color = Color(color.r, color.g, color.b, INACTIVE_ALPHA)
	for i in range(points.size()):
		var p := Vector2(points[i][0], points[i][1])
		draw_circle(p, POINT_RADIUS, color)
		if i > 0:
			var prev := Vector2(points[i - 1][0], points[i - 1][1])
			draw_line(prev, p, color, 2.0)


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

	var lines: Array[String] = ["PATH EDITOR  (T to exit)", ""]
	if target == Target.ROAD:
		if _active_road == "":
			lines.append("Editing: ROADS - none yet, press N")
		else:
			var road: Dictionary = data["roads"][_active_road]
			lines.append("Editing: %s [%s] - %d pts" % [_active_road, road["category"], road["points"].size()])
		lines.append("Roads total: %d" % data["roads"].size())
	else:
		var spec: Dictionary = PLANE_TARGETS[target]
		lines.append("Editing: %s - %d pts" % [spec["label"], data[spec["key"]].size()])
	lines.append("")
	lines.append("1 depart body    2 depart shadow")
	lines.append("3 arrive body    4 arrive shadow    5 roads")
	lines.append("click = add point   right-click = undo point")
	lines.append("H = clouds %s" % ["SHOWN" if get_node("../Clouds").visible else "HIDDEN"])
	if target == Target.ROAD:
		lines.append("N = new road   C = toggle category")
		lines.append("[ / ] = switch road   X = delete whole road")

	_hud_label.text = "\n".join(lines)
