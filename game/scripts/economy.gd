extends Node

signal money_changed(new_amount: int)

# ======================================================================
# DEBUG: set to 0 to turn off. Any value above 0 replaces the starting
# balance below. Deliberately a separate switch rather than editing
# STARTING_MONEY directly - a bumped test value hid inside that constant
# once and silently made every affordability path untestable until it was
# spotted much later.
# Set to 0 for a real playthrough - any positive value overrides
# STARTING_MONEY and skips the early game entirely.
const DEBUG_STARTING_MONEY := 0
# ======================================================================

# Arbitrary placeholder starting balance - we never captured the real game's
# actual economy values (that lives behind its API, not in anything we've
# extracted), so this is just a reasonable round number to make the system
# testable, not real game data.
# You now start with NO aircraft at all, so this is what buys your first one
# rather than what tops up a fleet you were handed. 5000 is one DC-3 at 3000
# with 2000 left over - enough to fuel it and still be short of the 5000
# EMB-120, so the first thing the game asks you to do is fly the plane you just
# bought rather than shop again.
#
# This replaced "exactly three more of the starting aircraft" (9000 against a
# free DC-3). That invariant is gone with the free aircraft; the opening is now
# about earning your way to the second pad instead of filling five at once.
const STARTING_MONEY := 5000

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
