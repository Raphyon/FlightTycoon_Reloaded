extends HBoxContainer

@onready var _money_label: Label = $MoneyLabel
@onready var _coin_label: Label = $CoinLabel
@onready var _fuel_label: Label = $FuelLabel


func _ready() -> void:
	Economy.money_changed.connect(_on_money_changed)
	_on_money_changed(Economy.money)
	Coins.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(Coins.amount)
	FuelStore.fuel_changed.connect(_on_fuel_changed)
	_on_fuel_changed(FuelStore.amount)


func _on_money_changed(amount: int) -> void:
	_money_label.text = str(amount)


func _on_coins_changed(amount: int) -> void:
	_coin_label.text = str(amount)


func _on_fuel_changed(amount: int) -> void:
	# Just the number - the drum icon beside it carries the meaning, matching
	# how money and coins read.
	_fuel_label.text = str(amount)
