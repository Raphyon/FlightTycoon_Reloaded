extends PanelContainer

# Liveries for one aircraft. Same shape as the apron skin picker on purpose -
# coins, bought for a single thing, switch freely once owned - but what it buys
# here is a speed grade rather than a revenue bonus.
const ICON_SIZE := Vector2(120, 70)

var _aircraft_id: int = -1
var _grid: GridContainer
var _title: Label
var _rows: Dictionary = {}   # livery_key -> Button


func _ready() -> void:
	visible = false
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	vbox.add_child(_grid)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide)
	vbox.add_child(close)

	Coins.coins_changed.connect(func(_n = null) -> void: _refresh())
	AircraftSkins.liveries_changed.connect(_refresh)


func show_for_aircraft(aircraft_id: int) -> void:
	# Same reason as RoutePickerPanel - the apron panel is later in the tree
	# and would otherwise cover this.
	move_to_front()
	_aircraft_id = aircraft_id
	_build()
	show()


func _build() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_rows.clear()
	var a := Fleet.get_aircraft(_aircraft_id)
	if not a:
		return
	_title.text = "%s - livery" % str(ShopCatalog.entry_for(a.model_key).get("name", a.model_key))

	# "None" first, so a painted aircraft can go back to its factory colours.
	_grid.add_child(_option(a, {"key": "", "name": "Default"}))
	for e in AircraftSkins.for_model(a.model_key):
		_grid.add_child(_option(a, e))
	_refresh()


func _option(a: FleetAircraft, entry: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)

	var preview := TextureRect.new()
	# expand_mode before the texture, or the hull art's own size becomes the
	# minimum and the cell balloons.
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var body: String = str(entry.get("body", Fleet.WORLD_SPRITES.get(a.model_key, {}).get("body", "")))
	if body != "" and ResourceLoader.exists(body):
		preview.texture = load(body)
	preview.custom_minimum_size = ICON_SIZE
	col.add_child(preview)

	var name_label := Label.new()
	name_label.text = str(entry["name"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	col.add_child(name_label)

	var b := Button.new()
	var key := str(entry["key"])
	b.pressed.connect(func() -> void: _on_pressed(key))
	col.add_child(b)
	_rows[key] = b
	return col


func _on_pressed(livery_key: String) -> void:
	if livery_key != "" and not AircraftSkins.is_owned(_aircraft_id, livery_key):
		if not AircraftSkins.buy(_aircraft_id, livery_key):
			return
	AircraftSkins.apply(_aircraft_id, livery_key)
	_refresh()


func _refresh(_unused = null) -> void:
	var a := Fleet.get_aircraft(_aircraft_id)
	if not a:
		return
	for key in _rows:
		var b: Button = _rows[key]
		if key == "":
			b.text = "Worn" if a.livery == "" else "Remove"
			b.disabled = a.livery == ""
		elif a.livery == key:
			b.text = "Worn"
			b.disabled = true
		elif AircraftSkins.is_owned(_aircraft_id, key):
			b.text = "Wear"
			b.disabled = false
		else:
			# What the coins actually buy, stated on the button.
			b.text = "Buy (%d) +1 speed" % AircraftSkins.COST
			b.disabled = Coins.amount < AircraftSkins.COST
