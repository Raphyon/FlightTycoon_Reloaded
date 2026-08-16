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

**Daily** - FIVE tasks dealt, reset on the `GameClock` day boundary. Each pays
cash or fuel. Completing **any three** pays **2 coins**, and one **swap** a day
trades a row you do not fancy for another.

Five-deal-three is what makes the set robust: the coin needs three, so when it
needed all three of three, a single row the player could not or would not do
cost the whole day. Now a bad row is something you skip rather than something
that ends your day, and which three you chase is a decision where there was
none.

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

## The coin budget

Five tasks are dealt and any three earn the coin, plus one swap a day for a row
you do not fancy. Measured over 90 days of regular play: **150 coins** from the sets.

The catalogue is 238, so about two thirds of the coin content is reachable in a
long playthrough and the rest is a real choice - which is the fit worth having
once you know the alternative costs four hours of game.

**The set pays 2**, swept rather than guessed. The coin is the only quest reward
that moves the game - coin aircraft ignore the level gate, so coins buy PROGRESS
as well as content, while cash and fuel together are worth about half an hour
across a playthrough.

| set coin | all six zones | coins earned |
|---|---|---|
| 1 | 36.7 h | 74 |
| **2** | **36.0 h** | **150** |
| 3 | 32.0 h | 243 |
| 5 | 34.0 h* | 420 |

\* before building upgrades existed, so not directly comparable.

1 to 2 costs 42 minutes and doubles the faucet. 2 to 3 costs four hours for the
last third of the catalogue. The cliff is at 3 and this sits under it.

If coin aircraft ever respect the level ladder, this constraint disappears and
the faucet can be as generous as the catalogue wants.

## Completability

THE COIN NEEDS ALL THREE TASKS, so one row the player cannot finish costs the
whole day. That makes "is this possible today" a property the draw has to check,
not something to leave to chance.

`_eligible()` is checked when the day is drawn, and it is about POSSIBILITY, not
difficulty - "Fly 40 routes" is hard and stays in the pool; "put up a building"
on a full city cannot be done at all and is not dealt.

| row | not dealt when |
|---|---|
| fly_far | fewer than 2 destinations are reachable |
| airborne | fleet under 3 |
| build_one | every plot is built |
| collect_rent, clear_rent | nothing is built |
| gain_level | level 40+, where a level is no longer a day's work |
| fly_model | no aircraft |

If a young airport cannot offer three possible tasks, the day is topped up from
the rest rather than dealt short.

Two targets came down as well, because no playstyle reached them:

- **airborne** 60% of the fleet aloft at once -> **35%**. Aircraft dispatch one
  at a time and a short leg lands before the next few are away.
- **fly_far** three distinct destinations -> **two**, capped at what the fleet
  can actually reach. Three asked a player who flies one destination all day to
  rebuild their routine for one task; two asks for one extra trip.

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
