# Balance

A full pass over the economy, start to finish, measured on 2026-08-24 against 59
aircraft, 17 buildings and 10 zones.

Everything here is either read straight out of the live tables or measured by
`--bot`, which drives `Fleet`, `Economy`, `Progression`, `ApronProgress`,
`ZoneProgress` and `BuildingProgress` directly. There is no second copy of the
rules, so there is nothing to drift. To reproduce:

    godot --headless --path game -- --bot --who casual
    godot --headless --path game -- --bot --who regular
    godot --headless --path game -- --bot --who heavy

**Back up `game/data` first and restore it after.** A bot run is guarded by
`SaveGame.is_bot_run()`, but the guard has been wrong before and a real save is
not worth the risk.

**These numbers go stale the moment a constant moves.** Anything below quoted to
three figures is a measurement, not a target.

---

## Pacing

| | casual 15 min/day | regular 40 min/day | heavy 120 min/day |
|---|---|---|---|
| all six home zones | 19.5 h (day 78) | 33.3 h (day 50) | 42.0 h (day 21) |
| all 42 plots | 19.5 h | 33.3 h | 42.0 h |
| level 70 | 52.0 h (day 208) | 87.3 h (day 131) | 108.0 h (day 54) |
| **every pad** | **never** | **never** | **never** |
| taps | 58/min | 40/min | 42/min |
| coin income | - | 594 | 512 |

**Playing more costs efficiency.** Level 70 takes 52 h of play for the casual
and 108 h for the heavy - twice the hours for the same finish. That is the idle
shape working as intended (long absences do the flying), but it is steep enough
to be worth stating plainly: the heavy player pays double for playing more.

**40-58 taps a minute, sustained.** One tap every 1-1.5 seconds for the whole
session, for a hundred hours. Taps are the binding constraint in this game and
every finding below is downstream of that.

---

## The root cause: leg time outruns fare

One relationship produces most of what is wrong here.

    CLOUD_BASE_MINUTES = [1, 5, 20, 93, 420]     Fleet.gd
    CLASS_STEP_MINUTES = [1, 3, 8, 22, 60]

A 1-cloud A-class leg takes **2 minutes**. A 5-cloud E-class leg takes **720
minutes** - twelve hours. That is a 360x spread in time. Fares over the same
span go from 1,500 to 300,000, a 200x spread. Time wins, so **income per minute
falls as you climb the ladder**.

### Nothing in the game beats the ATR 72

Payout per minute of flight, the metric a present player optimises:

| | level | $/hour | $/tap |
|---|---|---|---|
| **ATR 72** | **10** | **22,500** | 750 |
| Grumman F-14 | 70 | 21,429 | 150,000 |
| F-16 | 59 | 19,643 | 137,500 |
| Ark | 50 | 18,750 | 150,000 |
| Harrier | 68 | 16,875 | 135,000 |
| CRJ-700 | 17 | 15,750 | 2,100 |

**Zero of 59 aircraft have a better $/hour than a level-10 turboprop.** Sixty
levels of ladder above it and not one of them is an upgrade on that measure.

The bot buys purely on payout-per-minute (`_buy_aircraft`, `rate = payout /
mins`), and it shows: across two full runs and 150 hours of simulated play it
flew **four models** - ATR 72, Twin Otter, Paper Plane, DC-3 - for 195,000 legs,
and the other 55 never left a pad.

### But $/tap says the opposite, by 200x

An absent player collects **one leg per aircraft** however long that leg took.
So the metric that matters to a session player is per tap, not per minute:

    ATR 72          750 per tap
    Ark, F-14   150,000 per tap

**The ladder is meaningful after all - under the other metric.** The problem is
not that either number is wrong. It is that they disagree by 200x and **nothing
in the game tells a player which one applies to them.** A player who taps
constantly and a player who checks in twice a day want opposite fleets, and the
shop shows both the same card.

This is the same axis the buildings now have explicitly (TAP / IDLE / CROWD, see
ROADMAP item 6). The fleet has it by accident and does not name it.

---

## Findings, worst first

### 1. Cash peaks, then collapses, in every archetype

| day | regular | heavy |
|---|---|---|
| peak | $57.7M (day 40) | $62.2M (day 20) |
| after | $8.7M (day 50) | $2.0M (day 30) |
| rest of the run | $0.5-3M | $0.5-3.6M |

Every archetype ends the game **permanently broke** - level 70+, 90 days of play
remaining, and between half a million and three million in the bank against a
tail costing $85M to $600M. Level 70 arrives at 87 h with about $2M, and the
F-14 alone is another ~110 h of saving at the observed gross rate.

The tail is documented as a sink rather than an investment, which is a fair
design. What is not intended is that it is a sink **nobody can ever pay into**.

### 2. Every pad is unreachable

`PAD_COST_GROWTH` is 1.35, compounding per pad within a zone, so a 16-pad set
runs from $172k in Zone1 to $20.7M on the Carrier - about **$80M for a full
board**. No archetype finishes, ever. This is most of where the cash in finding
1 goes.

### 3. The Concorde is strictly dominated

| | level | price | $/hour |
|---|---|---|---|
| Airbus A300 | 38 | $160,000 | 1,000 |
| **Concorde** | **48** | **$2,000,000** | **938** |

Twelve and a half times the price of an aircraft ten levels below it, for less
income. It is C-class at 5 clouds - 600 minutes a leg - carrying 250 seats at
the default 15 ticket. It is not priced as a trophy either; it sits mid-ladder.
Either the ticket or the seat count is wrong.

### 4. A 4x income cliff at level 50

Everything from level 22 to 49 uses the default ticket of 15. From 50 up it is
85-105. So:

    An-225      level 49    67,500 a leg
    A400M       level 50   250,000 a leg

A 3.7x step in one level, and it is a step in the *rule*, not in the aircraft.
Below it the ladder is paced by seats and range; above it by an override. The
seam is visible.

### 5. The city out-earns the entire fleet

A maxed city, rent alone, tapped every cycle:

| | rent/hour at level 10 | x42 plots |
|---|---|---|
| Skypark Resort | 510,017 | **21,420,708** |
| Eiffel Tower | 425,014 | 17,850,590 |
| Office | 286,884 | 12,049,148 |

The bot's entire 169-aircraft fleet grossed **5.45M/h**. A maxed city of Skypark
Resorts is four times that in rent, before the popularity multiplier - which is
itself up to **+420%** on all flight cash at 336,000 inhabitants.

Buildings are the real economy and the aircraft are decoration, which is
backwards for an airport game. Rent does need tapping, so it competes for the
same constrained resource - but at 42 plots against 169 pads it wins that
contest comfortably.

---

## What is healthy

**Coins.** Measured income is **594 a run** (regular) and **512** (heavy) -
quests 258, building drops 194, login 80, milestones 62 on the regular run -
against a **410** catalogue, ending 139 clear having bought the lane. The coin
economy is in good shape and the Spirit of St. Louis at 65 did not break it.

An earlier note in `daily_login.gd` puts income at 400 against a 293 catalogue.
That is stale on both halves; this measurement supersedes it.

**Fuel** is 1.6% of income with **zero** departures blocked on an empty tank.
That matches the 1.3% it was designed to be - but it also means the fuel system
currently costs the player nothing and decides nothing.

**The early ladder**, levels 1-22, is clean: paybacks of 2-8 legs, prices rising
smoothly, something new to buy every other level from 1 to 7.

**The building archetypes.** The Pareto frontier over (rent/hour, people, rent
per collection) is 7 by level 50, against 1 before the sideways set went in.

---

## If one thing changes

**The cloud/grade time curve.** `CLOUD_BASE_MINUTES` and `CLASS_STEP_MINUTES`
produce findings 3 and 4 and both halves of the $/hour vs $/tap split. Flattening
the top end - a 5-cloud leg at 420 minutes base is seven hours before the grade
penalty, and E-class doubles it - would make the ladder mean the same thing under
both metrics instead of opposite things.

Everything else on this page is a number. That one is a shape.
