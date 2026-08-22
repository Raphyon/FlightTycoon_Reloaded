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
#     novelty and starter
#     feeder and regional
#     narrow-body
#     wide-body and flagship
#
# The whole ladder ends at 50, and every level here is the time-spaced ladder
# scaled by 1.4 alongside the zone gates - see ZoneProgress for why the levels
# rather than the prices are what paces this game.
#
# Stretching the zones without stretching the fleet would have left every
# aircraft owned by level 36 while the Carrier sat at 70, so the back half of
# the game had nothing new to fly. Scaled together, the ladder completes around
# 13 hours in and the last zone around 44 - you finish collecting aircraft about
# a quarter of the way through, and the rest is expansion. That ordering is
# deliberate: the aircraft are the reward, the zones are the long haul.
#
# It once ended at 150, which under the XP curve needed 658x the XP of level 32 -
# 164 hours with a full apron of the best aircraft in the game. The original's
# top aircraft are all buyable at its level 32.
#
# LEVELS ARE SPACED BY TIME, not by tier number. The bands above describe what
# each aircraft IS and still set the ORDER, but the level each one sits at is
# chosen so unlocks arrive at an even rate of PLAY.
#
# They used to run one level apart from 1 to 8, and the XP curve reaches level 8
# in fourteen minutes - so the first eight aircraft all arrived inside the first
# quarter hour, five of them within two minutes, and the level gate did nothing
# but flash on the way past. Measured against tools/econ_sim.py's time-to-level,
# unlocks now run 5 to 12 minutes apart across the whole ladder rather than 0 to
# 22.
#
# The DC-3 stays at 1 because it is GRANTED rather than bought (see
# Fleet.grant_starter), so it needs no gate at all. Coin aircraft keep their
# levels as a note of where they would sit on the earned ladder - unlocked()
# lets them ignore it entirely.
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
	# LIVE stats: A / 100 seats / 20 fuel / 15 fare / 1 cloud. The PRICE is not
	# live - the original charges 40,000 for it, which against 1,500 a leg is a
	# 27-leg payback when every other building and aircraft it sells is about
	# 15. Importing that would have put a strictly-worse aircraft above the
	# EMB-120 in both level and price, which is the one thing this ladder
	# promises never happens. Priced on its own income instead.
	{"key": "atr72", "name": "ATR 72", "icon": "atr72_default.png", "price": 4000, "level": 10,
		"force": "A", "seats": 100, "fuel": 20, "xp": 42, "range": 1, "has_world_sprite": true},
	# NO LIVE DATA - the original doesn't sell a Twin Otter, so every number
	# here is ours. It is the FIRST thing you can buy, two levels ahead of the
	# ATR-72, because the two are a CHOICE rather than a step: the ATR carries
	# 100 for 20 fuel, this carries 60 for 4. Per
	# leg the ATR nets more; per unit of fuel this is five times better, and
	# fuel is what actually grounds a new player - see tools/econ_sim.py, where
	# the only way out of a dead start is an aircraft cheap enough to fly.
	# Priced above the DC-3 because it strictly out-carries it on the same burn;
	# a bigger cabin for the same fuel at a lower price would make the starter
	# aircraft pointless the moment this appeared.
	{"key": "dhc6", "name": "Twin Otter", "icon": "dhc6_default.png", "price": 3500, "level": 7,
		"force": "A", "seats": 60, "fuel": 4, "xp": 36, "range": 1, "has_world_sprite": true},
	# LIVE 5000/A/80/6/2cl. It carries the NEW badge at level 2 in the original;
	# ours sits behind the ATR-72, which goes in ahead of it on income.
	{"key": "emb120", "name": "EMB-120", "icon": "emb120_default.png", "price": 5000, "level": 13,
		"force": "A", "seats": 80, "fuel": 6, "xp": 76, "range": 2, "has_world_sprite": true},
# ---- 4-10 . feeder and regional -----------------------------------
	{"key": "dhc8", "name": "Dash 8", "icon": "dhc8_default.png", "price": 12000, "level": 15,
		"force": "A", "seats": 120, "fuel": 8, "xp": 93, "range": 2, "has_world_sprite": true},
	# Sits between the Dash 8 and the 328 Jet: a bigger cabin than the turboprop
	# without the jet's third cloud, so it is a capacity step rather than a
	# reach one.
	{"key": "crj700", "name": "CRJ-700", "icon": "crj700_default.png", "price": 18000, "level": 17,
		"force": "A", "seats": 140, "fuel": 9, "xp": 100, "range": 2, "has_world_sprite": true},
	# LIVE stats: C / 150 seats / 25 fuel / 15 fare / 2 clouds. Price is ours
	# again - the original's 50,000 would have leapfrogged the 328 Jet, which
	# out-earns it.
	{"key": "an140", "name": "An-140", "icon": "an140_default.png", "price": 21000, "level": 20,
		"force": "C", "seats": 150, "fuel": 25, "xp": 104, "range": 2, "has_world_sprite": true},
	# First rating-3 airframe, which is worth more than its cabin: 3x on
	# every leg.
	{"key": "328jet", "name": "328 Jet", "icon": "328jet_blue.png", "price": 25000, "level": 22,
		"force": "S", "seats": 110, "fuel": 10, "xp": 133, "range": 3, "has_world_sprite": true},
	# Two seats, so it earns on fare - the same trick the original uses on
	# its F-15.
	{"key": "p51", "name": "P-51 Mustang", "icon": "p51_white.png", "price": 27, "currency": COINS, "level": 24,
		"force": "B", "seats": 2, "fuel": 12, "xp": 18, "ticket": 1100, "range": 3, "has_world_sprite": true},
	{"key": "dc6", "name": "Douglas DC-6", "icon": "dc6_default.png", "price": 55000, "level": 25,
		"force": "C", "seats": 175, "fuel": 25, "xp": 168, "range": 3, "has_world_sprite": true},
	# ---- 11-25 . narrow-body ------------------------------------------
	# LIVE 70000/D/200/30/3cl.
	{"key": "tu104", "name": "Tupolev Tu-104", "icon": "tu104_default.png", "price": 70000, "level": 27,
		"force": "D", "seats": 200, "fuel": 30, "xp": 180, "range": 3, "has_world_sprite": true},
	{"key": "a318", "name": "Airbus A318", "icon": "a318_default.png", "price": 80000, "level": 28,
		"force": "C", "seats": 235, "fuel": 30, "xp": 195, "range": 3, "has_world_sprite": true},
	# LIVE 25c/B/2/20/2000 fare/4cl - two seats at a 2000 fare, verbatim.
	{"key": "f15", "name": "F-15 Eagle", "icon": "f15_default.png", "price": 25, "currency": COINS, "level": 21,
		"force": "B", "seats": 2, "fuel": 20, "xp": 24, "ticket": 2000, "range": 4, "has_world_sprite": true},
	{"key": "a319", "name": "Airbus A319", "icon": "a319_default.png", "price": 90000, "level": 29,
		"force": "C", "seats": 280, "fuel": 32, "xp": 213, "range": 3, "has_world_sprite": true},
	# LIVE 100000/300 seats/4 clouds/35 fuel. The KEY stays "b727" because that
	# is what the art folder and the shop icon are called; the aircraft it
	# actually depicts is the original's Tu-154, so the NAME follows the art.
	# Same split the P-51 already has (shop "p51", sprites "p-51mustang").
	# 35.1m span, a hair over the A318 - the small end of the airliner class, so
	# it sits just above the A319 it shares a cabin size with.
	{"key": "a220", "name": "Airbus A220-300", "icon": "a220_default.png", "price": 95000, "level": 30,
		"force": "C", "seats": 290, "fuel": 33, "xp": 250, "range": 4, "has_world_sprite": true},
	{"key": "b727", "name": "Tupolev Tu-154", "icon": "b727_default.png", "price": 100000, "level": 31,
		"force": "E", "seats": 300, "fuel": 35, "xp": 294, "range": 4, "has_world_sprite": true},
	# The rating-4 threshold.
	{"key": "b707", "name": "Boeing 707", "icon": "b707_default.png", "price": 108000, "level": 32,
		"force": "D", "seats": 320, "fuel": 38, "xp": 304, "range": 4, "has_world_sprite": true},
	# Sits with its contemporaries rather than in the tail: four rear-mounted
	# engines, T-tail, 43m span, 900 km/h - a Boeing 707's exact class, so it
	# takes the 707's grade and the rung above it.
	{"key": "il62", "name": "Ilyushin IL-62", "icon": "il62_default.png", "price": 112000, "level": 33,
		"force": "D", "seats": 330, "fuel": 39, "xp": 308, "range": 4, "has_world_sprite": true},
	# LIVE stats: C / 100 seats / 30 fuel / 80 fare / 5 clouds. A saucer, and
	# the coin lane's middle rung - 40,000 a leg against the F-15's 16,000.
	{"key": "uss51", "name": "USS 51", "icon": "uss51_default.png", "price": 28, "currency": COINS, "level": 25,
		"force": "C", "seats": 100, "fuel": 30, "xp": 212, "ticket": 80, "range": 5, "has_world_sprite": true},
	# LIVE stats (20c/D/50/10/200 fare/5cl); level and coin price are ours,
	# moved up the coin lane so it doesn't outclass everything cash at level
	# 12.
	{"key": "balloon", "name": "Hot Air Balloon", "icon": "balloon_default.png", "price": 30, "currency": COINS, "level": 28,
		"force": "D", "seats": 50, "fuel": 10, "xp": 150, "ticket": 200, "range": 5, "has_world_sprite": true},
	{"key": "blackh", "name": "Black Hawk", "icon": "blackh_green.png", "price": 115000, "level": 34,
		"force": "B", "seats": 340, "fuel": 40, "xp": 313, "range": 4, "has_world_sprite": true},
	{"key": "airship", "name": "Airship", "icon": "airship_default.png", "price": 122000, "level": 35,
		"force": "E", "seats": 360, "fuel": 45, "xp": 322, "range": 4, "has_world_sprite": true},
	{"key": "ufo", "name": "UFO", "icon": "ufo_blue.png", "price": 35, "currency": COINS, "level": 34,
		"force": "S", "seats": 300, "fuel": 50, "xp": 367, "ticket": 60, "range": 5, "has_world_sprite": true},
	{"key": "v22", "name": "V-22", "icon": "v22_green.png", "price": 130000, "level": 36,
		"force": "B", "seats": 390, "fuel": 48, "xp": 335, "range": 4, "has_world_sprite": true},
	# ---- 26-36 . wide-body and flagship -------------------------------
	# Rating 5 from here on, which is what really makes this a tier.
	{"key": "a300", "name": "Airbus A300", "icon": "a300_default.png", "price": 138000, "level": 38,
		"force": "E", "seats": 320, "fuel": 55, "xp": 379, "range": 5, "has_world_sprite": true},
	{"key": "dc10", "name": "Douglas DC-10", "icon": "dc10_default.png", "price": 145000, "level": 39,
		"force": "E", "seats": 355, "fuel": 60, "xp": 400, "range": 5, "has_world_sprite": true},
	# LIVE 150000/E/400/40/5cl. Burns less than the A300 two tiers below it.
	{"key": "b787", "name": "Boeing 787", "icon": "b787_default.png", "price": 150000, "level": 41,
		"force": "E", "seats": 400, "fuel": 40, "xp": 424, "range": 5, "has_world_sprite": true},
	# LIVE 500000/E/500/70/5cl. The 150k -> 500k jump is the original's own.
	{"key": "747", "name": "Boeing 747", "icon": "747_default.png", "price": 500000, "level": 42,
		"force": "E", "seats": 500, "fuel": 70, "xp": 474, "range": 5, "has_world_sprite": true},
	# LIVE 200 seats / 100 fuel / 5cl; the fare wasn't legible, so 150 is
	# ours.
	{"key": "ncc1701", "name": "NCC-1701", "icon": "ncc1701_default.png", "price": 45, "currency": COINS, "level": 42,
		"force": "A", "seats": 200, "fuel": 100, "xp": 300, "ticket": 150, "range": 5, "has_world_sprite": true},
	# An unmanned spaceplane: it carries almost nothing, so like the P-51 and
	# the F-15 it earns on fare rather than capacity. Four "seats" at 2000 is
	# the payload, not passengers.
	{"key": "x37b", "name": "X-37B", "icon": "x37b_default.png", "price": 48, "currency": COINS, "level": 43,
		"force": "S", "seats": 4, "fuel": 90, "xp": 42, "ticket": 2000, "range": 5, "has_world_sprite": true},
	# The coin lane's top rung, above the X-37B's 48. A gunship rather than an
	# airliner, so it earns the coin lane's way - few seats, a large ticket -
	# and lands between the X-37B's 40,000 a leg and the NCC-1701's 150,000.
	#
	# NOTE the lane it joins is not internally ordered: the NCC-1701 costs 45
	# coins and pays 150,000, the X-37B costs 48 and pays 40,000. This sits
	# between them rather than papering over that.
	{"key": "banshee", "name": "Banshee", "icon": "banshee_default.png", "price": 50, "currency": COINS, "level": 45,
		"force": "A", "seats": 12, "fuel": 95, "xp": 300, "ticket": 1200, "range": 5, "has_world_sprite": true},
	# 60.3m span, four engines - the top of the airliner class, under the 747s
	# it shares a level band with. Slots into the empty rung at 44.
	# 64.75m span, near enough the 747-8's - a modern widebody, so it lands
	# between the 747 below it and the A340 above.
	{"key": "a350-900", "name": "Airbus A350-900", "icon": "a350-900_default.png", "price": 580000, "level": 43,
		"force": "E", "seats": 530, "fuel": 64, "xp": 490, "range": 5, "has_world_sprite": true},
	# 64.8m span and the longest twinjet there is, so it shares the A340's rung -
	# the same size class, four decades apart - and slots just above it on price.
	{"key": "b777-300er", "name": "Boeing 777-300ER", "icon": "b777-300er_default.png", "price": 700000, "level": 44,
		"force": "E", "seats": 590, "fuel": 68, "xp": 512, "range": 5, "has_world_sprite": true},
	{"key": "a340-300", "name": "Airbus A340-300", "icon": "a340-300_default.png", "price": 650000, "level": 44,
		"force": "E", "seats": 560, "fuel": 66, "xp": 505, "range": 5, "has_world_sprite": true},
	{"key": "b747", "name": "Boeing 747-8", "icon": "b747_default.png", "price": 800000, "level": 45,
		"force": "E", "seats": 600, "fuel": 72, "xp": 520, "range": 5, "has_world_sprite": true},
	# LIVE 1000000/E/700/70/5cl.
	{"key": "a380-300", "name": "Airbus A380", "icon": "a380-300_default.png", "price": 1000000, "level": 46,
		"force": "E", "seats": 700, "fuel": 70, "xp": 561, "range": 5, "has_world_sprite": true},
	# LIVE 2000000/C/250/75/5cl - and THE ONE DELIBERATE BREAK in the
	# ladder. Twice the A380's price for a third of its income: 107 legs to
	# pay for itself against the 747's 13. A trophy, not an investment, and
	# it is theirs - kept as priced rather than 'fixed'.
	# A bigger A400M - 51.7m span against 42.4 - so it sits above it, and takes
	# the A400M's grade because a heavy lifter is what it is.
	{"key": "c17", "name": "C-17 Globemaster III", "icon": "c17_default.png", "price": 1500000, "level": 47,
		"force": "D", "seats": 620, "fuel": 70, "xp": 580, "range": 5, "has_world_sprite": true},
	{"key": "concorde", "name": "Concorde", "icon": "concorde_default.png", "price": 2000000, "level": 48,
		"force": "C", "seats": 250, "fuel": 75, "xp": 335, "range": 5, "has_world_sprite": true},
	{"key": "an-225", "name": "An-225", "icon": "an-225_default.png", "price": 2500000, "level": 49,
		"force": "E", "seats": 900, "fuel": 80, "xp": 636, "range": 5, "has_world_sprite": true},
	# LIVE: 100 a head, 500 seats, rating 5 - 250,000 a leg, the biggest
	# earner in the game. A 100 fare on a military transport is why ticket
	# is a per-aircraft stat and not a constant.
	{"key": "a400m", "name": "A400M", "icon": "a400m_white.png", "price": 3500000, "level": 50,
		"force": "D", "seats": 500, "fuel": 100, "xp": 474, "ticket": 100, "range": 5, "has_world_sprite": true},
	{"key": "ark", "name": "Ark", "icon": "ark_default.png", "price": 7000000, "level": 50,
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


# COIN AIRCRAFT OBEY THE LEVEL GATE, same as everything else.
#
# They used to ignore it - the pay-to-win lane, buyable from the first minute by
# anyone with coins. That one exception distorted the whole economy: with coins
# skipping the ladder, every coin the game handed out bought PROGRESS rather than
# content, and the daily quest faucet had to be held down to 2 a set because 3
# cost four hours of playthrough. It is also what forced the starting float from
# 100 coins to 15, when the old float bought an Ark earning 150x the starter on
# the same two-minute hop.
#
# With the gate applied a coin buys a DIFFERENT aircraft at the point you could
# have afforded one anyway, not an earlier one.
#
# It does NOT make coins free of pacing, which is worth writing down because I
# assumed it did and the bot said otherwise: gated, 2 coins a set against 5 is
# still 32.7 h against 28.0 h to all six zones. A coin aircraft is an aircraft
# you did not spend cash on, and cash is the real constraint through the middle
# of the game.
static func unlocked(key: String) -> bool:
	return Progression.level >= level_for(key)
