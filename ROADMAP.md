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
| 2 level-up rewards | no - flourish optional | **start now** |
| 9 quests | no - existing board art | **start now** |
| 3 daily login | no - `source-assets/login/login_back@ipad.jpg` is unused | **start now** |
| 4 boost items | icons, but HUD art could stand in | prototype now |
| 5 more models | yes, per model | blocked |
| 6 more buildings | yes, per building | blocked |
| 7 events | yes, a lot | blocked |
| 8 passenger animations | yes, none exists | blocked |

Four of the nine are pure code against systems that already run. That is the
work available without waiting on anything.

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

| | |
|---|---|
| touches | `ApronSlot.gd`, `BuildingSlot.gd` |
| needs | a bar texture; the timers already exist |
| art | one sprite, maybe two |

The data is all there - `BuildingProgress.is_rent_ready`, an aircraft's
`flight_time_left` - and nothing is drawn from it. There is **no ProgressBar or
TextureProgress anywhere in the project**, so this is the first one.

Do this first. It is the cheapest item on the list and it is the only one that
makes the existing loop more legible rather than adding to it. Callouts are
already the game's whole button vocabulary; giving them a fill is a small change
to a thing the player looks at hundreds of times an hour.

**Watch out for:** the callout is a fixed-position button by deliberate design
(`CALLOUT_LIFT`) - a bar must not make it move or resize per state.

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
It also partially answers a measured problem: all 42 plots are exhausted about two hours
in, for every kind of player, after which the city stops being a system. More
types alone will not fix that - upgrades would - but it makes the two hours less
repetitive.

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
