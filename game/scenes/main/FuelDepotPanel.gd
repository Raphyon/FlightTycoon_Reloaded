extends PanelContainer

# Fuel Depot - the two upgrades that decide how fast fuel arrives and how much
# of it can be waiting when you get back. The store next door (FuelPanel) still
# sells fuel by the batch; this is what makes buying it optional.
#
# THE CARDS ARE BUILT IN CODE, unlike FuelPanel's four, which are real
# FuelOption instances baked into its scene. Two reasons: there are two of them
# rather than four, and each one reads out a DIFFERENT pair of numbers - a rate
# against a rate, and hours against hours - so a shared card scene would be a
# scene with two of everything and a flag deciding which half to hide.
const CARD_TEXTURE := preload("res://assets/board/board_aircraft_list@2x.png")
const BUY_NORMAL := preload("res://assets/buttons/button_orange2@2x.png")
# 136x62 both, so this one CAN be a pressed texture rather than a tint - see
# RoutesPanel.PRESS_TINT for the case where the art has no partner its own size.
const BUY_PRESSED := preload("res://assets/buttons/button_grey3@2x.png")

const CARD_SIZE := Vector2(420, 132)
const BUY_SIZE := Vector2(136, 46)
const TITLE_FONT := 24
const LABEL_FONT := 19
const READOUT_FONT := 16
const BUY_FONT := 17
const OUTLINE := Color(0.25, 0.10, 0.02, 1)

@onready var _vbox: VBoxContainer = $Frame/SafeArea/Margin/VBox
@onready var _close_button: Button = $Frame/SafeArea/Margin/VBox/CloseButton

var _status: Label
var _cards: Dictionary = {}  # "tankers" / "depot" -> {value, cost, button}


func _ready() -> void:
	_close_button.pressed.connect(hide)
	_close_button.visible = false
	BackButton.add_to($Frame, hide)
	_build()
	FuelDepot.depot_changed.connect(_refresh)
	FuelStore.fuel_changed.connect(func(_n: int) -> void: _refresh())
	Economy.money_changed.connect(func(_n: int) -> void: _refresh())
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh()


func _build() -> void:
	var title := _label("Fuel Depot", TITLE_FONT)
	_vbox.add_child(title)
	_vbox.move_child(title, 0)

	_status = _label("", READOUT_FONT)
	_status.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5, 1.0))
	_vbox.add_child(_status)
	_vbox.move_child(_status, 1)

	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 18)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_vbox.add_child(grid)
	_vbox.move_child(grid, 2)

	_cards["tankers"] = _card(grid, "Tanker fleet", "Barrels an hour", FuelDepot.buy_tanker)
	_cards["depot"] = _card(grid, "Depot size", "Hours banked before it overflows", FuelDepot.buy_depot)


# One upgrade: what it is, what it currently gives against what the next one
# would, and the price. The subtitle carries the UNIT, because "6 -> 7" on its
# own says nothing about whether that is a lot.
func _card(parent: Control, name: String, unit: String, on_buy: Callable) -> Dictionary:
	var card := Control.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	parent.add_child(card)

	var board := TextureRect.new()
	board.texture = CARD_TEXTURE
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.size = CARD_SIZE
	board.custom_minimum_size = CARD_SIZE
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(board)

	var heading := _label(name, LABEL_FONT)
	heading.position = Vector2(20, 14)
	card.add_child(heading)

	var sub := _label(unit, READOUT_FONT)
	sub.position = Vector2(20, 44)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	card.add_child(sub)

	var value := _label("", LABEL_FONT)
	value.position = Vector2(20, 78)
	card.add_child(value)

	var button := TextureButton.new()
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.texture_normal = BUY_NORMAL
	button.texture_pressed = BUY_PRESSED
	button.custom_minimum_size = BUY_SIZE
	button.size = BUY_SIZE
	button.position = Vector2(CARD_SIZE.x - BUY_SIZE.x - 20, (CARD_SIZE.y - BUY_SIZE.y) * 0.5)
	button.pressed.connect(func() -> void: on_buy.call())
	card.add_child(button)

	var cost := _label("", BUY_FONT)
	cost.size = BUY_SIZE
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cost)

	return {"value": value, "cost": cost, "button": button}


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _refresh(_unused = null) -> void:
	if _status == null:
		return
	_status.text = "%d / %d barrels   -   %s an hour   -   %.0f hours banked" % [
		FuelStore.amount, FuelDepot.capacity(), _n(FuelDepot.rate()), FuelDepot.hours()]

	var t: Dictionary = _cards["tankers"]
	if FuelDepot.tankers_maxed():
		t["value"].text = "%s an hour  (max)" % _n(FuelDepot.rate())
		_set_locked(t)
	else:
		var next_rate := FuelDepot.rate() * FuelDepot.RATE_GROWTH
		t["value"].text = "%s  ->  %s an hour" % [_n(FuelDepot.rate()), _n(next_rate)]
		_set_price(t, FuelDepot.tanker_cost())

	var d: Dictionary = _cards["depot"]
	if FuelDepot.depot_maxed():
		d["value"].text = "%.0f hours  (max)" % FuelDepot.hours()
		_set_locked(d)
	else:
		d["value"].text = "%.0f  ->  %.0f hours   (%d barrels)" % [
			FuelDepot.hours(), FuelDepot.hours() + FuelDepot.HOURS_STEP,
			int(round(FuelDepot.rate() * (FuelDepot.hours() + FuelDepot.HOURS_STEP)))]
		_set_price(d, FuelDepot.depot_cost())


# Greyed rather than hidden, same language ShopItem and ApronSlot use: a button
# that is simply absent reads as broken, one that is grey reads as "not yet".
func _set_price(card: Dictionary, cost: int) -> void:
	var afford := Economy.money >= cost
	card["cost"].text = "$%s" % _n(float(cost))
	card["button"].disabled = not afford
	card["button"].modulate = Color.WHITE if afford else Color(0.55, 0.55, 0.55, 1.0)


func _set_locked(card: Dictionary) -> void:
	card["cost"].text = "-"
	card["button"].disabled = true
	card["button"].modulate = Color(0.55, 0.55, 0.55, 1.0)


# Thousands separators, because a 31,871,907 tanker is unreadable without them
# and the HUD already prints money this way.
func _n(v: float) -> String:
	var s := str(int(round(v)))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out
