extends Control

# The left-edge tab that opens the daily tasks, where the reference game puts
# its DAILY REWARD gift box.
#
# DRAWN IN CODE, ON PURPOSE. There is no gift-box art in the dump - nothing for
# DAILY REWARD, PURCHASE BONUS or EVENT - so this is a placeholder built from
# the coin icon we do have. Swapping in real art is replacing the TextureRect
# below and deleting _draw; the behaviour does not change.
#
# IT REPORTS PROGRESS AT A GLANCE. Three pips, one per task, filled as they
# complete - so the tab answers "is there anything to do today" without being
# opened, which is the entire job of a thing sitting on the edge of the screen.
# When the set is claimable it pulses, because at that point there IS something
# to collect and a static icon would not say so.

const ICON_COIN := preload("res://assets/hud/icon_medium_coin@2x.png")

const TAB_SIZE := Vector2(84, 92)
const EDGE_MARGIN := 12.0
# How far down the left edge, as a fraction of screen height. A QUARTER, not
# half: that is where the reference game puts its NEWS icon, with the daily
# reward gift box directly beneath it. Proportional rather than a pixel offset
# so it holds its place on a screen of any height.
const EDGE_HEIGHT_FRACTION := 0.25
const PULSE_PERIOD := 1.4

const COLOR_PLATE := Color(0.20, 0.13, 0.09, 0.86)
const COLOR_EDGE := Color(1.0, 0.82, 0.42, 0.55)
const COLOR_EDGE_READY := Color(1.0, 0.88, 0.44)
const COLOR_PIP_ON := Color(0.49, 0.84, 0.48)
const COLOR_PIP_OFF := Color(0, 0, 0, 0.45)
const COLOR_LABEL := Color(1.0, 0.91, 0.76)

var _button: Button
var _icon: TextureRect
var _age := 0.0


func _ready() -> void:
	# Left edge, a quarter of the way down - where the reference game's NEWS
	# icon sits. Clear of the player card in the top corner and of the toolbar
	# along the bottom.
	#
	# ALL FOUR ANCHORS AND ALL FOUR OFFSETS, explicitly. set_anchors_preset
	# followed by assigning `position` left the right/bottom offsets stale and
	# put the tab at y=-46, off the top of the screen - the same trap the debug
	# menu hit. There is no shorthand here that is worth the ambiguity.
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = EDGE_HEIGHT_FRACTION
	anchor_bottom = EDGE_HEIGHT_FRACTION
	offset_left = EDGE_MARGIN
	offset_right = EDGE_MARGIN + TAB_SIZE.x
	offset_top = -TAB_SIZE.y * 0.5
	offset_bottom = TAB_SIZE.y * 0.5

	_icon = TextureRect.new()
	_icon.texture = ICON_COIN
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size = Vector2(40, 40)
	_icon.position = Vector2((TAB_SIZE.x - 40.0) * 0.5, 10)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	var label := Label.new()
	label.text = "DAILY"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_LABEL)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(TAB_SIZE.x, 18)
	label.position = Vector2(0, 52)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	# The whole tab is the button; the plate and pips are drawn under it.
	_button = Button.new()
	_button.flat = true
	_button.size = TAB_SIZE
	_button.pressed.connect(_open)
	add_child(_button)

	Quests.quests_changed.connect(queue_redraw)
	set_process(true)


func _open() -> void:
	var panel := get_node_or_null("../QuestsPanel")
	if panel and panel.has_method("open"):
		panel.open()


func _process(delta: float) -> void:
	# Only animates while there is something to collect, so an idle tab costs a
	# redraw a frame and nothing more.
	if Quests.set_reward_available():
		_age += delta
		queue_redraw()
	elif _age != 0.0:
		_age = 0.0
		queue_redraw()


func _draw() -> void:
	var ready := Quests.set_reward_available()
	var plate := Rect2(Vector2.ZERO, TAB_SIZE)
	draw_rect(plate, COLOR_PLATE, true)

	var edge := COLOR_EDGE
	if ready:
		# Pulse between the two, so it reads as "come and get it" without
		# animating anything expensive.
		var t: float = 0.5 + 0.5 * sin(_age / PULSE_PERIOD * TAU)
		edge = COLOR_EDGE.lerp(COLOR_EDGE_READY, t)
	draw_rect(plate, edge, false, 2.0)

	# One pip per task, along the bottom.
	# Towards the THREE the coin needs, not the five dealt - the tab answers
	# "how close am I to the coin", which is the only question it has room for.
	var done: int = mini(Quests.completed_count(), Quests.SET_REQUIRED)
	var count: int = Quests.SET_REQUIRED
	var pip := 9.0
	var gap := 6.0
	var total := count * pip + (count - 1) * gap
	var x := (TAB_SIZE.x - total) * 0.5
	for i in range(count):
		draw_circle(Vector2(x + pip * 0.5, TAB_SIZE.y - 16.0), pip * 0.5,
			COLOR_PIP_ON if i < done else COLOR_PIP_OFF)
		x += pip + gap
