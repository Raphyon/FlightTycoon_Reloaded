extends Node2D

# PLACE THE PAD BADGE BY EYE, ONCE, AND EVERY PAD TAKES IT.
#
# The badge sits at the same offset on all 110 pads, so there is exactly one
# number to get right and no reason to get it right by arithmetic. I placed it
# three times from the geometry and it was wrong three times; the pad is a
# diamond seen in projection and "the bottom left corner" is not a thing you can
# solve for without looking at it.
#
# Switched on from the F1 menu, like the other placement tools.
#
#   click on any pad   put the badge where you clicked, on EVERY pad
#   arrow keys         nudge one unit, shift for ten
#   S                  print the value to stdout, to be pasted into ApronSlot
#
# It writes nothing. The offset is one constant in ApronSlot and belongs in the
# source next to the art it positions, not in a data file that has to be loaded
# before a pad can draw itself.
# Preloaded rather than named: ApronSlot has no class_name, and adding one to
# reach a static would mean a fresh checkout that will not parse until an editor
# rescan has run. Same reason PanelManager is loaded by path.
const ApronSlotScript := preload("res://scenes/main/ApronSlot.gd")

const NUDGE := 1.0
const NUDGE_FAST := 10.0

var editing := false:
	set(value):
		editing = value
		set_process_unhandled_input(value)
		if value:
			print("BADGE PLACER on - click a pad, arrows nudge, S prints. now %s"
				% ApronSlotScript.badge_offset)
		_redraw_pads()


func _ready() -> void:
	set_process_unhandled_input(false)


func _redraw_pads() -> void:
	var aprons := get_node_or_null("../Aprons")
	if aprons == null:
		return
	for slot in aprons.get_children():
		if slot.has_method("queue_redraw"):
			slot.queue_redraw()


# The pad nearest the click. Nearest-centre rather than a hit test: the badge is
# being placed at the EDGE of a pad, and half the useful positions are outside
# the diamond a hit test would check.
func _pad_at(world: Vector2) -> Node2D:
	var aprons := get_node_or_null("../Aprons")
	if aprons == null:
		return null
	var best: Node2D = null
	var best_d := INF
	for slot in aprons.get_children():
		if not (slot is Node2D):
			continue
		var d: float = (slot as Node2D).global_position.distance_squared_to(world)
		if d < best_d:
			best_d = d
			best = slot
	return best


func _unhandled_input(event: InputEvent) -> void:
	if not editing:
		return

	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var world: Vector2 = get_global_mouse_position()
		var pad := _pad_at(world)
		if pad:
			ApronSlotScript.badge_offset = (world - pad.global_position).round()
			print("BADGE offset %s" % ApronSlotScript.badge_offset)
			_redraw_pads()
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey and event.pressed):
		return
	var key := event as InputEventKey
	var step: float = NUDGE_FAST if key.shift_pressed else NUDGE
	var delta := Vector2.ZERO
	match key.keycode:
		KEY_LEFT: delta = Vector2(-step, 0)
		KEY_RIGHT: delta = Vector2(step, 0)
		KEY_UP: delta = Vector2(0, -step)
		KEY_DOWN: delta = Vector2(0, step)
		KEY_S:
			print("static var badge_offset := Vector2(%.0f, %.0f)" % [
				ApronSlotScript.badge_offset.x, ApronSlotScript.badge_offset.y])
			get_viewport().set_input_as_handled()
			return
		_:
			return
	ApronSlotScript.badge_offset += delta
	print("BADGE offset %s" % ApronSlotScript.badge_offset)
	_redraw_pads()
	get_viewport().set_input_as_handled()
