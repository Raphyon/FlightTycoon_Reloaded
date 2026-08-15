extends Control

# DAILY TASKS. Three rows and the gold bar beneath them.
#
# THE COIN IS ALWAYS VISIBLE AND ALWAYS ONE STEP AWAY. That is the whole layout
# argument: the set bonus sits apart from the tasks, lit, with three pips that
# fill as you go, so the thing you are working towards is on screen the entire
# time rather than being announced when you finish. A per-task coin would be a
# trickle you collect without noticing; this is a thing you go and finish.
#
# Built in code rather than in the scene, like VisitorPanel - the rows are
# data-shaped (whatever Quests drew today) so there is nothing to lay out by
# hand, and a NinePatchRect lets the board art stretch to however tall three
# rows happen to be.

const BOARD := preload("res://assets/board/board_changelist@ipad.png")
const ICON_CASH := preload("res://assets/hud/icon_medium_money1@2x.png")
const ICON_FUEL := preload("res://assets/hud/icon_medium_oil@2x.png")
const ICON_COIN := preload("res://assets/hud/icon_medium_coin@2x.png")

const PANEL_SIZE := Vector2(760, 520)
const MARGIN := 34.0
const ROW_HEIGHT := 86.0
const ROW_GAP := 12.0
const BAR_SIZE := Vector2(320, 16)
const BONUS_HEIGHT := 96.0

const COLOR_TITLE := Color(1.0, 0.93, 0.82)
const COLOR_BODY := Color(0.88, 0.83, 0.74)
const COLOR_DIM := Color(0.72, 0.66, 0.58)
const COLOR_DONE := Color(0.72, 0.86, 0.70)
const COLOR_FILL := Color(0.94, 0.75, 0.32)
const COLOR_FILL_DONE := Color(0.49, 0.84, 0.48)
const COLOR_REWARD := Color(1.0, 0.90, 0.67)
const COLOR_GOLD := Color(1.0, 0.87, 0.44)

var _rows: VBoxContainer
var _bonus: Control
var _timer_label: Label
var _bonus_label: Label
var _bonus_button: Button
var _pips: Array[Panel] = []
var _built := false


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	_build()
	Quests.quests_changed.connect(_refresh)
	Progression.level_changed.connect(func(_l: int) -> void: _refresh())


func open() -> void:
	visible = true
	move_to_front()
	_refresh()


func _process(_delta: float) -> void:
	if visible and is_instance_valid(_timer_label):
		_timer_label.text = "Resets in %s" % Fleet.time_left_text(Quests.seconds_until_reset())


func _build() -> void:
	if _built:
		return
	_built = true

	# NinePatch, so the 943x452 board can be whatever height the rows need.
	var bg := NinePatchRect.new()
	bg.texture = BOARD
	bg.patch_margin_left = 28
	bg.patch_margin_right = 28
	bg.patch_margin_top = 28
	bg.patch_margin_bottom = 28
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := _label("DAILY TASKS", 30, COLOR_TITLE)
	title.position = Vector2(MARGIN, 22)
	add_child(title)

	_timer_label = _label("", 18, COLOR_DIM)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_label.size = Vector2(300, 24)
	_timer_label.position = Vector2(PANEL_SIZE.x - MARGIN - 300, 32)
	add_child(_timer_label)

	var rule := Panel.new()
	rule.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.16), 0))
	rule.position = Vector2(MARGIN, 68)
	rule.size = Vector2(PANEL_SIZE.x - MARGIN * 2.0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", int(ROW_GAP))
	_rows.position = Vector2(MARGIN, 86)
	_rows.size = Vector2(PANEL_SIZE.x - MARGIN * 2.0, ROW_HEIGHT * 3.0 + ROW_GAP * 2.0)
	add_child(_rows)

	_build_bonus()

	var close := Button.new()
	close.text = "Close"
	close.size = Vector2(110, 40)
	close.position = Vector2(PANEL_SIZE.x - MARGIN - 110, PANEL_SIZE.y - 52)
	close.pressed.connect(func() -> void: visible = false)
	add_child(close)


func _build_bonus() -> void:
	_bonus = Control.new()
	_bonus.position = Vector2(MARGIN, PANEL_SIZE.y - BONUS_HEIGHT - 74)
	_bonus.size = Vector2(PANEL_SIZE.x - MARGIN * 2.0, BONUS_HEIGHT)
	add_child(_bonus)

	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel",
		_box(Color(1.0, 0.81, 0.43, 0.12), 14, Color(1.0, 0.81, 0.43, 0.55)))
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bonus.add_child(frame)

	var coin := TextureRect.new()
	coin.texture = ICON_COIN
	coin.size = Vector2(44, 50)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.position = Vector2(22, 23)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bonus.add_child(coin)

	var head := _label("Complete all 3 today", 24, COLOR_GOLD)
	head.position = Vector2(84, 18)
	_bonus.add_child(head)

	_bonus_label = _label("", 18, COLOR_BODY)
	_bonus_label.position = Vector2(84, 52)
	_bonus.add_child(_bonus_label)

	for i in range(Quests.DAILY_COUNT):
		var pip := Panel.new()
		pip.size = Vector2(18, 18)
		pip.position = Vector2(320 + i * 26, 54)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bonus.add_child(pip)
		_pips.append(pip)

	_bonus_button = Button.new()
	_bonus_button.size = Vector2(168, 54)
	_bonus_button.position = Vector2(_bonus.size.x - 168 - 18, 21)
	_bonus_button.pressed.connect(func() -> void: Quests.claim_set())
	_bonus.add_child(_bonus_button)


# --- rows -------------------------------------------------------------------

func _refresh(_a = null) -> void:
	if not _built:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for key in Quests.active:
		_rows.add_child(_make_row(str(key)))
	_refresh_bonus()


func _make_row(key: String) -> Control:
	var done := Quests.is_complete(key)
	var taken: bool = bool(Quests.claimed.get(key, false))

	var row := Panel.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.22), 12,
		Color(0.49, 0.81, 0.48, 0.55) if done else Color(0, 0, 0, 0)))

	var title := _label(Quests.title_for(key), 22, COLOR_DONE if done else COLOR_TITLE)
	title.position = Vector2(24, 14)
	row.add_child(title)

	var track := Panel.new()
	track.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.42), 8))
	track.position = Vector2(24, 50)
	track.size = BAR_SIZE
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(track)

	var cur: int = int(Quests.progress.get(key, 0))
	var tot: int = maxi(1, int(Quests.targets.get(key, 1)))
	if cur > 0:
		var fill := Panel.new()
		fill.add_theme_stylebox_override("panel",
			_box(COLOR_FILL_DONE if done else COLOR_FILL, 6))
		fill.position = Vector2(26, 52)
		fill.size = Vector2((BAR_SIZE.x - 4.0) * clampf(float(cur) / tot, 0.0, 1.0),
			BAR_SIZE.y - 4.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(fill)

	var count := _label("%d/%d" % [cur, tot], 19, COLOR_BODY)
	count.position = Vector2(24 + BAR_SIZE.x + 16, 48)
	row.add_child(count)

	var is_fuel: bool = Quests.reward_kind(key) == Quests.KIND_FUEL
	var icon := TextureRect.new()
	icon.texture = ICON_FUEL if is_fuel else ICON_CASH
	icon.size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(452, 28)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var amount: int = Quests.reward_amount(key)
	var reward := _label(("%s fuel" % FloatingText.grouped(amount)) if is_fuel
		else ("$%s" % FloatingText.grouped(amount)), 21, COLOR_REWARD)
	reward.position = Vector2(490, 32)
	row.add_child(reward)

	# One button, three states - claimable, taken, still going.
	var button := Button.new()
	button.size = Vector2(122, 44)
	button.position = Vector2(row.custom_minimum_size.x, 0)   # fixed below
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.position = Vector2(PANEL_SIZE.x - MARGIN * 2.0 - 122 - 18, 21)
	if taken:
		button.text = "Claimed"
		button.disabled = true
	elif done:
		button.text = "Claim"
		button.pressed.connect(func() -> void: Quests.claim(key))
	else:
		button.text = "%d to go" % (tot - cur)
		button.disabled = true
	row.add_child(button)
	return row


func _refresh_bonus() -> void:
	var done := Quests.completed_count()
	_bonus_label.text = "%d of %d done" % [done, Quests.DAILY_COUNT]
	for i in range(_pips.size()):
		var lit := i < done
		_pips[i].add_theme_stylebox_override("panel",
			_box(COLOR_FILL_DONE if lit else Color(0, 0, 0, 0.42), 9))
	if Quests.set_claimed:
		_bonus_button.text = "Claimed"
		_bonus_button.disabled = true
	elif Quests.all_complete() and Progression.level < Quests.COIN_MIN_LEVEL:
		# Honest about the gate rather than a dead button: coin aircraft skip
		# the level ladder, so the coin does not start until level 10.
		_bonus_button.text = "Lv %d" % Quests.COIN_MIN_LEVEL
		_bonus_button.disabled = true
	else:
		_bonus_button.text = "+%d coins" % Quests.SET_COIN_REWARD
		_bonus_button.disabled = not Quests.set_reward_available()


# --- helpers ----------------------------------------------------------------

func _label(text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(color: Color, radius: int, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.corner_radius_top_left = radius
	b.corner_radius_top_right = radius
	b.corner_radius_bottom_left = radius
	b.corner_radius_bottom_right = radius
	if border.a > 0.0:
		b.border_color = border
		b.set_border_width_all(2)
	return b
