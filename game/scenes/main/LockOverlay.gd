extends Control

# Dims a shop card and stamps a padlock over it.
#
# The padlock is the source game's own icon, rasterised from its SVG by
# tools/svg_icon.py. This used to be a rectangle and an arc drawn in code,
# deliberately generic because no lock art existed. It does now.
const LOCK := preload("res://assets/hud/icon_lock.png")

const DIM := Color(0, 0, 0, 0.55)
# Fraction of the card's short side the padlock spans.
const LOCK_SCALE := 0.42


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DIM)

	var side := minf(size.x, size.y) * LOCK_SCALE
	var lock_size := Vector2(side * LOCK.get_width() / LOCK.get_height(), side)
	draw_texture_rect(LOCK, Rect2((size - lock_size) * 0.5, lock_size), false)
