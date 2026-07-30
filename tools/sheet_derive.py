"""Cut world sprites out of the dump's multi-element asset sheets.

Supersedes tools/blackhawk_derive.py. That tool existed because the Black Hawk
had no world art and had to be reconstructed from its shop icon - separating a
baked cast shadow by hue, and building a rotor blur by rotate-accumulating the
real blade tips. Once the real sheets turned up, none of that was needed, and
the Black Hawk stopped being a special case: four models ship as sheets, so
they share one tool.

Every part is located as a connected component, not by hardcoded rectangles.
The blob ids are pinned per model so a rerun is deterministic; the script
prints the component table on each run so they can be re-checked if a sheet is
ever replaced.

What each sheet holds, and why the four need different handling:

  blackh   two liveries, a static main rotor + two blur discs, a static tail
           rotor + its own two blur crescents, and two shadows (one casting
           the rotor blades, one not). Neither body carries any rotor.
  ufo      two liveries x two states - hull with thrusters off, and the same
           hull with all six firing - plus one shadow. The thruster art is
           what makes the borrowed V-22 downwash rings redundant here.
  airship  three liveries and a shadow. No moving parts.
  ark      body only. No shadow on the sheet, so its ground shadow is
           synthesised from the silhouette the way the jets' are.

Run from the repo root:  python3 tools/sheet_derive.py
"""
from PIL import Image
import numpy as np
from scipy import ndimage
import os

SRC_DIR = 'source-assets/aircraft'
OUT_DIR = 'game/assets/aircraft'

# Ground-shadow construction, for models whose sheet has no shadow of its own.
# Same constants plane_derive.py uses, so a synthesised shadow is
# indistinguishable from the jets'.
SHADOW_PEAK_ALPHA = 150
SHADOW_SQUASH = 0.80

# The Ark keeps the rotor-downwash rings under it. They were cut for the V-22,
# whose body is 121 px wide against a 139 px ring, so they're rescaled to hold
# that same ~1.15x overhang rather than leaving a helicopter-sized puff under a
# much larger hull. The UFO used to borrow them too and no longer needs to -
# its sheet has purpose-built thrusters (see derive_ufo).
DOWNWASH_SRC = 'game/assets/aircraft/v22'
DOWNWASH_RATIO = 139.0 / 121.0

# The dump exports some parts at a reduced alpha ceiling - the UFO's thruster
# state peaks at 179 against its own 255 hull, and the shadows come in at
# 166-179 against the fleet's 150. Left alone the UFO would visibly go
# translucent the moment it lifts off, which reads as a rendering fault rather
# than a design choice, and the shadows would be heavier than every other
# aircraft's. See the opacity note in README.md.
BODY_PEAK_ALPHA = 255


def components(path: str):
    """(rgba array, labelled mask, printed component table)."""
    im = Image.open(path).convert('RGBA')
    a = np.array(im)
    lab, n = ndimage.label(a[:, :, 3] > 8)
    print('%s  %dx%d  %d components' % (path, im.width, im.height, n))
    return a, lab, n


def cut(a: np.ndarray, lab: np.ndarray, blob: int) -> Image.Image:
    """One component's own pixels, cropped to it.

    Only that component's pixels: bounding boxes of neighbouring elements on a
    sheet overlap, so a plain rectangular crop drags in a slice of whatever
    sits alongside.
    """
    mask = lab == blob
    ys, xs = np.where(mask)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    out = np.zeros((y1 - y0, x1 - x0, 4), dtype=np.uint8)
    sub = mask[y0:y1, x0:x1]
    out[sub] = a[y0:y1, x0:x1][sub]
    return Image.fromarray(out, 'RGBA')


def rescale_alpha(img: Image.Image, peak: int) -> Image.Image:
    """Rescale alpha so its maximum becomes `peak`, keeping soft edges."""
    arr = np.array(img).astype(float)
    top = arr[:, :, 3].max()
    if top <= 0:
        return img
    arr[:, :, 3] = np.clip(arr[:, :, 3] / top * peak, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), 'RGBA')


def scaled(img: Image.Image, factor: float) -> Image.Image:
    return img.resize((max(1, round(img.width * factor)),
                       max(1, round(img.height * factor))), Image.LANCZOS)


def align_into(small: Image.Image, canvas: tuple, offset: tuple) -> Image.Image:
    """Pad `small` onto a `canvas`-sized transparent frame at `offset`.

    WorldAircraft draws the body with a centered Sprite2D, so swapping between
    two states of different size would re-centre and jerk the hull. Padding the
    smaller state onto the larger one's canvas, at the offset where their hulls
    actually coincide, makes the swap invisible.
    """
    out = Image.new('RGBA', canvas, (0, 0, 0, 0))
    out.paste(small, offset)
    return out


def hull_offset(small: Image.Image, big: Image.Image, threshold: int = 60) -> tuple:
    """Where `small`'s silhouette best sits inside `big`'s, by mask overlap.

    Measured rather than assumed: the UFO's thruster state extends below the
    hull for the plumes AND a little above it for the pod glow, so neither
    bbox centres nor top edges line the hulls up.
    """
    sm = np.array(small)[:, :, 3] > threshold
    bm = np.array(big)[:, :, 3] > threshold
    sh, sw = sm.shape
    bh, bw = bm.shape
    best = None
    for dy in range(-20, 41):
        for dx in range(-8, 9):
            ys0, ys1 = max(0, dy), min(bh, dy + sh)
            xs0, xs1 = max(0, dx), min(bw, dx + sw)
            if ys1 <= ys0 or xs1 <= xs0:
                continue
            g = bm[ys0:ys1, xs0:xs1]
            p = sm[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
            score = np.logical_and(g, p).sum() - 0.5 * np.logical_and(p, ~g).sum()
            if best is None or score > best[0]:
                best = (score, dx, dy)
    return best[1], best[2]


def save(img: Image.Image, model: str, name: str, note: str = '') -> None:
    dest = os.path.join(OUT_DIR, model)
    os.makedirs(dest, exist_ok=True)
    img.save(os.path.join(dest, name))
    print('  %-24s %3dx%-3d  %s' % (name, img.width, img.height, note))


def shadow_from(body: Image.Image) -> Image.Image:
    """Silhouette shadow, flattened to black and squashed - see plane_derive."""
    src_a = np.array(body)[:, :, 3].astype(float)
    sil = np.zeros((body.height, body.width, 4), dtype=np.uint8)
    sil[:, :, 3] = (src_a / max(src_a.max(), 1) * SHADOW_PEAK_ALPHA).astype(np.uint8)
    out = Image.fromarray(sil, 'RGBA')
    out = out.resize((out.width, max(1, int(out.height * SHADOW_SQUASH))), Image.LANCZOS)
    b = out.getbbox()
    return out.crop(b) if b else out


# --- per model -----------------------------------------------------------

def derive_blackh() -> None:
    a, lab, _ = components(os.path.join(SRC_DIR, 'blackh_sheet_2x.png'))
    parts = {
        'body_2x.png': (2, 'green hull (default livery)'),
        'body_desert_2x.png': (1, 'tan hull (desert livery)'),
        'rotor_idle_2x.png': (5, 'main rotor, static blades'),
        'rotor_spin_a_2x.png': (3, 'main rotor, blur a'),
        'rotor_spin_b_2x.png': (10, 'main rotor, blur b'),
        'tail_idle_2x.png': (6, 'tail rotor, static'),
        'tail_spin_a_2x.png': (7, 'tail rotor, blur a'),
        'tail_spin_b_2x.png': (8, 'tail rotor, blur b'),
        'shadow_2x.png': (4, 'shadow w/ rotor blades (parked)'),
        'shadow_spin_2x.png': (9, 'shadow w/o blades (spinning)'),
    }
    body = cut(a, lab, parts['body_2x.png'][0])
    factor = 86.0 / body.height   # second-smallest airframe, just above 328jet
    print('  scale %.4f -> hull %d px tall' % (factor, 86))
    for name, (blob, note) in parts.items():
        img = scaled(cut(a, lab, blob), factor)
        # The sheet's shadows come in near-opaque; bring them onto the fleet's
        # shadow opacity so this one doesn't sit darker than every other.
        if name.startswith('shadow'):
            img = rescale_alpha(img, SHADOW_PEAK_ALPHA)
        save(img, 'blackh', name, note)


def derive_ufo() -> None:
    a, lab, _ = components(os.path.join(SRC_DIR, 'ufo_sheet_2x.png'))
    # blob -> (plain, thrusters-firing) per livery
    liveries = {'': (1, 4), 'stone': (5, 3)}
    plain = cut(a, lab, liveries[''][0])
    # Sized to sit inside the 220x110 apron tile without crowding the pad or
    # the airport road traffic - the same reason the old derived sprite carried
    # a 0.75 override.
    factor = 100.0 / plain.height
    print('  scale %.4f -> hull %d px tall' % (factor, 100))

    for suffix, (plain_blob, glow_blob) in liveries.items():
        p = cut(a, lab, plain_blob)
        g = cut(a, lab, glow_blob)
        dx, dy = hull_offset(p, g)
        p = align_into(p, g.size, (dx, dy))
        # Restore the thruster state to the hull's own opacity, or the UFO
        # would turn translucent the instant it takes off.
        g = rescale_alpha(g, BODY_PEAK_ALPHA)
        tag = '_' + suffix if suffix else ''
        save(scaled(p, factor), 'ufo', 'body%s_2x.png' % tag,
             'hull, thrusters off%s (padded +%d,%d to match)' % (
                 '' if suffix else ' (default)', dx, dy))
        save(scaled(g, factor), 'ufo', 'body%s_spin_2x.png' % tag,
             'hull, six thrusters firing')

    save(rescale_alpha(scaled(cut(a, lab, 2), factor), SHADOW_PEAK_ALPHA),
         'ufo', 'shadow_2x.png', 'ground shadow')


def derive_airship() -> None:
    a, lab, _ = components(os.path.join(SRC_DIR, 'airship_sheet_2x.png'))
    # dreamingame is the default because the shop icon is that livery - keeping
    # shop and world consistent. It carries the original developer's brand name
    # on the hull, so it is the one to swap if this ever ships publicly.
    parts = {
        'body_2x.png': (3, 'dreamingame livery (default, matches shop icon)'),
        'body_green_2x.png': (1, 'green striped livery'),
        'body_purple_2x.png': (2, 'purple livery'),
        'shadow_2x.png': (4, 'ground shadow'),
    }
    body = cut(a, lab, parts['body_2x.png'][0])
    factor = 1.0   # already at world scale; the old derive used 1.0 too
    print('  scale %.4f (native) -> hull %d px tall' % (factor, body.height))
    for name, (blob, note) in parts.items():
        img = scaled(cut(a, lab, blob), factor)
        if name.startswith('shadow'):
            img = rescale_alpha(img, SHADOW_PEAK_ALPHA)
        save(img, 'airship', name, note)


def derive_ark() -> None:
    a, lab, _ = components(os.path.join(SRC_DIR, 'ark_sheet_2x.png'))
    body = cut(a, lab, 1)
    factor = 105.0 / body.height   # matches the size already accepted in game
    print('  scale %.4f -> hull %d px tall' % (factor, 105))
    body = scaled(body, factor)
    save(body, 'ark', 'body_2x.png', 'hull (no shadow on the sheet)')
    save(shadow_from(body), 'ark', 'shadow_2x.png', 'synthesised from silhouette')

    target_w = int(body.width * DOWNWASH_RATIO)
    for frame in ('downwash_a_2x.png', 'downwash_b_2x.png'):
        ring = Image.open(os.path.join(DOWNWASH_SRC, frame)).convert('RGBA')
        f = target_w / ring.width
        save(ring.resize((target_w, max(1, int(ring.height * f))), Image.LANCZOS),
             'ark', frame, 'V-22 ring rescaled to %d px (hull %d)' % (target_w, body.width))


if __name__ == '__main__':
    for fn in (derive_blackh, derive_ufo, derive_airship, derive_ark):
        fn()
        print()
