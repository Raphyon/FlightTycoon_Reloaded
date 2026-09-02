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

# ROUND WHERE THE THING UNDERNEATH IS ROUND. Everything that dims through this
# is a rectangular card except the shop hub, whose categories are discs on a
# transparent field - and a full-rect dim there drew a black SQUARE around a
# circular icon, which reads as a broken asset rather than as a locked one.
# Off by default so every existing caller is untouched.
#
# The disc fills most of its box but is not centred in it: the source art is
# 217x231 with the disc at y 47..197, so scaled into a square slot it sits a
# little low and a little left of centre. These are that measurement.
var circular := false
const DISC_CENTRE := Vector2(0.485, 0.53)
const DISC_RADIUS := 0.335


func _draw() -> void:
	if circular:
		var r: float = minf(size.x, size.y) * DISC_RADIUS
		draw_circle(size * DISC_CENTRE, r, DIM)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), DIM)

	var side := minf(size.x, size.y) * LOCK_SCALE
	var lock_size := Vector2(side * LOCK.get_width() / LOCK.get_height(), side)
	draw_texture_rect(LOCK, Rect2((size - lock_size) * 0.5, lock_size), false)
