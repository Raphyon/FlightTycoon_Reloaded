# Balance

Re-measured 2026-08-28, after the shop, the zones and the pads were all rebuilt
on figures read off the original game. **Every number in the previous version is
superseded**, and the reason is at the bottom under *What the second pass got
wrong* - it is one arithmetic error that had been doubling the fare since the
day it was written.

Everything here is either read out of the live tables or measured by `--bot`,
which drives `Fleet`, `Economy`, `Progression`, `ApronProgress`, `ZoneProgress`
and `BuildingProgress` directly. There is no second copy of the rules.

    godot --headless --path game -- --bot --who regular --buying prestige

**Back up `game/data` first and restore it after.** A bot run is guarded by
`SaveGame.is_bot_run()`, but the guard has been wrong before.

---

## What the shop cards actually say

The card is a 2x2 under the name: **grade, payout, fuel, XP**. It does not print
a seat count and it does not print a fare. The figure beside the money icon is
what a leg pays.

That was read as a fare of 15 for a long time. Three airliners whose cabins we
already had settle it - Tu-104 200 seats against a 1500 card, Tu-154 300/2250,
B787 400/3000 - and all three come out at **7.5 a head**, exactly half.

    fare           7.5, and per-aircraft where a cabin is tiny
    payout         seats x fare x the ROUTE's clouds
    leg minutes    CLOUD_BASE[clouds] + GRADE_STEP x CLASS_STEP[clouds]

    CLOUD_BASE  = [  1,  5, 20,  93, 420 ]   minutes
    CLASS_STEP  = [  1,  3,  8,  22,  60 ]
    GRADE_STEP  = S:0  A:1  B:2  C:3  D:4  E:5

---

## The three ladders

**Aircraft, cash.** 46 of them, $3,000 to $210,000,000, levels 1 to 70. Fifteen
carry live prices; the rest are interpolated between them. The top half of the
curve comes from the LOCKED shop pages, which print a level and a price without
naming the aircraft - a price ladder with no models attached, which is exactly
what was needed to place ours.

    L1 $3,000   L15 $40,000   L25 $70,000   L34 $150,000   L45 $15,000,000
    L53 $24,000,000   L58 $80,000,000   L70 $210,000,000

**Aircraft, coin.** 13 of them, 5 to 400 coins, **1,625 coins for the set**. It
was 410 before today, with nothing above 65.

**Zones.** Ten to unlock, and each has TWO prices - the original sells roughly
every other one for coins, and both columns were photographed.

    Zone2 $50,000/20c      DarkZone $100,000/30c   Forest $500,000/40c
    Desert $1,000,000/50c  Beach $5,000,000/60c    Snow $10,000,000/70c
    Dreamland $50M/100c, $100M/100c, $200M/150c    Carrier $300,000,000/200c

**Pads** cost a flat tenth of their zone, with no curve: $500 in Zone1 up to
$30,000,000 on the carrier.

---

## Pacing

| | casual 15 min/day | regular 40 min/day | heavy 120 min/day |
|---|---|---|---|
| all six home zones | 6.5 h (day 26) | 11.3 h (day 17) | 24.0 h (day 12) |
| **every pad bought** | **11.5 h (day 46)** | **18.7 h (day 28)** | **42.0 h (day 21)** |
| level at the end | 90 (day 220) | 98 (day 140) | 95 (day 70) |
| distinct models flown | 24 | 26 | 24 |
| zones owned | 8 of 10 | 8 of 10 | 8 of 10 |
| cash left at the end | $9.0M | $15.6M | $8.8M |
| gross | $861M | $1.02bn | $709M |
| taps | 64/min | 47/min | 33/min |

**Playing more still costs efficiency** - 11.5 h of play to finish the board
casually against 42.0 h heavily, the idle shape working as designed.

---

## Findings

### 1. Levels outrun the shelf

Every profile ends between 90 and 98. The shop's last aircraft is at **84**, and
its last cash aircraft at 70. So the top ten to twenty-eight levels buy nothing
at all.

This is the same shape as the old "nothing left to spend on", moved from money
to levels. The original's own ladder runs to at least 92 with a shop that goes
with it - its locked pages show aircraft at 73, 74, 76, 76, 80, 84, 84 and 92.
Ours stops early because seven of the models on those pages have no art.

### 2. Two zones are never reached

Every profile buys 8 of 10. Dreamland3 at $200M and the Carrier at $300M sit
past the end of a 140-day run. That is a real gate rather than a broken one -
but nothing else is competing for that money, so it is a gate on time, not on
choice.

### 3. The premium short-haul aircraft is also the best money in the game

The CRJ-700 - the original's C400, 1 cloud, A grade, bought for XP - turns out
to pay **$45,000/h**, the highest rate on the ladder, ahead of the F-14's
$42,857/h at seven hundred times the price. A 2-minute leg with a full fare and
no cloud penalty is simply the best throughput available.

It was flagged as a risk when it went in and the measurement confirms it. It
only bites a player who is present continuously, which is the same tap-versus-
idle split the buildings label and the fleet still does not.

### 4. The buy policy still decides the game

| | prestige | rate |
|---|---|---|
| distinct models flown | **26** | 11 |
| level at day 140 | **98** | 86 |
| every pad bought | **18.7 h** | 31.3 h |
| gross | **$1.02bn** | $507M |

The optimiser now finishes the board, which it could not do this morning, but
it flies eleven models to twenty-six and earns half as much.

---

## What holds up

- **The coin economy, now that it is measured properly.** 682 earned across a
  run - quests 240, building drops 278, login 80, milestones 84 - against a
  1,625-coin shop, ending 77 clear. Earned, spent and available are finally the
  same order of magnitude.
- **The cash sink.** Runs end on $9M to $16M against $818M before the zone and
  pad rebuild. Money is spent as fast as it arrives.
- **Model variety.** 24 to 26 distinct aircraft flown, up from 22.
- **The early ladder** and **the building archetypes**, both untouched today.

## What does not

- **Fuel is still inert.** 0.2% to 0.6% of income, **zero** departures blocked
  on an empty tank, in every profile. It costs nothing and decides nothing, and
  a cap on an instantly-refillable stock is a tax rather than a constraint.
- **XP above the last anchor is extrapolated, not measured.** Sixteen aircraft
  carry live XP; the other 43 are interpolated on price, and past $5,000,000
  the curve is a slope fitted to points below it. The F-14's 190,000 is the
  least trustworthy number in this document.

---

## What the second pass got wrong

**The fare was 15.** It is 7.5, and every default-ticket aircraft in the game
had been paying double since the comment claiming otherwise was written. The
comment said "every airliner on every page shows a 15 beside the money icon";
the cards show a payout there, and no fare at all.

**The bot called the coin balance "earned".** It printed the closing balance
less the starting float - coins LEFT - while the four source lines directly
above it added to ten times the figure. That is what made the previous pass
call the coin economy comfortable at "654 earned, 244 clear" when the real
question was whether there was anything to spend it on. Fixed; it now prints
earned, left, and the size of the shop.

**The pad curve.** 1.35 compounding put the carrier's ramp at $2.58bn on its
own and, once the fare was corrected, stopped the board being finishable at
all. A pad is a flat tenth of its zone now.

**Zone prices and levels.** Ours ran to $1.9M at level 70; the live ones run to
$300M at level 50. The old note on that table said levels pace the game and
costs do not. At $300M the cost is the gate and the level is barely one.

---

Anything here is worth re-measuring rather than reasoned about. Numbers quoted
to three figures are measurements of one build on one day.
