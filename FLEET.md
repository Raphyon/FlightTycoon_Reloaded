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

### There is an optimum, so there is a decision

Cap 20 is a real handicap: too few legs, too little XP, six home zones at 53.3 h
against 23.3. Cap 80 beats both 40 and infinity. **A curve with a peak in it is
exactly the decision the game does not currently offer**, because pads only go
up and keeping is free.

### Curation is punished on the one axis that gates everything

XP is per leg, so it scales with fleet SIZE: cap 20 ends at level 62 against the
uncapped 81. Level gates zones, aircraft and Depart All, so today the game
rewards curation on income and taps and punishes it on progress. **If the fleet
becomes the axis, XP cannot stay a pure count of legs flown** - breadth would
win by default whatever mastery pays.

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

Four parts. 1 and 3 are load-bearing: they are what turns a collection into a
portfolio. 2 and 4 are what give the portfolio a shape.

### 1. Keeping costs something

An operating cost per aircraft, anchored to the CURRENT top of the ladder rather
than to a fixed figure - roughly `k x the pay of the best aircraft you can buy
today`. An aircraft goes net-negative around the time it stops mattering, so the
bottom of the fleet falls off as you climb and you feel the tap bill you are
paying for it.

Anchoring rather than fixing is the whole trick. A flat number is a wall at
level 5 and invisible at level 60; a percentage of the aircraft's own income
never bites, because a DC-3 paying 80% of 400 is still positive. Anchored to the
ladder it cannot produce a figure the player cannot pay, and it is the
percentage-shaped late-game sink the readme's Known issues asks for.

Charge it on pads only - an aircraft in the hangar is stored, not operated - and
say plainly on the card when a model is losing money.

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

### 3. Trade-in that carries the investment

On the shop card: full price, or full price minus 50% of the model you retire,
in one tap - and a fraction of the retired model's mastery XP carried into the
new one.

The carry is the part that matters. ROADMAP names the blocker exactly: a model
at mastery 10 is 405 legs of investment and the resale is a flat 50% of
catalogue price either way, so **under a design where replacing the fleet IS the
progression, throwing that away is what makes replacement feel bad**. The pieces
exist - `Fleet.sell_one`, `AircraftSellPanel`, `sell_value` - and the sell bug
is already fixed. What is missing is the gesture and the carry.

Coin aircraft still refuse to be sold, and the trade-in has to say so rather
than appear broken.

### 4. Breadth costs something

Operating N distinct types costs progressively more - a type rating, paid once
per model, priced off how many types you already run. Without it mastery
dilutes, the answer is "own everything", and part 2 buys nothing.

With it, fifteen mastered types beat forty dabbled ones, and the capstone choice
in part 2 is what gives your fifteen a character. That is the portfolio.

---

## What has to be decided before any of this is built

- **What XP does.** It scales with fleet size today, which makes curation cost
  levels. Either XP stops being a pure leg count, or breadth wins whatever else
  changes. This is the first thing to solve, not the last.
- **Where the capstone lives for range-5 aircraft**, which is most of the top of
  the ladder.
- **Whether the trade-in carries mastery XP or discounts the price by it.**
  Carrying is more interesting and much easier to make illegible.
- **Whether upkeep applies to coin aircraft**, which cannot be sold to escape
  it.

## How to measure the next version

    godot --headless --path game -- --bot --who regular --fleet-cap 80

`--fleet-cap` is in the bot now and is instrument only - it drives `Fleet`,
`Economy` and `ApronProgress` through the same calls a player would. Back up
`game/data` first and restore it after, as always.

The replacement pass runs inside `_collect`, between claiming and departing,
because that is the only moment an aircraft is on the ground with nothing owed
to it. Attempted after the dispatch loop it found an empty apron and a board of
airborne aircraft every time - 758 refusals in a 30 day run, reporting nothing
retired. Worth knowing before moving it.

## Risks

- **Four multipliers on one number.** BALANCE.md's `If one thing changes`
  section is about exactly this failure. The +1 cloud cap is one guard; the
  doses above are the other, and they are unswept.
- **Upkeep reads as punishment** if the game does not say clearly which aircraft
  are costing money. The whole design turns on retirement feeling like an
  upgrade rather than a loss.
- **It makes the early ladder matter more, which is where the art is thinnest.**
  That is a content bill, not a balance one, but it is real.
