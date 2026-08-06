#!/usr/bin/env python3
"""Cut every sprite out of the airport sheet that the game does not already have.

PROVENANCE: reverse-engineered placeholder art, same terms as the rest of
source-assets - see the README. Not shippable. Output goes to source-assets
rather than game/assets for exactly that reason: these are raw finds, not
things the game has decided to use yet.

HOW SPRITES ARE FOUND. Label the alpha with a 5x5 dilation so the parts of one
object join up (a lamp's post and its head), then take each group's bounding box
from the ORIGINAL alpha rather than the dilated mask - the dilated box is two
pixels fat on every side, which is enough to make a cut sprite fail to match the
identical file already in the project.

WHAT COUNTS AS "ALREADY HAVE". Every PNG under game/assets is compared against
every sprite at a common 48x48 thumbnail, with a 4px size tolerance, because
some assets were cut from this sheet at a slightly different alpha threshold.
Ten match today: the two paging arrows, the V-22's body/shadow/rotor, and five
ground vehicles.

NAMES are keyed by the sprite's ORIGIN IN THE SHEET, not by its index in the
scan - an index shifts the moment the threshold changes, an origin does not.
Anything unnamed is written as prop_<x>_<y>.png, which is ugly on purpose: it
should be obvious which ones nobody has identified yet.

    python3 tools/airport_props.py
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "source-assets", "airport", "airport@2x.png")
GAME_ASSETS = os.path.join(ROOT, "game", "assets")
OUT = os.path.join(ROOT, "source-assets", "airport", "found")

MIN_PIXELS = 250
MIN_SIDE = 12
SIZE_TOLERANCE = 4
MATCH_THRESHOLD = 10.0

# origin in the sheet -> (folder, name). Confident identifications only;
# anything genuinely ambiguous is left to fall through to prop_<x>_<y> rather
# than given a name that reads as knowledge we do not have.
NAMES = {
    # Airport furniture
    (134, 39): ("props", "windsock"),
    (816, 45): ("props", "helipad"),
    (181, 11): ("props", "lamp_post"),
    (779, 111): ("props", "lamp_post_double"),
    (653, 532): ("props", "flag"),
    (592, 273): ("props", "fence"),
    (577, 291): ("props", "fence_rail"),
    (916, 542): ("props", "wooden_platform"),
    (40, 609): ("props", "construction_pit"),
    # Landscape
    (11, 142): ("props", "cliff_foliage"),
    (926, 212): ("props", "palm_small"),
    (610, 218): ("props", "palm_tall"),
    (667, 218): ("props", "palm_tall"),
    (938, 261): ("props", "palm_tall"),
    # Ground equipment the project has no equivalent of
    (841, 438): ("vehicles", "excavator"),
    (931, 476): ("vehicles", "road_roller"),
    (802, 344): ("vehicles", "forklift_loaded"),
    (788, 213): ("vehicles", "luggage_train"),
    (720, 361): ("vehicles", "ambulance"),
    # Light pools. Four sizes plus two green ones - the green pair are almost
    # certainly the UFO's, since the fleet already carries downwash rings for
    # the V-22 and Black Hawk and the UFO has none.
    (706, 414): ("glows", "glow_wide"),
    (805, 435): ("glows", "glow_small"),
    (736, 467): ("glows", "glow_flat"),
    (705, 504): ("glows", "glow_large"),
    (770, 920): ("glows", "glow_green"),
    (854, 924): ("glows", "glow_green"),
    # NAMED WITH LESS CONFIDENCE - flat grey with no detail, so probably a cast
    # shadow, but there is no sprite on the sheet it obviously belongs to.
    (909, 743): ("props", "boulder_shadow"),
    # A straw mound with a rosette on it. No idea what it is FOR; named for
    # what it looks like rather than for a purpose nobody has established.
    (13, 11): ("props", "decor_mound"),
}

# Trees and the light glows come in families; matched on size so a fourth palm
# does not need a new line here.
FAMILY_BY_SIZE = {
    (31, 40): ("props", "palm_small"),
    (25, 46): ("props", "palm_tall"),
}


def sprites():
    a = np.array(Image.open(SRC).convert("RGBA"))
    alpha = a[..., 3] > 8
    lab, _ = ndimage.label(ndimage.binary_dilation(alpha, np.ones((5, 5), bool)))
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab), start=1):
        mask = alpha[sl] & (lab[sl] == i)
        if mask.sum() < MIN_PIXELS:
            continue
        ys, xs = np.nonzero(mask)
        x0, y0 = int(sl[1].start + xs.min()), int(sl[0].start + ys.min())
        w, h = int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)
        if w < MIN_SIDE or h < MIN_SIDE:
            continue
        out.append((x0, y0, w, h))
    out.sort(key=lambda r: (r[1], r[0]))
    return a, out


def existing():
    got = []
    for root, _dirs, files in os.walk(GAME_ASSETS):
        for f in files:
            if not f.endswith(".png"):
                continue
            p = os.path.join(root, f)
            try:
                im = Image.open(p).convert("RGBA")
            except Exception:
                continue
            got.append((p, im.size, np.array(im)))
    return got


def thumb(arr):
    return np.array(Image.fromarray(arr).resize((48, 48), Image.LANCZOS)).astype(int)


def main() -> None:
    sheet, found = sprites()
    have = existing()
    thumbs = {}

    counts = {}
    skipped = []
    for (x, y, w, h) in found:
        crop = sheet[y:y + h, x:x + w]
        ct = thumb(crop)
        match = None
        for p, (aw, ah), arr in have:
            if abs(aw - w) > SIZE_TOLERANCE or abs(ah - h) > SIZE_TOLERANCE:
                continue
            if p not in thumbs:
                thumbs[p] = thumb(arr)
            if np.abs(thumbs[p] - ct).mean() < MATCH_THRESHOLD:
                match = p
                break
        if match:
            skipped.append((x, y, os.path.relpath(match, ROOT)))
            continue

        folder, name = NAMES.get((x, y), FAMILY_BY_SIZE.get((w, h), (None, None)))
        if name is None:
            folder, name = "unsorted", "prop_%d_%d" % (x, y)
        n = counts.get((folder, name), 0)
        counts[(folder, name)] = n + 1
        stem = name if n == 0 else "%s_%d" % (name, n + 1)

        d = os.path.join(OUT, folder)
        os.makedirs(d, exist_ok=True)
        Image.fromarray(crop).save(os.path.join(d, stem + ".png"))

    print("  %d sprites in the sheet" % len(found))
    print("  %d already in game/assets:" % len(skipped))
    for x, y, p in skipped:
        print("      (%4d,%4d)  %s" % (x, y, p))
    total = sum(counts.values())
    print("  %d written to %s" % (total, os.path.relpath(OUT, ROOT)))
    for folder in sorted(set(f for f, _ in counts)):
        n = sum(v for (f, _), v in counts.items() if f == folder)
        print("      %-10s %3d" % (folder, n))


if __name__ == "__main__":
    main()
