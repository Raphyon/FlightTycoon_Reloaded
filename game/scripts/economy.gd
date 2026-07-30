extends Node

signal money_changed(new_amount: int)

# ======================================================================
# DEBUG: set to 0 to turn off. Any value above 0 replaces the starting
# balance below. Deliberately a separate switch rather than editing
# STARTING_MONEY directly - a bumped test value hid inside that constant
# once and silently made every affordability path untestable until it was
# spotted much later.
const DEBUG_STARTING_MONEY := 40000  # reaches the V-22 (30000) on the rescaled curve
# ======================================================================

# Arbitrary placeholder starting balance - we never captured the real game's
# actual economy values (that lives behind its API, not in anything we've
# extracted), so this is just a reasonable round number to make the system
# testable, not real game data.
# One Zone1 apron (1000) plus change. Deliberately short of the cheapest
# aircraft (P-51, 3000) - you already own the 328 Jet, so the first goal is
# to fly it, not to shop.
const STARTING_MONEY := 2500

var money: int = DEBUG_STARTING_MONEY if DEBUG_STARTING_MONEY > 0 else STARTING_MONEY:
	set(value):
		money = value
		money_changed.emit(money)


func add_money(amount: int) -> void:
	money += amount


func spend_money(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	return true
