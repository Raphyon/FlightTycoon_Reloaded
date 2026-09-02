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
| 5 more models | yes, per model | open - gaps ranked, biggest one halved |
| 6 more buildings | one sheet, delivered | **DONE** - 17 types, three archetypes |
| 7 events | yes, a lot | blocked |
| 8 passenger animations | yes, none exists | blocked |
| 11 trade-in | no - shop art covers it | open - the sell bug is fixed |

**It is a distributable game now, which it was not this morning.** That is not
on the numbered list either, because the list assumed a thing you run from the
editor. What it took:

| | |
|---|---|
| saves in `user://` | **DONE** - res:// is read-only once exported, so every save would have failed silently in a build |
| export presets | **DONE** - macOS, macOS (devtools), Windows; progress files excluded by name |
| real builds | **DONE** - 130 MB exe, 189 MB app, both self-contained |
| distribution | **DONE** - GitHub Releases, named for the commit they were built from |
| splash / threaded load | **DONE** - real `ResourceLoader` progress, not a timer |
| save telemetry | **DONE** - `build`, `played_seconds`, `earned_total`, `level_at` |
| camera clamp | **DONE** - max zoom is about one zone, no grey void |
| audio | **NOT STARTED** - zero files, zero `AudioStreamPlayer` |
| onboarding | **NOT STARTED** - nothing explains a tap, a route or a cloud |
| **friends: add / search** | **NOT STARTED** - see below, and it is the last item off the tester list |
| signing | **NOT STARTED** - unsigned, so SmartScreen and Gatekeeper both object |

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

### The tester pass: 29 of 30

A first outside build came back with thirty numbered faults. All but one are
fixed. The ones worth remembering, because each was a class rather than a
one-off:

**No component knew what could be on screen.** Six panels could be open at once
and a demolish confirmation could sit beside the upgrade menu it contradicted.
`PanelManager` now owns that, in two tiers - a BASE you are looking at, a DIALOG
taken on one - and it watches `visibility_changed` rather than being called, so
all 24 panels kept the code they had.

**Buttons are not where their rectangles are.** Toolbar art carries a shadow
down one side, so captions centred on the rect sat eight pixels right of the
button. Routes art is drawn KEEP_ASPECT_CENTERED, so a "112px" button painted 57
and a nine-character caption spilled out of it.

**Layouts were reasoned about instead of looked at.** The shop hub was changed
three times and wrong three times; the pad badge four. What settled both was
screenshotting the running game and dumping real rectangles - see the readme's
`--dump-ui`, and the viewport warning attached to it.

**Two economies were priced as pillars and meant as flavour.** Lights were 13.4%
of income and 14.4% of every tap; fuel was 1.3% of income and blocked one
departure in sixty days. Both re-measured and re-pitched.

### 12. Friends you can actually add

THE ONLY ITEM OFF THE FIRST TESTER PASS THAT IS STILL OPEN. Twenty-nine of the
thirty were fixes; this one is a feature and was set aside deliberately rather
than rushed in beside them.

The Friends panel lists what `Friends` already holds and lets you visit and
remove. There is no way to ADD one and no way to SEARCH, so the list is
whatever the game seeded and the panel is a viewer for it.

What it needs that does not exist: an identity for a player other than
"whoever owns this save". Everything friend-shaped today is a robot map - a
second airport on the same device with your own fleet standing on it - and the
green pad badge for "sent by somebody else" is wired but unreachable for the
same reason (see ApronSlot). Add and search are the front of a system whose
back does not exist, so the honest order is: decide what a friend IS, then
build the screen.

Nothing else on this list is blocked by it.

**THIS IS NOW THE FRONT OF A LARGER PROJECT.** Deciding what a friend IS turned
out to be the first step of going online, not a self-contained screen - see
*Project: online* at the end of this file. Add and search are tier 0 of it, and
the reason they are worth doing first is that they need no server at all.

### What the first outside player did, immediately

One save came back from someone who had never seen the game. **Every aircraft
that had a choice of route was flying below its rating** - both DC-4s and the
paper plane, all three rated for 3 clouds, all three on 1 or 2. Not one on its
own route.

That is the exact behaviour `--bot` measures as costing **11 levels and 2.7x
income** over 60 days, arrived at within hours, with no bot heuristics involved.
It is not a modelling artefact. The game teaches it: per MINUTE the short hop is
better and the shop card shows a payout and a time, so the arithmetic a player
can actually do points the wrong way. Per TAP - which is the cost that binds,
because flights run while nobody is watching - distance pays exactly linearly.
Nothing on screen says so.

Their speed card made it worse: it cuts a 1-cloud leg in half and a 3-cloud leg
by a third, so the item that looks like a straight upgrade sharpens the trap.

**This is the strongest open design problem in the game** and it needs no new
art, no new system and no rebalancing - a route picker that says "back in 6 min,
pays 1x a tap" against "back tomorrow, pays 5x a tap" would close it.

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

**58 aircraft across levels 1-70** today, up from 36 when this was written.
Twenty-three arrived in one stretch, so the sentence this section used to carry -
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
| 54-55 | 2 | 5.6% |
| 67 | 1 | 5.3% |
| 64 | 1 | 4.6% |
| 60 | 1 | 3.8% |
| 58 | 1 | 3.4% |
| 51 | 1 | 2.3% |
| 40 | 1 | 1.0% |
| everything below 40 | 13 | **1.0% combined** |

**This table used to be led by 62-65 at 18% of a run** - four levels between the
Clipper at 61 and the H-4 at 66, and four of the most expensive levels in the
curve. Three aircraft went into it - the Super Guppy at 62, the Beluga XL at 63
and the Dreamlifter at 65 - and **64 is all that is left of it**. The tail from
40 up is 26% across seven gaps, and that is where models are worth building.

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

**Propellers are the one thing that is not free.** A jet is a body and a shadow
and nothing else; a propliner needs a hub placed by hand per engine, and the
render decides how many of those there can BE. The Super Guppy has four engines
and three hubs, because the near wing's inboard propeller is hidden behind the
fuselage - so when picking between two candidates that are otherwise level, the
one whose engines are all visible from this angle is the cheaper build.

**The tail, in priority order:**

| level | candidates | why |
|---|---|---|
| ~~62-65~~ | ~~Super Guppy, Beluga XL, 747 Dreamlifter~~ **BUILT** - at 62, 63 and 65 | see below |
| 64 | **Martin JRM Mars, Saunders-Roe Princess**, Tu-114 | all that is left of the big hole - and it should NOT be a fourth whale. Dreamland1/2 was the water tier, built round the Be-200, the US-2 and the Clipper because the island is a resort; three outsize freighters have left it one flying boat against three. A boat here pulls the tier back to what it was for. The Princess had ten engines and never entered service, which is exactly the register - and ten hubs to place, if the render shows all ten |
| 67 | Stratolaunch Roc, Convair XC-99 | sits directly after the H-4. The Roc is the largest wingspan flying TODAY against the largest ever built - a bookend, and the twin fuselage is unlike anything in the fleet |
| 60 | **Dornier Do X**, Blohm & Voss BV 238, Short Empire | the Do X was specced in item 10 and dropped because Dreamland2 already had the Clipper. 60 is the empty slot it actually belonged in |
| 58 | CL-415 / DHC-515, Sikorsky S-42 | joins the Be-200 / US-2 amphibian cluster one tier up |
| 54-55 | Il-76, An-12, Kawasaki C-2, Basler BT-67 | Snow tier, and the Il-76 is the workhorse that register is named after. The BT-67 is a DC-3 on skis, so the proportions are already in the repo |
| 51 | An-22 Antei, C-5 Galaxy | the An-22 is more contra-rotating props - eight hubs to place; the C-5 is a jet and sits beside the C-17 and the An-225 for nothing |

**The early shop, worth doing but for the other reason:**

| level | candidates | why |
|---|---|---|
| ~~2-6~~ | ~~An-2, Ford Trimotor, Junkers Ju 52~~ **BUILT** - at 2, 4 and 6 | the whole stretch, filled every other level. See below |
| 3, 5 | Cessna 208 Caravan, DHC-2 Beaver, Britten-Norman Islander | what is left of the opening, and it does not need much - the shop already offers something every other level here |
| 8-12 | Beechcraft 1900D, Let L-410, Saab 340, Dornier 228 | straight commuter turboprops, next to the Twin Otter and the EMB-120 |
| 14, 16 | Fokker 50, BAe Jetstream 31 | 14 is the Zone2 gate and currently arrives between the EMB-120 and the Dash 8 |
| 18-19 | Embraer E175, **BAe 146 / Avro RJ85** | the 146 is a four-engined regional, which reads as odd next to the CRJ in a good way |
| 23-26 | 737-800, Fokker 100, **Comet 4**, Tu-134 | the Comet was the first jetliner and the Tu-104 - already at 27 - was the second, so they cluster by era rather than by size |
| 40 | 767-300, A330-300, Il-96, MD-11 | the one mid-tail gap; a plain widebody fits, no drama needed |

**Two levels cannot fill four, so put them where they split the stretch by
TIME.** 63 and 65 cuts 61-66 into 37/41/22 rather than the 25/25/25/25 that
picking by level number implies - the same n^4.2 that makes the gap matter in
the first place makes its later halves bigger. Both are graded **D** against the
E-class flying boats around them, because the tail was otherwise a straight line
of haulers at one speed and a new aircraft has to be better at something.

**Levels 2-6 are the first entries placed for the OTHER reason** - the shop
looking thin rather than the ladder having a hole in it. The stretch is 0.01% of
a run, so nothing about pacing moves; what moves is that the opening offered
NOTHING between the granted DC-3 and the Twin Otter at 7. Three aircraft went in
at 2, 4 and 6, spaced so something arrives every other level rather than
clustering and then going quiet.

The ramp is by SIZE, which is what a player sees buying up the early shop - 72px,
75, 79, then the Otter's 84 - and NOT by date. The DC-3 is 1935 and granted, so
chronology was broken before any of these arrived; ordering by it would have
bought nothing and cost the size ramp.

Two of them hit the sizing floor. Scaled strictly off the DC-3's 78px at 28.96m,
the Ford Trimotor's 23.72m span wants 64 and the An-2's 18.18m wants 49 - both
under the 70 the Paper Plane was already raised to for reading as a speck on the
pad. They keep their ORDER against each other and give up the true ratio, which
is the same trade the Paper Plane made. The An-2 loses least by it: a biplane
stacks two wings into one height, so it reads stubby at 72 exactly as it should.

The Ju 52's default body also had to be swapped to the civil silver scheme
first. The early fleet runs bright - DC-3 luminance 172, DC-6 179 - and the only
dark default in the game is the Black Hawk at 83, a helicopter thirty levels
later.

**And the Super Guppy ended up with three hubs for four engines.** The near
wing's inboard propeller is hidden behind the fuselage - the bulge being the
entire point of that aeroplane - so a fourth hub had nowhere to sit but the body
centre, where it would have spun in the middle of the hull. The rig follows the
ART, which the H-4 already established at six hubs for the real aircraft's
eight. Worth carrying forward as a selection rule, not just a fix: see the note
above the candidate tables.

**The Super Guppy then took 62 rather than 64, which was the bigger gap.** 64
sits BETWEEN the other two, and three whale-bodied freighters in three
consecutive levels is one joke told three times. 62 runs the tier in the order
the idea was invented - Super Guppy 1965, Beluga 1994, Dreamlifter 2006 - and
puts an aircraft on the Dreamland2 gate itself. It is sized to read as the
eldest and much the smallest: 47.6m span against 60.3 and 64.4, so 103px against
108 and 110. And it is **E** where they are D, being the propeller ancestor, so
the tier has a shape inside it rather than three identical haulers.

**The coin lane is now ten.** It was nine, evenly spaced 1 to 52 at 5 to 60
coins, and the note here used to say adding one meant respacing the lane and
re-measuring the coin economy. The Spirit of St. Louis was APPENDED instead - 57
and 65 coins continues both steps exactly, so none of the other nine moved.

What it did cost is the thing that note warned about. The coin catalogue goes
345 to 410 against a run earning about 400, so **owning every coin aircraft in
one playthrough is no longer possible** - which was a deliberate decision the
other way (see `daily_login.gd`). A trophy at the top of the lane is a fair
reason to reverse it, but the next one has no such excuse: at 70 coins the
catalogue would be 480 against 400, and the lane stops being a ladder and
becomes a wall.

---

## 6. More buildings - AND THE CHOICE BETWEEN THEM - DONE

| | |
|---|---|
| touches | `building_layout.gd`, `PropShopPanel.gd` |
| needs | ~~more entries; a reason to pick one over another~~ both shipped |
| art | one sheet of eight, delivered |

~~**Only 9 building types for 42 plots.**~~ **17 now**, so the city repeats
itself 2.5 times rather than nearly five, and the eight new ones are the fix for
the harder half of this item as well - see below.

### The bigger problem: there is no choice to make

Adding a tenth building does not fix what is actually wrong here, which is that
**picking a building is not a decision - it is a wait.**

Rent per hour rose monotonically with price and so did population, so the
correct move on every plot was always "the most expensive thing I can afford".
Nothing about the plot, the zone, or what is next to it changed that answer.

**MEASURED, before and after.** The honest test is not "is any card dominated"
- a level-1 building losing to a level-52 one is just a ladder - but *how many
non-dominated choices does a player have at the level they are actually at*.
The Pareto frontier over (rent/hour, people, rent per collection), among
buildings buyable at that level:

| | frontier at L16 | at L30 | at L50 |
|---|---|---|---|
| the nine, as shipped | **1** | **1** | **1** |
| the nine, ignoring the Eiffel Tower | 2 | 2 | 2 |
| with the sideways eight | 2 | 4 | **7** |

One. At every level in the game, there was exactly one building not beaten
outright on all three counts, and it was the Eiffel Tower.

| | level | rent/hour | people | cycle |
|---|---|---|---|---|
| Coffee House | 1 | 3,000 | 200 | 4 min |
| Cafe | 1 | 2,600 | 260 | 6 min |
| Bar | 2 | 2,743 | 320 | 7 min |
| Business Center | 10 | 8,000 | 2,000 | 12 min |
| Grand Hotel | 12 | 9,000 | 3,000 | 14 min |
| Garden Hotel | 13 | 9,600 | 3,500 | 15 min |
| TV Tower | 15 | 10,364 | 2,500 | 11 min |
| Office | 16 | 10,125 | 4,000 | 16 min |
| Eiffel Tower | 1 | 15,000 | 8,000 | 20 min (30 coins) |

**Two of the nine could never be the right answer, and both are now FIXED.** The
Coffee House was beaten by the Cafe at the same level for $1,000 more, on rent
AND on people - the first card in the shop, dead on arrival. The TV Tower was
worse than the Grand Hotel and the Garden Hotel on both, while unlocking two
levels AFTER them: a level-15 reward worse than what you had at 12.

Both were fixed by shortening the CYCLE, which is the one figure in that table
that is ours - price, rent and people are read off the original's shop cards.
The Coffee House went 5 to 4 minutes and the TV Tower 13 to 11, so each now wins
its tier on rent per hour and loses it on people. They are the tap-hungry,
cash-now options against the idle-friendly ones beside them.

**That is a trade, not a buff.** Popularity is 800 people per 1% of ALL flight
cash, so by the late game a plot's inhabitants are worth more than its rent: at
$14M a day the Office's extra 1,500 people are worth about 11,000 an hour on
their own, more than any building's entire rent. The TV Tower wins the hour you
tap it and loses the hour you do not. Coin income does not move either - drop
chance is per cycle MINUTE, so chance times cycles-per-hour is constant.

**And the tech tree is over in about twenty-six minutes.** The last gate is the
Office at level 16, which is **0.20% of a run** - Zone2 at level 14 is measured
at 0.2-0.3 h, and 16 is not far past it. After that every building is available
for the remaining 99.8% of the game and the shop never says anything new.

Plots do not save it. They arrive six per zone across seven zones, so **thirty of
the forty-two arrive at DarkZone or later** - level 28, about 4.6 h - by which
time the whole catalogue has been unlocked for four hours. The pacing of PLOTS
is real; the pacing of BUILDINGS ends before the second zone is paid for.

The one thing genuinely holding the early game together is cash, not design: at
level 14 a player has just spent $16,000 on Zone2 and cannot put a $35,000
Garden Hotel on six plots, so the cheap buildings do get built - as a cash-flow
bridge, and then demolished at the 50% refund. That is not progression, it is a
tax on not knowing better. **NOT MEASURED: how many plots actually get a cheap
building first, and for how long.** A bot run that logs every build and demolish
would settle it, and should come before any fix.

### The fix, shipped: three archetypes

Eight new buildings, and none of them on the ladder. They carry no figures from
the original - they are new buildings, so unlike the nine there was nothing to
preserve - and each is **the best in the game at one thing and poor at the
others**:

| | | best at | poor at |
|---|---|---|---|
| **TAP** | Solar Exchange 18, Skypark Resort 38 | rent per HOUR - the Skypark's 18,000/h is the highest anywhere | pays one cycle to an absent player, and almost no inhabitants |
| **IDLE** | Downtown Offices 28, Corporate Campus 43 | rent per COLLECTION - the Campus pays 20,000 a go, seven times anything else | wastes most of its rate if you sit tapping it |
| **CROWD** | Harbour Towers 23, Spiral Gardens 33, Terrace Apartments 48, Concert Hall 52 | inhabitants - up to 7,600, and needs no taps at all | rent, badly: the Concert Hall pays back in 57 hours on rent alone |

**Rent does not stack** - one cycle completes and the building waits - which is
what makes TAP and IDLE genuine opposites rather than two labels on one number.
A 4-minute Skypark and a 90-minute Campus both pay one cycle over a night away:
1,200 against 20,000.

**Which archetype is right changes over a run, and that is the whole point.**
Trading the Skypark's rate for the Concert Hall's people is worth it once flight
income passes about **190,000/h** - popularity is 800 people per 1% of all
flight cash, so CROWD is worthless early and worth three times the rest in a
late game running 583,000/h. The CROWD entries are gated 23, 33, 48 and 52 so
the most extreme of them opens roughly when it starts being the right answer.

Within an archetype the later entries are **more extreme, not better**. The
CROWD line gives up rent as it climbs - 6,480/h down to 2,800 - while people go
4,800 up to 7,600, so no CROWD building beats another outright. Same for TAP.

**And the tech tree now runs most of the game.** Gates go 18, 23, 28, 33, 38,
43, 48, 52 against the old ladder finishing at 16.

### What is still open

- **The Eiffel Tower.** The frontier table above is the argument: with it in the
  pool the count is 1 at every level up to 30, because it beats all eight of the
  cash buildings on all three counts, from level 1, for 30 coins, with no limit
  on how many you may build. The sideways eight finally beat it on rent per hour
  (the Skypark) and per collection (the Campus), but not on people. Either it is
  a LANDMARK and there is one, or it is a building and it needs to lose at
  something.
- **The seven-of-nine ladder.** The original nine still beat each other in order
  as their gates pass. They are recorded figures and were left alone; the choice
  now comes from the eight beside them rather than from fixing them.
- **NOT MEASURED: how often a cheap building gets built and then demolished.**
  Cash, not design, is what makes anyone build a small one early - at level 14
  you have just paid $16,000 for Zone2 - and it is then demolished at the 50%
  refund. A bot run logging every build and demolish would settle it.

### Options considered, and the two still on the table

Adding eight more entries to the same ladder was the obvious move and the wrong
one - it moves the ceiling and changes nothing. What shipped was the first of
these; the two after it are still worth doing and still need no art:

- ~~Make buildings differ sideways rather than upwards.~~ **DONE** - the three
  archetypes above.
- **Make position matter.** A hotel next to the terminal, a business centre in a
  cluster - adjacency turns 42 identical decisions into a layout puzzle, and it
  costs no art at all. Now MORE attractive than it was: with three archetypes in
  the pool there is something for adjacency to interact with.
- **Gate by zone rather than by level.** Zone-specific buildings would make the
  six new plots feel like a new place rather than six more Offices. The new
  gates are 18-52 by level, so this is still unclaimed.
- ~~Fix the two dominated cards regardless.~~ **DONE** - the Coffee House and TV
  Tower cycle change, which was the first worked example of differing sideways.

### An honest note on the shop card

The card already prints the three numbers this design trades on - cycle, rent
per cycle, inhabitants - so the choice is legible without new UI. It does NOT
print rent per HOUR, which means comparing a 4-minute Skypark with a 90-minute
Campus is arithmetic the player has to do.

Left alone deliberately, for now. Printing rent/hour would make one column the
obvious score and pull the decision back towards a single number, which is the
thing this item exists to get away from. Worth revisiting if playtesting says
the trade reads as noise rather than as a choice.

### Art

**Unblocked and spent.** `source-assets/buildings` held exactly 10 PNGs - the 9
in the shop plus the terminal - until one contact sheet of eight arrived. It is
kept whole as the source of record and split into per-building PNGs beside it;
`buildings_derive.py` skips `*_sheet.png` so it does not derive all eight as one
200px sprite.

They fit, measured rather than eyeballed. The isometric ground-edge slope runs
-0.55 to -0.66 against the existing set's -0.50 to -0.64, so they sit on the
same ground plane; height-to-width lands inside the existing range; and at the
delivered 200px they are measurably CRISPER (acutance 75 against 63).

The one caveat is headroom. The existing nine are 1024px renders downscaling
5.1x to 200; these are ~230px cells downscaling 1.15x, so there is nothing above
the current target. The Eiffel Tower is already 200x329 and the terminal
295x233, so a building wanting to be bigger than 200 wide is not hypothetical.

---

## 11. Trade-in: replacing a fleet as the thing you do

| | |
|---|---|
| touches | `HangarPanel`, `RoutePickerPanel`, `ShopItem`, `Fleet.sell_one` |
| needs | one gesture that swaps an aircraft for a better one |
| art | none - the shop's button set already covers it |

**Selling exists and nobody can find it.** `Fleet.sell_one` works and pays 50%,
but the only ways to get an aircraft off a pad are *Clear route* and displacing
it by assigning a different aircraft to that pad. Neither is called "sell", and
neither is anywhere near the shop. The Sell button being greyed out was a
separate bug and is fixed - it tested `idle_count`, which means "assigned to no
pad", so a player who had put every aircraft on a pad could never sell anything.

**Why this is worth its own item.** Measured with a `--buying prestige` bot -
buy the dearest thing affordable, which is what a player actually does - the
fleet ladder is fully exercised: **21-25 models flown against the optimiser's
4**, level 70 arrives 40% sooner, and cash oscillates between half a million and
$180M instead of flatlining. Players already replace their fleet. The game just
makes them do it through a route-clearing screen that never mentions it.

**What it should be:** a trade-in on the shop card. You are looking at a Boeing
747; the card offers it at full price, or at full price minus 50% of the A320
you would retire for it, and takes both actions in one tap. That turns the
replacement players are already performing into a decision the game acknowledges.

Three things to decide first:

- **Affinity is lost on sale, silently.** A model levelled to 10 is 405 legs of
  investment and the resale is a flat 50% of catalogue price either way. Under a
  design where replacing the fleet IS the progression, throwing that away is
  exactly what makes replacement feel bad. Either the trade-in carries some
  affinity across, or the price reflects it.
- **Coin aircraft cannot be sold at all**, deliberately - it would launder
  premium currency into cash. So the trade-in has to refuse them gracefully
  rather than appear broken.
- ~~An aircraft that has just landed is not PARKED~~ **DONE** - `can_sell` now
  accepts all three home states, so a just-landed aircraft is sellable. Selling
  one that has not been tapped FORFEITS its flight reward rather than quietly
  settling it, and the panel says so behind a Confirm. Genuinely airborne and
  at-the-destination aircraft are still refused, with the reason on the board.

**And the bigger version, which is the user's own suggestion:** make aircraft
unlocks the progression axis outright. Each new model starts its affinity ramp
at the cheap end - the sawtooth already works this way, see
`aircraft_affinity.gd` - so replacing the fleet would drive progress, and
keeping a varied fleet would trade speed for breadth. The machinery exists; what
is missing is weight. Affinity currently pays **1% flight time per level, capped
at 10%**, which is far too small to carry a progression system. That number is
the first thing to solve if this is taken up.

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

**6** - more buildings - **is done**, and it turned out to be two items in one
coat. The art half was nine types for 42 plots; the half that mattered was that
choosing a building was a wait rather than a decision, measured as a Pareto
frontier of ONE at every level in the game. Both are fixed: 17 types, and eight
of them built to differ sideways rather than upwards. What is left of it -
adjacency, and gating by zone - still needs no art, and is more attractive now
that there is something for adjacency to interact with.

**5** stays open forever by nature, and is no longer blocked in any sense: the
pipeline is one render per aircraft and twenty arrived in a day. It now carries
a ranked candidate list, and the ranking is measured rather than by taste. The
first thing it found - levels 62-65 being 18% of a run with nothing new to fly -
is down to the single level 64; the tail from 40 up is 26% across seven gaps. Anything built for the early shop is worth
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

---

# Project: online

ITS OWN PROJECT, NOT AN ITEM ON THE LIST ABOVE. Everything numbered 1-12 adds
something to a game that already runs on one machine. This changes what the
game IS - it introduces a second player, and with them a second source of
truth - so it gets its own file-within-a-file rather than a row in the table.

**Nothing here is scheduled and nothing here is started.** This is the idea
pass: what online could mean for THIS game specifically, what the project
already has by accident, what it would cost, and which parts are worth
refusing. The order below is cheapest-first, not best-first.

## What is already built for it, by accident

More than expected. Going looking for the blockers turned up the opposite - a
client that has been written for other players all along and has never had any.

| what | where | state |
|---|---|---|
| a second airport that RENDERS | `Maps.MAPS` - `ROBOT_AREAS` mirrors `HOMELAND_AREAS` one for one | live, visitable |
| a table of five other "players" | `Maps.ROBOT_DESTINATIONS` - `{name, level, distance, unlock}` | live, fake |
| aircraft that fly to someone else's airport and park there | `Fleet` + `flight_seconds_to` | live |
| a friend list | `Friends` + `Maps.visitable_maps()` | live, seeded |
| the "somebody else's aircraft is on your pad" badge | `ApronSlot.BADGE_FRIEND`, `pad_friend@2x.png` | ART DONE, unreachable |
| the green friend flight tag and arrived bubble | `TAG_FRIEND_TEXTURE`, `CALLOUT_ARRIVED_HOME_TEXTURE` | ART DONE, half-reachable |
| one clock for the whole game | `GameClock` | live, and see below |
| per-player telemetry | `SaveGame` - `build`, `played_seconds`, `earned_total`, `level_at` | live |

`Maps` says it out loud: *"The names/levels are PLACEHOLDER, same as the
original robot's: there is no model of other players yet."* `ApronSlot` says it
twice, about two different sprites. **The sockets are cut and the art is drawn.**

Two of these are worth more than the rest:

**`GameClock` is the only thing in the project that reads the wall clock.**
Checked, not assumed: zero calls to `Time.get_unix_time_from_system` outside
it, and seven files asking it instead. It was built that way so a headless bot
could fast-forward - and it happens to be the single property that makes
server-authoritative time a one-file change later instead of a twenty-file one.
It costs nothing to keep. **Keep it.**

**A dispatched aircraft lands on the same apron id it took off from.** That is
not a shortcut, it is what the original did - a route record shows `startApron`
and `endApron` both `airport001_area001_apron0014`, for two different users. It
means a destination can never be full, there is no "friend's airport has no
room" case to design, and the awkward question of where a visiting aircraft
parks is already answered.

And one absence that is also an asset: **there is no networking code in this
project at all.** No `HTTPRequest`, no `WebSocket`, no multiplayer peer. Nothing
to unpick, no half-built protocol to stay compatible with.

## The idea worth building the rest around

**Your friends list becomes your route network.**

The payout formula is already `seats x ticket x ROUTE clouds`, and the five
destinations are already spread across the five distance ratings - one minute
at the near end, twelve hours at the far one, paying 5x for the trip. That is a
finished economy with placeholder people in it. Put real players at those
distances and the friends list stops being a viewer and becomes the thing you
route the airline through: **a friend far away is worth more to fly to than a
friend nearby.**

This is not a new mechanic. It is the existing one with the placeholder taken
out.

It also lands on the strongest open design problem in the game. The first
outside tester flew every aircraft below its rating - the bot measures that at
**11 levels and 2.7x income over 60 days** - because per minute the short hop
looks better and nothing on screen says that per TAP distance pays exactly
linearly. A route picker with a real name and a real airport at the far end is
a reason to fly the long leg that no tooltip is going to match.

**If only one thing on this page ever gets built, build this.**

## What "online" could mean, cheapest first

Seven tiers. Each is playable on its own and each assumes the ones above it.
The line worth noticing is between 2 and 5.

**0. Identity.** A random id, written once at first launch, never changed. No
network, no server, no meaning yet. Four lines. Everything below needs it and
nothing below can be retrofitted onto saves that were written without it.

**1. Snapshots - visit a real airport.** You upload a description of your
airport; your friends download it and walk around it. Static, one-directional,
no server logic - blob storage with a key on it. The renderer already does the
hard half. This is the smallest thing that is genuinely online.

**2. The aircraft actually lands there.** Dispatch to a friend; the aircraft
appears on a pad at their airport with the green badge; they see it next time
they open the game. Asynchronous, latency-tolerant, no real-time anything - and
mechanically it is what the game already does, against a real person.
**Tiers 1 and 2 together are the whole pitch.**

**3. A mailbox.** Fuel, coins, a boost card, sent to a friend. The classic
social-idle currency and the reason people add each other in the first place.
Needs a server-side inbox and nothing more clever than that.

**4. Verbs while visiting.** Shave time off a friend's building. Refuel
something stranded on their apron. **Visiting with nothing to do is dead
content** - it is a screenshot you walk around in - and this is the tier that
decides whether tier 1 was worth building. Cheap, and it should probably ship
WITH tier 1 rather than after it.

**5. Leaderboards and anything competitive.** Wants server-authoritative time
and validated progression, which is a different project wearing this one's
coat. See the hard problems below. **The recommendation is to refuse this**, at
least until there is a reason that outweighs it.

**6. Events and shared goals.** Co-operative rather than competitive, which
dodges most of tier 5's problems - a shared target nobody is incentivised to
cheat downward. Sits naturally on item 7 (events) and should wait for it.

## The four hard problems

**Time is the currency, and the client owns it.** This is an idle game: closing
it and coming back is how you earn. Progress is computed from timestamps on
load, so moving the system clock forward is free money. That is fine today and
stays fine for tiers 1 and 2 - cheating your own airport hurts nobody, and a
snapshot of an implausible airport is just a tall building. **The line to draw
is at anything that LEAVES your save.** A gift, a leaderboard entry, an
aircraft landing on somebody else's pad: those get rate-limited or checked
server-side, because they spend from a shared pool. Everything else stays
client-side and unpoliced, on purpose.

**Every number in the save is a claim, not a fact.** Eight plain JSON files in
`user://save/`, editable in any text editor. Not worth encrypting - it delays
nobody and it would break the thing that has been most useful all month, which
is a tester mailing their save over. Design for it instead: the server stores
what it was told and never treats it as authoritative for anything another
player receives.

**Names.** The moment a player types their own handle, someone types something
vile into a game with a friends list. The project already has the answer and
did not notice: `robot_222`, `robot_318`, `robot_451`. **Generated handles -
word plus number, no free text -** costs nothing, needs no moderation queue,
and is consistent with the five names already in the game. Free text can come
later or never.

**A server is a cost that never stops.** Money, attention, and an outage that
is your problem at 2am. Two consequences, both non-negotiable: the backend must
be the dumbest thing that works, and **the game must be completely playable
with the network down.** It is an idle game - people play it on a plane. Every
online feature is an addition to a game that still runs when it fails, and no
loading spinner ever blocks the airport.

## Shape of the backend

Offline-first, and dumb on purpose. Three endpoints is the whole of tiers 0-2:

| | |
|---|---|
| `PUT /airport/<id>` | store my snapshot |
| `GET /airport/<id>` | fetch a friend's |
| `POST /flight` | tell a friend an aircraft is coming |

Add `GET/POST /inbox/<id>` for tier 3 and that is tiers 0-4 complete. No game
logic on the server, no simulation, no authority - it is a mailbox and a filing
cabinet. Which means it can be object storage plus a few lines of glue, it can
sit inside a free tier for a long time, and it can be replaced wholesale later
without the client noticing.

Client side it is `HTTPRequest` and `JSON`, both in the engine already, both
async. Nothing threaded, nothing exotic. The macOS export is not sandboxed, so
no entitlement work; Windows is unaffected.

**Poll, do not push.** No sockets, no persistent connection. Ask on launch,
after a dispatch, and when the friends panel opens. An idle game measured in
hours does not need a live socket, and not having one removes a whole class of
failure.

## Identity, and the phone-in-the-lake problem

A device-local id means losing the device loses the account. The honest options:

- **Do nothing.** Correct for a prototype with a handful of testers, and it is
  where this starts.
- **A transfer code.** The game shows a string; type it into the new install
  and the id moves. No passwords, no email, no account system, no recovery
  desk. Cheap and good enough for a long time.
- **Real accounts.** Sign-in, recovery, a password to store and to leak.
  **Not worth it** until there is something to lose.

Take the first, plan for the second, and write the id into the save now so that
either remains possible.

## The snapshot format

The one piece here that is genuinely worth NOT designing yet, because the thing
it describes is still moving - pads, liveries, zones, and whatever the price
ladder turns into. Freezing it now buys a migration later. Two rules to settle
in advance, though, and they cost nothing:

**Version it from the first byte.** A `version` field on the first snapshot
ever written, even while there is only one version.

**Unknown fields are never fatal.** The save loader already works this way -
`d.get("destination", "")` - and a snapshot is read by a build that may be
older OR newer than the one that wrote it, which the save file never is. An old
client meeting a new airport should draw what it recognises and ignore the
rest.

What it holds, roughly: identity and level, the built pads and their skins, the
buildings and their levels, the aircraft parked outside with their liveries,
and a written-at timestamp. Explicitly NOT money, XP, or anything that would
make one player's numbers visible to another.

## What to do first, and it needs no network

**Give the save a player id, then teach the game to load a foreign airport
snapshot from a FILE ON DISK and visit it.**

That is the whole risky part of tier 1, done with zero infrastructure: a real
airport that is not yours, with pads you did not build and aircraft you do not
own, rendered by the code that currently renders a fake one. Every hard
question - what the format holds, what the renderer assumes about ownership,
what breaks when a friend has a livery you have never seen - gets answered on
the desk, for free, before a single line of server exists.

Swapping the file read for an HTTP fetch afterwards is the small part. It is
also the honest test of the format: if it cannot survive being loaded from a
file, it will not survive being loaded from a server.

Testers already mail their saves over. **The first foreign airport can be one
of theirs.**

## What this does NOT do, and what it risks

It does not lengthen the game by an hour. The 62 hours in item 10 are still 62
hours, and a friend at distance 5 pays what the robot at distance 5 pays -
`payout_for` does not care whose airport it is. **Online changes the reason,
not the rate.** Anything that makes friends pay BETTER than robots is a
balance change and should be argued as one, separately.

It does not fix the price ladder, and the price ladder is still the strongest
threat to the whole idea: **93x divergence between what aircraft cost and what
they pay, 33x inside a single tier.** The tester hit that wall in one session.
A social layer over a game people quit at level 30 is a social layer nobody
sees. If these two ever compete for a weekend, the ladder wins.

And the standing risk of the whole project: **it is the first part of this game
that can be broken by someone other than the person playing it.** A bad
snapshot, an outage, a griefer, a name. None of that exists today. Every tier
above zero is a trade of that safety for a reason to come back tomorrow, and
tiers 1 and 2 are where that trade is clearly worth making.
