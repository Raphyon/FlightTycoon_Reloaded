extends Node2D

@export var half_extent: int = 20
@export var line_color: Color = Color(1, 1, 1, 0.35)

# Just a general debug reference grid now (no area uses grid snapping any
# more), so this is a fixed default rather than tied to a specific area.
var origin := Vector2(752.5, 1290.4)


func _ready() -> void:
	# Visibility lives on DebugState so the G key and the debug menu can't
	# disagree about whether the grid is on.
	DebugState.flags_changed.connect(queue_redraw)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_G:
		DebugState.toggle_flag(&"show_grid")


func _draw() -> void:
	if not DebugState.show_grid:
		return
	for i in range(-half_extent, half_extent + 1):
		draw_line(
			IsoGrid.grid_to_screen(Vector2(i, -half_extent), origin),
			IsoGrid.grid_to_screen(Vector2(i, half_extent), origin),
			line_color
		)
		draw_line(
			IsoGrid.grid_to_screen(Vector2(-half_extent, i), origin),
			IsoGrid.grid_to_screen(Vector2(half_extent, i), origin),
			line_color
		)
