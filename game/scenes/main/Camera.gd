extends Camera2D

const ZOOM_STEP := 1.1
const MIN_ZOOM := 0.3
const MAX_ZOOM := 2.5
const ZOOM_SMOOTHING := 10.0

var _dragging := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_camera := Vector2.ZERO
var _target_zoom := 1.0


func _process(delta: float) -> void:
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
	var half: Vector2 = get_viewport_rect().size * 0.5 * zoom
	var lo := Vector2(limit_left + half.x, limit_top + half.y)
	var hi := Vector2(limit_right - half.x, limit_bottom - half.y)
	# A map smaller than the view has no room to pan on that axis - sit in the
	# middle of it rather than snapping to a corner.
	return Vector2(
		clampf(p.x, lo.x, hi.x) if lo.x <= hi.x else (limit_left + limit_right) * 0.5,
		clampf(p.y, lo.y, hi.y) if lo.y <= hi.y else (limit_top + limit_bottom) * 0.5,
	)


func _apply_zoom(new_zoom: float) -> void:
	_target_zoom = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	# Zooming out grows the view, which can push a legal position out of range.
	position = _clamp_to_limits(position)
