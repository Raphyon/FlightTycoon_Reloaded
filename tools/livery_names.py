#!/usr/bin/env python3
"""Name the paint schemes sheetfleet_derive.py wrote, and register them.

sheetfleet_derive.py writes every non-default scheme as body_alt<N>_2x.png,
because at that point nothing knows what the paint looks like. This reads the
art and gives each one a name, then rewrites that airframe's entry in
AircraftSkins.LIVERIES to match.

Run it after any install. It is safe to re-run: anything that is not the hull,
the shadow, or a freshly written alt is treated as a previous run's naming and
removed, which is what stops a re-installed airframe accumulating two
generations of paint side by side.

    python3 tools/livery_names.py a380-300 p51     # these keys
    python3 tools/livery_names.py                  # every key with alts
"""
import colorsys
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "game", "assets", "aircraft")
SKINS = os.path.join(ROOT, "game", "scripts", "aircraft_skins.gd")

# Hue bands, in degrees. Deliberately colours rather than airline names -
# nothing in the art says who any of these liveries are meant to belong to.
BANDS = [(0, 14, "crimson"), (14, 38, "amber"), (38, 66, "gold"),
         (66, 160, "emerald"), (160, 200, "teal"), (200, 255, "azure"),
         (255, 290, "violet"), (290, 330, "magenta"), (330, 361, "crimson")]


def name_of(path):
    """What to call this paint, read off the paint itself."""
    px = np.array(Image.open(path).convert("RGBA")).astype(float)
    rgb = px[:, :, :3][px[:, :, 3] > 60] / 255.0
    if not len(rgb):
        return "plain"
    step = max(1, len(rgb) // 4000)
    hsv = np.array([colorsys.rgb_to_hsv(*p) for p in rgb[::step]])
    # THE TOP DECILE OF SATURATION, not the average. Most of these aircraft are
    # mostly white fuselage; averaging over that calls every one of them
    # silver.
    strong = hsv[hsv[:, 1] > max(0.25, np.quantile(hsv[:, 1], 0.90))]
    if len(strong) < 20:
        return "silver"
    hue = float(np.median(strong[:, 0])) * 360
    val = float(np.median(strong[:, 2]))
    for lo, hi, nm in BANDS:
        if lo <= hue < hi:
            return "dark" + nm if val < 0.45 else nm
    return "silver"


def pretty(key):
    m = re.match(r"^(dark)?([a-z]+?)(\d+)?$", key)
    out = ("Dark " if m.group(1) else "") + m.group(2).capitalize()
    if m.group(3):
        out += " " + "II III IV V VI".split()[int(m.group(3)) - 2]
    return out


def rename(key):
    """altN -> its colour, dropping anything left from a previous run."""
    d = os.path.join(ART, key)
    for f in list(os.listdir(d)):
        if re.match(r"body_(?!alt\d+_2x\.png$).+_2x\.png$", f):
            os.remove(os.path.join(d, f))
            if os.path.exists(os.path.join(d, f + ".import")):
                os.remove(os.path.join(d, f + ".import"))
    names, used = [], set()
    for f in sorted(f for f in os.listdir(d) if re.match(r"body_alt\d+_2x\.png$", f)):
        n = name_of(os.path.join(d, f))
        base, i = n, 2
        while n in used:
            n = "%s%d" % (base, i)
            i += 1
        used.add(n)
        names.append(n)
        os.replace(os.path.join(d, f), os.path.join(d, "body_%s_2x.png" % n))
        if os.path.exists(os.path.join(d, f + ".import")):
            os.remove(os.path.join(d, f + ".import"))
    return names


def register(key, names):
    s = open(SKINS).read()
    entry = '\t"%s": [\n' % key
    for n in names:
        entry += ('\t\t{"key": "%s", "name": "%s",\n'
                  '\t\t\t"body": "res://assets/aircraft/%s/body_%s_2x.png"},\n'
                  % (n, pretty(n), key, n))
    entry += "\t],\n"
    existing = re.search(r'\t"%s": \[.*?\n\t\],\n' % re.escape(key), s, re.S)
    if existing:
        s = s.replace(existing.group(0), entry if names else "", 1)
    elif names:
        s = s.replace("const LIVERIES := {\n", "const LIVERIES := {\n" + entry, 1)
    open(SKINS, "w").write(s)


def main():
    keys = sys.argv[1:] or sorted(
        k for k in os.listdir(ART)
        if os.path.isdir(os.path.join(ART, k))
        and any(re.match(r"body_alt\d+_2x\.png$", f) for f in os.listdir(os.path.join(ART, k))))
    for key in keys:
        if not os.path.isdir(os.path.join(ART, key)):
            print("  %-13s no art folder" % key)
            continue
        names = rename(key)
        register(key, names)
        print("  %-13s %s" % (key, ", ".join(names) or "no alternates"))


if __name__ == "__main__":
    main()
