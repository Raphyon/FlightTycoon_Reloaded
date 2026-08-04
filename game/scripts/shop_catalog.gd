class_name ShopCatalog
extends RefCounted

# Every aircraft carries four stats, all four shown on the shop card in a 2x2
# under the name - the same four the original's card shows:
#
#   force   S-E grade, best to worst. Nimbleness, not literal airspeed, and it
#           tracks SIZE: the small early aircraft are A, the jumbos are E.
#           An ADDITIVE step on leg time, not a multiplier - the cloud
#           rating sets the scale (Fleet.CLOUD_BASE_MINUTES).
#   seats   capacity, all of which flies and all of which pays.
#   fuel    units burned per leg, spent out of FuelStore. Flat - the number on
#           the card, whatever the route.
#   xp      experience per leg, and A STAT IN ITS OWN RIGHT - not a function of
#           what the leg pays. The original's DC-3 pays 400 and gives 30; its
#           Paper Plane pays 450 and gives 150. Five times the XP for the same
#           money is the whole reason a 5-coin tutorial aircraft is worth
#           keeping, and no money-derived formula can express it.
#           Only those two are measured. The rest use 30 * rating * sqrt(seats
#           / 50) - anchored on the DC-3, rising with reach and cabin, with
#           capacity under a root so a 900-seat An-225 isn't worth eighteen
#           DC-3s. That shape is ours; replace it as real figures turn up.
#   ticket  per-head fare, and genuinely PER AIRCRAFT rather than a constant
#           with exceptions. 15 is only the common case: the DC-3 charges 8,
#           the A400M charges 100 and the F-15 charges 2000.
#   range   the cloud rating - drawn above the art, and the most important
#           number on the card, because it MULTIPLIES income directly.
#   level   pilot level required to buy it. Coin-priced aircraft ignore this
#           gate completely (see unlocked); their level is shop ordering only.
#
# ----------------------------------------------------------------------
# THESE NUMBERS COME FROM THE LIVE GAME, not from a solve.
#
# Screenshots of the original's shop pages gave verbatim stats for eleven
# aircraft. Where we have a real figure it is used as-is, marked LIVE below.
# Everything else is interpolated onto the pattern those eleven describe.
#
# The previous pass solved capacities backwards from a target income rate,
# against a fare of 8 chosen on the belief that the original's was 4. Its fare
# is 15. Every price here had been halved to compensate for that wrong premise,
# and every seat count inflated - the solve wanted 1325 seats in an A380 that
# really carries 700. Both distortions are gone.
#
# ----------------------------------------------------------------------
# WHAT A LEG PAYS - the original's own formula, confirmed against its A400M
# (100 a head, 500 seats, rating 5, 250,000 a leg):
#
#     ticket * seats * cloud rating
#
# All three are printed on the card. Route distance is NOT in it: the rating is
# the AIRCRAFT'S stat, so a further destination costs time and nothing else.
# That is what makes range the guarded number - a rating-5 aircraft earns five
# times a rating-1 one of the same cabin before capacity is even considered, and
# it is also why the original's ladder looks wrong by income-per-minute (its
# An-140 costs more than its ATR-72 and earns less per minute, but rates three
# clouds against one).
#
# Income rises strictly with every cash unlock, so no purchase is a downgrade.
# TWO deliberate exceptions, and both are the original's rather than ours: the
# Concorde (a trophy) and the Paper Plane (a tutorial).
# ----------------------------------------------------------------------
# TIERS, which is what the levels are laid out by - by aircraft TYPE, not by
# income. An earlier pass ordered purely by rate and ended up with wide-bodies
# below narrow-bodies.
#
#     1-3     novelty and starter
#     4-10    feeder and regional
#     11-25   narrow-body
#     26-36   wide-body and flagship
#
# The whole ladder now ends at 36. It ended at 150, which under our own XP curve
# (Progression, fitted from two live saves) needed 658x the XP of level 32 - 164
# hours with a full apron of the best aircraft in the game. The original's top
# aircraft are all buyable at level 32. The top third of our ladder was content
# nobody would ever see.
const CASH := "cash"
const COINS := "coins"

# has_world_sprite: whether the model has body/shadow art to place on an apron.
# Every entry is true today, so it gates nothing - it stays because it's the
# switch that keeps a model visible in the shop but unbuyable, which the next
# model we get a shop icon for before world art will need again.
const ENTRIES := [
	# ---- 1-3 . novelty and starter ------------------------------------
	# LIVE 3000/A/50 seats/4 fuel/1 cloud, and an 8 FARE - not the 15 the
	# airliners charge. The starter undercuts them per head, which is why its
	# 50 seats and 1 cloud add up to only 400 a leg. It is also the proof that
	# ticket has to be a per-aircraft stat rather than a constant with a few
	# exceptions: the cheap end varies as much as the expensive end does.
	{"key": "dc3", "name": "Douglas DC-3", "icon": "dc3_default.png", "price": 3000, "level": 1,
		"force": "A", "seats": 50, "fuel": 4, "xp": 30, "ticket": 8, "range": 1, "has_world_sprite": true},
	# LIVE 5c/A/10/0/3cl. WEAKER than the starter on purpose - 450 a leg
	# against 750 - but burns NOTHING and rates 3 clouds. It teaches what
	# the rating is worth.
	{"key": "paperplane", "name": "Paper Plane", "icon": "paperplane_default.png", "price": 5, "currency": COINS, "level": 1,
		"force": "A", "seats": 10, "fuel": 0, "xp": 150, "range": 3, "has_world_sprite": true},
	# LIVE 5000/A/80/6/2cl. Carries the NEW badge at level 2 in the
	# original.
	{"key": "emb120", "name": "EMB-120", "icon": "emb120_default.png", "price": 5000, "level": 2,
		"force": "A", "seats": 80, "fuel": 6, "xp": 76, "range": 2, "has_world_sprite": true},
	# ---- 4-10 . feeder and regional -----------------------------------
	{"key": "dhc8", "name": "Dash 8", "icon": "dhc8_default.png", "price": 12000, "level": 4,
		"force": "A", "seats": 120, "fuel": 8, "xp": 93, "range": 2, "has_world_sprite": true},
	# First rating-3 airframe, which is worth more than its cabin: 3x on
	# every leg.
	{"key": "328jet", "name": "328 Jet", "icon": "328jet_blue.png", "price": 25000, "level": 6,
		"force": "S", "seats": 110, "fuel": 10, "xp": 133, "range": 3, "has_world_sprite": true},
	# Two seats, so it earns on fare - the same trick the original uses on
	# its F-15.
	{"key": "p51", "name": "P-51 Mustang", "icon": "p51_white.png", "price": 40000, "level": 8,
		"force": "B", "seats": 2, "fuel": 12, "xp": 18, "ticket": 1100, "range": 3, "has_world_sprite": true},
	{"key": "dc6", "name": "Douglas DC-6", "icon": "dc6_default.png", "price": 55000, "level": 10,
		"force": "C", "seats": 175, "fuel": 25, "xp": 168, "range": 3, "has_world_sprite": true},
	# ---- 11-25 . narrow-body ------------------------------------------
	# LIVE 70000/D/200/30/3cl.
	{"key": "tu104", "name": "Tupolev Tu-104", "icon": "tu104_default.png", "price": 70000, "level": 11,
		"force": "D", "seats": 200, "fuel": 30, "xp": 180, "range": 3, "has_world_sprite": true},
	{"key": "a318", "name": "Airbus A318", "icon": "a318_default.png", "price": 80000, "level": 13,
		"force": "C", "seats": 235, "fuel": 30, "xp": 195, "range": 3, "has_world_sprite": true},
	# LIVE 25c/B/2/20/2000 fare/4cl - two seats at a 2000 fare, verbatim.
	{"key": "f15", "name": "F-15 Eagle", "icon": "f15_default.png", "price": 25, "currency": COINS, "level": 15,
		"force": "B", "seats": 2, "fuel": 20, "xp": 24, "ticket": 2000, "range": 4, "has_world_sprite": true},
	{"key": "a319", "name": "Airbus A319", "icon": "a319_default.png", "price": 90000, "level": 16,
		"force": "C", "seats": 280, "fuel": 32, "xp": 213, "range": 3, "has_world_sprite": true},
	# LIVE 100000/300 seats/4 clouds/35 fuel. The KEY stays "b727" because that
	# is what the art folder and the shop icon are called; the aircraft it
	# actually depicts is the original's Tu-154, so the NAME follows the art.
	# Same split the P-51 already has (shop "p51", sprites "p-51mustang").
	{"key": "b727", "name": "Tupolev Tu-154", "icon": "b727_default.png", "price": 100000, "level": 18,
		"force": "E", "seats": 300, "fuel": 35, "xp": 294, "range": 4, "has_world_sprite": true},
	# The rating-4 threshold.
	{"key": "b707", "name": "Boeing 707", "icon": "b707_default.png", "price": 108000, "level": 19,
		"force": "D", "seats": 320, "fuel": 38, "xp": 304, "range": 4, "has_world_sprite": true},
	# LIVE stats (20c/D/50/10/200 fare/5cl); level and coin price are ours,
	# moved up the coin lane so it doesn't outclass everything cash at level
	# 12.
	{"key": "balloon", "name": "Hot Air Balloon", "icon": "balloon_default.png", "price": 30, "currency": COINS, "level": 20,
		"force": "D", "seats": 50, "fuel": 10, "xp": 150, "ticket": 200, "range": 5, "has_world_sprite": true},
	{"key": "blackh", "name": "Black Hawk", "icon": "blackh_green.png", "price": 115000, "level": 21,
		"force": "B", "seats": 340, "fuel": 40, "xp": 313, "range": 4, "has_world_sprite": true},
	{"key": "airship", "name": "Airship", "icon": "airship_default.png", "price": 122000, "level": 22,
		"force": "E", "seats": 360, "fuel": 45, "xp": 322, "range": 4, "has_world_sprite": true},
	{"key": "ufo", "name": "UFO", "icon": "ufo_blue.png", "price": 35, "currency": COINS, "level": 24,
		"force": "S", "seats": 300, "fuel": 50, "xp": 367, "ticket": 60, "range": 5, "has_world_sprite": true},
	{"key": "v22", "name": "V-22", "icon": "v22_green.png", "price": 130000, "level": 25,
		"force": "B", "seats": 390, "fuel": 48, "xp": 335, "range": 4, "has_world_sprite": true},
	# ---- 26-36 . wide-body and flagship -------------------------------
	# Rating 5 from here on, which is what really makes this a tier.
	{"key": "a300", "name": "Airbus A300", "icon": "a300_default.png", "price": 138000, "level": 26,
		"force": "E", "seats": 320, "fuel": 55, "xp": 379, "range": 5, "has_world_sprite": true},
	{"key": "dc10", "name": "Douglas DC-10", "icon": "dc10_default.png", "price": 145000, "level": 27,
		"force": "E", "seats": 355, "fuel": 60, "xp": 400, "range": 5, "has_world_sprite": true},
	# LIVE 150000/E/400/40/5cl. Burns less than the A300 two tiers below it.
	{"key": "b787", "name": "Boeing 787", "icon": "b787_default.png", "price": 150000, "level": 28,
		"force": "E", "seats": 400, "fuel": 40, "xp": 424, "range": 5, "has_world_sprite": true},
	# LIVE 500000/E/500/70/5cl. The 150k -> 500k jump is the original's own.
	{"key": "747", "name": "Boeing 747", "icon": "747_default.png", "price": 500000, "level": 29,
		"force": "E", "seats": 500, "fuel": 70, "xp": 474, "range": 5, "has_world_sprite": true},
	# LIVE 200 seats / 100 fuel / 5cl; the fare wasn't legible, so 150 is
	# ours.
	{"key": "ncc1701", "name": "NCC-1701", "icon": "ncc1701_default.png", "price": 45, "currency": COINS, "level": 30,
		"force": "A", "seats": 200, "fuel": 100, "xp": 300, "ticket": 150, "range": 5, "has_world_sprite": true},
	{"key": "b747", "name": "Boeing 747-8", "icon": "b747_default.png", "price": 800000, "level": 32,
		"force": "E", "seats": 600, "fuel": 72, "xp": 520, "range": 5, "has_world_sprite": true},
	# LIVE 1000000/E/700/70/5cl.
	{"key": "a380-300", "name": "Airbus A380", "icon": "a380-300_default.png", "price": 1000000, "level": 33,
		"force": "E", "seats": 700, "fuel": 70, "xp": 561, "range": 5, "has_world_sprite": true},
	# LIVE 2000000/C/250/75/5cl - and THE ONE DELIBERATE BREAK in the
	# ladder. Twice the A380's price for a third of its income: 107 legs to
	# pay for itself against the 747's 13. A trophy, not an investment, and
	# it is theirs - kept as priced rather than 'fixed'.
	{"key": "concorde", "name": "Concorde", "icon": "concorde_default.png", "price": 2000000, "level": 34,
		"force": "C", "seats": 250, "fuel": 75, "xp": 335, "range": 5, "has_world_sprite": true},
	{"key": "an-225", "name": "An-225", "icon": "an-225_default.png", "price": 2500000, "level": 35,
		"force": "E", "seats": 900, "fuel": 80, "xp": 636, "range": 5, "has_world_sprite": true},
	# LIVE: 100 a head, 500 seats, rating 5 - 250,000 a leg, the biggest
	# earner in the game. A 100 fare on a military transport is why ticket
	# is a per-aircraft stat and not a constant.
	{"key": "a400m", "name": "A400M", "icon": "a400m_white.png", "price": 3500000, "level": 36,
		"force": "D", "seats": 500, "fuel": 100, "xp": 474, "ticket": 100, "range": 5, "has_world_sprite": true},
	{"key": "ark", "name": "Ark", "icon": "ark_default.png", "price": 70, "currency": COINS, "level": 36,
		"force": "A", "seats": 1000, "fuel": 90, "xp": 671, "ticket": 60, "range": 5, "has_world_sprite": true},
]

# Anything asking for a model we don't have an entry for still gets a flyable
# aircraft rather than one that earns nothing and burns no fuel.
const FALLBACK := {"force": "C", "seats": 50, "fuel": 10, "xp": 30, "range": 1,
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
