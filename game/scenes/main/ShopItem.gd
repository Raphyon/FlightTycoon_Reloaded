extends Control

const DISABLED_MODULATE := Color(0.6, 0.6, 0.6, 1.0)
const PRESSED_TEXTURE := preload("res://assets/buttons/button_grey3@2x.png")
const PRESSED_FLASH_TIME := 0.2

# Range, drawn as a row of clouds above the art - same icon and same meaning
# as the distance clouds on a friend's card, so "5 clouds of range" and "this
# airport is 3 clouds away" read against each other directly.
const CLOUD := preload("res://assets/bubbles/cloud_icon@2x.png")
const CLOUD_SIZE := Vector2(17, 12)
const CLOUD_GAP := 1.0
const CLOUD_Y := 38.0

# A 2x2 under the name - grade and PAYOUT on top, fuel and XP beneath. That is
# the reference card's own layout, and photographs of it settled a question we
# had answered wrong: the figure beside its money icon is what a leg PAYS, not
# a fare and not a seat count.
#
# Seats came off the card with it. A cabin size is an input to the payout and
# the payout is now shown directly, so printing both was printing the same
# fact twice - and the two numbers a player actually chooses between, money and
# XP, were the two that were missing.
const FORCE_ICON := preload("res://assets/hud/stat_force@2x.png")
const FUEL_ICON := preload("res://assets/bubbles/drum_icon@2x.png")
const XP_ICON := preload("res://assets/hud/icon_medium_xp@2x.png")
const STAT_Y := 152.0
const STAT_ROW_GAP := 17.0
const STAT_HEIGHT := 16.0
# 13px ICONS IN A UI SCALED WELL ABOVE THAT, and every cell packed to its own
# left edge - so three equal-width columns held three ragged left-aligned
# groups and the row read as misaligned rather than as a grid. The icon is
# sized to the row now, and each cell centres its own icon-and-number so the
# three sit under one another whatever the numbers say.
const STAT_ICON_W := 18.0
const STAT_FONT := 11

const COIN_ICON := preload("res://assets/hud/icon_medium_coin@2x.png")

var _entry: Dictionary
var _buy_button: TextureButton
var _state_label: Label
var _lock_overlay: Control
var _normal_texture: Texture2D


func setup(entry: Dictionary) -> void:
	_entry = entry

	var name_label: Label = $NameLabel
	var icon: TextureRect = $IconWrap/Icon
	_lock_overlay = $IconWrap/LockOverlay
	var price_label: Label = $PriceTag/PriceLabel
	_buy_button = $BuyWrap/BuyButton
	_state_label = $BuyWrap/StateLabel

	name_label.text = entry["name"]
	icon.texture = load("res://assets/shop/%s" % entry["icon"])
	price_label.text = _format_price(int(entry["price"]))
	# Coin-priced aircraft carry the coin icon, so the tag can't be read as a
	# absurdly cheap cash price.
	if ShopCatalog.currency_of(entry) == ShopCatalog.COINS:
		$PriceTag/MoneyIcon.texture = COIN_ICON
	_add_clouds(int(ShopCatalog.stat(entry["key"], "range")))
	_add_stats(entry)
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


# Both rows are anchored containers, NOT absolutely-positioned children.
# ShopPanel calls setup() before it parents the card, so at this point our own
# `size` is still zero - anything computed from it (a centred x, a column
# width) comes out at 0 or negative and the whole row collapses into the top
# left corner. Anchoring to the card's width instead means the layout is
# resolved whenever the card actually gets a size, and it survives the
# vbox.scale that _fit_content applies afterwards.
func _row(y: float, height: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.anchor_right = 1.0
	row.offset_left = 0.0
	row.offset_right = 0.0
	row.offset_top = y
	row.offset_bottom = y + height
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	return row


func _add_clouds(range_units: int) -> void:
	var row := _row(CLOUD_Y, CLOUD_SIZE.y)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(CLOUD_GAP))
	for i in range(range_units):
		var c := TextureRect.new()
		# Before the texture, or the icon's own 34x24 becomes the minimum and
		# the row comes out double width.
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.texture = CLOUD
		c.custom_minimum_size = CLOUD_SIZE
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(c)


func _add_stats(entry: Dictionary) -> void:
	var key: String = entry["key"]
	# SEATS x TICKET, and NOT multiplied by the cloud rating.
	#
	# It was multiplied, on the reasoning that the clouds are drawn right above
	# so the card may as well show what the aircraft actually earns on the route
	# it was built for. That is defensible and it is not what the reference
	# does: its B747 card reads 5,000, and 5,000 is 500 seats at 10 a head. The
	# clouds are a separate number on the card because the player is meant to
	# multiply them in.
	#
	# Showing the product made every figure five times the one the live cards
	# use, which is the unit every price and fare in ShopCatalog was set in.
	var pay := int(round(float(Fleet.passengers(key)) * Fleet.ticket_price(key)))
	var rows := [
		# null icon = the value carries its own mark. Cash is "$" everywhere
		# rather than a coin icon here and a "$" elsewhere.
		[[FORCE_ICON, str(ShopCatalog.stat(key, "force"))], [null, "$%s" % _compact(pay)]],
		[[FUEL_ICON, str(ShopCatalog.stat(key, "fuel"))],
			[XP_ICON, _compact(Fleet.xp_for_claim(key))]],
	]
	for i in rows.size():
		_stat_row(STAT_Y + float(i) * STAT_ROW_GAP, rows[i])


# Four-and-five-figure payouts do not fit a 122px card at eleven point, and the
# top of the ladder is six.
func _compact(n: int) -> String:
	if n < 10000:
		return str(n)
	if n < 1000000:
		return "%.1fk" % (float(n) / 1000.0)
	return "%.1fM" % (float(n) / 1000000.0)


func _stat_row(y: float, cells: Array) -> void:
	var row := _row(y, STAT_HEIGHT)
	row.add_theme_constant_override("separation", 0)
	for cell in cells:
		# One expanding cell per stat, so the three split the card evenly
		# whatever it ends up being.
		var box := HBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 3)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(box)

		if cell[0] == null:
			var only := Label.new()
			only.add_theme_font_size_override("font_size", STAT_FONT)
			only.text = cell[1]
			only.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			only.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			only.add_theme_color_override("font_color", Color.WHITE)
			only.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
			only.add_theme_constant_override("outline_size", 3)
			only.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(only)
			continue

		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = cell[0]
		# A SQUARE SLOT, EQUAL FOR ALL THREE. The source icons run from 0.62
		# aspect (stat_force, 16x26 portrait) to 1.55 (icon_medium_xp, 51x33
		# landscape), so KEEP_ASPECT_CENTERED drew them anywhere from 10px to
		# 18px wide inside a 18x16 box - three different footprints in what is
		# meant to read as one row. Equal square slots give them a common
		# anchor; making them look like a matched SET needs the art normalised,
		# which no layout here can do.
		ic.custom_minimum_size = Vector2(STAT_ICON_W, STAT_ICON_W)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(ic)

		var l := Label.new()
		l.add_theme_font_size_override("font_size", STAT_FONT)
		l.text = cell[1]
		# Shrinks to its text instead of eating the cell, or centring the box
		# would centre a full-width label and move nothing.
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
		l.add_theme_constant_override("outline_size", 3)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)


func _on_buy_pressed() -> void:
	Fleet.buy(_entry["key"], _entry["price"], ShopCatalog.currency_of(_entry))
	_flash_button()


func _flash_button() -> void:
	_buy_button.texture_normal = PRESSED_TEXTURE
	await get_tree().create_timer(PRESSED_FLASH_TIME).timeout
	if is_instance_valid(_buy_button):
		_buy_button.texture_normal = _normal_texture


func refresh() -> void:
	var coins := ShopCatalog.currency_of(_entry) == ShopCatalog.COINS
	# The padlock covers the art whenever the aircraft can't be had at all -
	# level-gated, or no world sprite to fly. Not for merely being too dear:
	# that's a matter of saving up, not of being locked out. Lives in refresh
	# rather than setup because levelling up clears it.
	_lock_overlay.visible = (not _entry.get("has_world_sprite", false)
		or not ShopCatalog.unlocked(_entry["key"]))
	var balance: int = Coins.amount if coins else Economy.money
	_set_lock_level("")
	if not _entry.get("has_world_sprite", false):
		_buy_button.disabled = true
		_state_label.text = "No art yet"
	elif not ShopCatalog.unlocked(_entry["key"]):
		# Locked by level, which no amount of money fixes - so say which level
		# rather than "Can't afford".
		_buy_button.disabled = true
		_state_label.text = "Locked"
		_set_lock_level("Lv.%d" % ShopCatalog.level_for(_entry["key"]))
	elif balance < int(_entry["price"]):
		_buy_button.disabled = true
		_state_label.text = "Buy"
	else:
		_buy_button.disabled = false
		_state_label.text = "Buy"
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
