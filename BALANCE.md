# Balance

A full pass over the economy, start to finish. Re-measured 2026-08-24 against 59
aircraft, 17 buildings and 10 zones.

**This document replaces an earlier version that was wrong in four places.** The
faults were all in the measuring instrument rather than the game, and they are
listed at the bottom under *What the first pass got wrong* - worth reading
before trusting any number here, because it is the same class of mistake that
would make this pass wrong too.

Everything below is either read out of the live tables or measured by `--bot`,
which drives `Fleet`, `Economy`, `Progression`, `ApronProgress`, `ZoneProgress`
and `BuildingProgress` directly. There is no second copy of the rules.

    godot --headless --path game -- --bot --who casual
    godot --headless --path game -- --bot --who regular
    godot --headless --path game -- --bot --who heavy

**Back up `game/data` first and restore it after.** A bot run is guarded by
`SaveGame.is_bot_run()`, but the guard has been wrong before.

---

## The buy policy decides most of the answers

The bot has two, and they do not play the same game:

    --buying prestige   the dearest thing on the shelf you can afford  (default)
    --buying rate       the best payout per minute of flight

Prestige is what a player does. Rate is an optimiser. Measured on the same
regular profile:

| | prestige | rate |
|---|---|---|
| distinct models flown | **22** | 9 |
| level 70 | 50.0 h | **never reached** |
| final cash | $132M | $1.0M |
| pads | 181 / 181 | 152 |

**The optimiser never finishes the game.** It fills its board with whatever pays
best per minute, which is a level-10 turboprop, and stops levelling. The player
who just buys the biggest thing available reaches the cap at 50 hours with 22
models flown and a hundred-odd million in the bank.

Any statement about this economy has to name which player it is about. The rest
of this document is the **prestige** player unless it says otherwise.

---

## Pacing

| | casual 15 min/day | regular 40 min/day | heavy 120 min/day |
|---|---|---|---|
| all six home zones | 15.0 h (day 60) | 21.3 h (day 32) | 30.0 h (day 15) |
| all 42 city plots | 15.2 h (day 61) | 21.3 h (day 32) | 30.0 h (day 15) |
| **every pad bought** | **15.2 h (day 61)** | **22.0 h (day 33)** | **32.0 h (day 16)** |
| level 70 | 31.8 h (day 127) | 50.0 h (day 75) | 80.0 h (day 40) |
| distinct models flown | 22 | 22 | 24 |
| coins left at the end | 328 | 244 | 229 |
| taps | 51/min | 40/min | 34/min |

**The map is finished in the first third and the levels take the rest.** Zones,
plots and pads are all done between 15 and 32 hours; level 70 arrives at 32 to
80. From that point on there is nothing left to buy but aircraft.

**Playing more costs efficiency.** The cap takes 31.8 h of play for the casual
profile and 80 for the heavy - two and a half times the hours for the same
finish. That is the idle shape working as designed, since long absences do the
flying, but it is steep.

---

## The shape of the income curve

One relationship drives the fleet's economics.

    fare per leg   = seats × ticket × clouds
    leg minutes    = CLOUD_BASE[clouds] + GRADE_STEP × CLASS_STEP[clouds]

    CLOUD_BASE  = [  1,  5, 20,  93, 420 ]   minutes
    CLASS_STEP  = [  1,  3,  8,  22,  60 ]
    GRADE_STEP  = S:0  A:1  B:2  C:3  D:4  E:5

Leg time spans **360×** across the ladder - 2 minutes to 720. Fares over the
same span move **200×**. So income per MINUTE falls as the ladder climbs, and
the level-10 ATR 72 has the best rate in the game at 22,500/h. Nothing beats it.

**That is only decisive for a player who is present continuously.** Rewards do
not stack: an aircraft that lands while you are away waits to be tapped, so an
absent player collects one leg per aircraft however long it took. On that
measure the ladder inverts completely - 750 per tap for the ATR 72 against
150,000 for an Ark or an F-14, a spread of 200×.

Both numbers are correct. They describe different players, and **nothing in the
game tells a player which one they are.** The buildings now name this axis
explicitly (tap-hungry, idle-friendly, population-only); the fleet has the same
axis by accident and does not label it.

---

## Findings

### 1. One aircraft is strictly dominated

| | level | price | $/hour |
|---|---|---|---|
| Airbus A300 | 38 | $160,000 | 1,000 |
| **Concorde** | **48** | **$2,000,000** | **938** |

Twelve and a half times the price of an aircraft ten levels below it, for less
income. Grade C at 5 clouds is a 600-minute leg carrying 250 seats at the
default 15 fare. It is not priced as a trophy; it sits mid-ladder. This reads as
a wrong number rather than a decision.

### 2. A 4x fare cliff at level 50

Aircraft from level 22 to 49 use the default ticket of 15. From 50 up the ticket
is overridden to 85-105.

| | level | fare per leg |
|---|---|---|
| An-225 | 49 | 67,500 |
| **A400M** | **50** | **250,000** |

A 3.7× step in one level, and it is a step in the pricing RULE rather than in
the aircraft. Below the seam the ladder is paced by seats and distance; above
it, by an override.

### 3. The city out-earns the fleet

Rent alone, buildings at max level, tapped every cycle:

| | $/hour each | × 42 plots |
|---|---|---|
| Skypark Resort | 510,017 | **21,420,708** |
| Eiffel Tower | 425,014 | 17,850,590 |
| Office | 286,884 | 12,049,148 |

The regular run grossed **$1.61bn over 93 hours - 17.3M/h** across the whole
fleet. A maxed city is more than that in rent alone, before the popularity
multiplier, which adds up to **+420%** on all flight income at full occupancy.

Rent needs tapping, so it competes for the same constrained resource - but 42
plots against 181 pads wins that contest comfortably.

### 4. The late game has nothing left to spend on

Zones, plots and pads are all finished by hour 32 at the latest. After that the
only sink is aircraft, and the cash curve stops being a curve and starts being a
sawtooth: $136k on day 50, $104M on day 70, $41M on day 120, $219M on day 130,
$132M on day 140. Each spike is money accumulating with nothing to buy; each
drop is one aircraft.

That is not broken - purchases reading as events is the intent - but it means
**the total sink in the game is finite**, and once the board is full, income
above the price of the next aircraft has nowhere to go.

---

## What holds up

- **The coin economy.** Sources measured on the regular run: quests 238,
  building drops 252, daily login 80, milestones 84 - **654 earned**, against a
  410-coin aircraft catalogue, ending 244 clear having bought the lane.
- **Fuel** is 0.4% of income with zero departures blocked on an empty tank.
  Comfortable to the point of being inert - it costs nothing and decides
  nothing.
- **The early ladder**, levels 1-22: paybacks of 2-8 legs, prices rising
  smoothly, something new to buy every other level from 1 to 7.
- **The building archetypes.** Non-dominated choices at a given level went from
  1 to 7 when the sideways set went in.
- **Model variety.** 22-24 distinct aircraft flown across a run. The ladder is
  used.

---

## What the first pass got wrong

Four claims in the previous version did not survive. All four came from trusting
bot output without checking what the bot actually computed, which is worth
stating plainly because it is the failure mode most likely to repeat.

**"Every pad is unreachable."** `_summary` printed four milestones and the
dictionary that filled them held three. `all pads` was never computed, so it
printed "not reached" unconditionally, on every run, at every setting. It is a
real check now and every profile finishes the board between 15 and 32 hours.

**"$80M for a full pad board."** That assumed 16 pads per zone. The real figure
is about **$2.58bn**, almost entirely the Carrier's 32-pad ramp at 1.35
compounding - the last pad alone is near $658M. Still finished by hour 32,
because income by then is far larger than the earlier pass measured.

**"594 coins against a 410 catalogue, ending 139 clear having bought the lane."**
It never bought the lane. `_buy_aircraft` took the first affordable coin
aircraft in catalogue order, which is the Paper Plane at 5 coins, so the bot
re-bought it every time it held five coins and never saved. That is also why
`paperplane` appeared in the top four models of every run ever measured.

**"Zero of 59 aircraft beat a level-10 turboprop", presented as the headline.**
True, and about a player who does not exist. The bot bought on payout-per-minute
because that was its only policy; a player buying the dearest affordable
aircraft flies 22 models and finishes the game. The finding survives as a
statement about *rate*, not as a statement about the ladder being decorative.

---

## If one thing changes

The **cloud and grade time curve**. It produces findings 1 and 2 on its own and
both halves of the rate-versus-tap split. A 5-cloud leg is seven hours before
the grade penalty and the slowest grade doubles it.

Be careful with it. A previous attempt to fix this by making the cloud
multiplier a table - `CLOUD_PAY = [1, 5, 14, 60, 150]` - was simulated and does
work on its own terms: the ATR 72 drops from first to 52nd and model variety
doubles. But late income inflates about 30×, every profile ends with tens of
billions it cannot spend, and pacing halves. Solving the table more gently
(`[1, 4, 13, 39, 114]`) barely moved either, because the runaway is in the
per-aircraft ticket overrides rather than in the band multiplier.

Anything here is worth re-measuring rather than reasoned about. Numbers quoted
to three figures are measurements of one build on one day.
