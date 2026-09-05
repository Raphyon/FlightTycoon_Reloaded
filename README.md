# Flight Tycoon Reloaded

Isometric airport tycoon remake.

Third-party art from a discontinued game is used for art. 
Everything borrowed lives under `source-assets/` so it can be easily identified.

## Installing a build

Builds are attached to GitHub Releases rather than committed - a 130 MB exe is
over GitHub's 100 MB per-file limit, and a binary that changes every session
would add its full size to history on every rebuild. Assets are named for the
commit they were built from (`FlightTycoon-Reloaded-win-4ad930e.zip`), which is the same
string the save reports back in its `build` field.

**Windows 10 or later.** Unzip anywhere and run `FlightTycoon_Reloaded.exe`. There is no
installer and nothing else to fetch - the pack is embedded in the executable.

Windows will say **"Windows protected your PC"**. The binary is unsigned, so
SmartScreen has nothing to check it against; **More info -> Run anyway**. Worth
saying to a tester up front, because otherwise it reads as a broken download.

**macOS 10.12 or later**, universal. Unzip and **right-click the app -> Open**,
then confirm. A normal double-click gives "cannot be opened because the
developer cannot be verified" and no way past it - same unsigned-binary story as
SmartScreen, and the right-click path is the only thing that differs.

### Where a build keeps its save

Progress lives in `user://`, which is outside the game folder - moving or
replacing the executable does not touch it, and deleting this folder is how you
force a fresh start:

| | |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\ft-proto\save` |
| macOS | `~/Library/Application Support/Godot/app_userdata/ft-proto/save` |

**Still `ft-proto`, and deliberately.** Godot derives that folder from
`config/name` in project.godot, so renaming the project to match the repo would
point the game at an empty directory and every existing save - yours and every
tester's - would still be on disk with nothing reading it. The internal name is
not worth a migration; it is seen here and nowhere else.

Seven JSON files. To collect a playthrough, zip the whole `save` folder - the
fleet is in `player.json` but zones, pads, buildings and airframe mastery are in
the other six.

### Reading a tester's save

`player.json` carries four fields that exist only to answer questions a snapshot
cannot:

    build             which commit produced the build, so two testers on two
                      builds are never silently compared
    played_seconds    wall-clock time with the game actually open
    earned_total      gross income, every upward move of the balance
    level_at          unix time against each level the moment it was reached

`level_at` is the valuable one: it carries the whole progression curve in one
file, directly comparable to a `--bot` run's day-by-day table.

**It only records forward.** A save made on an older build has none of these,
and carrying that save into a new build starts the curve from wherever the
player already is - the levels before that are gone. **A pacing sample has to be
a fresh start on a current build**, which is the one instruction worth giving a
tester twice.

## Layout

```
source-assets/
  raw/          untouched dump - reference only, never edited in place
  aircraft/     ALL aircraft source art, split by PROVENANCE - which is the
                one distinction that matters here, because the two halves
                carry different restrictions and different pipelines:
    aircraft/   extracted from the live game files. Sheet format
                (aircraft_<key>@2x.png, several paint schemes and a shadow
                in one grid) or pre-cut siblings. Read by
                sheetfleet_derive.py, which refuses any airframe not listed
                in its DEFAULTS table - which scheme is the default is not
                derivable and picking wrong repaints the fleet.
    generated/  art made FOR this project, so it carries none of the
                placeholder-only restriction the extracted art does. Flat
                ~1024px renders with no shadow, read by newfleet_derive.py,
                which synthesises the shadow and scales to a height table.
    <model>/    a few hand-kept per-model folders (a400m, 328jet,
                p-51mustang) that plane_derive.py reads directly.
                NOT worth generalising: 38 of 53 generated models have
                exactly one file, so a folder each is more clicking to
                reach the same picture. game/assets/aircraft IS per-model,
                and that is the tree worth browsing - it holds what the
                game actually draws.
  shop/         shop icons (livery variants, shadow pre-composited)
  original/     art made for this project, NOT from the dump - so it has
                none of the placeholder-only restriction everything else
                here carries. Kept apart from aircraft/ both because that
                folder is ingest.py output, and so it stays obvious at a
                glance what still needs replacing. plane_derive.py prefers
                these over the shop icon of the same name.
                SIX FILES, and not the same thing as aircraft/generated
                despite both being ours: these are named plainly (a300.png)
                and read by plane_derive.py as replacements for a shop icon
                it would otherwise use, where generated/ is the flat-render
                pipeline newfleet_derive.py drives. New flat renders go in
                generated/; this folder is not growing.
  background/, aprons/, board/, buttons/, cloud/, airport/, bubbles/,
  hud/, player_avatar/
                additional categories from the full asset dump - UI chrome,
                environment art. Not yet run through any tooling; ingest.py
                only understands the aircraft/shop pipeline above.
tools/
  ingest.py     sorts raw/ into the layout, writes manifest.json, validates
  propgen.py    generates 2-frame prop/rotor blur strips in the game's format
  plane_derive.py     builds world body+shadow for the jet fleet from the
                shop icons (lifting out their baked cast shadow), or from
                source-assets/original where a replacement exists, or from
                source-assets/aircraft for dump world sprites that arrive
                already shadow-free (WORLD_CLEAN - the A400M); also splits
                prop strips into hub-aligned per-frame files
  sheet_derive.py     cuts world sprites out of the dump's multi-element
                sheets (Black Hawk, UFO, airship, Ark) - liveries, rotor
                states, thruster states and shadows, located as connected
                components. Replaces blackhawk_derive.py, which only existed
                to reconstruct the Black Hawk before its real sheet turned up
  airport_props.py    cuts loose props, vehicles and glows out of the
                airport sheet into source-assets/airport/found/
  buildings_derive.py, newfleet_derive.py, arrows_derive.py
                same job for the building, later-fleet and arrow sheets
  affinity_bar.py, cloud_icon.py, stat_icons.py, svg_icon.py,
  arrived_label.py    author UI chrome the dump has no asset for - the
                affinity bar, distance clouds, stat glyphs, the composed
                "Arrived" callout
  econ_sim.py   Python economy sweep - runs a hundred players across a dozen
                constants in the time the in-game bot does one. SWEEP HERE,
                CONFIRM WITH THE BOT; where they disagree the bot is right,
                because this one is a reimplementation and has drifted before
  zone_bands.py seeds the 7 zone bands of 6 plots, sorted by screen depth
  export_assets.py    PNG-only export to ~/Documents/ft-proto-assets/,
                sorted into mine/ vs placeholder/ with a MANIFEST.csv
game/           Godot project root (engine, scenes, scripts)
manifest.json   generated - do not hand-edit
QUESTS.md       daily tasks: the pool, the coin budget, what was swept
UPGRADES.md     building levels: the curves, and the popularity trap
ROADMAP.md      what is wanted next, and what each item is blocked on
```

All folder names are lowercase, no spaces or punctuation other than `_` -
some of the original dump used `Title_Case` and one had a literal `:` in it,
which breaks on Windows/NTFS. Everything under `raw/` and the category
folders is exactly what was extracted; nothing was re-encoded or resized.

`source-assets/` sits outside `game/` so Godot's filesystem dock never scans
or auto-imports the raw dump. Only finished, renamed sprites get copied into
`game/` as they're needed.

## Engine

[Godot 4](https://godotengine.org/), GDScript. Chosen over Unity for a
solo, local-only, sprite-based isometric project: native isometric TileMap
support, fast editor startup, and no build weight the project doesn't need.
Open `game/project.godot` in the Godot editor to run it.

## What's implemented

20 autoloaded systems, 21 UI panels, 4 in-game placement tools.

### Airports and travel

Four airports — `homeland` (yours), `robot` (the AI airport you fly to),
`dreamland` and `carriership`. The robot airport is reachable at **five
distances**, each a separate destination gated behind one of your own zone
unlocks, so range becomes worth something as the map opens up.

| | zones | aprons | building plots |
|---|---|---|---|
| homeland | 7 | 110 | 42 |
| robot | 7 | 110 | — |
| dreamland | 3 | 42 | — |
| carriership | 1 | 32 | — |

**You cannot travel to a world you have not bought.** `Maps.is_owned` gates the
world map on a zone - Dreamland and the carrier used to be reachable from the
first minute, showing empty airports nobody had paid for. Dreamland2 opens the
whole island for now (`ZoneProgress.OPENED_BY`), a temporary table to delete
when its three zones become three real steps.

Building plots exist on homeland alone, and `Buildings` rebuilds on travel -
without that the slots from the airport you left stayed on screen at the old
coordinates, which looked like the plots had been copied across.

Zones unlock by **level and cash together**, from Zone2 at level 14 / $16,000
to Carrier at level 70 / $1.9M. Levels are what actually pace the game — see
Pacing below.

Which zone a thing belongs to is answered two different ways, because aprons
and plots arrived by different routes: an apron carries the area it was placed
into, while a plot is just an id and a position and is resolved against
hand-drawn polygons in `game/data/zone_regions.json`. Without those, every plot
became available the moment Zone2 was bought.

### The flight loop

Buy an aircraft, assign it to a pad, route it to a destination, fly it.

A lap is **four taps — two at each end**: claim the reward, then refuel and
depart. From the routes list it is one press per end: that button runs the
aircraft as far as it will go. Fuel is charged at departure and scales with the
route, so a five-cloud haul burns five times a one-cloud hop; the destination
refuels the return leg free. Legs run 1, 5, 20, 93 and 420 minutes by distance
before aircraft class and livery speed bonuses.

A flight pays `passengers x ticket price x distance`. Apron skins add a flat
bonus to cash and XP; your city's population multiplies cash only, deliberately
not XP, so decorating cannot pull the level curve forward.

Fuel is a shared stock bought from a market that **reprices hourly** off the
wall clock, so you either wait for a better slot or buy at a loss.

**It is ordered, not conjured.** A purchase lands after a delay that scales with
the batch - a minute for 50 units, an hour for 50,000 - so buying big is still
cheaper per unit and now costs foresight as well. This is what makes running dry
possible at all: price and burn alone never did it, because fuel bought on demand
out of money that is never short can be made expensive but not scarce.

Batches carry a price multiplier, so how much you buy is its own decision:

| batch | multiplier |
|---|---|
| 50 | +20% |
| 500 | +10% |
| 5,000 | par |
| 50,000 | -10% |

Buying 50,000 units 50 at a time costs 25% more than buying them in one lot.
This is also what gives the hourly market teeth - at a flat per-unit price
stockpiling was free, so a bad slot could always be waited out at no cost.

The minimum purchase is 50 units and it is now the dearest fuel in the game,
which is a real early-game trap - see Known issues.

### What a tap looks like

Claiming is not instant. Tapping a claim or a refuel fills a bar for two
seconds - "Claiming", "Refueling" - and **the action fires when the bar lands**,
so the wait is the transaction rather than a flourish over an outcome already
decided. It does not block: every other pad stays live and can start its own,
which matters because taps are the binding constraint (43 a minute measured).

What it paid then floats off the top of the bubble - cash first, XP half a
second behind it, and a coin if a rent claim turned one up. Measured as
before/after deltas rather than predicted, so it reports what actually
happened, including the parts nothing predicted.

**Depart All** in the routes panel does the whole turnaround for every aircraft
in one press, and is **locked until level 15**. Locked, it wears the grey art
and reads "Level 15" rather than going absent. The level is measured, not
picked: the manual path costs two taps an aircraft and the button costs two
flat, so it saves 2N-2, and the fleet is 5-10 aircraft by level 8 - under 18
taps, which nobody would miss - against 20 aircraft by level 15, where it saves
38, about 46 seconds of tapping a cycle. Priced over a full 140-day run:

| | taps over the run | six home zones | top of the shelf | level at day 140 |
|---|---|---|---|---|
| without | 242,460 (43/min) | 14.0 h | 40.7 h | 89 |
| with | 135,005 (24/min) | 12.0 h | 30.0 h | 101 |

**Depart All is the single largest accelerant measured in this project.** Not
because of the two hours it takes off the zones, but because of the ten it takes
off the top of the shelf and the twelve levels it adds by day 140: taps are the
session budget, and handing half of them back buys everything else. Worth
knowing that **the bot does not use it by default**, so every pacing figure
below assumes the manual path - which means every one of them is a floor.

Routes panel rows are 52px, down from 62, and the bulk button keeps its art's
3.1:1 at 138x45 rather than its native 192x62, which matters when the fleet is
sixty aircraft.

**A tapped row goes to the back of the queue on the tap**, not when its bar
lands, and whatever the table is sorted by. Two seconds is long enough to keep
tapping through, so a row that held its place would be the one under your finger
for the next press. The stamp lasts until the aircraft has nothing left to do:
one press runs the whole lap, so that is usually the moment the bar lands, but a
turnaround that REFUSED - no fuel, no pad, out of range - leaves the aircraft
sitting there ready, and it stays at the back rather than jumping back under
your finger. Ties break on the aircraft id as well, because `sort_custom` is not
a stable sort and every aircraft waiting on you sits at zero seconds left: under
the default sort that was most of the table, free to reshuffle on every tap.

**The table is the panel now.** Measured on the 1152x648 base canvas rather than
estimated: a 16:9 screen showed 3.6 aircraft at a time, because the title, the
sort buttons and Depart all each had a row of their own - 131 of the content
area's 340 pixels spent on three short lines, each with the whole width to the
right of it empty - and the panel started at 0.219 of the screen, 46 pixels
below the lowest thing it had to clear.

The three lines are one line: title left, sort centred, Depart all right, with
the two side cells given the same minimum width so the sort group sits on the
table's centre rather than 150 pixels left of it. The panel starts at 0.16, just
under the avatar block (which ends at y96) and the "In service / Ready" board
(y86), the two things it actually has to clear. Rows are 964 wide rather than
900 - the limit is the back arrow at x1078, and a centred row of 964 stops at
1065 - and the gap between them is 4px rather than 6.

**3.6 aircraft on screen becomes 5.9** at 16:9, and 5.6 becomes 8.3 at 4:3. The
table area goes from 914x207 to 978x331. Nothing shrank to pay for it: the row,
its type, and the icons are the size they were.

An aircraft in the air carries a **countdown tag** on its pad - `47m 42s` - but
only while that pad's own menu is open, since there is nothing to tap. Once it
lands the tag says "Arrived", shows unasked and travels you there. Blue for your
own aircraft, green when a friend is involved.

### Daily tasks

**Five dealt a day** from a pool of twelve, and finishing **any three** pays 2
coins. Each task pays cash or fuel on its own; the coin is the set. One swap a
day trades a row you do not fancy.

Adding a task is adding a row: every entry declares a TYPE and the type decides
which signal drives it. Targets scale with what you own and are frozen when the
day is drawn, and each row carries a difficulty weight so "Fly 40 routes" is not
worth the same as "Buy fuel 500 units at a time".

The draw never deals a row you cannot finish - no "put up a building" on a full
city - because the coin needs three of five and one impossible row would cost
the day.

Three of the twelve exist to give a dead system a reason: flying to two
different destinations (range is worth 2.4% either way), buying fuel under $8 a
unit (the market reprices hourly and nothing rewarded watching it), and buying
500 units at a time (the batch multipliers).

See `QUESTS.md`.

### Daily login

**Seven tiles, one a day, streak resets if you miss one.** The panel opens
itself on launch when a day is owed - a daily you have to go looking for is not
a daily. Day 7 is the one worth coming back for: 3 coins and the largest cash, and
**days 2 and 6 hand over a boost card** - they used to hand over fuel, which is
1.3% of income, so those were the two days in the cycle that gave you nothing
you would notice.
Cash rides the quest curve, `level^1.1`, because a flat figure is real money at
level 5 and an insult at level 50.

Same day boundary as the tasks above, `floor(now / 86400)`. They must match, or
the game is telling the player two different things about what day it is.

**Two clock traps**, both because `GameClock`'s fast-forward offset is not
persisted, so a restart after a fast-forwarded session moves `now()` BACKWARDS.
A streak must not break on that - losing one to a debug session is the game
taking something for nothing - so an earlier day counts as the same day. And
`can_claim` must be `today() > last_day`, not `!=`: the second version also
fires when the clock has gone back, so you could bank a day, fast-forward,
restart, and claim it twice.

The panel is NOT built on `source-assets/login/login_back@ipad.jpg`, which was
what earmarked this feature as unblocked. It is a splash illustration - a whole
sky of aircraft over the island - and seven tiles of numbers on it would be
unreadable. A loading screen, not a panel frame.

### Boosts

Six cards, held in an inventory, used one at a time, expiring on `GameClock`.
**You are given them** - the daily login, aircraft affinity levels, and events
once those exist. There is no shop, which is the point: a boost is a windfall
for turning up or for flying one model a lot, not another thing to buy.

They are nowhere near each other in value, and all four numbers are measured:

| card | worth |
|---|---|
| **auto-turnaround** | aircraft turn themselves round while nobody is watching. **One hour a day nearly halves the time to DarkZone** - 2.2 h to 1.2 h |
| **speed** | everything below A flies as an A. 71% of the fleet qualifies, the fleet gets **26% faster**, and it helps the WORST aircraft most: E->A is -33% on a five cloud leg, B->A only -11% |
| **double cash** | fine early, quietly weak late - repricing the Ark $4.5M to $7M changed a 90 day run by nothing |
| **free fuel** | 1.3% of income, which is what fuel is worth in total. Honest as the commonest drop, a trap as anything you would spend a coin on |

Four hook points in `Fleet`, one line each: `grade_for` asks `lift_grade`,
`fuel_cost` asks `fuel_is_free`, `reward_cash_for` multiplies by
`cash_multiplier`, and auto-turnaround drives `Fleet.advance_all` on a timer.

**Auto-turnaround is why rarity is the lever.** Taps are the binding constraint
in this game, and a boost that removes them WHILE THE PLAYER IS AWAY removes the
constraint entirely for as long as it runs. What does the damage is total
coverage across a run - tier length times drop rate - and sustained one hour a
day is 90 h, the dose that halved DarkZone. So a 12 hour card is worth
twenty-four 30 minute ones, and belongs to events at one per 30-45 days.
The login and affinity between them are about 17 h a run, comfortably inside it.

Four rules that are not obvious and each cost a bug or nearly did:

- **Speed can only ever RAISE a grade.** Lifting "everything below A to A"
  naively drags an S-class aircraft down to A, which is a boost making your best
  aircraft worse. It applies after the livery step, so paint keeps what it
  bought.
- **All three auto-turnaround lengths share ONE timer.** Two timers means the
  30 minute card ending also ends the 12 hour one.
- **Using a card already running EXTENDS it**, rather than restarting. A restart
  throws away whatever was left - the player losing something for pressing a
  button.
- **A saved timer is discarded if it ends further out than the longest card
  could reach.** `GameClock`'s offset is not persisted, so a restart moves the
  clock backwards and a timer written before it reads as running for hours. The
  same trap the daily login hit twice.

There is **no toolbar button**. Every button on that shelf is art with its own
pressed state and there is none for this, so the entry point is one card at the
corner of the screen, there only while you hold something or something is
running, carrying a count and lit while a boost is live.

### Coins, and how many there are

Four sources, re-measured on the pinned clock over the full runs:

| | casual (55 h) | regular (93 h) | heavy (140 h) |
|---|---|---|---|
| daily tasks | 388 | 278 | 142 |
| building rent drops | 198 | 216 | 311 |
| upgrade milestones | 84 | 84 | 84 |
| daily login | 125 | 80 | 40 |
| **total** | **795** | **658** | **577** |

Against a shop costing **1,705** across 14 coin aircraft. Nobody buys the set:
runs end on 90, 73 and **-3** coins, which is a faucet sized against its sink
about as well as it can be.

**The three profiles earn it completely differently.** The casual player lives
off dailies and logins - 64% of their coins - and the heavy player off building
rent drops, 54% of theirs. It is not one faucet, and a change to any one source
moves a different player.

What it spends is what the coin gate used to buy. Coin aircraft were "aircraft
you did not pay cash for" - so if a run ever comes back much faster than 14.0 h
for the home zones, this is the first place to look.

### Progression and economy

You start with **$5,000, 15 coins, and a granted DC-3**. 69 aircraft on the
shop ladder - **55 cash across levels 1-70** and **14 coin-priced, totalling
1,705 coins and reaching level 84**.

**Every price is a round number** - one or two significant digits and zeros for
cash, a multiple of five for coins. That took spreading things out rather than
rounding them: eight aircraft sat between 108,000 and 150,000, which needs five
thousand steps to keep distinct and nothing that fine reads as round. Letting an
algorithm snap each to the nearest nice figure and push collisions up a rung
cascaded - the 787 came out at $1,000,000 against its $150,000 - so the packed
band was spread by hand instead and nothing moved more than a third.

The coin lane is spaced too, and was not: four of the nine sat inside eight
levels and three more inside four, so most of it arrived in two clumps. It steps
4-5 levels now, 1/21/25/29/33/37/42/47/52, with the Spirit of St. Louis appended
at 57 to continue the step rather than disturb it.

**Owning the whole lane is no longer possible**, which was the intent when the
catalogue passed the size of a run's earnings. The rebuild took it much further
than that: the shop is 1,705 coins across 14 aircraft now, against 577-795
earned in a full run. The lane is a set of choices rather than a checklist.

The ladder used to stop at 50 while the zone gates ran to 70, which left most of
the game's 93 hours with nothing new to fly. Thirteen entries fill it, and every
one belongs to the zone it opens rather than being another airliner:

| level | zone | price | |
|---|---|---|---|
| 52, 53 | Snow | $12M, $15M | An-74, LC-130 on skis |
| 56, 57 | Dreamland1 | $25M, $35M | Be-200, US-2 - the island is a water resort |
| 59 | | $45M | F-16 - the first fighter past the gate |
| 61 | Dreamland2 | $85M | Boeing 314 Clipper |
| 62, 63, 65 | | $100M, $120M, $180M | Super Guppy, Beluga XL, Dreamlifter - the outsize freighters, in the order the idea was invented |
| 66 | Dreamland3 | $250M | Hughes H-4 - the largest wingspan ever built |
| 68, 69, 70 | Carrier | $400M, $500M, $600M | Harrier, E-2 Hawkeye, F-14 - the first naval aircraft |

**And the gaps between them were then measured, which is a different question
from where the zones are.** The XP curve is `n^4.2`, so a level near 70 is worth
thousands near the start and counting empty LEVELS gives the wrong answer:
62-65 was four levels and **18% of an entire run** with nothing new to buy,
while 2-6 was five levels and 0.01% - which is why the An-2, the Ford Trimotor
and the Ju 52 went in at 2, 4 and 6 for a different reason entirely: the shop
looking thin in the first minutes rather than the ladder having a hole in it.
That opening is ordered by SIZE - 72px, 75, 79, then the Twin Otter's 84 - and
deliberately not by date, since the granted DC-3 is 1935 and breaks any
chronology before it starts. Two of the three also hit the sizing floor: strict
span scaling wants 64 for the Trimotor and 49 for the An-2, both under the 70
the Paper Plane was already raised to for reading as a speck on the pad, so they
keep their ORDER against each other and give up the true ratio. The Beluga XL and the Dreamlifter went in at
63 and 65 - not 63 and 64, because 63/65 splits that stretch 37/41/22 by time
where picking by level number implies an even quarter each. The Super Guppy then
took 62 rather than 64, the bigger of the two gaps left, because 64 sits BETWEEN
the other two and three whale-bodied freighters in three consecutive levels is
one joke told three times - at 62 the tier runs 1965, 1994, 2006 instead. The
remaining gaps are ranked in `ROADMAP.md` item 5.

**The tail is a sink, not an investment.** Every entry past 50 pays
220,000-300,000 a leg, at or under the Ark's 300,000, so none of it adds income
the pacing has not already measured. The PRICE is the ladder: $12M to $600M,
which is payback in 54 legs at the bottom and 2,000 at the top. The F-14 never
repays itself and is not meant to - it is somewhere for a late game measuring
$14M a day to put the money.

An entry past 50 must carry an explicit `ticket`. Without one it falls back to
the flat 15 fare, which is silent: the first two shipped that way and earned
31,500 a leg against the A400M's 250,000 while costing three times as much.

Seven of those arrived in one stretch and all were placed BY CLASS rather than
in the empty tail, which was the other option:

| | level | price | why there |
|---|---|---|---|
| A220-300 | 30 | $95,000 | 35.1m span, a hair over the A318 |
| IL-62 | 33 | $112,000 | the B707's class - four rear engines, T-tail, 43m |
| A350-900 | 43 | $580,000 | 64.75m, near enough the 747-8's band |
| A340-300 | 44 | $650,000 | 60.3m, the top of the airliner class |
| B777-300ER | 44 | $700,000 | 64.8m, the A340's size class four decades on |
| Banshee | 45 | 50 coins | the coin lane's top rung, above the X-37B's 48 |
| C-17 | 47 | $1,500,000 | a bigger A400M, 51.7m span against 42.4 |

The cash ladder still climbs with level after all of them, which is the thing
that breaks when two aircraft share a rung.

**Coin aircraft obey the level gate**, same as everything else. They used to
ignore it - the pay-to-win lane, buyable from minute one - which made every coin
a purchase of progress rather than of content. Gating it did not make coins free
of pacing (2 coins a set against 5 was 32.7 h against 28.0 h, on the older
unpinned instrument and a smaller catalogue - unre-measured, since it needs the
constant changed), but it
changed the shape of the advantage: a coin now buys a DIFFERENT aircraft at a
point you could have afforded one anyway.

**Aircraft affinity** is per MODEL, not per aircraft, and caps at level 10 worth
1% speed each. It accrues per LEG - both the destination claim and the home
claim grant - so a round trip counts twice, and six DC-3s in service fill the
same DC-3 pool six times over.

Levelling one **pays $1,000, flat**. Flat because it aims at the early game:
1,000 is real money against a 3,000 DC-3 and quietly becomes nothing against a
7,000,000 Ark, with no taper to tune. Scaling it by the model's price would do
the opposite, since the early models ARE the cheap ones. The claim bubble floats
"Level 2!" in violet when it happens - the cash is paid inside the claim, so
without that the player sees a bigger number and no reason for it.

The curve is **progressive**, `50 x (n-1)^2` XP:

| level | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|
| legs for this level | 5 | 15 | 25 | 35 | 45 | 55 | 65 | 75 | 85 |
| legs, cumulative | 5 | 20 | 45 | 80 | 125 | 180 | 245 | 320 | 405 |

It was flat five legs a level, which meant a model did all nine level-ups inside
its first 45 legs and never moved again. Far gentler than the PLAYER curve at
`n^4.2` - an airframe should get harder to master, not compete with levelling.

Liveries are a coin purchase that makes one specific aircraft faster. **41
across 20 models**, the deepest being the A350-900 and the C-17 with five each -
the first aircraft whose pickers have to page, since the row shows three.

Several arrive as ONE image holding two to five aircraft. `newfleet_derive.py`
takes `(file, index)` as a source and cuts the cell out by CONNECTED ALPHA
rather than by assuming a grid, because the cells are neither evenly spaced nor
equally sized and a grid split clipped them. Index is reading order, top row
left to right. That keeps `source-assets` the one place the art lives instead of
exporting derived PNGs back into it.

A livery is pinned to its body's exact SIZE, not scaled to the same height. The
renders differ by a percent or two, and a sprite is centred on its pad, so the
A380's midnight paint - 130 wide against a 137 body - walked the aircraft three
pixels sideways when you changed it. Eight were off before that was fixed.

How far apart a sheet measures from its own default is worth checking before
wiring one, because it says whether the art actually matches: the ATR's three
came in at 0.5% and the 777's at 1%, while the C-17's five run 2.7-4.9% wider
and cost about 4px of vertical stretch once pinned. Scaled to a common height
they are still plainly the same airframe, which is what settled it - the bounding
box alone would not have.

Both livery shops - aircraft and apron paint - are built from the building
shop's own pieces: `board_card1` at 122.5x200, the price tag, and a real buy button reading
Buy / Wear / Worn. They used to be a 157x90 badge stretched to card shape with
no button at all, the whole card being one invisible Button.

### Buildings

42 plots, built from a shop, each earning rent on a cycle you tap to collect,
with a small chance of turning up a coin. Population housed feeds the popularity
multiplier above. **17 types.**

**Nine of them are a ladder; eight are not, and that is the design.** Rent per
hour and population both rose monotonically with price, so the correct move on
every plot was always "the dearest thing I can afford" - picking a building was
a wait rather than a decision, and the tech tree finished at level 16, 0.2% of a
run. Measured as a Pareto frontier over rent/hour, inhabitants and rent per
collection, among buildings a player could actually buy, the count was **1 at
every level in the game**, and it was the Eiffel Tower.

The eight new ones carry no figures from the original - they are new buildings,
so unlike the nine there was nothing to preserve - and each is the best in the
game at one thing and poor at the others:

| | best at | poor at |
|---|---|---|
| **TAP** - Solar Exchange, Skypark Resort | rent per HOUR; the Skypark's 18,000/h is the highest anywhere | pays one cycle to an absent player, few inhabitants |
| **IDLE** - Downtown Offices, Corporate Campus | rent per COLLECTION; the Campus pays 20,000 a go | wastes most of its rate if you sit tapping it |
| **CROWD** - Harbour Towers, Spiral Gardens, Terrace Apartments, Concert Hall | inhabitants, to 7,600, and needs no taps at all | rent: the Concert Hall repays in 57 hours on rent alone |

**Rent does not stack** - one cycle completes and the building waits - which is
what makes TAP and IDLE opposites rather than two labels on one number. A
4-minute Skypark and a 90-minute Campus both pay one cycle over a night away:
1,200 against 20,000.

**Which archetype wins changes over a run.** Trading the Skypark's rate for the
Concert Hall's people is worth it once flight income passes about 190,000/h, so
CROWD is worthless early and worth three times the rest in a late game running
583,000/h. The CROWD gates are 23, 33, 48 and 52, so the most extreme opens
roughly when it starts being the right answer. Within an archetype the later
entries are more EXTREME, not better - the CROWD line gives up rent as it climbs
- so none beats another outright. The frontier is 7 by level 50 against 1.

**Plots carry a level, to 10.** Rent x1.45 each, so the cheapest building on the
board ends up paying more than an Eiffel Tower - about $1.04M and six hours of
construction. Cost rides the building's own price, so a level is $8,300 on a
roadside hotel and $110,000 on an office building - both through `NiceNumber`,
because a curve does not produce figures anybody would choose. **A coin building
upgrades with coins:** the Eiffel Tower's price is denominated in them, so the
cash curve was charging dollars for a number derived from coins.

A building **does not earn while upgrading**: taking it out of service is the
cost of improving it. The site shows a cone bubble and a countdown while it is
down. Upgrades are per plot, not a queue - the limit is money.

Upgrades raise **rent only, never population**, and that is load-bearing:
popularity multiplies flight cash and is uncapped, so scaling population with
levels would take a maxed city past +1,600% on every flight and void every
pacing number here.

**A level also raises the coin drop chance**, +8% a level, and reaching level 5
or level 10 pays a coin on the spot. That exists because rent alone made
upgrading close to worthless: a level produced cash and nothing else, and an
Office at 5->6 costs $830,000 to gain $20,140 an hour - 41 hours of never
missing a 16-minute collection, on a game that reaches level 70 in 93. Coins are
what is actually scarce, and buildings already supplied about 40% of them, just
blind to level. Population was the obvious lever and is the wrong one; see
`UPGRADES.md` for why, and for the measured curve.

Pressing **Upgrade** opens a confirmation window rather than spending: the
building as it is and as it will be, side by side with an arrow between them,
the rent difference, the price, and any milestone coin promised before you
commit. The button used to read "Lv 4  510,000 coins" - a level the building's
own name already shows, a price, and no answer to what the money buys.

Demolition refunds half of everything sunk in, upgrades included. See
`UPGRADES.md`.

### Development tooling

Nothing in this project guesses at placements - everything was placed in game
and lives as coordinates in `game/data/*.json`.

Three of the tools turned out to be the game itself. `ApronLayer` spawns every
apron and world aircraft, `CloudLayer` the covers over locked zones, `PathLayer`
the roads traffic follows - roughly 90-95% of each file is runtime, with the
placement mode bolted on because the tool was written inside the node that draws
the things. They were called `*Editor` until the names started misleading people
about what deleting them would do.

`BadgePlacer` is the newest and the smallest: the pad badge sits at one offset
shared by all 110 pads, so it is placed once by eye on a real pad and every pad
takes it. It writes `data/badge_offset.json` on every nudge - a value that only
a human can transcribe out of a console is a value that gets lost.

`RotorEditor` is a genuine tool and rigs two things now: propeller and rotor
hubs, and **afterburner nozzles**. A nozzle and a hub want exactly the same
things placed against a live preview - where, how big, in front or behind - so
they share the editor and the file rather than growing a second of each. `E`
switches lists; the exhaust list is stored under its own key, `f14:exhaust`
beside `f14`.

| | |
|---|---|
| `M` | cycle model |
| `E` | rotor hubs / exhaust nozzles |
| `1-9` | select hub |
| click | place it |
| `-` `+` | size |
| `Q` `W` | rotate - **exhaust only**, a rotor disc is drawn face-on |
| `B` | behind the fuselage / in front |
| `Escape` | leave |

**21 rotor rigs and 5 exhaust rigs**, 57 hubs placed by hand between them.

**The rig follows the ART, not the aircraft.** Two now carry fewer hubs than the
real machine has engines: the H-4 gets six for its eight, and the Super Guppy
three for its four - the near wing's inboard propeller is hidden behind the
fuselage, the bulge being the entire point of that aeroplane, so a fourth hub
had nowhere to sit but the body centre, where it would spin in the middle of the
hull. When the two disagree the drawing wins, because the drawing is what the
player is looking at. The defaults in `fleet.gd` drop to match, or a fresh save
re-introduces a hub the placed one does not have.

The building-plot, landmark and zone-region editors were deleted once their data
was placed; the coordinates they produced are in `game/data`.

They use `_input` rather than `_unhandled_input`, because an apron's Area2D
claims world clicks through physics picking first, and act on mouse *release*
without drag so a left-drag still pans the camera.

**Fast-forward** (`GameClock`) advances the simulation by hand while the engine
stays at 1x. Scaling `Engine.time_scale` instead hands every frame a five
second delta at x300 and greys the screen out. It **holds while a panel is
open** — fast-forward multiplies the world, not the hand holding the phone —
except Routes, which is the panel you turn the fleet around in.

**Give controls** in the F1 menu nudge the save by hand - cash in 10k/100k/1m/10m
steps, coins in 5/10/50/100, levels in 1/5/10. Levels are granted as XP rather
than assigned, so `add_xp` runs its own loop and every `level_changed` fires;
the shop, the zone cards and the quest gates all listen for those.

These replaced four scenario presets that jumped to fixed points and wiped the
save to get there. Most testing wants one number nudged, not a new game.

**The bot cannot touch your save.** It calls `reset_to_defaults()` and plays 90
simulated days, and all of that used to be written straight to `game/data` - a
session of bot runs silently replaced a level 24 airport with a level 1 one.

The guard was added per-file, three times, to the three paths that had leaked so
far. That is a rule which only covers the files somebody remembered, and it
leaked again through `ApronSkins`. It is now one public statement -
`SaveGame.is_bot_run()` - called by every writer under `scripts/`; nine were
unguarded when it was audited per WRITE rather than per file. Bot runs are still
snapshotted and restored around, because a guard that has failed is a guard you
verify rather than trust.

One live cost of that guard, found by a sweep that returned three identical
runs: `AircraftAffinity.grant_use` opened by re-reading its own file, so the
increment two lines later only survived if the write landed. Blocked writes meant
it never did. **No bot run had ever levelled an aircraft**, and every pacing
figure in this project was measured with no affinity speed bonus.

**The bot** (`scripts/bot.gd`) plays the real autoloads headless:

```bash
godot --headless --path game -- --bot --who regular --seed 1234
```

**`--dump-ui` prints every Control in a panel with its global rect and texture.**

```bash
godot --headless --path game -- --dump-ui     # but see below
```

Containers decide the real rectangles - a VBox stretches its children, a
negative separation draws one on top of another, a margin moves a whole block -
and none of that is visible in the code that sets it up. Reading the source
instead is how one panel got "fixed" three times and was wrong three times.

**RUN IT WINDOWED FOR ANYTHING ABOUT VERTICAL SPACE.** No `viewport_width` is
set, so headless defaults to 1152x1152 while the real window is 1152x720 - a
dump taken headless is measuring 432 units of height the game does not have, and
content that "fits" there will sit outside the panel on screen.

**Pass `--seed` for anything you intend to compare.** A run is reproducible on
two conditions and this is the one that is not automatic: the clock is pinned
under `--bot` (`GameClock.BOT_EPOCH`), which fixes the fuel market and the daily
quest draw, but the lights still roll off the global RNG. With both, two reports
are byte-identical apart from the wall-time line; with neither, the same config
an hour apart came out ~20% apart on day-40 cash. `--epoch <unix seconds>` moves
the pinned instant, for asking whether a result survives a different starting
hour deliberately rather than by accident.

It drives Fleet, Economy, Progression and the rest directly rather than
reimplementing them, because `tools/econ_sim.py` reimplemented the rules and
was wrong three separate times in ways that invalidated everything it had said.

Flags worth knowing: `--bulk on` makes it use Depart All instead of tapping each
aircraft, which is how that button was priced. It also reports **legs flown per
model** - the rate-buying run flies eleven models in total against thirty for a
prestige player, so for a workhorse any affinity curve maxes - and **fleet size
against level**, which is where the level 15 gate came from.
A tap costs 1.2s of session time (`--latency`), and `--speed` charges taps at
`latency x speed` since fast-forward does not speed the player up either.

### Pacing

Measured with the bot, latency modelled, for a regular player (4 sessions a
day, 10 minutes each) over the full 140-day run - 93.3 hours of play. This
table was three rebuilds out of date until 2026-08-31; `BALANCE.md` carries the
other two profiles.

| milestone | play time |
|---|---|
| Zone2 | 0.7 h (day 2) |
| all six homeland zones | 14.0 h (day 21) |
| all 42 building plots | 14.0 h (day 21) |
| the city maxed | 420 levels, 42 of 42, by the end |
| top of the shelf, level 84 | 40.7 h (day 61) |
| all pads | never - 152 of 184; the missing 32 are the Carrier's |

The run ends at level 89 with $45.7M in hand, having grossed $791M and tapped
242,460 times.

**Pacing is XP-gated, not money-gated.** Quadrupling zone prices moved a casual
player 9.5h to 10.0h; stretching the level requirements moved a regular player
to 40h. Prices are close to irrelevant; levels are the whole lever - and the
corollary is that **coins are, because coin aircraft are aircraft you did not
pay cash for.** Cash and fuel quest rewards together are worth about half an
hour across a playthrough; the coin is worth several.

**The game has a sawtooth, and it stops at level 48.** Every zone unlock up to
Beach arrives with new aircraft, and a new model starts at the cheap end of the
affinity curve, so an unlock hands back a burst of quick airframe levels before
the ramp bites again:

| zone | level | models arriving |
|---|---|---|
| Zone2 | 14 | emb120, dhc8 |
| DarkZone | 28 | tu104, a318, a319, uss51, a220 |
| Forest | 36 | blackh, airship, v22, ufo, a300 |
| Desert | 42 | b787, 747, ncc1701, a350-900, b777-300er, a340-300 |
| Beach | 48 | a380-300, x37b, c17, concorde, an-225, a400m, ark |
| Snow | 53 | banshee, an74, lc130 |
| Dreamland1 | 57 | be200, us2, f16 |
| Dreamland2 | 62 | b314, guppy, beluga-xl, dreamlifter |
| Dreamland3 | 66 | h4, harrier |
| Carrier | 70 | harrier, e2, f14 |

So the tail is not only empty of aircraft, it is missing the pattern that
carries the first 48 levels - and that tail is most of the 93 hours. Eight
entries, placed on the teeth rather than spaced evenly, are specced in
`ROADMAP.md` item 10.

**All ten open with something now.** The tail entries were placed by ZONE rather
than by class, which is the whole difference: an aircraft that belongs to the
gate it opens. Snow got polar aircraft, Dreamland got flying boats because the
island is a water resort, the Carrier got the first naval aircraft in the game,
and Dreamland3 got the Hughes H-4 - the largest wingspan ever built, for the
last gate that used to arrive as a level number and a bill.

Everything here is measured, and the measuring instrument has been wrong five
times. The bot did not claim quests, did not upgrade buildings, and rolled its
day off `_process` which never fires when it advances the clock by hand - each
of those reported "this change does nothing", which was a statement about the
bot. Then it only ever expanded the homeland, so the late game looked flatter
than it is. Then `AircraftAffinity.grant_use` re-read its file on every call, so
with writes blocked under `--bot` the increment was discarded every time and
**no bot run had ever levelled an aircraft** - every figure here was measured
with no affinity speed bonus at all. If a run says a change had no effect, check
the bot models the change at all before believing it.

### Saves

`SaveGame` writes `player.json` and six sibling progress files to
`user://save`, NOT to `game/data`. They were written to `res://data` until the
project was first exported, at which point they would all have failed silently:
res:// is baked into the pack and read-only, and nothing in the write path
reported it. `SavePaths` owns the decision - it reads `user://` first and falls
back to `res://data`, so an existing playthrough migrates on its next save
without a step anybody has to run.

**The layouts stay in `game/data`.** `apron_layout`, `building_layout`,
`cloud_layout`, `landmark_layout`, `paths`, `zone_regions` and `aircraft_rig`
are CONTENT, authored with the F1 editors and shipped with the game - not
progress. The export excludes the eight progress files by name so a build ships
with none of a developer's playthrough in it.

**A bot run writes nothing to disk**, stated once as `SaveGame.is_bot_run()` and
called by every writer under `scripts/`. It was enforced per-file before, which
is a rule that only covers the files somebody remembered - it leaked through
`ApronSkins` and destroyed a real playthrough. Bot runs are still snapshotted
and restored around, because a guard that has failed is a guard you check.

## Asset format

Reverse-engineered from the dump. Verified, not guessed.

**World sprites** — `aircraft_<model>_<slot>_2x.png`

| slot | contents |
|---|---|
| 1 | aircraft body, no shadow |
| 2 (also seen as `s`) | detached ground shadow |
| 3 | propeller / rotor blur |

The slot index is a **state key, not a z-order**. Draw order is always
shadow -> body -> prop regardless of numbering. Slot 3 only becomes active once
the aircraft is fuelled.

**Shop icons** — `<model>[_<livery>].png`

Same render and same pixel dimensions as slot 1, but a different livery, with
the shadow already flattened in. Confirmed by diffing `p51_white.png` against
`aircraft_p-51mustang_1_2x.png`: body differences are 41% lighter / 42% darker,
signed mean −0.2. That is a repaint, not shading. There is no baked ambient
occlusion anywhere in the set.

### Shadows

Pure black, flat alpha, anti-aliased outline only. Straight alpha — **not**
multiply. Because the body is a single alpha value, overlapping shadows will
double-darken; render them to one buffer with max blending rather than
compositing individually.

Opacity is inconsistent between aircraft (328jet 191, P-51 143). `ingest.py`
flags this. Normalise before building.

### Prop / rotor blur

Two frames in one strip separated by a 4px empty gutter. Pure white, straight
alpha, flat per frame — frame 0 at 128, frame 1 at 153. The opacity differing
between frames is deliberate; it pulses brightness and is what makes two frames
read as fast rotation. Do not normalise them to a single value. Play at 12–16fps.

`tools/propgen.py` generates strips to this spec for aircraft whose slot-3
asset is missing. Parameterised by cell size, blade count and hub radius.

Not every strip is two frames: the A400M's carries four, a full rotation
cycle, and includes a dark spinner hub rather than being pure white. Frames
are split on their empty columns, but each is then pasted into an identical
cell with its hub on a fixed spot — the content spans differ in width
(24/24/24/23) and `WorldAircraft` draws frames with a centered `Sprite2D`, so
cropping each to its own bounds would re-center it and make the disc wander
between frames. See `split_prop_strip` in `plane_derive.py`.

### Afterburners

Four frames, one flipbook, shared by every aircraft that has nozzles -
`tools/afterburner.py`, ORIGINAL art. Lit for the departure only, both the
runway path and bulk dispatch, and put out in `play_arrival`: a departure fades
out with it still burning and the same node is reused when the aircraft returns.
A fighter parked on its pad with the burner running would be wrong, and the pad
is what you actually look at.

**One flame whose parameters animate, not four flames.** Length breathes 25-30px,
intensity pulses on an offset phase, and the shock diamonds travel aft so it
shimmers rather than strobing. The first cut drew three separate plumes - a soft
cone, one with diamonds, a short bloom - and cycling those would have jumped,
because each had its own size and its own centre. Every frame here shares one
canvas and one anchor at the nozzle.

**No angle in the art.** It points straight back along +x and the game rotates
it per nozzle. Baking the angle in was the first design and it was wrong: every
airframe sits at its own slope, so it meant one plume per aircraft rather than
one shared by all of them. How far apart they turned out to be:

| | plumes | angle | scale | behind the hull |
|---|---|---|---|---|
| F-14 | 2 | 25 deg | 1.00 | hub 1 only |
| F-15 | 2 | 26 deg | 0.90 | both |
| Concorde | 2 | 27 deg | 1.15 | both |
| X-37B | 1 | 31 deg | **2.25** | yes |
| F-16 | 1 | 32 deg | 1.32 | yes |

**The Harrier has none, deliberately.** It is a fast jet and it was on the
candidate list for exactly that reason, which is not a reason - the Pegasus is a
NON-AFTERBURNING turbofan. It vectors thrust down through four nozzles instead,
which is a different effect and not this one.

Concorde has four engines and two plumes: at 155px the nacelle pairs read as one
dark shape each, so a plume per engine would be two overlapping flames
pretending to be one. The X-37B at 2.25x is a single rocket bell beside a
turbofan, which is the argument for scale living on the HUB rather than the
aircraft.

**Behind the hull turned out to be the majority.** This shipped hardcoded to
draw on top, reasoning that from this camera the exhaust exits away from the
airframe - true of the F-14 and of nothing else. Concorde's nacelles sit under
the delta, the X-37B's nozzle under its tail, and the F-15's tailplane crosses
both of its. Only the F-14 keeps a plume in front.

**Placement is a rig, not arithmetic.** Nozzles were seeded by measuring the
source renders and scaling to sprite size, and every one of the five still moved
once rigged against a live preview. The pattern across all of them: the seed
gets POSITION close - the F-16's landed within 5px - and says almost nothing
useful about angle or scale, which went 20 deg to 32 and 0.80 to 1.32 on that
same aircraft, and 18 degrees out on the Concorde.

**Resizing a sprite breaks a placed rig.** Offsets are pixels from the body
centre, so growing an aircraft leaves its nozzles and rotor hubs behind. The
F-16 going 80px to 88 needed its hub and scale multiplied by the same 88/80 -
the angle does not move, being a rotation rather than a length. Rescale rather
than re-place, or the placement work is thrown away.

### Altitude

Costs no extra art. Shadow stays pinned to the ground anchor; body translates
up and shifts along the light vector, measured at roughly `0.20 * altitude` in
screen x. Nearly straight-down light, about 11° off vertical.

### Padding is not consistent

The 328jet assets carry a 1px transparent border. The P-51 assets run flush to
the canvas edge. Do not assume a uniform trim margin in any importer.

## Known issues

### Design

- **Range is inert on the clock and expensive on the thumb.** A leg pays x5
  from the nearest destination to the furthest while taking x420 as long, so the
  1-cloud hop is 84x better per MINUTE - but a lap is four taps whatever its
  length, so the furthest is 5x better per TAP. A session is a budget of the
  player's time and the hours between sessions are free, so the two effects very
  nearly cancel on pacing and do not cancel at all on cost:

  | routing | six home zones | top of the shelf | taps | gross income |
  |---|---|---|---|---|
  | always 1-cloud (`near`) | 15.3 h | 40.0 h | 296,738 (53/min) | $662M |
  | the game's default (`match`) | 14.0 h | 40.7 h | 242,460 (43/min) | $791M |

  Forty-two minutes apart on the ladder, against 23% more taps and 16% less
  income for the short hop. Range is the dearest stat on the shop card and it
  still changes nothing you would notice. Fixing the payout exponent buys no
  extra hours of game, but it would make range mean something. Not done.

  **`--routing far` is not a second data point.** It produces a byte-identical
  run to the default, because `Fleet.best_destination_for` returns the exact
  cloud match and destinations sit at distances 1-5 with ranges of 1-5, so the
  match always exists and is always the furthest reachable. The table this entry
  used to carry was the near run against the default run under two names, on a
  clock that was not pinned.
- **The opening move is undiscoverable, and it is worth 8x.** Zone1 ships with
  five free pads; spending the whole $5,000 filling them immediately is the
  difference between reaching Zone2 in 1 hour and in 8-9. Nothing in the game
  says so. Granting two or three aircraft at start would make the five-pad
  opening happen whether or not the player works it out.
- **Fuel bites now, but as a tax on the poor.** It scales with the route and
  arrives on a delay, which took blocked departures from 1 to 250 over sixty
  days. But its share of income runs 13.9% casual against 6.8% heavy: it costs
  most to the player earning least, because income outgrows the fuel bill.
- **The 50-unit batch squeezes the early game twice.** It is the only batch a
  new player can afford, it is the dearest fuel in the game at +20%, and 50
  units is still more than a small fleet needs - so the first fuel purchase is
  a large, overpriced, mostly-idle outlay. The premium is deliberate (small
  batches should be the habit you grow out of) but it stacks with a minimum
  that was already a trap. Lowering the minimum, rather than the premium, is
  probably the fix.
- **Late-game cash is not a lever.** Repricing the Ark from $4.5M to $7M changed
  a 90-day run by nothing at all - by then income is large enough that price
  does not bind. Only level and availability do, which is worth remembering
  before tuning any top-of-ladder number.
- **Dreamland and the Carrier are gated but not built.** Levels 57-70 unlock
  content that does not exist yet - dreamland has aprons and nothing else. The
  honest route to a 40-hour game past the homeland zones runs through building
  these, not through stretching the curve further.
- **The board is 184 pads and no profile finishes it.** Every run stops at 150
  to 152, and 184 - 152 is exactly the Carrier's 32: at $300,000,000 the zone
  itself is never bought, so its pads are never on sale. This entry used to say
  the bot "never reaches all pads, so the top of the apron ladder is unmeasured".
  It is measured now - the check had been comparing pads built against the pads
  on the maps owned at that moment, which goes true the first time the homeland
  fills - and the answer is that one zone price is the end of the game.

### Technical

- **The fast-forward offset is not persisted.** `GameClock.offset` resets on
  restart, so time skipped in one session is not carried into the next and rent
  cycles disagree with what the save expects.
- **Model keys disagree between categories.** The shop icon is `p51`, the world
  sprites are `p-51mustang`. Needs an alias map before the manifest can join
  them automatically.
- **Most models are shop-icon only.** Later-tier content streamed on demand and
  never downloaded. Treat the roster as data-driven so a missing sprite yields a
  placeholder rather than a hard failure.

## Usage

```bash
python tools/ingest.py --raw source-assets/raw           # dry run
python tools/ingest.py --raw source-assets/raw --apply   # write layout
python tools/propgen.py                                  # regenerate blur strips
```

Run the game headless to check it boots, and the bot to measure pacing:

```bash
godot --headless --path game --quit-after 30
godot --headless --path game -- --bot --who regular --seed 1234
```

Before exporting a build, write the stamp:

```bash
python3 tools/stamp.py
```

That generates `game/scripts/build_stamp.gd` with the current commit, which is
what a save's `build` field reports. It is gitignored and never committed - it
used to be a hand-edited constant in `save_game.gd`, which meant a pull request
every time anything shipped and a stamp that drifted three times in one day
when nobody made one. A clone with no stamp reports `dev`; a dirty tree is
stamped `<hash>+dirty`.

`class_name` globals only register after an editor rescan — `godot --headless
--editor --path game --quit` — otherwise a new one is "not declared in the
current scope" at runtime.
