#!/usr/bin/env python3
"""Draw the UI furniture instead of cutting it out of the third-party dump.

The buttons, boards, bubbles and HUD plates are not illustrations - they are
geometry with a palette. A pill button measured column by column is five
mechanical layers:

    a soft black drop shadow, offset down
    a dark outline
    a body gradient that BRIGHTENS towards the bottom
    a darker rim along the bottom inside edge
    a bright gloss cap over the top third

Every pill in the set is that same recipe with different colours, so they can
be drawn rather than owned. That matters because everything under
game/assets/buttons is currently reverse-engineered from a discontinued game
and cannot ship - see tools/export_assets.py --audit for what is left.

SAME NAMES, SAME PIXEL SIZES. These overwrite the files they replace, so a
button that was 136x62 is still 136x62 and nothing in the UI moves. The sizes
are not invented here either; they are read off the art being replaced, which
is also how the tool knows a size is wrong.

Drawn at SUPERSAMPLE times the final size and reduced, because PIL has no
antialiased shapes and a hard-edged pill on a 62px button reads as a mistake.

    python3 tools/ui_derive.py --list     # what it can draw, and what it cannot
    python3 tools/ui_derive.py            # draw everything in RECIPES
    python3 tools/ui_derive.py orange2    # just these
"""
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "assets", "buttons")

SUPERSAMPLE = 4

# Sampled from the art being replaced, down a column through the middle, so the
# replacements sit beside the not-yet-replaced ones without a visible seam.
#
#   body   the gradient, top colour then bottom colour
#   gloss  the bright cap over the top third
#   rim    the darker band along the bottom inside edge
#   lip    a pale stroke just inside the outline
#   line   the outline, which is the darkest thing in the sprite
PALETTES = {
    "orange": {"lip": (255, 226, 175), "body": ((255, 171, 89), (255, 204, 109)), "gloss": (255, 215, 116),
               "rim": (210, 121, 70), "line": (69, 36, 22)},
    "grey":   {"lip": (226, 226, 226), "body": ((146, 146, 146), (159, 159, 159)), "gloss": (216, 216, 216),
               "rim": (101, 101, 101), "line": (32, 32, 32)},
    "red":    {"lip": (255, 168, 150), "body": ((255, 46, 37), (255, 101, 64)), "gloss": (255, 122, 73),
               "rim": (196, 13, 29), "line": (62, 1, 11)},
    # The pressed red is not a darker red - it is a LIGHTER, washed one, which
    # is what makes it read as pushed in rather than as a different button.
    "red_pressed": {"lip": (255, 205, 190), "body": ((255, 116, 101), (250, 158, 119)), "gloss": (255, 178, 150),
                    "rim": (175, 60, 74), "line": (62, 1, 11)},
}

# file stem -> (palette, corner radius or None for a pill)
RECIPES = {
    "button_orange2": ("orange", None),
    "button_orange4": ("orange", None),
    "button_grey3":   ("grey", None),
    "button_red1":    ("red", None),
    "button_red2":    ("red_pressed", None),
}

# Geometry, as a fraction of the button's height, so one recipe covers a 62px
# pill and a 231px card without a second set of numbers.
SHADOW_DROP = 0.09
SHADOW_BLUR = 0.05
SHADOW_ALPHA = 163
OUTLINE = 0.055
RIM_HEIGHT = 0.16
GLOSS_TOP = 0.08
GLOSS_HEIGHT = 0.42
GLOSS_INSET = 0.055


def png_size(path):
    """Width and height without decoding the image."""
    with open(path, "rb") as f:
        return struct.unpack(">II", f.read(24)[16:24])


def _rounded(draw, box, radius, fill):
    # CLAMPED, not swapped for an ellipse. A pill asks for radius == height/2,
    # which is the exact case the old guard treated as "too round to be a
    # rounded rectangle" - so every pill came out a lens.
    half_w = (box[2] - box[0]) // 2
    half_h = (box[3] - box[1]) // 2
    draw.rounded_rectangle(box, radius=max(0, min(radius, half_w, half_h)), fill=fill)


def _gradient(size, top, bottom):
    """A vertical ramp. One column, stretched - the shape is masked in after."""
    w, h = size
    strip = Image.new("RGB", (1, h))
    px = strip.load()
    for y in range(h):
        t = y / max(1, h - 1)
        px[0, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return strip.resize((w, h), Image.BILINEAR)


def button(width, height, palette_name, radius=None):
    """One button at its final size, drawn big and reduced."""
    p = PALETTES[palette_name]
    s = SUPERSAMPLE
    w, h = width * s, height * s
    r = (h // 2) if radius is None else int(radius * s)

    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    # The body sits above the shadow, so it cannot fill the whole canvas.
    drop = int(h * SHADOW_DROP)
    body_box = (0, 0, w - 1, h - 1 - drop)
    body_h = body_box[3] - body_box[1]

    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    _rounded(sd, (body_box[0], body_box[1] + drop, body_box[2], body_box[3] + drop),
             r, (0, 0, 0, SHADOW_ALPHA))
    shadow = shadow.filter(ImageFilter.GaussianBlur(max(1, int(h * SHADOW_BLUR))))
    canvas.alpha_composite(shadow)

    # Outline, then the body inset inside it - drawing the dark shape first and
    # covering its middle is how the line stays an even width around a curve.
    plate = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pd = ImageDraw.Draw(plate)
    _rounded(pd, body_box, r, p["line"] + (255,))

    inset = max(1, int(h * OUTLINE))
    inner = (body_box[0] + inset, body_box[1] + inset,
             body_box[2] - inset, body_box[3] - inset)
    inner_r = max(1, r - inset)

    mask = Image.new("L", (w, h), 0)
    _rounded(ImageDraw.Draw(mask), inner, inner_r, 255)
    plate.paste(_gradient((w, h), *p["body"]), (0, 0), mask)

    # A pale stroke just inside the dark outline. Thin, and the thing that
    # makes the edge read as moulded rather than as a flat shape with a border.
    lip = Image.new("L", (w, h), 0)
    ld = ImageDraw.Draw(lip)
    _rounded(ld, inner, inner_r, 255)
    _rounded(ld, (inner[0] + inset, inner[1] + inset, inner[2] - inset, inner[3] - inset),
             max(1, inner_r - inset), 0)
    plate.paste(Image.new("RGBA", (w, h), p["lip"] + (255,)), (0, 0), lip)

    # The rim is the body's own shape, clipped to a band at the bottom.
    rim = Image.new("L", (w, h), 0)
    rd = ImageDraw.Draw(rim)
    _rounded(rd, inner, inner_r, 255)
    rd.rectangle((0, 0, w, int(body_box[3] - body_h * RIM_HEIGHT)), fill=0)
    plate.paste(Image.new("RGBA", (w, h), p["rim"] + (255,)), (0, 0), rim)

    # Gloss: the body's shape again, inset and cropped to the top, with its
    # alpha ramped away downwards so it reads as light falling on a curve
    # rather than a painted stripe. The ramp is multiplied INTO the mask - the
    # previous version composited it against itself and did nothing.
    gtop = int(body_box[1] + body_h * GLOSS_TOP)
    gbot = int(body_box[1] + body_h * (GLOSS_TOP + GLOSS_HEIGHT))
    # A FRACTION OF THE WIDTH. Scaling the inset off the corner radius made it
    # a small centred blob on a 136px pill, where the real one runs nearly the
    # whole width and tapers into the ends.
    gi = int(w * GLOSS_INSET)
    shape = Image.new("L", (w, h), 0)
    _rounded(ImageDraw.Draw(shape),
             (inner[0] + gi, gtop, inner[2] - gi, gbot), (gbot - gtop) // 2, 255)
    ramp = Image.new("L", (w, h), 0)
    rp = ramp.load()
    for y in range(h):
        if y <= gtop:
            v = 255
        elif y >= gbot:
            v = 0
        else:
            v = int(255 * (1.0 - (y - gtop) / max(1, gbot - gtop)) ** 1.6)
        for x in range(w):
            rp[x, y] = v
    gloss = Image.fromarray(
        (np.array(shape).astype(int) * np.array(ramp).astype(int) // 255).astype("uint8"))
    plate.paste(Image.new("RGBA", (w, h), p["gloss"] + (255,)), (0, 0), gloss)

    canvas.alpha_composite(plate)
    return canvas.resize((width, height), Image.LANCZOS)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if "--list" in sys.argv[1:]:
        print("  drawable, and the size each is held to by the art it replaces:")
        for stem, (pal, radius) in sorted(RECIPES.items()):
            path = os.path.join(OUT, stem + "@2x.png")
            size = "%dx%d" % png_size(path) if os.path.exists(path) else "MISSING"
            print("    %-18s %-9s %s" % (stem, size, pal))
        print()
        print("  NOT drawable here - geometry wrapped around an illustration:")
        print("    the 109x102 toolbar buttons, the 217x231 shop cards, the map")
        print("    plates. This tool can make their frames; the pictures inside")
        print("    them are art and stay art.")
        return

    for stem, (pal, radius) in sorted(RECIPES.items()):
        if args and not any(a in stem for a in args):
            continue
        path = os.path.join(OUT, stem + "@2x.png")
        if not os.path.exists(path):
            print("  %-18s no file to match - skipped" % stem)
            continue
        w, h = png_size(path)
        button(w, h, pal, radius).save(path)
        print("  %-18s %dx%d  %s" % (stem, w, h, pal))


if __name__ == "__main__":
    main()
