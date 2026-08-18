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
const FRAME_EMPTY := preload("res://assets/board/board_apron_info_icon1@2x.png")
const FRAME_FILLED := preload("res://assets/board/board_apron_info_icon2@2x.png")
const ARROW_LEFT := preload("res://assets/buttons/button_arrow_left@2x.png")
const ARROW_RIGHT := preload("res://assets/buttons/button_arrow_right@2x.png")
const ICON_COIN := preload("res://assets/hud/icon_medium_coin@2x.png")

const BOARD_SCALE := 0.72
const BOARD_SIZE := Vector2(679, 325)
# Nine-sliced at the frame art's own corner radius, so a card taller than the
# 157x90 badge keeps its border instead of being squashed into it.
const FRAME_MARGIN := 22

const TITLE_Y := 0.055
const VISIBLE := 3
const CARD_W := 0.225
const CARD_H := 0.50
const CARD_GAP := 0.025
const ROW_Y := 0.26
const ARROW_SCALE := 2.0
const ARROW_HIT_W := 0.10

const FONT_TITLE := 22
const FONT_NAME := 15
const FONT_STATE := 13
const FONT_MIN := 9

const COLOR_TITLE := Color(1.0, 0.93, 0.82)
const COLOR_NAME := Color(1.0, 0.96, 0.90)
const COLOR_OWNED := Color(0.62, 0.88, 0.62)
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

	var frame := NinePatchRect.new()
	frame.texture = FRAME_FILLED if equipped else FRAME_EMPTY
	frame.patch_margin_left = FRAME_MARGIN
	frame.patch_margin_right = FRAME_MARGIN
	frame.patch_margin_top = FRAME_MARGIN
	frame.patch_margin_bottom = FRAME_MARGIN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = _px(fx, ROW_Y)
	frame.size = _px(CARD_W, CARD_H)
	_content.add_child(frame)

	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2.ZERO
	art.position = _px(fx + 0.018, ROW_Y + 0.05)
	art.size = _px(CARD_W - 0.036, CARD_H * 0.55)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := str(entry.get("texture", ""))
	if ResourceLoader.exists(path):
		art.texture = load(path)
	if not owned:
		art.modulate = Color(0.55, 0.55, 0.6, 1)
	_content.add_child(art)

	var name_label := _label(_fs(FONT_NAME), COLOR_NAME)
	name_label.text = str(entry.get("name", key))
	name_label.position = _px(fx, ROW_Y + CARD_H * 0.60)
	name_label.size = _px(CARD_W, 0.10)
	_content.add_child(name_label)

	# Three states, and the locked one says WHAT unlocks it rather than just
	# refusing - a card that only greys out reads as broken.
	var state := _label(_fs(FONT_STATE), COLOR_OWNED)
	if equipped:
		state.text = "In use"
	elif owned:
		state.text = "Owned"
	elif not unlocked:
		state.text = "Level %d" % int(entry.get("level", 1))
		state.add_theme_color_override("font_color", COLOR_LOCKED)
	else:
		state.text = "%d coins" % ApronSkins.SKIN_COST
		state.add_theme_color_override("font_color", COLOR_PRICE)
	state.position = _px(fx, ROW_Y + CARD_H * 0.78)
	state.size = _px(CARD_W, 0.10)
	_content.add_child(state)

	var button := Button.new()
	button.flat = true
	button.position = _px(fx, ROW_Y)
	button.size = _px(CARD_W, CARD_H)
	button.disabled = equipped or not unlocked \
		or (not owned and Coins.amount < ApronSkins.SKIN_COST)
	button.pressed.connect(_on_pressed.bind(key))
	_content.add_child(button)


func _on_pressed(skin_key: String) -> void:
	if not ApronSkins.is_owned(_apron_id, skin_key):
		if not ApronSkins.buy_skin(_apron_id, skin_key):
			return
	ApronSkins.set_skin(_apron_id, skin_key)
	hide()
