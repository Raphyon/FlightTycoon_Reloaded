extends Node

signal coins_changed(new_amount: int)

# Coins are meant to be hard to earn - IAP or ads in the real game. They now
# have an earn path here too: a lottery on rent collection, scaled so that
# coins-per-hour is flat across the building catalogue (see
# BuildingProgress.COIN_CHANCE_PER_CYCLE_MINUTE).
#
# 15 IS A DESIGNED GRANT, unlike the 100 it replaces. That was a testing float
# from before coins could be earned at all, and it did not survive the arithmetic
# once the shop was priced: coin aircraft ignore the level gate entirely
# (ShopCatalog.unlocked - "the pay-to-win lane"), so 100 coins bought a 70-coin
# Ark on the first minute of a new game. Flying the same two-minute robot hop as
# the starter DC-3, that Ark earns 150 TIMES what the DC-3 does. The opening was
# not a difficulty curve, it was a shopping trip.
#
# 15 buys a Paper Plane and an apron skin, or three Paper Planes - enough to
# feel like a gift, not enough to skip the game. It also keeps the emergency
# escape intact: the Paper Plane burns no fuel, so a player who spends
# themselves into a dead start can always buy back in (see tools/econ_sim.py's
# grounded check).
const DEFAULT_AMOUNT := 15

var amount: int = DEFAULT_AMOUNT:
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
