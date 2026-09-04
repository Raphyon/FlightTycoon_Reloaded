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


# THE CURVE IS DEGENERATE AT THE BOTTOM AND THE FIRST TRIP EATS IT. Level 2
# costs 1 XP on the formula, level 3 costs 10, level 4 costs 33 - and the
# granted DC-3 pays 30 XP a claim, two claims to a round trip. So ONE FULL TRIP
# WITH A SINGLE PLANE LANDED THE PLAYER AT LEVEL 4, and the third claim at level
# 5, with the bar never visibly moving.
#
# That is faithful to the original, whose own saves put a character at level 4
# on 58 XP. The divergence is deliberate: three levels for one flight is not a
# fast opening, it is no opening, because nothing was earned.
#
# THE FLOOR BELOW IS SIZED IN ROUND TRIPS of that starter aircraft, which is the
# only thing a new player owns, and solved from two anchors rather than picked:
#
#     level 2 at TWO trips        -> 120 XP, the coefficient
#     level 3 at FOUR AND A HALF  -> 270 XP, which fixes the exponent at 1.17
#
# Every early level then costs between two and three and a bit trips, rising
# gently, instead of the formula's 0.0 / 0.2 / 0.6.
#
# IT HANDS OFF AT LEVEL 10 ON ITS OWN. The floor passes under the real curve
# there - 1568 against 1584 - so level 10 costs exactly what it costs today and
# the "level 10 at about fifteen minutes" pacing target is untouched. Only the
# eight levels below it are re-spaced, which is the whole intent: THE OPENING
# STAYS EASY, it just stops handing out levels three at a time.
const EARLY_XP_COEFFICIENT := 120.0
const EARLY_XP_EXPONENT := 1.17


func xp_for_level(n: int) -> int:
	if n <= 1:
		return 0
	# maxi, not a replacement: the floor stops applying the moment the real
	# curve passes it, so there is no seam to tune and no second curve to keep
	# in step with the first.
	return maxi(int(XP_COEFFICIENT * pow(float(n), XP_EXPONENT)),
		int(EARLY_XP_COEFFICIENT * pow(float(n - 1), EARLY_XP_EXPONENT)))


func add_xp(amount: int) -> void:
	xp += amount
	xp_changed.emit(xp)
	while xp >= xp_for_level(level + 1):
		level += 1
		level_changed.emit(level)
