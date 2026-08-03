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
#   level   pilot level required to buy it. The 328 Jet is the only cash
#           aircraft you start able to own; the coin-priced ones ignore this
#           gate completely (see unlocked).
#   ticket  OPTIONAL per-head fare, overriding Fleet.TICKET_PRICE. Only for
#           aircraft whose capacity is too small to earn at the flat rate.
#
# Revenue for a leg is seats * fare, and nothing else - distance buys you a
# longer wait, never a bigger cheque.
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

# In UNLOCK order - which is also the order the shop pages read.
#
# These numbers are SOLVED, not chosen. XP is payout/MONEY_PER_XP and a round trip takes
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
# 1500 is what its slot in the curve requires.
#
# Prices are payback-in-round-trips rising 2 -> 50. They no longer match the
# live game's (its 747 is 500,000, ours 250,000) because our fare is double
# its, so the same payback costs half as much. The shape is the same, and they
# stay on the same scale as the construction economy they compete with for
# money (ApronProgress, ZoneProgress).
#
# Three entries capacity can't solve, because they're meant to be tiny: the
# P-51 and F-15 carry two, the paper plane carries one. They get a fare
# instead, set to the same target ratio as everything else, so they land on the
# curve rather than dominating the middle of the game. The balloon is the same
# trick read the other way - 16 seats at a sightseeing fare, because an E-class
# balloon needing 255 seats to hit its rate is a shape no balloon has.
#
# The cash ladder below is strictly monotone in BOTH price and rate: each
# aircraft you unlock costs more than the last and earns more per second than
# the last, so there is never a level where the new thing is a downgrade. The
# coin aircraft sit deliberately ABOVE the cash aircraft at their level - that
# premium is what you're paying coins for - and so break the shared curve on
# purpose. Their `level` is a note of where they'd sit if earned, and is only
# used to order them in the shop (see unlocked).
const ENTRIES := [
	# The starting aircraft. 50 seats at the flat fare of 8 is 400 a leg, 800
	# the round trip, and it costs two round trips to pay for itself - which is
	# what lets Zone1 fill inside fifteen minutes. Everything else is priced
	# against it.
	{"key": "328jet", "name": "328 Jet", "icon": "328jet_blue.png", "price": 1500, "level": 1,
		"force": "S", "seats": 50, "fuel": 5, "range": 2, "has_world_sprite": true},
	# The cheapest thing in the game and the first taste of the coin lane: five
	# coins for something marginally better than the aircraft you started with.
	{"key": "paperplane", "name": "Paper Plane", "icon": "paperplane_default.png", "price": 5, "currency": COINS, "level": 2,
		"force": "A", "seats": 1, "fuel": 7, "ticket": 540, "range": 2, "has_world_sprite": true},
	# The live game's own opening pair, at the live game's own prices - the DC-3
	# at 3,000 and the EMB-120 at 5,000. Ours aren't the starter (the 328 Jet
	# is, and the fifteen-minute Zone1 pacing is calibrated on it), so they sit
	# just after it as the first two upgrades you buy.
	{"key": "dc3", "name": "Douglas DC-3", "icon": "dc3_default.png", "price": 3000, "level": 3,
		"force": "C", "seats": 115, "fuel": 18, "range": 2, "has_world_sprite": true},
	{"key": "emb120", "name": "EMB-120", "icon": "emb120_default.png", "price": 5000, "level": 5,
		"force": "C", "seats": 130, "fuel": 21, "range": 2, "has_world_sprite": true},
	{"key": "dhc8", "name": "Dash 8", "icon": "dhc8_default.png", "price": 7000, "level": 8,
		"force": "B", "seats": 110, "fuel": 13, "range": 2, "has_world_sprite": true},
	{"key": "p51", "name": "P-51 Mustang", "icon": "p51_white.png", "price": 8500, "level": 10,
		"force": "A", "seats": 2, "fuel": 10, "ticket": 400, "range": 2, "has_world_sprite": true},
	# Sightseeing, not transport: sixteen seats at a fare seventeen times the
	# flat rate. Slowest class in the game and priced like a joyride.
	{"key": "balloon", "name": "Hot Air Balloon", "icon": "balloon_default.png", "price": 14000, "level": 12,
		"force": "E", "seats": 16, "fuel": 62, "ticket": 130, "range": 2, "has_world_sprite": true},
	{"key": "a318", "name": "Airbus A318", "icon": "a318_default.png", "price": 19000, "level": 15,
		"force": "C", "seats": 180, "fuel": 29, "range": 3, "has_world_sprite": true},
	{"key": "dc6", "name": "Douglas DC-6", "icon": "dc6_default.png", "price": 27000, "level": 20,
		"force": "D", "seats": 240, "fuel": 48, "range": 3, "has_world_sprite": true},
	{"key": "a319", "name": "Airbus A319", "icon": "a319_default.png", "price": 35000, "level": 25,
		"force": "C", "seats": 200, "fuel": 32, "range": 3, "has_world_sprite": true},
	{"key": "tu104", "name": "Tupolev Tu-104", "icon": "tu104_default.png", "price": 40000, "level": 30,
		"force": "C", "seats": 225, "fuel": 36, "range": 3, "has_world_sprite": true},
	{"key": "blackh", "name": "Black Hawk", "icon": "blackh_green.png", "price": 45000, "level": 35,
		"force": "B", "seats": 190, "fuel": 23, "range": 3, "has_world_sprite": true},
	{"key": "b727", "name": "Boeing 727", "icon": "b727_default.png", "price": 65000, "level": 40,
		"force": "C", "seats": 285, "fuel": 46, "range": 3, "has_world_sprite": true},
	{"key": "a300", "name": "Airbus A300", "icon": "a300_default.png", "price": 95000, "level": 45,
		"force": "D", "seats": 390, "fuel": 78, "range": 4, "has_world_sprite": true},
	{"key": "b707", "name": "Boeing 707", "icon": "b707_default.png", "price": 110000, "level": 50,
		"force": "D", "seats": 420, "fuel": 84, "range": 4, "has_world_sprite": true},
	{"key": "dc10", "name": "Douglas DC-10", "icon": "dc10_default.png", "price": 130000, "level": 55,
		"force": "D", "seats": 450, "fuel": 90, "range": 4, "has_world_sprite": true},
	{"key": "airship", "name": "Airship", "icon": "airship_default.png", "price": 150000, "level": 60,
		"force": "E", "seats": 570, "fuel": 137, "range": 4, "has_world_sprite": true},
	# Two seats like the P-51, and the same fare treatment - but S-class, so
	# it's the fastest thing you can buy with cash and the last aircraft that
	# earns on speed rather than capacity.
	{"key": "f15", "name": "F-15 Eagle", "icon": "f15_default.png", "price": 175000, "level": 65,
		"force": "S", "seats": 2, "fuel": 17, "ticket": 860, "range": 4, "has_world_sprite": true},
	{"key": "ufo", "name": "UFO", "icon": "ufo_blue.png", "price": 100, "currency": COINS, "level": 70,
		"force": "S", "seats": 300, "fuel": 24, "range": 5, "has_world_sprite": true},
	{"key": "b787", "name": "Boeing 787", "icon": "b787_default.png", "price": 215000, "level": 75,
		"force": "C", "seats": 525, "fuel": 84, "range": 5, "has_world_sprite": true},
	{"key": "747", "name": "Boeing 747", "icon": "747_default.png", "price": 250000, "level": 80,
		"force": "D", "seats": 725, "fuel": 145, "range": 5, "has_world_sprite": true},
	{"key": "concorde", "name": "Concorde", "icon": "concorde_default.png", "price": 275000, "level": 85,
		"force": "A", "seats": 395, "fuel": 40, "range": 5, "has_world_sprite": true},
	{"key": "a400m", "name": "A400M", "icon": "a400m_white.png", "price": 300000, "level": 90,
		"force": "C", "seats": 680, "fuel": 109, "range": 5, "has_world_sprite": true},
	{"key": "v22", "name": "V-22", "icon": "v22_green.png", "price": 350000, "level": 100,
		"force": "B", "seats": 600, "fuel": 72, "range": 5, "has_world_sprite": true},
	{"key": "ncc1701", "name": "NCC-1701", "icon": "ncc1701_default.png", "price": 150, "currency": COINS, "level": 105,
		"force": "S", "seats": 430, "fuel": 34, "range": 5, "has_world_sprite": true},
	{"key": "an-225", "name": "An-225", "icon": "an-225_default.png", "price": 700000, "level": 110,
		"force": "E", "seats": 1500, "fuel": 360, "range": 5, "has_world_sprite": true},
	# A separate airframe from the 747 above, not a repaint of it - the user's
	# call on the art. Sits between the An-225 and the A380 on the same curve.
	{"key": "b747", "name": "Boeing 747-8", "icon": "b747_default.png", "price": 725000, "level": 120,
		"force": "D", "seats": 1290, "fuel": 258, "range": 5, "has_world_sprite": true},
	{"key": "a380-300", "name": "Airbus A380", "icon": "a380-300_default.png", "price": 750000, "level": 130,
		"force": "D", "seats": 1325, "fuel": 265, "range": 5, "has_world_sprite": true},
	{"key": "ark", "name": "Ark", "icon": "ark_default.png", "price": 250, "currency": COINS, "level": 150,
		"force": "A", "seats": 1000, "fuel": 100, "range": 5, "has_world_sprite": true},
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
	# Coin-priced aircraft ignore the level gate entirely. They're the
	# pay-to-win lane: available from the first minute to anyone willing to
	# spend, rather than something you earn your way to. Their `level` stays in
	# the data as a note of where they'd otherwise sit on the earned ladder,
	# and it's still what orders them in the shop.
	if currency_of(entry_for(key)) == COINS:
		return true
	return Progression.level >= level_for(key)
