extends Control

# CONFIRM AN UPGRADE, by showing what it buys.
#
# The upgrade button used to carry the whole decision: it read "Lv 4  110,000
# coins", which is a level number the building's own name already shows, a price,
# and no answer at all to the only question worth asking - what do I get?
#
# So the button says "Upgrade" and this says the rest: the building as it is
# now, an arrow, and the building as it will be. The price sits under the pair
# and the confirm is the last thing you touch.
#
# Built on the pickers' board, at the pickers' size, and LANDSCAPE because two
# cards side by side is a wide shape and that is the board the game has. The
# comparison takes the left, the price and the confirm take the right.

const BOARD := preload("res://assets/board/board_changelist@ipad.png")
const CARD_ART := preload("res://assets/board/board_card1@2x.png")
const TAG_ART := preload("res://assets/board/board_price@2x.png")
const ARROW_ART := preload("res://assets/buttons/button_arrow_right@2x.png")
const BUTTON_ART := preload("res://assets/buttons/button_orange2@2x.png")
const BUTTON_OFF_ART := preload("res://assets/buttons/button_grey3@2x.png")
const COST_COIN := preload("res://assets/hud/icon_medium_coin@2x.png")
const COST_CASH := preload("res://assets/hud/icon_medium_money1@2x.png")
const RENT_ICON := preload("res://assets/hud/icon_medium_money1@2x.png")

const BOARD_NATIVE := Vector2(943, 452)
const BOARD_SCALE := 0.72
const BOARD_SIZE := Vector2(679, 325)

# The shop's card, at the shop's size - this is what board_card1 is drawn at
# everywhere else in the game.
const CARD_PX := Vector2(122.5, 200.0)
const CARD_GAP := 46.0
const CARDS_X := 46.0
const CARDS_Y := 84.0
const CARDS_W := CARD_PX.x * 2.0 + CARD_GAP

const TITLE_Y := 24.0

# Inside a card, as a fraction of it.
const CARD_ART_RECT := Rect2(0.10, 0.10, 0.80, 0.42)
const CARD_LEVEL_Y := 0.56
const CARD_RENT_Y := 0.72
const RENT_ICON_H := 20.0
const RENT_GAP := 4.0

const ARROW_SCALE := 1.6

# The action column, centred in what is left to the right of the cards.
const ACTION_CX := (CARDS_X + CARDS_W + BOARD_SIZE.x) * 0.5
const TAG_W := 150.0
const TAG_Y := 120.0
const TAG_GAP := 5.0
const BUTTON_W := 128.0
const BUTTON_Y := 162.0
const NOTE_Y := 232.0

# ONLY THE TITLE is board text. Everything else sits on a card or a button that
# is drawn at its own native size whatever the board does, so it uses literal
# sizes - running these through _fs() put the card text at 9pt.
const FONT_TITLE := 22
const FONT_LEVEL := 13
const FONT_RENT := 15
const FONT_TAG := 15
const FONT_BUTTON := 15
const FONT_NOTE := 11
const FONT_MIN := 9

const COLOR_NOW := Color(1.0, 0.96, 0.90)
const COLOR_NEXT := Color(0.62, 1.0, 0.66)
const COLOR_NOTE := Color(0.95, 0.86, 0.74)
const COLOR_SHORT := Color(1.0, 0.62, 0.55)

var _plot_id: int = -1
var _on_done: Callable = Callable()
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
	Coins.coins_changed.connect(func(_n = null) -> void: _rebuild())
	Economy.money_changed.connect(func(_n = null) -> void: _rebuild())


func show_for_plot(plot_id: int, on_done: Callable = Callable()) -> void:
	# The info panel is later in the tree and would otherwise cover this, the
	# same reason RoutePickerPanel does it.
	move_to_front()
	_plot_id = plot_id
	_on_done = on_done
	visible = true
	_rebuild()


func _rebuild() -> void:
	if not visible or _plot_id < 0:
		return
	# Out of the tree NOW rather than next frame - confirming emits a currency
	# signal which rebuilds again, and queue_free is deferred, so the old
	# contents would draw over the new ones until the frame ended.
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()

	var key := BuildingProgress.building_at(_plot_id)
	if key == "" or BuildingProgress.is_upgrading(_plot_id):
		hide()
		return
	var level := BuildingProgress.level_at(_plot_id)
	if level >= BuildingProgress.MAX_LEVEL:
		hide()
		return

	var now_rent := BuildingProgress.rent_at(_plot_id)
	var next_rent := BuildingProgress.rent_at_level(key, level + 1)
	var title := _label(_fs(FONT_TITLE), COLOR_NOW)
	title.text = BuildingLayout.name_of(key)
	title.position = Vector2(0.0, TITLE_Y)
	title.size = Vector2(BOARD_SIZE.x, 26.0)

	_card(key, CARDS_X, level, now_rent, false)
	_card(key, CARDS_X + CARD_PX.x + CARD_GAP, level + 1, next_rent, true)

	# The arrow reads left to right, which is what says which card is the one
	# you have and which is the one you are buying.
	var arrow := TextureRect.new()
	arrow.texture = ARROW_ART
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.custom_minimum_size = Vector2.ZERO
	arrow.size = Vector2(ARROW_ART.get_width(), ARROW_ART.get_height()) * ARROW_SCALE
	arrow.position = Vector2(CARDS_X + CARD_PX.x + (CARD_GAP - arrow.size.x) * 0.5,
		CARDS_Y + CARD_PX.y * 0.5 - arrow.size.y * 0.5)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(arrow)

	var cost := BuildingProgress.upgrade_cost(_plot_id)
	var in_coins := BuildingProgress.upgrade_currency(_plot_id) == "coins"
	var affordable := (Coins.amount >= cost) if in_coins else (Economy.money >= cost)
	_price_tag(cost, in_coins, affordable)
	_confirm_button(affordable)

	var note := _label(FONT_NOTE, COLOR_NOTE)
	# The part that is easy to miss: an upgrading building earns nothing while
	# the work is on, so this is a real cost and not a detail.
	note.text = "No rent for %s" % _countdown(BuildingProgress.upgrade_seconds(_plot_id))
	note.position = Vector2(ACTION_CX - 110.0, NOTE_Y)
	note.size = Vector2(220.0, 16.0)


func _card(key: String, x: float, level: int, rent: int, is_next: bool) -> void:
	var card := TextureRect.new()
	card.texture = CARD_ART
	# Before the size, or the art's 245x400 becomes the minimum and the size
	# below is silently clamped back up to it.
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.position = Vector2(x, CARDS_Y)
	card.size = CARD_PX
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_next:
		# The one you already have, stated quieter than the one you are buying.
		card.modulate = Color(0.78, 0.76, 0.74)
	_content.add_child(card)

	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2.ZERO
	art.position = Vector2(x + CARD_PX.x * CARD_ART_RECT.position.x,
		CARDS_Y + CARD_PX.y * CARD_ART_RECT.position.y)
	art.size = Vector2(CARD_PX.x * CARD_ART_RECT.size.x,
		CARD_PX.y * CARD_ART_RECT.size.y)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := BuildingLayout.texture_path(key)
	if ResourceLoader.exists(path):
		art.texture = load(path)
	if not is_next:
		art.modulate = Color(0.80, 0.78, 0.76)
	_content.add_child(art)

	var lv := _label(FONT_LEVEL, COLOR_NEXT if is_next else COLOR_NOW)
	lv.text = "Level %d" % level
	lv.position = Vector2(x, CARDS_Y + CARD_PX.y * CARD_LEVEL_Y)
	lv.size = Vector2(CARD_PX.x, 18.0)

	# Rent as an icon and a number, which is the whole point of the comparison -
	# the two cards differ in exactly one figure and it should be the one thing
	# your eye lands on.
	var amount := _label(FONT_RENT, COLOR_NEXT if is_next else COLOR_NOW)
	_content.add_child(amount)
	amount.text = _thousands(rent)
	var text_w: float = amount.get_minimum_size().x
	var icon_w: float = RENT_ICON_H * RENT_ICON.get_width() / float(RENT_ICON.get_height())
	var group: float = icon_w + RENT_GAP + text_w
	var left: float = x + (CARD_PX.x - group) * 0.5

	var icon := TextureRect.new()
	icon.texture = RENT_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ZERO
	icon.size = Vector2(icon_w, RENT_ICON_H)
	icon.position = Vector2(left, CARDS_Y + CARD_PX.y * CARD_RENT_Y)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_next:
		icon.modulate = Color(0.82, 0.82, 0.82)
	_content.add_child(icon)

	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.position = Vector2(left + icon_w + RENT_GAP, CARDS_Y + CARD_PX.y * CARD_RENT_Y)
	amount.size = Vector2(text_w, RENT_ICON_H)


func _price_tag(cost: int, in_coins: bool, affordable: bool) -> void:
	var tag := TextureRect.new()
	tag.texture = TAG_ART
	tag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tag.stretch_mode = TextureRect.STRETCH_SCALE
	tag.size = Vector2(TAG_W, TAG_W * TAG_ART.get_height() / float(TAG_ART.get_width()))
	tag.position = Vector2(ACTION_CX - TAG_W * 0.5, TAG_Y)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(tag)

	var art: Texture2D = COST_COIN if in_coins else COST_CASH
	var price := _label(FONT_TAG,
		Color(1, 0.94, 0.68) if affordable else COLOR_SHORT)
	_content.add_child(price)
	price.text = str(cost) if in_coins else _thousands(cost)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var text_w: float = price.get_minimum_size().x
	var icon_h: float = tag.size.y * 0.82
	var icon_w: float = icon_h * art.get_width() / float(art.get_height())
	var group: float = icon_w + TAG_GAP + text_w
	var left: float = tag.position.x + (tag.size.x - group) * 0.5

	var icon := TextureRect.new()
	icon.texture = art
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ZERO
	icon.size = Vector2(icon_w, icon_h)
	icon.position = Vector2(left, tag.position.y + (tag.size.y - icon_h) * 0.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(icon)

	price.position = Vector2(left + icon_w + TAG_GAP, tag.position.y)
	price.size = Vector2(text_w, tag.size.y)


func _confirm_button(affordable: bool) -> void:
	var h: float = BUTTON_W * BUTTON_ART.get_height() / float(BUTTON_ART.get_width())
	var b := TextureButton.new()
	b.focus_mode = Control.FOCUS_NONE
	# Before the size - the same trap as the card art above.
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_normal = BUTTON_ART if affordable else BUTTON_OFF_ART
	b.custom_minimum_size = Vector2.ZERO
	b.size = Vector2(BUTTON_W, h)
	b.position = Vector2(ACTION_CX - BUTTON_W * 0.5, BUTTON_Y)
	b.disabled = not affordable
	if affordable:
		b.pressed.connect(_on_confirm)
	_content.add_child(b)

	var caption := _label(FONT_BUTTON,
		Color.WHITE if affordable else Color(0.78, 0.75, 0.72))
	caption.text = "Upgrade" if affordable else "Not enough"
	caption.clip_text = true
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.position = b.position
	caption.size = b.size


func _on_confirm() -> void:
	if _plot_id < 0:
		return
	if BuildingProgress.start_upgrade(_plot_id):
		if _on_done.is_valid():
			_on_done.call()
		hide()


func _label(size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(l)
	return l


func _fs(native: int) -> int:
	return maxi(FONT_MIN, roundi(native * BOARD_SCALE))


func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


func _countdown(seconds: float) -> String:
	var t := int(max(0.0, seconds))
	if t >= 3600:
		return "%dh %dm" % [t / 3600, (t % 3600) / 60]
	if t >= 60:
		return "%dm" % (t / 60)
	return "%ds" % t
