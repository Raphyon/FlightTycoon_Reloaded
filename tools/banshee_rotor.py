#!/usr/bin/env python3
"""The Banshee's ducted lift fans, spinning.

PROVENANCE: ORIGINAL. Nothing in the dump is the right shape - every propeller
in the project is a VERTICAL disc at 0.41:1, and the only wide ellipses are the
Black Hawk's and V-22's bare rotors, which read as an open helicopter head
rather than a fan turning inside a duct. Drawn from scratch here, so it carries
none of the placeholder-only restriction and ships.

WHAT IT IS NOT: a helicopter disc. A ducted fan is enclosed, so the blur stops
at a hard rim instead of feathering out, the blades are many and short rather
than few and long, and the hub is a solid centre rather than a mast.

SPIN FRAMES ONLY, no idle. The static fans are painted into the body art - the
same arrangement as the A400M, whose parked props need no overlay - so these
only ever layer on while the thing is running.

Rotational blur is done honestly: the blade set is drawn many times across the
arc it sweeps between frames, each pass at low alpha, then the whole disc is
squashed to the isometric ellipse. Drawing an ellipse and faking streaks inside
it gets the silhouette right and the motion wrong.

    python3 tools/banshee_rotor.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "aircraft" / "banshee"

# The duct opening measured off body_2x.png: about 46 x 29, so 1.6:1.
WIDTH = 48
ASPECT = 1.60
SS = 10               # supersample; a circle needs it

BLADES = 8            # short and many, the way a lift fan is
BLUR_PASSES = 44      # copies across the swept arc
FRAMES = 2

BLADE = (226, 233, 242)
# How hard the swept coverage maps to opacity, and the ceiling it reaches.
ALPHA_GAIN = 1.30
MAX_ALPHA = 132.0
RIM = (176, 186, 198)
HUB = (86, 92, 102)


def frame(index: int) -> Image.Image:
    """One blur phase: rasterise the blade set across the arc it sweeps and
    ACCUMULATE coverage, rather than alpha-blending passes over each other.
    Blending a transparent base repeatedly just darkens toward the last pass -
    the first attempt at this came out an opaque grey lid over the duct."""
    n = WIDTH * SS
    c = n / 2.0
    r = n * 0.47
    pitch = 360.0 / BLADES
    # Sweep LESS than a full blade pitch, or every point is covered equally and
    # the disc comes out a flat wash with no sense of rotation in it.
    # Nearly a full pitch. At 0.55 the blades stayed separate and the thing
    # read as a fan sitting still; a fan at speed is almost a uniform disc with
    # only a trace of angular structure left in it.
    sweep = pitch * 0.95
    start_ang = index * pitch / FRAMES

    cover = np.zeros((n, n), dtype=np.float32)
    for p in range(BLUR_PASSES):
        t = p / float(BLUR_PASSES - 1)
        ang = start_ang + t * sweep
        layer = Image.new("L", (n, n), 0)
        ld = ImageDraw.Draw(layer)
        for b in range(BLADES):
            a0 = ang + b * pitch
            ld.pieslice([c - r * 0.93, c - r * 0.93, c + r * 0.93, c + r * 0.93],
                        a0, a0 + pitch * 0.44, fill=255)
        ld.ellipse([c - r * 0.28, c - r * 0.28, c + r * 0.28, c + r * 0.28], fill=0)
        cover += np.asarray(layer, dtype=np.float32) / 255.0
    cover /= float(BLUR_PASSES)

    # Coverage -> alpha. Translucent on purpose: a fan you can see the duct
    # through is spinning, one you cannot is a lid.
    alpha = np.clip(cover * ALPHA_GAIN, 0.0, 1.0) * MAX_ALPHA

    rgba = np.zeros((n, n, 4), dtype=np.uint8)
    rgba[:, :, 0], rgba[:, :, 1], rgba[:, :, 2] = BLADE
    rgba[:, :, 3] = alpha.astype(np.uint8)
    disc = Image.fromarray(rgba, "RGBA")

    # NO SHROUD RING. The duct is already drawn in the body art underneath, and
    # painting a second rim on top of it just doubled the edge. Only what
    # actually moves belongs in an overlay.
    d = ImageDraw.Draw(disc)
    d.ellipse([c - r * 0.15, c - r * 0.15, c + r * 0.15, c + r * 0.15], fill=HUB + (200,))

    disc = disc.filter(ImageFilter.GaussianBlur(n * 0.005))
    height = max(1, int(round(WIDTH / ASPECT)))
    # Squashed LAST: the blur is computed round and then laid on the ground
    # plane, which is what the camera does to a horizontal disc.
    return disc.resize((WIDTH, height), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for i in range(FRAMES):
        im = frame(i)
        name = "rotor_spin_%s_2x.png" % "ab"[i]
        im.save(OUT / name)
        print("  %-24s %dx%d" % (name, im.width, im.height))


if __name__ == "__main__":
    main()
