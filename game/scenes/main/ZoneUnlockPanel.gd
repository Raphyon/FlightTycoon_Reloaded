extends PanelContainer

@onready var _title: Label = $Margin/VBox/TitleLabel
@onready var _status: Label = $Margin/VBox/StatusLabel
@onready var _action_button: Button = $Margin/VBox/ActionButton
@onready var _close_button: Button = $Margin/VBox/CloseButton

var _area_name: String = ""


func _ready() -> void:
	_close_button.pressed.connect(hide)
	_action_button.pressed.connect(_on_action_pressed)
	ZoneProgress.unlocked_changed.connect(_refresh)
	Progression.level_changed.connect(_refresh)
	Economy.money_changed.connect(_refresh)


func show_zone(area_name: String) -> void:
	_area_name = area_name
	_title.text = area_name
	show()
	_refresh()


func _refresh(_unused = null) -> void:
	if not visible or _area_name == "":
		return
	if ZoneProgress.is_unlocked(_area_name):
		_status.text = "Unlocked"
		_action_button.visible = false
		return
	var req: Dictionary = ZoneProgress.requirement_for(_area_name)
	_status.text = "Requires Level %d - $%d to unlock" % [req.level, req.cost]
	_action_button.visible = true
	# The cost is on the status line above - a button says the verb.
	_action_button.text = "Unlock"
	_action_button.disabled = Progression.level < req.level or Economy.money < req.cost


func _on_action_pressed() -> void:
	ZoneProgress.unlock(_area_name)
