extends Control

const PROGRESS_WIDTH := 70.0

@onready var _icon: TextureRect = $Icon
@onready var _count_label: Label = $CountBadgeBg/CountLabel
@onready var _name_label: Label = $NameLabel
@onready var _level_label: Label = $AffinityRow/StarWrap/LevelLabel
@onready var _progress_fill: ColorRect = $AffinityRow/ProgressWrap/ProgressFill

var _model_key: String


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
