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
# Exactly three more of the starting aircraft at 3000 each (the DC-3 - see
# Fleet.STARTER_MODEL). You start with five free pads and one aircraft, so the
# opening is filling them - four in the air from the first minute is what makes
# the first fifteen minutes feel like running an airport rather than watching
# one aeroplane.
#
# Tied to the starter's PRICE, so it moves when that does. It was 4500 against
# a 1500 starter; the DC-3 is 3000 in the live game, and the whole ladder now
# uses live prices rather than the halved ones (see Fleet.TICKET_PRICE), so
# this doubles with it and the "three more" invariant is unchanged.
const STARTING_MONEY := 9000

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
