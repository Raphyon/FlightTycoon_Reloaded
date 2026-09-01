extends PanelContainer

# Landing screen for the Shop button - a grid of category buttons, each
# leading to its own sub-screen. Only Aircraft Shop and Fuel Shop are wired
# up to real systems so far; the rest are visible but locked (same
# lock-overlay language as ShopItem/ApronSlot use for "not available yet"),
# not build-per-category screens we haven't designed yet.
const LockOverlayScript := preload("res://scenes/main/LockOverlay.gd")
const BOARD_TEXTURE := preload("res://assets/board/board_store@2x.png")
const ICON_SIZE := Vector2(100, 100)
# 120x34 AT THE DEFAULT FONT DID NOT HOLD THE LONGEST LABEL. "Expanding
# Airport" wraps to two lines and spilled past the board art, and the reason
# line the Prop Shop now carries ("no empty sites") makes three. Wider, taller,
# and a font size chosen so three lines fit rather than left at whatever the
# theme happened to give.
const BOARD_SIZE := Vector2(132, 48)
const BOARD_FONT := 12
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
		{"icon": "button_store09@2x.png", "label": "Prop Shop", "on_pressed": _open_prop_shop,
			"why_not": _prop_shop_unavailable},
	]
	for entry in _categories:
		_grid.add_child(_build_category_button(entry))
	_refresh_availability()

	get_tree().root.size_changed.connect(_fit_content)
	call_deferred("_fit_content")


# See FuelPanel.gd's _fit_content for why this exists - the designed size is
# a guess at actual screen resolution, so shrink to whatever's really there.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		call_deferred("_fit_content")
		_refresh_availability()


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
	entry["_button"] = button
	icon_wrap.add_child(button)

	if not enabled:
		var lock := Control.new()
		lock.set_script(LockOverlayScript)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.custom_minimum_size = ICON_SIZE
		lock.size = ICON_SIZE
		icon_wrap.add_child(lock)

	vbox.add_child(icon_wrap)
	var board := _build_label_board(entry["label"])
	entry["_label"] = board.get_child(1)
	# THE NAME IS PART OF THE BUTTON. It sits directly under the icon, reads as
	# one control, and did nothing when pressed - so half of every target was
	# dead. Forwarded to the same handler, and it follows the icon's disabled
	# state through _refresh_availability.
	if enabled:
		board.mouse_filter = Control.MOUSE_FILTER_STOP
		board.gui_input.connect(_on_board_input.bind(entry))
	vbox.add_child(board)

	return vbox


# WHETHER A SHOP CAN BE ENTERED IS NOT FIXED AT BUILD TIME. The Prop Shop
# always opens ON a site, so with every site taken there is nothing to show -
# and it was still pressable, doing nothing on screen and printing the reason
# to a console the player does not have. Re-decided every time the hub opens,
# with the reason on the label rather than in stdout.
func _refresh_availability() -> void:
	for entry in _categories:
		if not entry.has("why_not") or not entry.has("_button"):
			continue
		var why: String = (entry["why_not"] as Callable).call()
		var ok := why == ""
		var button: TextureButton = entry["_button"]
		button.disabled = not ok
		button.modulate = Color.WHITE if ok else DISABLED_MODULATE
		var label: Label = entry["_label"]
		label.text = entry["label"] if ok else "%s\n%s" % [entry["label"], why]


# "" when it can be opened, otherwise the reason it cannot.
func _prop_shop_unavailable() -> String:
	if not BuildingProgress.buildings_unlocked():
		return "opens with Zone 2"
	for plot in BuildingLayout.load_data():
		if not BuildingProgress.is_built(int(plot.get("id", 0))):
			return ""
	return "no empty sites"


func _on_board_input(event: InputEvent, entry: Dictionary) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return
	var button: TextureButton = entry.get("_button")
	if button and button.disabled:
		return
	(entry["on_pressed"] as Callable).call()


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
	label.add_theme_font_size_override("font_size", BOARD_FONT)
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
	elif not BuildingProgress.buildings_unlocked():
		print("The Prop Shop opens with Zone2 - buy it in the Expansion Shop.")
	else:
		print("No empty construction sites - place some with G, or build on one directly.")
