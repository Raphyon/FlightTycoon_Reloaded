#!/usr/bin/env python3
"""Rasterise the flat SVG icons pulled out of the source game.

There is no SVG renderer on this machine (no cairosvg, rsvg, inkscape or
ImageMagick) and Pillow can't read SVG, so the icons the user pulls out of the
original client have to be rasterised here. Hand-tracing them into polygons is
what this replaces - the paths are used exactly as authored.

Scope is deliberately small: filled paths with a solid `fill`, which is all
these icons are. No strokes, gradients, transforms or CSS - the one icon that
needs a gradient (the speed bolt) is handled in stat_icons.py instead.

Subpaths are combined even-odd rather than by SVG's default nonzero winding.
For these icons the two agree: the holes (keyhole, shackle opening) are simple
and don't overlap each other.

    python3 tools/svg_icon.py
"""
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SS = 4  # supersample factor
CURVE_STEPS = 12  # flattening resolution for a cubic segment

# What to build: source svg -> (output png, height in px).
ICONS = [
    (ROOT / "source-assets/hud/icon_lock.svg", ROOT / "game/assets/hud/icon_lock.png", 96),
]

_NUM = re.compile(r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")
_CMD = re.compile(r"([MmLlHhVvCcSsQqTtAaZz])")


def _nums(s):
    return [float(n) for n in _NUM.findall(s)]


def _cubic(p0, p1, p2, p3, out):
    for i in range(1, CURVE_STEPS + 1):
        t = i / CURVE_STEPS
        u = 1 - t
        out.append((
            u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
            u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1],
        ))


def _arc(p0, rx, ry, rot, large, sweep, p1, out):
    """SVG elliptical arc, endpoint -> centre parameterisation (F.6.5)."""
    if rx == 0 or ry == 0 or p0 == p1:
        out.append(p1)
        return
    rx, ry = abs(rx), abs(ry)
    phi = math.radians(rot)
    cos_p, sin_p = math.cos(phi), math.sin(phi)
    dx2, dy2 = (p0[0] - p1[0]) / 2, (p0[1] - p1[1]) / 2
    x1 = cos_p * dx2 + sin_p * dy2
    y1 = -sin_p * dx2 + cos_p * dy2

    # Scale up the radii if they're too small to span the endpoints.
    lam = x1 * x1 / (rx * rx) + y1 * y1 / (ry * ry)
    if lam > 1:
        rx *= math.sqrt(lam)
        ry *= math.sqrt(lam)

    num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
    den = rx * rx * y1 * y1 + ry * ry * x1 * x1
    coef = math.sqrt(max(0.0, num / den)) * (-1 if large == sweep else 1)
    cx1 = coef * rx * y1 / ry
    cy1 = -coef * ry * x1 / rx
    cx = cos_p * cx1 - sin_p * cy1 + (p0[0] + p1[0]) / 2
    cy = sin_p * cx1 + cos_p * cy1 + (p0[1] + p1[1]) / 2

    def angle(ux, uy):
        return math.atan2(uy, ux)

    th0 = angle((x1 - cx1) / rx, (y1 - cy1) / ry)
    th1 = angle((-x1 - cx1) / rx, (-y1 - cy1) / ry)
    dth = th1 - th0
    if not sweep and dth > 0:
        dth -= 2 * math.pi
    elif sweep and dth < 0:
        dth += 2 * math.pi

    steps = max(2, int(abs(dth) / (math.pi / 8)) + 1)
    for i in range(1, steps + 1):
        th = th0 + dth * i / steps
        ex, ey = rx * math.cos(th), ry * math.sin(th)
        out.append((cos_p * ex - sin_p * ey + cx, sin_p * ex + cos_p * ey + cy))


def parse_path(d):
    """Flatten a path's `d` into a list of subpaths, each a list of points."""
    tokens = [t for t in _CMD.split(d) if t.strip()]
    subpaths, cur = [], []
    x = y = 0.0
    start = (0.0, 0.0)
    prev_c2 = None  # second control point of the last cubic, for S/s
    cmd = None
    i = 0
    while i < len(tokens):
        if _CMD.fullmatch(tokens[i]):
            cmd = tokens[i]
            i += 1
            if cmd in "Zz":
                if cur:
                    subpaths.append(cur)
                    cur = []
                x, y = start
                prev_c2 = None
                continue
            args = _nums(tokens[i]) if i < len(tokens) else []
            i += 1
        else:
            args = _nums(tokens[i])
            i += 1

        rel = cmd.islower()
        c = cmd.upper()
        k = 0
        while k < len(args):
            if c == "M":
                nx, ny = args[k], args[k + 1]
                k += 2
                x, y = (x + nx, y + ny) if rel else (nx, ny)
                if cur:
                    subpaths.append(cur)
                cur = [(x, y)]
                start = (x, y)
                # Subsequent pairs after a moveto are implicit linetos.
                c = "L"
                prev_c2 = None
            elif c == "L":
                nx, ny = args[k], args[k + 1]
                k += 2
                x, y = (x + nx, y + ny) if rel else (nx, ny)
                cur.append((x, y))
                prev_c2 = None
            elif c == "H":
                nx = args[k]
                k += 1
                x = x + nx if rel else nx
                cur.append((x, y))
                prev_c2 = None
            elif c == "V":
                ny = args[k]
                k += 1
                y = y + ny if rel else ny
                cur.append((x, y))
                prev_c2 = None
            elif c in ("C", "S"):
                if c == "C":
                    c1 = (args[k], args[k + 1])
                    c2 = (args[k + 2], args[k + 3])
                    end = (args[k + 4], args[k + 5])
                    k += 6
                    if rel:
                        c1 = (x + c1[0], y + c1[1])
                        c2 = (x + c2[0], y + c2[1])
                        end = (x + end[0], y + end[1])
                else:
                    c2 = (args[k], args[k + 1])
                    end = (args[k + 2], args[k + 3])
                    k += 4
                    if rel:
                        c2 = (x + c2[0], y + c2[1])
                        end = (x + end[0], y + end[1])
                    # Reflect the previous control point through the current one.
                    c1 = (2 * x - prev_c2[0], 2 * y - prev_c2[1]) if prev_c2 else (x, y)
                _cubic((x, y), c1, c2, end, cur)
                prev_c2 = c2
                x, y = end
            elif c == "A":
                rx, ry, rot = args[k], args[k + 1], args[k + 2]
                large, sweep = bool(args[k + 3]), bool(args[k + 4])
                end = (args[k + 5], args[k + 6])
                k += 7
                if rel:
                    end = (x + end[0], y + end[1])
                _arc((x, y), rx, ry, rot, large, sweep, end, cur)
                x, y = end
                prev_c2 = None
            else:
                raise ValueError(f"unsupported path command {c!r}")
    if cur:
        subpaths.append(cur)
    return subpaths


def render(svg_path: Path, out_path: Path, height: int) -> None:
    svg = svg_path.read_text()
    vb = _nums(re.search(r'viewBox="([^"]+)"', svg).group(1))
    vw, vh = vb[2], vb[3]
    width = max(1, round(height * vw / vh))
    W, H = width * SS, height * SS
    scale = H / vh

    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for d, fill in re.findall(r'<path[^>]*\sd="([^"]+)"[^>]*\sfill="([^"]+)"', svg):
        mask = Image.new("L", (W, H), 0)
        for sub in parse_path(d):
            if len(sub) < 3:
                continue
            layer = Image.new("L", (W, H), 0)
            ImageDraw.Draw(layer).polygon(
                [((px - vb[0]) * scale, (py - vb[1]) * scale) for px, py in sub], fill=255
            )
            # Even-odd: a subpath inside another punches a hole.
            mask = Image.eval(Image.merge("L", [mask]), lambda v: v)  # copy
            mask = Image.frombytes("L", (W, H), bytes(
                a ^ b for a, b in zip(mask.tobytes(), layer.tobytes())
            ))
        rgb = fill.lstrip("#")
        colour = Image.new("RGBA", (W, H), tuple(int(rgb[j:j + 2], 16) for j in (0, 2, 4)) + (255,))
        img = Image.composite(colour, img, mask)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.resize((width, height), Image.LANCZOS).save(out_path)
    print(f"wrote {out_path.relative_to(ROOT)} {(width, height)}")


def main() -> None:
    for svg, out, height in ICONS:
        render(svg, out, height)


if __name__ == "__main__":
    main()
