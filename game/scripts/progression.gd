extends Node

signal xp_changed(new_xp: int)
signal level_changed(new_level: int)

var xp: int = 0
var level: int = 1


# The real game's own curve, solved from two live saves rather than invented:
# a level-4 character on 58 XP (46.15% toward 5) and a level-12 one on 3845
# (31.99% toward 13). Both fit
#
#     cumulative XP to reach level n  =  0.1 * n ^ 4.2
#
# to within 0.00%. This replaced a flat 8 XP per level, whose cumulative was
# quadratic (4n^2). The two agree around level 4 and then diverge hard - by
# level 40 the real curve wants 86x more, by level 150 it wants 1543x - which
# is exactly the "you level up too fast" the playtest found: our low levels
# were about right and everything above them was nearly free.
#
# Reward is calibrated to match: see the per-aircraft "xp" in ShopCatalog.
const XP_COEFFICIENT := 0.1
const XP_EXPONENT := 4.2


func xp_for_level(n: int) -> int:
	if n <= 1:
		return 0
	return int(XP_COEFFICIENT * pow(float(n), XP_EXPONENT))


func add_xp(amount: int) -> void:
	xp += amount
	xp_changed.emit(xp)
	while xp >= xp_for_level(level + 1):
		level += 1
		level_changed.emit(level)
