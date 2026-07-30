"""Cut the distance-marker cloud out of the hangar's "busy" tab.

The visitor panel shows one cloud per unit of distance to a destination (see
Maps "distance"), and no standalone cloud icon exists in the dump - the only
other clouds are the zone-cover crops, which are 1400-2600 px wide and turn to
mush at icon size. button_planebussy@2x.png carries one at exactly the right
scale, sitting on the tag's gold background.

Separated by colour rather than by a hand-drawn rectangle: the cloud is white
through pale blue, the tag behind it is saturated gold, so the two don't
overlap in hue. The largest connected component of "not gold" is the cloud;
anything smaller is the tag's punch-hole highlight and edge antialiasing.

Run from the repo root:  python3 tools/cloud_icon.py
"""
from PIL import Image
import numpy as np
from scipy import ndimage

SRC = 'source-assets/buttons/button_planebussy@2x.png'
DEST = 'game/assets/bubbles/cloud_icon@2x.png'


def main() -> None:
    im = Image.open(SRC).convert('RGBA')
    a = np.array(im).astype(int)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]

    # Gold tag: red and green well above blue. The cloud is the opposite -
    # blue at least as strong as red.
    gold = (r - b > 40) & (g - b > 20)
    cloud = (al > 40) & ~gold

    lab, n = ndimage.label(cloud)
    if n == 0:
        raise SystemExit('no non-gold region found')
    sizes = ndimage.sum(cloud, lab, range(1, n + 1))
    keep = int(np.argmax(sizes)) + 1
    mask = lab == keep

    ys, xs = np.where(mask)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    out = np.zeros((y1 - y0, x1 - x0, 4), dtype=np.uint8)
    sub = mask[y0:y1, x0:x1]
    out[sub] = a[y0:y1, x0:x1][sub]
    Image.fromarray(out, 'RGBA').save(DEST)
    print('%s -> %s  %dx%d  (largest of %d non-gold regions, %d px)'
          % (SRC, DEST, x1 - x0, y1 - y0, n, int(sizes.max())))


if __name__ == '__main__':
    main()
