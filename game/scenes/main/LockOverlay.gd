extends Control

# Simple generic padlock drawn in code - not tracing anyone's specific icon
# art, just a rectangle + an arc.


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))

	var cx := size.x * 0.5
	var body_w := size.x * 0.32
	var body_h := size.y * 0.26
	var body_top := size.y * 0.56

	var shackle_r := body_w * 0.4
	var shackle_center := Vector2(cx, body_top)
	draw_arc(shackle_center, shackle_r, PI, TAU, 24, Color(0.95, 0.95, 0.95), 4.0)
	draw_rect(Rect2(cx - body_w * 0.5, body_top, body_w, body_h), Color(0.95, 0.95, 0.95), true)
