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
	# EVERY PRICE IS A ROUND NUMBER - one or two significant digits and zeros for
	# cash, a multiple of five for coins. Eighteen cash prices and seven coin
	# prices moved to get there.
	#
	# The obstacle was not rounding, it was CROWDING. Eight aircraft sat between
	# 108,000 and 150,000, which needs five thousand steps to keep apart, and
	# nothing that fine reads as round: 108k and 112k both want to be 110k. The
	# first attempt let an algorithm snap each to the nearest nice figure and
	# push collisions up a rung, which cascaded - the 787 came out at $1,000,000
	# against its $150,000, +567%, and everything above it moved with it.
	#
	# So the packed band was spread by hand instead, 110/120/130/140/150/160/
	# 180/200, and nothing else moved more than a third. Same shape, round
	# numbers, and a 90 day run is unchanged: 19.7 h for the home zones, Zone2
	# at 0.2 h, DarkZone at 2.2 h.
	#
	# The coin lane going 293 -> 345 is a happy side effect rather than the
	# point. A run earns about 400, so the spare at the end drops from 107 to 55
	# - which pulls the coin economy back toward the scarcity it was measured
	# with, without touching a single coin SOURCE.
	#
	# THE COIN LANE IS SPACED, and was not. Four of the nine sat inside eight
	# levels (21, 24, 25, 28) and three more inside four (42, 43, 45), so most of
	# the lane arrived in two clumps with long nothing either side. It runs on a
	# 4-5 level step now: 1, 21, 25, 29, 33, 37, 42, 47, 52.
	#
	# The Banshee moving 45 -> 52 does a second job: coin aircraft stopped at 45
	# while the cash ladder runs to 70, so the whole tail had no coin option at
	# all. It now opens Snow alongside the An-74 and the LC-130.
	#
	# The 20 level gap from the Paper Plane to the F-15 is deliberate and stays:
	# you start with 15 coins and the Paper Plane costs 5, so the early game has
	# its one coin purchase and then has to earn the next.
	{"key": "paperplane", "name": "Paper Plane", "icon": "paperplane_default.png", "price": 5, "currency": COINS, "level": 1,
		"force": "A", "seats": 10, "fuel": 0, "xp": 150, "range": 3, "has_world_sprite": true},
	# NO LIVE DATA - the original doesn't sell a Twin Otter, so every number
	# here is ours. It is three levels ahead of the ATR-72, because the two are a CHOICE rather than a step: the ATR carries
	# 100 for 20 fuel, this carries 60 for 4. Per
	# leg the ATR nets more; per unit of fuel this is five times better, and
	# fuel is what actually grounds a new player - see tools/econ_sim.py, where
	# the only way out of a dead start is an aircraft cheap enough to fly.
	# Priced above the DC-3 because it strictly out-carries it on the same burn;
	# a bigger cabin for the same fuel at a lower price would make the starter
	# aircraft pointless the moment this appeared.
	# LEVELS 2-6 WERE FIVE EMPTY LEVELS - the shop said nothing between the
	# granted DC-3 and the Twin Otter at 7, which is the first minutes of the
	# game and the thinnest the catalogue ever looks. This is a first-impressions
	# fix and not a pacing one: the whole stretch is 0.01% of a run.
	#
	# THREE OF THEM, at 2, 4 and 6, so the opening offers something every other
	# level instead of a cluster and then silence. The Ju 52 was at 4 on its own
	# and moved to 6 for that spacing - it is the biggest of the three and now
	# sits next to the Twin Otter it hands over to.
	#
	# The ramp is by SIZE, which is what a player actually sees buying up the
	# early shop: 72px, 75, 79, then the Otter's 84. Not by date - the DC-3 is
	# 1935 and granted, so chronology was already broken before these arrived.
	#
	# Pay per leg steps 520 / 650 / 770 between the granted DC-3's 400 and the
	# Twin Otter's 900, so each is a real step up without reaching past the next
	# thing you can buy.
	{"key": "an2", "name": "Antonov An-2", "icon": "an2_default.png", "price": 3050, "level": 2,
		"force": "A", "seats": 40, "fuel": 4, "xp": 31, "ticket": 13, "range": 1, "has_world_sprite": true},
	{"key": "trimotor", "name": "Ford Trimotor", "icon": "trimotor_default.png", "price": 3200, "level": 4,
		"force": "A", "seats": 50, "fuel": 4, "xp": 33, "ticket": 13, "range": 1, "has_world_sprite": true},
	{"key": "ju52", "name": "Junkers Ju 52", "icon": "ju52_default.png", "price": 3350, "level": 6,
		"force": "A", "seats": 55, "fuel": 4, "xp": 35, "ticket": 14, "range": 1, "has_world_sprite": true},
	{"key": "dhc6", "name": "Twin Otter", "icon": "dhc6_default.png", "price": 3500, "level": 7,
		"force": "A", "seats": 60, "fuel": 4, "xp": 36, "range": 1, "has_world_sprite": true},
	# LIVE stats: A / 100 seats / 20 fuel / 15 fare / 1 cloud. The PRICE is not
	# live - the original charges 40,000 for it, which against 1,500 a leg is a
	# 27-leg payback when every other building and aircraft it sells is about
	# 15. Importing that would have put a strictly-worse aircraft above the
	# EMB-120 in both level and price, which is the one thing this ladder
	# promises never happens. Priced on its own income instead.
	{"key": "atr72", "name": "ATR 72", "icon": "atr72_default.png", "price": 4000, "level": 10,
		"force": "A", "seats": 100, "fuel": 20, "xp": 42, "range": 1, "has_world_sprite": true},
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
	{"key": "an140", "name": "An-140", "icon": "an140_default.png", "price": 20000, "level": 20,
		"force": "C", "seats": 150, "fuel": 25, "xp": 104, "range": 2, "has_world_sprite": true},
	# First rating-3 airframe, which is worth more than its cabin: 3x on
	# every leg.
	{"key": "328jet", "name": "328 Jet", "icon": "328jet_blue.png", "price": 25000, "level": 22,
		"force": "S", "seats": 110, "fuel": 10, "xp": 133, "range": 3, "has_world_sprite": true},
	# Two seats, so it earns on fare - the same trick the original uses on
	# its F-15.
	{"key": "p51", "name": "P-51 Mustang", "icon": "p51_white.png", "price": 30, "currency": COINS, "level": 25,
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
	{"key": "b707", "name": "Boeing 707", "icon": "b707_default.png", "price": 110000, "level": 32,
		"force": "D", "seats": 320, "fuel": 38, "xp": 304, "range": 4, "has_world_sprite": true},
	# Sits with its contemporaries rather than in the tail: four rear-mounted
	# engines, T-tail, 43m span, 900 km/h - a Boeing 707's exact class, so it
	# takes the 707's grade and the rung above it.
	{"key": "il62", "name": "Ilyushin IL-62", "icon": "il62_default.png", "price": 120000, "level": 33,
		"force": "D", "seats": 330, "fuel": 39, "xp": 308, "range": 4, "has_world_sprite": true},
	# LIVE stats: C / 100 seats / 30 fuel / 80 fare / 5 clouds. A saucer, and
	# the coin lane's middle rung - 40,000 a leg against the F-15's 16,000.
	{"key": "uss51", "name": "USS 51", "icon": "uss51_default.png", "price": 35, "currency": COINS, "level": 29,
		"force": "C", "seats": 100, "fuel": 30, "xp": 212, "ticket": 80, "range": 5, "has_world_sprite": true},
	# LIVE stats (20c/D/50/10/200 fare/5cl); level and coin price are ours,
	# moved up the coin lane so it doesn't outclass everything cash at level
	# 12.
	{"key": "balloon", "name": "Hot Air Balloon", "icon": "balloon_default.png", "price": 40, "currency": COINS, "level": 33,
		"force": "D", "seats": 50, "fuel": 10, "xp": 150, "ticket": 200, "range": 5, "has_world_sprite": true},
	{"key": "blackh", "name": "Black Hawk", "icon": "blackh_green.png", "price": 130000, "level": 34,
		"force": "B", "seats": 340, "fuel": 40, "xp": 313, "range": 4, "has_world_sprite": true},
	{"key": "airship", "name": "Airship", "icon": "airship_default.png", "price": 140000, "level": 35,
		"force": "E", "seats": 360, "fuel": 45, "xp": 322, "range": 4, "has_world_sprite": true},
	{"key": "ufo", "name": "UFO", "icon": "ufo_blue.png", "price": 45, "currency": COINS, "level": 37,
		"force": "S", "seats": 300, "fuel": 50, "xp": 367, "ticket": 60, "range": 5, "has_world_sprite": true},
	{"key": "v22", "name": "V-22", "icon": "v22_green.png", "price": 150000, "level": 36,
		"force": "B", "seats": 390, "fuel": 48, "xp": 335, "range": 4, "has_world_sprite": true},
	# ---- 26-36 . wide-body and flagship -------------------------------
	# Rating 5 from here on, which is what really makes this a tier.
	{"key": "a300", "name": "Airbus A300", "icon": "a300_default.png", "price": 160000, "level": 38,
		"force": "E", "seats": 320, "fuel": 55, "xp": 379, "range": 5, "has_world_sprite": true},
	{"key": "dc10", "name": "Douglas DC-10", "icon": "dc10_default.png", "price": 180000, "level": 39,
		"force": "E", "seats": 355, "fuel": 60, "xp": 400, "range": 5, "has_world_sprite": true},
	# LIVE 150000/E/400/40/5cl. Burns less than the A300 two tiers below it.
	{"key": "b787", "name": "Boeing 787", "icon": "b787_default.png", "price": 200000, "level": 41,
		"force": "E", "seats": 400, "fuel": 40, "xp": 424, "range": 5, "has_world_sprite": true},
	# LIVE 500000/E/500/70/5cl. The 150k -> 500k jump is the original's own.
	{"key": "747", "name": "Boeing 747", "icon": "747_default.png", "price": 500000, "level": 42,
		"force": "E", "seats": 500, "fuel": 70, "xp": 474, "range": 5, "has_world_sprite": true},
	# LIVE 200 seats / 100 fuel / 5cl; the fare wasn't legible, so 150 is
	# ours.
	{"key": "ncc1701", "name": "NCC-1701", "icon": "ncc1701_default.png", "price": 50, "currency": COINS, "level": 42,
		"force": "A", "seats": 200, "fuel": 100, "xp": 300, "ticket": 150, "range": 5, "has_world_sprite": true},
	# An unmanned spaceplane: it carries almost nothing, so like the P-51 and
	# the F-15 it earns on fare rather than capacity. Four "seats" at 2000 is
	# the payload, not passengers.
	{"key": "x37b", "name": "X-37B", "icon": "x37b_default.png", "price": 55, "currency": COINS, "level": 47,
		"force": "S", "seats": 4, "fuel": 90, "xp": 42, "ticket": 2000, "range": 5, "has_world_sprite": true},
	# The coin lane's top rung, above the X-37B's 48. A gunship rather than an
	# airliner, so it earns the coin lane's way - few seats, a large ticket -
	# and lands between the X-37B's 40,000 a leg and the NCC-1701's 150,000.
	#
	# NOTE the lane it joins is not internally ordered: the NCC-1701 costs 45
	# coins and pays 150,000, the X-37B costs 48 and pays 40,000. This sits
	# between them rather than papering over that.
	{"key": "banshee", "name": "Banshee", "icon": "banshee_default.png", "price": 60, "currency": COINS, "level": 52,
		"force": "A", "seats": 12, "fuel": 95, "xp": 300, "ticket": 1200, "range": 5, "has_world_sprite": true},
	# THE TOP OF THE COIN LANE, and the first entry added to it since it was
	# respaced. APPENDED rather than inserted: the other nine step 4-5 levels and
	# 5 coins, and inserting would have shifted every one of them. 57 and 65
	# continues both steps exactly.
	#
	# It earns the lane's way - few seats, an enormous ticket - because a seat on
	# the aeroplane that crossed the Atlantic alone is not an airline fare. Pays
	# 18,000 a leg against the Banshee's 14,400, five levels below it.
	#
	# B, not A. It is a 1927 monoplane that cruised at 100mph, and the lane has
	# never been ordered by grade anyway - the UFO is S at 45 coins and the
	# Banshee A at 60. The ticket is what makes it worth owning.
	#
	# READ THIS BEFORE ADDING ANOTHER: at 65 coins the coin catalogue goes from
	# 345 to 410, against a run that earns about 400. Owning every coin aircraft
	# in one playthrough was deliberate - see the note in daily_login.gd - and
	# this ends it. That is the point of a trophy at the top of the lane, but it
	# IS a reversal, and it was made on purpose rather than by drift.
	{"key": "spirit", "name": "Spirit of St. Louis", "icon": "spirit_default.png", "price": 65, "currency": COINS, "level": 57,
		"force": "B", "seats": 6, "fuel": 70, "xp": 320, "ticket": 3000, "range": 5, "has_world_sprite": true},
	# 60.3m span, four engines - the top of the airliner class, under the 747s
	# it shares a level band with. Slots into the empty rung at 44.
	# 64.75m span, near enough the 747-8's - a modern widebody, so it lands
	# between the 747 below it and the A340 above.
	{"key": "a350-900", "name": "Airbus A350-900", "icon": "a350-900_default.png", "price": 600000, "level": 43,
		"force": "E", "seats": 530, "fuel": 64, "xp": 490, "range": 5, "has_world_sprite": true},
	# 64.8m span and the longest twinjet there is, so it shares the A340's rung -
	# the same size class, four decades apart - and slots just above it on price.
	{"key": "b777-300er", "name": "Boeing 777-300ER", "icon": "b777-300er_default.png", "price": 800000, "level": 44,
		"force": "E", "seats": 590, "fuel": 68, "xp": 512, "range": 5, "has_world_sprite": true},
	{"key": "a340-300", "name": "Airbus A340-300", "icon": "a340-300_default.png", "price": 700000, "level": 44,
		"force": "E", "seats": 560, "fuel": 66, "xp": 505, "range": 5, "has_world_sprite": true},
	{"key": "b747", "name": "Boeing 747-8", "icon": "b747_default.png", "price": 900000, "level": 45,
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

	# PAST LEVEL 50, and the first aircraft that are. Both open Snow, and both
	# are polar rather than more airliners - a zone should arrive with something
	# that belongs to it. See ROADMAP item 10.
	#
	# Stats are deliberately ORDINARY: XP near the A400M's 474, seats and range
	# inside what already exists. The PRICE is what makes these a goal. Push the
	# XP and the aircraft added to fill 62 hours would shorten the 62 hours.
	# EVERY TAIL ENTRY CARRIES A TICKET, and the first two shipped without one -
	# which meant they fell back to the flat 15 fare and earned 31,500 a leg
	# against the A400M's 250,000, while costing three times as much. 380 legs
	# to pay back against fourteen. Nobody would have bought either.
	#
	# The band is 220,000-300,000 a leg, at or under the Ark's 300,000, so the
	# tail adds no income the pacing has not already seen. PRICE is the ladder
	# here, not payout - these are sinks for a late game that measures $14M a
	# day with nothing to spend it on.
	{"key": "an74", "name": "Antonov An-74", "icon": "an74_default.png", "price": 12000000, "level": 52,
		"force": "D", "seats": 420, "fuel": 55, "xp": 476, "ticket": 105, "range": 5, "has_world_sprite": true},
	{"key": "lc130", "name": "Lockheed LC-130", "icon": "lc130_default.png", "price": 15000000, "level": 53,
		"force": "D", "seats": 470, "fuel": 60, "xp": 484, "ticket": 100, "range": 5, "has_world_sprite": true},
	# Dreamland's boats. The island is a water resort and the fleet had no
	# flying boat or amphibian in it - see ROADMAP item 10.
	{"key": "be200", "name": "Beriev Be-200", "icon": "be200_default.png", "price": 25000000, "level": 56,
		"force": "D", "seats": 480, "fuel": 58, "xp": 492, "ticket": 100, "range": 5, "has_world_sprite": true},
	{"key": "us2", "name": "ShinMaywa US-2", "icon": "us2_default.png", "price": 35000000, "level": 57,
		"force": "D", "seats": 500, "fuel": 60, "xp": 500, "ticket": 100, "range": 5, "has_world_sprite": true},
	# A fighter in the tail. 9.96m span, so the smallest thing here after the
	# Paper Plane, and priced as a trophy like everything past 50.
	{"key": "f16", "name": "F-16 Fighting Falcon", "icon": "f16_default.png", "price": 45000000, "level": 59,
		"force": "S", "seats": 10, "fuel": 66, "xp": 560, "ticket": 5500, "range": 5, "has_world_sprite": true},
	{"key": "b314", "name": "Boeing 314 Clipper", "icon": "b314_default.png", "price": 85000000, "level": 61,
		"force": "E", "seats": 560, "fuel": 64, "xp": 530, "ticket": 95, "range": 5, "has_world_sprite": true},
	# LEVELS 62-65 WERE THE BIGGEST HOLE IN THE GAME: four levels between the
	# Clipper and the H-4, and 18% of a whole run, because the XP curve is n^4.2
	# and a level up here is worth thousands near the start. Two aircraft cannot
	# fill four levels, so they go where they split the stretch most evenly BY
	# TIME rather than by level number - 63 and 65, which cuts it 37/41/22.
	#
	# Both are D where the flying boats around them are E. That is the reason to
	# buy one: the tail was otherwise a straight line of E-class haulers.
	# THE ELDEST OF THE THREE, and it opens Dreamland2. Placed at 62 rather than
	# at 64 - the marginally bigger gap - so the tier runs in the order the idea
	# was invented: Super Guppy 1965, Beluga 1994, Dreamlifter 2006. At 64 it
	# would have sat BETWEEN the other two, which is three whales in three
	# levels and one joke told three times.
	#
	# E where they are D. It is the propeller ancestor, so the tier has a shape
	# inside it rather than three identical haulers.
	{"key": "guppy", "name": "Super Guppy", "icon": "guppy_default.png", "price": 100000000, "level": 62,
		"force": "E", "seats": 590, "fuel": 66, "xp": 545, "ticket": 92, "range": 5, "has_world_sprite": true},
	{"key": "beluga-xl", "name": "Airbus Beluga XL", "icon": "beluga-xl_default.png", "price": 120000000, "level": 63,
		"force": "D", "seats": 620, "fuel": 68, "xp": 570, "ticket": 90, "range": 5, "has_world_sprite": true},
	{"key": "dreamlifter", "name": "Boeing Dreamlifter", "icon": "dreamlifter_default.png", "price": 180000000, "level": 65,
		"force": "D", "seats": 660, "fuel": 72, "xp": 600, "ticket": 88, "range": 5, "has_world_sprite": true},
	# DREAMLAND3'S, and the last gate in the game to get an aircraft. The
	# largest wingspan ever built, so it is the largest sprite here too.
	{"key": "h4", "name": "Hughes H-4 Hercules", "icon": "h4_default.png", "price": 250000000, "level": 66,
		"force": "E", "seats": 700, "fuel": 74, "xp": 620, "ticket": 85, "range": 5, "has_world_sprite": true},
	# The Carrier's third, and the one that earns its slot mechanically - a
	# Harrier leaves a deck straight up, and vtol already exists.
	{"key": "harrier", "name": "AV-8B Harrier II", "icon": "harrier_default.png", "price": 400000000, "level": 68,
		"force": "A", "seats": 12, "fuel": 70, "xp": 640, "ticket": 4500, "range": 5, "has_world_sprite": true},
	# The Carrier's other half. A Tomcat and a Hawkeye is the pair a deck
	# actually runs, and it gives the Carrier two entries the way Snow and
	# Dreamland1 have two - one zone, one aircraft was the thinnest tooth here.
	{"key": "e2", "name": "Grumman E-2 Hawkeye", "icon": "e2_default.png", "price": 500000000, "level": 69,
		"force": "D", "seats": 25, "fuel": 68, "xp": 650, "ticket": 2300, "range": 5, "has_world_sprite": true},
	# The Carrier's, and the top of the game. Twenty seats at a premium fare
	# rather than a cabin full - it lands on the Ark's 300,000 a leg either way,
	# and a Tomcat with 900 seats in it would read as a joke.
	{"key": "f14", "name": "Grumman F-14 Tomcat", "icon": "f14_default.png", "price": 600000000, "level": 70,
		"force": "S", "seats": 20, "fuel": 70, "xp": 660, "ticket": 3000, "range": 5, "has_world_sprite": true},
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
