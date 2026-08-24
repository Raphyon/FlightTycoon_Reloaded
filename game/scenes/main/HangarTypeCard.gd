extends Control

const PROGRESS_WIDTH := 70.0

@onready var _icon: TextureRect = $Icon
@onready var _count_label: Label = $CountBadgeBg/CountLabel
@onready var _name_label: Label = $NameLabel
@onready var _level_label: Label = $AffinityRow/StarWrap/LevelLabel
@onready var _progress_clip: Control = $AffinityRow/ProgressWrap/ProgressClip



var _model_key: String
var _choose_button: Button
var _details_button: Button


# Tapping the card opens the sell panel. It used to be a button crammed into the
# 26px under the affinity row, and the shop's button art is 136x62 with a
# gradient across BOTH axes - no flat band, so no nine-slice - which meant
# either squashing a pill into a bar or shrinking it to 57px and dropping the
# word "Sell". The panel has room for it at its own proportions.
func show_details(enabled: bool, on_open: Callable) -> void:
	if not enabled:
		if is_instance_valid(_details_button):
			_details_button.queue_free()
			_details_button = null
		return
	if not is_instance_valid(_details_button):
		_details_button = Button.new()
		_details_button.name = "DetailsButton"
		_details_button.flat = true
		_details_button.focus_mode = Control.FOCUS_NONE
		_details_button.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_details_button)
	for c in _details_button.pressed.get_connections():
		_details_button.pressed.disconnect(c["callable"])
	_details_button.pressed.connect(on_open.bind(_model_key))


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
