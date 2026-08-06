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
const COUNTDOWN_FONT_SIZE := 15
const COUNTDOWN_COLOR := Color(0.85, 0.88, 0.95, 0.85)

var _tick := 0.0


func _ready() -> void:
	FuelStore.price_changed.connect(func(_p: int) -> void: queue_redraw())
	queue_redraw()


# The countdown is the only thing here that moves between price changes, and it
# only needs to move once a second. Skipped entirely while the shop is closed.
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))

	draw_string(
		ThemeDB.fallback_font, Vector2(MARGIN, HEADER_HEIGHT - 10),
		"Current Price: $%d/unit" % FuelStore.current_price,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - MARGIN * 2.0, HEADER_FONT_SIZE, Color.WHITE
	)

	# What the price does next, and when. Without it "the market moves hourly"
	# is a rule the player can only infer by standing here for an hour - and
	# waiting out a bad price is supposed to be a decision, not a gamble.
	draw_string(
		ThemeDB.fallback_font, Vector2(MARGIN, HEADER_HEIGHT - 11),
		"new price in %s" % _countdown(FuelStore.seconds_until_next_price()),
		HORIZONTAL_ALIGNMENT_RIGHT, size.x - MARGIN * 2.0,
		COUNTDOWN_FONT_SIZE, COUNTDOWN_COLOR
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


func _countdown(secs: float) -> String:
	var t := int(ceilf(secs))
	if t >= 3600:
		return "%dh %02dm" % [t / 3600, (t % 3600) / 60]
	if t >= 60:
		return "%dm" % (t / 60)
	return "%ds" % t
