extends PanelContainer

@onready var _list: VBoxContainer = $Margin/VBox/List
@onready var _empty_label: Label = $Margin/VBox/EmptyLabel
@onready var _close_button: Button = $Margin/VBox/CloseButton

var _apron_id: int = -1


func _ready() -> void:
	_close_button.pressed.connect(hide)
	Fleet.fleet_changed.connect(_refresh)


func show_for_apron(apron_id: int) -> void:
	_apron_id = apron_id
	show()
	_refresh()


func _refresh(_unused = null) -> void:
	if not visible:
		return
	for child in _list.get_children():
		child.queue_free()

	var by_type: Dictionary = {}  # model_key -> Array[FleetAircraft]
	for a in Fleet.idle_aircraft():
		if not by_type.has(a.model_key):
			by_type[a.model_key] = []
		by_type[a.model_key].append(a)

	_empty_label.visible = by_type.is_empty()

	for model_key in by_type:
		_list.add_child(_build_row(model_key, by_type[model_key]))


func _build_row(model_key: String, group: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var entry := _catalog_entry(model_key)
	var icon := TextureRect.new()
	if entry.size() > 0:
		icon.texture = load("res://assets/shop/%s" % entry["icon"])
	icon.custom_minimum_size = Vector2(60, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var label := Label.new()
	label.text = "%s (x%d idle)" % [entry.get("name", model_key), group.size()]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var button := Button.new()
	button.text = "Select"
	var aircraft_id: int = group[0].id
	button.pressed.connect(func() -> void:
		Fleet.assign_to_apron(aircraft_id, _apron_id)
		hide()
	)
	row.add_child(button)

	return row


func _catalog_entry(model_key: String) -> Dictionary:
	for entry in ShopCatalog.ENTRIES:
		if entry["key"] == model_key:
			return entry
	return {}
