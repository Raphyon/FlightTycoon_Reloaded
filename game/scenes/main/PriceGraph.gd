extends Control

# Simple trailing line chart of FuelStore.price_history - procedurally
# drawn, not tracing any specific chart art, same approach as LockOverlay.
# Current price is drawn as a header inside the graph box itself.
const LINE_COLOR := Color(0.95, 0.75, 0.25, 1.0)
const POINT_COLOR := Color(1.0, 0.9, 0.5, 1.0)
const GRID_COLOR := Color(1, 1, 1, 0.15)
const MARGIN := 8.0
const HEADER_HEIGHT := 34.0
const HEADER_FONT_SIZE := 22


func _ready() -> void:
	FuelStore.price_changed.connect(func(_p: int) -> void: queue_redraw())
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))

	draw_string(
		ThemeDB.fallback_font, Vector2(MARGIN, HEADER_HEIGHT - 10),
		"Current Price: $%d/unit" % FuelStore.current_price,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - MARGIN * 2.0, HEADER_FONT_SIZE, Color.WHITE
	)

	var chart_top := HEADER_HEIGHT
	var chart_h := size.y - HEADER_HEIGHT - MARGIN
	for i in range(1, 4):
		var y := chart_top + chart_h * i / 4.0
		draw_line(Vector2(MARGIN, y), Vector2(size.x - MARGIN, y), GRID_COLOR, 1.0)

	var history := FuelStore.price_history
	if history.size() < 2:
		return

	var lo := FuelStore.BASE_PRICE * (1.0 - FuelStore.PRICE_SWING) - 1.0
	var hi := FuelStore.BASE_PRICE * (1.0 + FuelStore.PRICE_SWING) + 1.0
	var w := size.x - MARGIN * 2.0
	var n := history.size()

	var points := PackedVector2Array()
	for i in range(n):
		var x := MARGIN + w * (float(i) / float(n - 1))
		var t := inverse_lerp(lo, hi, float(history[i]))
		var y := chart_top + chart_h * (1.0 - clampf(t, 0.0, 1.0))
		points.append(Vector2(x, y))

	draw_polyline(points, LINE_COLOR, 2.0, true)
	for p in points:
		draw_circle(p, 3.0, POINT_COLOR)
