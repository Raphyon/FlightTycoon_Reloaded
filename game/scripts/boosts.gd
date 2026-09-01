extends Node

# BOOST CARDS. Held in an inventory, used one at a time, expire on the clock.
#
# You are GIVEN these - the daily login, aircraft affinity levels, and events
# once those exist. There is no shop, which is the point: a boost is a windfall
# for turning up or for flying one model a lot, not another thing to buy. See
# ROADMAP item 4.
#
# WHAT EACH IS WORTH is measured, not guessed, and they are not close to each
# other:
#
#   autoturn  aircraft turn themselves round while nobody is watching. ONE HOUR
#             A DAY nearly halves the time to DarkZone (2.2 h -> 1.2 h), because
#             taps are the binding constraint in this game and this removes them
#             for as long as it runs. The 12 hour card is worth twenty-four of
#             the 30 minute ones and belongs to events alone.
#   speed     everything below A flies as an A. 71% of the fleet qualifies and
#             the fleet gets 26% faster - and it helps the WORST aircraft most
#             (E->A is -33% on a five cloud leg, B->A only -11%), so it is
#             self-limiting by shape.
#   cash      double flight cash. Fine early; quietly weak late, where cash
#             stopped being the constraint.
#   fuel      free refuelling. Worth about 1.3% of income, which is what fuel
#             is worth in total. Honest as the commonest drop, a trap as
#             anything you would spend a coin on.

signal inventory_changed
signal boost_started(key: String, seconds: float)
signal boost_ended(key: String)

# key -> how long one card runs, in seconds.
const DURATIONS := {
	"autoturn_30": 1800.0,
	"autoturn_60": 3600.0,
	"autoturn_720": 43200.0,
	"speed": 3600.0,
	"cash": 3600.0,
	"fuel": 3600.0,
}

# key -> the icon in game/assets/boosts, and what to call it on a card.
const CARDS := {
	"autoturn_30": {"icon": "collect", "name": "Auto Turnaround", "detail": "30 minutes"},
	"autoturn_60": {"icon": "collect", "name": "Auto Turnaround", "detail": "1 hour"},
	"autoturn_720": {"icon": "collect", "name": "Auto Turnaround", "detail": "12 hours"},
	"speed": {"icon": "speed", "name": "Speed Boost", "detail": "1 hour"},
	"cash": {"icon": "cash", "name": "Double Cash", "detail": "1 hour"},
	"fuel": {"icon": "fuel", "name": "Free Fuel", "detail": "1 hour"},
}

# Every autoturn card is the same effect at a different length, so the things
# that ask "is it on" ask about the FAMILY rather than listing three keys.
const AUTOTURN := ["autoturn_30", "autoturn_60", "autoturn_720"]

# How often an auto-turnaround pass runs while it is active.
#
# THIS WAS 20 SECONDS AND THAT IS WHAT CLOGGED IT. A sweep on a long timer does
# not service a landing when it lands - it collects every landing in the window
# and turns them all round together, which is precisely the pile-up Depart All
# had before BULK_LAUNCH_STAGGER, arriving by a different route. Twenty seconds
# of a large fleet is a lot of aircraft on one frame.
#
# A second instead, so one landing is one turnaround and the natural spacing of
# arrivals is the stagger. When several DO land together - coming back to a full
# board after an absence - advance_all spreads their departures exactly the way
# Depart All does, which is the behaviour that was wanted in both places.
const AUTOTURN_INTERVAL := 1.0

# Backing off when a pass finds nothing to do, or something merely BLOCKED -
# an aircraft parked with no fuel stays serviceable forever, and retrying it
# every second buys a full-fleet walk to be told so again.
const AUTOTURN_IDLE_INTERVAL := 10.0

var owned: Dictionary = {}      # key -> count
var active: Dictionary = {}     # key -> GameClock time it ends at

var _autoturn_due := 0.0


func _process(_delta: float) -> void:
	_expire()
	if not autoturn_active():
		return
	# Driven off GameClock rather than real seconds, so a boost bought at x1 and
	# run at x300 covers the game time it promised rather than the wall time.
	if GameClock.now() < _autoturn_due:
		return
	if not Fleet.has_serviceable():
		_autoturn_due = GameClock.now() + AUTOTURN_IDLE_INTERVAL
		return
	var result := Fleet.advance_all()
	var moved := int(result.get("moved", 0))
	_autoturn_due = GameClock.now() + (AUTOTURN_INTERVAL if moved > 0
		else AUTOTURN_IDLE_INTERVAL)


# --- inventory ---------------------------------------------------------------

func grant(key: String, count := 1) -> void:
	if not DURATIONS.has(key) or count <= 0:
		return
	owned[key] = int(owned.get(key, 0)) + count
	inventory_changed.emit()


func count(key: String) -> int:
	return int(owned.get(key, 0))


func total_held() -> int:
	var n := 0
	for k in owned:
		n += int(owned[k])
	return n


# ONE BOOST AT A TIME, AND IT CANNOT BE EXTENDED.
#
# This used to let a card that was already running EXTEND itself, on the
# reasoning that replacing it would throw away whatever was left. That is true,
# and it is still the wrong trade: it made duration a thing you pile up, so the
# strongest play was to hold cards until you had several of a kind and burn
# them together, and a 12-hour autoturn on top of a running one was worth more
# than the same two cards spent apart. Nothing else in the game rewards
# hoarding like that.
#
# So: refused while ANYTHING is running, of any family. A card is a decision
# about the next half hour, not a resource to stack.
func any_active() -> bool:
	for family in active:
		if float(active[family]) > GameClock.now():
			return true
	return false


func use(key: String) -> bool:
	if count(key) <= 0:
		return false
	if any_active():
		return false
	owned[key] = count(key) - 1
	if owned[key] <= 0:
		owned.erase(key)

	var family := _family(key)
	active[family] = GameClock.now() + float(DURATIONS[key])
	if family == "autoturn":
		_autoturn_due = GameClock.now()

	inventory_changed.emit()
	boost_started.emit(family, seconds_left(family))
	return true


# --- what is running ---------------------------------------------------------

# Every autoturn length shares one timer, or holding a 30 and a 12 hour card
# would let both run at once and the shorter one would end the longer one.
func _family(key: String) -> String:
	return "autoturn" if key in AUTOTURN else key


func is_active(family: String) -> bool:
	return seconds_left(family) > 0.0


func seconds_left(family: String) -> float:
	return maxf(0.0, float(active.get(family, 0.0)) - GameClock.now())


func autoturn_active() -> bool:
	return is_active("autoturn")


func _expire() -> void:
	for family in active.keys():
		if float(active[family]) <= GameClock.now():
			active.erase(family)
			boost_ended.emit(family)


# --- what the game asks ------------------------------------------------------

# Flight cash multiplier. Read by Fleet.reward_cash_for.
func cash_multiplier() -> float:
	return 2.0 if is_active("cash") else 1.0


# Whether a leg costs fuel at all. Read by Fleet.fuel_cost.
func fuel_is_free() -> bool:
	return is_active("fuel")


# The grade an aircraft flies at. Read by Fleet.grade_for, and it can only ever
# RAISE one: an S-class aircraft is not dragged down to A by this.
func lift_grade(grade: String) -> String:
	if not is_active("speed"):
		return grade
	var here := Fleet.GRADE_LADDER.find(grade)
	var floor_at := Fleet.GRADE_LADDER.find("A")
	if here == -1 or here >= floor_at:
		return grade
	return "A"


# --- saving ------------------------------------------------------------------

func to_save() -> Dictionary:
	return {"owned": owned.duplicate(), "active": active.duplicate()}


func load_save(data: Dictionary) -> void:
	owned = (data.get("owned", {}) as Dictionary).duplicate()
	active = (data.get("active", {}) as Dictionary).duplicate()
	# A timer written against a clock that has since moved BACKWARDS - which is
	# what GameClock does on restart, since its fast-forward offset is not
	# persisted - would otherwise read as running for hours. Anything that ends
	# more than its own longest card away is stale.
	var ceiling: float = GameClock.now() + float(DURATIONS["autoturn_720"])
	for family in active.keys():
		if float(active[family]) > ceiling:
			active.erase(family)
	inventory_changed.emit()


func reset() -> void:
	owned.clear()
	active.clear()
	inventory_changed.emit()
