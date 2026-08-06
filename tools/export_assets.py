#!/usr/bin/env python3
"""Export every asset to a browsable folder, sorted by WHO MADE IT.

WHY PROVENANCE IS THE TOP-LEVEL SPLIT
-------------------------------------
This project holds two kinds of art that look identical in a file browser and
are not remotely the same thing:

  * Art made FOR this project - source-assets/original/, and the hand-made
    fleet that tools/newfleet_derive.py consumes. No restriction.
  * Art reverse-engineered from a discontinued third-party game, used as
    placeholder while the systems get built. Documented throughout the repo as
    never shippable.

Sorting by category alone - all the aircraft together, all the UI together -
puts those side by side and loses the only distinction that decides what can
leave the machine. So provenance is the top folder and category is the second,
which happens to preserve the existing category layout anyway.

PNG only - the SVGs, the JPG login backdrop, Godot's .import sidecars and any
editor "~" backups are all left behind. Originals are never touched; everything
here is a copy.

    python3 tools/export_assets.py [destination]
"""
import csv
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME_ASSETS = os.path.join(ROOT, "game", "assets")
SOURCE_ASSETS = os.path.join(ROOT, "source-assets")
DEFAULT_DEST = os.path.expanduser("~/Documents/ft-proto-assets")

# PNG only. The trees also hold a handful of SVGs (the affinity star and bar,
# the options gear), a JPG login backdrop, and editor backup files ending in
# "~" - none of which are wanted in a browsable dump of the art.
KEEP_SUFFIX = ".png"


def project_authored_sources():
    """What tools/newfleet_derive.py declares as made for this project.

    Read out of the tool rather than listed here, so adding an aircraft to that
    table is enough - this cannot fall out of step with what actually gets
    derived.
    """
    src = open(os.path.join(ROOT, "tools", "newfleet_derive.py")).read()
    names, keys = set(), set()
    for block in ("MODELS", "LIVERY_OF_EXISTING"):
        m = re.search(r"%s = \{(.*?)\n\}" % block, src, re.S)
        if not m:
            continue
        for km in re.finditer(r'"([\w.-]+)":\s*\(\d+,\s*\{(.*?)\}\)', m.group(1), re.S):
            keys.add(km.group(1))
            names.update(re.findall(r'"\w+":\s*"([\w.-]+\.png)"', km.group(2)))
    return names, keys


def classify(rel_path, mine_sources, mine_keys):
    """(bucket, why) for one asset, from its path inside the repo."""
    parts = rel_path.replace("\\", "/").split("/")
    base = parts[-1]

    if parts[0] == "source-assets":
        if len(parts) > 1 and parts[1] == "original":
            return "mine", "made for this project (source-assets/original)"
        if base in mine_sources:
            return "mine", "hand-made fleet source (see newfleet_derive.py)"
        return "placeholder", "reverse-engineered from third-party game"

    # game/assets is all derived, so it inherits whatever it came FROM. Paths
    # here run game/assets/<category>/..., so the category is parts[2] and a
    # model folder - aircraft/crj700/ - is parts[3].
    category = parts[2] if len(parts) > 2 else ""
    if category == "aircraft" and len(parts) > 3 and parts[3] in mine_keys:
        return "mine", "derived from own art (%s)" % parts[3]
    if category == "shop" and base.endswith("_default.png"):
        key = base[: -len("_default.png")]
        if key in mine_keys:
            return "mine", "derived from own art (%s)" % key
    return "placeholder", "derived from third-party placeholder art"


README = """ft-proto assets
===============

A copy of every asset in the project, sorted by provenance first and category
second. Nothing here is linked to the repo - editing these files changes
nothing in the game.

  mine/         Art made FOR this project. No restrictions.
    source/       the originals, mostly 1024px
    game-ready/   what the game actually loads - scaled sprites, shadows,
                  shop icons, livery variants

  placeholder/  Reverse-engineered from a discontinued third-party game and
                used as placeholder while the systems get built. NOT
                SHIPPABLE - this is the half that still needs replacing.
    source/       includes raw/, the untouched dump kept for reference
    game-ready/

MANIFEST.csv lists every file with its original path in the repo and why it
landed in the bucket it did.

PNG only. The few SVGs (affinity star and bar, options gear), the JPG login
backdrop and Godot's .import sidecars are not included.

Regenerate with:  python3 tools/export_assets.py [destination]
"""


def main():
    dest = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DEST
    mine_sources, mine_keys = project_authored_sources()

    rows = []
    for tree, label in [(GAME_ASSETS, "game-ready"), (SOURCE_ASSETS, "source")]:
        for dirpath, _dirs, files in os.walk(tree):
            for name in sorted(files):
                # Catches .DS_Store, .import sidecars, .svg, .jpg and the "~"
                # backups in one rule.
                if not name.lower().endswith(KEEP_SUFFIX):
                    continue
                full = os.path.join(dirpath, name)
                rel = os.path.relpath(full, ROOT)
                bucket, why = classify(rel, mine_sources, mine_keys)
                out = os.path.join(dest, bucket, label, os.path.relpath(full, tree))
                os.makedirs(os.path.dirname(out), exist_ok=True)
                shutil.copy2(full, out)
                rows.append([bucket, label, os.path.relpath(out, dest), rel, why])

    rows.sort()
    with open(os.path.join(dest, "MANIFEST.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["bucket", "kind", "exported path", "repo path", "provenance"])
        w.writerows(rows)
    with open(os.path.join(dest, "README.txt"), "w") as f:
        f.write(README)

    mine = sum(1 for r in rows if r[0] == "mine")
    print("  exported %d files to %s" % (len(rows), dest))
    print("    mine        %4d" % mine)
    print("    placeholder %4d" % (len(rows) - mine))


if __name__ == "__main__":
    main()
