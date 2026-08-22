#!/usr/bin/env python3
"""The afterburner plume, as a four frame flipbook.

PROVENANCE: ORIGINAL. Nothing in the dump is a jet exhaust, so this is drawn
from scratch and ships, like tools/banshee_rotor.py.

ONE FLAME THAT BREATHES, not three variants cycled. The first pass made three
separate plumes - a soft cone, one with shock diamonds, a short bloom - and
cycling those would have jumped, because each had its own size and its own
centre. What animates instead are the PARAMETERS of a single flame:

  length     breathes 25 <-> 30px, the soft and long shapes
  intensity  pulses on an offset phase, the short bloom's punch
  diamonds   travel aft as the frames advance, so it shimmers not strobes

Every frame is drawn on ONE canvas with the nozzle at ONE anchor point, which is
what stops the flame walking about as it cycles. The anchor is printed so the
rig can be set from it.

NO ROTATION HERE. The plume is drawn pointing straight back along +x and the
game rotates it per aircraft - see the `exhaust` rig in fleet.gd. Baking the
angle in was the first design and it was wrong: every airframe sits at its own
slope, so it would have meant one plume per aircraft rather than one plume.

    python3 tools/afterburner.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "effects"

SS = 8
FRAMES = 4
MAX_LEN = 32
WIDTH = 12

# The nozzle sits this far into the canvas, leaving room for the flame to be
# rotated about it without clipping.
LEAD = 12


def frame(i: int) -> Image.Image:
    import math
    t0 = i / float(FRAMES)
    length = (25.0 + 5.0 * math.sin(t0 * 2 * math.pi)) * SS
    bloom = 0.55 + 0.25 * math.sin(t0 * 2 * math.pi + 1.1)
    phase = t0 * 2 * math.pi

    cw, ch = (MAX_LEN + LEAD * 2) * SS, WIDTH * 3 * SS
    nz = (LEAD * SS, ch // 2)
    a = np.zeros((ch, cw), dtype=np.float32)
    w_full = WIDTH * SS

    for x in range(cw):
        t = (x - nz[0]) / length
        if t < 0.0 or t > 1.0:
            continue
        # Widest just aft of the nozzle, tapering to nothing.
        w = w_full * 0.5 * (0.55 + 0.9 * t ** 0.6) * (1.0 - t ** 2.2)
        if w <= 0.0:
            continue
        dia = 0.78 + 0.42 * abs(math.cos(t * math.pi * 3.2 - phase))
        lo, hi = int(nz[1] - w), int(nz[1] + w) + 1
        for y in range(lo, hi):
            r = abs(y - nz[1]) / max(w, 1e-3)
            v = (1.0 - r * r) * (1.0 - t) ** bloom * dia
            if v > a[y, x]:
                a[y, x] = v

    a = np.clip(a, 0.0, 1.0)
    rgba = np.zeros((ch, cw, 4), dtype=np.uint8)
    # White-hot core grading out through yellow to orange at the edge.
    rgba[:, :, 0] = 255
    rgba[:, :, 1] = np.clip(120 + 135 * a, 0, 255)
    rgba[:, :, 2] = np.clip(40 + 215 * a ** 2.6, 0, 255)
    rgba[:, :, 3] = (a * 235).astype(np.uint8)

    im = Image.fromarray(rgba, "RGBA").filter(ImageFilter.GaussianBlur(SS * 0.5))
    return im.resize((cw // SS, ch // SS), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for i in range(FRAMES):
        im = frame(i)
        name = "afterburner_%s_2x.png" % "abcd"[i]
        im.save(OUT / name)
        print("  %-28s %dx%d" % (name, im.width, im.height))
    print("\n  anchor (the nozzle) is at %d,%d in every frame" % (LEAD, frame(0).height // 2))


if __name__ == "__main__":
    main()
