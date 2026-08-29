#!/usr/bin/env python3
"""Install the sheet-format aircraft art: bodies, shadows and paint schemes.

This is a THIRD input format, alongside plane_derive.py (the old shop-icon
crops) and newfleet_derive.py (flat ~1024px renders with no shadow). What
arrives here is already cut to something near sprite scale, already carries its
own shadow, and ships several paint schemes per airframe:

    aircraft_a300@2x.png        a sheet: 5 paint schemes + 1 shadow in a grid
    aircraft_a319_1@2x.png      or the same thing pre-cut, one file per scheme
    aircraft_a319_s@2x.png      with the shadow alongside

Because it is drawn AT apron scale there is no height table here and no shadow
synthesis - the two things newfleet_derive.py exists to do. Cells are separated
by connected alpha, the same way sheet_derive.py cuts the Dreamlifter's four.

WHICH SCHEME IS THE DEFAULT IS NOT DERIVABLE. It is not the first cell, it is
not the same position on every sheet, and picking wrong repaints the fleet. So
DEFAULTS below is filled in by hand and the script refuses to touch an airframe
that is not listed.

    python3 tools/sheetfleet_derive.py            # everything in DEFAULTS
    python3 tools/sheetfleet_derive.py a300 b747  # just these
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "source-assets", "aircraft", "aircraft")
OUT = os.path.join(ROOT, "game", "assets", "aircraft")
SHOP = os.path.join(ROOT, "game", "assets", "shop")

# Anything smaller than this on a sheet is a stray pixel, not a cell.
MIN_CELL_PIXELS = 400

# The shop card scales its icon into a fixed box, so this only sets sharpness.
# Same figure newfleet_derive.py uses, so the shelf stays consistent.
SHOP_ICON_SCALE = 1.2

# sheet group -> our ShopCatalog key. Most match; these do not.
KEYS = {
    # a380 and a380_800 are TWO AIRCRAFT, not one with two livery sets. The
    # -800 is the second-last unlock in the shop; the plain A380 sits well
    # below it.
    "A400M": "a400m", "a340": "a340-300", "a380": "a380-300",
    "a380_800": "a380-800", "b777": "b777-300er", "c400": "crj700",
    "dash8": "dhc8", "dc-3": "dc3", "dc-6": "dc6", "emb-120": "emb120",
    "f-15-eagle": "f15", "ncc-1701": "ncc1701", "p-51mustang": "p51",
    "tu-104": "tu104", "tu-154": "b727",
}

# THE ONE THING THAT HAS TO BE DECIDED BY EYE.
#
# group: (default_scheme_number, {scheme_number: livery_name})
#
# The numbers are the ones printed by --list, which are the same ones on the
# contact sheet. The default becomes body_2x.png; every other listed scheme
# becomes body_<name>_2x.png and wants an entry in AircraftSkins.LIVERIES.
# Schemes left unnamed are still written, as body_alt<N>_2x.png.
DEFAULTS = {
    "a300": (1, {}),
    "a319": (1, {}),
    "a340": (1, {}),
    "a380": (3, {}),
    "a380_800": (1, {}),
    "airship": (3, {}),
    "b737": (1, {}),
}

# LOOKED AT AND REJECTED - not the same as "not decided yet", which is what an
# absence from DEFAULTS means. These keep the art they already have.
SKIP = {
    "atr72",
}


def cells_of(group):
    """Every cell for a group, in reading order, as (name, Image).

    Sheets are cut by connected alpha; pre-cut groups are read from their own
    files. Both come back the same shape so the caller cannot tell which it is.
    """
    sheet = os.path.join(SRC, "aircraft_%s@2x.png" % group)
    if os.path.exists(sheet):
        im = Image.open(sheet).convert("RGBA")
        lab, n = ndimage.label(np.array(im)[:, :, 3] > 30)
        boxes = []
        for i in range(1, n + 1):
            ys, xs = np.where(lab == i)
            if len(ys) < MIN_CELL_PIXELS:
                continue
            boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        boxes.sort(key=lambda b: (b[1] // 40, b[0]))
        return [(None, im.crop(b)) for b in boxes]
    out = []
    for f in sorted(os.listdir(SRC)):
        m = re.match(r"aircraft_%s_(\d+)@2x\.png$" % re.escape(group), f)
        if m:
            out.append((int(m.group(1)), Image.open(os.path.join(SRC, f)).convert("RGBA")))
    out.sort()
    return [(None, im) for _, im in out]


def shadow_of(group, cells):
    """The shadow, and the cells that are not it.

    A pre-cut group keeps its shadow in its own _s file. On a sheet the shadow
    is one of the cells, and it is picked RELATIVE to its siblings - flattest
    and darkest - because "grey" is a different number on a slate saucer than
    on a white airliner. A one-cell sheet has no shadow in it at all; that cell
    is the aircraft.
    """
    own = os.path.join(SRC, "aircraft_%s_s@2x.png" % group)
    shadow = Image.open(own).convert("RGBA") if os.path.exists(own) else None
    is_sheet = os.path.exists(os.path.join(SRC, "aircraft_%s@2x.png" % group))

    # ONLY A SHEET HAS ITS SHADOW AMONG THE CELLS. A pre-cut group's cells are
    # all paint schemes and its shadow is the separate _s file, so removing a
    # cell there throws away a scheme - which is what happened to the A319 and
    # the A340, both of which came out with one.
    #
    # A group can have both a sheet and an _s. The cell still has to come out
    # of the scheme list either way; the _s only wins on which image is used.
    if not is_sheet or len(cells) < 2:
        return shadow, cells

    def flatness(im):
        px = np.array(im).astype(int)
        op = px[:, :, 3] > 30
        rgb = px[:, :, :3]
        return (rgb.max(axis=2) - rgb.min(axis=2))[op].mean() * 2 \
            + rgb.mean(axis=2)[op].mean() / 8

    scores = [flatness(im) for _, im in cells]
    i = scores.index(min(scores))
    rest = [c for j, c in enumerate(cells) if j != i]
    return (shadow if shadow is not None else cells[i][1]), rest


def install(group, default_n, names):
    key = KEYS.get(group, group)
    folder = os.path.join(OUT, key)
    cells = cells_of(group)
    if not cells:
        print("  %-14s no art found" % group)
        return
    shadow, schemes = shadow_of(group, cells)
    if not 1 <= default_n <= len(schemes):
        print("  %-14s default %d is out of range (1-%d)" % (group, default_n, len(schemes)))
        return
    os.makedirs(folder, exist_ok=True)

    body = schemes[default_n - 1][1]
    body.save(os.path.join(folder, "body_2x.png"))
    written = ["body_2x.png"]
    if shadow is not None:
        shadow.save(os.path.join(folder, "shadow_2x.png"))
        written.append("shadow_2x.png")

    for i, (_, im) in enumerate(schemes, start=1):
        if i == default_n:
            continue
        name = names.get(i, "alt%d" % i)
        im.save(os.path.join(folder, "body_%s_2x.png" % name))
        written.append("body_%s_2x.png" % name)

    icon = body.copy()
    icon.thumbnail((int(body.width * SHOP_ICON_SCALE), int(body.height * SHOP_ICON_SCALE)))
    icon.save(os.path.join(SHOP, "%s_default.png" % key))

    print("  %-14s -> %-12s %dx%d, %d files%s"
          % (group, key, body.width, body.height, len(written),
             "" if shadow is not None else "  (NO SHADOW)"))


def main():
    wanted = sys.argv[1:]
    if not DEFAULTS:
        print("DEFAULTS is empty - nothing to install.\n")
        print("Every group, with how many paint schemes it has:")
        groups = sorted({re.sub(r"^aircraft_|_(s|\d+)@2x\.png$|@2x\.png$", "", f)
                         for f in os.listdir(SRC)})
        for g in groups:
            cells = cells_of(g)
            shadow, schemes = shadow_of(g, cells)
            if g in SKIP:
                state = "SKIPPED"
            elif g in DEFAULTS:
                state = "default %d" % DEFAULTS[g][0]
            else:
                state = "-"
            print("  %-14s %-12s %d schemes  %-10s%s"
                  % (g, KEYS.get(g, g), len(schemes), state,
                     "" if shadow is not None else "  (no shadow)"))
        return
    for group, (default_n, names) in sorted(DEFAULTS.items()):
        if wanted and group not in wanted:
            continue
        if group in SKIP:
            print("  %-14s skipped - keeping its existing art" % group)
            continue
        install(group, default_n, names)


if __name__ == "__main__":
    main()
