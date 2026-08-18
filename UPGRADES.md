# Building upgrades

BUILT - the first slice. Numbers below are measured from the code, not settled
balance; the bot has yet to say what they do to a whole playthrough.

## Why this one

CORRECTION FIRST, because this document and the readme were both built on a
stale number. "The city is finished about two hours in" was measured BEFORE
plots were gated behind zone regions. They are now: a plot cannot be built until
its zone is bought, so the city fills as the zones open and the last plot lands
at **~31 h**, not 2.

So upgrades are not rescuing a two-hour system. What they do is give the city an
arc that continues AFTER the last plot is built - which was still a wall, just a
later one than advertised.

Measured, 90 days of regular play: **412 building levels across the plots, 34 of
42 maxed**. The city is still being improved at the end of the run, where before
it was finished the moment the last zone opened.

And it costs hours rather than saving them: all six zones went 30.7 h -> 32.0 h,
because upgrade money is money not spent on pads and aircraft. That is the right
direction - more to do, and the fleet does not get there faster.

None of it is art-blocked: an upgraded building is the same sprite.

## What exists now

9 building types, one level each, on 42 plots.

| building | rent | cycle | people |
|---|---|---|---|
| roadside_hotel | 200 | 5 min | 200 |
| cafe | 260 | 6 min | 260 |
| residential_building | 320 | 7 min | 320 |
| business_center | 1,600 | 12 min | 2,000 |
| tv_tower | 1,900 | 13 min | 2,500 |
| grand_hotel | 2,100 | 14 min | 3,000 |
| garden_hotel | 2,400 | 15 min | 3,500 |
| office_building | 2,700 | 16 min | 4,000 |
| eifel_tower | 5,000 | 20 min | 8,000 |

## The shape

Every built plot carries a **level**. Upgrading costs cash, takes **time**, and
raises what the building pays.

The time is the point. A building already has a rent cycle, so the machinery is
there - and an upgrade that takes twenty minutes is a thing you come back to
rather than a thing you buy. It is the same reason the claim swoop takes two
seconds instead of none.

**Max level 10.** High enough to run the whole game against a cost curve that
outpaces income, low enough that a plot has a finish line.

## The numbers, as built

Rent x1.45 a level, cost `price x 0.6 x level^2.2`, time `2 min x level^1.8`.
A roadside hotel, the cheapest thing on the board:

| level | rent | this level cost | build time |
|---|---|---|---|
| 1 | $200 | - | - |
| 2 | $290 | $8,300 | 7m |
| 5 | $884 | $62,000 | 35m |
| 8 | $2,695 | $170,000 | 1h 30m |
| 10 | **$5,667** | $290,000 | 2h |

Costs and times both go through `NiceNumber`, because a curve does not produce
figures anybody would choose - these were $8,271 and 6m58s before.

More than an Eiffel Tower pays, for about $1.04M and six hours of construction.

Cost rides the building's own price, so a level costs what the building is
worth: **$8,300 on a roadside hotel against $110,000 on an office building**.

**A coin building upgrades with coins.** The Eiffel Tower's price is 30 COINS,
so running it through the cash curve produced a figure derived from coins and
charged in dollars - the best building in the game, at 5,000 a cycle, reached
level 10 for $2,800 while a roadside hotel wanted $290,000.

Its own curve is far gentler, because coins are scarce - a playthrough earns
150-260 and the aircraft catalogue alone is 243:

| level | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|
| coins | 5 | 10 | 15 | 20 | 20 | 25 | 30 | 30 | 35 |

About 190 coins to max, which is meant to be a real choice against buying an
aircraft rather than a formality.

## THE THING THAT WILL BREAK IF WE ARE NOT CAREFUL

**Popularity multiplies flight cash, and it is uncapped.**

    popularity = 1 + total_people / 80,000

A full city of Eiffel Towers today is 336,000 people - **+420% on every flight
the fleet makes**, a 5.2x multiplier on the entire air economy. That is already
the largest single number in the game.

If upgrades raise `people` the way they raise rent, a fully upgraded city is
1.28M people and **+1,600%**, a 17x multiplier on flight income. The fleet
economy would stop meaning anything and every pacing number we have measured
would be void.

**DECIDED: upgrades raise rent only.** Population stays a property of WHAT you
built, not how far you have taken it. The city's economy and the fleet's grow
separately, which is how they work today, and no pacing number already measured
is invalidated.

## AND A LEVEL RAISES THE COIN CHANCE

ADDED AFTER PLAYING IT. The verdict from the table above was "upgrading is
essentially worthless", and measuring said that was right - and structural
rather than a tuning problem.

An upgrade produced exactly ONE thing: more cash. `coin_chance_for()` read only
the building's cycle minutes, so level was not in it, and rent has never paid
XP - only flight claims do. So a level bought cash, and cash is the resource the
late game already has too much of.

Payback on one level, assuming you collect EVERY cycle:

| building | level | cost | +rent/hr | payback |
|---|---|---|---|---|
| Coffee House | 3->4 | $20,000 | $2,270 | 8.8 h |
| Office | 3->4 | $270,000 | $9,579 | 28 h |
| Office | 5->6 | $830,000 | $20,140 | **41 h** |

41 hours of perfect collection, on a game that reaches level 70 in 93. Nobody
taps 42 buildings on cycle, so the real figure is worse.

**Population was the obvious fix and is the wrong one.** Popularity multiplies
FLIGHT cash, so scaling it with level makes upgrades produce more of the same
abundant currency - and it is the most dangerous number in the game, uncapped
and applied to every flight. A live save sits at x2.40 today. See the section
below, which still stands.

So level raises the COIN chance instead, because coins are what is actually
scarce - the catalogue is 243 and a run earns 150-260 - and buildings already
supplied about 40% of them, just blind to level.

`COIN_LEVEL_BONUS = 0.15`, so level 10 is 2.35x level 1. Measured over 90 days:

| bonus | level 10 | building coins | share of all coins |
|---|---|---|---|
| 0.00 | x1 | 98, 107, 118, 122 | ~40% |
| **0.15** | **x2.35** | **161, 162** | **~49%** |
| 0.35 | x4.15 | 248 | ~60%, total income +50% |

All six home zones finished at 19.3-19.7 h in every run, because coins do not
gate zones - XP does. The city gets a purpose and the ladder does not move.

### And a one-off at levels 5 and 10

The chance bonus alone is a PORTFOLIO effect: one office going 5->6 moves its
own odds by 0.002 a collection, which nobody can feel. What they would feel is
the city as a whole paying out faster - true, but not legible.

So reaching **level 5 or level 10 pays a coin on the spot**, on the building you
just upgraded, and the confirmation window promises it before you commit rather
than springing it afterwards.

Sizing them meant taking some economy back out of the drip. Totals over 90 days,
all coins from all sources, against a 243-coin catalogue:

| chance bonus | milestones | total coins | |
|---|---|---|---|
| 0.00 | none | ~277 | the old game - a level bought nothing |
| 0.15 | none | 327 | all of it invisible |
| 0.15 | 5:1, 10:2 | 411 | coins stop being scarce |
| 0.15 | 5:1, 10:1 | 381 | |
| **0.08** | **5:1, 10:1** | **323** | **shipped** |

The last row is the point: it lands the same total economy as 0.15 with no
milestones, but a chunk of it arrives as a payout you can see. **Drops carry the
economy, milestones carry the feedback.**

Milestones get their own signal rather than borrowing `coin_found`. They can
fire from inside a rent collection - `collect_rent` reads `rent_at`, which reads
`level_at`, which settles a finished upgrade - so anything telling the two apart
by when they arrive would be wrong.

## What it needs

| | |
|---|---|
| touches | `building_progress.gd`, `building_layout.gd`, `BuildingInfoPanel`, `BuildingSlot` |
| data | a level per plot in the save: `{"key": ..., "since": ..., "level": N}` |
| art | **none** - an upgraded building is the same sprite |

The save already stores a dictionary per plot, so a `level` field slots in with
old saves defaulting to 1.

**Under construction** wants the flight tag we already built: a bubble with a
countdown, "Upgrading", and the progress bar. `ProgressBubble.show_status` takes
exactly that, so `BuildingSlot` shows a timer the same way an apron does.

Demolition refunds half - that has to count what was spent on **upgrades** too,
or a maxed plot becomes a trap.

## Decided

- **A building does not earn while upgrading.** Taking it out of service is the
  cost of improving it, which makes starting one a real decision rather than a
  free click - and makes upgrading the whole city at once something you feel.
- **Per plot, not a global queue.** A rich player can have the whole city under
  scaffolding; the limit is money, not a slot.
- **Cost scales with the building's tier.** An Eiffel Tower level costs more
  than a cafe level, or the cheap buildings would be the efficient upgrade and
  the expensive ones a trap.

## First slice

Level on the plot, cost and time curves, upgrade from `BuildingInfoPanel`, and
the countdown on the slot. Rent only, no population change - measure, then
decide whether population should move at all.
