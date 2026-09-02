extends PanelContainer

# Fuel Shop - bulk purchase tiers at a fluctuating market price (see
# FuelStore), laid out 2x2: 50/500 on top, 5000/50000 on the bottom, all four
# bought with cash.
#
# The tiers are not just quantities - each carries a price multiplier
# (FuelStore.BATCH_MULTIPLIER), from +20% on 50 units to -10% on 50,000, shown
# on the cell so the reason one batch looks dear is legible.
#
# The fourth cell used to be 5000 fuel for 5 coins. It was replaced rather than
# added to because the top tier had stopped being a top tier: a full apron of
# 110 Arks burns 100 a leg each, so a single round trip of the fleet costs
# 22,000 - the old 5000 ceiling was a fifth of one cycle, and late game meant
# tapping the same button over and over. 50,000 covers a bit over two cycles.
# Fuel is no longer buyable with coins as a result; the coin sinks that remain
# are aprons, apron skins, liveries and the coin-priced aircraft.
#
# The 4 cells are real FuelOption.tscn instances baked directly into the
# Grid below (see Frame/SafeArea/Margin/VBox/Row/Grid in this scene), not
# code-generated - open this scene in the editor and they're visible and
# draggable immediately, no need to press Play. This script just wires them
# up to real data on _ready().
const MONEY_ICON := preload("res://assets/hud/icon_medium_money1@2x.png")

const QUANTITIES := [50, 500, 5000, 50000]
const DELIVERY_FONT := 15
const DELIVERY_COLOR := Color(1.0, 0.86, 0.5, 1.0)


var _delivery: Label
@onready var _grid: GridContainer = $Frame/SafeArea/Margin/VBox/Row/Grid
@onready var _close_button: Button = $Frame/SafeArea/Margin/VBox/CloseButton
@onready var _option_nodes: Dictionary = {
	50: $Frame/SafeArea/Margin/VBox/Row/Grid/Option50,
	500: $Frame/SafeArea/Margin/VBox/Row/Grid/Option500,
	5000: $Frame/SafeArea/Margin/VBox/Row/Grid/Option5000,
	50000: $Frame/SafeArea/Margin/VBox/Row/Grid/Option50000,
}

var _options: Dictionary = {}  # qty -> FuelOption instance


func _ready() -> void:
	_close_button.pressed.connect(hide)
	# The reference uses a bottom-right arrow, not a full-width bar.
	_close_button.visible = false
	BackButton.add_to($Frame, hide)
	# WHAT YOU HAVE ALREADY PAID FOR. Fuel lands on a delay now, so without this
	# the tank does not move when you buy and there is nothing on screen saying
	# why - which reads as the purchase having failed.
	_delivery = Label.new()
	_delivery.add_theme_font_size_override("font_size", DELIVERY_FONT)
	_delivery.add_theme_color_override("font_color", DELIVERY_COLOR)
	_delivery.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
	_delivery.add_theme_constant_override("outline_size", 4)
	_delivery.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_delivery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Frame/SafeArea/Margin/VBox.add_child(_delivery)
	FuelStore.delivery_changed.connect(_refresh)
	FuelStore.price_changed.connect(_refresh)
	FuelStore.fuel_changed.connect(_refresh)
	Economy.money_changed.connect(_refresh)

	for qty in QUANTITIES:
		var opt: Node = _option_nodes[qty]
		opt.setup(qty, MONEY_ICON, false)
		opt.buy_pressed.connect(func() -> void:
			FuelStore.buy(qty)
		)
		_options[qty] = opt

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


# The countdown has to tick, and nothing else on this panel changes per second.
func _process(_delta: float) -> void:
	if visible and is_instance_valid(_delivery):
		_update_delivery()


func _update_delivery() -> void:
	var units := FuelStore.pending_units()
	if units <= 0:
		_delivery.text = ""
		return
	_delivery.text = "%s units on the way - arriving in %s" % [
		FloatingText.grouped(units), _mmss(FuelStore.seconds_until_delivery())]


func _mmss(seconds: float) -> String:
	var t := int(ceil(maxf(seconds, 0.0)))
	if t >= 3600:
		return "%dh %02dm" % [t / 3600, (t % 3600) / 60]
	return "%d:%02d" % [t / 60, t % 60]


func _refresh(_unused = null) -> void:
	_update_delivery()
	for qty in QUANTITIES:
		var cost: int = FuelStore.cost_of(qty)
		_options[qty].set_price_text("%d" % cost)
		# The premium or discount, spelled out. The multiplier is invisible in a
		# total - "600" and "500" for the same 50 units look like the market
		# moved, not like small batches cost more.
		_options[qty].set_affordable(Economy.money >= cost)
