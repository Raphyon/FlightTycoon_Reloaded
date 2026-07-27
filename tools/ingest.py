#!/usr/bin/env python3
"""
Ingest a raw Flight Tycoon asset dump into the repo layout and emit manifest.json.

Naming scheme (reverse-engineered):

  World sprites   aircraft_<model>_<slot>_2x.png
                    slot 1  -> body
                    slot 2  -> shadow   (alias: 's')
                    slot 3  -> prop/rotor blur, 2-frame strip w/ 4px gutter
  Shop icons      <model>[_<livery>].png
                    same render as the body, different livery,
                    with the shadow already composited in

Usage
  python tools/ingest.py --raw source-assets/raw            # dry run, report only
  python tools/ingest.py --raw source-assets/raw --apply    # copy into layout
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
from collections import defaultdict
from pathlib import Path

try:
    from PIL import Image
    import numpy as np
except ImportError:
    raise SystemExit("needs pillow + numpy:  pip install pillow numpy")

SLOT_NAMES = {"1": "body", "2": "shadow", "s": "shadow", "3": "prop"}

WORLD_RE = re.compile(r"^aircraft_(?P<model>.+?)_(?P<slot>\d+|s)_(?P<scale>\d+)x\.png$", re.I)
SHOP_RE = re.compile(r"^(?P<model>.+?)(?:_(?P<livery>[a-z]+|\d+))?\.png$", re.I)

GUTTER_MIN = 2  # empty columns that mark a frame boundary in a strip


def probe(path: Path) -> dict:
    """Measure the properties that actually matter for this asset set."""
    im = Image.open(path).convert("RGBA")
    a = np.array(im)
    alpha = a[:, :, 3]
    solid = alpha > 4

    info: dict = {"file": path.name, "width": im.width, "height": im.height}

    if not solid.any():
        info["empty"] = True
        return info

    ys, xs = np.nonzero(solid)
    info["bbox"] = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
    info["pad"] = [
        int(xs.min()),
        int(im.width - 1 - xs.max()),
        int(ys.min()),
        int(im.height - 1 - ys.max()),
    ]

    flat = int(np.bincount(alpha[solid]).argmax())
    info["flat_alpha"] = flat
    info["max_alpha"] = int(alpha.max())

    rgb = a[:, :, :3][alpha > 60]
    if len(rgb):
        info["mean_rgb"] = [round(float(v), 1) for v in rgb.mean(axis=0)]
        # a shadow is flat-alpha pure black; a prop blur is flat-alpha pure white
        if float(rgb.max()) < 30:
            info["kind_hint"] = "shadow"
        elif float(rgb.min()) > 240:
            info["kind_hint"] = "blur"

    # frame detection: look for fully empty column runs
    occupancy = solid.sum(axis=0)
    runs, start = [], None
    for x, v in enumerate(occupancy):
        if v == 0 and start is None:
            start = x
        elif v != 0 and start is not None:
            if x - start >= GUTTER_MIN:
                runs.append((start, x - 1))
            start = None
    inner = [r for r in runs if r[0] > 0 and r[1] < im.width - 1]
    if inner:
        info["frames"] = len(inner) + 1
        info["gutters"] = [[int(s), int(e)] for s, e in inner]
        info["cell_width"] = int(round(im.width / (len(inner) + 1)))

    return info


def classify(path: Path):
    m = WORLD_RE.match(path.name)
    if m:
        slot = m.group("slot").lower()
        return (
            "world",
            m.group("model").lower(),
            SLOT_NAMES.get(slot, f"slot{slot}"),
            int(m.group("scale")),
        )

    m = SHOP_RE.match(path.name)
    if m:
        livery = (m.group("livery") or "default").lower()
        if livery.isdigit():
            livery = "default"
        return "shop", m.group("model").lower(), livery, 1

    return None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default="source-assets/raw", type=Path)
    ap.add_argument("--out", default="source-assets", type=Path)
    ap.add_argument("--apply", action="store_true", help="actually copy files")
    args = ap.parse_args()

    if not args.raw.is_dir():
        raise SystemExit(f"no such directory: {args.raw}")

    models: dict[str, dict] = defaultdict(lambda: {"world": {}, "shop": {}})
    unmatched: list[str] = []

    for path in sorted(args.raw.rglob("*.png")):
        result = classify(path)
        if result is None:
            unmatched.append(path.name)
            continue

        category, model, key, scale = result
        entry = probe(path)
        entry["scale"] = scale
        entry["source"] = str(path.relative_to(args.raw))
        models[model][category][key] = entry

        if args.apply:
            if category == "world":
                dest = args.out / "aircraft" / model / f"{key}_{scale}x.png"
            else:
                dest = args.out / "shop" / f"{model}_{key}.png"
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, dest)

    manifest = {
        "schema": 1,
        "slot_map": SLOT_NAMES,
        "aircraft": {k: models[k] for k in sorted(models)},
        "unmatched": unmatched,
    }
    Path("manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    # ---- report -------------------------------------------------------
    print(f"{'model':<22} {'body':>5} {'shadow':>7} {'prop':>5}  liveries   notes")
    print("-" * 78)

    shadow_alphas: dict[str, int] = {}
    for model in sorted(models):
        world = models[model]["world"]
        shop = models[model]["shop"]
        notes = []

        if "shadow" in world:
            shadow_alphas[model] = world["shadow"]["flat_alpha"]
        if "prop" in world:
            frames = world["prop"].get("frames", 1)
            notes.append(f"prop {frames}f")
            if frames == 1:
                notes.append("!no gutter found")
        if not world:
            notes.append("shop icon only - no world sprites")

        print(
            f"{model:<22} "
            f"{'y' if 'body' in world else '-':>5} "
            f"{'y' if 'shadow' in world else '-':>7} "
            f"{'y' if 'prop' in world else '-':>5}  "
            f"{','.join(sorted(shop)) or '-':<10} "
            f"{'; '.join(notes)}"
        )

    if len(set(shadow_alphas.values())) > 1:
        print("\nWARNING  shadow opacity is inconsistent across the set:")
        for model, alpha in sorted(shadow_alphas.items(), key=lambda kv: kv[1]):
            print(f"  {model:<22} alpha {alpha:>3}  ({alpha / 255:.0%})")
        print("  normalise these before building, or your fleet will look uneven.")

    if unmatched:
        print(f"\n{len(unmatched)} file(s) did not match any known pattern:")
        for name in unmatched[:15]:
            print(f"  {name}")

    print(f"\nwrote manifest.json  ({len(models)} models)")
    if not args.apply:
        print("dry run - pass --apply to copy files into the layout")


if __name__ == "__main__":
    main()
