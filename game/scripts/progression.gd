extends Node

signal xp_changed(new_xp: int)
signal level_changed(new_level: int)

var xp: int = 0
var level: int = 1


# Placeholder XP curve - not real game data. Level N needs (N-1)*100
# cumulative XP, i.e. flat 100 XP per level.
func xp_for_level(n: int) -> int:
	return (n - 1) * 100


func add_xp(amount: int) -> void:
	xp += amount
	xp_changed.emit(xp)
	while xp >= xp_for_level(level + 1):
		level += 1
		level_changed.emit(level)
