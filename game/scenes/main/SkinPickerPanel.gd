extends PanelContainer

const ICON_SIZE := Vector2(90, 60)

@onready var _grid: GridContainer = $Margin/VBox/Grid
@onready var _close_button: Button = $Margin/VBox/CloseButton

var _apron_id: int = -1
var _buttons: Dictionary = {}  # skin_key -> Button


func _ready() -> void:
	_close_button.pressed.connect(hide)
	for entry in ApronSkins.SKINS:
		_grid.add_child(_build_skin_option(entry))
	ApronSkins.owned_changed.connect(_refresh)
	Coins.coins_changed.connect(_refresh)
	# Levelling up is what makes a new skin appear, so it has to redraw.
	Progression.level_changed.connect(_refresh)


func show_for_apron(apron_id: int) -> void:
	_apron_id = apron_id
	show()
	_refresh()


func _build_skin_option(entry: Dictionary) -> Control:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)

	var icon := TextureRect.new()
	icon.texture = load(entry["texture"])
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(icon)

	var name_label := Label.new()
	name_label.text = entry["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var button := Button.new()
	button.pressed.connect(func() -> void: _on_skin_pressed(entry["key"]))
	vbox.add_child(button)
	_buttons[entry["key"]] = button

	return vbox


func _on_skin_pressed(skin_key: String) -> void:
	if not ApronSkins.is_owned(_apron_id, skin_key):
		if not ApronSkins.buy_skin(_apron_id, skin_key):
			return
	ApronSkins.set_skin(_apron_id, skin_key)
	hide()


func _refresh(_unused = null) -> void:
	for entry in ApronSkins.SKINS:
		var button: Button = _buttons[entry["key"]]
		if ApronSkins.is_owned(_apron_id, entry["key"]):
			button.text = "Select"
			button.disabled = false
		elif not ApronSkins.is_unlocked(entry["key"]):
			# Locked by level, which coins can't fix - name the level instead.
			button.text = "Level %d" % ApronSkins.level_for(entry["key"])
			button.disabled = true
		else:
			button.text = "Buy (%d coins)" % ApronSkins.SKIN_COST
			button.disabled = Coins.amount < ApronSkins.SKIN_COST
