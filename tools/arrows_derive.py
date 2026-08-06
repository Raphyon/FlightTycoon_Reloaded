#!/usr/bin/env python3
"""Cut the two paging arrows out of the airport sheet.

PROVENANCE: reverse-engineered placeholder art, same terms as the rest of
source-assets - see the README. Not shippable.

They sit alone in a clear band at the top of airport@2x.png, between the sprout
and the helipad, so their bounds are found by alpha rather than hardcoded:
scan the band for columns with content, then trim each piece to its own rows.

    python3 tools/arrows_derive.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "source-assets", "airport", "airport@2x.png")
OUT = os.path.join(ROOT, "game", "assets", "buttons")

# The band the arrows live in, and the two column runs inside it.
BAND = (20, 100)          # y range to search
SPAN = (655, 750)         # x range to search
NAMES = ["button_arrow_left@2x.png", "button_arrow_right@2x.png"]


def main() -> None:
    a = np.array(Image.open(SRC).convert("RGBA"))
    alpha = a[..., 3] > 8
    band = alpha[BAND[0]:BAND[1], SPAN[0]:SPAN[1]]

    runs, start = [], None
    for i, has in enumerate(band.any(axis=0)):
        if has and start is None:
            start = i
        elif not has and start is not None:
            runs.append((start + SPAN[0], i - 1 + SPAN[0]))
            start = None
    if start is not None:
        runs.append((start + SPAN[0], SPAN[1] - 1))

    if len(runs) != len(NAMES):
        raise SystemExit("expected %d arrows, found %d: %s" % (len(NAMES), len(runs), runs))

    os.makedirs(OUT, exist_ok=True)
    for (x0, x1), name in zip(runs, NAMES):
        rows = np.nonzero(alpha[BAND[0]:BAND[1], x0:x1 + 1].any(axis=1))[0]
        y0, y1 = rows.min() + BAND[0], rows.max() + BAND[0]
        piece = Image.fromarray(a[y0:y1 + 1, x0:x1 + 1])
        piece.save(os.path.join(OUT, name))
        print("  %-28s %dx%d  from (%d,%d)" % (name, piece.width, piece.height, x0, y0))


if __name__ == "__main__":
    main()
