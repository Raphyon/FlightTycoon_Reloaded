extends Node

signal xp_changed(new_xp: int)
signal level_changed(new_level: int)

var xp: int = 0
var level: int = 1


# Levelling gets harder as it goes: level N itself costs STEP*N, so the
# cumulative requirement is STEP*N*(N-1)/2 - quadratic, not the flat 100 a
# level this replaced.
#
# It has to rise, because the reward rises too. XP now scales with what an
# aircraft earns (Fleet.xp_for_claim), so a late-game A380 brings in 14x the
# starter's XP per leg; against a flat curve the last hundred levels would
# fall over in a handful of trips. The two curves are set against each other
# so the pace stays roughly even - see the pacing table in the notes.
const STEP := 8


func xp_for_level(n: int) -> int:
	return STEP * n * (n - 1) / 2


func add_xp(amount: int) -> void:
	xp += amount
	xp_changed.emit(xp)
	while xp >= xp_for_level(level + 1):
		level += 1
		level_changed.emit(level)
