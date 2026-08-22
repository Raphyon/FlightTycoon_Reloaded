# Roadmap

What we want in the game, what each one actually touches, and what it needs
that does not exist yet.

Ordered roughly by "what does this cost against what does it change", not by
importance. Nothing here is scheduled.

## What we can start today

**There is no unused art in this project.** `source-assets/buildings` holds 10
PNGs - the shop's 9 buildings plus the terminal. `source-assets/aircraft` holds
3 model folders and the only name without a ladder entry is `p-51mustang`,
which is the known `p51` alias. Everything we have is in the game.

So the split is clean:

| | needs new art? | |
|---|---|---|
| 1 progress bars | no - drawable in code | **DONE** |
| 9 quests | no - existing board art | **DONE** |
| 2 level-up rewards | no - flourish optional | **start now** |
| 3 daily login | no - `source-assets/login/login_back@ipad.jpg` is unused | **start now** |
| 4 boost items | icons, but HUD art could stand in | prototype now |
| 5 more models | yes, per model | blocked |
| 6 more buildings | yes, per building | blocked |
| 7 events | yes, a lot | blocked |
| 8 passenger animations | yes, none exists | blocked |
| 10 extend the ladder | yes, ~8 models | blocked, but specced |

Building upgrades were on this list as a Known Issue rather than a numbered item
and are also DONE - see UPGRADES.md.

---

## 1. Progress bars on the bubbles - DONE

Shipped as three things rather than one:

* **The swoop.** Tapping a claim or a refuel spends two seconds visibly doing
  it - "Claiming", "Refueling" - and the action fires when the BAR FILLS, so
  the two seconds are the transaction rather than a flourish over an outcome
  already decided. It does not block: every other pad stays live, which matters
  because taps are the binding constraint (~34 a minute).
* **The floating amount.** What the action actually did pops off the top of the
  bubble on completion - measured as a before/after delta, so a rent claim that
  also turns up a coin reports both without anything predicting it.
* **The flight tag.** A countdown while the aircraft is in the air, visible only
  while that pad's own menu is open; "Arrived" once it is down, visible unasked
  and tappable to travel. Blue for your own aircraft, green when a friend is
  involved.

Still open: green for aircraft a FRIEND has sent you. There is no notion of
another player's aircraft in Fleet, so only the visiting half is live.

---

## 2. Level-up rewards for aircraft

Affinity levels should give something worth having.

| | |
|---|---|
| touches | `aircraft_affinity.gd`, `HangarPanel.gd` |
| needs | a reward table; the XP and levels already exist |
| art | level-up flourish, optional |

Affinity already tracks XP per model, caps at level 10, and grants 1% speed a
level - so the ladder exists and pays almost nothing. Measured, a maxed model is
10% faster, which is inside the noise of everything else.

This is the cheapest way to add a second progression axis, because the counter
is already running and already saved. Candidates: a cash or XP multiplier on
that model, a fuel discount, a free livery slot at max.

**Note:** anything that multiplies XP will move the level curve, and levels are
the only thing that paces this game. Keep affinity rewards on the cash side, or
measure before and after with `--bot`.

---

## 3. Daily login rewards

| | |
|---|---|
| touches | new autoload; `SaveGame`, `GameClock` |
| needs | a streak counter, a reward table, a panel |
| art | day tiles - but `source-assets/login/login_back@ipad.jpg` is an unused login background |

**Nothing like this exists** - no daily, login or streak anything in the
codebase.

`GameClock.now()` is the right clock to key off, since every wall-clock reader
already goes through it. Two known traps: the fast-forward offset is **not
persisted across restarts**, so a streak keyed off it can be gamed or broken by
a debug session; and `SaveGame` already records `saved_at` and computes elapsed
time on load, which is most of the machinery.

Worth doing for the reason daily rewards exist - they pull lapsed players back -
and this is a game where the hours between sessions are free and doing work.

---

## 4. Boost items

Free-refuel cards, speed boosts, timed multipliers.

| | |
|---|---|
| touches | new autoload; `Fleet`, `FuelStore`, `Coins` |
| needs | an inventory, expiry on the game clock, a UI to hold them |
| art | an icon per boost, an inventory panel |

The nearest existing thing is `ApronSkins` - a permanent flat bonus attached to
a pad. Timed, consumable, inventory-held is new.

Two things make this more interesting than it looks:

- It is a **coin sink**, and coins are currently spent only on aprons, skins,
  liveries and the seven coin aircraft.
- A free-refuel card is worth almost nothing at present, because fuel is 1.3%
  of income (see Known issues in the readme). Boosts want to be attached to
  things that actually bind - taps and time - rather than to fuel. A boost that
  auto-claims a whole airport, or halves flight times for an hour, is worth
  something. A fuel card is not.

---

## 5. More aircraft models

| | |
|---|---|
| touches | `shop_catalog.gd`, `tools/plane_derive.py`, `tools/sheet_derive.py` |
| needs | ladder respacing; the asset pipeline already handles this |
| art | per model - most of the dump is shop-icon only |

36 aircraft across levels 1-50 today. The pipeline for adding one is solid and
documented, and the ladder was respaced once already.

**The constraint is art, not code, and there is no slack.** Every model folder
in `source-assets/aircraft` already has a ladder entry. Most models in the dump
never downloaded their world sprites, so a new entry means deriving one from a
shop icon or authoring it outright. Adding models also stretches the ladder, which moves
pacing - measure with `--bot` after.

---

## 6. More buildings

| | |
|---|---|
| touches | `building_layout.gd`, `PropShopPanel.gd` |
| needs | more entries; the plots already exist |
| art | per building |

**Only 9 building types for 42 plots.** So the city repeats itself nearly five
times over, and every player's airport looks the same.

**Art-blocked, though.** `source-assets/buildings` holds exactly 10 PNGs - the
9 in the shop plus the terminal - so there is nothing waiting to be added. Every
new type is a new sprite, from the dump or from `source-assets/original`.

Once art exists this is the highest ratio of visible change to work on the list.
The city no longer RUNS OUT - plots are gated behind zones (last one at ~38 h)
and carry upgrade levels now - but it still repeats itself, and nine types across
42 plots is why every airport looks the same.

---

## 7. Events with special rewards

| | |
|---|---|
| touches | new system; `Maps`, `Fleet`, `BuildingProgress` |
| needs | a schedule, a goal type, a reward table, a panel |
| art | a lot - event chrome, unique rewards, probably unique models |

The largest item here and the one most gated on art, as noted.

Worth deferring until the loop underneath it is settled: an event is a frame
around the core loop, and the core loop currently has an inert range stat, a
city that runs out in two hours, and an opening move nothing tells you about.
Events amplify whatever they are wrapped around.

---

## 8. Passenger boarding animations

| | |
|---|---|
| touches | `WorldAircraft`, `ApronSlot` |
| needs | a walk cycle along a path, timed to the turnaround |
| art | **none exists** - no passenger or crowd art in the dump at all |

Pure texture, no systems. It would make the two-tap turnaround feel like
something is happening, and there is already a path system (`paths.json`,
`PathEditor`) that road traffic uses, so the machinery for walking a sprite
along a route is in place.

Entirely art-blocked. Nothing in `source-assets/raw` matches passenger, people
or crowd.

---

## 9. Quests, as a way to earn coins

| | |
|---|---|
| touches | new system; `Coins`, `Fleet`, `BuildingProgress`, `Progression` |
| needs | goal types, progress tracking, a claim panel |
| art | a quest panel, goal icons |

**This fixes a measured hole, and the hole is big.** Over 60 hours of play the
bot earned **35 coins**, on top of the 15 you start with. The coin catalogue it
is meant to buy:

| | coins |
|---|---|
| paperplane | 5 |
| f15 | 25 |
| uss51 | 28 |
| balloon | 30 |
| ufo | 35 |
| ncc1701 | 45 |
| ark | 70 |
| **all seven** | **238** |

Plus liveries and apron skins on top. So a full playthrough earns barely enough
for the paper plane and one mid-tier aircraft, and the Ark - a level 50 unlock -
is out of reach of everything a player can earn in sixty hours.

The only faucet today is a per-cycle chance of a single coin from a building.
That is a trickle by design, because coins stand in for IAP - but a premium
currency with no earned path makes seven aircraft, every livery and every skin
into content that is authored, shipped and never seen.

Quests are the natural faucet: they pay out for playing rather than for waiting,
they can be tuned per goal, and unlike a daily reward they scale with how much
the player is actually doing.

**Design constraint worth stating up front:** coin aircraft **ignore the level
gate entirely**. That is why the starting float was cut from 100 to 15 - the old
float bought an Ark that earned 150x the starter on the same 2-minute hop. Any
quest faucet has to be measured against that, or it reopens the same hole. Tie
early quest rewards to cash and XP, and gate coin payouts behind level or
progress that the coin aircraft would otherwise skip.

---

## Also on the table

Not requested - these came out of measurement, and each one is a known problem
with no owner. Listed so they are not lost.

- **Tell the player the opening move.** Filling Zone1's five free pads
  immediately is worth **8x** - Zone2 in 1 hour against 8-9 - and nothing says
  so. Granting two or three aircraft at start makes it happen either way.
- **Building upgrades.** All 42 plots are done at ~2 h for everyone. Upgrades
  are what turn the city back into a system.
- **A percentage-based late-game sink.** Fuel is 1.3% of income and cannot be
  scaled up without breaking the shop. A handling fee or apron upkeep tracks
  revenue on its own.
- **Make range mean something.** Measured, routing to the nearest destination
  and to the furthest land 2.4% apart. Range is the dearest stat on the shop
  card and buys nothing.
- **Build out Dreamland and the Carrier.** Gated at levels 57-70 with nothing
  behind them. This is the honest route to a longer game.

---

## Suggested order

1, 6, 2 first - all cheap, all visible, none of them touch the level curve.

Then **9**, which has the best case of anything on this list: it is the only
item that unlocks content already built and shipping. Seven aircraft, every
livery and every apron skin are currently priced beyond what a sixty-hour
playthrough can earn.

Then 3 and 4 as a pair, since a daily reward wants something to hand you and
boosts want a reason to exist - and both share the inventory and claim-panel
machinery that 9 would build first.

5 whenever art appears. 7 and 8 last: one is art-blocked outright, the other
wants a settled loop underneath it.

---

## 10. Extend the fleet ladder past level 50

The shop stops at level 50, which a regular player reaches at **31 hours**. The
last two unlocks in the game are Dreamland at level 57 (47 h) and the Carrier at
level 70 (93 h), so **62 hours of play sit past the end of the ladder with two
events in them**. The level curve is `n^4.2` - levels 1-50 are only a quarter of
the XP needed for 70 - so those hours are not a mistake, they are simply empty.

Measured, regular player, all three airports:

| | day | play time |
|---|---|---|
| level 50, every aircraft unlocked AND bought | 47 | 31 h |
| all six homeland zones, all 42 plots | 57 | 38 h |
| level 57, Dreamland opens | 70 | 47 h |
| level 70, the Carrier opens | 140 | 93 h |

### The prices are the design

Cash on hand across the tail is not what it looks like:

| day | cash | |
|---|---|---|
| 60-100 | $0.4M - $2.8M | starved: pads, zones and building levels eat everything |
| 110 | $128M | the city is maxed, every existing sink is exhausted |
| 130 | $409M | +$14M a day with nothing to buy |

So the middle of the tail has money PRESSURE and nothing to want, and the end has
money and nothing to spend it on. Expensive aircraft fix both halves - a thing to
save toward while poor, and a sink once rich.

The top of the cash ladder climbs about x1.4 a level ($800k at 45 to $7M at 50).
Continuing that slope to 70 gives $5.6B, four times what the tail earns.
**x1.25 a level** lands right.

### PUT THEM ON THE ZONE UNLOCKS, not at even spacing

REVISED. This section used to space eight entries evenly at 53/56/59/62/65/68.
That was written before the sawtooth was understood, and even spacing is the one
layout that does not produce one.

The game already has a sawtooth and it is already aligned: every zone unlock up
to Beach arrives with new aircraft, and a new model starts at the cheap end of
the affinity curve, so an unlock hands back a burst of quick airframe levels
before the ramp bites again.

| zone | level | models arriving |
|---|---|---|
| Zone2 | 14 | emb120, dhc8 |
| DarkZone | 28 | tu104, a318, balloon, a319 |
| Forest | 36 | blackh, ufo, airship, v22, a300 |
| Desert | 42 | b787, 747, ncc1701, x37b |
| Beach | 48 | a380-300, concorde, an-225, a400m, ark |
| Snow | 53 | **nothing** |
| Dreamland1 | 57 | **nothing** |
| Dreamland2 | 62 | **nothing** |
| Dreamland3 | 66 | **nothing** |
| Carrier | 70 | **nothing** |

So the tail is not just empty of aircraft - it is missing the pattern that
carries the first 48 levels. Eight entries, placed on the teeth:

| level | zone | price | aircraft | |
|---|---|---|---|---|
| 52 | Snow | $12M | **Antonov An-74** | BUILT |
| 53 | Snow | $14M | **Lockheed LC-130** | BUILT |
| 56 | Dreamland1 | $27M | Beriev Be-200 | |
| 57 | Dreamland1 | $34M | ShinMaywa US-2 | |
| 61 | Dreamland2 | $84M | Boeing 314 Clipper | |
| 62 | Dreamland2 | $105M | Dornier Do X | |
| 66 | Dreamland3 | $250M | Hughes H-4 Hercules | |
| 70 | Carrier | $600M | F-14 / E-2 Hawkeye / Harrier | pick one |

### AND MATCH THE AIRCRAFT TO THE ZONE, which is what named them

The zones are not interchangeable backdrops and the aircraft should not be
either. Two holes in a 42-model fleet, found by looking at the maps rather than
the catalogue:

**Dream Land is a water resort** - lagoons, piers, moored boats - and there is
not one flying boat or amphibian in the game. The Twin Otter's floats are the
only nod to water anywhere in the fleet. So Dreamland's four are all boats: the
Be-200 and US-2 are working amphibians, and the Clipper and the Do X are the
golden-age flying boats a resort island is practically asking for. The Do X
carries twelve engines in six push-pull pairs, which reads at sprite size in a
way another airliner does not.

**The Carrier is a real flight deck** - catapults, island, thirty pads - and
there is no naval aircraft at all. Any of the three works; the Harrier earns it
mechanically, because `vtol: true` already exists and it would leave the deck
straight up like the V-22 and the Banshee.

**Snow got the polar pair**, and they are BUILT: the An-74 with its engines
mounted above the wing, and the LC-130 on skis. Neither is another airliner and
both say where they belong at a glance.

Cheapest to draw are the two that are done. The flying boats are the expensive
half of this list - hulls, sponsons, many engines - so if the tail wants filling
quickly, that is worth knowing before starting at the top.

Same count and roughly the same total as the even spacing, but each zone opens
with something new to fly rather than a level number.

Eight entries totalling ~$1.1B against ~$1.3B earned across the tail. You can own
nearly all of them by level 70, but not without choosing an order, and each is a
several-hour goal rather than an instant purchase.

### Stat envelope: ordinary on purpose

**Hold XP per claim near the a400m/Ark tier (roughly 470-670).** XP runs 64 at
the bottom of the ladder to 532 at the top - an 8x climb - and continuing that
curve into 50-70 would raise the XP rate and pull level 70 in from 93 h. The
aircraft added to fill the gap would shorten the gap. The PRICE is what makes
these a goal, so the stats do not have to be.

Seats and range likewise: near the top of what exists, not past it. A 2000-seat
aircraft would double income per pad and undo the pacing twice over - the same
trap the Ark hit when it moved to cash.

### Art is the whole blocker - eight renders

REWRITTEN. This used to say "a shop icon, a world body and shadow
(plane_derive.py takes both from the shop icon)". That was true of the old
pipeline and is not now: the fleet added since - the IL-62, Banshee, A220,
A340-300, A350-900, C-17, 777-300ER - all came through
`tools/newfleet_derive.py`, which takes ONE render and produces the body, the
ground shadow and the shop icon from it.

So what is actually needed is **eight renders**, one per entry, in the same form
every recent aircraft arrived in:

| | |
|---|---|
| size | ~1024px canvas, the aircraft filling most of it |
| alpha | clean, and **no baked shadow** - the ground shadow is derived |
| pose | the fleet's isometric three-quarter: nose down-left, tail up-right |
| where | `source-assets/aircraft/<key>_default.png` |
| then | one line in `newfleet_derive.py` giving the sprite HEIGHT |

Liveries are free after that: any number of aircraft on one sheet, any layout,
as `<key>_liveries.png`. The tool cuts them by connected alpha rather than
assuming a grid, so the cells need not be evenly spaced or the same size. Keep a
sheet within about 1% of the default's aspect - the C-17's ran 2.7-4.9% and
costs about 4px of stretch once pinned to the body.

A prop or rotor strip only if the airframe needs one, and only if its fans are
not already painted into the body - see the Banshee, whose discs are drawn in
and whose spin overlay is generated by `tools/banshee_rotor.py`.

### What this does NOT do

It does not lengthen the game. The 62 hours already exist; this fills them. And
it must not shorten them either, which is what the XP note above is for.

The alternative considered and set aside: lowering the Dreamland and Carrier
gates (they are PLACEHOLDER levels) to land inside the 31-50 window. Free, uses
content that exists, but moves content rather than adding it.
