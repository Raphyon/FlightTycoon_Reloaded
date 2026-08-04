#!/usr/bin/env python3
"""Bring the buildings into the game as world sprites.

Much simpler than the aircraft pipeline: these are vertical, they sit on the
ground, and the user has said they need NO shadows - so there is no silhouette
to derive and no ground plane to fake. Crop the transparent margin, scale, done.

SIZED BY WIDTH, one target for all of them.

This was a single 1/3 factor, on the reasoning that the set carried its own size
hierarchy worth preserving. It does not. The source renders just frame
differently inside their 1024px canvases - the cafe fills 584px of its, the
office 1014 of its - so a uniform factor made six of the nine come out about
twice the size of the other three, and only the small-framed ones fit a plot.

TARGET_WIDTH is the footprint every building is normalised to. Height is left
to fall out of each one's own aspect, so the Eiffel Tower still towers and the
cafe still squats - the variation that means something survives, the variation
that was an artifact of framing does not.

Per-building overrides live in WIDTHS for anything that should genuinely read
bigger or smaller than the rest.

An earlier pass tried to measure each building's ground diamond and correct two
of them for a "wrong camera angle". That measurement was wrong - it was reading
rooflines and foliage, not footprints - and comparing the art directly against
an apron tile showed all eight already share the game's projection. There is no
correction here because none is needed.

    python3 tools/buildings_derive.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "source-assets", "buildings")
OUT = os.path.join(ROOT, "game", "assets", "buildings")

# Against a 229x118 apron tile. Matches the three that already fit a plot.
TARGET_WIDTH = 200

# Only for buildings that should break from the common footprint.
WIDTHS = {}


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    names = sorted(f for f in os.listdir(SRC) if f.lower().endswith(".png"))
    for name in names:
        img = Image.open(os.path.join(SRC, name)).convert("RGBA")
        box = img.getchannel("A").getbbox()
        if box:
            img = img.crop(box)
        key = name[:-4]
        target = WIDTHS.get(key, TARGET_WIDTH)
        w = max(1, target)
        h = max(1, round(img.height * target / img.width))
        img = img.resize((w, h), Image.LANCZOS)
        img.save(os.path.join(OUT, "%s_2x.png" % name[:-4]))
        print("  %-24s %dx%d" % (name[:-4], w, h))
    print("\n%d buildings (apron tile is 229x118 for comparison)" % len(names))


if __name__ == "__main__":
    main()
