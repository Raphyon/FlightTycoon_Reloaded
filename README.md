# ft-proto

Isometric airport tycoon prototype. Private, local-only.

Third-party art from a discontinued game is used as **placeholder** while the
systems get built. Everything borrowed lives under `source-assets/` so it can be
stripped or swapped in one move. Nothing here ships.

## Layout

```
source-assets/
  raw/          untouched dump - reference only, never edited in place
  aircraft/     ingested world sprites, one folder per model
  shop/         shop icons (livery variants, shadow pre-composited)
  generated/    procedurally authored fills for missing assets
tools/
  ingest.py     sorts raw/ into the layout, writes manifest.json, validates
  propgen.py    generates 2-frame prop/rotor blur strips in the game's format
manifest.json   generated - do not hand-edit
```

`source-assets/` sits outside `Assets/` so Unity does not import the raw dump.
Only finished, renamed sprites get copied into the Unity project.

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

### Altitude

Costs no extra art. Shadow stays pinned to the ground anchor; body translates
up and shifts along the light vector, measured at roughly `0.20 * altitude` in
screen x. Nearly straight-down light, about 11° off vertical.

### Padding is not consistent

The 328jet assets carry a 1px transparent border. The P-51 assets run flush to
the canvas edge. Do not assume a uniform trim margin in any importer.

## Known issues

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
