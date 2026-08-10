class_name ClickDrag
extends RefCounted

# Tells a CLICK apart from a PAN, for the in-game placement tools.
#
# THE BUG THIS EXISTS TO STOP, which has now been written four times and got it
# wrong twice: the camera pans by left-drag and listens in _unhandled_input, so
# an editor that marks the left PRESS handled stops the camera ever seeing it
# and kills panning outright while that tool is open. Eating the RELEASE instead
# is just as bad - Camera clears _dragging on release, so swallowing it leaves
# the view panning forever.
#
# The answer is to swallow neither and act on release only if the pointer barely
# moved. Drag to look around, click to place.
#
#     var _click := ClickDrag.new()
#     ...
#     if _click.completed(event):
#         _place(get_global_mouse_position())
#
# Nothing here consumes the event - that is the point.

# How far the pointer may travel between press and release and still count as a
# click. Small enough that a deliberate drag never places anything, large enough
# that a shaky hand on a trackpad still can.
const SLOP := 6.0

var _pressed := false
var _at := Vector2.ZERO


# True exactly once per click: on the release that follows a press near the same
# spot. Returns false for the press, for a release that travelled, and for
# everything that is not this mouse button.
func completed(event: InputEvent, button: int = MOUSE_BUTTON_LEFT) -> bool:
	if not (event is InputEventMouseButton) or event.button_index != button:
		return false
	if event.pressed:
		_pressed = true
		_at = event.position
		return false
	if not _pressed:
		return false
	_pressed = false
	return event.position.distance_to(_at) <= SLOP


# Call when a tool is switched off, so a press that started inside it cannot
# complete as a click after it closes.
func reset() -> void:
	_pressed = false
