"""
Generate a 2-frame propeller/rotor blur strip matching Flight Tycoon's format:
  - single PNG, two frames side by side, 4px empty gutter
  - pure white RGB, flat alpha (frame0=128, frame1=153)
  - elliptical disc with a centre cutout for the spinner/hub
  - denser blur arcs on the leading side
"""
from PIL import Image, ImageDraw, ImageFilter
import numpy as np, math

def make_frame(w, h, alpha, phase, blades=4, hub=0.28, arc_boost=60):
    SS = 4                                    # supersample
    W, H = w*SS, h*SS
    img = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(img)
    cx, cy = W/2, H/2
    rx, ry = W/2-2, H/2-2

    # base disc
    d.ellipse([cx-rx, cy-ry, cx+rx, cy+ry], fill=alpha)

    # blade blur arcs - brighter streaks sweeping round the disc
    for b in range(blades):
        a0 = phase + b*(360/blades)
        for k in range(14):
            t = k/13
            spread = 26*(1-t*0.55)
            inset = 0.10 + 0.90*t
            bb = [cx-rx*inset, cy-ry*inset, cx+rx*inset, cy+ry*inset]
            d.pieslice(bb, a0-spread/2, a0+spread/2,
                       fill=min(255, int(alpha + arc_boost*(1-t))))

    # hub cutout so the nose/spinner reads through
    d.ellipse([cx-rx*hub, cy-ry*hub, cx+rx*hub, cy+ry*hub], fill=0)

    img = img.resize((w, h), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
    a = np.array(img)
    a[a < 6] = 0
    return a

def make_strip(w, h, path, blades=4, frames=(128, 153), phases=(0, 47), hub=0.28):
    gut = 4
    W = w*len(frames) + gut*(len(frames)-1)
    out = np.zeros((h, W, 4), np.uint8)
    out[:, :, :3] = 255
    for i, (al, ph) in enumerate(zip(frames, phases)):
        x0 = i*(w+gut)
        out[:, x0:x0+w, 3] = make_frame(w, h, al, ph, blades=blades, hub=hub)
    Image.fromarray(out).save(path)
    return W, h

# P-51: 3-blade, matches aircraft_p-51mustang_3_2x.png geometry (44x55 cells)
make_strip(44, 55, '/mnt/user-data/outputs/prop_p51_gen_2x.png', blades=3)
# Black Hawk main rotor: wide flat disc, 4 blades
make_strip(140, 62, '/mnt/user-data/outputs/rotor_blackhawk_gen_2x.png', blades=4, hub=0.16)
print('generated')
