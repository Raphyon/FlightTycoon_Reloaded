#!/usr/bin/env python3
"""Seed data/zone_regions.json with seven bands of six building plots.

WHY BANDS AND NOT BLOCKS. 42 = 6 x 7 and 7 is prime, so seven equal groups are
strips of six and six equal groups are strips of seven - a square-ish block of
six is 2x3, and 2x3 does not tile a 6x7 rectangle. Squares were never available.
The district is also a diamond rather than a rectangle (its rows run
1,2,2,3,4,5,6,5,4,4,3,2,1), so the bands follow the ISOMETRIC DIAGONAL, which
means they run along the city's streets instead of cutting across them.

BANDS ARE ORDERED DOWN THE SCREEN - Zone1 the top strip, Snow the bottom one.
They were first ordered by distance from the terminal, which sounded better than
it read: diagonal strips all sit at similar range, so the middle five came out
433/493/499/525/532 apart and the sequence looked arbitrary. Top to bottom is a
thing you can see.

WHY IT ONLY HAS TO BE RIGHT AT THE PLOTS. ZoneRegions.area_at is only ever asked
about plot positions, so two bands overlapping in empty ground is harmless. That
is what makes a plain convex hull good enough here - no polygon union, no
staircase boundary - and the check at the end is the thing that actually
matters: every plot must land in the band it was assigned to.

Re-runnable; it overwrites homeland's regions and leaves other maps alone.
Adjust by hand afterwards with the Z editor in game.

    python3 tools/zone_bands.py
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "game", "data")
MAP = "homeland"

# Top strip first. Zone1 is included: it is where the game starts, so its six
# plots are the ones available as soon as the Prop Shop opens at Zone2.
ORDER = ["Zone1", "Zone2", "DarkZone", "Forest", "Desert", "Beach", "Snow"]
PER_BAND = 6

# Isometric tile half-width and half-height - the lattice the plots sit on.
HALF_W, HALF_H = 128.0, 64.0
# How far a band's outline sits outside its plots. Under half a tile, so a band
# cannot reach the next row of plots along.
INFLATE = 52.0


def load(name):
    with open(os.path.join(DATA, name)) as f:
        return json.load(f)


def hull(points):
    pts = sorted(set(points))
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    def half(seq):
        out = []
        for p in seq:
            while len(out) >= 2 and cross(out[-2], out[-1], p) <= 0:
                out.pop()
            out.append(p)
        return out

    return half(pts)[:-1] + half(pts[::-1])[:-1]


def inflate(poly, by):
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    out = []
    for x, y in poly:
        d = math.hypot(x - cx, y - cy) or 1.0
        out.append((x + (x - cx) / d * by, y + (y - cy) / d * by))
    return out


def inside(point, poly):
    """Even-odd test, matching Geometry2D.is_point_in_polygon closely enough."""
    x, y = point
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def main() -> None:
    plots = load("building_layout.json")[MAP]

    # Sorted DOWN THE SCREEN, then across it. Screen y is what "top" means to
    # someone looking at the map, and in this projection it rises with u + v -
    # so this both stacks the bands correctly and keeps each one contiguous.
    cells = []
    for p in plots:
        x, y = float(p["x"]), float(p["y"])
        u = round((x / HALF_W + y / HALF_H) / 2)
        v = round((-x / HALF_W + y / HALF_H) / 2)
        cells.append((u + v, u - v, x, y, int(p["id"])))
    cells.sort()

    groups = [cells[i * PER_BAND:(i + 1) * PER_BAND]
              for i in range(len(cells) // PER_BAND)]
    leftover = cells[len(groups) * PER_BAND:]
    if leftover:
        groups[-1].extend(leftover)

    # Already in top-to-bottom order from the sort above, so ORDER maps
    # straight on: Zone1 is the top strip, Snow the bottom one.

    regions = {}
    for name, group in zip(ORDER, groups):
        poly = inflate(hull([(c[2], c[3]) for c in group]), INFLATE)
        regions[name] = [[round(x, 1), round(y, 1)] for x, y in poly]

    # THE CHECK THAT MATTERS: every plot lands in the band it was given.
    want = {}
    for name, group in zip(ORDER, groups):
        for c in group:
            want[c[4]] = name
    wrong = []
    for p in plots:
        pid = int(p["id"])
        pt = (float(p["x"]), float(p["y"]))
        got = ""
        for name in ORDER:
            if inside(pt, [tuple(q) for q in regions[name]]):
                got = name
                break
        if got != want[pid]:
            wrong.append((pid, want[pid], got or "none"))

    path = os.path.join(DATA, "zone_regions.json")
    all_data = {}
    if os.path.exists(path):
        with open(path) as f:
            all_data = json.load(f)
    all_data[MAP] = regions
    with open(path, "w") as f:
        json.dump(all_data, f, indent="\t")

    print("  %d bands of %d written to data/zone_regions.json" % (len(groups), PER_BAND))
    for name, group in zip(ORDER, groups):
        ys = sum(c[3] for c in group) / len(group)
        print("    %-9s %d plots   screen y %4.0f   ids %s"
              % (name, len(group), ys, sorted(c[4] for c in group)))
    if wrong:
        print("\n  MISASSIGNED %d - lower INFLATE and re-run:" % len(wrong))
        for pid, w, g in wrong:
            print("    plot %-3d wanted %-9s got %s" % (pid, w, g))
    else:
        print("\n  all %d plots land in their own band" % len(plots))


if __name__ == "__main__":
    main()
