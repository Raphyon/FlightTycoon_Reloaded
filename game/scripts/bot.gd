extends Node

# A bot that plays THE ACTUAL GAME, headless, at whatever speed the clock allows.
#
#     godot --headless --path game -- --bot
#     godot --headless --path game -- --bot --days 60 --sessions 4 --minutes 5
#
# WHY THIS EXISTS, when tools/econ_sim.py already answers the same questions.
#
# That tool REIMPLEMENTS the rules in Python - the fare formula, the flight
# curve, the buy order, what a pad costs - and a reimplementation drifts. It has
# been wrong three separate times in ways that invalidated everything it had
# said up to that point: it flew each aircraft one round trip per DAY, it never
# bought coin aircraft at all, and it charged for Zone1's five free pads. Each
# was found by accident.
#
# This drives Fleet, Economy, Progression, ApronProgress, ZoneProgress and
# BuildingProgress directly. If a price changes, it sees the change. There is no
# second copy of the rules to keep in step, so there is nothing to drift.
#
# The Python tool stays useful for SWEEPS - it runs a hundred players across a
# dozen constants in the time this takes to do one - so the division of labour
# is: sweep there, confirm here. Where they disagree, this one is right.
#
# WHAT IT USED TO NOT MODEL: taps. It assumed every action a player COULD take
# in a session, they took, instantly and for free - which made it an upper bound
# on progress rather than a picture of one. It was doing 114 actions a MINUTE,
# roughly two a second, sustained for hours. That is not a player, and it is why
# it reported Zone2 in 0.8 h against a real playthrough that took 8-9.
#
# So a tap now costs time: LATENCY seconds each, charged against the session and
# advancing the clock, because a player who is claiming and dispatching is not
# also getting those seconds back. --latency 0 restores the old upper bound.
#
# AND IT COSTS MORE WHEN THE GAME RUNS FAST. Fast-forward does not speed the
# PLAYER up - at x300 one second of deciding where to send an aircraft is five
# game minutes gone. --speed models playing under fast-forward and charges taps
# accordingly, which is the only honest way to ask whether fast-forward actually
# buys anything.

const DEFAULT_DAYS := 30
const DEFAULT_SESSIONS := 4
const DEFAULT_MINUTES := 5.0

# Named players, so two runs are comparable and a result can be quoted without
# also quoting a pair of numbers. These are the user's own description of the
# range - "5-10, maybe even 20 minutes, at least 3-6 times a day" - with regular
# sitting at the middle of it rather than at the bottom, which is where the
# earlier archetypes in tools/econ_sim.py had put it.
#
#     godot --headless --path game -- --bot --who regular
const WHO := {
	"casual":  {"sessions": 3, "minutes": 5.0,  "days": 220},
	"regular": {"sessions": 4, "minutes": 10.0, "days": 140},
	"heavy":   {"sessions": 6, "minutes": 20.0, "days": 70},
}
# Real seconds of wall time this is allowed to run before giving up, so a
# pathological config cannot wedge a headless CI run forever.
const WALL_LIMIT := 600.0

# Seconds a single tap costs. Not reaction time - the whole action: find the
# aircraft, read what it wants, hit the button, watch the panel settle. A second
# and a bit is brisk for a real hand on a real screen.
const DEFAULT_LATENCY := 1.2

var _days := DEFAULT_DAYS
var _sessions := DEFAULT_SESSIONS
var _minutes := DEFAULT_MINUTES
var _played := 0.0          # minutes of simulated PLAY, not elapsed time
var _day := 0               # calendar days elapsed
var _who := "custom"
var _milestones := {}
var _zone_times := {}       # area -> [minutes of play, calendar day] when bought
# Every claim, refuel and dispatch it performs. THE BOT NEVER MISSES ONE, so
# this is the tap bill a real player would have to pay to match it.
var _taps := 0
var _latency := DEFAULT_LATENCY
# Whether the player uses the routes panel's DEPART ALL. Off by default, which
# is what every pacing number measured so far assumed - the bot has always
# tapped each aircraft twice, claim then depart, and never touched advance_all.
# That makes depart-all an unmeasured accelerant, which --bulk exists to price.
var _bulk := false
# Fleet size is what decides whether DEPART ALL is worth having: the manual path
# costs two taps per aircraft, the button costs two flat, so the saving is
# 2N-2. Recording the level at each size says where a gate would actually bite.
var _fleet_marks := {}
var _trace := false
# Fast-forward multiplier the imaginary player is running at. Taps cost
# _latency * _speed of GAME time, because their hands do not speed up.
var _speed := 1.0
# Is fuel ever actually a constraint? Spend against earnings, and how often an
# aircraft sat on the ground because the tank was empty.
var _fuel_spend := 0
var _earned := 0
var _fuel_blocks := 0
var _peak_stock := 0
var _fuel_before := 0
var _last_money := -1
# Which destination the imaginary player routes to. "match" is the game's own
# default (the exact cloud match for the aircraft); "near" always takes the
# 1-cloud hop; "far" always takes the furthest it can reach.
#
# The two are not obviously ordered. Short legs pay 84x more per MINUTE, long
# legs 5x more per TAP, and a session is a budget of the player's time while the
# hours between sessions are free - so which one binds depends on the size of
# the fleet, and may well flip as it grows.
var _routing := "match"
# Whether the imaginary player bothers with the daily tasks. OFF is the baseline
# the quest faucet has to be measured against - and a bot that does not claim
# would report "quests changed nothing", which is a statement about the bot.
var _do_quests := true
var _quest_coins := 0
# Coins that fell out of BUILDINGS, kept apart from quest coins so the two
# sources can be sized against each other - the whole question of whether a
# building upgrade is worth anything turns on which one dominates.
var _building_coins := 0
# Milestone payouts, apart from drops - they are a different lever with a
# different cap and sizing one against the other is the whole point.
var _milestone_coins := 0
var _sets_done := 0
var _started := 0.0


func _ready() -> void:
	BuildingProgress.milestone_reached.connect(_on_milestone)
	var args := OS.get_cmdline_user_args()
	if not args.has("--bot"):
		return
	# --who first, so an explicit --sessions/--minutes after it still wins.
	for i in range(args.size() - 1):
		if args[i] == "--who" and WHO.has(args[i + 1]):
			var w: Dictionary = WHO[args[i + 1]]
			_who = args[i + 1]
			_sessions = int(w["sessions"])
			_minutes = float(w["minutes"])
			_days = int(w["days"])
	for i in range(args.size() - 1):
		match args[i]:
			"--days": _days = int(args[i + 1])
			"--routing": _routing = args[i + 1]
			"--quests": _do_quests = args[i + 1] != "off"
			"--trace": _trace = true
			"--latency": _latency = maxf(0.0, float(args[i + 1]))
			"--speed": _speed = maxf(1.0, float(args[i + 1]))
			"--sessions": _sessions = int(args[i + 1])
			"--bulk": _bulk = args[i + 1] != "off"
			"--minutes": _minutes = float(args[i + 1])
	call_deferred("_run")


func _run() -> void:
	_started = Time.get_ticks_msec() / 1000.0
	# DROP THE WHOLE SCENE FIRST. The bot drives autoloads; the world is just an
	# audience. Left in the tree, every fleet_changed rebuilds every apron slot
	# and world sprite - at 110 pads that is 220 nodes a time, thousands of
	# times a run, and it exhausts Godot's 32MB deferred-call queue outright
	# (the same overflow Fleet.BULK_LAUNCH_STAGGER was added for).
	# free(), not queue_free(): queued frees are deferred to the end of the
	# frame, so the panels were still in the tree and still connected when the
	# reset below fired its signals - straight into half-torn-down UI.
	var scene := get_tree().current_scene
	if scene:
		get_tree().root.remove_child(scene)
		scene.free()
	# A bot run is a fresh game every time, or it measures whatever save
	# happened to be lying about.
	SaveGame.reset_to_defaults()

	print("  BOT [%s] - %d sessions/day x %.0f min = %.0f min/day, over %d days"
		% [_who, _sessions, _minutes, _sessions * _minutes, _days])
	print("  fare %d - the game's own ShopCatalog, Fleet and Progression, not a copy\n"
		% Fleet.TICKET_PRICE)
	print("  %6s %6s %12s %6s %5s %5s %6s" %
		["day", "level", "cash", "fleet", "pads", "zones", "bldgs"])

	var gap := (16.0 * 60.0 - _sessions * _minutes) / maxf(1.0, _sessions - 1.0)
	for day in range(1, _days + 1):
		_day = day
		for s in range(_sessions):
			_session(_minutes)
			var last := s == _sessions - 1
			_skip((8.0 * 60.0 if last else gap) * 60.0)
		_check_milestones()
		if day == 1 or day == 7 or day % 10 == 0 or day == _days:
			_report(day)
		if Time.get_ticks_msec() / 1000.0 - _started > WALL_LIMIT:
			print("\n  STOPPED at day %d - wall clock limit" % day)
			break
	_summary()


# One sitting: service everything that landed, spend, dispatch, and keep going
# until the session's minutes are used. Short legs complete WITHIN a session, so
# this has to loop - the Python tool got this wrong for a long time and it made
# the early game look ten times slower than it is.
# A session is a budget of the player's OWN time, and everything spends from it:
# taps at _latency each, waiting for the next landing at face value. It ends when
# the budget is gone, wherever that leaves the fleet - mid-cycle, half-dispatched,
# aircraft sitting claimed and unfuelled. Which is how sessions actually end.
func _session(minutes: float) -> void:
	var left := minutes * 60.0
	for _pass in range(400):
		var before := _taps
		_collect()
		_buy()
		_dispatch()
		# Is fuel ever actually a constraint? Gross income is every upward
		# movement of the balance; a block is an aircraft sitting on the ground
		# this pass because the tank was empty.
		if _last_money >= 0 and Economy.money > _last_money:
			_earned += Economy.money - _last_money
		_last_money = Economy.money
		for a in Fleet.aircraft:
			if Fleet.block_reason(a).begins_with("needs"):
				_fuel_blocks += 1
		_peak_stock = maxi(_peak_stock, FuelStore.amount)
		# The day's tasks, collected like anything else - and charged for.
		if _do_quests:
			_claim_quests()
		# Charge for what all of that just did. At speed > 1 the same hand
		# movement eats _speed times as much game time.
		var spent := float(_taps - before) * _latency
		if spent > 0.0:
			_skip(spent * _speed)
			left -= spent
		if left <= 0.0:
			break
		var next := _next_landing()
		var step: float = left if next <= 0.0 else minf(next, left)
		_skip(step * _speed)
		left -= step
	_played += minutes
	if _trace and _played <= 120.0:
		print("    t+%5.0f min  lvl %2d  $%-9s  %2d aircraft  %2d pads  %d taps"
			% [_played, Progression.level, _thousands(Economy.money),
				Fleet.aircraft.size(), _total_pads(), _taps])


func _skip(seconds: float) -> void:
	GameClock.skip(seconds)
	Fleet.advance_by(seconds)
	# Both of these normally ride _process, which never runs here - see
	# Quests.tick.
	Quests.tick()


# One press of DEPART ALL: it claims and departs every aircraft that can move.
# Charged two taps - opening the routes panel and pressing the button - against
# the two PER AIRCRAFT the manual path pays.
func _collect_bulk() -> void:
	# advance_all cannot buy fuel, so a dry store would silently stall the whole
	# fleet and read as the bulk player being slower rather than out of fuel.
	var need := 0
	for a in Fleet.aircraft:
		if not a.is_idle():
			need += Fleet.fuel_cost(a.model_key, Fleet.destination_of(a))
	if FuelStore.amount < need:
		_buy_fuel(need - FuelStore.amount)
	_taps += 2
	Fleet.advance_all()
	var coins_before: int = Coins.amount
	var milestones_before: int = _milestone_coins
	BuildingProgress.collect_all()
	_building_coins += (Coins.amount - coins_before) \
		- (_milestone_coins - milestones_before)


func _next_landing() -> float:
	var soonest := -1.0
	for a in Fleet.aircraft:
		if a.state == FleetAircraft.State.FLYING_OUT or a.state == FleetAircraft.State.FLYING_BACK:
			if soonest < 0.0 or a.flight_time_left < soonest:
				soonest = a.flight_time_left
	return soonest


func _note_fleet() -> void:
	var n: int = Fleet.aircraft.size()
	for mark in [3, 5, 8, 10, 12, 15, 20, 25, 30, 40]:
		if n >= mark and not _fleet_marks.has(mark):
			_fleet_marks[mark] = [Progression.level, _played / 60.0, maxi(0, 2 * n - 2)]


func _collect() -> void:
	_note_fleet()
	if _bulk:
		_collect_bulk()
		return
	for a in Fleet.aircraft.duplicate():
		match a.state:
			FleetAircraft.State.AWAITING_DEST_CLAIM:
				_taps += 1
				Fleet.claim_destination_reward(a.id)
			FleetAircraft.State.AWAITING_HOME_CLAIM:
				_taps += 1
				Fleet.claim_home_reward(a.id)
	for a in Fleet.aircraft.duplicate():
		match a.state:
			FleetAircraft.State.AWAITING_DEST_REFUEL:
				_taps += 1
				Fleet.refuel_at_destination(a.id)
			FleetAircraft.State.AWAITING_HOME_REFUEL:
				# BUYING FIRST MATTERS. A round trip spends fuel twice - once to
				# depart and once to refuel on arrival home - and only the
				# departure was topping up. An aircraft that landed with the tank
				# short stuck in AWAITING_HOME_REFUEL forever, because nothing
				# ever bought the fuel it was waiting for.
				var need := Fleet.fuel_cost(a.model_key, Fleet.destination_of(a))
				if FuelStore.amount < need:
					_buy_fuel(need)
				_taps += 1
				Fleet.refuel_and_depart(a.id)
	# Measured as a delta MINUS whatever milestones landed inside the call - a
	# rent collection settles finished upgrades on its way through, so a
	# milestone can be paid in here and would otherwise be counted as a drop.
	var coins_before: int = Coins.amount
	var milestones_before: int = _milestone_coins
	BuildingProgress.collect_all()
	_building_coins += (Coins.amount - coins_before) \
		- (_milestone_coins - milestones_before)


# EVERY AIRCRAFT NEEDS A PAD BEFORE IT CAN DO ANYTHING. Fleet.buy only adds it
# to the roster with assigned_apron_id = -1 - assigning is a separate act the
# player performs on the apron. The bot was buying nineteen aircraft and flying
# exactly one: the granted starter, which is the only one that comes with a pad.
# Everything else sat idle in the hangar for thirty simulated days.
func _assign_idle() -> void:
	var taken := {}
	for a in Fleet.aircraft:
		if a.assigned_apron_id > 0:
			taken[a.assigned_apron_id] = true
	var free: Array = []
	var starts: Dictionary = ApronLayout.compute_id_starts()
	for map_key in _owned_maps():
		var data := ApronLayout.effective_area_data(map_key)
		for area_name in Maps.areas_for(map_key):
			if not ZoneProgress.is_unlocked(area_name) or not starts.has(area_name):
				continue
			var pts: Array = data.get(area_name, [])
			for i in range(pts.size()):
				var id: int = starts[area_name] + i
				if ApronProgress.is_built(id) and not taken.has(id):
					free.append(id)
	free.sort()
	var n := 0
	for a in Fleet.aircraft:
		if a.assigned_apron_id > 0 or n >= free.size():
			continue
		Fleet.assign_to_apron(a.id, free[n])
		n += 1


func _dispatch() -> void:
	_assign_idle()
	for a in Fleet.aircraft:
		if a.state != FleetAircraft.State.PARKED:
			continue
		if a.destination == "":
			a.destination = _route_for(a.model_key)
		var need := Fleet.fuel_cost(a.model_key, Fleet.destination_of(a))
		if FuelStore.amount < need:
			_buy_fuel(need)
		_taps += 1
		Fleet.fuel_and_depart(a.id)


# The shop sells fixed bundles, so this cannot buy the exact shortfall - the
# smallest tier that covers it, or nothing.
# Batches carry a price multiplier now (FuelStore.BATCH_MULTIPLIER), so the
# smallest batch that covers the need is no longer the cheapest way to buy -
# 50 units at a time costs 25% more than the same fuel in 50,000 lots.
#
# So it buys the BIGGEST batch it can comfortably afford, capping the spend at
# a third of the balance so it does not sink the whole treasury into fuel and
# stall the pads and aircraft it is saving for. Falls back to the smallest one
# that covers the need, which is what a player with no money has to do.
const FUEL_SPEND_SHARE := 0.34

# The destination this policy wants, clamped to what the aircraft can actually
# reach and what is actually unlocked.
func _coin_models() -> int:
	var n := 0
	for e in ShopCatalog.ENTRIES:
		if str(e.get("currency", "")) == ShopCatalog.COINS:
			n += 1
	return n


# Collect anything the day's tasks have finished. Charged at the same tap rate
# as everything else: one to open the panel, one per claim, one for the set.
func _claim_quests() -> void:
	var any := false
	for key in Quests.active.duplicate():
		if Quests.is_complete(str(key)) and not bool(Quests.claimed.get(key, false)):
			if not any:
				_taps += 1        # opening the panel
				any = true
			_taps += 1
			Quests.claim(str(key))
	if Quests.set_reward_available():
		if not any:
			_taps += 1
		_taps += 1
		var before: int = Coins.amount
		if Quests.claim_set():
			_sets_done += 1
			_quest_coins += Coins.amount - before


func _route_for(model_key: String) -> String:
	if _routing == "match":
		return Fleet.best_destination_for(model_key)
	var reachable: Array = []
	for map_key in Maps.visitable_maps():
		if Maps.is_robot_map(map_key) and Fleet.in_range(model_key, map_key):
			reachable.append(map_key)
	if reachable.is_empty():
		return Fleet.best_destination_for(model_key)
	reachable.sort_custom(func(x, y): return Fleet.distance_to(x) < Fleet.distance_to(y))
	return str(reachable[0] if _routing == "near" else reachable[-1])


func _buy_fuel(need: int) -> void:
	var short: int = need - FuelStore.amount
	var budget: float = Economy.money * FUEL_SPEND_SHARE
	_fuel_before = Economy.money
	var tiers := [50, 500, 5000, 50000]
	for i in range(tiers.size() - 1, -1, -1):
		var qty: int = tiers[i]
		if qty >= short and FuelStore.cost_of(qty) <= budget:
			_fuel_spend += FuelStore.cost_of(qty)
			FuelStore.buy(qty)
			return
	for qty in tiers:
		if qty < short:
			continue
		if Economy.money >= FuelStore.cost_of(qty):
			_fuel_spend += FuelStore.cost_of(qty)
			FuelStore.buy(qty)
		return


# Deliberately the same priority the Python tool uses, so the two are comparable:
# pads first (they gate the fleet), then aircraft, then zones, then buildings.
# A fuel reserve is held back - an aircraft that cannot fly is worth nothing.
func _buy() -> void:
	for _pass in range(60):
		var did := false
		if _free_pads() <= 0 and _build_pad():
			did = true
		elif _free_pads() > 0 and _buy_aircraft():
			did = true
		elif _buy_zone():
			did = true
		elif _buy_building():
			did = true
		if not did:
			return


func _reserve() -> int:
	var need := 0
	for a in Fleet.aircraft:
		need += Fleet.fuel_cost(a.model_key, Fleet.destination_of(a))
	return maxi(0, need - FuelStore.amount) * FuelStore.current_price


func _spendable() -> int:
	return Economy.money - _reserve()


# EVERY AIRPORT YOU OWN, not just homeland.
#
# The bot looked only at Maps.DEFAULT_MAP everywhere, so it would buy Dreamland
# at level 57 and then never build one of its 42 pads - the fleet stayed pinned
# at homeland's 110 from day 50 to day 90, and with it the income and the XP
# rate. That flat rate was read as "the curve slows down"; it was the bot
# refusing to expand.
static func _owned_maps() -> Array:
	var out: Array = []
	for map_key in Maps.MAPS:
		if Maps.is_owned(map_key) and not Maps.MAPS[map_key].has("visiting"):
			out.append(map_key)
	return out


func _free_pads() -> int:
	var built := 0
	for map_key in _owned_maps():
		for area_name in Maps.areas_for(map_key):
			if ZoneProgress.is_unlocked(area_name):
				built += _built_in(area_name, map_key)
	return built - Fleet.aircraft.size()


func _built_in(area_name: String, map_key := Maps.DEFAULT_MAP) -> int:
	var starts: Dictionary = ApronLayout.compute_id_starts()
	if not starts.has(area_name):
		return 0
	var pts: Array = ApronLayout.effective_area_data(map_key).get(area_name, [])
	var n := 0
	for i in range(pts.size()):
		if ApronProgress.is_built(starts[area_name] + i):
			n += 1
	return n


# The cheapest unbuilt pad anywhere unlocked - pads price per area and rise with
# each one built there, so filling one area before starting the next is the
# worst possible order.
func _build_pad() -> bool:
	var best_area := ""
	var best_id := -1
	var best_cost := 1 << 30
	var starts: Dictionary = ApronLayout.compute_id_starts()
	for map_key in _owned_maps():
		var data := ApronLayout.effective_area_data(map_key)
		for area_name in Maps.areas_for(map_key):
			if not ZoneProgress.is_unlocked(area_name) or not starts.has(area_name):
				continue
			var cost := ApronProgress.cost_for_area(area_name)
			if cost >= best_cost:
				continue
			var pts: Array = data.get(area_name, [])
			for i in range(pts.size()):
				var id: int = starts[area_name] + i
				if not ApronProgress.is_built(id):
					best_area = area_name
					best_id = id
					best_cost = cost
					break
	if best_id < 0 or _spendable() < best_cost:
		return false
	return ApronProgress.build(best_id, best_area)


func _buy_aircraft() -> bool:
	var best := ""
	var best_rate := 0.0
	var coin_best := ""
	for e in ShopCatalog.ENTRIES:
		var key := str(e["key"])
		if not ShopCatalog.unlocked(key):
			continue
		var dest := Fleet.best_destination_for(key)
		var mins := Fleet.flight_seconds_to(dest, key) / 60.0
		var rate := Fleet.payout_for(key, dest) / maxf(mins, 0.01)
		if str(e.get("currency", ShopCatalog.CASH)) == ShopCatalog.COINS:
			if Coins.amount >= int(e["price"]) and coin_best == "":
				coin_best = key
			continue
		if int(e["price"]) > _spendable():
			continue
		if rate > best_rate:
			best_rate = rate
			best = key
	# Coins first while any are affordable - they ignore the level gate, so they
	# are the strongest thing a new account can do.
	if coin_best != "":
		var ce := ShopCatalog.entry_for(coin_best)
		return Fleet.buy(coin_best, int(ce["price"]), ShopCatalog.COINS)
	if best == "":
		return false
	return Fleet.buy(best, int(ShopCatalog.entry_for(best)["price"]), ShopCatalog.CASH)


# EVERY zone, not just homeland's. Four of the ten in ZONE_REQUIREMENTS are on
# other maps - the three Dreamland zones and the Carrier - and walking only
# homeland's area list meant the bot could never buy them, so "all zones" was
# unreachable by construction and reported "not reached" after 55 hours of play
# as though that were a finding about the game.
func _buy_zone() -> bool:
	if _free_pads() > 0:
		return false
	for area_name in ZoneProgress.ZONE_REQUIREMENTS:
		if ZoneProgress.is_unlocked(area_name):
			continue
		var req: Dictionary = ZoneProgress.requirement_for(area_name)
		if req.is_empty() or Progression.level < int(req["level"]):
			continue
		if _spendable() < int(req["cost"]):
			continue
		if ZoneProgress.unlock(area_name):
			if not _zone_times.has(area_name):
				_zone_times[area_name] = [_played, _day]
			return true
	return false


func _buy_building() -> bool:
	if not BuildingProgress.buildings_unlocked():
		return false
	var best := ""
	var best_rate := 0.0
	for b in BuildingLayout.BUILDINGS:
		var key := str(b["key"])
		if BuildingLayout.currency_of(key) == "coins":
			continue
		if not BuildingProgress.is_unlocked(key) or BuildingLayout.price_of(key) > _spendable():
			continue
		var rate := float(BuildingLayout.rent_of(key)) / maxf(1.0, float(b["minutes"]))
		if rate > best_rate:
			best_rate = rate
			best = key
	if best == "":
		return false
	for plot in BuildingLayout.load_data():
		var id := int(plot.get("id", 0))
		if not BuildingProgress.is_built(id):
			return BuildingProgress.build(id, best)
	# THE CITY IS FULL - which used to be the end of it, and is the wall
	# upgrades exist to remove. Take the cheapest level available: it is the
	# best rent per dollar, since cost climbs faster than rent does.
	return _upgrade_building()


# One tap to start, and the building goes off service until it finishes.
func _upgrade_building() -> bool:
	var best_plot := -1
	var best_cost := 0
	for plot in BuildingLayout.load_data():
		var id := int(plot.get("id", 0))
		if not BuildingProgress.can_upgrade(id):
			continue
		var cost := BuildingProgress.upgrade_cost(id)
		if cost > _spendable():
			continue
		if best_plot == -1 or cost < best_cost:
			best_plot = id
			best_cost = cost
	if best_plot == -1:
		return false
	_taps += 1
	return BuildingProgress.start_upgrade(best_plot)


func _check_milestones() -> void:
	var top := 1
	for e in ShopCatalog.ENTRIES:
		if str(e.get("currency", ShopCatalog.CASH)) != ShopCatalog.COINS:
			top = maxi(top, int(e["level"]))
	# HOMELAND'S ZONES, not all ten. Dreamland and the Carrier have maps and
	# price tags but almost nothing built on them - their levels and costs are
	# marked PLACEHOLDER in ZoneProgress - so counting them measured how long it
	# takes to finish content that does not exist yet, and reported "not
	# reached" after fifty hours as though that said something about pacing.
	var home_total := 0
	var home_done := 0
	for area_name in Maps.areas_for(Maps.DEFAULT_MAP):
		if not ZoneProgress.ZONE_REQUIREMENTS.has(area_name):
			continue
		home_total += 1
		if ZoneProgress.is_unlocked(area_name):
			home_done += 1
	var done := {
		"fleet ladder": Progression.level >= top,
		"home zones": home_total > 0 and home_done >= home_total,
		"all plots": BuildingProgress.built_count() >= BuildingLayout.load_data().size(),
	}
	for name in done:
		if done[name] and not _milestones.has(name):
			_milestones[name] = [_played, _day]


func _report(day: int) -> void:
	print("  %6d %6d %12s %6d %5d %5d %6d" % [
		day, Progression.level, _thousands(Economy.money),
		Fleet.aircraft.size(), _total_pads(), ZoneProgress.unlocked_zones.size(),
		BuildingProgress.built_count()])


# GDScript has no thousands separator, and a nine-figure balance is unreadable
# without one.
func _thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	var c := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


func _total_pads() -> int:
	var n := 0
	for map_key in _owned_maps():
		for area_name in Maps.areas_for(map_key):
			n += _built_in(area_name, map_key)
	return n


func _summary() -> void:
	print("\n  after %.0f minutes (%.1f hours) of PLAY:" % [_played, _played / 60.0])
	for name in ["fleet ladder", "all pads", "home zones", "all plots"]:
		if _milestones.has(name):
			print("    %-14s %6.1f h of play   (day %d)"
				% [name, _milestones[name][0] / 60.0, _milestones[name][1]])
		else:
			print("    %-14s not reached" % name)
	print("\n  zones, in the order they were bought:")
	for area_name in Maps.areas_for(Maps.DEFAULT_MAP):
		if _zone_times.has(area_name):
			print("    %-10s %6.1f h of play   (day %d)" % [area_name,
				_zone_times[area_name][0] / 60.0, _zone_times[area_name][1]])
		elif ZoneProgress.ZONE_REQUIREMENTS.has(area_name):
			print("    %-10s never" % area_name)
	var levels := 0
	var maxed := 0
	for plot in BuildingLayout.load_data():
		var id := int(plot.get("id", 0))
		if BuildingProgress.is_built(id):
			levels += BuildingProgress.level_at(id)
			if BuildingProgress.level_at(id) >= BuildingProgress.MAX_LEVEL:
				maxed += 1
	print("  city: %d building levels across the plots, %d of them maxed"
		% [levels, maxed])
	print("  routing policy: %s   daily tasks: %s" % [_routing, "on" if _do_quests else "off"])
	print("  quests: %d sets completed, %d coins earned" % [_sets_done, _quest_coins])
	print("  building coin drops: %d" % _building_coins)
	print("  FLEET SIZE vs LEVEL (taps a turnaround saved by Depart All):")
	for mark in [3, 5, 8, 10, 12, 15, 20, 25, 30, 40]:
		if _fleet_marks.has(mark):
			var v: Array = _fleet_marks[mark]
			print("    %2d aircraft  at level %-3d  %5.1f h of play   saves %d taps"
				% [mark, v[0], v[1], v[2]])
	print("  milestone coins: %d" % _milestone_coins)
	print("  coins: %d earned over the run (started with %d), against %d coin aircraft in the shop"
		% [Coins.amount - Coins.DEFAULT_AMOUNT, Coins.DEFAULT_AMOUNT, _coin_models()])
	print("\n  fuel: spent $%s against $%s earned = %.1f%% of income"
		% [_thousands(_fuel_spend), _thousands(_earned),
			100.0 * _fuel_spend / maxf(1.0, _earned)])
	print("  fuel: %s aircraft-passes blocked on an empty tank, peak stock %s units"
		% [_thousands(_fuel_blocks), _thousands(_peak_stock)])
	print("\n  taps: %s over %.1f h of play = %.0f a minute (%.1fs each, x%d speed)"
		% [_thousands(_taps), _played / 60.0, _taps / maxf(1.0, _played),
			_latency, roundi(_speed)])
	print("\n  wall time %.1f s" % (Time.get_ticks_msec() / 1000.0 - _started))
	get_tree().quit()


func _on_milestone(_plot_id: int, amount: int) -> void:
	_milestone_coins += amount
