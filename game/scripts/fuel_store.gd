extends Node

signal fuel_changed(new_amount: int)
signal price_changed(new_price: int)

# Placeholder economy - not real game data. Price re-rolls periodically to
# simulate a fluctuating fuel market, swinging up to 50% above or below the
# base price each time.
const BASE_PRICE := 10
const PRICE_SWING := 0.5
const PRICE_UPDATE_INTERVAL := 10.0  # seconds
const PRICE_HISTORY_LENGTH := 20

# Arbitrary placeholder starting stockpile, same caveat as Economy.money.
var amount: int = 20:
	set(value):
		amount = value
		fuel_changed.emit(amount)

var current_price: int = BASE_PRICE:
	set(value):
		current_price = value
		price_history.append(value)
		if price_history.size() > PRICE_HISTORY_LENGTH:
			price_history.pop_front()
		price_changed.emit(current_price)

var price_history: Array[int] = []

var _price_timer := 0.0


func _ready() -> void:
	_reroll_price()


func _process(delta: float) -> void:
	_price_timer += delta
	if _price_timer >= PRICE_UPDATE_INTERVAL:
		_price_timer = 0.0
		_reroll_price()


func _reroll_price() -> void:
	var low := BASE_PRICE * (1.0 - PRICE_SWING)
	var high := BASE_PRICE * (1.0 + PRICE_SWING)
	current_price = roundi(randf_range(low, high))


func consume(units: int) -> bool:
	if units > amount:
		return false
	amount -= units
	return true


func buy(units: int) -> bool:
	if not Economy.spend_money(units * current_price):
		return false
	amount += units
	return true


func buy_with_coins(units: int, coin_cost: int) -> bool:
	if not Coins.spend(coin_cost):
		return false
	amount += units
	return true
