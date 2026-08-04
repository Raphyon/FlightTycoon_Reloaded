#!/usr/bin/env python3
"""Turn the new hand-made aircraft art into world sprites, shadows and shop icons.

These came in as ~1024px renders with clean alpha and NO shadow, so each one
needs cropping, scaling to the game's sprite scale, and a ground shadow
derived to match the ones already in the game.

PROVENANCE: like source-assets/original/, this art was made FOR this project
and carries none of the placeholder-only restriction the rest of source-assets
does.

SIZE is set by HEIGHT, not width - same reasoning as plane_derive.py's ORIGINAL
table. These renders are drawn at a steeper angle than the old shop icons, so
matching a width makes them tower over the fleet: the A380 came out 152px tall
against the existing fleet's 110-112 ceiling. Heights are set relative to each
other so the fleet keeps one size hierarchy, and the widths that fall out are
printed so they can be checked against the 220x110 apron tile.

The shadow recipe matches plane_derive.py so new aircraft sit correctly beside
old ones: the airframe's own silhouette, flattened to black at SHADOW_PEAK_ALPHA
and squashed vertically onto the ground plane.

The balloon is the exception and gets an ellipse instead - see balloon_shadow.

    python3 tools/newfleet_derive.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "source-assets", "aircraft")
OUT = os.path.join(ROOT, "game", "assets", "aircraft")
SHOP = os.path.join(ROOT, "game", "assets", "shop")

# Same values plane_derive.py uses, so the new fleet matches the old.
SHADOW_PEAK_ALPHA = 150
SHADOW_SQUASH = 0.80

# The shop card fits its icon into an 80x70 box with KEEP_ASPECT_CENTERED, so
# the icon's own pixel size only sets its sharpness. The existing icons run
# 1.0-1.35x their world sprite; this sits in that range.
SHOP_ICON_SCALE = 1.2

# key -> (target sprite HEIGHT, {output name: source file})
#
# Heights carry the fleet's size hierarchy: the existing fleet runs 83 (328 Jet)
# to 112 (An-225, the largest airframe), and these are placed inside that.
MODELS = {
    # 46 was "a paper plane is tiny", which is true and unhelpful - at 89x46 it
    # read as a speck on a 220x110 pad, less than half the height of the next
    # smallest aircraft. 70 keeps it clearly the littlest thing in the fleet
    # while still occupying its pad.
    "paperplane": (70, {"body": "paper_airplane_default.png",
                        "body_dollar": "paper_airplane_dollar.png"}),
    # The one aircraft allowed past the ceiling: a balloon is tall by nature,
    # and squashing it to airliner height would read as a beach ball.
    "balloon":    (132, {"body": "hot_air_ballon.png"}),
    "f15":        (76, {"body": "f15_eagle_default.png"}),
    "dc3":        (78, {"body": "dc3_default.png", "body_duggy": "dc3_duggy.png"}),
    "emb120":     (84, {"body": "emb_120_default.png"}),
    "dhc8":       (88, {"body": "dhc8_qantas.png"}),
    "atr72":      (88, {"body": "atr_72_default.png"}),
    "an140":      (86, {"body": "an_140_default.png"}),
    "uss51":      (84, {"body": "uss_51_default.png"}),
    "crj700":     (86, {"body": "crj_700_default.png", "body_sas": "crj_700_sas.png"}),
    "ncc1701":    (88, {"body": "ncc_1701_default.png"}),
    "x37b":       (94, {"body": "x_37b_default.png"}),
    "concorde":   (88, {"body": "concorde_zebra.png",
                        "body_firebird": "concorde_firebird.png"}),
    "dc6":        (92, {"body": "dc6_default.png"}),
    "tu104":      (92, {"body": "tu104_default.png",
                        "body_beard": "tu104_beardlivery.png"}),
    "b727":       (92, {"body": "b727_default.png", "body_welcome": "b727_welcome.png"}),
    "b707":       (96, {"body": "b707_default.png"}),
    "dc10":       (100, {"body": "dc10_default.png"}),
    "b787":       (104, {"body": "b787_default.png", "body_klm": "b787_klm.png"}),
    "b747":       (112, {"body": "b747_default.png", "body_yellow": "b747_yellow.png"}),
}

# Not a model of its own. The A380 we already have is an airline livery of the
# same airframe (user's call), so this blue-and-magenta one is a second livery
# rather than a second aircraft - it lands in the existing folder and reuses
# that model's shadow. Height matches a380-300's body exactly, because a livery
# that changes size would jump when you switch to it.
LIVERY_OF_EXISTING = {
    "a380-300": (110, {"body_midnight": "a380_300_default.png"}),
}


def load_trimmed(name: str) -> Image.Image:
    img = Image.open(os.path.join(SRC, name)).convert("RGBA")
    box = img.getchannel("A").getbbox()
    return img.crop(box) if box else img


def scaled_to_height(img: Image.Image, height: int) -> Image.Image:
    width = max(1, round(img.width * height / img.height))
    return img.resize((width, height), Image.LANCZOS)


def silhouette_shadow(body: Image.Image) -> Image.Image:
    """The airframe's own outline, flattened and laid on the ground."""
    alpha = np.array(body)[:, :, 3].astype(float)
    sil = np.zeros((body.height, body.width, 4), dtype=np.uint8)
    sil[:, :, 3] = (alpha / max(alpha.max(), 1) * SHADOW_PEAK_ALPHA).astype(np.uint8)
    out = Image.fromarray(sil, "RGBA")
    out = out.resize((out.width, max(1, int(out.height * SHADOW_SQUASH))), Image.LANCZOS)
    box = out.getbbox()
    return out.crop(box) if box else out


def balloon_shadow(body: Image.Image) -> Image.Image:
    """A balloon can't use its own silhouette.

    Everything else here sits ON the ground, so its outline IS roughly its
    shadow. A balloon's envelope is metres above it: flattening the silhouette
    would print a teardrop on the tarmac - wide where the envelope is, tapering
    to the basket - which is not a shape any light source could cast.

    What it actually casts is the envelope's widest cross-section, so this
    takes that width, draws it as an ellipse on the ground plane, and blurs the
    edge because a shadow thrown from that height has no crisp outline.
    """
    alpha = np.array(body)[:, :, 3]
    rows = [np.where(row > 24)[0] for row in alpha]
    widths = [(r.max() - r.min() + 1) if r.size else 0 for r in rows]
    envelope = max(widths)

    # Narrower than the envelope itself: an isometric view looks along the
    # light, so the cast ellipse reads smaller than the widest slice.
    w = max(2, int(envelope * 0.78))
    h = max(2, int(w * 0.52))          # ground-plane foreshortening
    pad = max(2, w // 12)
    out = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(out).ellipse(
        (pad, pad, pad + w, pad + h), fill=(0, 0, 0, SHADOW_PEAK_ALPHA))
    return out.filter(ImageFilter.GaussianBlur(max(1.0, w / 22.0)))


def write_bodies(folder: str, height: int, parts: dict) -> int:
    os.makedirs(folder, exist_ok=True)
    made = 0
    for out_name, src_name in parts.items():
        if not os.path.exists(os.path.join(SRC, src_name)):
            print("  MISSING %s" % src_name)
            continue
        body = scaled_to_height(load_trimmed(src_name), height)
        body.save(os.path.join(folder, "%s_2x.png" % out_name))
        made += 1
    return made


def main() -> None:
    made = 0
    for key, (height, parts) in MODELS.items():
        folder = os.path.join(OUT, key)
        made += write_bodies(folder, height, parts)

        # One shadow per model, from its default body - a livery repaints the
        # hull without changing its outline.
        base = Image.open(os.path.join(folder, "body_2x.png")).convert("RGBA")
        shadow = balloon_shadow(base) if key == "balloon" else silhouette_shadow(base)
        shadow.save(os.path.join(folder, "shadow_2x.png"))

        # Shop icon: the same art again, a touch larger so the card stays crisp.
        icon = scaled_to_height(base, int(height * SHOP_ICON_SCALE))
        icon.save(os.path.join(SHOP, "%s_default.png" % key))

        print("  %-11s body %-9s shadow %-9s icon %s%s" % (
            key, "%dx%d" % base.size, "%dx%d" % shadow.size,
            "%dx%d" % icon.size, "   (ellipse)" if key == "balloon" else ""))

    for key, (height, parts) in LIVERY_OF_EXISTING.items():
        n = write_bodies(os.path.join(OUT, key), height, parts)
        made += n
        print("  %-11s +%d livery body (reuses the model's shadow)" % (key, n))

    print("\n%d sprites across %d models" % (made, len(MODELS)))


if __name__ == "__main__":
    main()
