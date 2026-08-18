extends Control

# APRON LIVERIES. The same shop as the aircraft one (LiveryPickerPanel), for the
# paint on a pad rather than on a plane.
#
# It used to be a PanelContainer with an EMPTY stylebox holding default Godot
# labels and buttons - a transparent 640x440 box of grey widgets floating over
# the world, in a game where every other panel is built from the same board and
# button art. This is the only shop that never got the treatment.
#
# Built in code for the reason the others are: the cards are data-shaped
# (ApronSkins.SKINS), so there is nothing to lay out by hand.

const BOARD := preload("res://assets/board/board_changelist@ipad.png")
# The building shop's pieces, same as LiveryPickerPanel now uses. These cards
# were on board_apron_info_icon - a 157x90 badge - which is why nothing shaped
# like a card ever sat on it properly.
const CARD_ART := preload("res://assets/board/board_card1@2x.png")
const TAG_ART := preload("res://assets/board/board_price@2x.png")
const BUTTON_ART := preload("res://assets/buttons/button_orange2@2x.png")
const BUTTON_OFF_ART := preload("res://assets/buttons/button_grey3@2x.png")
const ARROW_LEFT := preload("res://assets/buttons/button_arrow_left@2x.png")
const ARROW_RIGHT := preload("res://assets/buttons/button_arrow_right@2x.png")
const ICON_COIN := preload("res://assets/hud/icon_medium_coin@2x.png")

const BOARD_SCALE := 0.72
const BOARD_SIZE := Vector2(679, 325)

const TITLE_Y := 0.055
const VISIBLE := 3

# CARD_ART is 245x400 and the building shop draws it at exactly half. So do we,
# and every piece inside is a fraction OF THE CARD rather than of the board -
# the old layout mixed board fractions with card fractions and drifted.
const CARD_PX := Vector2(122.5, 200.0)
const CARD_W := CARD_PX.x / BOARD_SIZE.x
const CARD_H := CARD_PX.y / BOARD_SIZE.y
const CARD_GAP := 30.0 / BOARD_SIZE.x

const TAG_X := 0.06
const TAG_W := 0.88
const TAG_Y := 0.03
const TAG_INNER_GAP := 5.0
const ART_RECT := Rect2(0.10, 0.15, 0.80, 0.45)
const NAME_Y := 0.60
const NAME_H := 0.17
# Breathing room either side of the name before the type starts shrinking.
const NAME_PAD := 10.0
const BUTTON_RECT := Rect2(0.222, 0.79, 0.556, 0.155)
const ROW_Y := 0.29
const ARROW_SCALE := 2.0
const ARROW_HIT_W := 0.10

const FONT_TITLE := 22
# NOT run through _fs() - a card is 122.5x200 whatever the 0.72 board does, so
# its text is the building shop's literal 12 and 14.
const FONT_CARD_NAME := 12
const FONT_CARD_TEXT := 14
const FONT_MIN := 9

const COLOR_TITLE := Color(1.0, 0.93, 0.82)
const COLOR_NAME := Color(1.0, 0.96, 0.90)
const COLOR_LOCKED := Color(0.80, 0.72, 0.62)
const COLOR_PRICE := Color(1.0, 0.87, 0.44)

var _apron_id: int = -1
var _first := 0
var _content: Control
var _title: Label
var _prev: TextureButton
var _next: TextureButton


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

	_title = _label(_fs(FONT_TITLE), COLOR_TITLE)
	_title.position = _px(0.0, TITLE_Y)
	_title.size = _px(1.0, 0.14)
	add_child(_title)

	_prev = _arrow(ARROW_LEFT, ARROW_HIT_W * 0.5)
	_next = _arrow(ARROW_RIGHT, 1.0 - ARROW_HIT_W * 0.5)
	_prev.pressed.connect(func() -> void: _scroll(-1))
	_next.pressed.connect(func() -> void: _scroll(1))

	CloseButton.add_to(self, BOARD_SIZE, hide)

	ApronSkins.owned_changed.connect(_rebuild)
	Coins.coins_changed.connect(func(_n = null) -> void: _rebuild())
	# Levelling up is what makes a new skin appear, so it has to redraw.
	Progression.level_changed.connect(func(_l = null) -> void: _rebuild())


func show_for_apron(apron_id: int) -> void:
	_apron_id = apron_id
	_first = 0
	visible = true
	move_to_front()
	_rebuild()


# --- layout helpers, in board fractions so one board size drives everything ---

func _px(fx: float, fy: float) -> Vector2:
	return Vector2(BOARD_SIZE.x * fx, BOARD_SIZE.y * fy)


func _fs(native: int) -> int:
	return maxi(FONT_MIN, roundi(native * BOARD_SCALE))


func _label(size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.20, 0.11, 0.04))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _arrow(art: Texture2D, cx: float) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = art
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.size = Vector2(BOARD_SIZE.x * ARROW_HIT_W, art.get_height() * ARROW_SCALE)
	b.position = Vector2(BOARD_SIZE.x * cx - b.size.x * 0.5,
		BOARD_SIZE.y * (ROW_Y + CARD_H * 0.5) - b.size.y * 0.5)
	add_child(b)
	return b


# --- the row ------------------------------------------------------------------

func _scroll(by: int) -> void:
	_first = clampi(_first + by, 0, maxi(0, ApronSkins.SKINS.size() - VISIBLE))
	_rebuild()


func _rebuild(_a = null) -> void:
	if not visible or _content == null:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	_title.text = "Apron %d  -  paint" % _apron_id
	var total: int = ApronSkins.SKINS.size()
	var shown: int = mini(VISIBLE, total)
	var span: float = shown * CARD_W + maxi(0, shown - 1) * CARD_GAP
	var left: float = (1.0 - span) * 0.5
	for i in range(shown):
		var entry: Dictionary = ApronSkins.SKINS[_first + i]
		_card(entry, left + i * (CARD_W + CARD_GAP))
	_prev.disabled = _first <= 0
	_next.disabled = _first + VISIBLE >= total
	_prev.modulate = Color(1, 1, 1, 0.35 if _prev.disabled else 1.0)
	_next.modulate = Color(1, 1, 1, 0.35 if _next.disabled else 1.0)


func _card(entry: Dictionary, fx: float) -> void:
	var key := str(entry["key"])
	var equipped: bool = ApronSkins.get_skin_key(_apron_id) == key
	var owned: bool = ApronSkins.is_owned(_apron_id, key)
	var unlocked: bool = ApronSkins.is_unlocked(key)

	var origin := Vector2(BOARD_SIZE.x * fx, BOARD_SIZE.y * ROW_Y)

	var card := TextureRect.new()
	card.texture = CARD_ART
	# Before the size - otherwise the art's 245x400 becomes the minimum.
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.position = origin
	card.size = CARD_PX
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked or (not owned and Coins.amount < ApronSkins.SKIN_COST):
		card.modulate = Color(0.72, 0.70, 0.70)
	_content.add_child(card)

	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2.ZERO
	art.position = origin + _in_card(ART_RECT.position)
	art.size = _in_card(ART_RECT.size)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := str(entry.get("texture", ""))
	if ResourceLoader.exists(path):
		art.texture = load(path)
	_content.add_child(art)

	var name_label := _label(FONT_CARD_NAME, COLOR_NAME)
	# IN THE TREE BEFORE IT IS MEASURED. _label returns an unparented Label, and
	# an unparented Control resolves get_theme_font to the engine fallback - a
	# narrower face than the one it will actually be drawn in. Measuring there
	# said "Celebration Cake" was 99px when the real answer was 132.
	_content.add_child(name_label)
	name_label.text = str(entry.get("name", key))
	name_label.position = origin + Vector2(0, CARD_PX.y * NAME_Y)
	# THE FONT FITS THE CARD, rather than the card being asked to fit the font.
	# A Label's minimum size is the width of its string, so assigning a narrower
	# width is silently clamped back up - "Celebration Cake" came out 132px wide
	# on a 122.5px card. autowrap does not fix it either: it lowers the minimum
	# through update_minimum_size(), which is DEFERRED, so the assignment on the
	# next line still sees the old one. Shrinking the type is the only version
	# that is true the moment it runs.
	var name_font := name_label.get_theme_font("font")
	var name_size := FONT_CARD_NAME
	while name_size > FONT_MIN and name_font.get_string_size(name_label.text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, name_size).x > CARD_PX.x - NAME_PAD:
		name_size -= 1
	name_label.add_theme_font_size_override("font_size", name_size)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size = Vector2(CARD_PX.x, CARD_PX.y * NAME_H)

	# The tag carries a price only while there is one to pay.
	if unlocked and not owned:
		var tag := TextureRect.new()
		tag.texture = TAG_ART
		tag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tag.stretch_mode = TextureRect.STRETCH_SCALE
		tag.size = Vector2(CARD_PX.x * TAG_W, 0)
		tag.size.y = tag.size.x * TAG_ART.get_height() / float(TAG_ART.get_width())
		tag.position = origin + Vector2(CARD_PX.x * TAG_X, CARD_PX.y * TAG_Y)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(tag)

		# Coin and number are laid out as one centred group, not pinned to the
		# pill's left edge with the number adrift in the middle.
		var coin_px: float = tag.size.y * 0.8
		var price := _label(FONT_CARD_TEXT, COLOR_PRICE)
		_content.add_child(price)
		price.text = str(ApronSkins.SKIN_COST)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var digits: float = price.get_minimum_size().x
		var group: float = coin_px + TAG_INNER_GAP + digits
		var group_x: float = tag.position.x + (tag.size.x - group) * 0.5

		var coin := TextureRect.new()
		coin.texture = ICON_COIN
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.custom_minimum_size = Vector2.ZERO
		coin.size = Vector2(coin_px, coin_px)
		coin.position = Vector2(group_x,
			tag.position.y + (tag.size.y - coin_px) * 0.5)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(coin)

		var text_h: float = price.get_minimum_size().y
		price.position = Vector2(group_x + coin_px + TAG_INNER_GAP,
			tag.position.y + (tag.size.y - text_h) * 0.5)
		price.size = Vector2(digits, text_h)

	# A REAL BUY BUTTON. The card used to be one invisible flat Button with a
	# caption under the art, so nothing on screen looked pressable - and a
	# locked card still says WHAT unlocks it rather than only refusing.
	var caption := "Buy"
	var enabled := false
	if equipped:
		caption = "In use"
	elif owned:
		caption = "Use"
		enabled = true
	elif not unlocked:
		caption = "Level %d" % int(entry.get("level", 1))
	else:
		enabled = Coins.amount >= ApronSkins.SKIN_COST

	var button := TextureButton.new()
	button.focus_mode = Control.FOCUS_NONE
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.texture_normal = BUTTON_ART if enabled else BUTTON_OFF_ART
	button.custom_minimum_size = Vector2.ZERO
	button.position = origin + _in_card(BUTTON_RECT.position)
	button.size = _in_card(BUTTON_RECT.size)
	button.disabled = not enabled
	if enabled:
		button.pressed.connect(_on_pressed.bind(key))
	_content.add_child(button)

	var caption_label := _label(FONT_CARD_TEXT, Color.WHITE if enabled
		else COLOR_LOCKED)
	_content.add_child(caption_label)
	caption_label.text = caption
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.clip_text = true
	caption_label.position = button.position
	caption_label.size = button.size


func _in_card(v: Vector2) -> Vector2:
	return v * CARD_PX


func _on_pressed(skin_key: String) -> void:
	if not ApronSkins.is_owned(_apron_id, skin_key):
		if not ApronSkins.buy_skin(_apron_id, skin_key):
			return
	ApronSkins.set_skin(_apron_id, skin_key)
	hide()
