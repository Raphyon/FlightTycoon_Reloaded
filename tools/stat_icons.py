#!/usr/bin/env python3
"""Build the two stat icons the asset dump doesn't contain.

The shop card shows three stats - force, seats, fuel - each behind a small
icon. Fuel already has one (bubbles/drum_icon@2x.png, cut from the arrived
bubble sheet); the bolt and the seat did not, and are produced here.

PROVENANCE, and the two differ:

  stat_force  PLACEHOLDER. The bolt is the source game's own vector path,
              decoded from the SVG the user pulled out of it, so it is
              reverse-engineered like everything under source-assets/ and
              carries the same never-ship restriction. Path, gradient stops
              and the absence of a stroke are all the original's. Its gradient
              is named "speedGradient", which is what settled that the A-E
              grade behind this icon is speed - the visible label on the card
              reads "force", but the art says speed, and speed is what
              fleet.gd applies it to.

  stat_seat   PLACEHOLDER. The source game's own seat glyph, supplied by the
              user at 200x200 and kept at source-assets/hud/icon_seat@2x.png.
              This one used to be drawn here - a hand-built stand-in that read
              as a toilet rather than a seat - and is now just trimmed and
              downscaled from the real thing. Same never-ship restriction as
              the bolt.

The bolt is rasterised at 4x and downsampled so its diagonals antialias; the
seat is only trimmed and resized.

    python3 tools/stat_icons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "hud"
BOLT_SIZE = (16, 26)  # the real path is tall and narrow - aspect 0.584
SS = 4  # supersample factor

# The original fills the bolt with a vertical linear gradient and gives it no
# stroke at all - <linearGradient id="speedGradient" x1=0 y1=0 x2=0 y2=1>,
# #FABD53 at the top through to #F33127 at the bottom.
BOLT_TOP = (250, 189, 83, 255)
BOLT_BOTTOM = (243, 49, 39, 255)

# The source game's bolt, straight off its SVG path:
#   M226.8125 1024 l555.3 -664.606 H551.5995 L811.2205 0
#   h-391.21 L212.7785 554.9 h201 z
# in a 1024 viewBox, normalised to 0-1 here and scaled at draw time.
BOLT_VIEWBOX = 1024.0  # the source viewBox is 0 0 1024 1024
BOLT_PATH = [
    (226.8125, 1024.0), (782.1125, 359.394), (551.5995, 359.394),
    (811.2205, 0.0), (420.0105, 0.0), (212.7785, 554.9), (413.7785, 554.9),
]
# The seat is a real asset, not drawn - trimmed to its alpha bbox (148x180 of
# the supplied 200x200) and fitted to the icon height, so its own proportions
# survive rather than being stretched to the bolt's box.
SEAT_SRC = Path(__file__).resolve().parent.parent / "source-assets" / "hud" / "icon_seat@2x.png"
SEAT_HEIGHT = 26


def _bolt_points(size):
    """Fit the 1024-space path to `size`, preserving its aspect."""
    xs = [p[0] for p in BOLT_PATH]
    ys = [p[1] for p in BOLT_PATH]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    pad = 1.0  # room for the outline stroke
    sx = (size[0] - 2 * pad) / (x1 - x0)
    sy = (size[1] - 2 * pad) / (y1 - y0)
    return [(pad + (x - x0) * sx, pad + (y - y0) * sy) for x, y in BOLT_PATH]


def _seat(path: Path) -> None:
    """Trim the supplied seat glyph to its content and fit it to icon height."""
    src = Image.open(SEAT_SRC).convert("RGBA")
    src = src.crop(src.getchannel("A").getbbox())
    w = max(1, round(src.width * SEAT_HEIGHT / src.height))
    src.resize((w, SEAT_HEIGHT), Image.LANCZOS).save(path)
    print(f"wrote {path.relative_to(Path.cwd())} {(w, SEAT_HEIGHT)}")


def _draw_bolt(path: Path, size=BOLT_SIZE) -> None:
    """The speed bolt: source path, source gradient, no outline."""
    w, h = size[0] * SS, size[1] * SS
    mask = Image.new("L", (w, h), 0)
    pts = [(x * SS, y * SS) for x, y in _bolt_points(size)]
    ImageDraw.Draw(mask).polygon(pts, fill=255)

    grad = Image.new("RGBA", (w, h))
    for y in range(h):
        t = y / max(1, h - 1)
        grad.paste(
            tuple(round(a + (b - a) * t) for a, b in zip(BOLT_TOP, BOLT_BOTTOM)),
            (0, y, w, y + 1),
        )
    grad.putalpha(mask)
    grad.resize(size, Image.LANCZOS).save(path)
    print(f"wrote {path.relative_to(Path.cwd())} {size}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    _draw_bolt(OUT / "stat_force@2x.png")
    _seat(OUT / "stat_seat@2x.png")


if __name__ == "__main__":
    main()
