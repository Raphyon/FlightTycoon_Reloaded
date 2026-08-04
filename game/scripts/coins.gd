extends Node

signal coins_changed(new_amount: int)

# Coins are meant to be hard to earn (IAP / watching ads, per the real
# game) - we haven't built any earn path yet, that's a separate task. Same
# "arbitrary placeholder starting balance" caveat as Economy.money and
# FuelStore.amount.
#
# 100 is a testing float, not a designed grant: enough to buy a Paper Plane at
# 5 and still have room for aprons, liveries and a coin aircraft or two without
# an earn path existing. Drop it to something small once coins can be earned.
var amount: int = 100:
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
