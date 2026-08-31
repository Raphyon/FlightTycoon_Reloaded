# Balance

Re-measured 2026-08-31 against 69 aircraft, 17 buildings and 10 zones, after a
fleet rebuild that replaced most of the catalogue's art and a third of its
numbers - and after the bot stopped disagreeing with itself.

**A RUN IS NOW REPRODUCIBLE, AND IT WAS NOT WHEN THIS DOCUMENT WAS LAST
MEASURED.** `--seed` fixed the global RNG, but `GameClock.now()` was the system
clock, and the hourly fuel market and the daily quest draw both seed themselves
off it - so a run also inherited the wall-clock moment it was launched at. The
clock is pinned under `--bot` now (`GameClock.BOT_EPOCH`). **Both halves are
required**: pass `--seed` for anything you intend to compare, because the lights
still roll off the global RNG. With both, two runs are byte-identical apart from
the wall-time line; every figure below was measured that way, and the previous
pass's were one sample of a distribution nobody knew was there.

Everything here is either read out of the live tables or measured by `--bot`,
which drives `Fleet`, `Economy`, `Progression`, `ApronProgress`, `ZoneProgress`
and `BuildingProgress` directly. There is no second copy of the rules.

    godot --headless --path game -- --bot --who regular --buying prestige --seed 1234

`--epoch <unix seconds>` moves the pinned instant, which is how to ask whether a
result survives a different starting hour - deliberately, one run against
another, rather than having the clock decide it for you.

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
| all six home zones | 7.0 h (day 28) | 14.0 h (day 21) | 24.0 h (day 12) |
| all 42 city plots | 7.0 h (day 28) | 14.0 h (day 21) | 24.0 h (day 12) |
| top of the shelf (level 84) | 19.5 h (day 78) | 40.7 h (day 61) | 54.0 h (day 27) |
| **every pad bought** | **never - 152 of 184** | **never - 152 of 184** | **never - 150 of 184** |
| level at the end | 93 (day 220) | 89 (day 140) | 94 (day 70) |
| distinct models flown | **29** | **30** | 27 |
| zones bought | 8 of 10 | 8 of 10 | 8 of 10 |
| cash left at the end | $138.4M | $45.7M | $14,899 |
| gross | $1,020M | $791M | $917M |
| lights, share of income | 11.4% | 9.7% | 12.2% |
| taps | 59/min | 43/min | 40/min |

**Playing more still costs efficiency** - 19.5 hours of play to reach the top of
the shelf casually against 54.0 heavily. That is the idle shape working as
designed.

**The pads row is not a typo, and it used to be.** It read "every pad bought" at
10-38 hours because the check compared pads built against the pads on the maps
owned AT THAT MOMENT, which goes true the first time the homeland fills. Against
the real 184-pad board no profile finishes, and the 32 missing are the Carrier's
- see finding 4.

---

## Findings

### 1. Levels still outrun the shelf

Every profile ends between 89 and 94. The shop's last aircraft is at **84**, its
last cash aircraft at 70. The top five to ten levels buy nothing - narrower than
the previous pass reported, and still the same fault.

This is the oldest unfixed problem in the document, and it has survived a fare
correction, a zone rebuild and twelve new aircraft. The original's own ladder
runs to at least 92 with a shop that goes with it - its locked pages show
aircraft at 73, 74, 76, 76, 80, 84, 84 and 92, and **five of those slots are
still empty here** for want of art.

### 2. Model variety is the rebuild's clearest win

30 distinct aircraft flown on the regular profile, 29 casual, 27 heavy, against
22-26 before the rebuild. The catalogue grew from 59 to 69 and the ladder got
denser rather than longer, so more of it is used rather than stepped over. (The
33/32 the previous pass quoted was measured on the unpinned clock; the win is
real, a little smaller than it looked.)

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

### 4. One zone is never reached - the Carrier

Every profile buys 8 of 10, and the previous pass read that as Dreamland3 and
the Carrier both sitting past the end of a run. Only half of that is true.
**Dreamland2 opens Dreamland1 and Dreamland3 with it** (`ZoneProgress.OPENED_BY`),
so all 42 dreamland pads get bought even though those two never appear in the
ledger. The arithmetic settles it: every profile stops at 152 pads of 184, and
184 - 152 is exactly the Carrier's 32.

So the gate is one zone at $300,000,000, and it is a gate on time rather than on
choice, since nothing else competes for that money. Two of the three "unbought"
zones are a bookkeeping artifact; the third is the end of the game.

### 5. The buy policy still decides the game

| | prestige | rate |
|---|---|---|
| distinct models flown | **30** | 11 |
| level at day 140 | **89** | 88 |
| all six home zones | **14.0 h** | 18.0 h |
| top of the shelf | **40.7 h** | 50.0 h |
| pads at the end | **152** | 139 |
| gross | **$791M** | $637M |

The optimiser gets close on level now, which it could not before the pad
rebuild, but it flies eleven models to thirty, reaches the top of the shelf nine
hours later and earns a fifth less. Note how little separates them on level and
how much on everything else: the ladder is no longer the thing the buy policy
decides.

---

## What holds up

- **The coin economy.** 658 earned across a regular run - quests 278, building
  drops 216, login 80, milestones 84 - against a 1,705-coin shop, ending 73
  clear. Casual earns the most (795) and heavy the least (577), and both the
  heavy and the rate runs end on **-3** and **-2**, having spent the lot. Three
  of the four land within a hundred coins of zero, which is a faucet sized
  against its sink about as well as it can be.
- **The lights.** 9.7% to 12.2% of income across the profiles - 14.7% on the
  rate run - and a second tap loop on the city side that is doing what it was
  added for.
- **The early ladder** and **the building archetypes**, both untouched.

## What does not

- **Fuel is inert.** 0.3% to 0.8% of income, and across four full runs exactly
  **one** aircraft-pass was ever blocked on an empty tank. A cap on an
  instantly-refillable stock is a tax rather than a constraint. (The previous
  pass said zero every profile; the one is the regular run, and it is the same
  finding.)
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

**The bot did not agree with itself.** `--seed` fixed the global RNG and was
believed to be the whole story - its own comment said two runs then differed
only by what was being tested. They did not: `GameClock.now()` was the system
clock, and the fuel market and the daily quest draw seed off it, so a run also
inherited the hour it was launched at. Everything above this line in earlier
passes was one sample. Pinned now, and `--seed` is still needed alongside it.

**"Every pad bought."** The check compared pads built against the pads on the
maps owned AT THAT MOMENT, so it went true the first time the homeland filled
and was quoted as a finished board at 10-38 hours. No profile finishes the real
184; every one stops at the Carrier.

---

Anything here is worth re-measuring rather than reasoned about. Numbers quoted
to three figures are measurements of one build - but no longer of one *day*:
with the clock pinned and `--seed` passed, re-running the command at the top of
this document on an unchanged tree reproduces every figure in it exactly. If two
runs of one config ever disagree again, something has started reading the system
clock.
