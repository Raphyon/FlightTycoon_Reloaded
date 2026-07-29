"""Derive Black Hawk world sprites from its shop icon.

Everything here is a mechanical transform of pixels already in
source-assets/shop/blackh_green.png - nothing is drawn by hand:
  * the baked-in cast shadow is colour-separated out of the body
  * the ground shadow is that body's own silhouette, flattened + squashed
  * the rotor blur is the helicopter's real blade tips, rotate-accumulated
"""
from PIL import Image
import numpy as np
from scipy import ndimage

SRC = 'source-assets/shop/blackh_green.png'
DEST = 'game/assets/aircraft/blackh'
SCALE = 0.85          # brings it in line with the P-51 / V-22 footprint
SHADOW_PEAK_ALPHA = 150
SHADOW_SQUASH = 0.80

im = Image.open(SRC).convert('RGBA')
a = np.array(im).astype(int)
r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
vis = al > 30

# --- 1. separate the baked cast shadow (blue-grey) from the airframe -------
cast = vis & ((b - g) >= 12)
craft = vis & ~cast

# --- 2. isolate the main rotor blades -------------------------------------
dark = craft & (r < 75) & (g < 85) & (b < 85)
olive = craft & ((b - g) < -15) & (r > 55)
outer = dark & ~ndimage.binary_dilation(olive, iterations=3)
outer = ndimage.binary_opening(outer, np.ones((2, 2)))
lab, n = ndimage.label(outer, structure=np.ones((3, 3)))
blades = np.zeros_like(outer)
for i in range(1, n + 1):
    m = lab == i
    ys, _ = np.where(m)
    # Real blades are the big components up in the rotor band; the small
    # leftovers lower down are cabin windows and landing gear.
    if m.sum() >= 60 and ys.mean() < 65:
        blades |= m

# Hub = where the blade axes converge. The bbox centre of these segments is
# NOT the hub: only the parts of each blade clear of the fuselage survive
# the mask, so their extents are lopsided and the centre lands off-mast.
# Fit each blade's principal axis and least-squares the intersection.
A = np.zeros((2, 2))
Bv = np.zeros(2)
lab2, n2 = ndimage.label(blades, structure=np.ones((3, 3)))
for i in range(1, n2 + 1):
    m = lab2 == i
    ys, xs = np.where(m)
    P = np.stack([xs, ys]).astype(float)
    c = P.mean(1, keepdims=True)
    u, _, _ = np.linalg.svd(P - c)
    d = u[:, 0]
    Q = np.eye(2) - np.outer(d, d)
    A += Q
    Bv += Q @ c.ravel()
hub = tuple(np.linalg.solve(A, Bv))

bys, bxs = np.where(blades)
disc_rx = float(np.hypot(bxs - hub[0], bys - hub[1]).max())
squash = 0.48  # iso projection of the rotor disc, measured off the blade spread
disc_ry = disc_rx * squash
print('blades=%d  hub=(%.1f,%.1f)  disc radius %.0f  squash %.2f'
      % (blades.sum(), hub[0], hub[1], disc_rx, squash))

# --- 3. body: airframe only, cast shadow removed --------------------------
body_arr = np.array(im).copy()
body_arr[cast] = [0, 0, 0, 0]
body_img = Image.fromarray(body_arr, 'RGBA')
bbox = body_img.getbbox()
body_img = body_img.crop(bbox)
print('body bbox', bbox, '->', body_img.size)

# --- 4. ground shadow from the airframe silhouette ------------------------
ca = np.zeros((im.height, im.width, 4), dtype=np.uint8)
src_a = np.array(im)[:, :, 3].astype(float) * craft
ca[:, :, 3] = (src_a / src_a.max() * SHADOW_PEAK_ALPHA).astype(np.uint8)
shadow = Image.fromarray(ca, 'RGBA').crop(bbox)
shadow = shadow.resize((max(1, int(shadow.width * SCALE)),
                        max(1, int(shadow.height * SCALE * SHADOW_SQUASH))), Image.LANCZOS)
shadow = shadow.crop(shadow.getbbox())

# --- 5. rotor blur: rotate-accumulate the real blades ---------------------
# The disc is an ellipse in iso view, so un-squash to circular, spin the
# blades around the hub, then squash back.
blade_rgba = np.zeros((im.height, im.width, 4), dtype=np.uint8)
blade_rgba[blades] = [225, 232, 236, 255]      # pale metal smear
blade_img = Image.fromarray(blade_rgba, 'RGBA')

pad = int(disc_rx * 2.4)
canvas = Image.new('RGBA', (pad, pad), (0, 0, 0, 0))
canvas.alpha_composite(blade_img, (int(pad / 2 - hub[0]), int(pad / 2 - hub[1])))
# un-squash vertically about the hub -> blades now sweep a true circle
tall = canvas.resize((pad, int(pad / squash)), Image.LANCZOS)


def sweep(start_deg, steps=36, span=90.0, peak=58):
    """Accumulate the blades across `span` degrees from `start_deg`.

    Four blades sit 90 deg apart, so a 90 deg sweep smears each one exactly
    into its neighbour's place - a full, closed ring. Uniform weighting: a
    real rotor blur is an even band, and ramping the opacity across the
    sweep just made it look like a lopsided smudge.
    """
    acc = np.zeros((tall.height, tall.width), dtype=float)
    for i in range(steps):
        ang = start_deg + span * i / steps
        rot = tall.rotate(ang, resample=Image.BILINEAR, center=(tall.width / 2, tall.height / 2))
        acc = np.maximum(acc, np.array(rot)[:, :, 3].astype(float))
    acc = ndimage.gaussian_filter(acc, sigma=0.9)
    # Thin out toward the hub: near the mast the blade is narrow and slow,
    # at the tips it's sweeping fast over a much bigger arc. Without this
    # the disc fills in solid and fogs the cockpit underneath.
    yy, xx = np.mgrid[0:tall.height, 0:tall.width]
    rn = np.hypot(xx - tall.width / 2.0, yy - tall.height / 2.0)
    rn = np.clip(rn / (tall.width / 2.0), 0.0, 1.0)
    acc *= np.clip(rn, 0.0, 1.0) ** 0.7
    acc = acc / max(acc.max(), 1e-6) * peak
    out = np.zeros((tall.height, tall.width, 4), dtype=np.uint8)
    out[:, :, 0], out[:, :, 1], out[:, :, 2] = 236, 241, 245
    out[:, :, 3] = acc.astype(np.uint8)
    disc = Image.fromarray(out, 'RGBA').resize((pad, pad), Image.LANCZOS)  # re-squash
    return disc.resize((max(1, int(pad * SCALE)), max(1, int(pad * SCALE))), Image.LANCZOS)


frame_a = sweep(0.0)
frame_b = sweep(45.0)

# --- 6. scale body to match the rest of the fleet -------------------------
body_scaled = body_img.resize((max(1, int(body_img.width * SCALE)),
                               max(1, int(body_img.height * SCALE))), Image.LANCZOS)

# rotor hub offset from the body sprite's centre, in final scaled pixels
hub_local = ((hub[0] - bbox[0]) * SCALE, (hub[1] - bbox[1]) * SCALE)
rotor_offset = (hub_local[0] - body_scaled.width / 2.0,
                hub_local[1] - body_scaled.height / 2.0)

body_scaled.save(f'{DEST}/body_2x.png')
shadow.save(f'{DEST}/shadow_2x.png')
frame_a.save(f'{DEST}/rotor_spin_a_2x.png')
frame_b.save(f'{DEST}/rotor_spin_b_2x.png')

print('body   ', body_scaled.size)
print('shadow ', shadow.size)
print('rotor  ', frame_a.size)
print('ROTOR OFFSET for Fleet.WORLD_SPRITES: Vector2(%.1f, %.1f)' % rotor_offset)
