extends Node

# THE GAME'S IDEA OF "NOW". Everything that measures elapsed wall-clock time -
# rent cycles, the fuel market, how long the game was closed - reads it from
# here rather than from Time directly.
#
# WHY. Two systems in this project run on two different clocks. Flights tick off
# _process(delta); rent and the fuel market read the system clock. Routing the
# wall-clock readers through here is what lets both halves be accelerated
# together.
#
# IT DOES NOT USE Engine.time_scale, and that is the whole design. Scaling the
# engine seemed obvious and broke the game: at x300 every frame carries a FIVE
# SECOND delta, so tweens finish instantly, timers fire in droves, cars travel
# the map in a frame, and the fleet lands dozens of aircraft at once - each
# rebuilding every apron slot and world sprite until the deferred-call queue
# runs out of memory and the screen goes grey. Exactly the overflow the headless
# bot hit, which is why the bot drops the scene entirely.
#
# So the SIMULATION is advanced by hand and the engine keeps running at 1x.
# Animations, input and the UI stay normal speed; only game time moves faster.
# That is what you want anyway - a takeoff roll at 300x tells you nothing.
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
# A HEADLESS BOT RUN IS THE ONE EXCEPTION: it counts from a fixed instant
# instead, which is what makes it reproducible. See BOT_EPOCH.
#
# When it is NOT 1.0 the badge below says so, on top of everything, always. A
# fast-forward you forgot to turn off does not look like a fast-forward - it
# looks like the economy is broken - and this project has already spent a whole
# session chasing pacing numbers that turned out to be measurement artifacts.

# Seconds added to the clock's origin. Grows while the game runs fast; never
# shrinks, because time going backwards would make a rent cycle that had already
# completed un-complete itself.
var offset := 0.0

# WHERE A BOT RUN COUNTS FROM, so that two runs of the same build agree.
#
# now() used to be the system clock outright, and two things seed themselves off
# it: the fuel market's hourly slot (FuelStore.price_for_slot) and the daily
# quest draw (Quests._roll_if_new_day) both hash a number derived from now(). So
# a run launched at 09:40 on a Tuesday met a different market and a different
# three tasks from the same build launched at 14:10 on a Wednesday. Two runs an
# hour apart came out ~20% apart on day-40 cash, a quest set apart, and tens of
# legs apart per model - while the structural columns (level, fleet, pads,
# zones, buildings) matched to the digit, which is exactly why it read as noise
# in the money rather than as a broken instrument. README calls the bot the
# arbiter where it disagrees with the Python sweeps; it could not be.
#
# FIXED HERE RATHER THAN WITH MORE SEEDS DOWNSTREAM. Every wall-clock reader in
# the project already asks this file, so pinning the origin makes all of them
# reproducible at once - rent cycles, upgrade timers and boost expiries
# included - and a reader added tomorrow is deterministic without anyone having
# to remember to seed it.
#
# The value is arbitrary but must be DAY- AND HOUR-ALIGNED, so a run starts at
# the top of a quest day and the top of a fuel slot rather than partway through
# either. 0 satisfies that and was the obvious pick; a plausible modern
# timestamp is used instead so nothing that stores a time and reads 0 as "unset"
# can collide with the first instant of a run. 2023-11-15 00:00:00 UTC.
const BOT_EPOCH := 1700006400.0

# The origin in force, or -1 for "ask the system clock" - which is normal play.
# Resolved on FIRST READ rather than in _ready(): FuelStore prices a slot inside
# its own _ready, and this being autoload number one is not a thing to make the
# fuel market depend on.
var _epoch := -1.0
var _epoch_resolved := false

# Kept only so a caller can ask how long the process has been up; the offset is
# derived from _process's own delta now, not from wall time.
var _last_real := 0.0
var _badge: Label

# What the F1 menu offers. 1 is normal; 60 turns an hour of the loop into a
# minute, which is the point of the thing.
const SPEEDS := [1.0, 5.0, 20.0, 60.0, 300.0]

# The most game time one frame may carry, however high the speed. A frame hitch
# at x300 would otherwise hand the fleet a minute at once and land everything
# simultaneously; this bounds the churn instead. It only binds during a stall -
# x300 at 60fps is 5s a frame, well under.
const MAX_STEP := 30.0

# Our own multiplier. NOT Engine.time_scale - see the note at the top.
var speed := 1.0

# THE PLAYER DOES NOT SPEED UP. Fast-forward multiplies the world, not the hand
# holding the phone, so at x300 one second spent reading a route panel is five
# game minutes gone - fuel burned, rent cycles missed, a market slot passed. The
# faster you run it the more every moment of hesitation costs, which makes the
# feature actively hostile to doing anything while it is on.
#
# So it HOLDS while a panel is open. Menus are where the DECIDING happens - what
# to buy, where to send it, which livery - and deciding is the part that should
# not cost five game minutes a second.
#
# EXCEPT THE ONES YOU WORK IN. Routes is not a menu you read, it is the menu you
# turn the fleet around in: claim, refuel, dispatch, Run all, repeat. Holding
# there would break the exact loop fast-forward exists to speed up - you would
# open it, nothing would land, and you would have to close it again to let the
# aircraft come home. So time keeps running while it is open.
#
# The distinction is browsing versus working, not panel versus world.
#
# Detected by name rather than by a registry: every panel in Main.tscn is a
# direct child of UI called something-Panel, and asking the tree costs nothing
# next to keeping a list in step with it.
const HOLD_WHILE_PANEL_OPEN := true
const RUN_WHILE_OPEN: Array[String] = ["RoutesPanel"]

var _held := false


func _ready() -> void:
	_last_real = Time.get_ticks_msec() / 1000.0
	_build_badge()


# Its own CanvasLayer at a very high layer, so it survives whatever scene is
# loaded and cannot be covered by a panel.
func _build_badge() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_badge = Label.new()
	_badge.add_theme_font_size_override("font_size", 18)
	_badge.add_theme_color_override("font_color", Color(1, 0.86, 0.35))
	_badge.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02))
	_badge.add_theme_constant_override("outline_size", 5)
	_badge.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_badge.offset_top = 8
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.visible = false
	layer.add_child(_badge)


# Is the player mid-decision? Any visible UI/*Panel counts.
func _player_busy() -> bool:
	if not HOLD_WHILE_PANEL_OPEN:
		return false
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var ui := scene.get_node_or_null("UI")
	if ui == null:
		return false
	for child in ui.get_children():
		if child is Control and child.visible and str(child.name).ends_with("Panel") \
				and not RUN_WHILE_OPEN.has(str(child.name)):
			return true
	return false


func _process(delta: float) -> void:
	_last_real = Time.get_ticks_msec() / 1000.0
	_held = speed > 1.0 and _player_busy()
	if speed > 1.0 and not _held:
		# The EXTRA time this frame is worth. Fleet already advances by delta in
		# its own _process, so only the surplus is added here.
		var extra: float = minf(delta * (speed - 1.0), MAX_STEP)
		offset += extra
		Fleet.advance_by(extra)
	if is_instance_valid(_badge):
		_badge.visible = speed > 1.0
		if _badge.visible:
			_badge.text = ("FAST FORWARD  x%d  HELD - menu open   (+%s)" if _held
				else "FAST FORWARD  x%d   (+%s)") % [roundi(speed), _elapsed_text()]


# What every wall-clock reader should ask instead of Time.
func now() -> float:
	return epoch() + offset


# What now() counts from: live wall time in normal play, a fixed instant under
# --bot. Public so a report can state which, since a pinned clock is a fact
# about the numbers underneath it.
func epoch() -> float:
	if not _epoch_resolved:
		_epoch_resolved = true
		_epoch = _resolve_epoch()
	return Time.get_unix_time_from_system() if _epoch < 0.0 else _epoch


# --epoch <unix seconds> overrides the constant, which is how you ask what the
# SAME build does starting at a different hour of a different day - the one
# question pinning the clock would otherwise make unanswerable.
#
# BOT RUNS ONLY. A real playthrough has to keep tracking real time or its rent
# cycles stop, and reading the flag straight off the command line rather than
# through SaveGame.is_bot_run() is deliberate: this is the first autoload in the
# list and SaveGame is the second to last, so the singleton does not exist yet.
func _resolve_epoch() -> float:
	var args := OS.get_cmdline_user_args()
	if not args.has("--bot"):
		return -1.0
	for i in range(args.size() - 1):
		if args[i] == "--epoch":
			return maxf(0.0, float(args[i + 1]))
	return BOT_EPOCH


# Jump forward without waiting - what the bot uses, and what makes a 44-hour
# playthrough finish in seconds. Flights do not tick off this clock, so the
# caller advances them too (Fleet.advance_by).
func skip(seconds: float) -> void:
	offset += maxf(0.0, seconds)


# How much game time the fast-forward has added, in words - "+3h 20m". The
# number that matters is not the multiplier, it is how far ahead of real life
# the save has been pushed.
func _elapsed_text() -> String:
	var t := int(offset)
	if t >= 86400:
		return "%dd %dh" % [t / 86400, (t % 86400) / 3600]
	if t >= 3600:
		return "%dh %02dm" % [t / 3600, (t % 3600) / 60]
	if t >= 60:
		return "%dm" % (t / 60)
	return "%ds" % t


func set_scale(n: float) -> void:
	speed = clampf(n, 1.0, 3600.0)


func scale() -> float:
	return speed


func reset() -> void:
	offset = 0.0
	speed = 1.0
