extends Node

# THE GAME'S IDEA OF "NOW". Everything that measures elapsed wall-clock time -
# rent cycles, the fuel market, how long the game was closed - reads it from
# here rather than from Time directly.
#
# WHY. Two systems in this project run on two different clocks. Flights tick off
# _process(delta), so Engine.time_scale speeds them up for free. Rent and the
# fuel market read the system clock, which no time scale can touch - so setting
# time_scale alone produced a world where aircraft flew at 60x and buildings
# still paid once every fifteen real minutes. Routing the wall-clock readers
# through here is what lets both halves be accelerated together.
#
# That buys two things the project could not do before:
#
#   * A HEADLESS BOT can play the real game - these autoloads, not a Python
#     reimplementation of them - by advancing this clock in steps. See
#     scripts/bot.gd. The simulator in tools/econ_sim.py has been wrong three
#     separate times by drifting from the rules it was copying; a bot driving
#     the actual code cannot drift.
#   * FAST-FORWARD while playing, so an hour of the loop can be watched in a
#     minute. No simulation can tell you whether forty aircraft on one screen is
#     legible.
#
# DEBUG ONLY in the sense that nothing in normal play changes it - at scale 1.0
# now() is exactly Time.get_unix_time_from_system() and the offset stays zero.

# Seconds added to the system clock. Grows while the game runs fast; never
# shrinks, because time going backwards would make a rent cycle that had already
# completed un-complete itself.
var offset := 0.0

# Real seconds since boot, unaffected by Engine.time_scale - which is the whole
# point. _process's delta is ALREADY scaled, so deriving the offset from it
# would count the acceleration twice.
var _last_real := 0.0


func _ready() -> void:
	_last_real = Time.get_ticks_msec() / 1000.0


func _process(_delta: float) -> void:
	var real := Time.get_ticks_msec() / 1000.0
	var elapsed := real - _last_real
	_last_real = real
	if not is_equal_approx(Engine.time_scale, 1.0):
		offset += elapsed * (Engine.time_scale - 1.0)


# What every wall-clock reader should ask instead of Time.
func now() -> float:
	return Time.get_unix_time_from_system() + offset


# Jump forward without waiting - what the bot uses, and what makes a 44-hour
# playthrough finish in seconds. Flights do not tick off this clock, so the
# caller advances them too (Fleet.advance_by).
func skip(seconds: float) -> void:
	offset += maxf(0.0, seconds)


func set_scale(n: float) -> void:
	Engine.time_scale = clampf(n, 1.0, 3600.0)


func scale() -> float:
	return Engine.time_scale


func reset() -> void:
	offset = 0.0
	Engine.time_scale = 1.0
