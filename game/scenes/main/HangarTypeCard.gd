extends Control

const PROGRESS_WIDTH := 70.0

@onready var _icon: TextureRect = $Icon
@onready var _count_label: Label = $CountBadgeBg/CountLabel
@onready var _name_label: Label = $NameLabel
@onready var _level_label: Label = $AffinityRow/StarWrap/LevelLabel
@onready var _progress_fill: ColorRect = $AffinityRow/ProgressWrap/ProgressFill

var _model_key: String
var _sell_button: Button
var _choose_button: Button


# Selling lives on the idle submenu only: an aircraft standing on a pad is in
# service, and the hangar's other two tabs aren't a place to scrap things from.
# Coin-bought aircraft never offer it (see Fleet.can_sell).
func show_sell(enabled: bool) -> void:
	if not enabled:
		if is_instance_valid(_sell_button):
			_sell_button.queue_free()
			_sell_button = null
		return
	if Fleet.sell_value(_model_key) <= 0:
		return
	if not is_instance_valid(_sell_button):
		_sell_button = Button.new()
		_sell_button.name = "SellButton"
		_sell_button.custom_minimum_size = Vector2(0, 26)
		_sell_button.anchor_left = 0.0
		_sell_button.anchor_right = 1.0
		_sell_button.anchor_top = 1.0
		_sell_button.anchor_bottom = 1.0
		_sell_button.offset_top = -28.0
		_sell_button.offset_bottom = -2.0
		_sell_button.pressed.connect(_on_sell_pressed)
		add_child(_sell_button)
	_sell_button.text = "Sell $%s" % _thousands(Fleet.sell_value(_model_key))
	_sell_button.disabled = Fleet.idle_count(_model_key) <= 0


# While the hangar is being used to pick an aircraft for a route, the whole
# card becomes the button - there is nothing else to do with it in that mode.
func show_choose(enabled: bool, on_pick: Callable) -> void:
	if not enabled:
		if is_instance_valid(_choose_button):
			_choose_button.queue_free()
			_choose_button = null
		return
	if not is_instance_valid(_choose_button):
		_choose_button = Button.new()
		_choose_button.name = "ChooseButton"
		_choose_button.flat = true
		_choose_button.focus_mode = Control.FOCUS_NONE
		_choose_button.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_choose_button)
	for c in _choose_button.pressed.get_connections():
		_choose_button.pressed.disconnect(c["callable"])
	_choose_button.pressed.connect(on_pick.bind(_model_key))


func _on_sell_pressed() -> void:
	Fleet.sell_one_idle(_model_key)


# 17500 -> 17,500. Long numbers on a small button are unreadable otherwise.
func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


func setup(model_key: String, display_name: String, icon_texture: Texture2D, count: int) -> void:
	_model_key = model_key
	_icon.texture = icon_texture
	_name_label.text = display_name
	_count_label.text = str(count)
	refresh()


func refresh() -> void:
	_level_label.text = str(AircraftAffinity.level_for(_model_key))
	var progress := AircraftAffinity.progress_for(_model_key)
	_progress_fill.size.x = PROGRESS_WIDTH * progress
