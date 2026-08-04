extends PanelContainer

# Landing screen for the Shop button - a grid of category buttons, each
# leading to its own sub-screen. Only Aircraft Shop and Fuel Shop are wired
# up to real systems so far; the rest are visible but locked (same
# lock-overlay language as ShopItem/ApronSlot use for "not available yet"),
# not build-per-category screens we haven't designed yet.
const LockOverlayScript := preload("res://scenes/main/LockOverlay.gd")
const BOARD_TEXTURE := preload("res://assets/board/board_store@2x.png")
const ICON_SIZE := Vector2(100, 100)
const BOARD_SIZE := Vector2(120, 34)
const DISABLED_MODULATE := Color(0.55, 0.55, 0.55, 1.0)

@onready var _grid: GridContainer = $Frame/SafeArea/Margin/VBox/Grid
@onready var _close_button: Button = $Frame/SafeArea/Margin/VBox/CloseButton

var _categories: Array = []


func _ready() -> void:
	_close_button.pressed.connect(hide)
	# The reference uses a bottom-right arrow, not a full-width bar.
	_close_button.visible = false
	BackButton.add_to($Frame, hide)
	_categories = [
		{"icon": "button_store01@2x.png", "label": "Aircraft Shop", "on_pressed": _open_aircraft_shop},
		{"icon": "button_store02@2x.png", "label": "Fuel Shop", "on_pressed": _open_fuel_shop},
		{"icon": "button_store03@2x.png", "label": "Gold"},
		{"icon": "button_store04@2x.png", "label": "Terminal"},
		{"icon": "button_store06@2x.png", "label": "Expanding Airport", "on_pressed": _open_expansion_shop},
		{"icon": "button_store09@2x.png", "label": "Prop Shop", "on_pressed": _open_prop_shop},
	]
	for entry in _categories:
		_grid.add_child(_build_category_button(entry))

	get_tree().root.size_changed.connect(_fit_content)
	call_deferred("_fit_content")


# See FuelPanel.gd's _fit_content for why this exists - the designed size is
# a guess at actual screen resolution, so shrink to whatever's really there.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		call_deferred("_fit_content")


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


func _build_category_button(entry: Dictionary) -> Control:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon_wrap := Control.new()
	icon_wrap.custom_minimum_size = ICON_SIZE

	var button := TextureButton.new()
	button.texture_normal = load("res://assets/buttons/%s" % entry["icon"])
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = ICON_SIZE
	var enabled: bool = entry.has("on_pressed")
	button.disabled = not enabled
	if enabled:
		button.pressed.connect(entry["on_pressed"])
	else:
		button.modulate = DISABLED_MODULATE
	icon_wrap.add_child(button)

	if not enabled:
		var lock := Control.new()
		lock.set_script(LockOverlayScript)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.custom_minimum_size = ICON_SIZE
		lock.size = ICON_SIZE
		icon_wrap.add_child(lock)

	vbox.add_child(icon_wrap)
	vbox.add_child(_build_label_board(entry["label"]))

	return vbox


func _build_label_board(text: String) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = BOARD_SIZE

	var board := TextureRect.new()
	board.texture = BOARD_TEXTURE
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(board)

	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(label)

	return wrap


func _open_aircraft_shop() -> void:
	hide()
	get_node("../ShopPanel").show()


func _open_fuel_shop() -> void:
	hide()
	get_node("../FuelPanel").show()


func _open_expansion_shop() -> void:
	hide()
	get_node("../ExpansionShopPanel").show()


# The Prop Shop always builds ON a site, so this picks the first free one
# rather than opening a browse mode that would then have to ask. With every
# site taken there is nothing to offer, so it says so instead of opening empty.
func _open_prop_shop() -> void:
	var panel := get_node("../PropShopPanel")
	if panel.open_for_first_free_plot():
		hide()
	else:
		print("No empty construction sites - place some with G, or build on one directly.")
