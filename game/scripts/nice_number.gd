class_name NiceNumber
extends RefCounted

# ROUND NUMBERS, everywhere a price or a duration is computed from a curve.
#
# Every cost in this game comes out of a formula - pads are base * 1.35^built,
# upgrades are price * 0.6 * level^2.2 - and a formula does not produce numbers
# anybody would choose. The pad ladder read $500, $675, $911, $1,230, $1,661,
# and a building level cost $8,271. They are correct and they look like noise.
#
# One rounder, so a price rounded in the shop is the price charged at the till.
# Two figures that agree today and drift tomorrow is the failure this project
# keeps hitting; a shared static cannot drift from itself.

# The step grows with the figure, so it reads clean at every scale rather than
# carrying five significant digits into the millions.
# "250k", "1.2M" - for somewhere too narrow for the full figure, like a shop
# card or a daily tile. BuildingItem grew its own copy of this before there was
# anywhere shared to put it; that one can move here whenever it is next touched.
static func short(n: int) -> String:
	if n >= 1000000:
		var m := float(n) / 1000000.0
		return ("%.0fM" % m) if m >= 10.0 else ("%.1fM" % m)
	if n >= 1000:
		return "%dk" % (n / 1000)
	return str(n)


static func cash(n: int) -> int:
	var v := absi(n)
	var step := 50
	if v >= 1000000: step = 100000
	elif v >= 100000: step = 10000
	elif v >= 10000: step = 1000
	elif v >= 1000: step = 100
	var out := int(round(float(v) / step)) * step
	return -out if n < 0 else out


# Coins are small integers, so the cash steps would flatten them to nothing.
# Multiples of five, never less than five - a price of "17 coins" is a formula
# talking where "15" is a number somebody chose.
static func coins(n: int) -> int:
	return maxi(5, int(round(float(maxi(0, n)) / 5.0)) * 5)


# Durations the same way. A build time of 6m58s is a formula talking; 7m is a
# number. Steps chosen so the result is always something a clock face would
# show: whole minutes under ten, five-minute marks under an hour, quarter hours
# above it.
static func seconds(s: float) -> float:
	var v := maxf(0.0, s)
	var step := 60.0
	if v >= 3600.0: step = 900.0
	elif v >= 600.0: step = 300.0
	return maxf(step, round(v / step) * step)
