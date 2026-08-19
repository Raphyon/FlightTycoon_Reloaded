extends Node

signal affinity_changed

# The model, its new level and what it paid - so a panel can say so rather than
# leaving the money to appear silently in the counter.
signal model_levelled(model_key: String, level: int, reward: int)

# Placeholder affinity mechanic - no source data exists for this (only
# extracted images, no game logic), so this is invented: affinity is
# per-model (shared across every instance of that model), goes up by a
# fixed amount every time an aircraft of that model claims a reward
# (destination or home leg), leveling up every XP_PER_LEVEL points.
const XP_PER_LEVEL := 50
const XP_PER_USE := 10

# WHAT AFFINITY DOES: every level shaves 1% off this model's flight time, to a
# maximum of 10% at level 10.
#
# Until now it did nothing at all - it counted legs and drew a bar, and no
# system read it. A number that goes up and changes nothing is worse than no
# number, because the player reasonably assumes it means something.
#
# Speed rather than money deliberately. Cash bonuses already come from three
# directions (apron skins, the city's popularity, the route's own distance) and
# a fourth would be invisible inside them. Time is the resource the player
# actually feels: 10% off a leg is 10% more legs in a session, which compounds
# into money on its own without being another multiplier on the same number.
#
# The bonus counts from level 1 rather than from 0, so the card's "Lv.5" reads
# as 5% and the player never has to know the ladder is 1-indexed.
#
# Model-scoped, not per-aircraft - flying any CRJ-700 levels every CRJ-700. That
# is what makes it a reason to commit to a type instead of a reason to hoard one
# lucky airframe.
const MAX_LEVEL := 10
const SPEED_BONUS_PER_LEVEL := 0.01
# CASH ON EVERY LEVEL, and FLAT on purpose. This is aimed at the early game, so
# it wants a number that is real money against a 3,000 DC-3 and quietly becomes
# nothing against a 7,000,000 Ark - which is what a flat figure does on its own,
# with no taper to tune.
#
# Scaling it by the model's price would do the opposite: the early models are
# the cheap ones, so a share of the price would pay 5 on a Paper Plane exactly
# where the reward is supposed to land hardest.
#
# A level is 5 flights (XP_PER_LEVEL / XP_PER_USE), and an early leg pays about
# 750, so 1,000 a level is roughly a quarter on top of what those flights earn.
const LEVEL_REWARD_CASH := 1000

const SAVE_PATH := "res://data/aircraft_affinity.json"

var _xp: Dictionary = {}  # model_key -> xp, persisted


func _ready() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_xp = parsed


func reset() -> void:
	_xp.clear()
	_save()


func xp_for(model_key: String) -> int:
	return _xp.get(model_key, 0)


func level_for(model_key: String) -> int:
	return mini(xp_for(model_key) / XP_PER_LEVEL + 1, MAX_LEVEL)


func is_maxed(model_key: String) -> bool:
	return level_for(model_key) >= MAX_LEVEL


# Full at the cap rather than sawtoothing back to empty on XP that no longer
# counts for anything.
func progress_for(model_key: String) -> float:
	if is_maxed(model_key):
		return 1.0
	return float(xp_for(model_key) % XP_PER_LEVEL) / float(XP_PER_LEVEL)


# What a leg's duration gets MULTIPLIED by - 0.90 at the cap. See Fleet's
# flight_seconds_for / flight_seconds_to, which are the only callers.
func speed_multiplier(model_key: String) -> float:
	return 1.0 - SPEED_BONUS_PER_LEVEL * float(level_for(model_key))


func speed_bonus_percent(model_key: String) -> int:
	return roundi(SPEED_BONUS_PER_LEVEL * float(level_for(model_key)) * 100.0)


func grant_use(model_key: String) -> void:
	# NOT reloaded from disk here. _xp is the live state; _load belongs to
	# _ready. Re-reading the file on every use meant the increment below was
	# discarded whenever the write did not land - which is exactly what the
	# --bot guard does, so a bot run has never levelled an aircraft in its life
	# and every pacing figure measured so far ran with no affinity speed bonus.
	# Stop accruing at the cap. Left running, the saved number would climb
	# forever behind a bar that cannot move and a bonus that cannot grow.
	if is_maxed(model_key):
		return
	var before := level_for(model_key)
	_xp[model_key] = xp_for(model_key) + XP_PER_USE
	_save()
	# Levels are worth cash. Paid per level crossed rather than once, because a
	# single use cannot cross two today but XP_PER_USE is a constant somebody
	# will raise one day and a skipped level would be a silent loss.
	var after := level_for(model_key)
	if after > before:
		var reward := LEVEL_REWARD_CASH * (after - before)
		Economy.add_money(reward)
		model_levelled.emit(model_key, after, reward)
	affinity_changed.emit()


func _load() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


func _save() -> void:
	# Never over a real playthrough - see SaveGame.save().
	if OS.get_cmdline_user_args().has("--bot"):
		return
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_xp, "\t"))
	f.close()
