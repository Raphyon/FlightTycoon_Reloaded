extends Camera2D

const ZOOM_STEP := 1.1
const MIN_ZOOM := 0.3
const MAX_ZOOM := 2.5
const ZOOM_SMOOTHING := 10.0

# How far past the outermost thing you own the view may reach. Enough to see a
# pad's whole tile plus a little air, not enough to show the next zone.
const EDGE_MARGIN := 130.0

# The smallest a limit box may be, as a multiple of the visible area.
#
# On a fresh save the only unlocked thing is Zone1, whose twenty pads bound a
# box of 1221x740. That is SMALLER THAN THE SCREEN, so _clamp_to_limits parks
# the camera dead centre with nowhere to go and the view reads as frozen - the
# same "stuck" the placement tools hit, but in normal play. The box now always
# leaves at least this much slack around the view, so panning is never a no-op
# even when you own almost nothing.
#
# It does not defeat the gating: 1.15 of a screen is a nudge, not enough to see
# into the next zone, and everything beyond it is still cloud.
const MIN_VIEW_FACTOR := 1.15

var _dragging := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_camera := Vector2.ZERO
var _target_zoom := 1.0
var _editor_was_active := false


func _ready() -> void:
	# The camera shows what you OWN, and grows as you buy. On a fresh game that
	# is Zone1 alone, which is also what keeps the building plots out of sight
	# until Zone2 opens - they sit south-west of Zone1 and are not inside its
	# box at all, so no special case is needed for them.
	ZoneProgress.unlocked_changed.connect(_fit_limits_to_unlocked)
	Maps.map_changed.connect(_on_map_changed)
	# _min_zoom is measured against the viewport, so a resized window
	# changes how far out is legal.
	get_tree().root.size_changed.connect(_refit)
	call_deferred("_fit_limits_to_unlocked")


func _on_map_changed(_map_key: String) -> void:
	_refit()


# The bounding box of every apron in an unlocked area, plus the building plots
# once there are any to see. Falls back to the scene's authored limits if an
# airport has nothing unlocked yet, so the camera can never end up with an
# inside-out box it cannot clamp into.
# Any placement tool being open means the whole airport, not just the part you
# have paid for. AUTHORING IS NOT PLAYING: the zone editor exists to draw
# regions over the building district, which sits outside Zone1 entirely - so on
# a fresh save the camera would not let you reach the thing the tool is for. The
# landmark editor has the same problem with the terminal.
func _editor_active() -> bool:
	var world := get_parent()
	if world == null:
		return false
	for child in world.get_children():
		# THE PROPERTY, not the name. This matched on a node called something
		# ending in "Editor", which happens to be true today and is not a fact
		# about anything - rename a node and the camera silently stops
		# unlocking the map while you place. Owning an `editing` flag that is
		# true IS the definition of an editor being active.
		if "editing" in child and child.editing:
			return true
	return false


# Re-clamp the zoom as well as the limits. Travelling from homeland to the
# carrier shrinks the world from 3072 wide to 2304, so a zoom that was legal a
# moment ago now shows past the edge - and nothing else would notice.
func _refit() -> void:
	_apply_zoom(_target_zoom)
	_fit_limits_to_unlocked()


func _fit_limits_to_unlocked() -> void:
	if _editor_active():
		var size := Maps.size_for()
		limit_left = 0
		limit_top = 0
		limit_right = size.x
		limit_bottom = size.y
		return
	var pts: Array[Vector2] = []
	var layout := ApronLayout.effective_area_data()
	for area_name in layout:
		if not ZoneProgress.is_unlocked(area_name):
			continue
		for p in layout[area_name]:
			pts.append(Vector2(float(p[0]), float(p[1])))
	# Plots count one zone at a time, not all at once. Every plot joining the
	# box the moment Zone2 was bought is why an airport's whole city could be
	# built inside two hours - see ZoneRegions for the regions this reads.
	if BuildingProgress.buildings_unlocked():
		for plot in BuildingLayout.load_data():
			if BuildingProgress.plot_is_available(int(plot.get("id", 0))):
				pts.append(Vector2(float(plot.get("x", 0.0)), float(plot.get("y", 0.0))))
	if pts.is_empty():
		return
	var lo := pts[0]
	var hi := pts[0]
	for v in pts:
		lo = lo.min(v)
		hi = hi.max(v)
	_apply_limits(lo - Vector2(EDGE_MARGIN, EDGE_MARGIN),
		hi + Vector2(EDGE_MARGIN, EDGE_MARGIN))


# Grows the box about its own centre until it is at least MIN_VIEW_FACTOR of the
# visible area, then clips it to the map so it cannot reach past the edge of the
# world. Written once here because every caller wants the same guarantee.
func _apply_limits(lo: Vector2, hi: Vector2) -> void:
	var view: Vector2 = get_viewport_rect().size / zoom * MIN_VIEW_FACTOR
	var centre := (lo + hi) * 0.5
	var half := Vector2(maxf((hi.x - lo.x) * 0.5, view.x * 0.5),
		maxf((hi.y - lo.y) * 0.5, view.y * 0.5))
	lo = centre - half
	hi = centre + half
	var world := Vector2(Maps.size_for())
	# Shift rather than shrink if it overhangs, or a small box at the map edge
	# would lose the slack it was just given.
	if lo.x < 0.0:
		hi.x -= lo.x
		lo.x = 0.0
	if lo.y < 0.0:
		hi.y -= lo.y
		lo.y = 0.0
	if hi.x > world.x:
		lo.x -= hi.x - world.x
		hi.x = world.x
	if hi.y > world.y:
		lo.y -= hi.y - world.y
		hi.y = world.y
	limit_left = int(maxf(0.0, lo.x))
	limit_top = int(maxf(0.0, lo.y))
	limit_right = int(minf(world.x, hi.x))
	limit_bottom = int(minf(world.y, hi.y))
	position = _clamp_to_limits(position)


func _process(delta: float) -> void:
	# Editors are toggled from the F1 menu and from their own hotkeys, neither
	# of which tells the camera anything - so the state is polled. One bool a
	# frame against a handful of siblings.
	var active := _editor_active()
	if active != _editor_was_active:
		_editor_was_active = active
		_fit_limits_to_unlocked()
	if not is_equal_approx(zoom.x, _target_zoom):
		var z := lerpf(zoom.x, _target_zoom, clampf(delta * ZOOM_SMOOTHING, 0.0, 1.0))
		zoom = Vector2(z, z)


# The world must not ZOOM while the pointer is over a menu.
#
# Only zoom. _unhandled_input already handles clicks correctly - a Control that
# wants a press consumes it - but a ScrollContainer only consumes a wheel event
# when it has somewhere left to scroll, so reaching either end of the routes
# list spilled the wheel through and zoomed the airport out from under the
# panel. Applying this to dragging as well stopped panning working at all,
# because a drag that begins over the world can pass under a HUD element
# mid-gesture.
func _pointer_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# No UI guard on the drag: a Control that wants a click consumes it
			# before this ever runs, so reaching here already means the press
			# landed on the world. Guarding it as well broke panning outright.
			_dragging = event.pressed
			if _dragging:
				_drag_start_mouse = event.position
				# Start from a legal position, so a drag that begins in the
				# dead zone doesn't have to travel out of it first.
				_drag_start_camera = _clamp_to_limits(position)
				position = _drag_start_camera
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if not _pointer_over_ui():
				_apply_zoom(_target_zoom / ZOOM_STEP)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not _pointer_over_ui():
				_apply_zoom(_target_zoom * ZOOM_STEP)
	elif event is InputEventMouseMotion and _dragging:
		var to: Vector2 = event.position
		position = _clamp_to_limits(_drag_start_camera - (to - _drag_start_mouse) * zoom)
	elif event is InputEventPanGesture:
		# macOS trackpad two-finger scroll - doesn't come through as a mouse wheel event.
		if not _pointer_over_ui():
			_apply_zoom(_target_zoom * pow(ZOOM_STEP, event.delta.y))
	elif event is InputEventMagnifyGesture:
		# macOS trackpad pinch-to-zoom.
		if not _pointer_over_ui():
			_apply_zoom(_target_zoom / event.factor)


# Camera2D clamps the VIEW to its limits but leaves `position` wherever you put
# it. A position outside the limits therefore looks identical to the nearest
# legal one, and dragging out of that dead zone moves nothing on screen until
# it crosses back in - which reads as the camera being frozen no matter where
# you grab. Keeping position itself legal makes every pixel of a drag count.
func _clamp_to_limits(p: Vector2) -> Vector2:
	# viewport / zoom, NOT viewport * zoom. Godot 4 zoom magnifies: the visible
	# world is the viewport DIVIDED by it. Multiplying made the half-extent
	# shrink as you zoomed out, so the clamp loosened at exactly the moment the
	# view was growing past the map edge - which is how the carrier could be
	# panned onto white.
	var half: Vector2 = get_viewport_rect().size * 0.5 / zoom
	var lo := Vector2(limit_left + half.x, limit_top + half.y)
	var hi := Vector2(limit_right - half.x, limit_bottom - half.y)
	# A map smaller than the view has no room to pan on that axis - sit in the
	# middle of it rather than snapping to a corner.
	var out := Vector2(
		clampf(p.x, lo.x, hi.x) if lo.x <= hi.x else (limit_left + limit_right) * 0.5,
		clampf(p.y, lo.y, hi.y) if lo.y <= hi.y else (limit_top + limit_bottom) * 0.5,
	)
	# AND THE WORLD, not only the limit box. The box is fitted to unlocked
	# aprons and can be far smaller than the view - and when it is, the fallback
	# above centres on the BOX, which may sit near the map edge and leave half a
	# screen of surround showing. Where the world has room, the view stays in it.
	var world := Vector2(Maps.size_for())
	if world.x >= half.x * 2.0:
		out.x = clampf(out.x, half.x, world.x - half.x)
	if world.y >= half.y * 2.0:
		out.y = clampf(out.y, half.y, world.y - half.y)
	return out


# The furthest out this MAP allows: any less and the view is wider or taller
# than the world, and the surround shows through. The carrier is the tight one
# at 2304x1792 - a flat MIN_ZOOM of 0.3 shows 3840x2160 there, which is most of
# a screen of white.
func _min_zoom() -> float:
	var world := Vector2(Maps.size_for())
	if world.x <= 0.0 or world.y <= 0.0:
		return MIN_ZOOM
	var view := get_viewport_rect().size
	return maxf(MIN_ZOOM, maxf(view.x / world.x, view.y / world.y))


func _apply_zoom(new_zoom: float) -> void:
	_target_zoom = clampf(new_zoom, _min_zoom(), MAX_ZOOM)
	# Zooming out grows the view, which can push a legal position out of range.
	position = _clamp_to_limits(position)
