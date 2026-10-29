"""Cut Gutterjaw's 4x4 sheets (rows: down, left, right, up) into clean frames.
The source grids aren't exact (content crosses the 256 px lines), so:
  1. rows are split at the emptiest horizontal line near each 256 boundary,
  2. inside each row band, columns at the emptiest vertical line near each boundary,
  3. in each cut, small blobs touching the cut edge (bits of the neighbour) are dropped,
  4. each frame is placed on a CELLxCELL canvas with its alpha centroid at ANCHOR.
Output: same name in OUT dir, 4x4 grid of CELL px."""
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage

CELL_W, CELL_H = 320, 288
ANCHOR = (160, 168)
## Usage: python clean_gutterjaw_sheets.py <folder with the drawn sheets> <output folder>
SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)


def best_split(profile, center, reach=70):
    lo, hi = max(1, center - reach), min(len(profile) - 1, center + reach)
    seg = profile[lo:hi]
    m = seg.min()
    idx = np.where(seg <= m + 1e-6)[0]
    # middle of the emptiest run closest to the nominal line
    best = idx[np.argmin(np.abs(idx + lo - center))]
    return int(best + lo)


def clean_frame(rgba):
    a = rgba[..., 3] > 40
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n == 0:
        return rgba
    sizes = ndimage.sum(a, lab, range(1, n + 1))
    biggest = sizes.max()
    keep = np.zeros(n + 1, bool)
    h, w = a.shape
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        touches = ys.min() == 0 or xs.min() == 0 or ys.max() == h - 1 or xs.max() == w - 1
        if sizes[i - 1] >= biggest * 0.08 or (not touches and sizes[i - 1] >= 12):
            keep[i] = True
    mask = keep[lab] | (rgba[..., 3] <= 40) & ndimage.binary_dilation(keep[lab], iterations=2)
    out = rgba.copy()
    out[..., 3] = np.where(mask, out[..., 3], 0)
    return out


for name in ["gutterjaw_stalk", "gutterjaw_ambush", "gutterjaw_tail_sweep", "gutterjaw_hungry_charge", "gutterjaw_trash_spit"]:
    im = np.array(Image.open(os.path.join(SRC, name + ".png")).convert("RGBA"))
    alpha = im[..., 3].astype(float)
    H, W = alpha.shape
    rows = [0] + [best_split(alpha.sum(1), c) for c in (256, 512, 768)] + [H]
    sheet = Image.new("RGBA", (CELL_W * 4, CELL_H * 4), (0, 0, 0, 0))
    for r in range(4):
        band = alpha[rows[r]:rows[r + 1]]
        cols = [0] + [best_split(band.sum(0), c) for c in (256, 512, 768)] + [W]
        for c in range(4):
            fr = im[rows[r]:rows[r + 1], cols[c]:cols[c + 1]]
            fr = clean_frame(fr)
            a = fr[..., 3].astype(float)
            if a.sum() == 0:
                continue
            ys, xs = np.indices(a.shape)
            cy = (ys * a).sum() / a.sum()
            cx = (xs * a).sum() / a.sum()
            ox = int(round(ANCHOR[0] - cx))
            oy = int(round(ANCHOR[1] - cy))
            cell = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
            cell.alpha_composite(Image.fromarray(fr), (max(ox, 0), max(oy, 0)), (max(-ox, 0), max(-oy, 0)))
            sheet.alpha_composite(cell, (c * CELL_W, r * CELL_H))
    sheet.save(os.path.join(OUT, name + ".png"))
    print(name, "rows", rows)
