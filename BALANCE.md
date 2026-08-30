# Balance

Re-measured 2026-08-30 against 69 aircraft, 17 buildings and 10 zones, after a
fleet rebuild that replaced most of the catalogue's art and a third of its
numbers.

Everything here is either read out of the live tables or measured by `--bot`,
which drives `Fleet`, `Economy`, `Progression`, `ApronProgress`, `ZoneProgress`
and `BuildingProgress` directly. There is no second copy of the rules.

    godot --headless --path game -- --bot --who regular --buying prestige

**Back up `game/data` first and restore it after.** A bot run is guarded by
`SaveGame.is_bot_run()`, but the guard has been wrong before.

---

## What the shop cards say

The card is a 2x2 under the name: **grade, payout, fuel, XP**. It does not print
a seat count and it does not print a fare - the figure beside the money icon is
what a leg pays, and reading it as a fare of 15 had every default-ticket
aircraft in the game paying double for a long time.

    fare           7.5, and per-aircraft wherever a cabin is tiny or the
                   payout does not divide by it
    payout         seats x fare x the ROUTE's clouds
    leg minutes    CLOUD_BASE[clouds] + GRADE_STEP x CLASS_STEP[clouds]

    CLOUD_BASE  = [  1,  5, 20,  93, 420 ]   minutes
    CLASS_STEP  = [  1,  3,  8,  22,  60 ]
    GRADE_STEP  = S:0  A:1  B:2  C:3  D:4  E:5

---

## The three ladders

**Aircraft, cash.** 55 of them, $3,000 to $210,000,000, levels 1 to 70. **24
carry live prices** and the rest are interpolated between them. The top half of
the curve comes from the LOCKED shop pages, which print a level and a price
without naming the aircraft - a price ladder with no models attached, which is
exactly what was needed to place ours.

**Aircraft, coin.** 14 of them, 5 to 400 coins, **1,705 coins for the set**,
reaching level 84. It was 410 with nothing above 65 before the rebuild.

**Zones.** Ten to unlock, each with two prices, because the original sells
roughly every other one for coins:

    Zone2 $50,000/20c      DarkZone $100,000/30c   Forest $500,000/40c
    Desert $1,000,000/50c  Beach $5,000,000/60c    Snow $10,000,000/70c
    Dreamland $50M/100c, $100M/100c, $200M/150c    Carrier $300,000,000/200c

**Pads** cost a flat tenth of their zone, no curve: $500 in Zone1 to
$30,000,000 on the carrier.

---

## Pacing

| | casual 15 min/day | regular 40 min/day | heavy 120 min/day |
|---|---|---|---|
| all six home zones | 6.2 h (day 25) | 12.0 h (day 18) | 22.0 h (day 11) |
| **every pad bought** | **10.2 h (day 41)** | **21.3 h (day 32)** | **38.0 h (day 19)** |
| level at the end | 97 (day 220) | 91 (day 140) | 89 (day 70) |
| distinct models flown | **33** | **32** | 25 |
| zones owned | 8 of 10 | 8 of 10 | 8 of 10 |
| cash left at the end | $10.6M | $7.1M | $32.9M |
| gross | $905M | $783M | $810M |
| taps | 59/min | 44/min | 38/min |

**Playing more still costs efficiency** - 10.2 hours of play to finish the board
casually against 38.0 heavily. That is the idle shape working as designed.

---

## Findings

### 1. Levels still outrun the shelf

Every profile ends between 89 and 97. The shop's last aircraft is at **84**, its
last cash aircraft at 70. The top five to twenty-seven levels buy nothing.

This is the oldest unfixed problem in the document, and it has survived a fare
correction, a zone rebuild and twelve new aircraft. The original's own ladder
runs to at least 92 with a shop that goes with it - its locked pages show
aircraft at 73, 74, 76, 76, 80, 84, 84 and 92, and **five of those slots are
still empty here** for want of art.

### 2. Model variety is the rebuild's clearest win

33 distinct aircraft flown on the casual profile, 32 on regular, against 22-26
before. The catalogue grew from 59 to 69 and the ladder got denser rather than
longer, so more of it is used rather than stepped over.

### 3. The premium short-haul archetype is now deliberate

Three aircraft cost more than a B787 and fly a fraction of the distance:

| | clouds | fare | XP | XP per fare |
|---|---|---|---|---|
| CRJ-700 | 1 | 1,500 | 1,250 | **0.83** |
| C800 | 2 | 2,000 | 1,250 | **0.62** |
| ERJ-170 | 3 | 4,000 | 2,500 | **0.62** |
| B787 | 5 | 3,000 | 300 | 0.10 |

XP is the entire reason to own one. This used to be an accident of the tables;
it is now three aircraft with the same shape, and it is the fleet's answer to
the tap-versus-idle split the buildings label and the aircraft still do not.

### 4. Two zones are never reached

Every profile buys 8 of 10. Dreamland3 at $200M and the Carrier at $300M sit
past the end of a 140-day run. A gate on time rather than on choice, since
nothing else competes for that money.

### 5. The buy policy still decides the game

| | prestige | rate |
|---|---|---|
| distinct models flown | **32** | 12 |
| level at day 140 | **91** | 85 |
| every pad bought | **21.3 h** | 32.0 h |
| gross | **$783M** | $555M |

The optimiser finishes the board now, which it could not before the pad rebuild,
but it flies twelve models to thirty-two and earns a third less.

---

## What holds up

- **The coin economy.** 654 earned across a regular run - quests 250, building
  drops 240, login 80, milestones 84 - against a 1,705-coin shop, ending 74
  clear. The casual run ends on **-1**, having spent the lot.
- **The cash sink.** Runs end on $7M to $33M against $818M before the zone and
  pad rebuild.
- **The lights.** 4.9% to 12.1% of income across the profiles, and a second tap
  loop on the city side that is doing what it was added for.
- **The early ladder** and **the building archetypes**, both untouched.

## What does not

- **Fuel is inert.** 0.2% to 0.5% of income, **zero** departures blocked on an
  empty tank, every profile. A cap on an instantly-refillable stock is a tax
  rather than a constraint.
- **The A380-800's margin is an accident, not a decision.** It tops the rate
  ladder at $46,667/h, which is right - it is the last unlock in the game. But
  it leads the CRJ-700 by four percent, and its grade, cabin, fuel and XP are
  all interpolated: only its level and price are known. The ORDER is intended;
  the size of the gap is a by-product of the interpolation, so retuning the
  CRJ could flip it without anybody deciding to.
- **XP above the last anchor is extrapolated.** Sixteen aircraft carry measured
  XP; the rest are interpolated on price, and past $5,000,000 the curve is a
  slope fitted to points below it.
- **The fare seam at the top.** The A340 pays 4,200 a leg at $15M while the
  A400M pays 50,000 at $18M, because one uses the default 7.5 and the other a
  live 100-a-head override. Same seam as the old level-50 cliff, in a new place.

---

## What earlier passes got wrong

**The fare was 15.** It is 7.5. The comment asserting otherwise claimed every
airliner shows a 15 beside the money icon; the cards show a payout there and no
fare at all.

**The bot called the coin balance "earned".** It printed the closing balance
less the starting float while the four source lines above it added to ten times
that. Fixed - it now prints earned, left, and the size of the shop.

**The pad curve.** 1.35 compounding put the carrier's ramp at $2.58bn on its own
and, once the fare was corrected, stopped the board being finishable. A pad is a
flat tenth of its zone now.

**Zone prices and levels.** Ours ran to $1.9M at level 70; the live ones run to
$300M at level 50. At $300M the cost is the gate and the level is barely one.

---

Anything here is worth re-measuring rather than reasoned about. Numbers quoted
to three figures are measurements of one build on one day.
