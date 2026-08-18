extends Node

signal built_changed
signal rent_changed
# The EVENT. rent_changed fires for any reason a timer moved; this one means a
# player tapped a building and took the money.
signal rent_collected(plot_id: int, amount: int)
# An upgrade started or finished. Separate from built_changed because the plot's
# building did not change - only what it is worth.
signal upgrade_changed(plot_id: int)


# --- UPGRADES ---------------------------------------------------------------
#
# The city was FINISHED ABOUT TWO HOURS IN - all 42 plots built and nothing left
# to do with them, which was the earliest wall in the game by a wide margin.
# Levels turn a two-hour system into one that runs the whole game, and cost no
# art: an upgraded building is the same sprite.
#
# RENT ONLY, NOT POPULATION, and that is load-bearing. Popularity multiplies
# FLIGHT cash and is uncapped - a full city is already +420% on every flight the
# fleet makes. Scaling population with levels too would take a maxed city past
# +1,600%, a 17x multiplier on air income, and void every pacing number measured
# so far. The city's economy grows; the fleet's is left alone.
const MAX_LEVEL := 10
const RENT_PER_LEVEL := 1.45
# Cost rides the building's OWN price, so an Eiffel Tower level costs more than
# a cafe level. Otherwise the cheap buildings are the efficient upgrade and the
# expensive ones are a trap you paid extra to enter.
const UPGRADE_COST_EXPONENT := 2.2
const UPGRADE_COST_SHARE := 0.6
# A COIN BUILDING UPGRADES WITH COINS. Its `price` is denominated in coins, so
# running it through the cash curve produced a figure derived from coins and
# charged in dollars - the Eiffel Tower, the best building in the game at 5,000
# a cycle, went to level 10 for $2,800 while a roadside hotel wanted $290,000.
#
# Much gentler curve, because coins are scarce: a whole playthrough earns about
# 150-260 of them (see QUESTS.md) and the aircraft catalogue alone is 243. Maxing
# a coin building costs roughly 180, which is meant to be a real choice against
# buying an aircraft rather than a formality.
const UPGRADE_COIN_SHARE := 0.12
const UPGRADE_COIN_EXPONENT := 1.0
# Two minutes for the first, about two hours for the last. The time is the
# point: a building you come back to is worth more than one you buy.
const UPGRADE_BASE_SECONDS := 120.0
const UPGRADE_TIME_EXPONENT := 1.8

# What the player has built, where, and when its rent was last taken. Keyed by
# the plot ids BuildingLayout authors, per airport:
#
#     {map_key: {"3": {"key": "cafe", "since": 1754300000.0}}}
#
# "since" is a wall-clock unix time, not accumulated play time, so rent builds
# up while the game is SHUT - which is the whole point of a four-hour Grand
# Hotel cycle. Same principle as SaveGame advancing flights while you are away.
#
# The layout says where the construction sites are; this says what stands on
# them. Same split as apron_layout / apron_progress, and for the same reason -
# one is level data that ships with the game, the other is somebody's save.
#
# Ids are strings here because JSON keys always are; helpers below take ints so
# callers don't have to think about it.
const SAVE_PATH := "res://data/building_progress.json"


var built: Dictionary = {}  # map_key -> {plot_id_string: building_key}


func _ready() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		built = parsed
		_migrate_bare_strings()


# Buildings saved before rent existed are a bare key with no "since", which
# reads as an elapsed time of decades and leaves them permanently collectable.
# Stamp them as starting their first cycle now: a save from before the feature
# should begin earning, not hand over a free payout per building.
func _migrate_bare_strings() -> void:
	var now := GameClock.now()
	var touched := false
	for map_key in built:
		var m: Variant = built[map_key]
		if not m is Dictionary:
			continue
		for plot_key in (m as Dictionary):
			if (m as Dictionary)[plot_key] is String:
				(m as Dictionary)[plot_key] = {"key": (m as Dictionary)[plot_key], "since": now}
				touched = true
	if touched:
		_save()


# The Prop Shop is open from the start, and WHICH plots you may use is decided
# per zone instead - see plot_is_available and ZoneRegions.
#
# It used to be shut until Zone2. That gate existed for one reason: a fresh game
# owned no aircraft, so a 3,000 Coffee House out of a 5,000 start left you at
# 2,000 against a 3,000 DC-3, with nothing that flies and one building to tap.
# Granting the starter DC-3 (Fleet.grant_starter) removed the hole itself - you
# can always fly, whatever you spend - so the fence around it is redundant.
#
# Keeping it would also have made the plot bands incoherent: Zone1 has a band of
# six, and Zone1 is where the game starts, so those six were gated behind buying
# a DIFFERENT zone. The bands are the pacing now.
func buildings_unlocked() -> bool:
	return true


# Which zone a plot sits in, from the hand-drawn regions in zone_regions.json, and
# whether that zone is bought yet.
#
# An UNDRAWN plot - one no region contains - stays available. A half-drawn map
# has to keep playing, and a plot that silently vanished because nobody had got
# round to drawing its zone would read as a bug rather than as work outstanding.
# The zone editor shows the unassigned count for exactly this reason.
func plot_area(plot_id: int, map_key: String = "") -> String:
	for plot in BuildingLayout.load_data(map_key):
		if int(plot.get("id", 0)) == plot_id:
			return ZoneRegions.area_at(
				Vector2(float(plot.get("x", 0.0)), float(plot.get("y", 0.0))), map_key)
	return ""


func plot_is_available(plot_id: int, map_key: String = "") -> bool:
	if not buildings_unlocked():
		return false
	var area := plot_area(plot_id, map_key)
	return area == "" or ZoneProgress.is_unlocked(area)


func cost_of(building_key: String) -> int:
	return BuildingLayout.price_of(building_key)


# Unlocked by level, except the coin building - same rule the aircraft shop
# uses, where paying real money skips the earned ladder.
# Coin buildings obey the level gate too, for the same reason coin aircraft now
# do (see ShopCatalog.unlocked). A no-op today - the only coin building is the
# Eiffel Tower at level 1 - but the exception is gone rather than lying in wait.
func is_unlocked(building_key: String) -> bool:
	if not buildings_unlocked():
		return false
	return Progression.level >= BuildingLayout.level_of(building_key)


func can_afford(building_key: String) -> bool:
	if BuildingLayout.currency_of(building_key) == "coins":
		return Coins.amount >= cost_of(building_key)
	return Economy.money >= cost_of(building_key)


# How much of the airport's population it takes to add 1% to what a flight
# pays. The walkthrough's popularity system: "as you add more businesses... you
# will become more popular. This causes your Airport to earn more money."
#
# 800, set against the SIZE OF THE AIRPORT rather than against a feel for what
# one building is worth. Homeland has 41 plots; filling them all with the best
# cash building is 164,000 inhabitants, which at this rate is +205% - the city
# roughly triples what the fleet earns, for $1.64M and 41 purchases.
#
# It was 250, chosen when I was picturing a handful of sites. At 41 plots that
# came to +656%, seven times the +91% the original's level-32 account showed,
# and made the city worth several times the entire fleet.
#
# The cost of the fix is the other end: three buildings is now +0.9% rather
# than +2.9%, so the early game barely feels it. ONE LINEAR RATE CANNOT make
# three buildings matter and forty-one not be absurd. If the opening needs to
# feel it, that wants a curve - more per head early, diminishing after - which
# is a different mechanic, not a different constant.
#
# CASH ONLY, never XP (see Fleet._grant_reward). Levelling is calibrated
# against flights alone, and letting the city accelerate it would drag every
# unlock forward as a side effect of decorating.
const PEOPLE_PER_PERCENT := 800.0


# Multiplier on flight cash from the population, as a plain factor: 1.0 with no
# buildings at all. Deliberately uncapped - the ceiling is the number of plots
# an airport has, which is authored.
func popularity_multiplier(map_key: String = "") -> float:
	return 1.0 + float(total_people(map_key)) / (PEOPLE_PER_PERCENT * 100.0)


func popularity_percent(map_key: String = "") -> float:
	return float(total_people(map_key)) / PEOPLE_PER_PERCENT


# Every inhabitant your buildings have brought in. Cumulative and permanent -
# unlike rent it is never collected, it is just a number that goes up as the
# airport grows.
func total_people(map_key: String = "") -> int:
	var total := 0
	for id_str in _map(map_key):
		total += BuildingLayout.people_of(building_at(int(id_str), map_key))
	return total


func _map(map_key: String) -> Dictionary:
	var key := map_key if map_key != "" else Maps.current
	var got: Variant = built.get(key, {})
	return got if got is Dictionary else {}


# What stands on this plot, or "" if it's still an empty site.
func building_at(plot_id: int, map_key: String = "") -> String:
	var e: Variant = _map(map_key).get(str(plot_id), null)
	if e == null:
		return ""
	# Tolerates the plain-string form this used before rent existed, so a save
	# from then still reads rather than showing an empty airport.
	if e is String:
		return e
	return str((e as Dictionary).get("key", ""))


func level_at(plot_id: int, map_key: String = "") -> int:
	# SETTLE FIRST. An upgrade finishes lazily - there is no timer node, just a
	# timestamp - so whoever asks a question about this plot is what banks it.
	# Without this here, a plot whose upgrade completed while the game was shut
	# reported its OLD level to anything that did not happen to call
	# is_upgrading first, which is most callers.
	_settle(plot_id, map_key)
	var e: Variant = _map(map_key).get(str(plot_id), null)
	if e is Dictionary:
		return maxi(1, int((e as Dictionary).get("level", 1)))
	return 1


# What this plot pays a cycle, its level included. EVERYTHING that asks what a
# building is worth goes through here - BuildingLayout.rent_of is the level 1
# figure and using it directly is how a level would silently stop counting.
func rent_at(plot_id: int, map_key: String = "") -> int:
	var key := building_at(plot_id, map_key)
	if key == "":
		return 0
	return int(round(BuildingLayout.rent_of(key)
		* pow(RENT_PER_LEVEL, level_at(plot_id, map_key) - 1)))


func rent_at_level(building_key: String, level: int) -> int:
	return int(round(BuildingLayout.rent_of(building_key) * pow(RENT_PER_LEVEL, level - 1)))


# Which currency this plot's next level is priced in - the same one it was
# bought with, so a coin building stays a coin building all the way up.
func upgrade_currency(plot_id: int, map_key: String = "") -> String:
	return BuildingLayout.currency_of(building_at(plot_id, map_key))


func upgrade_cost(plot_id: int, map_key: String = "") -> int:
	var key := building_at(plot_id, map_key)
	if key == "":
		return 0
	var next := level_at(plot_id, map_key) + 1
	if BuildingLayout.currency_of(key) == "coins":
		return NiceNumber.coins(int(round(cost_of(key) * UPGRADE_COIN_SHARE
			* pow(float(next), UPGRADE_COIN_EXPONENT))))
	return NiceNumber.cash(int(round(cost_of(key) * UPGRADE_COST_SHARE
		* pow(float(next), UPGRADE_COST_EXPONENT))))


# Rounded to something a clock face would show - whole minutes under ten, five
# minute marks under an hour, quarter hours above. The curve gave 6m58s and
# 1h24m, which is a formula talking.
func upgrade_seconds(plot_id: int, map_key: String = "") -> float:
	var next := level_at(plot_id, map_key) + 1
	return NiceNumber.seconds(UPGRADE_BASE_SECONDS * pow(float(next), UPGRADE_TIME_EXPONENT))


func upgrade_finishes_at(plot_id: int, map_key: String = "") -> float:
	var e: Variant = _map(map_key).get(str(plot_id), null)
	if e is Dictionary:
		return float((e as Dictionary).get("upgrading_until", 0.0))
	return 0.0


func is_upgrading(plot_id: int, map_key: String = "") -> bool:
	_settle(plot_id, map_key)
	return upgrade_finishes_at(plot_id, map_key) > 0.0


# Bank an upgrade whose time is up. Cheap and idempotent, so every reader can
# call it without caring whether somebody already did.
func _settle(plot_id: int, map_key: String = "") -> void:
	var until := upgrade_finishes_at(plot_id, map_key)
	if until > 0.0 and GameClock.now() >= until:
		_finish_upgrade(plot_id, map_key)


func upgrade_seconds_left(plot_id: int, map_key: String = "") -> float:
	if not is_upgrading(plot_id, map_key):
		return 0.0
	return maxf(0.0, upgrade_finishes_at(plot_id, map_key) - GameClock.now())


func upgrade_progress(plot_id: int, map_key: String = "") -> float:
	if not is_upgrading(plot_id, map_key):
		return 0.0
	var total := upgrade_seconds(plot_id, map_key)
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - upgrade_seconds_left(plot_id, map_key) / total, 0.0, 1.0)


func can_upgrade(plot_id: int, map_key: String = "") -> bool:
	return building_at(plot_id, map_key) != "" \
		and level_at(plot_id, map_key) < MAX_LEVEL \
		and not is_upgrading(plot_id, map_key)


# Start one. THE BUILDING GOES OFF SERVICE for the duration - taking it out is
# the cost of improving it, which is what makes putting the whole city under
# scaffolding at once a thing you feel rather than a free click.
func start_upgrade(plot_id: int, map_key: String = "") -> bool:
	if not can_upgrade(plot_id, map_key):
		return false
	var cost := upgrade_cost(plot_id, map_key)
	if upgrade_currency(plot_id, map_key) == "coins":
		if not Coins.spend(cost):
			return false
	elif not Economy.spend_money(cost):
		return false
	var mk := map_key if map_key != "" else Maps.current
	var m := _map(mk)
	var e: Dictionary = m.get(str(plot_id), {})
	e["upgrading_until"] = GameClock.now() + upgrade_seconds(plot_id, map_key)
	# What has been sunk into this plot, so demolition can refund it - a maxed
	# plot that refunded only its original price would be a trap.
	e["spent"] = int(e.get("spent", 0)) + cost
	m[str(plot_id)] = e
	built[mk] = m
	_save()
	upgrade_changed.emit(plot_id)
	built_changed.emit()
	return true


func _finish_upgrade(plot_id: int, map_key: String = "") -> void:
	var mk := map_key if map_key != "" else Maps.current
	var m := _map(mk)
	var e: Variant = m.get(str(plot_id), null)
	if not (e is Dictionary):
		return
	var d := e as Dictionary
	if float(d.get("upgrading_until", 0.0)) <= 0.0:
		return
	d["level"] = mini(int(d.get("level", 1)) + 1, MAX_LEVEL)
	d.erase("upgrading_until")
	# The rent cycle restarts from the moment it comes back into service, so an
	# upgrade cannot also hand over a cycle's rent for the time it was shut.
	d["since"] = GameClock.now()
	m[str(plot_id)] = d
	built[mk] = m
	_save()
	upgrade_changed.emit(plot_id)
	rent_changed.emit()


func _since(plot_id: int, map_key: String = "") -> float:
	var e: Variant = _map(map_key).get(str(plot_id), null)
	if e is Dictionary:
		return float((e as Dictionary).get("since", 0.0))
	return 0.0


# Seconds until this building's rent is ready. 0 means it is waiting for you.
func seconds_until_ready(plot_id: int, map_key: String = "") -> float:
	var key := building_at(plot_id, map_key)
	if key == "":
		return 0.0
	var cycle := BuildingLayout.cycle_seconds(key)
	var elapsed := GameClock.now() - _since(plot_id, map_key)
	return maxf(0.0, cycle - elapsed)


func is_rent_ready(plot_id: int, map_key: String = "") -> bool:
	# A building under scaffolding earns nothing - see start_upgrade.
	return building_at(plot_id, map_key) != "" \
		and not is_upgrading(plot_id, map_key) \
		and seconds_until_ready(plot_id, map_key) <= 0.0


# Rent does NOT stack. One cycle completes and then the building waits to be
# collected - leaving for a day does not bank twelve Grand Hotel payouts, it
# banks one. That is what the walkthrough describes ("can be collected after a
# certain amount of time"), and it is also what stops going away being strictly
# better than playing.
# A lottery on every rent collection, and the first way coins ENTER the game -
# until now the only coins in existence were the starting float, with aprons,
# skins, liveries and the coin aircraft all draining a pool that never refilled.
#
# On rent rather than on flights deliberately: it gives the city a job the fleet
# cannot do, and it is the reward for a thing you already tap.
#
# THE RATE IS THE WHOLE DESIGN. Rent does not stack, so collections are bounded
# by how often you open the game, not by how many buildings you own - a full 42
# plots collected four times a day is 168 rolls, and no more. See the table in
# tools/econ_sim.py --coins for what a given chance actually pays out.
# PER MINUTE OF THE BUILDING'S CYCLE, not per collection. A flat per-collection
# chance pays out fastest on whatever cycles fastest, and the fastest cycles are
# the cheapest buildings - a 5-minute Coffee House would roll four times as
# often as a 16-minute Office. That makes the coin lottery push players to fill
# all 42 plots with the cheapest thing available, which is the exact trap
# demolish() was added to let them escape. Scaling by cycle length makes
# coins-per-hour identical across the catalogue, so what you build is a
# decision about rent and inhabitants and nothing else.
#
# 0.00083 puts a 12-minute building - about the catalogue average - at 1% a
# collection, which measures at roughly 5 coins a month for a casual player and
# 36 for a regular one against a 5-coin Paper Plane and a 70-coin Ark. See
# tools/econ_sim.py --coins.
const COIN_CHANCE_PER_CYCLE_MINUTE := 0.00083
const COIN_DROP_AMOUNT := 1


func coin_chance_for(building_key: String) -> float:
	return COIN_CHANCE_PER_CYCLE_MINUTE * float(BuildingLayout.entry(building_key).get("minutes", 0))

# So a drop can be shown. Without it the only feedback is the HUD counter
# ticking up, which nobody is looking at while tapping a building.
signal coin_found(plot_id: int, amount: int)


func collect_rent(plot_id: int, map_key: String = "") -> int:
	if not is_rent_ready(plot_id, map_key):
		return 0
	var key := building_at(plot_id, map_key)
	var amount := rent_at(plot_id, map_key)
	Economy.add_money(amount)
	if randf() < coin_chance_for(key):
		Coins.add(COIN_DROP_AMOUNT)
		coin_found.emit(plot_id, COIN_DROP_AMOUNT)
	var mk := map_key if map_key != "" else Maps.current
	var m := _map(mk)
	var existing: Dictionary = m.get(str(plot_id), {})
	existing["key"] = key
	existing["since"] = GameClock.now()
	m[str(plot_id)] = existing
	built[mk] = m
	_save()
	rent_changed.emit()
	rent_collected.emit(plot_id, amount)
	return amount


# Everything waiting to be collected here, for a "collect all" and for the HUD.
func ready_plots(map_key: String = "") -> Array:
	var out: Array = []
	for id_str in _map(map_key):
		var id := int(id_str)
		if is_rent_ready(id, map_key):
			out.append(id)
	out.sort()
	return out


func collect_all(map_key: String = "") -> int:
	var total := 0
	for id in ready_plots(map_key):
		total += collect_rent(id, map_key)
	return total


func is_built(plot_id: int, map_key: String = "") -> bool:
	return building_at(plot_id, map_key) != ""


func built_count(map_key: String = "") -> int:
	return _map(map_key).size()


# What a demolition hands back, as a fraction of what the building cost. The
# same 0.5 Fleet.RESALE_FRACTION uses for selling an aircraft, because it is the
# same promise: a purchase is reversible at a real but survivable loss.
#
# WHY THIS EXISTS AT ALL. There are 42 plots and nine buildings, and the plots
# fill in the first few hours - the simulator has every archetype at all 42
# inside 3.5 to 16 hours of play, long before the Grand Hotel, Garden Hotel and
# Office Building are affordable. Without a way to clear a site, filling the
# airport with Coffee Houses is a permanent decision that locks the top half of
# the catalogue out of the game for good.
#
# The loss is what stops it being free churn: rebuilding costs you half of what
# the old building cost, so replacing a Cafe with an Office Building is a
# decision rather than an obvious yes.
const DEMOLITION_REFUND := 0.5


# Clears a plot and refunds part of the price, in whatever currency it was
# bought with. Returns what was refunded, or 0 if there was nothing to clear.
#
# The inhabitants go with it, so popularity drops - that is the cost of a
# mistake, and it is what makes filling every plot with the cheapest thing a
# real error rather than a temporary one.
func demolish(plot_id: int, map_key: String = "") -> int:
	var key := building_at(plot_id, map_key)
	if key == "":
		return 0
	var refund := refund_for(plot_id, map_key)
	if BuildingLayout.currency_of(key) == "coins":
		Coins.add(refund)
	else:
		Economy.add_money(refund)
	var mk := map_key if map_key != "" else Maps.current
	var m := _map(mk)
	m.erase(str(plot_id))
	built[mk] = m
	_save()
	built_changed.emit()
	return refund


# What clearing this plot gives back. INCLUDES WHAT WAS SUNK INTO UPGRADES, or a
# maxed plot would refund its original price and nothing else - a trap you paid
# a quarter of a million dollars to walk into.
#
# The panel quotes this and demolish() pays it, so it is one calculation. The
# first version had demolish counting upgrades and this one not, which is
# exactly the drift that keeps biting: two figures that agree on a fresh plot
# and diverge on a real one.
func refund_for(plot_id: int, map_key: String = "") -> int:
	var key := building_at(plot_id, map_key)
	if key == "":
		return 0
	return int(floor(_sunk_into(plot_id, map_key) * DEMOLITION_REFUND))


func _sunk_into(plot_id: int, map_key: String = "") -> int:
	var key := building_at(plot_id, map_key)
	if key == "":
		return 0
	var total := cost_of(key)
	var e: Variant = _map(map_key).get(str(plot_id), null)
	if e is Dictionary:
		total += int((e as Dictionary).get("spent", 0))
	return total


# Buys and places in one step. Refuses a plot that already has something on it
# rather than silently replacing it - clearing one is a separate decision, with
# its own price. See demolish.
func build(plot_id: int, building_key: String, map_key: String = "") -> bool:
	if BuildingLayout.entry(building_key).is_empty():
		return false
	if is_built(plot_id, map_key):
		return false
	if not plot_is_available(plot_id, map_key):
		return false
	if not is_unlocked(building_key):
		return false
	var paid := (Coins.spend(cost_of(building_key))
		if BuildingLayout.currency_of(building_key) == "coins"
		else Economy.spend_money(cost_of(building_key)))
	if not paid:
		return false
	var key := map_key if map_key != "" else Maps.current
	var m := _map(key)
	# The cycle starts the moment it's built, so a new building is not
	# immediately collectable - you pay, then you wait, like every other timer.
	m[str(plot_id)] = {"key": building_key, "since": GameClock.now()}
	built[key] = m
	_save()
	built_changed.emit()
	return true


func _save() -> void:
	# Never over a real playthrough - see SaveGame.save().
	if OS.get_cmdline_user_args().has("--bot"):
		return
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(built, "\t"))
	f.close()
