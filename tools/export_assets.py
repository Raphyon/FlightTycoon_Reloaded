#!/usr/bin/env python3
"""Export every asset to a browsable folder, sorted by WHO MADE IT.

WHY PROVENANCE IS THE TOP-LEVEL SPLIT
-------------------------------------
This project holds two kinds of art that look identical in a file browser and
are not remotely the same thing:

  * Art made FOR this project - source-assets/original/, the hand-made fleet
    that tools/newfleet_derive.py consumes, and the sheet art under
    source-assets/aircraft/aircraft/ that tools/sheetfleet_derive.py cuts up.
    No restriction.
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

    python3 tools/export_assets.py --audit       # what is left, copying nothing
    python3 tools/export_assets.py [destination] # the full browsable export
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

# Aircraft built from the sheet art without a DEFAULTS row, so nothing in the
# tools names them. Kept short and explained, because a hand-maintained list is
# exactly what the rest of this function exists to avoid.
HAND_INSTALLED_FROM_SHEET = {"skylink"}


def project_authored_sources():
    """Every aircraft key this project's own art covers, and the files it uses.

    Read out of the DERIVE TOOLS rather than listed here, so adding an aircraft
    to either table is enough - this cannot fall out of step with what actually
    gets built. There are two tools and it has to read both: newfleet_derive
    consumes flat renders, sheetfleet_derive cuts up the paint sheets, and for
    a while this only knew about the first. That misfiled 57 aircraft files and
    all 66 sheet sources as third-party.
    """
    names, keys = set(), set()

    src = open(os.path.join(ROOT, "tools", "newfleet_derive.py")).read()
    for block in ("MODELS", "LIVERY_OF_EXISTING"):
        m = re.search(r"%s = \{(.*?)\n\}" % block, src, re.S)
        if not m:
            continue
        for km in re.finditer(r'"([\w.-]+)":\s*\(\d+,\s*\{(.*?)\}\)', m.group(1), re.S):
            keys.add(km.group(1))
            names.update(re.findall(r'"\w+":\s*"([\w.-]+\.png)"', km.group(2)))

    sheet = open(os.path.join(ROOT, "tools", "sheetfleet_derive.py")).read()
    # DEFAULTS is keyed by SHEET GROUP; KEYS maps the ones whose group name is
    # not our catalogue key. SKIP is a group deliberately left on older art, so
    # it is not evidence of anything and is excluded.
    remap = dict(re.findall(r'"([\w.-]+)":\s*"([\w.-]+)"',
                            re.search(r"KEYS = \{(.*?)\n\}", sheet, re.S).group(1)))
    skipped = set(re.findall(r'"([\w.-]+)"',
                             re.search(r"SKIP = \{(.*?)\n\}", sheet, re.S).group(1)))
    groups = re.findall(r'\n    "([\w.-]+)":\s*\(\d+,',
                        re.search(r"DEFAULTS = \{(.*?)\n\}", sheet, re.S).group(1))
    for g in groups:
        if g not in skipped:
            keys.add(remap.get(g, g))

    # UI furniture DRAWN by tools/ui_derive.py rather than cut from the dump.
    # Read out of its RECIPES table for the same reason as the two fleet tools.
    ui = open(os.path.join(ROOT, "tools", "ui_derive.py")).read()
    drawn = set()
    for table in ("RECIPES", "GLYPHS"):
        m = re.search(r"%s = \{(.*?)\n\}" % table, ui, re.S)
        if m:
            drawn.update(re.findall(r'\n    "([\w.-]+)":\s*\("', m.group(1)))

    # Installed from the sheet source by hand rather than through DEFAULTS -
    # the Skylink came in as aircraft_a300_1/_2/_s, which is a different
    # aircraft from the A300 whose sheet those files sit beside.
    keys.update(HAND_INSTALLED_FROM_SHEET)
    keys.update(drawn)
    return names, keys


def classify(rel_path, mine_sources, mine_keys):
    """(bucket, why) for one asset, from its path inside the repo."""
    parts = rel_path.replace("\\", "/").split("/")
    base = parts[-1]

    if parts[0] == "source-assets":
        if len(parts) > 1 and parts[1] == "original":
            return "mine", "made for this project (source-assets/original)"
        # The paint sheets. Nested inside aircraft/ because that is where they
        # arrived, not because they share its provenance - everything else in
        # aircraft/ is ingest.py output from the third-party dump.
        if parts[1:3] == ["aircraft", "aircraft"]:
            return "mine", "made for this project (sheet art)"
        if base in mine_sources:
            return "mine", "hand-made fleet source (see newfleet_derive.py)"
        return "placeholder", "reverse-engineered from third-party game"

    # game/assets is all derived, so it inherits whatever it came FROM. Paths
    # here run game/assets/<category>/..., so the category is parts[2] and a
    # model folder - aircraft/crj700/ - is parts[3].
    category = parts[2] if len(parts) > 2 else ""
    if category == "aircraft" and len(parts) > 3 and parts[3] in mine_keys:
        return "mine", "derived from own art (%s)" % parts[3]
    # Drawn UI keeps its filename, so the stem is the key.
    if category == "buttons" and base.rsplit("@", 1)[0] in mine_keys:
        return "mine", "drawn by ui_derive.py"
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


def scan():
    """Every PNG in both trees, classified. (rel_path, bucket, why, tree)."""
    mine_sources, mine_keys = project_authored_sources()
    out = []
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
                out.append((full, rel, bucket, why, tree, label))
    return out


def audit():
    """What is left to replace, without copying a thing.

    The export answers the same question but only by writing a thousand files
    to another folder first, which is too much ceremony to run often - so the
    number went unchecked for weeks and drifted. This is the cheap version, and
    it is the one to run while replacing art.
    """
    rows = scan()
    shipped = [r for r in rows if r[4] == GAME_ASSETS]
    by_category = {}
    for _full, rel, bucket, _why, _tree, _label in shipped:
        parts = rel.split(os.sep)
        category = parts[2] if len(parts) > 2 else "?"
        tally = by_category.setdefault(category, [0, 0])
        tally[0 if bucket == "mine" else 1] += 1

    print("  THE SHIPPED TREE - game/assets")
    print("  %-16s %6s %6s" % ("category", "mine", "dump"))
    for category, (mine, dump) in sorted(by_category.items(), key=lambda kv: -kv[1][1]):
        mark = "" if dump else "   done"
        print("  %-16s %6d %6d%s" % (category, mine, dump, mark))
    mine = sum(v[0] for v in by_category.values())
    dump = sum(v[1] for v in by_category.values())
    print("  %-16s %6d %6d" % ("TOTAL", mine, dump))
    print()
    print("  %d of %d still to replace before this can ship." % (dump, mine + dump))

    both = len(rows)
    all_mine = sum(1 for r in rows if r[2] == "mine")
    print("  (both trees together: %d mine, %d placeholder, %d files)"
          % (all_mine, both - all_mine, both))


def export(dest):
    rows = []
    for full, rel, bucket, why, tree, label in scan():
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


def main():
    args = [a for a in sys.argv[1:] if a != "--audit"]
    if "--audit" in sys.argv[1:]:
        audit()
        return
    export(args[0] if args else DEFAULT_DEST)


if __name__ == "__main__":
    main()
