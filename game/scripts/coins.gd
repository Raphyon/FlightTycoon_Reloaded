extends Node

signal coins_changed(new_amount: int)

# Coins are meant to be hard to earn (IAP / watching ads, per the real
# game) - we haven't built any earn path yet, that's a separate task. Same
# "arbitrary placeholder starting balance" caveat as Economy.money and
# FuelStore.amount, just enough to make apron skins testable.
var amount: int = 20:
	set(value):
		amount = value
		coins_changed.emit(amount)


func spend(cost: int) -> bool:
	if cost > amount:
		return false
	amount -= cost
	return true


func add(n: int) -> void:
	amount += n
