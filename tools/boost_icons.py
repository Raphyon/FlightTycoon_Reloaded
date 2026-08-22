#!/usr/bin/env python3
"""Boost item icons: a gold frame, the shop board's own fill, one glyph each.

PROVENANCE: ORIGINAL. Nothing in the dump is an item icon, so these are drawn
from scratch and ship, like tools/banshee_rotor.py and tools/afterburner.py.

BOTH PALETTES ARE SAMPLED, not invented, so these sit in the set rather than
near it:

  fill   #442418  the middle of board_changelist@ipad, the shop board
  gold   #E07D1B / #EFC508 / #FCF468  the shadow, body and highlight of
         icon_medium_coin@2x, taken at the 15th, 55th and 92nd percentile of
         its opaque luminance

WHAT THE GLYPHS ARE, and why these four: ROADMAP item 4 says a boost has to
attach to something that BINDS. Fuel does not - it is 1.3% of income - so there
is no fuel card here. Taps and time bind, and cash and XP are what the game
actually pays in.

  collect   coins with a sweep      claims a whole airport in one press
  speed     a stopwatch             halves flight times
  cash      a note with x2          doubles flight cash
  xp        a chevron badge with x2 doubles XP

Supersampled 8x and downscaled, which is how a bevelled rounded square gets a
clean edge out of Pillow.

    python3 tools/boost_icons.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "boosts"

SIZE = 64
SS = 8
RADIUS = 0.20          # corner radius as a fraction of the size
FRAME = 0.085          # gold border thickness, same fraction

FILL = (0x44, 0x24, 0x18)
GOLD_LO = (0xE0, 0x7D, 0x1B)
GOLD_MID = (0xEF, 0xC5, 0x08)
GOLD_HI = (0xFC, 0xF4, 0x68)
GLYPH = (0xFF, 0xF2, 0xD4)
GLYPH_DIM = (0xD8, 0xB0, 0x7A)


def _lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def frame(n: int) -> Image.Image:
    """The gold surround and the board-coloured well inside it."""
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = n * RADIUS
    # Gold body, graded top-left lit to bottom-right dark like the coin's bevel.
    steps = 48
    for i in range(steps):
        t = i / (steps - 1.0)
        inset = t * n * 0.045
        col = _lerp(GOLD_HI, GOLD_LO, t)
        d.rounded_rectangle([inset, inset, n - 1 - inset, n - 1 - inset],
                            radius=max(1.0, r - inset * 0.6), fill=col + (255,))
    # The well. Inset by the frame thickness, and a touch darker at the top so
    # the frame reads as standing proud of it rather than painted on.
    f = n * FRAME
    d.rounded_rectangle([f, f, n - 1 - f, n - 1 - f],
                        radius=max(1.0, r - f * 0.5), fill=FILL + (255,))
    shade = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(shade).rounded_rectangle(
        [f, f, n - 1 - f, f + n * 0.30], radius=max(1.0, r - f * 0.5),
        fill=(0, 0, 0, 60))
    img.alpha_composite(shade.filter(ImageFilter.GaussianBlur(n * 0.02)))
    return img


def _stopwatch(d: ImageDraw.ImageDraw, n: int) -> None:
    c, r = n / 2.0, n * 0.235
    d.ellipse([c - r, c - r + n * 0.03, c + r, c + r + n * 0.03],
              outline=GLYPH + (255,), width=int(n * 0.055))
    d.rectangle([c - n * 0.055, c - r - n * 0.06, c + n * 0.055, c - r + n * 0.01],
                fill=GLYPH + (255,))
    # Hands at ten past ten, the only pose where neither hides behind the other.
    d.line([c, c + n * 0.03, c - n * 0.10, c - n * 0.07], fill=GLYPH + (255,),
           width=int(n * 0.045))
    d.line([c, c + n * 0.03, c + n * 0.12, c - n * 0.02], fill=GLYPH + (255,),
           width=int(n * 0.038))


def _sweep(d: ImageDraw.ImageDraw, n: int) -> None:
    """A stack of coins with an arc sweeping them up.

    This was a hand coming down on the stack, which at 64px read as a vase. A
    hand needs fingers to be a hand, and there is no room for fingers here.
    """
    for i, y in enumerate((0.72, 0.63, 0.54)):
        w = n * (0.20 - i * 0.018)
        col = GLYPH_DIM if i < 2 else GLYPH
        d.ellipse([n * 0.5 - w, n * y - n * 0.042, n * 0.5 + w, n * y + n * 0.042],
                  fill=col + (255,))
    # The sweep: an arc over the stack, ending in a head, so it reads as
    # "all of these, at once" rather than as a pile sitting there.
    box = [n * 0.20, n * 0.14, n * 0.80, n * 0.62]
    d.arc(box, start=200, end=340, fill=GLYPH + (255,), width=int(n * 0.055))
    d.polygon([(n * 0.78, n * 0.28), (n * 0.86, n * 0.40), (n * 0.68, n * 0.40)],
              fill=GLYPH + (255,))


def _note(d: ImageDraw.ImageDraw, n: int) -> None:
    d.rounded_rectangle([n * 0.17, n * 0.27, n * 0.66, n * 0.55],
                        radius=n * 0.05, fill=GLYPH + (255,))
    d.ellipse([n * 0.345, n * 0.345, n * 0.475, n * 0.475], fill=FILL + (255,))


def _badge(d: ImageDraw.ImageDraw, n: int) -> None:
    # Two chevrons - the shape a level-up wears everywhere.
    for k, y in enumerate((0.20, 0.37)):
        col = GLYPH if k == 0 else GLYPH_DIM
        d.polygon([(n * 0.5, n * y), (n * 0.72, n * (y + 0.17)),
                   (n * 0.62, n * (y + 0.17)), (n * 0.5, n * (y + 0.08)),
                   (n * 0.38, n * (y + 0.17)), (n * 0.28, n * (y + 0.17))],
                  fill=col + (255,))


def _times_two(d: ImageDraw.ImageDraw, n: int) -> None:
    """x2 in the bottom right, drawn as strokes rather than typeset.

    The 2 was an ellipse OUTLINE in the first cut, which reads as x0 - which is
    the opposite of what a multiplier badge is for. It is a real digit now:
    a top arc, a diagonal down, and a foot.

    No system font. A tool that ships cannot depend on Arial being installed,
    and three strokes are cheaper than bundling a face.
    """
    x, y = n * 0.615, n * 0.635
    s = n * 0.072
    w = int(n * 0.05)
    # the x
    d.line([x - s, y - s, x + s, y + s], fill=GOLD_HI + (255,), width=w)
    d.line([x - s, y + s, x + s, y - s], fill=GOLD_HI + (255,), width=w)
    # the 2, to its right
    bx = x + s * 2.5
    top = y - s * 1.15
    d.arc([bx - s * 0.95, top, bx + s * 0.95, top + s * 1.5],
          start=160, end=20, fill=GOLD_HI + (255,), width=w)
    d.line([bx + s * 0.9, top + s * 0.75, bx - s * 0.9, y + s * 1.15],
           fill=GOLD_HI + (255,), width=w)
    d.line([bx - s * 0.95, y + s * 1.15, bx + s * 0.95, y + s * 1.15],
           fill=GOLD_HI + (255,), width=w)


GLYPHS = {
    "collect": (_sweep, False),
    "speed": (_stopwatch, False),
    "cash": (_note, True),
    "xp": (_badge, True),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    n = SIZE * SS
    base = frame(n)
    for name, (draw_glyph, multiplier) in GLYPHS.items():
        img = base.copy()
        layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        draw_glyph(d, n)
        if multiplier:
            _times_two(d, n)
        img.alpha_composite(layer)
        img = img.resize((SIZE, SIZE), Image.LANCZOS)
        img.save(OUT / ("boost_%s_2x.png" % name))
        print("  boost_%-9s %dx%d" % (name + "_2x.png", img.width, img.height))


if __name__ == "__main__":
    main()
