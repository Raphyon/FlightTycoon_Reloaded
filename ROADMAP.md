# Roadmap

What we want in the game, what each one actually touches, and what it needs
that does not exist yet.

Ordered roughly by "what does this cost against what does it change", not by
importance. Nothing here is scheduled.

## What we can start today

**Art stopped being the blocker.** This list opened with "there is no unused art
in this project", and for a while that was the whole story: five of the ten
items were waiting on drawings nobody had. Then aircraft started arriving - 14
airframes and 20-odd liveries - and the two items that mattered most moved.

| | needs new art? | |
|---|---|---|
| 1 progress bars | no - drawable in code | **DONE** |
| 9 quests | no - existing board art | **DONE** |
| 2 level-up rewards | no | **DONE** |
| 3 daily login | no | **DONE** |
| 4 boost items | no - the icons are generated | **DONE** |
| 10 extend the ladder | 8 models | **DONE** |
| 5 more models | yes, per model | open - unblocked, and the gaps are ranked |
| 6 more buildings | yes, per building | blocked |
| 7 events | yes, a lot | blocked |
| 8 passenger animations | yes, none exists | blocked |

Building upgrades were on this list as a Known Issue rather than a numbered item
and are DONE - see UPGRADES.md. They were also nearly worthless when first
built, and fixing that is the more useful half of the story.

### What actually shipped, and what it cost

Four things landed that are not numbered items, because nobody thought to want
them until something else made them obvious:

**Upgrades pay coins, not just rent.** A level produced cash and nothing else,
and an Office at 5->6 costs $830,000 to gain $20,140 an hour - 41 hours of never
missing a collection. Level now raises the coin drop chance, and levels 5 and 10
pay a coin on the spot. See UPGRADES.md.

**Airframe levelling is a curve.** It was flat five legs a level, so a model did
all nine level-ups inside its first 45 legs and never moved again. `(n-1)^2` now,
5 legs to 85. That is also what gives the sawtooth teeth - a new model starts at
the cheap end, so a zone unlock hands back a burst of quick levels.

**Depart All is gated at 15.** Worth 6x fewer taps and 4.4 hours over a run, and
the bot had never used it, so every pacing figure in the readme had quietly
assumed the manual path.

**Afterburners**, which nobody asked for on this list but the fighters wanted -
art, a rig, an editor mode, per-nozzle rotation and z-order, four aircraft
placed.

### The bill for all of it

Three coin sources were added in one day. A 90-day run went from 277 coins to
400, against a catalogue costing 293, and that was kept deliberately - see the
readme's coin table. **Every pacing figure in this file was measured while coin
aircraft were rationed.** If a run comes back faster than 32.7 h for the home
zones, that is why.

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

## 2. Level-up rewards for aircraft - DONE

A model level pays **$1,000, flat**, and the claim bubble floats "Level 2!" in
violet when it happens.

Flat because it aims at the early game: 1,000 is real money against a 3,000 DC-3
and quietly nothing against a 7,000,000 Ark, with no taper to tune. Scaling by
the model's price would have done the opposite - the early models ARE the cheap
ones.

The note this section carried was right and was followed: **anything that
multiplies XP moves the level curve, and levels are the only thing that paces
this game.** The reward is on the cash side and 20-day runs at 0, 1,000 and
5,000 a level all finish Zone2 at 0.2-0.3 h.

Levelling is a CURVE now rather than flat - `50 * (n-1)^2` XP, 5 legs for the
first level and 85 for the last, 405 end to end. It was five legs a level flat,
so a model did all nine level-ups inside its first 45 legs and then never moved
again for the rest of the game.

**The find here was not the feature.** A sweep came back with three identical
runs, because `grant_use` re-read its own file on every call and the `--bot`
guard blocks that write - so no bot run had ever levelled an aircraft, and every
pacing figure in this project had been measured with no affinity speed bonus at
all.

---

## 3. Daily login rewards - DONE

Seven tiles, one a day, streak resets if you miss one, and **the panel opens
itself on launch** when a day is owed - a daily you have to go looking for is
not a daily. Day 7 is the one worth coming back for: 3 coins and the largest
cash. Cash rides the quest curve, `level^1.1`.

Same day boundary as the tasks, `floor(now / 86400)`. They must match, or the
game tells the player two different things about what day it is.

**Both clock traps this section predicted were real**, and both come from
`GameClock`'s fast-forward offset not being persisted, so a restart after a
fast-forwarded session moves `now()` BACKWARDS:

  - A streak must not break on it. Losing one to a debug session is the game
    taking something for nothing, so an earlier day counts as the same day.
  - `can_claim` was `today() != last_day`, which ALSO fires when the clock has
    gone back: bank a day, fast-forward, restart, claim it twice. It is
    `today() > last_day` now. A probe caught that, not a reading of the code.

The art note was wrong, though. `login_back@ipad.jpg` is what marked this item
unblocked, but it is a splash illustration - a whole sky of aircraft over the
island - and seven tiles of numbers on it would be unreadable. It is a loading
screen, not a panel frame, and the panel uses the board every other window uses.

It pays **52 coins a run**, the fourth coin source in the game. See the bill at
the top of this file.

---

## 4. Boost items - DONE

Six cards - three auto-turnaround lengths, speed, double cash, free fuel - held
in an inventory, used one at a time, expiring on `GameClock`. Four hook points
in `Fleet`, one line each. Icons from `tools/boost_icons.py`, so this needed no
art anybody had to draw.

**No shop.** Cards come from the daily login, aircraft affinity levels, and
events when those exist. A boost is a windfall for turning up or for flying one
model a lot, not another thing to buy.

### What each is worth, measured

| card | worth |
|---|---|
| **auto-turnaround** | **one hour a day nearly halves the time to DarkZone** - 2.2 h to 1.2 h |
| **speed** | 71% of the fleet qualifies, the fleet gets 26% faster, and it helps the WORST aircraft most - E->A is -33% on a five cloud leg, B->A only -11%, so it is self-limiting by shape |
| **double cash** | fine early, quietly weak late |
| **free fuel** | 1.3% of income. Honest as the commonest drop, a trap as anything you spend a coin on |

Auto-turnaround is the whole balance problem, because taps are the binding
constraint and it removes them WHILE THE PLAYER IS AWAY. What does the damage is
total coverage across a run - tier length times drop rate - so:

| tier | 1 per 7 days | 1 per 30 days | 1 per 45 days |
|---|---|---|---|
| 30 min | 6 h (7%) | 1.5 h (2%) | 1 h (1%) |
| 1 hour | 13 h (14%) | 3 h (3%) | 2 h (2%) |
| **12 hours** | **154 h (171%)** | 36 h (40%) | 24 h (27%) |

against the 90 h that halved DarkZone. **The 12 hour card is granted by nothing
yet** - it is worth twenty-four 30 minute ones and belongs to events at one per
30-45 days. Login plus affinity is about 17 h a run, comfortably inside.

### The sources, both live

**Days 2 and 6 of the login**, which used to hand over FUEL - the two days in
the cycle that gave you nothing you would notice. Two 30 minute cards a week.

**Affinity levels 5 and 10**, the same shape the building milestones use, and
naturally rationed by how much a model actually flies: four models reach level
10 over a 90 day run, so eight cards. Granted per level CROSSED rather than
landed on, since `XP_PER_USE` is a constant somebody will raise.

### Four rules that each cost a bug or nearly did

- **Speed can only ever RAISE a grade.** Lifting "everything below A to A"
  naively drags an S-class down to A - a boost making your best aircraft worse.
- **All three auto-turnaround lengths share ONE timer**, or the 30 minute card
  ending also ends the 12 hour one.
- **Using a running card EXTENDS it**, rather than restarting and throwing away
  whatever was left.
- **A saved timer further out than the longest card could reach is stale**,
  because `GameClock` moves backwards on restart. The daily login hit this twice.

**No toolbar button** - every button on that shelf is art with its own pressed
state and there is none for this. The entry point is one card at the corner of
the screen, there only while you hold something or something is running.

---

## 5. More aircraft models

| | |
|---|---|
| touches | `shop_catalog.gd`, `tools/plane_derive.py`, `tools/sheet_derive.py` |
| needs | ladder respacing; the asset pipeline already handles this |
| art | per model - most of the dump is shop-icon only |

**52 aircraft across levels 1-70** today, up from 36 when this was written.
Seventeen arrived in one stretch, so the sentence this section used to carry -
"the constraint is art, not code, and there is no slack" - stopped being true.

The pipeline is one line per aircraft. `tools/newfleet_derive.py` takes ONE
render, ~1024px with clean alpha and no baked shadow, and produces the world
body, the ground shadow and the shop icon from it. Give it a target sprite
HEIGHT, set by the real airframe's span against the rest of the fleet, and the
width falls out.

Liveries are free after that: any number of aircraft on one sheet, any layout,
cut by connected alpha rather than by assuming a grid. Keep a sheet within ~1%
of the default's aspect - the C-17's ran 2.7-4.9% and costs about 4px of stretch
once pinned to the body.

Placement is still a decision, and there are three ways to make it. **By CLASS**
puts an aircraft next to its contemporaries and changes nothing structural. **By
ZONE** puts it on a gate that had nothing, which is what item 10 was about and
is now finished - every zone opens with an aircraft. **BY GAP** is the one left,
and it is the only one worth ranking, because a gap in the ladder is a stretch
of play with nothing new to buy.

### Where the ladder is actually empty

Level COUNT is the wrong unit and gives the wrong answer. The XP curve is
`n^4.2`, so a level near 70 is worth thousands near the start: levels 1-50 are
24% of the XP needed for 70. The honest measure is what share of a full run each
gap eats.

| gap | levels | share of a run |
|---|---|---|
| **62-65** | 4 | **18.0%** |
| 54-55 | 2 | 5.6% |
| 67 | 1 | 5.3% |
| 60 | 1 | 3.8% |
| 58 | 1 | 3.4% |
| 51 | 1 | 2.3% |
| 40 | 1 | 1.0% |
| everything below 40 | 14 | **1.0% combined** |

**62-65 is a fifth of the game with nothing new to fly.** Four levels, between
the Clipper at 61 and the Hughes H-4 at 66, and they are four of the most
expensive levels in the curve. The whole tail - 51 through 67 - is 38% of a run
across six gaps. That is where models are worth building.

And the reverse, which is the useful half of measuring this: **levels 2-6 are
five consecutive levels with no aircraft and 0.01% of a run.** It is not a
pacing hole at all. It is a first-impressions hole - the shop is thin in the
first minutes, when a player is deciding whether this game has stuff in it - and
that is a real reason to fill it, but not the same reason, and not with the same
urgency.

### Candidates

None of these have art. There is no unused aircraft in `source-assets` - the
last one was the 727, which now flies as the Tu-154 - so each is one render
through `newfleet_derive.py`. The sprite HEIGHT column is the airframe's real
span judged against the fleet, which is the one input the pipeline needs.

**The tail, in priority order:**

| level | candidates | why |
|---|---|---|
| **62-65** | Martin JRM Mars, Saunders-Roe Princess, Beluga XL, 747 Dreamlifter, Super Guppy, Tu-114 | the biggest hole in the game. Dreamland2 is the flying-boat and outsize-freighter tier already; the Princess had ten engines and never entered service, which is exactly the register. The Tu-114 brings contra-rotating props and the rotor rig already handles those |
| 67 | Stratolaunch Roc, Convair XC-99 | sits directly after the H-4. The Roc is the largest wingspan flying TODAY against the largest ever built - a bookend, and the twin fuselage is unlike anything in the fleet |
| 60 | **Dornier Do X**, Blohm & Voss BV 238, Short Empire | the Do X was specced in item 10 and dropped because Dreamland2 already had the Clipper. 60 is the empty slot it actually belonged in |
| 58 | CL-415 / DHC-515, Sikorsky S-42 | joins the Be-200 / US-2 amphibian cluster one tier up |
| 54-55 | Il-76, An-12, Kawasaki C-2, Basler BT-67 | Snow tier, and the Il-76 is the workhorse that register is named after. The BT-67 is a DC-3 on skis, so the proportions are already in the repo |
| 51 | An-22 Antei, C-5 Galaxy | the An-22 is more contra-rotating props; the C-5 sits beside the C-17 and the An-225 |

**The early shop, worth doing but for the other reason:**

| level | candidates | why |
|---|---|---|
| 2-6 | Cessna 208 Caravan, DHC-2 Beaver, Britten-Norman Islander, **An-2** | four cheap small-span sprites where the shop is emptiest at the moment a player is deciding about the game. The An-2 is a biplane, which nothing else in the fleet is |
| 8-12 | Beechcraft 1900D, Let L-410, Saab 340, Dornier 228 | straight commuter turboprops, next to the Twin Otter and the EMB-120 |
| 14, 16 | Fokker 50, BAe Jetstream 31 | 14 is the Zone2 gate and currently arrives between the EMB-120 and the Dash 8 |
| 18-19 | Embraer E175, **BAe 146 / Avro RJ85** | the 146 is a four-engined regional, which reads as odd next to the CRJ in a good way |
| 23-26 | 737-800, Fokker 100, **Comet 4**, Tu-134 | the Comet was the first jetliner and the Tu-104 - already at 27 - was the second, so they cluster by era rather than by size |
| 40 | 767-300, A330-300, Il-96, MD-11 | the one mid-tail gap; a plain widebody fits, no drama needed |

**Not proposed: more coin aircraft.** The coin lane is nine, evenly spaced 1 to
52 at 5 to 60 coins, and it was deliberately respaced to stop them arriving in
clumps. Adding one means respacing the lane and re-measuring the coin economy
against a 345-coin catalogue, which is a balance job rather than an art job.

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

## 9. Quests, as a way to earn coins - DONE

| | |
|---|---|
| touches | new system; `Coins`, `Fleet`, `BuildingProgress`, `Progression` |
| needs | goal types, progress tracking, a claim panel |
| art | a quest panel, goal icons |

**This fixes a measured hole, and the hole is big.** Over 60 hours of play the
bot earned **35 coins**, on top of the 15 you start with. The coin catalogue it
is meant to buy:

| | level | coins |
|---|---|---|
| paperplane | 1 | 5 |
| f15 | 21 | 25 |
| p51 | 25 | 30 |
| uss51 | 29 | 35 |
| balloon | 33 | 40 |
| ufo | 37 | 45 |
| ncc1701 | 42 | 50 |
| x37b | 47 | 55 |
| banshee | 52 | 60 |
| **all nine** | | **345** |

That table is the CURRENT one, not the one this item was written against. The
catalogue was seven aircraft costing 238 when the hole was measured; it is nine
costing 345 now, respaced so the gaps between coin unlocks are even rather than
arriving in two clumps.

Plus liveries and apron skins on top. So a full playthrough earns barely enough
for the paper plane and one mid-tier aircraft, and the Ark - a level 50 unlock -
is out of reach of everything a player can earn in sixty hours.

**What shipped: five daily tasks dealt from a pool, and the coin comes from
finishing the SET rather than from any one task.** One coin per task is a
trickle you collect without noticing; a coin for clearing five is a thing you
sit down to do. Individual tasks pay cash and fuel instead.

Two coins a set, which is measured rather than picked. Three moved a playthrough
to 32.0 h and earned 243 coins, and that is the cliff - it puts most of the
catalogue inside one run. Two keeps the hours and reaches two thirds of the coin
content.

**And the design constraint below was resolved the other way.** Coin aircraft
obey the level gate now (`ShopCatalog.unlocked`), so a coin buys a shortcut past
the CASH rather than past the level, and the 60-hour Ark that could be bought at
level 3 is not a thing that can happen. Everything under it still stands as the
reason the gate went in.

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

REWRITTEN, because most of what it recommended is done. 1, 2, 3, 4, 9 and 10
have all shipped.

**7 - events - is the one that has grown a reason, and is now next.** It was last on this list
because it is art-heavy and wants a settled loop underneath it. It now also owns
the only home for the 12 hour auto-turnaround card, which is the single most
valuable thing in the boost system and is currently granted by nothing at all.

**6** - more buildings - is worth more than its position suggests now that
upgrades pay coins. The city is a real economy rather than a rent trickle, and
it has nine buildings against fifty-two aircraft.

**5** stays open forever by nature, and is no longer blocked in any sense: the
pipeline is one render per aircraft and seventeen arrived in a day. It now
carries a ranked candidate list, and the ranking is measured rather than by
taste - **levels 62-65 are 18% of a run with nothing new to fly**, and the whole
tail above 51 is 38% across six gaps. Anything built for the early shop is worth
doing for how the game LOOKS in the first minutes, not for pacing: levels 2-6
are five empty levels and one hundredth of one percent of a run.

8 last, unchanged: passenger animation is art-blocked outright and there is
nothing in the dump to start from.

---

## 10. Extend the fleet ladder past level 50 - DONE

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

| level | zone | price | aircraft |
|---|---|---|---|
| 52 | Snow | $12M | Antonov An-74 |
| 53 | Snow | $15M | Lockheed LC-130 |
| 56 | Dreamland1 | $25M | Beriev Be-200 |
| 57 | Dreamland1 | $35M | ShinMaywa US-2 |
| 59 | - | $45M | F-16 Fighting Falcon |
| 61 | Dreamland2 | $85M | Boeing 314 Clipper |
| 66 | Dreamland3 | $250M | **Hughes H-4 Hercules** |
| 68 | Carrier | $400M | AV-8B Harrier II |
| 69 | Carrier | $500M | Grumman E-2 Hawkeye |
| 70 | Carrier | $600M | Grumman F-14 Tomcat |

Ten built against the eight specced. The Dornier Do X was dropped - Dreamland2
already had the Clipper - and the F-16 and Harrier were added instead, the
Harrier because it earns the Carrier slot mechanically: `vtol` already existed,
so it leaves a deck straight up.

**DONE, and every zone in the game now opens with an aircraft.** Dreamland3 was
the last gate that arrived as a level number and a bill; the Hughes H-4 closes
it. The Carrier ended up with three, which is what a deck actually runs. Nine of the ten zones now open with something new to
fly; only Dreamland3 at 66 does not, so the H-4 is the one entry that still
changes whether a gate feels like an unlock or a bill. The Do X at 62 is the
last of the nice-to-haves - Dreamland2 already has the Clipper.

### The tail is a SINK, not an investment, and the numbers say so

| | level | pays a leg | price | legs to pay back |
|---|---|---|---|---|
| A400M | 50 | 250,000 | $3.5M | 14 |
| Ark | 50 | 300,000 | $7M | 23 |
| An-74 | 52 | 220,500 | $12M | 54 |
| US-2 | 57 | 250,000 | $34M | 136 |
| Clipper | 61 | 266,000 | $84M | 315 |
| F-14 | 70 | 300,000 | $600M | 2,000 |

Every tail entry pays 220,000-300,000 a leg - AT OR UNDER the Ark, deliberately,
so none of them adds income the pacing has not already measured. What climbs is
the price, by a factor of fifty across the tail. So payback runs from 54 legs to
2,000: the top of the ladder never repays itself and is not meant to. It is
somewhere for a late game measuring $14M a day to put the money.

THE TRAP THIS ALMOST FELL INTO: the first two shipped with no `ticket`, so they
fell back to the flat 15 fare and earned 31,500 a leg - an eighth of the A400M
below them, at three times the price, 380 legs to pay back. Every tail entry
needs an explicit ticket.

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
