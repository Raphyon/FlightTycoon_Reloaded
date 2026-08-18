extends Control

# Liveries for one aircraft.
#
# Same shape as the apron skin picker on purpose - coins, bought for a single
# aircraft, switched freely once owned - but what it buys here is a speed grade
# rather than a revenue bonus (see AircraftSkins).
#
# Rebuilt on board_changelist@ipad, replacing a bare MarginContainer/VBox with
# Godot's default grey panel behind it. Deliberately a SMALL window and a SINGLE
# ROW: a model has one to three liveries, so a grid was mostly empty space, and
# the row scrolls rather than paging because there is never enough to page
# through - you are choosing between a handful of paint jobs, not shopping.
const BOARD := preload("res://assets/board/board_changelist@ipad.png")
const FRAME_EMPTY := preload("res://assets/board/board_apron_info_icon1@2x.png")
const FRAME_FILLED := preload("res://assets/board/board_apron_info_icon2@2x.png")
const COIN_ICON := preload("res://assets/hud/icon_medium_coin@2x.png")
# Cut from the airport sheet by tools/arrows_derive.py - the other shops page
# with literal "<" and ">" Buttons because nobody had found these yet.
const ARROW_LEFT := preload("res://assets/buttons/button_arrow_left@2x.png")
const ARROW_RIGHT := preload("res://assets/buttons/button_arrow_right@2x.png")

const BOARD_NATIVE := Vector2(943, 452)
const BOARD_SCALE := 0.72
const BOARD_SIZE := Vector2(679, 325)

const TITLE_Y := 0.055
# Three at a time. A fourth would not fit beside the arrows at a card size the
# art is still readable at, and no model has more than three anyway.
const VISIBLE := 3
# The corner radius of the frame art, so nine-slicing leaves it alone.
const FRAME_MARGIN := 22

const CARD_W := 0.225
const CARD_H := 0.50
const CARD_GAP := 0.025
const ROW_Y := 0.26
# The art is 20x24. Drawn at 2x for a touchable size, with the BUTTON larger
# still - a 40px triangle is a fine thing to look at and a poor thing to hit.
const ARROW_SCALE := 2.0
const ARROW_HIT_W := 0.085

const FONT_TITLE := 22
const FONT_NAME := 15
const FONT_STATE := 13
const FONT_MIN := 9

var _aircraft_id: int = -1
var _content: Control
var _title: Label
var _prev: TextureButton
var _next: TextureButton
# Index of the leftmost card on screen. The list is "Default" plus whatever
# AircraftSkins has for this model, so it always has at least one entry.
var _first := 0
var _options: Array = []


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

	_title = _label(_fs(FONT_TITLE), HORIZONTAL_ALIGNMENT_CENTER)
	_title.position = _px(0.0, TITLE_Y)
	_title.size = _px(1.0, 0.14)

	_prev = _arrow(ARROW_LEFT, ARROW_HIT_W * 0.5)
	_next = _arrow(ARROW_RIGHT, 1.0 - ARROW_HIT_W * 0.5)
	_prev.pressed.connect(func() -> void: _scroll(-1))
	_next.pressed.connect(func() -> void: _scroll(1))

	CloseButton.add_to(self, BOARD_SIZE, hide)

	Coins.coins_changed.connect(func(_n = null) -> void: _rebuild())
	AircraftSkins.liveries_changed.connect(_rebuild)


func _px(fx: float, fy: float) -> Vector2:
	return Vector2(BOARD_SIZE.x * fx, BOARD_SIZE.y * fy)


func _fs(native: int) -> int:
	return maxi(FONT_MIN, roundi(native * BOARD_SCALE))


func _label(size_px: int, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(l)
	return l


func _arrow(art: Texture2D, cx: float) -> TextureButton:
	var b := TextureButton.new()
	b.focus_mode = Control.FOCUS_NONE
	# Before the size, or the art's own dimensions become the minimum and the
	# button refuses to shrink - the trap every panel here has hit.
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.texture_normal = art
	b.size = Vector2(BOARD_SIZE.x * ARROW_HIT_W, art.get_height() * ARROW_SCALE)
	b.position = Vector2(BOARD_SIZE.x * cx - b.size.x * 0.5,
		BOARD_SIZE.y * (ROW_Y + CARD_H * 0.5) - b.size.y * 0.5)
	add_child(b)
	return b


func show_for_aircraft(aircraft_id: int) -> void:
	# Same reason as RoutePickerPanel - the apron panel is later in the tree and
	# would otherwise cover this.
	move_to_front()
	_aircraft_id = aircraft_id
	_first = 0
	visible = true
	_rebuild()


func _scroll(by: int) -> void:
	_first = clampi(_first + by, 0, maxi(0, _options.size() - VISIBLE))
	_rebuild()


func _rebuild() -> void:
	if not visible:
		return
	# Out of the tree NOW, not next frame. queue_free is deferred, so two
	# rebuilds in one frame - which happens every time a card is tapped, since
	# apply() emits liveries_changed and then we rebuild again - would draw the
	# old row on top of the new one until the frame ended.
	for c in _content.get_children():
		if c == _title:
			continue
		_content.remove_child(c)
		c.queue_free()

	var a := Fleet.get_aircraft(_aircraft_id)
	if a == null:
		hide()
		return

	_title.text = "%s  -  Liveries" % str(
		ShopCatalog.entry_for(a.model_key).get("name", a.model_key))

	# "Default" first, so a painted aircraft can always go back to its factory
	# colours - and so a model with no liveries at all still shows something
	# rather than an empty row.
	_options = [{"key": "", "name": "Default"}]
	_options.append_array(AircraftSkins.for_model(a.model_key))
	_first = clampi(_first, 0, maxi(0, _options.size() - VISIBLE))

	var shown: int = mini(VISIBLE, _options.size())
	var span: float = shown * CARD_W + maxi(0, shown - 1) * CARD_GAP
	var left: float = 0.5 - span * 0.5
	for i in range(shown):
		var opt: Dictionary = _options[_first + i]
		_card(a, opt, left + i * (CARD_W + CARD_GAP))

	_prev.disabled = _first <= 0
	_next.disabled = _first + VISIBLE >= _options.size()
	_prev.modulate = Color(1, 1, 1, 0.35) if _prev.disabled else Color.WHITE
	_next.modulate = Color(1, 1, 1, 0.35) if _next.disabled else Color.WHITE
	# Hidden rather than greyed when the whole list fits - two dead arrows
	# either side of three cards reads as a broken control.
	var scrolls := _options.size() > VISIBLE
	_prev.visible = scrolls
	_next.visible = scrolls


func _card(a: FleetAircraft, opt: Dictionary, fx: float) -> void:
	var key := str(opt.get("key", ""))
	var equipped := a.livery == key
	var owned := key == "" or a.owned_liveries.has(key)

	# NINE-SLICED, not scaled. The art is a 157x90 badge and the card is 153x162
	# - taller than it is wide - so STRETCH_SCALE squashed it to half its
	# proportions, worst on the equipped card because that is the one using the
	# filled variant. Nine-slicing keeps the corners and the border at their
	# authored size and stretches only the middle.
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
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = _px(fx + 0.018, ROW_Y + 0.05)
	art.size = _px(CARD_W - 0.036, CARD_H * 0.55)
	# The livery's own hull art, or the catalogue icon for the stock option -
	# the point of the card is seeing what you are buying.
	var path := str(opt.get("body", ""))
	if path == "":
		path = "res://assets/shop/%s" % ShopCatalog.entry_for(a.model_key).get("icon", "")
	if ResourceLoader.exists(path):
		art.texture = load(path)
	# Not yours yet: shown dimmed, so the row reads as a shop rather than as a
	# wardrobe you already own.
	if not owned:
		art.modulate = Color(0.55, 0.55, 0.6, 1)
	_content.add_child(art)

	var name_label := _label(_fs(FONT_NAME), HORIZONTAL_ALIGNMENT_CENTER)
	name_label.text = str(opt.get("name", key))
	name_label.position = _px(fx, ROW_Y + CARD_H * 0.60)
	name_label.size = _px(CARD_W, 0.10)

	var state := _label(_fs(FONT_STATE), HORIZONTAL_ALIGNMENT_CENTER)
	state.position = _px(fx, ROW_Y + CARD_H * 0.78)
	state.size = _px(CARD_W, 0.10)
	if equipped:
		state.text = "Equipped"
		state.add_theme_color_override("font_color", Color(0.72, 1.0, 0.72))
	elif owned:
		state.text = "Tap to wear"
		state.add_theme_color_override("font_color", Color(1, 0.94, 0.80))
	else:
		state.text = "%d coins" % AircraftSkins.COST
		var afford := Coins.amount >= AircraftSkins.COST
		state.add_theme_color_override("font_color",
			Color(1, 0.90, 0.55) if afford else Color(1, 0.62, 0.55))

	# The card IS the button - one tap buys it if it is not yours and wears it
	# if it is. A separate buy button per card would double the furniture in a
	# window this size for a decision that only ever has one next step.
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.modulate = Color(1, 1, 1, 0)
	b.position = _px(fx, ROW_Y)
	b.size = _px(CARD_W, CARD_H)
	b.disabled = equipped or (not owned and Coins.amount < AircraftSkins.COST)
	b.pressed.connect(_on_card_pressed.bind(key))
	_content.add_child(b)


func _on_card_pressed(livery_key: String) -> void:
	var a := Fleet.get_aircraft(_aircraft_id)
	if a == null:
		return
	# Buying immediately wears it. Paying ten coins and then having to tap the
	# same card again to see the paint is a step that exists only because the
	# two operations happen to be separate functions.
	if livery_key != "" and not a.owned_liveries.has(livery_key):
		if not AircraftSkins.buy(_aircraft_id, livery_key):
			return
	AircraftSkins.apply(_aircraft_id, livery_key)
	_rebuild()
