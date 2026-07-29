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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if _dragging:
				_drag_start_mouse = event.position
				_drag_start_camera = position
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(_target_zoom / ZOOM_STEP)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(_target_zoom * ZOOM_STEP)
	elif event is InputEventMouseMotion and _dragging:
		position = _drag_start_camera - (event.position - _drag_start_mouse) * zoom
	elif event is InputEventPanGesture:
		# macOS trackpad two-finger scroll - doesn't come through as a mouse wheel event.
		_apply_zoom(_target_zoom * pow(ZOOM_STEP, event.delta.y))
	elif event is InputEventMagnifyGesture:
		# macOS trackpad pinch-to-zoom.
		_apply_zoom(_target_zoom / event.factor)


func _apply_zoom(new_zoom: float) -> void:
	_target_zoom = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
