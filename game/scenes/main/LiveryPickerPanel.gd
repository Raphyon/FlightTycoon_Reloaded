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
# The same four pieces the building shop is built from, so the two screens read
# as one game. The livery cards were on board_apron_info_icon - a 157x90 badge -
# which is why they looked wrong at any card shape that was not 157x90.
const CARD_ART := preload("res://assets/board/board_card1@2x.png")
const TAG_ART := preload("res://assets/board/board_price@2x.png")
const COIN_ICON := preload("res://assets/hud/icon_medium_coin@2x.png")
# Cut from the airport sheet by tools/arrows_derive.py - the other shops page
# with literal "<" and ">" Buttons because nobody had found these yet.
const ARROW_LEFT := preload("res://assets/buttons/button_arrow_left@2x.png")
const ARROW_RIGHT := preload("res://assets/buttons/button_arrow_right@2x.png")
const BUTTON_ART := preload("res://assets/buttons/button_orange2@2x.png")
const BUTTON_OFF_ART := preload("res://assets/buttons/button_grey3@2x.png")

const BOARD_NATIVE := Vector2(943, 452)
const BOARD_SCALE := 0.72
const BOARD_SIZE := Vector2(679, 325)

const TITLE_Y := 0.055
# Three at a time. A fourth would not fit beside the arrows at a card size the
# art is still readable at, and no model has more than three anyway.
const VISIBLE := 3

# CARD_ART is 245x400 and the building shop draws it at exactly half that. So do
# we: 122.5x200, its own aspect, no stretch. Everything inside is a fraction OF
# THE CARD rather than of the board, so the pieces travel together if the card
# ever resizes - the old layout mixed the two and drifted.
const CARD_PX := Vector2(122.5, 200.0)
const CARD_W := CARD_PX.x / BOARD_SIZE.x
const CARD_H := CARD_PX.y / BOARD_SIZE.y
const CARD_GAP := 30.0 / BOARD_SIZE.x

# Only x and width - the tag's height comes from its own art, so the pill keeps
# its shape instead of being squashed to whatever fraction looked right.
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
# The art is 20x24. Drawn at 2x for a touchable size, with the BUTTON larger
# still - a 40px triangle is a fine thing to look at and a poor thing to hit.
const ARROW_SCALE := 2.0
const ARROW_HIT_W := 0.085

const FONT_TITLE := 22
# NOT run through _fs(). Everything else on this panel is a fraction of a board
# drawn at 0.72, but a card is 122.5x200 whatever the board does, so its text is
# the building shop's literal 12 and 14 - at _fs() these came out 9pt.
const FONT_CARD_NAME := 12
const FONT_CARD_TEXT := 14
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

	# One card, built the way BuildingItem builds one: card art, price tag over
	# the top, the picture, the name, and a BUY BUTTON. The old card had no
	# button at all - the whole card was one invisible Button and the only clue
	# was a line of text reading "Tap to wear", so nothing on screen looked
	# pressable. A shop should have the same control in the same place whatever
	# it is selling.
	var origin := Vector2(BOARD_SIZE.x * fx, BOARD_SIZE.y * ROW_Y)

	var card := TextureRect.new()
	card.texture = CARD_ART
	# Before the size, always - otherwise the art's 245x400 is the minimum and
	# the assignment below is silently clamped back up.
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.position = origin
	card.size = CARD_PX
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if equipped:
		card.modulate = Color(1.0, 1.0, 1.0)
	elif not owned and Coins.amount < AircraftSkins.COST:
		# Out of reach reads as dimmed, the same as a locked plot.
		card.modulate = Color(0.72, 0.70, 0.70)
	_content.add_child(card)

	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2.ZERO
	art.position = origin + _in_card(ART_RECT.position)
	art.size = _in_card(ART_RECT.size)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The livery's own hull art, or the catalogue icon for the stock option -
	# the point of the card is seeing what you are buying.
	var path := str(opt.get("body", ""))
	if path == "":
		path = "res://assets/shop/%s" % ShopCatalog.entry_for(a.model_key).get("icon", "")
	if ResourceLoader.exists(path):
		art.texture = load(path)
	_content.add_child(art)

	var name_label := _label(FONT_CARD_NAME, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.text = str(opt.get("name", key))
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

	# The price tag only exists while there is a price. On an owned livery the
	# slot stays empty rather than showing a paid-for number.
	if not owned:
		var tag := TextureRect.new()
		tag.texture = TAG_ART
		tag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tag.stretch_mode = TextureRect.STRETCH_SCALE
		tag.size = Vector2(CARD_PX.x * TAG_W, 0)
		tag.size.y = tag.size.x * TAG_ART.get_height() / float(TAG_ART.get_width())
		tag.position = origin + Vector2(CARD_PX.x * TAG_X, CARD_PX.y * TAG_Y)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(tag)

		var coin_px: float = tag.size.y * 0.8
		var price := _label(FONT_CARD_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		price.text = str(AircraftSkins.COST)
		var digits: float = price.get_minimum_size().x
		var group: float = coin_px + TAG_INNER_GAP + digits
		var group_x: float = tag.position.x + (tag.size.x - group) * 0.5

		var coin := TextureRect.new()
		coin.texture = COIN_ICON
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
		price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price.add_theme_color_override("font_color",
			Color(1, 0.92, 0.62) if Coins.amount >= AircraftSkins.COST
			else Color(1, 0.62, 0.55))

	var caption := "Worn"
	var enabled := false
	if equipped:
		caption = "Worn"
	elif owned:
		caption = "Wear"
		enabled = true
	else:
		caption = "Buy"
		enabled = Coins.amount >= AircraftSkins.COST

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
		button.pressed.connect(_on_card_pressed.bind(key))
	_content.add_child(button)

	var caption_label := _label(FONT_CARD_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	caption_label.text = caption
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.clip_text = true
	caption_label.position = button.position
	caption_label.size = button.size
	caption_label.add_theme_color_override("font_color",
		Color.WHITE if enabled else Color(0.78, 0.75, 0.72))


func _in_card(v: Vector2) -> Vector2:
	return v * CARD_PX


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
