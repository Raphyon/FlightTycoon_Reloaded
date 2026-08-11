extends Node2D

# Draw the zones. One polygon per area, clicked corner by corner.
#
#   Switched on from the F1 menu - no toggle key, see _input.
#   1-7        pick which area you are drawing
#   left click add a corner to the current area
#   right clic remove the LAST corner
#   C          clear the current area entirely
#   H          hide/show the fills, so you can see the ground under them
#
# Saves immediately to res://data/zone_regions.json, per airport.
#
# WHY. Aprons know their zone because you told the apron editor which area you
# were placing into. Building plots are just an id and a position, so nothing
# could say which zone a plot belongs to - and every plot became reachable the
# moment Zone2 was bought, which is why an airport's whole city fills in two
# hours. Drawing the regions answers it for plots and for anything else placed
# by position later.
#
# Deliberately NOT snapped to anything. Zone edges follow painted ground in the
# background art - a runway, a treeline, a road - and no lattice this project
# has matches all of them.

const AREA_COLORS := [
	Color(0.35, 0.75, 1.0),    # Zone1
	Color(0.45, 1.0, 0.55),    # Zone2
	Color(0.75, 0.55, 1.0),    # DarkZone
	Color(1.0, 0.85, 0.35),    # Forest
	Color(1.0, 0.55, 0.35),    # Desert
	Color(0.45, 1.0, 0.95),    # Beach
	Color(1.0, 0.55, 0.75),    # Snow
]
const FILL_ALPHA := 0.22
const LINE_WIDTH := 3.0
const HANDLE_RADIUS := 6.0

var editing := false:
	set(value):
		if editing == value:
			return
		editing = value
		_click.reset()
		_update_hud()
		queue_redraw()
var area_index := 0
var show_fills := true

var _regions: Dictionary = {}   # area_name -> PackedVector2Array
var _click := ClickDrag.new()
var _hud: EditorHud


func _ready() -> void:
	_hud = EditorHud.create(self)
	Maps.map_changed.connect(func(_k: String) -> void: reload())
	reload()


func reload() -> void:
	_regions = ZoneRegions.load_data()
	area_index = 0
	_update_hud()
	queue_redraw()


func _areas() -> Array:
	return Maps.areas_for()


func _area() -> String:
	var a := _areas()
	return str(a[area_index]) if area_index < a.size() else ""


# _input, not _unhandled_input - an apron or a building slot claims world
# clicks through physics picking first. Same reason the other editors use it.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			# No toggle key - the F1 menu switches this on. See ApronEditor.
			KEY_C:
				if editing:
					_regions.erase(_area())
					_save()
			KEY_H:
				if editing:
					show_fills = not show_fills
					queue_redraw()
			_:
				if editing and event.keycode >= KEY_1 and event.keycode <= KEY_7:
					var i: int = event.keycode - KEY_1
					if i < _areas().size():
						area_index = i
						_update_hud()
						queue_redraw()
	if not editing:
		return
	# Corners go down on RELEASE and nothing is swallowed, so a left-drag still
	# pans - see ClickDrag.
	if _click.completed(event):
		_add_corner(get_global_mouse_position())
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		_drop_corner()


func _add_corner(pos: Vector2) -> void:
	var key := _area()
	if key == "":
		return
	var poly: PackedVector2Array = _regions.get(key, PackedVector2Array())
	poly.append(pos)
	_regions[key] = poly
	_save()


func _drop_corner() -> void:
	var key := _area()
	var poly: PackedVector2Array = _regions.get(key, PackedVector2Array())
	if poly.is_empty():
		return
	poly.remove_at(poly.size() - 1)
	_regions[key] = poly
	_save()


func _save() -> void:
	ZoneRegions.save_data(_regions)
	_update_hud()
	queue_redraw()
	# The camera's limits are built from which plots are reachable, and that now
	# depends on these shapes - so redrawing a zone has to re-fit it.
	var cam := get_node_or_null("../Camera2D")
	if cam and cam.has_method("_fit_limits_to_unlocked"):
		cam._fit_limits_to_unlocked()


func _color(i: int) -> Color:
	return AREA_COLORS[i % AREA_COLORS.size()]


func _draw() -> void:
	if not editing:
		return
	var areas := _areas()
	for i in range(areas.size()):
		var key := str(areas[i])
		var poly: PackedVector2Array = _regions.get(key, PackedVector2Array())
		if poly.is_empty():
			continue
		var c := _color(i)
		var current := i == area_index
		if show_fills and poly.size() >= 3:
			var fill := c
			fill.a = FILL_ALPHA * (1.6 if current else 1.0)
			draw_colored_polygon(poly, fill)
		if poly.size() >= 2:
			var loop := poly.duplicate()
			loop.append(poly[0])
			draw_polyline(loop, c, LINE_WIDTH if current else 1.5)
		for v in poly:
			draw_circle(v, HANDLE_RADIUS if current else 3.0, c)

	# Every plot, tinted by the zone it currently falls in - white means no
	# region contains it yet. This is the whole point of the tool, so it is
	# drawn while editing rather than hidden behind another toggle.
	var plots := BuildingLayout.load_data()
	var pts: Array = []
	for p in plots:
		pts.append(Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))))
	var owners := ZoneRegions.areas_for_points(pts)
	for j in range(pts.size()):
		var owner := str(owners[j])
		var col := Color.WHITE
		if owner != "":
			col = _color(maxi(0, areas.find(owner)))
		draw_circle(pts[j], 7.0, col)
		draw_arc(pts[j], 10.0, 0.0, TAU, 16, Color(0, 0, 0, 0.6), 2.0)


func _update_hud() -> void:
	if _hud == null:
		return
	var areas := _areas()
	var pts: Array = []
	for p in BuildingLayout.load_data():
		pts.append(Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))))
	var owners := ZoneRegions.areas_for_points(pts)
	var counts := {}
	for o in owners:
		counts[str(o)] = int(counts.get(str(o), 0)) + 1

	var lines: Array = [
		"ZONE EDITOR - %s  (F1 to switch off)" % Maps.display_name(),
		"",
	]
	for i in range(areas.size()):
		var key := str(areas[i])
		var poly: PackedVector2Array = _regions.get(key, PackedVector2Array())
		lines.append("%s %d  %-10s %2d corners   %2d plots" % [
			">" if i == area_index else " ", i + 1, key, poly.size(),
			int(counts.get(key, 0))])
	lines.append("")
	lines.append("unassigned plots: %d of %d" % [int(counts.get("", 0)), pts.size()])
	lines.append("click = corner  ·  right click = undo  ·  C clear  ·  H fills")
	_hud.set_lines(editing, lines)
