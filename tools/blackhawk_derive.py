"""Cut the Black Hawk's world sprites out of its real asset sheet.

This replaces an earlier version of this tool that reconstructed the Black
Hawk from its shop icon, because no world art existed at the time: it
separated the baked cast shadow by hue (the airframe is olive, so the
translucency test that works for the jets would have erased it), and it built
the rotor blur by rotate-accumulating the helicopter's own blade tips. Both
were approximations, and the proportions showed it. The real sheet turned up,
so neither is needed - everything below is a straight crop.

The sheet holds ten elements, located as connected components rather than by
hardcoded rectangles:

  bodies        green (default livery) and tan (desert), same silhouette, and
                neither carries any rotor - both rotors are overlays
  main rotor    a static 6-blade star, plus two white blur discs
  tail rotor    its own static blades and its own two blur crescents, which
                is why WORLD_SPRITES needs per-hub art for this model
  shadows       two - one casting the main rotor blades, one without. The
                first matches the parked look, the second the spinning one.

The two blur frames of each rotor differ in opacity on purpose (see the
prop/rotor blur note in README.md); they are not normalised here.

Run from the repo root:  python3 tools/blackhawk_derive.py
"""
from PIL import Image
import numpy as np
from scipy import ndimage
import os

SRC = 'source-assets/aircraft/blackh_sheet_2x.png'
DEST = 'game/assets/aircraft/blackh'

# Target body height. The sheet draws the helicopter 95 px tall, which would
# make it the size of an A400M (96) and larger than an A318 (90) - wrong for a
# utility helicopter. 86 sits just above the 328jet (83), making it the
# second-smallest airframe in the fleet. Every part is scaled by this same
# factor so the rotor overlays keep matching the body.
TARGET_BODY_H = 86

# Which connected component is which, identified by size, position and colour
# (the script prints the component table on each run) and then pinned so a
# rerun is deterministic rather than re-deciding every time.
PARTS = {
	'body_2x.png':          {'blob': 2,  'desc': 'green body (default livery)'},
	'body_desert_2x.png':   {'blob': 1,  'desc': 'tan body (desert livery)'},
	'rotor_idle_2x.png':    {'blob': 5,  'desc': 'main rotor, static blades'},
	'rotor_spin_a_2x.png':  {'blob': 3,  'desc': 'main rotor, blur frame a'},
	'rotor_spin_b_2x.png':  {'blob': 10, 'desc': 'main rotor, blur frame b'},
	'tail_idle_2x.png':     {'blob': 6,  'desc': 'tail rotor, static blades'},
	'tail_spin_a_2x.png':   {'blob': 7,  'desc': 'tail rotor, blur frame a'},
	'tail_spin_b_2x.png':   {'blob': 8,  'desc': 'tail rotor, blur frame b'},
	'shadow_2x.png':        {'blob': 4,  'desc': 'shadow w/ rotor blades (parked)'},
	'shadow_spin_2x.png':   {'blob': 9,  'desc': 'shadow w/o blades (spinning)'},
}


def main() -> None:
	im = Image.open(SRC).convert('RGBA')
	a = np.array(im)
	lab, n = ndimage.label(a[:, :, 3] > 8)
	print('%s  %dx%d  %d components' % (SRC, im.width, im.height, n))

	ys, xs = np.where(lab == PARTS['body_2x.png']['blob'])
	body_h = ys.max() - ys.min() + 1
	scale = TARGET_BODY_H / float(body_h)
	print('body %dx%d -> height %d, scale %.4f (applied to every part)'
	      % (xs.max() - xs.min() + 1, body_h, TARGET_BODY_H, scale))

	os.makedirs(DEST, exist_ok=True)
	for name, spec in PARTS.items():
		mask = lab == spec['blob']
		ys, xs = np.where(mask)
		x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
		# Keep only this component's own pixels. Bounding boxes of adjacent
		# elements on the sheet overlap, so a plain rectangular crop would
		# drag in a slice of whatever sits next to it.
		cut = np.zeros((y1 - y0, x1 - x0, 4), dtype=np.uint8)
		sub = mask[y0:y1, x0:x1]
		cut[sub] = a[y0:y1, x0:x1][sub]
		part = Image.fromarray(cut, 'RGBA')
		scaled = part.resize((max(1, round(part.width * scale)),
		                      max(1, round(part.height * scale))), Image.LANCZOS)
		scaled.save(os.path.join(DEST, name))
		print('  %-22s blob %2d  %3dx%-3d -> %3dx%-3d  %s'
		      % (name, spec['blob'], part.width, part.height,
		         scaled.width, scaled.height, spec['desc']))

	# Downwash rings are still wanted and are not on this sheet, so whatever
	# the previous tool produced is left in place untouched.
	for ring in ('downwash_a_2x.png', 'downwash_b_2x.png'):
		path = os.path.join(DEST, ring)
		print('  %-22s %s' % (ring, 'kept' if os.path.exists(path) else 'MISSING'))


if __name__ == '__main__':
	main()
