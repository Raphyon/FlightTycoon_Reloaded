# Quests

The daily half is BUILT - `scripts/quests.gd`, twelve tasks, `QuestsPanel`, and
a left-edge tab where the reference game puts its DAILY REWARD gift box. The
career ladders below are still a sketch.

The tab is DRAWN IN CODE and is a placeholder: there is no gift-box art in the
dump, nor anything for PURCHASE BONUS or EVENT. Swapping in real art is
replacing one TextureRect and deleting `_draw`.

Numbers here are targets to be measured against `--bot`, not settled balance.

## Why

The coin catalogue is **238 coins** for the seven coin aircraft, before liveries
and apron skins. A sixty-hour playthrough currently earns **35**, on top of the
15 you start with. Seven aircraft, every livery and every skin are authored,
shipped, and unreachable.

Quests are the faucet. They pay for playing rather than for waiting, which a
daily login reward does not.

## Shape

**Daily** - three tasks, drawn from a pool, reset on the `GameClock` day
boundary. Each pays **cash or fuel**. Completing **all three** pays **5 coins**.
The set is the coin faucet; the individual tasks are not.

**Career** - one-off, ordered, visible ahead as a roadmap. Mostly cash and XP.
Coins only at the top of a ladder or on a zone unlock.

Dailies **hold** rather than reroll on a missed day: a missed day should not
destroy a set you were two thirds through.

## The daily pool - built, 12 tasks

Every entry declares a TYPE, and the type decides which signal drives it, so
adding a task is adding a row rather than writing a handler. Several rows can
share a type - `fly_routes` and `fly_far` both count claimed flights, and the
difference lives in the row.

Each also carries a WEIGHT, a multiplier on the reward. Without it every task
paid the same and the set became a hunt for the cheapest row rather than a day's
work. Roughly 1.2-1.3 for things costing a lot of taps or a long leg, 0.6-0.8
for a single purchase. At level 20: `fly_far` pays $140,000, `bulk_fuel`
$65,000.

Targets scale with what the player owns, so "fly 8 routes" is not trivial at 40
aircraft and impossible at 2. `N` below is the scaled figure - the rule is in
Scaling.

### Loop tasks

| task | target | reward |
|---|---|---|
| Fly N routes | 4 x fleet size, capped | cash |
| Earn $N in the air | 3 x one fleet lap | cash |
| Collect rent from N buildings | half the built plots | fuel |
| Refuel N aircraft | fleet size | fuel |
| Have N aircraft in the air at once | 60% of fleet | cash |
| Clear every building with rent waiting | all of them | fuel |
| Fly the <model> twice | a model you own | cash |
| Buy any building | 1 | cash |
| Gain a level today | 1 | cash |

### Tasks that give a dead system a reason

These three are worth more than they look. Both systems below are, measured,
close to inert - and both times the honest fix was a formula change with
knock-on effects. A quest attaches a reason without touching balance, and if it
does not work you delete a table row.

| task | what it rescues |
|---|---|
| Fly to 3 different destinations | **Range.** Routing everything to the nearest destination and to the furthest land 2.4% apart (`--bot --routing near\|far`). The payout formula cannot justify a long leg; a quest can. |
| Buy fuel at $8/unit or less | **The hourly market.** It reprices every hour and nothing rewards timing it. |
| Buy a batch of 500 or more | **The batch multipliers.** Teaches they exist. |

### Deliberately not in the pool

- Anything that asks you to **spend coins** - it fights what quests are for.
- Anything satisfied by waiting rather than playing.
- Visiting the robot airport or a friend.

## The career ladders

Each is a ladder, not a single goal, so the payout spreads across the
playthrough instead of clumping.

| ladder | tiers |
|---|---|
| Buildings owned | 5 / 12 / 25 / 42 |
| Pads owned | 10 / 30 / 60 / 110 |
| Zones opened | one per unlock (6) |
| Level reached | 10 / 20 / 30 / 40 / 50 |
| Aircraft owned | 5 / 15 / 30 / 60 |
| Affinity maxed | 1 / 3 / 6 models |

Cash and XP at every tier. **Coins only at the top of a ladder and on zone
unlocks** - about six payouts of 5, ~30 coins total.

## The coin budget - MEASURED, and the estimate was wrong

Projected ~195 coins from daily sets at "65% completion". The bot, over 90 days
of regular play, completed **10 sets - 50 coins**. Four times less.

| source | projected | measured (`--bot --quests on`) |
|---|---|---|
| start | 15 | 15 |
| building drops | ~35 | 21 |
| daily sets | ~195 | **50** (10 sets) |
| career tops | ~30 | not built |
| **total** | ~275 | **86 against a 238 catalogue** |

The bot is a FLOOR rather than an expectation: it plays its own loop and claims
whatever happens to have completed, where a player nudges their day towards the
three tasks in front of them. But the gap is too big to be only that, and it
points at the pool - several tasks are near-impossible for a given playstyle:

- **fly_far** wants three distinct destinations; a player routing by best cloud
  match flies one destination all day.
- **airborne** wants 60% of the fleet in the air at once, which sequential
  dispatch never reaches.
- **build_one** and **gain_level** stop being possible once the city is full
  and the levels slow down.

So one of three things: raise SET_COIN_REWARD, make the pool more completable,
or accept the catalogue is a long game. Not yet decided - and worth having a
human play a week before choosing, since the bot cannot want anything.

## What the faucet did to pacing

Measured either side, regular player, 90 days:

| | quests off | quests on |
|---|---|---|
| all six homeland zones | 40.7 h | **38.7 h** |
| fleet ladder | 33.3 h | 32.0 h |
| Zone2 | 1.0 h | 0.3 h |
| fuel as share of income | 2.6% | 1.9% |

**It pulls the game forward about 2 hours, 5%.** Small, and it lands inside the
40-hour target - but it is a real movement and it is fastest at the very start
(Zone2 in 0.3 h against 1.0), which is where the cash rewards are largest
relative to what the player has. Worth watching if the pool grows.

## The constraint everything is designed around

**Coin aircraft ignore the level gate.** That is why the starting float went
from 100 to 15 - the old float bought an Ark earning 150x the starter on the
same two-minute hop.

- **No coin payouts below level 10.**
- Career coin payouts sit behind zone unlocks, so coin income tracks progress
  rather than racing ahead of it.
- Measure with `--bot` either side of any change to the faucet. If it pulls the
  fleet ladder forward, that milestone lands earlier and the run will say so.

## Scaling

A fixed target is either trivial or impossible depending on the fleet. Each task
carries a formula rather than a number, evaluated when the day's three are
drawn, then frozen for the day so the goal cannot move under the player.

Rewards scale the same way - cash against level, **fuel flat**. Fuel is worth
most exactly where the game is meanest: the minimum purchase is 50 units at a
+20% premium, which is the early trap in the readme. 50-100 units early is a
real gift and harmless noise later, so it self-balances without a formula.

## What it needs that does not exist

State signals cover most of the career ladders. Nothing today reports an EVENT,
which is what the loop tasks count:

| signal | emitted from |
|---|---|
| `flight_claimed(model, dest, cash)` | `Fleet._grant_reward` |
| `flight_departed(model, dest)` | `Fleet._launch` |
| `rent_collected(plot, amount)` | `BuildingProgress.collect_rent` |
| `fuel_bought(units, unit_price)` | `FuelStore.buy` |

One line each, at a site that already exists.

Already available: `built_changed` (aprons and buildings), `unlocked_changed`,
`level_changed`, `affinity_changed`, `coins_changed`, `map_changed`.

## Shape in code

- `game/scripts/quests.gd`, an autoload. Definitions as `const DAILY_POOL` and
  `const CAREER`, following `ShopCatalog` rather than JSON - the ladders are
  level data, not player data.
- Counters and the day's drawn three live in the autoload, saved in
  `player.json` with everything else.
- `QuestsPanel` on `board_changelist@ipad.png`: three rows with a progress pill,
  a reward chip and a state button, and the gold set-bonus row beneath, locked
  until all three pips are green.

That panel is the machinery daily login and boost items both want later, which
is the other reason to do this one first.

## First slice

The autoload, the four signals, **three** task types, and the panel with claim.
Enough to play a day of it. Widen the pool once the shape is proven.
