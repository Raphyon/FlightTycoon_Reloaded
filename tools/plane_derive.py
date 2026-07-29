"""Derive world sprites for the jet fleet from their shop icons.

The shop icons turn out to already be world-body art: same isometric angle,
same scale (compare source-assets/shop/p51_white.png against the official
game/assets/aircraft/p-51mustang/body_2x.png). So the only work is

  1. lifting the baked-in cast shadow out of the icon, and
  2. deriving a proper ground shadow from the airframe silhouette.

The cast shadow is drawn dark and translucent while the airframe itself is
fully opaque - that, plus an adjacency test to spare the airframe's own
outline (which shares the shadow's colour), separates it cleanly. Note this
is NOT the same test that worked for the Black Hawk (which keyed on hue,
because it is olive); a hue rule would erase a blue aircraft outright.

Models listed in ORIGINAL skip all of that - they come from
source-assets/original already clean and are only cropped and scaled.

Run from the repo root:  python3 tools/plane_derive.py
"""
from PIL import Image
import numpy as np
from scipy import ndimage
import os

# Whether a model is VTOL is a Fleet.WORLD_SPRITES concern, not a sprite
# one - the derivation is identical either way, so the airship/ark/ufo ride
# along here rather than needing their own tool.
MODELS = {
    '747': '747_default.png',
    'a300': 'a300_default.png',
    'a318': 'a318_default.png',
    'a319': 'a319_default.png',
    'a380-300': 'a380-300_default.png',
    'an-225': 'an-225_default.png',
    'airship': 'airship_default.png',
    'ark': 'ark_default.png',
    'ufo': 'ufo_blue.png',
}

# Thruster-lifted craft get the rotor-downwash rings under them. The rings
# were cut for the V-22, whose body is 121 px wide against a 139 px ring -
# so they're rescaled to keep that same ~1.15x overhang rather than leaving
# a helicopter-sized puff under a much bigger hull.
DOWNWASH_MODELS = ['ark', 'ufo']
DOWNWASH_SRC = 'game/assets/aircraft/v22'
DOWNWASH_RATIO = 139.0 / 121.0

# The icons are drawn at world scale already, so they're used 1:1 by
# default. These are the exceptions - at full size they sprawl well past
# the 220x110 apron tile, crowding the pad and the airport road traffic.
SCALE_OVERRIDES = {
    'ark': 0.75,
    'ufo': 0.75,
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

SRC_DIR = 'source-assets/shop'
OUT_DIR = 'game/assets/aircraft'
SHADOW_PEAK_ALPHA = 150
SHADOW_SQUASH = 0.80
OUTLINE_REACH = 2         # px an airframe outline may sit from solid paint


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


def add_downwash(key: str) -> None:
    dest = os.path.join(OUT_DIR, key)
    body_w = Image.open(os.path.join(dest, 'body_2x.png')).width
    target_w = int(body_w * DOWNWASH_RATIO)
    for frame in ['downwash_a_2x.png', 'downwash_b_2x.png']:
        ring = Image.open(os.path.join(DOWNWASH_SRC, frame)).convert('RGBA')
        scale = target_w / ring.width
        ring = ring.resize((target_w, max(1, int(ring.height * scale))), Image.LANCZOS)
        ring.save(os.path.join(dest, frame))
    print('%-10s downwash scaled to %d px wide (body %d)' % (key, target_w, body_w))


if __name__ == '__main__':
    for k, v in MODELS.items():
        if k in ORIGINAL:
            derive_original(k, ORIGINAL[k])
        else:
            derive(k, v)
    for k in DOWNWASH_MODELS:
        add_downwash(k)
