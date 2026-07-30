"""Compose the apron's "Arrived" callout, matching the reference layout.

Four pieces, none usable alone:
  bubble@2x.png    component 17 is the wide oval bubble with a downward tail;
                   component 1 is the small blue plane icon
  Arrived.png      the word, on an oversized transparent canvas
  ArrivedBar.png   the blue pill that sits UNDER the word inside the bubble

Layout follows the reference screenshot: word in the upper half of the oval,
pill centred beneath it, and the plane icon overlapping the bubble's left edge
so it hangs outside the outline. That overhang is why the composed sprite is
wider than the bubble itself.

Everything is placed against the oval BODY, not the full sprite height - the
bottom ~14 px is the tail that points at the apron, and centring on the whole
sprite would push the contents down into it.

Composed here rather than layered as four nodes in the engine: the whole thing
is static, so ApronSlot only needs one texture, and the fit stays reproducible
if any piece is redrawn.

Run from the repo root:  python3 tools/arrived_label.py
"""
from PIL import Image
import numpy as np
from scipy import ndimage

SHEET = 'source-assets/bubbles/bubble@2x.png'
WORD = 'source-assets/bubbles/Arrived.png'
BAR = 'source-assets/bubbles/ArrivedBar.png'
BUBBLE_BLOB = 17
PLANE_BLOB = 1
DEST_BUBBLE = 'game/assets/bubbles/big_bubble@2x.png'
DEST_LABEL = 'game/assets/bubbles/arrived_bubble@2x.png'

# All fractions of the bubble's own width / oval-body height, measured off the
# reference screenshot.
WORD_W = 0.54
BAR_W = 0.54
WORD_TOP = 0.10          # of the oval body, from its top
BAR_GAP = 0.06           # between the word's baseline and the pill
PLANE_W = 0.26
PLANE_OVERHANG = 0.55    # how much of the icon hangs off the bubble's left edge


def blob(a, lab, which):
    mask = lab == which
    ys, xs = np.where(mask)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    cut = np.zeros((y1 - y0, x1 - x0, 4), dtype=np.uint8)
    sub = mask[y0:y1, x0:x1]
    cut[sub] = a[y0:y1, x0:x1][sub]
    return Image.fromarray(cut, 'RGBA')


def fit_w(img, w):
    return img.resize((w, max(1, round(img.height * w / img.width))), Image.LANCZOS)


def main() -> None:
    sheet = Image.open(SHEET).convert('RGBA')
    a = np.array(sheet)
    lab, _ = ndimage.label(a[:, :, 3] > 8)
    bubble = blob(a, lab, BUBBLE_BLOB)
    plane = blob(a, lab, PLANE_BLOB)
    bubble.save(DEST_BUBBLE)

    alpha = np.array(bubble)[:, :, 3]
    wide = [i for i, c in enumerate((alpha > 8).sum(axis=1)) if c > bubble.width * 0.5]
    body_top, body_h = wide[0], wide[-1] - wide[0] + 1

    word = Image.open(WORD).convert('RGBA')
    word = fit_w(word.crop(word.getbbox()), int(bubble.width * WORD_W))
    bar = fit_w(Image.open(BAR).convert('RGBA'), int(bubble.width * BAR_W))
    plane = fit_w(plane, int(bubble.width * PLANE_W))

    # The plane hangs off the left, so the canvas grows leftward.
    overhang = int(plane.width * PLANE_OVERHANG)
    out = Image.new('RGBA', (bubble.width + overhang, bubble.height), (0, 0, 0, 0))
    out.alpha_composite(bubble, (overhang, 0))

    cx = overhang + bubble.width // 2
    wy = body_top + int(body_h * WORD_TOP)
    out.alpha_composite(word, (cx - word.width // 2, wy))
    out.alpha_composite(bar, (cx - bar.width // 2,
                              wy + word.height + int(body_h * BAR_GAP)))
    out.alpha_composite(plane, (0, body_top + (body_h - plane.height) // 3))

    out.save(DEST_LABEL)
    print('bubble %dx%d (body y%d h%d) + word %dx%d + bar %dx%d + plane %dx%d'
          % (bubble.width, bubble.height, body_top, body_h,
             word.width, word.height, bar.width, bar.height, plane.width, plane.height))
    print('  -> %s  %dx%d  (plane overhangs %d px left of the bubble)'
          % (DEST_LABEL, out.width, out.height, overhang))


if __name__ == '__main__':
    main()
