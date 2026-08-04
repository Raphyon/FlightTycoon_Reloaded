extends PanelContainer

# The Prop Shop - what you put on a construction site.
#
# Always opens FOR A PLOT. The walkthrough's flow is that you tap a cone on an
# empty site and the business menu opens for it, so the plot is chosen first and
# the building second; the hub's Prop Shop button is a shortcut that picks the
# first free site for you rather than a different way in. That's why there is no
# browse-then-choose-a-plot mode - it would be a second flow doing the same job.
#
# Cards are built in code rather than as a scene, because a building card is a
# thumbnail, a name and a price - less than the ShopItem scene carries, and a
# .tscn for it would be more indirection than content.
const CARD_SIZE := Vector2(150, 190)
const THUMB_HEIGHT := 104.0
const COLUMNS := 5
const AFFORD_MODULATE := Color(1, 1, 1, 1)
const BROKE_MODULATE := Color(0.55, 0.55, 0.55, 1)
const MONEY_ICON := preload("res://assets/hud/icon_medium_money1@2x.png")

@onready var _grid: GridContainer = $Frame/SafeArea/Margin/VBox/Grid
@onready var _title: Label = $Frame/SafeArea/Margin/VBox/TitleLabel
@onready var _close_button: Button = $Frame/SafeArea/Margin/VBox/CloseButton

var _plot_id: int = -1
var _cards: Dictionary = {}  # building key -> {root, button, price}


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(hide)
	# The reference uses a bottom-right arrow, not a full-width bar.
	_close_button.visible = false
	BackButton.add_to($Frame, hide)
	Economy.money_changed.connect(_refresh_affordable)
	_grid.columns = COLUMNS
	for entry in BuildingLayout.BUILDINGS:
		_grid.add_child(_build_card(str(entry["key"]), str(entry["name"])))
	get_tree().root.size_changed.connect(_fit_content)


func open_for_plot(plot_id: int) -> void:
	# An occupied site has nothing to offer - demolition isn't a thing yet, so
	# opening the shop on one would be a dead end.
	if BuildingProgress.is_built(plot_id):
		return
	_plot_id = plot_id
	_title.text = "Prop Shop  -  site %d" % plot_id
	move_to_front()
	visible = true
	_refresh_affordable()
	call_deferred("_fit_content")


# The hub button's shortcut: first site with nothing on it.
func open_for_first_free_plot() -> bool:
	for plot in BuildingLayout.load_data():
		var id := int(plot.get("id", 0))
		if not BuildingProgress.is_built(id):
			open_for_plot(id)
			return true
	return false


func _build_card(key: String, display_name: String) -> Control:
	var root := PanelContainer.new()
	root.custom_minimum_size = CARD_SIZE

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	root.add_child(box)

	var thumb := TextureRect.new()
	# Before the texture, or the art's own size becomes the minimum and the
	# card grows to fit it - the trap every panel in this project has hit.
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.custom_minimum_size = Vector2(0, THUMB_HEIGHT)
	var path := BuildingLayout.texture_path(key)
	if ResourceLoader.exists(path):
		thumb.texture = load(path)
	box.add_child(thumb)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 13)
	box.add_child(name_label)

	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var coin := TextureRect.new()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.custom_minimum_size = Vector2(18, 18)
	coin.texture = MONEY_ICON
	price_row.add_child(coin)
	var price := Label.new()
	price.text = _format(BuildingProgress.cost_of(key))
	price.add_theme_font_size_override("font_size", 14)
	price_row.add_child(price)
	box.add_child(price_row)

	var buy := Button.new()
	buy.text = "Build"
	buy.pressed.connect(func() -> void: _buy(key))
	box.add_child(buy)

	_cards[key] = {"root": root, "button": buy}
	return root


func _buy(key: String) -> void:
	if _plot_id < 0:
		return
	if BuildingProgress.build(_plot_id, key):
		hide()


# Greys out what you can't afford rather than hiding it - the price is the
# information, same as the aircraft shop.
func _refresh_affordable(_unused = null) -> void:
	for key in _cards:
		var cost := BuildingProgress.cost_of(str(key))
		var ok: bool = Economy.money >= cost
		var card: Dictionary = _cards[key]
		(card["root"] as Control).modulate = AFFORD_MODULATE if ok else BROKE_MODULATE
		(card["button"] as Button).disabled = not ok


func _format(v: int) -> String:
	var s := str(v)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		call_deferred("_fit_content")


# See FuelPanel.gd's _fit_content for why this exists - the designed size is a
# guess at actual screen resolution, so shrink to whatever's really there.
func _fit_content() -> void:
	var vbox: Control = $Frame/SafeArea/Margin/VBox
	var safe_area: Control = $Frame/SafeArea
	if not is_instance_valid(vbox) or not is_instance_valid(safe_area):
		return
	vbox.scale = Vector2.ONE
	var natural := vbox.get_combined_minimum_size()
	var available := safe_area.size
	if natural.x <= 0 or natural.y <= 0 or available.x <= 0 or available.y <= 0:
		return
	var s := minf(1.0, minf(available.x / natural.x, available.y / natural.y))
	vbox.scale = Vector2(s, s)
