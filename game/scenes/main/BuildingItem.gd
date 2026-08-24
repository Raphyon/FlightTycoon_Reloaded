extends Control

# One card in the Prop Shop, built on the aircraft shop's card so the two
# screens read as one shop: same board_card1 frame, same price tag, same lock
# overlay, same orange buy button. Only the stat row differs, because a
# building has different things worth knowing.
#
# The scene is a clone of ShopItem.tscn - the layout is identical and the only
# difference is this script, so cloning beat parameterising a card that would
# then have to branch on which kind of thing it was showing.
const DISABLED_MODULATE := Color(0.6, 0.6, 0.6, 1.0)
const PRESSED_TEXTURE := preload("res://assets/buttons/button_grey3@2x.png")
const PRESSED_FLASH_TIME := 0.2

const RENT_ICON := preload("res://assets/bubbles/dollar_icon@2x.png")
const PEOPLE_ICON := preload("res://assets/hud/icon_medium_people@2x.png")
const CLOCK_Y := 38.0
const STAT_Y := 154.0
const STAT_HEIGHT := 18.0
const STAT_ICON_W := 15.0
const STAT_FONT := 11

const MONEY_ICON := preload("res://assets/hud/icon_medium_money1@2x.png")
const COIN_ICON := preload("res://assets/hud/icon_medium_coin@2x.png")

signal build_pressed(building_key: String)

var _key: String = ""
var _lock_overlay: Control
var _buy_button: TextureButton
var _state_label: Label
var _normal_texture: Texture2D


func setup(key: String) -> void:
	_key = key

	var name_label: Label = $NameLabel
	var icon: TextureRect = $IconWrap/Icon
	_lock_overlay = $IconWrap/LockOverlay
	var price_label: Label = $PriceTag/PriceLabel
	_buy_button = $BuyWrap/BuyButton
	_state_label = $BuyWrap/StateLabel

	name_label.text = BuildingLayout.display_name(key)
	var path := BuildingLayout.texture_path(key)
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	price_label.text = _format_price(BuildingLayout.price_of(key))
	# The coin building carries the coin icon, or 30 reads as absurdly cheap
	# beside a 40,000 office.
	if BuildingLayout.currency_of(key) == "coins":
		$PriceTag/MoneyIcon.texture = COIN_ICON

	_add_cycle()
	_add_stats()
	_normal_texture = _buy_button.texture_normal
	_buy_button.pressed.connect(_on_buy_pressed)
	refresh()


# 1000000 is unreadable on a 65px tag; 1.0M is not.
func _format_price(price: int) -> String:
	if price >= 1000000:
		return "%.1fM" % (price / 1000000.0)
	if price >= 10000:
		return "%dk" % (price / 1000)
	return str(price)


# Anchored rather than absolutely placed - see the long note in ShopItem._row.
# The panel sizes cards after setup(), so anything computed from our own size
# here comes out zero.
func _row(y: float, height: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.anchor_right = 1.0
	row.offset_top = y
	row.offset_bottom = y + height
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	return row


# Where the aircraft card shows its cloud rating, a building shows its cycle -
# it is the equivalent question, "how long until this does something".
func _add_cycle() -> void:
	var row := _row(CLOCK_Y, 14.0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 11)
	l.text = "%d min" % int(BuildingLayout.entry(_key).get("minutes", 0))
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)


# The two figures the original prints on its own building cards: what a cycle
# pays, and the inhabitants it brings in.
func _add_stats() -> void:
	var cells := [
		[RENT_ICON, str(BuildingLayout.rent_of(_key))],
		[PEOPLE_ICON, str(BuildingLayout.people_of(_key))],
	]
	var row := _row(STAT_Y, STAT_HEIGHT)
	row.add_theme_constant_override("separation", 0)
	for cell in cells:
		var box := HBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(box)

		var ic := TextureRect.new()
		# Before the texture, or its own size becomes the row's minimum.
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = cell[0]
		ic.custom_minimum_size = Vector2(STAT_ICON_W, STAT_HEIGHT)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(ic)

		var l := Label.new()
		l.add_theme_font_size_override("font_size", STAT_FONT)
		l.text = cell[1]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
		l.add_theme_constant_override("outline_size", 3)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)


func _on_buy_pressed() -> void:
	build_pressed.emit(_key)
	_flash_button()


func _flash_button() -> void:
	_buy_button.texture_normal = PRESSED_TEXTURE
	await get_tree().create_timer(PRESSED_FLASH_TIME).timeout
	if is_instance_valid(_buy_button):
		_buy_button.texture_normal = _normal_texture


func refresh() -> void:
	# The padlock covers the art when the building can't be had at all - the
	# level gate. Not for merely being too dear: that's saving up, not being
	# locked out. Same rule the aircraft card uses.
	var unlocked := BuildingProgress.is_unlocked(_key)
	_lock_overlay.visible = not unlocked
	_set_lock_level("")
	if not unlocked:
		_buy_button.disabled = true
		_state_label.text = "Locked"
		_set_lock_level("Lv.%d" % BuildingLayout.level_of(_key))
	elif not BuildingProgress.can_afford(_key):
		_buy_button.disabled = true
		_state_label.text = "Can't afford"
	else:
		_buy_button.disabled = false
		_state_label.text = "Build"
	_buy_button.modulate = DISABLED_MODULATE if _buy_button.disabled else Color.WHITE

# The required level, over the padlock rather than on the button. A button says
# what pressing it does; "Lv.42" is neither an instruction nor something the
# player can act on by pressing it.
func _set_lock_level(text: String) -> void:
	var l: Label = _lock_overlay.get_node_or_null("LockLevel")
	if l == null:
		l = Label.new()
		l.name = "LockLevel"
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(1, 0.94, 0.82))
		l.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
		l.add_theme_constant_override("outline_size", 5)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		_lock_overlay.add_child(l)
	l.text = text
	l.visible = text != ""
