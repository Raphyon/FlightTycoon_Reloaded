extends PanelContainer

@onready var _title: Label = $Margin/VBox/TitleLabel
@onready var _status: Label = $Margin/VBox/StatusLabel
@onready var _action_button: Button = $Margin/VBox/ActionButton
@onready var _close_button: Button = $Margin/VBox/CloseButton

var _coin_button: Button

var _area_name: String = ""


func _ready() -> void:
	_close_button.pressed.connect(hide)
	_action_button.pressed.connect(_on_action_pressed)
	# A zone has two prices, so it needs two buttons. Built here rather than in
	# the scene for the same reason the coin price exists at all - it arrived
	# with the live zone pages, and the panel had one button and one currency.
	_coin_button = Button.new()
	_coin_button.text = "Use Coins"
	_coin_button.pressed.connect(_on_coin_pressed)
	_action_button.get_parent().add_child(_coin_button)
	_action_button.get_parent().move_child(_coin_button,
		_action_button.get_index() + 1)
	ZoneProgress.unlocked_changed.connect(_refresh)
	Progression.level_changed.connect(_refresh)
	Economy.money_changed.connect(_refresh)
	Coins.coins_changed.connect(_refresh)


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
		_coin_button.visible = false
		return
	var req: Dictionary = ZoneProgress.requirement_for(_area_name)
	var coins := int(req.get("coins", 0))
	_status.text = "Requires Level %d - $%d or %d coins to unlock" \
		% [req.level, req.cost, coins]
	var high_enough: bool = Progression.level >= req.level
	# Both costs are on the status line above - the buttons say the verb and
	# which purse it comes out of, nothing else.
	_action_button.visible = true
	_action_button.text = "Unlock"
	_action_button.disabled = not high_enough or Economy.money < req.cost
	_coin_button.visible = coins > 0
	_coin_button.disabled = not high_enough or Coins.amount < coins


func _on_action_pressed() -> void:
	ZoneProgress.unlock(_area_name)


func _on_coin_pressed() -> void:
	ZoneProgress.unlock(_area_name, true)
