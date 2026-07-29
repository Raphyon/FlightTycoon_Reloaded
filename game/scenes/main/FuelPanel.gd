extends PanelContainer

# Fuel Shop - bulk purchase tiers at a fluctuating market price (see
# FuelStore), laid out 2x2: 50/500 fuel for $ on top, 5000 fuel for $ and
# an alternate 5000-for-coins option on the bottom (see Coins/FuelStore).
#
# The 4 cells are real FuelOption.tscn instances baked directly into the
# Grid below (see Frame/SafeArea/Margin/VBox/Row/Grid in this scene), not
# code-generated - open this scene in the editor and they're visible and
# draggable immediately, no need to press Play. This script just wires them
# up to real data on _ready().
const COIN_ICON := preload("res://assets/hud/icon_medium_coin@2x.png")
const MONEY_ICON := preload("res://assets/hud/icon_medium_money1@2x.png")

const QUANTITIES := [50, 500, 5000]
const COIN_QUANTITY := 5000
const COIN_COST := 5

@onready var _grid: GridContainer = $Frame/SafeArea/Margin/VBox/Row/Grid
@onready var _close_button: Button = $Frame/SafeArea/Margin/VBox/CloseButton
@onready var _option_nodes: Dictionary = {
	50: $Frame/SafeArea/Margin/VBox/Row/Grid/Option50,
	500: $Frame/SafeArea/Margin/VBox/Row/Grid/Option500,
	5000: $Frame/SafeArea/Margin/VBox/Row/Grid/Option5000,
}
@onready var _coin_option: Node = $Frame/SafeArea/Margin/VBox/Row/Grid/OptionCoins

var _options: Dictionary = {}  # qty -> FuelOption instance


func _ready() -> void:
	_close_button.pressed.connect(hide)
	FuelStore.price_changed.connect(_refresh)
	FuelStore.fuel_changed.connect(_refresh)
	Economy.money_changed.connect(_refresh)
	Coins.coins_changed.connect(_refresh)

	for qty in QUANTITIES:
		var opt: Node = _option_nodes[qty]
		opt.setup(qty, MONEY_ICON, false)
		opt.buy_pressed.connect(func() -> void:
			FuelStore.buy(qty)
		)
		_options[qty] = opt

	_coin_option.setup(COIN_QUANTITY, COIN_ICON, false)
	_coin_option.set_price_text("%d" % COIN_COST)
	_coin_option.buy_pressed.connect(func() -> void:
		FuelStore.buy_with_coins(COIN_QUANTITY, COIN_COST)
	)

	_refresh()
	get_tree().root.size_changed.connect(_fit_content)
	call_deferred("_fit_content")


# The content's designed size is a guess at actual screen resolution, which
# has been wrong more than once - this measures the real available space in
# SafeArea (see Main.tscn) and shrinks the content to fit instead of letting
# it overflow into the background art's top/bottom decoration.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
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
	for qty in QUANTITIES:
		var cost: int = qty * FuelStore.current_price
		_options[qty].set_price_text("%d" % cost)
		_options[qty].set_affordable(Economy.money >= cost)
	_coin_option.set_affordable(Coins.amount >= COIN_COST)
