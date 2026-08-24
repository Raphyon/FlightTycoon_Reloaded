extends Control

const PROGRESS_WIDTH := 70.0

@onready var _icon: TextureRect = $Icon
@onready var _count_label: Label = $CountBadgeBg/CountLabel
@onready var _name_label: Label = $NameLabel
@onready var _level_label: Label = $AffinityRow/StarWrap/LevelLabel
@onready var _progress_clip: Control = $AffinityRow/ProgressWrap/ProgressClip

# The shop's own button art, the same pair every other panel uses - red because
# scrapping is not a purchase, grey when there is nothing to scrap. A
# TextureButton carries no text of its own, so the caption is a Label pinned
# over it, exactly as BoostPanel and DailyLoginPanel do it.
const SELL_ART := preload("res://assets/buttons/button_red1@2x.png")
const SELL_OFF_ART := preload("res://assets/buttons/button_grey3@2x.png")
const SELL_HEIGHT := 26.0

var _model_key: String
var _sell_button: TextureButton
var _sell_label: Label
var _choose_button: Button


# Coin-bought aircraft never offer it (see Fleet.can_sell) - selling one would
# be a laundering route out of the premium currency.
#
# ENABLED ON SELLABLE_COUNT, not idle_count. An aircraft parked on its pad can
# be sold; is_idle() only means it has no pad at all. See Fleet.sell_one.
func show_sell(enabled: bool) -> void:
	if not enabled:
		for n in [_sell_button, _sell_label]:
			if is_instance_valid(n):
				n.queue_free()
		_sell_button = null
		_sell_label = null
		return
	if Fleet.sell_value(_model_key) <= 0:
		return
	if not is_instance_valid(_sell_button):
		_sell_button = TextureButton.new()
		_sell_button.name = "SellButton"
		_sell_button.focus_mode = Control.FOCUS_NONE
		# Before the texture, or the art's 136x62 becomes the minimum and the
		# anchors below are silently clamped up to it.
		_sell_button.ignore_texture_size = true
		_sell_button.stretch_mode = TextureButton.STRETCH_SCALE
		_sell_button.custom_minimum_size = Vector2.ZERO
		_sell_button.anchor_left = 0.0
		_sell_button.anchor_right = 1.0
		_sell_button.anchor_top = 1.0
		_sell_button.anchor_bottom = 1.0
		_sell_button.offset_top = -SELL_HEIGHT - 2.0
		_sell_button.offset_bottom = -2.0
		_sell_button.pressed.connect(_on_sell_pressed)
		add_child(_sell_button)

		_sell_label = Label.new()
		_sell_label.name = "SellLabel"
		_sell_label.add_theme_font_size_override("font_size", 12)
		_sell_label.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
		_sell_label.add_theme_constant_override("outline_size", 4)
		_sell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sell_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_sell_label.clip_text = true
		_sell_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sell_label.anchor_left = 0.0
		_sell_label.anchor_right = 1.0
		_sell_label.anchor_top = 1.0
		_sell_label.anchor_bottom = 1.0
		_sell_label.offset_top = -SELL_HEIGHT - 2.0
		_sell_label.offset_bottom = -2.0
		add_child(_sell_label)

	var can: bool = Fleet.sellable_count(_model_key) > 0
	_sell_button.texture_normal = SELL_ART if can else SELL_OFF_ART
	_sell_button.disabled = not can
	_sell_label.text = "Sell $%s" % _thousands(Fleet.sell_value(_model_key))
	_sell_label.add_theme_color_override("font_color",
		Color(1, 1, 1) if can else Color(0.78, 0.75, 0.72))


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
	Fleet.sell_one(_model_key)


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
	# Widen the clip, not the bolt. The bar is a lightning shape rather than a
	# rectangle, so scaling the fill would stretch its tip and its kink along
	# with it; sliding the clip edge wipes the bolt in from the left instead.
	_progress_clip.size.x = PROGRESS_WIDTH * progress
