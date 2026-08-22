extends Node

# DAILY LOGIN. A seven day cycle, one reward a day, and the streak resets if you
# miss one.
#
# It exists for the reason dailies exist - to pull a lapsed player back - and
# this is a game where the hours between sessions are already free and doing
# work, so coming back is the thing worth rewarding.
#
# THE SAME DAY AS QUESTS. Both key off floor(GameClock.now() / 86400), and they
# must: two dailies that roll at different instants is a bug the player
# experiences as the game lying about what day it is.

signal streak_changed
# What was actually handed over, so the panel can float it rather than the
# numbers appearing silently in the HUD.
signal claimed(day: int, cash: int, coins: int, fuel: int, boost: String)

const DAY_SECONDS := 86400.0
const CYCLE := 7

# Cash rides the SAME curve the quest rewards do, level^1.1, because a flat
# figure is real money at level 5 and an insult at level 50. The multipliers are
# per day of the cycle - see REWARDS.
const CASH_BASE := 4000.0
const CASH_EXPONENT := 1.1
const FUEL_BASE := 120.0
const FUEL_EXPONENT := 0.6

# Day -> what it pays. Cash and fuel are multipliers on the curves above; coins
# are literal, because a coin is a coin at every level.
#
# FOUR COINS A WEEK, measured at 52 across a 90 day run.
#
# READ THIS BEFORE CHANGING IT. That 52 does not land on an empty table - it is
# the fourth coin source added to this game, and the total is now:
#
#   quests           166
#   building drops   130
#   milestones        52
#   daily login       52
#   TOTAL            400   against a catalogue costing 293
#
# Which is past where the coin economy was deliberately set earlier: 323 was
# chosen as right, and 411 was rejected as "coins stop being scarce". A run now
# ends 107 coins clear of owning every coin aircraft in the game.
#
# DECIDED: keep it. Coins are less scarce than they were, on purpose. A run
# ending able to own the whole coin catalogue with something left over is the
# shape now, and the three sources added today - drop chance, milestones, this -
# are all staying at the values they were measured at.
#
# What that costs is the thing the coin gate used to buy: coin aircraft were
# "aircraft you did not pay cash for", and pacing was measured on the assumption
# that they were rationed. If a future run comes back faster than 32.7 h for the
# home zones, this is the first place to look.
#
# The SHAPE is separate and worth keeping either way: days 1-6 are small and day
# 7 is the one you came back for. A cycle that pays evenly gives nobody a reason
# to finish it.
# DAYS 2 AND 6 HAND OVER A BOOST, and used to hand over fuel. Fuel is 1.3% of
# income across a whole playthrough, so those were the two days in the cycle
# that gave you nothing you would notice - the weakest thing in the feature.
#
# Two 30 minute auto-turnaround cards a week is about 26 a run and 13 h of
# coverage, 14% of the dose measured as nearly halving the time to DarkZone.
# Never the 12 hour card: that one is worth twenty-four of these and belongs to
# events. See ROADMAP item 4.
const REWARDS := [
	{"cash": 0.5, "coins": 0, "fuel": 0.0, "boost": ""},
	{"cash": 0.0, "coins": 0, "fuel": 0.0, "boost": "autoturn_30"},
	{"cash": 0.8, "coins": 0, "fuel": 0.0, "boost": ""},
	{"cash": 0.0, "coins": 1, "fuel": 0.0, "boost": ""},
	{"cash": 1.0, "coins": 0, "fuel": 0.0, "boost": ""},
	{"cash": 0.0, "coins": 0, "fuel": 0.0, "boost": "autoturn_30"},
	{"cash": 1.2, "coins": 3, "fuel": 0.0, "boost": ""},
]

# The day index the streak last collected on, in GameClock days. -1 is "never".
var last_day := -1
# How many days running, 1-based. The cycle position is (streak - 1) % CYCLE.
var streak := 0


func today() -> int:
	return int(floor(GameClock.now() / DAY_SECONDS))


func seconds_until_reset() -> float:
	return maxf(0.0, float(today() + 1) * DAY_SECONDS - GameClock.now())


# STRICTLY LATER, not merely different. This was `today() != last_day`, which is
# also true when the clock has gone BACKWARDS - and GameClock's fast-forward
# offset is not persisted, so restarting after a fast-forwarded session does
# exactly that. A player could bank a day, fast-forward, restart, and claim the
# same day again. See _streak_broken for the other half of that problem.
func can_claim() -> bool:
	return today() > last_day


# Where in the seven the NEXT claim lands, 0-based. A missed day starts over.
func next_index() -> int:
	if _streak_broken():
		return 0
	return streak % CYCLE


# A day was missed if the last claim was not today and not yesterday.
#
# CLOCKS THAT GO BACKWARDS DO NOT BREAK A STREAK. GameClock's fast-forward
# offset is not persisted, so restarting after a fast-forwarded session moves
# now() backwards and today() with it. Losing a streak to that would be the game
# taking something away for a debug session, so an earlier day is treated as the
# same day: no break, and no second claim either.
func _streak_broken() -> bool:
	if last_day < 0:
		return true
	return today() > last_day + 1


func claim() -> bool:
	if not can_claim():
		return false
	var index := next_index()
	streak = 1 if index == 0 else streak + 1
	last_day = today()

	var reward: Dictionary = REWARDS[index]
	var cash := cash_for(index)
	var coins := int(reward.get("coins", 0))
	var fuel := fuel_for(index)
	if cash > 0:
		Economy.add_money(cash)
	if coins > 0:
		Coins.add(coins)
	if fuel > 0:
		# FuelStore has no add() - amount is a setter-backed property and the
		# signal fires off the assignment.
		FuelStore.amount += fuel

	var boost := boost_for(index)
	if boost != "":
		Boosts.grant(boost)

	claimed.emit(index, cash, coins, fuel, boost)
	streak_changed.emit()
	return true


func cash_for(index: int) -> int:
	var mult := float(REWARDS[index].get("cash", 0.0))
	if mult <= 0.0:
		return 0
	return NiceNumber.cash(int(CASH_BASE
		* pow(float(Progression.level), CASH_EXPONENT) * mult))


func fuel_for(index: int) -> int:
	var mult := float(REWARDS[index].get("fuel", 0.0))
	if mult <= 0.0:
		return 0
	return NiceNumber.cash(int(FUEL_BASE
		* pow(float(Progression.level), FUEL_EXPONENT) * mult))


func boost_for(index: int) -> String:
	return str(REWARDS[index].get("boost", ""))


func coins_for(index: int) -> int:
	return int(REWARDS[index].get("coins", 0))


func to_save() -> Dictionary:
	return {"last_day": last_day, "streak": streak}


func load_save(data: Dictionary) -> void:
	last_day = int(data.get("last_day", -1))
	streak = int(data.get("streak", 0))


func reset() -> void:
	last_day = -1
	streak = 0
	streak_changed.emit()
