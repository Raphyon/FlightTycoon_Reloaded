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
from scipy import ndimage
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
    # Twin Otter, on floats. 84 rather than the DC-3's 78 because a chunk of
    # this render's height is float and strut rather than airframe - matched on
    # how big the fuselage reads, not on the bounding box.
    "dhc6":       (84, {"body": "dhc_6_twin_otter.png"}),
    "atr72":      (88, {"body": "atr_72_default.png",
                        "body_cloudy": "atr_72_cloudy.png",
                        "body_metaliminal": "atr_72_metaliminal.png",
                        "body_pinkdreams": "atr_72_pinkdreams.png"}),
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
    "b787":       (104, {"body": "b787_default.png", "body_klm": "b787_klm.png",
                         "body_flash": "b787_flash.png",
                         "body_sharky": "b787_sharky.png"}),
    "b747":       (112, {"body": "b747_default.png", "body_yellow": "b747_yellow.png"}),
    # Four rear-mounted engines and a T-tail, 43m span - the same class as the
    # B707 above it and the A300, so it takes their height.
    # 60.3m span, near enough the B787's 60.1 to take its height. Four engines
    # and a wing that long is the top of the airliner class, under the 747s.
    # 35.1m span, a hair over the A318's 34.1 - the smallest airliners in the
    # fleet, and it sits just above them.
    "a220":       (92, {"body": "a220_default.png"}),
    # 64.75m span, near enough the 747-8's 64.4 to take its height band. Five
    # liveries: four off a 2x2 sheet, plus SAS supplied on its own.
    # 64.8m span, the longest twinjet there is - between the A350's 108 and the
    # 747-8's 112. Three liveries off one sheet.
    # THE FIRST TWO PAST LEVEL 50. Both are Snow's, and both are polar aircraft
    # rather than more airliners - see ROADMAP item 10 for why the tail entries
    # are matched to the zone they open.
    #
    # An-74: 31.9m span, so it sits with the A318 at the small end. Engines
    # mounted ABOVE the wing, which is the whole silhouette.
    "an74":       (88, {"body": "an74_default.png"}),
    # LC-130 on skis: 40.4m span, just under the A400M's 42.4, so just under
    # its 96.
    "lc130":      (94, {"body": "lockheed_lc130_hercules.png"}),
    "b777-300er": (110, {"body": "b777_300er_default.png",
                         "body_delta": ("b777_300er_liveries.png", 0),
                         "body_emirates": ("b777_300er_liveries.png", 1),
                         "body_ana": ("b777_300er_liveries.png", 2)}),
    "a350-900":   (108, {"body": "a350_900_default.png",
                         "body_global": ("a350_900_liveries.png", 0),
                         "body_arctic": ("a350_900_liveries.png", 1),
                         "body_safari": ("a350_900_liveries.png", 2),
                         "body_oceanic": ("a350_900_liveries.png", 3),
                         "body_sas": "a350_900_sas.png"}),
    "a340-300":   (104, {"body": "a340_300_default.png",
                         "body_celestial": "a340_300_celestial.png",
                         "body_global": "a340_300_global.png"}),
    # A bigger A400M - 51.7m span against 42.4 - so it sits above it at the
    # DC-10's height rather than taking the A400M's 96.
    # Five liveries off a sheet. They measure 2.7-4.9% wider than the default,
    # more than the ATR's 0.5% or the 777's 1% - the sheet was drawn a little
    # apart from the original render. Pinning them to the body's size takes
    # that out, which is what keeps the aircraft still when you change paint;
    # the cost is about 4px of vertical stretch on a 100px sprite.
    "c17":        (100, {"body": "c_17_globemaster.png",
                         "body_house": ("c_17_globemaster_liveries.png", 0),
                         "body_military": ("c_17_globemaster_liveries.png", 1),
                         "body_globecargo": ("c_17_globemaster_liveries.png", 2),
                         "body_atlas": ("c_17_globemaster_liveries.png", 3),
                         "body_express": ("c_17_globemaster_liveries.png", 4)}),
    "il62":       (96, {"body": "il_62_default.png",
                        "body_zipped": "il_62_zipped.png"}),
    # A gunship, not an airliner: sized between the Black Hawk at 86 and the
    # V-22 at 99, since it reads heavier than one and smaller than the other.
    #
    # ITS ROTORS ARE PAINTED INTO THE BODY and it has no prop strip, so they do
    # not turn yet. RotorEditor (kept for exactly this) places the discs by
    # hand - see the readme; nothing in this project guesses at placements.
    "banshee":    (92, {"body": "banshee_default.png"}),
}

# Not a model of its own. The A380 we already have is an airline livery of the
# same airframe (user's call), so this blue-and-magenta one is a second livery
# rather than a second aircraft - it lands in the existing folder and reuses
# that model's shadow. Height matches a380-300's body exactly, because a livery
# that changes size would jump when you switch to it.
LIVERY_OF_EXISTING = {
    "a380-300": (110, {"body_midnight": "a380_300_default.png"}),
}


def load_trimmed(name) -> Image.Image:
    """A source is either a filename, or (filename, index) for one aircraft off
    a sheet. The A350's four liveries arrived as a single 2x2 image, and
    splitting it here keeps source-assets the one place the art lives - the
    alternative was exporting four derived PNGs back into the source tree.

    Index is by reading order, top row left to right, which is how the sheet is
    laid out and how anyone looking at it would number them."""
    if isinstance(name, tuple):
        name, index = name
        img = Image.open(os.path.join(SRC, name)).convert("RGBA")
        return _sheet_cell(img, index)
    img = Image.open(os.path.join(SRC, name)).convert("RGBA")
    box = img.getchannel("A").getbbox()
    return img.crop(box) if box else img


# Ignores specks - antialiasing leaves stray pixels that would otherwise count
# as aircraft. The real ones are hundreds of thousands of pixels.
SHEET_MIN_BLOB = 2000


def _sheet_cell(img: Image.Image, index: int) -> Image.Image:
    """One aircraft off a sheet, found by connected alpha rather than by
    assuming a grid - the cells are not evenly spaced or equally sized."""
    mask = np.asarray(img)[:, :, 3] > 8
    labels, count = ndimage.label(mask)
    sizes = ndimage.sum(mask, labels, range(1, count + 1))
    boxes = []
    for i in range(count):
        if sizes[i] < SHEET_MIN_BLOB:
            continue
        ys, xs = np.where(labels == i + 1)
        boxes.append((ys.min(), xs.min(), xs.max() + 1, ys.max() + 1))
    boxes.sort(key=lambda b: (b[0], b[1]))
    top, left, right, bottom = boxes[index]
    return img.crop((left, top, right, bottom))


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
    # "body" first, whatever order the dict is in - the liveries below measure
    # themselves against the file it writes.
    parts = dict(sorted(parts.items(), key=lambda kv: kv[0] != "body"))
    os.makedirs(folder, exist_ok=True)
    made = 0
    for out_name, src_name in parts.items():
        # A sheet source is (file, index), so check the file half of it.
        file_name = src_name[0] if isinstance(src_name, tuple) else src_name
        if not os.path.exists(os.path.join(SRC, file_name)):
            print("  MISSING %s" % file_name)
            continue
        body = scaled_to_height(load_trimmed(src_name), height)
        # A LIVERY IS PINNED TO THE BODY'S EXACT SIZE, not scaled to the same
        # height and left to land where its own aspect puts it. The renders are
        # drawn a hair apart - the A380's midnight paint came out 130 wide
        # against a 137 body - and since a sprite is centred on its pad, a
        # seven pixel difference walks the aircraft sideways when you change
        # its paint. Eight livery sprites were off before this.
        if out_name != "body":
            base_path = os.path.join(folder, "body_2x.png")
            if os.path.exists(base_path):
                target = Image.open(base_path).size
                if body.size != target:
                    body = body.resize(target, Image.LANCZOS)
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
