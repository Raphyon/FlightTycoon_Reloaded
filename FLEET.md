# The fleet as the progression axis

PROPOSED, not built. This is the design ROADMAP item 11 gestures at in its last
paragraph - "make aircraft unlocks the progression axis outright" - worked out
far enough to argue with.

Everything under *What the measurement says* is measured against the live build
on 2026-08-26 with `--bot`. Everything under *The design* is a proposal, and the
doses in it are ILLUSTRATIVE - chosen so the arithmetic could be done at all,
not swept. They are marked where they appear. Do not quote them as balance.

---

## Why: the fleet is additive, and additive is worse

Nothing in the game ever asks you to retire an aircraft. Pads only ever grow -
110 homeland pads, all built by hour 24 - and keeping an aircraft costs nothing
at all. So the fleet is purely additive: the DC-3 from minute one is still on a
pad at hour 93, and a 140 day regular run ends with **180 aircraft, none of
which was ever sold**.

That would be harmless if aircraft were interchangeable. They are not, in the
resource that actually binds:

| | level | $/leg | leg | $/hour | **$/tap** |
|---|---|---|---|---|---|
| F-14 | 70 | 300,000 | 420 min | 21,429 | **150,000** |
| ATR 72 | 10 | 1,500 | 2 min | **22,500** | 750 |
| DC-3 | 1 | 400 | 2 min | 6,000 | **200** |

`$/hour` spans **47x** across the whole ladder. `$/tap` spans **750x**. A lap is
four taps whatever is flying it, and taps are the measured constraint - 35 a
minute, 195,367 over a run. So most of an additive fleet charges full price in
the scarce resource and pays back a rounding error. The EMB-120 flew 13,357
legs in that run, more than any other model, for roughly 2% of the money.

Replacement never happens because keeping is free, so adding strictly
dominates. **Any version of "the fleet is the progression" has to make keeping
cost something**, or mastery is just a stat on a collection that only grows.

---

## What the measurement says

`--fleet-cap N` was added to the bot for this: the board stops growing at N, and
when something better is affordable the bot retires its worst lap and buys the
better one. Nothing in the game changed. Same 140 days, same regular profile.

| | no cap (today) | cap 20 | cap 40 | **cap 80** |
|---|---|---|---|---|
| aircraft at end | 180 | 20 | 40 | 80 |
| gross income | $1.50bn | $1.40bn | $3.33bn | **$6.75bn** |
| taps | 195,367 | 20,723 | 31,850 | **50,782** |
| taps per minute | **35** | 4 | 6 | 9 |
| **$ per tap** | $7,698 | $67,640 | $104,573 | **$132,910** |
| six home zones | 23.3 h | 53.3 h | 31.3 h | **20.0 h** |
| level at end | 81 | 62 | 73 | **85** |

**A curated 80 beats an accumulated 180 on every axis at once** - 4.5x the
income, a quarter of the taps, zones finished three hours sooner, four levels
higher. The 180-aircraft board is not a bigger airline. It is a worse one that
takes four times as long to operate.

### The apron ladder competes with the thing it is supposed to enable

Every pad is filled with whatever is affordable AFTER paying for the pad, so the
apron ladder converts money into low-value laps. BALANCE.md has pads as the
biggest sink in the game; this reframes that. They are not just the sink, they
are the sink that competes with the fleet.

### Taps are the constraint, and an additive fleet spends them badly

35 taps a minute sustained across 93 hours is not a person - it is what the
current shape quietly demands of one. A curated board runs at 4-9.

### With Depart All in use, curating still wins - and still loses

Every figure above is the MANUAL turnaround. Depart All collapses a whole
fleet's turnaround into two taps and is unlocked at level 15, so it is what a
real player past the first hour actually uses. Re-measured with `--bulk on`:

| | accumulate (181) | curate (80) |
|---|---|---|
| gross income | $1.66bn | **$5.86bn** |
| taps | 139,932 | **10,183** |
| taps per minute | 25 | 2 |
| six home zones | **21.3 h** | 24.0 h |
| fleet ladder | **51.3 h** | 57.3 h |
| level at day 140 | 82 | 82 |
| cash at the end | $59.6M | **$5.35bn** |

Curating still wins enormously on both money and taps - the bulk button does not
rescue a bloated board. **But accumulating finishes the zones sooner, finishes
the ladder sooner, and ends on the same level**, while the curated player sits
on five billion dollars with nothing to buy.

**That is the real reason nobody retires an aircraft, and it is not that keeping
is free. It is that money is worthless.** Curation buys money and taps;
accumulation buys progress; progress gates every zone and aircraft in the game.
A player optimising for what the game actually rewards should hoard, and would
be right to.

### XP is linear in headcount, and quality very nearly pays for it

Converted to XP earned rather than levels reached:

| | aircraft | level | total XP | XP per aircraft |
|---|---|---|---|---|
| no cap | 180 | 81 | 10.4M | **57,592** |
| cap 20 | 20 | 62 | 3.4M | 168,661 |
| cap 40 | 40 | 73 | 6.7M | 167,454 |
| cap 80 | 80 | 85 | 12.7M | 158,661 |

XP is almost exactly linear in fleet size - 20/40/80 earn 1:2:4 - but a CURATED
aircraft earns **2.9x** the XP of an accumulated one, and the two effects very
nearly cancel. A curated 80 out-levels an accumulated 180; break-even is around
65 aircraft.

**So curation is not punished on the level axis** - it is punished only below
about 65 aircraft. An earlier version of this document said otherwise, on levels
alone rather than on XP, and was wrong. Fleet size having a straight payoff in
levels is a counterweight against taps and upkeep, not a fault to design out.

The real asymmetry is elsewhere, and it lands on the capstone: see below.

### What this measurement does NOT separate

A capped board also stops paying the apron ladder, so the cap measures curation
and pad thrift together. A `--cap-pads` control that keeps buying pads it will
never fill was tried and does not work: `_buy_zone` refuses to expand while any
pad stands empty, so the control stops buying zones after the fourth and
measures a player nobody is. It was removed rather than left in place to give
confident wrong answers. The flag's own comment says so.

Read the table as *curating instead of accumulating*, pads included - not as a
figure for fleet quality alone.

---

## The design

Four parts were proposed. **Part 1 was measured and dropped**, and part 3 turned
out to be doing its job from the other direction. What is left is a design with
no punitive mechanic in it: 3 is the sink that makes curating pay, 2 is what
makes the fleet you keep worth keeping, and 4 is still open.

### 1. Keeping costs something - CONSIDERED AND DROPPED

The original first part of this design was upkeep: a running cost per aircraft,
anchored to the best aircraft you could currently buy, so the bottom of the
fleet went net-negative as you climbed and retiring became the obvious move.

**It was aimed at a problem that is not there.** The measurement above says the
incentive to curate is already enormous - 3.5x the income at a fourteenth of the
taps - and no player is failing to retire aircraft because the pull is too weak.
They are failing to retire them because the reward for curating is money, and
money buys nothing once the map is finished.

Upkeep would have attacked that by making hoarding hurt. Three objections, in
rising order of weight:

- It is a PUSH. The player is billed for owning the things the game spent forty
  hours persuading them to buy.
- Its anchor inherits BALANCE.md's finding 2. `best available lap` is not a
  smooth curve - it is flat through the mid-game and jumps 11x at level 50 where
  the ticket override lands. At 2% it retires nothing at all at level 30, eleven
  models at level 50, and then stops moving.
- **It solves the symptom.** Hoarding is rational because cash has no sink. Fix
  the sink and hoarding stops being rational on its own, with nothing punitive
  anywhere in the design.

Kept here rather than deleted because the reasoning is the useful part, and
because a later pass that finds a genuine need for a fleet-size cost should know
this was measured rather than skipped.

### 2. Mastery worth committing to

Today: 1% flight time per level, capped at 10% at level 10, 405 legs to max.
ROADMAP already calls this far too small to carry a progression system, and it
is: 10% off a leg is invisible next to a 750x spread in what a lap pays.

The proposal is that mastery pays in FOUR currencies, and that the last level is
a CHOICE between them rather than a stack of all four.

ILLUSTRATIVE doses, for the arithmetic only:

| | at mastery 10 |
|---|---|
| speed | -40% leg time |
| payout | +50% per leg |
| seats | +50% cabin |
| range | **+1 cloud, and +1 is the maximum** |

They do not stack into one number, which is the interesting part. Range pulls
against the other three:

| mastery 10 | $/tap | $/hour |
|---|---|---|
| speed + payout + seats, no cloud | x2.25 | **x3.75** |
| ...+1 cloud, from range 1 | **x4.50** | x1.50 |
| ...+1 cloud, from range 4 | x2.81 | x1.04 |
| *(+2 clouds, rejected - see below)* | *x6.8* | *x0.56* |

So mastery does not make a model better in one direction. It makes it better for
a KIND OF PLAYER: the cloud is a per-tap upgrade for someone who is away between
sessions, and the other three are a per-hour upgrade for someone who is present.
BALANCE.md observes that the fleet already has this axis by accident and does
not label it. This labels it and hands it to the player.

**Range is capped at +1 cloud, at the final level only.** At +2 the branch was a
per-hour LOSS - you paid real income to buy taps - and x6.8 per tap on every
model is the same order as the `CLOUD_PAY` experiment BALANCE.md warns about,
which inflated late income about 30x and halved pacing. At +1 both branches land
above x1.0 on both axes: neither choice is a punishment, they differ in
emphasis.

Two consequences fall out of the arithmetic rather than out of taste:

**A cloud is inherently a short-haul reward.** It is worth x2.00 per tap at
range 1 and x1.25 at range 4 - the gain shrinks as range rises while the time
cost stays flat. So it lands hardest on exactly the cheap early aircraft the
game currently abandons. An ATR 72 flown four hundred times doubling its pay per
leg is a real answer to "why keep flying the type I committed to".

**58% of the roster cannot take it at all.** 34 of 59 aircraft are already at
range 5, including 17 of the level-50-and-up ladder, and `Maps` has exactly five
destinations - a sixth cloud has nothing to fly to, and `Fleet._leg_minutes`
clamps at 5 regardless. So range is one option among several and never the sole
capstone. The top of the ladder has to be offered a different one, which is
arguably the point: the capstone means something different depending on where
the aircraft sits.

### 3. Trade-in that carries the investment - AND IS THE SINK

On the shop card: full price, or full price minus 50% of the model you retire,
in one tap - and a fraction of the retired model's mastery XP carried into the
new one.

**This is what part 1 was reaching for, from the other side.** Cash buys fleet
quality; fleet quality buys income and taps; and the loop closes instead of
dead-ending in a bank balance. A curated player's 3.5x income advantage becomes
3.5x of something they want, at which point curating is simply the better play
and nobody had to be billed for anything.

The carry is the part that matters. ROADMAP names the blocker exactly: a model
at mastery 10 is 405 legs of investment and the resale is a flat 50% of
catalogue price either way, so **under a design where replacing the fleet IS the
progression, throwing that away is what makes replacement feel bad**. The pieces
exist - `Fleet.sell_one`, `AircraftSellPanel`, `sell_value` - and the sell bug
is already fixed. What is missing is the gesture and the carry.

Coin aircraft still refuse to be sold, and the trade-in has to say so rather
than appear broken.

### 4. Breadth costs something - OPEN, and suspect for the same reason

Operating N distinct types costs progressively more - a type rating, paid once
per model, priced off how many types you already run. Without it mastery
dilutes, the answer is "own everything", and part 2 buys nothing. With it,
fifteen mastered types beat forty dabbled ones, and the capstone choice in part
2 is what gives your fifteen a character.

**But it is another PUSH, and part 1 died of exactly that.** Before building it,
check whether mastery alone already answers it: if a mastered type is worth
enough, spreading thin costs you the mastery you would otherwise have had, and
breadth is self-limiting with nothing charged for it. Measure that before
charging for type ratings.

---

## The XP question, solved

MEASURED, and the fix is in `Fleet.xp_for_claim`.

**Cash scales with the route's clouds; XP does not.** `payout_for` multiplies by
`distance_to(map_key)`; `xp_for_claim` takes the map key and ignores it. So the
two economies disagree about what a route is worth, and the disagreement lands
on the capstone:

| taking +1 cloud | $/tap | $/hour | XP/tap | XP/hour |
|---|---|---|---|---|
| range 1 -> 2 | x2.00 | x0.40 | x1.00 | **x0.20** |
| range 4 -> 5 | x1.25 | x0.28 | x1.00 | **x0.22** |

Cash treats the capstone as a trade. XP treats it as a straight loss - an idle
player who takes the range branch levels four to five times slower, and levels
gate every zone and aircraft in the game.

**Two obvious fixes were measured and both failed.** Weighting XP by clouds,
`xp x (1 + w(clouds - 1))`, cannot win the race: leg time is geometric in clouds
at x4.5 each, while a linear weight buys at most x2. Even at full cash parity
the capstone still costs 60% of the model's XP rate, and it costs 2.5x the
pacing to get there:

| | home zones | fleet ladder | level at end | total XP |
|---|---|---|---|---|
| flat (today) | 23.3 h | 54.0 h | 81 | x1.00 |
| w = 0.25 | 16.7 h | 35.3 h | 91 | x1.63 |
| w = 0.5 | 13.3 h | 27.3 h | 99 | x2.32 |
| w = 1.0 | 9.3 h | 18.7 h | 110 | x3.62 |

Renormalising that with one divisor works on pacing and breaks the opening.
`stat x clouds / 2.42` lands home zones at 23.3 h exactly - but early aircraft
fly 1-cloud routes, so they eat the divisor with no cloud to pay for it, and
level 10 slips from 9 minutes to 30.

**The fix is to normalise on the aircraft's own catalogue range:**

    xp = stat x distance_to(route) / catalogue range

A model flying the route it was built for earns exactly what it earns today, so
today's pacing, today's opening and the live DC-3 and Paper Plane figures all
survive untouched. Only DEPARTURES from that route move the number - and they
move it by the same factor cash already moves by. Flying a 5-cloud aircraft on a
1-cloud hop pays a fifth of the XP, which is a fifth of the cash. Gaining a
cloud pays x(r+1)/r, which is what the cash pays.

Measured over 140 days, regular, against the same run without it:

| | baseline | range-normalised |
|---|---|---|
| Zone2 / DarkZone / Forest | 0.3 / 3.3 / 7.8 h | 0.5 / 3.7 / 8.2 h |
| Desert / Beach / Snow | 11.8 / 17.2 / 22.7 h | 12.3 / 17.8 / 23.5 h |
| all pads | 24.0 h | 24.7 h |
| all plots | 23.3 h | 24.0 h |
| fleet ladder | 54.0 h | 55.3 h |
| level at day 140 | 81 | 80 |
| taps | 195,367 | 194,092 |

Within 3% on every milestone. The residual is aircraft flying below their
matched route while the far destinations are still locked, which is the new rule
working rather than drift.

**The denominator must be the CATALOGUE range, not the current one.** If mastery
raises an aircraft's range and the denominator follows it, the bonus cancels
itself out exactly and the whole change buys nothing.

It also gives the readme's "range is inert" issue its first real push: routing
near against far now differs in XP as well as in cash, where before the XP was
identical either way.

### And one round trip took you to level 4

Separate fault, same system. The curve is degenerate at the bottom - level 2
costs **1 XP**, level 3 costs 10, level 4 costs 33 - while the granted DC-3 pays
30 a claim and a round trip is two claims. So **one full trip with a single
plane landed the player at level 4**, and the third claim at level 5, with the
bar never visibly moving.

Three levels for one flight is not a fast opening, it is no opening. Nothing was
earned, so nothing registered.

This is faithful to the original, whose own saves put a character at level 4 on
58 XP. The divergence is deliberate.

`Progression` now puts a floor under the early levels, sized in ROUND TRIPS of
the starter aircraft because that is the only thing a new player owns, and
solved from two anchors rather than picked:

    level 2 at TWO trips        -> 120 XP, the coefficient
    level 3 at FOUR AND A HALF  -> 270 XP, which fixes the exponent at 1.17

    floor(n) = 120 * (n - 1) ^ 1.17

| level | curve | floor | trips to reach | trips for this level |
|---|---|---|---|---|
| 2 | 1 | **120** | 2.0 | 2.0 |
| 3 | 10 | **270** | 4.5 | 2.5 |
| 4 | 33 | **433** | 7.2 | 2.7 |
| 6 | 185 | **788** | 13.1 | 3.0 |
| 8 | 620 | **1169** | 19.5 | 3.2 |
| 10 | **1584** | 1568 | 26.4 | 3.6 |

Applied with `maxi`, so there is no seam to tune and no second curve to keep in
step - and **it hands off at level 10 on its own**, the floor passing under the
real curve at 1568 against 1584. Level 10 therefore costs exactly what it costs
today. Only the eight levels below it are re-spaced.

What a new player now sees, one aircraft, one trip at a time:

| | today | with the floor |
|---|---|---|
| trip 1 | **level 4** | level 1, bar half full |
| trip 2 | level 5 | level 2 |
| trip 5 | level 5 | **level 3** |

**The opening stays easy.** Nothing is gated harder and no reward shrank; the
first trip still visibly fills half a bar. What changes is that levels arrive
two to three trips apart instead of three in a single tap. Level 10 slips from
about 13 minutes to about 20 - not from its threshold, which is unchanged, but
because a lower level buys fewer aircraft for the first few minutes.

### Both changes measured together

| | baseline | both changes |
|---|---|---|
| Zone2 / DarkZone / Forest | 0.3 / 3.3 / 7.8 h | 0.5 / 3.7 / 8.2 h |
| Desert / Beach / Snow | 11.8 / 17.2 / 22.7 h | 12.3 / 17.8 / 23.3 h |
| all pads / all plots | 24.0 / 23.3 h | 24.7 / 24.0 h |
| fleet ladder | 54.0 h | 55.3 h |
| level at day 140 | 81 | 80 |

Within 3% everywhere downstream. The floor is worth about 700 XP against a run
that earns ten million, so it changes the first quarter hour and nothing else.

---

## What has to be decided before any of this is built

- **Where the capstone lives for range-5 aircraft**, which is most of the top of
  the ladder.
- **Whether the trade-in carries mastery XP or discounts the price by it.**
  Carrying is more interesting and much easier to make illegible.
- **Whether breadth needs charging for at all** - see part 4.

## How to measure the next version

    godot --headless --path game -- --bot --who regular --fleet-cap 80
    godot --headless --path game -- --bot --who regular --fleet-cap 80 --bulk on

`--fleet-cap` is in the bot now and is instrument only - it drives `Fleet`,
`Economy` and `ApronProgress` through the same calls a player would. Back up
`game/data` first and restore it after, as always.

The replacement pass runs inside `_collect`, between claiming and departing,
because that is the only moment an aircraft is on the ground with nothing owed
to it. Attempted after the dispatch loop it found an empty apron and a board of
airborne aircraft every time - 758 refusals in a 30 day run, reporting nothing
retired. Worth knowing before moving it.

**`--bulk on` needs its own call and nearly cost a wrong conclusion.**
`_collect_bulk` claims and departs in one `advance_all`, so it leaves no gap at
all - the pass never ran, `--fleet-cap` under `--bulk` silently measured a board
FROZEN at N rather than a curated one, and it reported "0 aircraft retired" as
though that were a result. It now runs before `advance_all` and reports 734. The
cost of that position is that a retirement there forfeits an unclaimed reward,
which `Fleet.sell_one` avoids where it can by taking idle and parked aircraft
first.

## Risks

- **Four multipliers on one number.** BALANCE.md's `If one thing changes`
  section is about exactly this failure. The +1 cloud cap is one guard; the
  doses above are the other, and they are unswept.
- **The sink has to be big enough to matter.** The whole design now rests on
  cash having somewhere to go; if the trade-in is the only sink and it is
  cheap, a curated player is back to sitting on billions and hoarding is
  rational again. This is the thing to measure first.
- **It makes the early ladder matter more, which is where the art is thinnest.**
  That is a content bill, not a balance one, but it is real.
