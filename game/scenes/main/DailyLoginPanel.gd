extends Control

# DAILY LOGIN, the window. Seven tiles, today's lit, the rest dim.
#
# NOT built on source-assets/login/login_back@ipad.jpg, which ROADMAP item 3
# nominated. Having looked at it, that is a splash illustration - a full sky of
# aircraft over the island - and seven tiles of numbers on top of it would be
# unreadable. It is a loading screen, not a panel frame. This uses the board
# every other window uses, and the login art stays unused.

const BOARD := preload("res://assets/board/board_changelist@ipad.png")
const TILE_ART := preload("res://assets/board/board_card1@2x.png")
const BUTTON_ART := preload("res://assets/buttons/button_orange2@2x.png")
const BUTTON_OFF_ART := preload("res://assets/buttons/button_grey3@2x.png")
const ICON_CASH := preload("res://assets/hud/icon_medium_money1@2x.png")
const ICON_COIN := preload("res://assets/hud/icon_medium_coin@2x.png")
const ICON_FUEL := preload("res://assets/hud/icon_medium_oil@2x.png")

const BOARD_SCALE := 0.72
const BOARD_SIZE := Vector2(679, 325)

# Seven across. board_card1 is 245x400, so a tile is its aspect at whatever
# width seven of them plus gaps fit into - stretching it would look exactly like
# stretching it.
const TILE_W := 78.0
const TILE_H := TILE_W * 400.0 / 245.0
const TILE_GAP := 12.0
const TILES_Y := 78.0

const TITLE_Y := 20.0
const BUTTON_W := 150.0
const BUTTON_Y := 228.0
const NOTE_Y := 288.0

const FONT_TITLE := 22
const FONT_DAY := 12
const FONT_AMOUNT := 13
const FONT_BUTTON := 16
const FONT_NOTE := 11
const FONT_MIN := 9

const COLOR_TODAY := Color(1.0, 0.96, 0.82)
const COLOR_DONE := Color(0.62, 1.0, 0.66)
const COLOR_LATER := Color(0.92, 0.90, 0.86)
const COLOR_NOTE := Color(0.95, 0.86, 0.74)

var _content: Control


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
	DailyLogin.streak_changed.connect(_rebuild)


func show_panel() -> void:
	move_to_front()
	visible = true
	_rebuild()


func _rebuild() -> void:
	if not visible:
		return
	# Out of the tree now rather than next frame - claiming rebuilds immediately
	# and queue_free is deferred, so the old row would draw over the new one.
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()

	var next := DailyLogin.next_index()
	var claimable := DailyLogin.can_claim()

	var title := _label(_fs(FONT_TITLE), COLOR_TODAY, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = "Daily Reward" if DailyLogin.streak <= 0 \
		else "Daily Reward  -  %d day streak" % DailyLogin.streak
	title.position = Vector2(0.0, TITLE_Y)
	title.size = Vector2(BOARD_SIZE.x, 26.0)

	var span := DailyLogin.CYCLE * TILE_W + (DailyLogin.CYCLE - 1) * TILE_GAP
	var left := (BOARD_SIZE.x - span) * 0.5
	for i in range(DailyLogin.CYCLE):
		# A tile is DONE if the streak has already passed it this cycle. With no
		# claim pending, today's reward is the one just taken, so the marker sits
		# on the last one collected rather than on tomorrow's.
		var done := i < next if claimable else i < next or (next == 0 and i == 0)
		_tile(i, left + i * (TILE_W + TILE_GAP), i == next and claimable, done)

	_claim_button(claimable)

	var note := _label(FONT_NOTE, COLOR_NOTE, HORIZONTAL_ALIGNMENT_CENTER)
	note.text = "Come back tomorrow for day %d" % (next + 1) if not claimable \
		else "Miss a day and the streak starts over"
	note.position = Vector2(0.0, NOTE_Y)
	note.size = Vector2(BOARD_SIZE.x, 16.0)


func _tile(index: int, x: float, is_today: bool, done: bool) -> void:
	var tile := TextureRect.new()
	tile.texture = TILE_ART
	# Before the size, or the art's 245x400 is the minimum and the assignment
	# below is silently clamped back up to it.
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_SCALE
	tile.position = Vector2(x, TILES_Y)
	tile.size = Vector2(TILE_W, TILE_H)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if done:
		tile.modulate = Color(0.62, 0.72, 0.62)
	elif not is_today:
		tile.modulate = Color(0.78, 0.76, 0.74)
	_content.add_child(tile)

	var day := _label(FONT_DAY,
		COLOR_TODAY if is_today else (COLOR_DONE if done else COLOR_LATER),
		HORIZONTAL_ALIGNMENT_CENTER)
	day.text = "Day %d" % (index + 1)
	day.position = Vector2(x, TILES_Y + TILE_H * 0.07)
	day.size = Vector2(TILE_W, 16.0)

	var coins := DailyLogin.coins_for(index)
	var cash := DailyLogin.cash_for(index)
	var fuel := DailyLogin.fuel_for(index)
	# Coin days lead with the coin even when they also pay cash - day 7 pays
	# both, and the coin is the reason anybody finishes the week.
	var art: Texture2D = ICON_COIN if coins > 0 else (ICON_CASH if cash > 0 else ICON_FUEL)
	var amount := str(coins) if coins > 0 else (
		NiceNumber.short(cash) if cash > 0 else NiceNumber.short(fuel))

	var icon := TextureRect.new()
	icon.texture = art
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ZERO
	icon.size = Vector2(TILE_W * 0.42, TILE_W * 0.42)
	icon.position = Vector2(x + (TILE_W - icon.size.x) * 0.5, TILES_Y + TILE_H * 0.30)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if done:
		icon.modulate = Color(0.75, 0.85, 0.75)
	_content.add_child(icon)

	var amount_label := _label(FONT_AMOUNT,
		COLOR_TODAY if is_today else (COLOR_DONE if done else COLOR_LATER),
		HORIZONTAL_ALIGNMENT_CENTER)
	amount_label.text = amount
	amount_label.position = Vector2(x, TILES_Y + TILE_H * 0.68)
	amount_label.size = Vector2(TILE_W, 18.0)


func _claim_button(claimable: bool) -> void:
	var h: float = BUTTON_W * BUTTON_ART.get_height() / float(BUTTON_ART.get_width())
	var b := TextureButton.new()
	b.focus_mode = Control.FOCUS_NONE
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_normal = BUTTON_ART if claimable else BUTTON_OFF_ART
	b.custom_minimum_size = Vector2.ZERO
	b.size = Vector2(BUTTON_W, h)
	b.position = Vector2((BOARD_SIZE.x - BUTTON_W) * 0.5, BUTTON_Y)
	b.disabled = not claimable
	if claimable:
		b.pressed.connect(_on_claim)
	_content.add_child(b)

	var caption := _label(FONT_BUTTON,
		Color.WHITE if claimable else Color(0.78, 0.75, 0.72),
		HORIZONTAL_ALIGNMENT_CENTER)
	caption.text = "Collect" if claimable else "Collected"
	caption.clip_text = true
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.position = b.position
	caption.size = b.size


func _on_claim() -> void:
	var index := DailyLogin.next_index()
	if not DailyLogin.claim():
		return
	# Float what it paid off the tile it came from, the same way a claim bubble
	# reports a flight - the money landing in the HUD with no sign of where it
	# came from is the thing FloatingText exists to fix.
	var span := DailyLogin.CYCLE * TILE_W + (DailyLogin.CYCLE - 1) * TILE_GAP
	var at := Vector2((BOARD_SIZE.x - span) * 0.5 + index * (TILE_W + TILE_GAP)
		+ TILE_W * 0.5, TILES_Y)
	var stack := 0.0
	var cash := DailyLogin.cash_for(index)
	var coins := DailyLogin.coins_for(index)
	var fuel := DailyLogin.fuel_for(index)
	if cash > 0:
		FloatingText.spawn(self, at, "+$%s" % FloatingText.grouped(cash),
			FloatingText.COLOR_GAIN, stack * 0.5)
		stack += 1.0
	if coins > 0:
		FloatingText.spawn(self, at, "+%d coin" % coins,
			FloatingText.COLOR_COIN, stack * 0.5)
		stack += 1.0
	if fuel > 0:
		FloatingText.spawn(self, at, "+%s fuel" % FloatingText.grouped(fuel),
			FloatingText.COLOR_SPEND, stack * 0.5)


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
