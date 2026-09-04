extends Control

# BOOST CARDS, held and spent.
#
# One row per card you own: what it is, how long it runs, how many you have, and
# a button to spend one. Anything currently running is listed above them with
# what is left on the clock.
#
# NO TOOLBAR BUTTON. Every button on that shelf is a piece of art with its own
# pressed state, and there is none for this. The boost icons are already
# button-shaped - a gold frame with a glyph in it - so the entry point is a
# single card that appears at the edge of the screen ONLY while you hold
# something, and vanishes when you do not. A control that is not there when it
# has nothing to say costs no screen and needs no art.

const BOARD := preload("res://assets/board/board_changelist@ipad.png")
const ROW_ART := preload("res://assets/board/board_card1@2x.png")
const BUTTON_ART := preload("res://assets/buttons/button_orange2@2x.png")
const BUTTON_OFF_ART := preload("res://assets/buttons/button_grey3@2x.png")

const BOARD_SCALE := 0.72
const BOARD_SIZE := Vector2(679, 325)

const TITLE_Y := 18.0
const LIST_Y := 56.0
# Six rows is the most this can ever show - three auto-turnaround lengths, speed,
# cash, fuel - plus whatever is running. At 46px they ran off the bottom of a
# 325px board, so a row is 38 and the gap is 4: seven of those fit with margin.
const ROW_H := 38.0
const ROW_GAP := 4.0
const ROW_X := 40.0
const ROW_W := BOARD_SIZE.x - ROW_X * 2.0
const ICON := 28.0
# 1x NATIVE, and no longer stretched - it was 92x25 against art that is
# 136x62, an aspect of 3.68 against the art's own 2.19.
const USE_W := 68.0
const USE_H := 31.0

const FONT_TITLE := 22
const FONT_NAME := 14
const FONT_SUB := 11
const FONT_BUTTON := 13
const FONT_MIN := 9

const COLOR_NAME := Color(1.0, 0.96, 0.90)
const COLOR_SUB := Color(0.92, 0.84, 0.70)
const COLOR_RUNNING := Color(0.62, 1.0, 0.66)

var _content: Control

# The running rows' clock labels, by family. _process used to call _rebuild(),
# which frees and re-instantiates every node on the board - icons re-load()ed,
# buttons re-wired, labels re-themed - sixty times a second, to move text that
# changes once a second at most. The rows themselves only change when a boost
# starts, ends or is spent, and all three already have signals.
var _running_labels: Dictionary = {}


func _ready() -> void:
	visible = false
	custom_minimum_size = BOARD_SIZE
	size = BOARD_SIZE

	var board := TextureRect.new()
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.texture = BOARD
	board.size = BOARD_SIZE
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	CloseButton.add_to(self, BOARD_SIZE, hide)
	Boosts.inventory_changed.connect(_rebuild)
	Boosts.boost_ended.connect(func(_k: String) -> void: _rebuild())
	# A boost STARTING adds a running row, and nothing here was listening for
	# it - the per-frame rebuild had been covering that up.
	Boosts.boost_started.connect(func(_k: String, _s: float) -> void: _rebuild())
	# And when one ENDS - otherwise every Use button stays greyed until the
	# panel is closed and opened again.
	Boosts.boost_ended.connect(func(_k: String) -> void: _rebuild())
	visibility_changed.connect(_on_visibility_changed)
	set_process(false)


func show_panel() -> void:
	move_to_front()
	# Asked to open a board that is already open, visibility_changed does not
	# fire, so the rebuild is done here rather than only in that handler.
	visible = true
	_rebuild()


func _on_visibility_changed() -> void:
	if visible:
		_rebuild()
	else:
		set_process(false)
		_running_labels.clear()


func _process(_delta: float) -> void:
	# The clock is the one thing here that moves without the player touching
	# anything. Only the text changes - the row it sits in does not.
	for family in _running_labels:
		var l: Label = _running_labels[family]
		if not is_instance_valid(l):
			continue
		l.text = _running_text(family)


func _running_rows() -> int:
	var n := 0
	for family in ["autoturn", "speed", "cash", "fuel"]:
		if Boosts.is_active(family):
			n += 1
	return n


func _rebuild() -> void:
	if not visible:
		return
	_running_labels.clear()
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()

	var title := _label(_fs(FONT_TITLE), COLOR_NAME, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = "Boosts"
	title.position = Vector2(0.0, TITLE_Y)
	title.size = Vector2(BOARD_SIZE.x, 26.0)

	var y := LIST_Y

	# Running first, because "what is on right now" is the question you opened
	# this to answer.
	for family in ["autoturn", "speed", "cash", "fuel"]:
		if not Boosts.is_active(family):
			continue
		_running_labels[family] = _row(y, _icon_for_family(family),
			_name_for_family(family), _running_text(family), 0, true)
		y += ROW_H + ROW_GAP

	var held := 0
	for key in Boosts.CARDS:
		var n: int = Boosts.count(key)
		if n <= 0:
			continue
		held += n
		var card: Dictionary = Boosts.CARDS[key]
		var detail := str(card["detail"])
		if n > 1:
			detail += "   x%d" % n
		_row(y, str(card["icon"]), str(card["name"]), detail, n, false, key)
		y += ROW_H + ROW_GAP

	if held == 0 and _running_rows() == 0:
		var empty := _label(_fs(FONT_NAME), COLOR_SUB, HORIZONTAL_ALIGNMENT_CENTER)
		empty.text = "No boosts yet - they come from daily rewards and aircraft levels."
		empty.position = Vector2(0.0, BOARD_SIZE.y * 0.45)
		empty.size = Vector2(BOARD_SIZE.x, 20.0)

	# No clock on the board, no reason to be called every frame.
	set_process(not _running_labels.is_empty())


func _running_text(family: String) -> String:
	return "running - %s left" % _clock(Boosts.seconds_left(family))


# Returns the row's detail label - the line the running rows tick their clock
# on, and the only thing on a row that changes while the board stays put.
func _row(y: float, icon: String, name: String, sub: String, count: int,
		running: bool, key := "") -> Label:
	var bg := TextureRect.new()
	bg.texture = ROW_ART
	# Before the size, or the art's 245x400 becomes the minimum.
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.position = Vector2(ROW_X, y)
	bg.size = Vector2(ROW_W, ROW_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.modulate = Color(0.72, 0.82, 0.72) if running else Color(0.86, 0.84, 0.82)
	_content.add_child(bg)

	var path := "res://assets/boosts/boost_%s_2x.png" % icon
	if ResourceLoader.exists(path):
		var im := TextureRect.new()
		im.texture = load(path)
		im.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		im.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		im.custom_minimum_size = Vector2.ZERO
		im.size = Vector2(ICON, ICON)
		im.position = Vector2(ROW_X + 8.0, y + (ROW_H - ICON) * 0.5)
		im.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(im)

	var text_x := ROW_X + ICON + 18.0
	var title := _label(FONT_NAME, COLOR_RUNNING if running else COLOR_NAME,
		HORIZONTAL_ALIGNMENT_LEFT)
	title.text = name
	title.position = Vector2(text_x, y + 3.0)
	title.size = Vector2(ROW_W - ICON - USE_W - 40.0, 17.0)

	var detail := _label(FONT_SUB, COLOR_SUB, HORIZONTAL_ALIGNMENT_LEFT)
	detail.text = sub
	detail.position = Vector2(text_x, y + 19.0)
	detail.size = Vector2(ROW_W - ICON - USE_W - 40.0, 15.0)

	if running:
		return detail

	# GREYED, AND IT SAYS WHY. One boost runs at a time now, so every Use
	# button is dead while anything is going - and a live-looking button that
	# does nothing is worse than no button. The hover carries the reason; the
	# press is refused in _use rather than by `disabled`, because a disabled
	# TextureButton stops taking the mouse and takes its tooltip with it.
	var blocked := Boosts.any_active()
	var h := USE_H
	var b := TextureButton.new()
	b.focus_mode = Control.FOCUS_NONE
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_normal = BUTTON_ART
	b.custom_minimum_size = Vector2.ZERO
	b.size = Vector2(USE_W, h)
	b.position = Vector2(ROW_X + ROW_W - USE_W - 10.0, y + (ROW_H - h) * 0.5)
	b.pressed.connect(func() -> void: _use(key))
	if blocked:
		b.modulate = Color(0.55, 0.55, 0.55, 1.0)
		b.tooltip_text = "Boost is already running"
	_content.add_child(b)

	var caption := _label(FONT_BUTTON, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	# A button says what pressing it does. The count belongs on the row.
	caption.text = "Use"
	caption.clip_text = true
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.position = b.position
	caption.size = b.size
	return detail


func _use(key: String) -> void:
	if key == "" or Boosts.any_active():
		return
	Boosts.use(key)


func _icon_for_family(family: String) -> String:
	return "collect" if family == "autoturn" else family


func _name_for_family(family: String) -> String:
	match family:
		"autoturn": return "Auto Turnaround"
		"speed": return "Speed Boost"
		"cash": return "Double Cash"
		"fuel": return "Free Fuel"
	return family


func _clock(seconds: float) -> String:
	var t := int(max(0.0, seconds))
	if t >= 3600:
		return "%dh %02dm" % [t / 3600, (t % 3600) / 60]
	if t >= 60:
		return "%dm" % (t / 60)
	return "%ds" % t


func _label(size_px: int, color: Color, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(l)
	return l


func _fs(native: int) -> int:
	return maxi(FONT_MIN, roundi(native * BOARD_SCALE))
