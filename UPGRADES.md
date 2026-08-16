# Building upgrades

BUILT - the first slice. Numbers below are measured from the code, not settled
balance; the bot has yet to say what they do to a whole playthrough.

## Why this one

The city is **finished about two hours in**, for every kind of player - all 42
plots built, nothing left to do with them. After that it is scenery that pays
rent. That is the earliest wall in the game by a wide margin: zones run to ~36 h,
the fleet ladder to level 50, pads are not exhausted in 90 days.

Upgrades turn a two-hour system into one that runs the whole game. Nothing else
on the list converts as many hours for as little work, and none of it is
art-blocked - an upgraded building can be the same sprite.

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
| 2 | $290 | $8,271 | 6m 58s |
| 5 | $884 | $62,087 | 36m 15s |
| 8 | $2,695 | $174,610 | 1h 24m |
| 10 | **$5,667** | $285,280 | 2h 06m |

More than an Eiffel Tower pays, for about $1.04M and six hours of construction.

Cost rides the building's own price, so a level costs what the building is
worth: **$8,271 on a roadside hotel against $110,275 on an office building**.

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
