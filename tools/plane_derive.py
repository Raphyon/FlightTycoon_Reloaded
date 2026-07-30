"""Derive world sprites for the jet fleet from their shop icons.

The shop icons turn out to already be world-body art: same isometric angle,
same scale (compare source-assets/shop/p51_white.png against the official
game/assets/aircraft/p-51mustang/body_2x.png). So the only work is

  1. lifting the baked-in cast shadow out of the icon, and
  2. deriving a proper ground shadow from the airframe silhouette.

The cast shadow is drawn dark and translucent while the airframe itself is
fully opaque - that, plus an adjacency test to spare the airframe's own
outline (which shares the shadow's colour), separates it cleanly.

Models listed in ORIGINAL skip all of that - they come from
source-assets/original already clean and are only cropped and scaled.

Models listed in WORLD_CLEAN also skip the shadow lift, but for a different
reason and from a different place - see that dict.

Run from the repo root:  python3 tools/plane_derive.py
"""
from PIL import Image
import numpy as np
from scipy import ndimage
import os

# The jets, derived from their shop icons. The Black Hawk, UFO, airship and
# Ark used to ride along here too; they ship as real multi-element sheets now
# and are handled by tools/sheet_derive.py instead, which is also where the
# Ark's downwash rings come from.
MODELS = {
    '747': '747_default.png',
    'a300': 'a300_default.png',
    'a318': 'a318_default.png',
    'a319': 'a319_default.png',
    'a380-300': 'a380-300_default.png',
    'an-225': 'an-225_default.png',
}

# The icons are drawn at world scale already, so they're used 1:1 by
# default. These are the exceptions - at full size they sprawl well past
# the 220x110 apron tile, crowding the pad and the airport road traffic.
SCALE_OVERRIDES = {
    'an-225': 0.85,
}

# Original replacements, from source-assets/original - art made for this
# project rather than reverse-engineered out of the dump, so it carries
# none of the placeholder-only restriction the rest of source-assets does.
# They come in clean (no baked cast shadow, alpha already cut), so they
# skip the shadow separation entirely and are just cropped and scaled.
# Takes precedence over the shop icon of the same name.
# Value is the target sprite height in px.
ORIGINAL_DIR = 'source-assets/original'
# Target sprite height in px. These carry the fleet's size hierarchy, so
# they're set relative to each other rather than to each source file - the
# incoming art is framed tighter than the old shop icons, so matching a
# previous pixel height would render the aircraft visibly larger (which is
# exactly what happened with the A380 at 151).
ORIGINAL = {
    'a380-300': 110,   # sized to the 220x110 apron tile
    'an-225': 112,     # largest airframe in the fleet
    '747': 104,
    'a300': 96,
    'a319': 94,
    'a318': 90,        # smallest of the airliners
}

# Dump world sprites that arrive already clean: the game's own in-world art
# rather than a shop icon, so there is no baked cast shadow to lift. Unlike
# ORIGINAL this is still dump art, so it keeps the placeholder-only
# restriction - which is exactly why it lives here and not in
# source-assets/original. Source is ingest.py's output tree.
#
# The A400M's own shop icon does have a shadow, but not a liftable one: it's a
# soft contact shadow tucked under the airframe rather than an offset
# silhouette, so only the slivers peeking past the wings survive extraction
# (~1800 px of disconnected fragments). The silhouette shadow below is the
# right answer instead.
#
# Value is the target sprite height. Sized into the same hierarchy as
# ORIGINAL rather than used 1:1: the dump draws the A400M 133 px tall, which
# would make it the largest airframe in the fleet, ahead of the An-225. 96
# puts it level with the A300, whose wingspan it nearly matches (42.4 m vs
# 44.8 m).
WORLD_CLEAN_DIR = 'source-assets/aircraft'
WORLD_CLEAN = {
    'a400m': 96,
}

SRC_DIR = 'source-assets/shop'
OUT_DIR = 'game/assets/aircraft'
SHADOW_PEAK_ALPHA = 150
SHADOW_SQUASH = 0.80
OUTLINE_REACH = 2         # px an airframe outline may sit from solid paint
FRAME_SUFFIXES = 'abcdefgh'
HUB_MAX_LUMA = 90         # the spinner is dark against a pale blur
HUB_MIN_ALPHA = 120


def save_shadow_from(body: Image.Image, dest: str) -> Image.Image:
    """Ground shadow from an already-cleaned body: its own silhouette,
    flattened to black and squashed - matching the shipped 328jet/p-51."""
    src_a = np.array(body)[:, :, 3].astype(float)
    sil = np.zeros((body.height, body.width, 4), dtype=np.uint8)
    sil[:, :, 3] = (src_a / max(src_a.max(), 1) * SHADOW_PEAK_ALPHA).astype(np.uint8)
    shadow = Image.fromarray(sil, 'RGBA')
    shadow = shadow.resize((shadow.width, max(1, int(shadow.height * SHADOW_SQUASH))), Image.LANCZOS)
    sb = shadow.getbbox()
    if sb:
        shadow = shadow.crop(sb)
    shadow.save(os.path.join(dest, 'shadow_2x.png'))
    return shadow


def split_prop_strip(strip: Image.Image, dest: str, scale: float) -> list:
    """Split a blur strip into one file per frame, hub-aligned.

    Frames are separated by empty columns, but their content spans are not
    all the same width (the A400M's are 24/24/24/23), and WorldAircraft draws
    each frame with a centered Sprite2D. Cropping each frame to its own
    content would therefore re-center it and make the hub wander between
    frames - a visible wobble. So every frame is pasted into an identical
    cell with its hub landing on the same spot, which is what keeps the prop
    spinning about a fixed point.
    """
    a = np.array(strip)
    alpha = a[:, :, 3].astype(int)
    luma = a[:, :, 0].astype(int)
    filled = (alpha > 8).any(axis=0)

    spans, start = [], None
    for i, f in enumerate(filled):
        if f and start is None:
            start = i
        elif not f and start is not None:
            spans.append((start, i))
            start = None
    if start is not None:
        spans.append((start, len(filled)))

    hubs = []
    for s, e in spans:
        hub = (luma[:, s:e] < HUB_MAX_LUMA) & (alpha[:, s:e] > HUB_MIN_ALPHA)
        ys, xs = np.where(hub)
        # Fall back to the span's centre if a frame has no dark spinner.
        hubs.append((xs.mean(), ys.mean()) if len(ys) else ((e - s) / 2.0, strip.height / 2.0))

    cell_w = max(e - s for s, e in spans)
    cell_h = strip.height
    hub_x = max(h[0] for h in hubs)
    hub_y = max(h[1] for h in hubs)

    written = []
    for i, ((s, e), (hx, hy)) in enumerate(zip(spans, hubs)):
        frame = strip.crop((s, 0, e, cell_h))
        cell = Image.new('RGBA', (cell_w, cell_h), (0, 0, 0, 0))
        cell.paste(frame, (int(round(hub_x - hx)), int(round(hub_y - hy))))
        if scale != 1.0:
            cell = cell.resize((max(1, int(cell_w * scale)),
                                max(1, int(cell_h * scale))), Image.LANCZOS)
        name = 'prop_%s_2x.png' % FRAME_SUFFIXES[i]
        cell.save(os.path.join(dest, name))
        written.append(name)
    return written


def derive_world_clean(key: str, target_h: int) -> None:
    """Clean dump world sprite: crop + scale, silhouette shadow, prop split."""
    src = os.path.join(WORLD_CLEAN_DIR, key)
    im = Image.open(os.path.join(src, 'body_2x.png')).convert('RGBA')
    im = im.crop(im.getbbox())
    scale = target_h / im.height
    body = im.resize((max(1, int(im.width * scale)), target_h), Image.LANCZOS)

    dest = os.path.join(OUT_DIR, key)
    os.makedirs(dest, exist_ok=True)
    body.save(os.path.join(dest, 'body_2x.png'))
    shadow = save_shadow_from(body, dest)

    # The prop frames overlay the static props painted into the body, so they
    # scale by exactly the same factor or they stop lining up with them.
    frames = []
    strip_path = os.path.join(src, 'prop_2x.png')
    if os.path.exists(strip_path):
        strip = Image.open(strip_path).convert('RGBA')
        frames = split_prop_strip(strip, dest, scale)

    print('%-10s WORLD_CLEAN %-9s scale %.3f -> body %-9s shadow %-9s prop %s'
          % (key, '%dx%d' % im.size, scale, '%dx%d' % body.size,
             '%dx%d' % shadow.size, '%df %s' % (len(frames), ','.join(frames)) if frames else '-'))


def derive_original(key: str, target_h: int) -> None:
    """Original art: already clean, so only crop + scale + shadow."""
    im = Image.open(os.path.join(ORIGINAL_DIR, key + '.png')).convert('RGBA')
    im = im.crop(im.getbbox())
    s = target_h / im.height
    body = im.resize((max(1, int(im.width * s)), target_h), Image.LANCZOS)
    dest = os.path.join(OUT_DIR, key)
    os.makedirs(dest, exist_ok=True)
    body.save(os.path.join(dest, 'body_2x.png'))
    shadow = save_shadow_from(body, dest)
    print('%-10s ORIGINAL %-11s -> body %-9s shadow %s'
          % (key, '%dx%d' % im.size, '%dx%d' % body.size, '%dx%d' % shadow.size))


def derive(key: str, icon: str) -> None:
    im = Image.open(os.path.join(SRC_DIR, icon)).convert('RGBA')
    a = np.array(im).astype(int)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]

    # Cast shadow: very dark, blue-tinted and - the reliable part - always
    # translucent, whereas the airframe is fully opaque. Icons vary between
    # pure black (747, A318/A319) and dark navy (A300, A380, An-225), so
    # the colour test has to be loose and the alpha test does the real work.
    #
    # The airframe's own outline shares that exact signature, so it has to
    # be told apart some other way. Blob SIZE was the wrong call - it left
    # ~250 px of shadow speckle per aircraft in blobs just under the cutoff,
    # showing up as a dotted ghost trailing off the wings. Adjacency is the
    # real distinction: the outline hugs opaque airframe pixels, the cast
    # shadow floats clear of them.
    sig = (r < 70) & (g < 80) & (b < 95) & (al > 100) & (al < 235)
    solid = (al > 240) & ~sig
    outline = sig & ndimage.binary_dilation(solid, iterations=OUTLINE_REACH)
    cast = sig & ~outline

    craft = (al > 8) & ~cast

    body_arr = np.array(im).copy()
    body_arr[cast] = [0, 0, 0, 0]
    body = Image.fromarray(body_arr, 'RGBA')
    bbox = body.getbbox()
    body = body.crop(bbox)

    # Ground shadow: the airframe's own silhouette, flattened to black and
    # squashed - the same construction as the shipped 328jet/p-51 shadows.
    sil = np.zeros((im.height, im.width, 4), dtype=np.uint8)
    src_a = np.array(im)[:, :, 3].astype(float) * craft
    sil[:, :, 3] = (src_a / max(src_a.max(), 1) * SHADOW_PEAK_ALPHA).astype(np.uint8)
    shadow = Image.fromarray(sil, 'RGBA').crop(bbox)
    shadow = shadow.resize((shadow.width, max(1, int(shadow.height * SHADOW_SQUASH))), Image.LANCZOS)
    sb = shadow.getbbox()
    if sb:
        shadow = shadow.crop(sb)

    scale = SCALE_OVERRIDES.get(key, 1.0)
    if scale != 1.0:
        body = body.resize((max(1, int(body.width * scale)),
                            max(1, int(body.height * scale))), Image.LANCZOS)
        shadow = shadow.resize((max(1, int(shadow.width * scale)),
                                max(1, int(shadow.height * scale))), Image.LANCZOS)

    dest = os.path.join(OUT_DIR, key)
    os.makedirs(dest, exist_ok=True)
    body.save(os.path.join(dest, 'body_2x.png'))
    shadow.save(os.path.join(dest, 'shadow_2x.png'))
    print('%-10s icon %-9s cast %4d px  scale %.2f -> body %-9s shadow %s'
          % (key, '%dx%d' % im.size, cast.sum(), scale,
             '%dx%d' % body.size, '%dx%d' % shadow.size))


if __name__ == '__main__':
    for k, v in MODELS.items():
        if k in ORIGINAL:
            derive_original(k, ORIGINAL[k])
        else:
            derive(k, v)
    for k, target_h in WORLD_CLEAN.items():
        derive_world_clean(k, target_h)
