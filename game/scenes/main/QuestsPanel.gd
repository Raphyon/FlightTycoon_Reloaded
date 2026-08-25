extends Control

# DAILY TASKS. Five rows and the gold bar beneath them.
#
# THE COIN IS ALWAYS VISIBLE AND ALWAYS ONE STEP AWAY. That is the whole layout
# argument: the set bonus sits apart from the tasks, lit, with pips that fill as
# you go, so the thing you are working towards is on screen the entire time
# rather than being announced when you finish. A per-task coin would be a
# trickle you collect without noticing; this is a thing you go and finish.
#
# THE PIPS COUNT TO THREE, NOT FIVE. Five tasks are dealt and any three earn the
# coin, so the bar tracks the three - "how close am I" has one answer and it is
# not the number of rows on screen.
#
# Built in code rather than in the scene, like VisitorPanel - the rows are
# data-shaped (whatever Quests drew today) so there is nothing to lay out by
# hand, and a NinePatchRect lets the board art stretch to however tall the rows
# happen to be.

const BOARD := preload("res://assets/board/board_changelist@ipad.png")
const ICON_CASH := preload("res://assets/hud/icon_medium_money1@2x.png")
const ICON_FUEL := preload("res://assets/hud/icon_medium_oil@2x.png")
const ICON_COIN := preload("res://assets/hud/icon_medium_coin@2x.png")

# THE GAME'S OWN BUTTONS, not Godot's. Every other panel in here is built from
# this art - orange for the thing you want to press, grey for the one you
# cannot - and a default-themed Button in the middle of it looks like a
# debug overlay. See CloseButton/BackButton for the same argument.
const BUTTON_GO := preload("res://assets/buttons/button_orange2@2x.png")
const BUTTON_WIDE := preload("res://assets/buttons/button_orange4@2x.png")
const BUTTON_OFF := preload("res://assets/buttons/button_grey3@2x.png")

# 1x NATIVE, and the only two button sizes in this panel. The art is @2x, so
# half its pixels is the size it was drawn to be shown at: the pill is 136x62
# and the wide one 192x62. These were 78x26, 54x24 and 110x32 - three different
# scales, none of them either.
const PILL_SIZE := Vector2(68, 31)
const ROW_W := PANEL_SIZE.x - MARGIN * 2.0
const BUTTON_EDGE := 8.0
const BUTTON_SPACING := 12.0
const WIDE_SIZE := Vector2(96, 31)

# SIZED AGAINST THE SCREEN.
#
# project.godot sets no viewport width or height, so the design resolution is
# Godot's default 1152x648. This was 800x620 - nearly the full height of the
# screen for a five-line checklist. Matching RoutePickerPanel's 859x430 did not
# help either: that is a full-screen list and this is not.
#
# 620x320 is a bit over half the screen each way. Everything inside is sized FOR
# it rather than shrunk to fit, which is why the fonts and icon sizes are
# declared here too.
const PANEL_SIZE := Vector2(620, 320)
const MARGIN := 16.0
const ROW_HEIGHT := 38.0
const ROW_GAP := 5.0
# Fraction of the screen the panel may occupy before it is scaled down - the
# safety net for a short window, not the way it is sized.
const SCREEN_SHARE := 0.92
# The reward icons are authored at 53x47 and 39x44; a third of a row's height is
# plenty and more than that crowds the line.
const REWARD_ICON := 16.0
const COIN_ICON := 22.0
const BAR_SIZE := Vector2(170, 9)
const BONUS_HEIGHT := 48.0

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
var _bonus_button: TextureButton
var _pips: Array[Panel] = []
var _built := false


func _ready() -> void:
	visible = false
	# All four anchors and offsets explicitly - a preset followed by assigning
	# size leaves the other two offsets stale, which is how the daily tab ended
	# up off the top of the screen.
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -PANEL_SIZE.x * 0.5
	offset_right = PANEL_SIZE.x * 0.5
	offset_top = -PANEL_SIZE.y * 0.5
	offset_bottom = PANEL_SIZE.y * 0.5
	# Scales about the middle, so shrinking it does not walk it off centre.
	pivot_offset = PANEL_SIZE * 0.5
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	_build()
	get_tree().root.size_changed.connect(_fit)
	call_deferred("_fit")
	Quests.quests_changed.connect(_refresh)
	Progression.level_changed.connect(func(_l: int) -> void: _refresh())


func open() -> void:
	visible = true
	move_to_front()
	_fit()
	_refresh()


# Shrink to fit a short window. Never grows past 1:1 - a panel blown up on a
# tall screen would just look soft.
func _fit() -> void:
	var screen := get_viewport_rect().size
	if screen.x <= 0.0 or screen.y <= 0.0:
		return
	var s := minf(1.0, minf(screen.x * SCREEN_SHARE / PANEL_SIZE.x,
		screen.y * SCREEN_SHARE / PANEL_SIZE.y))
	scale = Vector2(s, s)


func _process(_delta: float) -> void:
	if visible and is_instance_valid(_timer_label):
		_timer_label.text = "Resets in %s   -   %d swap%s left" % [
		Fleet.time_left_text(Quests.seconds_until_reset()), Quests.refreshes_left,
		"" if Quests.refreshes_left == 1 else "s"]


func _build() -> void:
	if _built:
		return
	_built = true

	# NinePatch, so the 943x452 board can be whatever height the rows need.
	var bg := NinePatchRect.new()
	bg.texture = BOARD
	bg.patch_margin_left = 20
	bg.patch_margin_right = 20
	bg.patch_margin_top = 20
	bg.patch_margin_bottom = 20
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := _label("DAILY TASKS", 17, COLOR_TITLE)
	# Says the rule up front: the coin wants three of the five, not all of them.
	title.position = Vector2(MARGIN, 9)
	add_child(title)

	_timer_label = _label("", 11, COLOR_DIM)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_label.size = Vector2(250, 16)
	_timer_label.position = Vector2(PANEL_SIZE.x - MARGIN - 250, 13)
	add_child(_timer_label)

	var rule := Panel.new()
	rule.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.16), 0))
	rule.position = Vector2(MARGIN, 32)
	rule.size = Vector2(PANEL_SIZE.x - MARGIN * 2.0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", int(ROW_GAP))
	_rows.position = Vector2(MARGIN, 40)
	_rows.size = Vector2(PANEL_SIZE.x - MARGIN * 2.0,
		ROW_HEIGHT * Quests.DAILY_COUNT + ROW_GAP * (Quests.DAILY_COUNT - 1))
	add_child(_rows)

	_build_bonus()

	# The round X the other dialogs use, not a "Close" label - see CloseButton
	# for why a panel over the world gets this rather than the Back arrow.
	CloseButton.add_to(self, PANEL_SIZE, func() -> void: visible = false)


func _build_bonus() -> void:
	_bonus = Control.new()
	_bonus.position = Vector2(MARGIN, PANEL_SIZE.y - BONUS_HEIGHT - 18)
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
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Minimum first, THEN the size. A TextureRect's own art is its minimum
	# size until expand_mode says otherwise, so assigning a smaller size
	# before this line is silently clamped straight back up - which is why
	# shrinking these icons appeared to do nothing at all.
	coin.custom_minimum_size = Vector2.ZERO
	coin.size = Vector2(COIN_ICON, COIN_ICON)
	coin.position = Vector2(10, 13)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bonus.add_child(coin)

	var head := _label("Complete any %d today" % Quests.SET_REQUIRED, 13, COLOR_GOLD)
	head.position = Vector2(40, 7)
	_bonus.add_child(head)

	_bonus_label = _label("", 11, COLOR_BODY)
	_bonus_label.position = Vector2(40, 26)
	_bonus.add_child(_bonus_label)

	for i in range(Quests.SET_REQUIRED):
		var pip := Panel.new()
		pip.size = Vector2(10, 10)
		pip.position = Vector2(200 + i * 15, 28)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bonus.add_child(pip)
		_pips.append(pip)

	# Rebuilt by _refresh_bonus, because its art changes with its state.
	_bonus_button = _texture_button(BUTTON_WIDE, WIDE_SIZE, "", false)
	_bonus_button.position = Vector2(_bonus.size.x - WIDE_SIZE.x - 10, 8)
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

	var title := _label(Quests.title_for(key), 13, COLOR_DONE if done else COLOR_TITLE)
	title.position = Vector2(12, 4)
	row.add_child(title)

	var track := Panel.new()
	track.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.42), 8))
	track.position = Vector2(12, 22)
	track.size = BAR_SIZE
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(track)

	var cur: int = int(Quests.progress.get(key, 0))
	var tot: int = maxi(1, int(Quests.targets.get(key, 1)))
	if cur > 0:
		var fill := Panel.new()
		fill.add_theme_stylebox_override("panel",
			_box(COLOR_FILL_DONE if done else COLOR_FILL, 6))
		fill.position = Vector2(14, 24)
		fill.size = Vector2((BAR_SIZE.x - 4.0) * clampf(float(cur) / tot, 0.0, 1.0),
			BAR_SIZE.y - 4.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(fill)

	var count := _label("%d/%d" % [cur, tot], 11, COLOR_BODY)
	count.position = Vector2(12 + BAR_SIZE.x + 8, 20)
	row.add_child(count)

	var is_fuel: bool = Quests.reward_kind(key) == Quests.KIND_FUEL
	var icon := TextureRect.new()
	icon.texture = ICON_FUEL if is_fuel else ICON_CASH
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Minimum first, THEN the size. A TextureRect's own art is its minimum
	# size until expand_mode says otherwise, so assigning a smaller size
	# before this line is silently clamped straight back up - which is why
	# shrinking these icons appeared to do nothing at all.
	icon.custom_minimum_size = Vector2.ZERO
	icon.size = Vector2(REWARD_ICON, REWARD_ICON)
	icon.position = Vector2(250, 10)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var amount: int = Quests.reward_amount(key)
	var reward := _label(("%s fuel" % FloatingText.grouped(amount)) if is_fuel
		else ("$%s" % FloatingText.grouped(amount)), 12, COLOR_REWARD)
	reward.position = Vector2(272, 12)
	row.add_child(reward)

	# One button, three states - claimable, taken, still going.
	# Laid out from the row's right edge off PILL_SIZE, not the old 78/54 widths
	# they used to be - those left Swap overlapping Claim by 8px.
	var button_pos := Vector2(ROW_W - PILL_SIZE.x - BUTTON_EDGE, 6)
	var button: TextureButton
	if taken:
		button = _texture_button(BUTTON_OFF, PILL_SIZE, "Claimed", false)
	elif done:
		button = _texture_button(BUTTON_GO, PILL_SIZE, "Claim", true,
			func() -> void: Quests.claim(key))
	else:
		button = _texture_button(BUTTON_OFF, PILL_SIZE,
			"%d to go" % (tot - cur), false)
	button.position = button_pos
	row.add_child(button)

	# REROLL. Only on a row that is not finished - rerolling a completed task
	# would be a way to bank its reward and take another run at the same slot.
	if Quests.can_refresh(key):
		var swap := _texture_button(BUTTON_OFF, PILL_SIZE, "Swap", true,
			func() -> void: Quests.refresh(key))
		swap.modulate = Color(1, 1, 1)
		swap.tooltip_text = "Swap this task (%d left today)" % Quests.refreshes_left
		swap.position = Vector2(ROW_W - PILL_SIZE.x * 2.0 - BUTTON_EDGE - BUTTON_SPACING, 7)
		row.add_child(swap)
	return row


func _refresh_bonus() -> void:
	var done := Quests.completed_count()
	_bonus_label.text = "%d of %d done" % [mini(done, Quests.SET_REQUIRED), Quests.SET_REQUIRED]
	for i in range(_pips.size()):
		var lit := i < done
		_pips[i].add_theme_stylebox_override("panel",
			_box(COLOR_FILL_DONE if lit else Color(0, 0, 0, 0.42), 9))
	# Rebuilt rather than relabelled: the art itself changes between the orange
	# "press me" and the grey "you cannot".
	var caption := "+%d coins" % Quests.SET_COIN_REWARD
	var enabled := Quests.set_reward_available()
	if Quests.set_claimed:
		caption = "Claimed"
		enabled = false
	elif Quests.set_ready() and Progression.level < Quests.COIN_MIN_LEVEL:
		# Honest about the gate rather than a dead button: coin aircraft skip
		# the level ladder, so the coin does not start until level 10.
		caption = "Lv %d" % Quests.COIN_MIN_LEVEL
		enabled = false
	var slot := _bonus_button.position
	_bonus.remove_child(_bonus_button)
	_bonus_button.queue_free()
	_bonus_button = _texture_button(BUTTON_WIDE, Vector2(110, 32), caption, enabled,
		func() -> void: Quests.claim_set())
	_bonus_button.position = slot
	_bonus.add_child(_bonus_button)


# --- helpers ----------------------------------------------------------------

# A button in the game's own art, with its caption centred on it.
#
# ignore_texture_size BEFORE the size, or the art's own dimensions become the
# minimum and everything set afterwards is silently clamped up to them - the
# trap CloseButton documents.
func _texture_button(texture: Texture2D, button_size: Vector2, caption: String,
		enabled: bool, on_pressed := Callable()) -> TextureButton:
	var button := TextureButton.new()
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_normal = texture if enabled else BUTTON_OFF
	button.size = button_size
	button.custom_minimum_size = button_size
	button.disabled = not enabled
	if not enabled:
		button.modulate = Color(0.82, 0.82, 0.82)
	if enabled and on_pressed.is_valid():
		button.pressed.connect(on_pressed)

	var caption_label := _label(caption, 11, Color(1, 1, 1) if enabled else COLOR_DIM)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.size = button_size
	caption_label.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.03))
	caption_label.add_theme_constant_override("outline_size", 4)
	button.add_child(caption_label)
	return button


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
