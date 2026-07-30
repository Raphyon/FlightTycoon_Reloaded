class_name ShopCatalog
extends RefCounted

# Every aircraft carries three stats, all three shown on the shop card in a
# row under the name:
#
#   force   S-E grade, best to worst, S being the top class. Nimbleness, not
#           literal airspeed: the 328 Jet is S and the 747/A380 are down at
#           D/E. Drives flight time via SPEED_FACTOR in fleet.gd, where an
#           S-class covers a cloud in one minute flat.
#   seats   capacity, all of which flies and all of which pays.
#   fuel    units burned per leg, spent out of FuelStore.
#   range   how many clouds of distance it can cover - drawn above the art.
#   level   pilot level required to buy it. The 328 Jet is the only one you
#           start able to own.
#   ticket  OPTIONAL per-head fare, overriding Fleet.TICKET_PRICE. Only for
#           aircraft whose capacity is too small to earn at the flat rate.
#
# Revenue for a leg is seats * fare, and nothing else - distance buys you a
# longer wait, never a bigger cheque. Price is then set as (target payback in
# round trips) * (revenue for a round trip), with the target rising by tier -
# 5 round trips for the 328 Jet up to 71 for the A380 - so each step up is an
# investment rather than a free upgrade.
#
# The P-51 is the one entry that can't be solved by capacity - it has two
# seats and is meant to. It gets a fare instead (400), set to the same target
# ratio as everything else, which lands it just above the 328 Jet and just
# below the A318 rather than dominating the middle of the game.
#
# Prices are NOT arbitrary any more. Three are known from the real game and
# the curve reproduces all three exactly: the second cash aircraft at 5,000
# (our 328 Jet, the 50-seat starter), the 747 at 500,000 and the A380 at
# 1,000,000.
#
# That also puts aircraft on the same scale as the construction
# economy they have to compete with for money - Snow aprons are 500,000 each
# (ApronProgress) and the Snow zone itself is 1,000,000 (ZoneProgress). At the
# old 250-9999 prices the entire fleet cost less than one apron.
#
# Still placeholder: which grade/seat/fuel numbers each of OUR fourteen gets.
# None of the aircraft with readable reference stats are in our fleet, so
# these are interpolated onto the reference's scale, not copied from it.
#
# has_world_sprite: whether the model has body/shadow art to actually place
# on an apron. 328jet and p-51mustang were ingested from the dump; the jets
# are derived from their own shop icons (tools/plane_derive.py); the A400M came
# in as a clean dump world sprite with its own 4-frame prop strip (WORLD_CLEAN
# in plane_derive.py); and the Black Hawk, UFO, airship and Ark are cut from
# real multi-element sheets (tools/sheet_derive.py).
#
# Every entry is true as of the A400M landing, so the flag currently gates
# nothing - it stays because it's the switch that keeps a model visible in
# the shop but unbuyable, and the next model we get a shop icon for before
# world art will need it again.
const CASH := "cash"
const COINS := "coins"

# Listed cheapest first - that IS the progression order, and the shop pages
# read in this order.
# In UNLOCK order - which is also the order the shop pages read.
#
# These numbers are SOLVED, not chosen. XP is payout/50 and a round trip takes
# 2 * 60 * SPEED_FACTOR seconds, so an aircraft's worth per second of play is
# exactly payout / SPEED_FACTOR - the grade matters as much as the capacity.
# A target for that ratio was set rising ~22% per unlock, and each aircraft's
# capacity solved backwards from it given the grade its art suggests:
#
#     seats = target_rate * SPEED_FACTOR / fare
#
# so both XP per second and money per second rise strictly with unlock level
# and every new aircraft is the best thing you own. Before this the fast
# 2-seat P-51 beat every airliner in the game from level 10 to level 90.
#
# Fuel is payout/100 * SPEED_FACTOR, i.e. it eats SPEED_FACTOR/10 of revenue -
# an S-class sips 10%, an E-class drinks 30%. That is what stops the grades
# from being a pure ranking: the fast aircraft are also the efficient ones,
# and the huge slow freighters pay for their capacity at the pump.
#
# Seat counts are game numbers, not real specifications - an An-225 holding
# 1500 is what its slot in the curve requires. Prices are payback-in-round-
# trips rising 6 -> 50, pinned to the three known real ones: the 328 Jet at
# 5,000, the 747 at 500,000 and the A380 at 1,000,000.
const ENTRIES := [
	{"key": "328jet", "name": "328 Jet", "icon": "328jet_blue.png", "price": 5000, "level": 1,
		"force": "S", "seats": 50, "fuel": 5, "range": 2, "has_world_sprite": true},
	{"key": "p51", "name": "P-51 Mustang", "icon": "p51_white.png", "price": 13000, "level": 10,
		"force": "A", "seats": 2, "fuel": 10, "ticket": 400, "range": 2, "has_world_sprite": true},
	{"key": "a318", "name": "Airbus A318", "icon": "a318_default.png", "price": 30000, "level": 15,
		"force": "C", "seats": 160, "fuel": 32, "range": 3, "has_world_sprite": true},
	{"key": "a319", "name": "Airbus A319", "icon": "a319_default.png", "price": 48000, "level": 25,
		"force": "C", "seats": 200, "fuel": 40, "range": 3, "has_world_sprite": true},
	{"key": "blackh", "name": "Black Hawk", "icon": "blackh_green.png", "price": 58000, "level": 35,
		"force": "B", "seats": 190, "fuel": 28, "range": 3, "has_world_sprite": true},
	{"key": "a300", "name": "Airbus A300", "icon": "a300_default.png", "price": 130000, "level": 45,
		"force": "D", "seats": 390, "fuel": 98, "range": 4, "has_world_sprite": true},
	{"key": "airship", "name": "Airship", "icon": "airship_default.png", "price": 215000, "level": 60,
		"force": "E", "seats": 570, "fuel": 171, "range": 4, "has_world_sprite": true},
	{"key": "ufo", "name": "UFO", "icon": "ufo_blue.png", "price": 40, "currency": COINS, "level": 70,
		"force": "S", "seats": 235, "fuel": 24, "range": 5, "has_world_sprite": true},
	{"key": "747", "name": "Boeing 747", "icon": "747_default.png", "price": 500000, "level": 80,
		"force": "D", "seats": 725, "fuel": 181, "range": 5, "has_world_sprite": true},
	{"key": "a400m", "name": "A400M", "icon": "a400m_white.png", "price": 550000, "level": 90,
		"force": "C", "seats": 680, "fuel": 136, "range": 5, "has_world_sprite": true},
	{"key": "v22", "name": "V-22", "icon": "v22_green.png", "price": 600000, "level": 100,
		"force": "B", "seats": 600, "fuel": 90, "range": 5, "has_world_sprite": true},
	{"key": "an-225", "name": "An-225", "icon": "an-225_default.png", "price": 850000, "level": 110,
		"force": "E", "seats": 1500, "fuel": 450, "range": 5, "has_world_sprite": true},
	{"key": "a380-300", "name": "Airbus A380", "icon": "a380-300_default.png", "price": 1000000, "level": 130,
		"force": "D", "seats": 1325, "fuel": 331, "range": 5, "has_world_sprite": true},
	{"key": "ark", "name": "Ark", "icon": "ark_default.png", "price": 25, "currency": COINS, "level": 150,
		"force": "A", "seats": 750, "fuel": 94, "range": 5, "has_world_sprite": true},
]

# Anything asking for a model we don't have an entry for still gets a flyable
# aircraft rather than one that earns nothing and burns no fuel.
const FALLBACK := {"force": "C", "seats": 50, "fuel": 10, "range": 1,
	"price": 0, "currency": CASH, "level": 1}


static func entry_for(key: String) -> Dictionary:
	for e in ENTRIES:
		if e["key"] == key:
			return e
	return FALLBACK


static func stat(key: String, stat_name: String) -> Variant:
	return entry_for(key).get(stat_name, FALLBACK[stat_name])


static func currency_of(entry: Dictionary) -> String:
	return str(entry.get("currency", CASH))


static func level_for(key: String) -> int:
	return int(entry_for(key).get("level", 1))


static func unlocked(key: String) -> bool:
	return Progression.level >= level_for(key)
