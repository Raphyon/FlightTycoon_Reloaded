extends PanelContainer

# Pure fleet roster now - grouped by aircraft model (count owned + affinity
# level), no assign/recall here anymore. Assigning happens entirely through
# the apron's own panel (see AssignPickerPanel).
const HANGAR_TYPE_CARD_SCENE := preload("res://scenes/main/HangarTypeCard.tscn")

@onready var _grid: GridContainer = $Frame/SafeArea/Margin/VBox/Grid
@onready var _close_button: Button = $Frame/SafeArea/Margin/VBox/CloseButton

var _cards: Dictionary = {}  # model_key -> HangarTypeCard


func _ready() -> void:
	_close_button.pressed.connect(hide)
	Fleet.fleet_changed.connect(_refresh)
	AircraftAffinity.affinity_changed.connect(_refresh_affinity)
	get_tree().root.size_changed.connect(_fit_content)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh()
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


func _refresh(_unused = null) -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()

	var counts: Dictionary = {}  # model_key -> count
	for a in Fleet.aircraft:
		counts[a.model_key] = counts.get(a.model_key, 0) + 1

	for model_key in counts:
		var entry := _catalog_entry(model_key)
		var card := HANGAR_TYPE_CARD_SCENE.instantiate()
		_grid.add_child(card)
		var icon_texture: Texture2D = load("res://assets/shop/%s" % entry["icon"]) if entry.size() > 0 else null
		card.setup(model_key, entry.get("name", model_key), icon_texture, counts[model_key])
		_cards[model_key] = card

	call_deferred("_fit_content")


func _refresh_affinity(_unused = null) -> void:
	for card in _cards.values():
		card.refresh()


func _catalog_entry(model_key: String) -> Dictionary:
	for entry in ShopCatalog.ENTRIES:
		if entry["key"] == model_key:
			return entry
	return {}
