"""Meander prototype: take the rivers the erosion made (drainage on the eroded ground), bend each reach sideways with a wave that grows as
the valley floor flattens and the river gets bigger, keep it inside the valley floor, and cut the bed along the bent line.
Usage: python meander.py RUN_DIR [thr_km2]   (RUN_DIR holds after.npy and area.npy from precarve.py)
Writes RUN_DIR/meander_after.npy, meander_paths.npy (object array of polylines, grid units) and meander.png."""
import sys, numpy as np, lem
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import LightSource

DX = 32.0


def reaches(h, area, thr):
    n = h.shape[0]
    hr = h.ravel().astype(np.float64)
    sea = (hr <= 0).astype(np.uint8)
    filled, rec, order = lem.route(np.maximum(hr, 0.0), sea, n)
    chan = (area.ravel() > thr) & (sea == 0)
    has_up = np.zeros(n * n, bool)
    for i in np.nonzero(chan)[0]:
        d = rec[i]
        if d >= 0 and chan[d]: has_up[d] = True
    used = np.zeros(n * n, bool)
    out = []
    heads = [i for i in np.nonzero(chan & ~has_up)[0]]
    heads.sort(key=lambda i: -hr[i])
    for hd in heads:
        path = [hd]; i = hd
        while True:
            d = rec[i]
            if d < 0: break
            path.append(d)
            if sea[d] or not chan[d] or used[d]: break
            i = d
        for p in path[:-1]: used[p] = True
        out.append(np.array(path))
    return out, rec, sea.astype(bool)


def smooth(a, w):
    k = np.ones(w) / w
    pad = np.pad(a, (w // 2, w // 2), mode='edge')
    return np.convolve(pad, k, mode='valid')[:a.size]


def meander_reach(cells, n, h, area, rng, k_amp=2.5, k_wave=12.0, slope_flat=0.18):
    if cells.size < 14: return None
    ys, xs = np.divmod(cells, n)
    px = smooth(xs.astype(float), 5); py = smooth(ys.astype(float), 5)
    px[0], py[0], px[-1], py[-1] = xs[0], ys[0], xs[-1], ys[-1]
    tx = np.gradient(px); ty = np.gradient(py); tl = np.hypot(tx, ty) + 1e-9
    tx /= tl; ty /= tl; nx_, ny_ = -ty, tx
    seg = np.hypot(np.diff(px), np.diff(py)) * DX
    s = np.concatenate([[0], np.cumsum(seg)])
    km2 = np.maximum(area.ravel()[cells], 0.35e6) / 1e6
    width = 8.0 + 12.0 * np.sqrt(km2)                      # bankfull width in m
    bed = smooth(h.ravel()[cells].astype(float), 9)
    slope = np.abs(np.gradient(bed, s + 1e-9))
    slope = smooth(slope, 15)
    flat = np.clip(1.0 - slope / slope_flat, 0.0, 1.0) ** 0.7
    amp = k_amp * width * flat
    lam = k_wave * width
    phase = np.concatenate([[0], np.cumsum(2 * np.pi * seg / (0.5 * (lam[1:] + lam[:-1])))]) + rng.uniform(0, 2 * np.pi)
    taper = np.minimum(np.minimum(s, s[-1] - s) / (8 * DX), 1.0)
    d = taper * amp * np.sin(phase)
    # keep inside the valley floor: step out along the normal until the ground rises 4 m above the bed
    lim_pos = np.zeros(cells.size); lim_neg = np.zeros(cells.size)
    for i in range(cells.size):
        for sign, lim in ((1, lim_pos), (-1, lim_neg)):
            r = 0
            while r < 12:
                x = int(round(px[i] + sign * nx_[i] * (r + 1))); y = int(round(py[i] + sign * ny_[i] * (r + 1)))
                if x < 0 or y < 0 or x >= n or y >= n or h[y, x] > bed[i] + 4.0 or h[y, x] <= 0: break
                r += 1
            lim[i] = max(r - 1, 0) * DX * 0.8
    d = np.clip(d, -lim_neg, lim_pos)
    qx = px + d / DX * nx_; qy = py + d / DX * ny_
    return dict(x=qx, y=qy, s=s, width=width, bed=np.minimum.accumulate(bed), old=(px, py))


def carve(h, r):
    n = h.shape[0]
    out = h.copy()
    # densify and cut: bed profile follows the monotone bed; cross-section is a trapezoid with 0.35 bank slope
    qx, qy, s, w, bed = r['x'], r['y'], r['s'], r['width'], r['bed']
    steps = np.maximum((np.hypot(np.diff(qx), np.diff(qy)) * 2).astype(int), 1)
    for i in range(len(qx) - 1):
        for t in np.linspace(0, 1, steps[i], endpoint=False):
            x = qx[i] + t * (qx[i + 1] - qx[i]); y = qy[i] + t * (qy[i + 1] - qy[i])
            b = bed[i] + t * (bed[i + 1] - bed[i]) - 1.5
            ww = w[i] / 2
            x0, y0 = int(round(x)), int(round(y))
            for dy in range(-4, 5):
                for dx_ in range(-4, 5):
                    xx, yy = x0 + dx_, y0 + dy
                    if xx < 0 or yy < 0 or xx >= n or yy >= n or h[yy, xx] <= 0: continue
                    dist = np.hypot(xx - x, yy - y) * DX
                    level = b + max(dist - ww, 0.0) * 0.35
                    if level < out[yy, xx]: out[yy, xx] = level
    return out


if __name__ == '__main__':
    run = sys.argv[1]; thr = float(sys.argv[2]) * 1e6 if len(sys.argv) > 2 else 0.35e6
    h = np.load(f'{run}/after.npy').astype(np.float64); area = np.load(f'{run}/area.npy')
    rs, rec, sea = reaches(h, area, thr)
    rng = np.random.default_rng(11)
    new = h.copy(); paths = []; bent = 0
    for cells in sorted(rs, key=lambda c: -len(c)):
        r = meander_reach(cells, h.shape[0], h, area, rng)
        if r is None: continue
        bent += 1
        new = carve(new, r); paths.append(np.stack([r['x'], r['y']], 1))
    print('reaches', len(rs), 'meandered', bent)
    np.save(f'{run}/meander_after.npy', new.astype(np.float32)); np.save(f'{run}/meander_paths.npy', np.array(paths, dtype=object), allow_pickle=True)
    sl = (slice(380, 900), slice(380, 900)); ls = LightSource(315, 40)
    fig, ax = plt.subplots(1, 2, figsize=(20, 10))
    for a, z, t in ((ax[0], h, 'erosion result'), (ax[1], new, 'meandered and carved')):
        a.imshow(ls.shade(np.where(z > 0, z, -30)[sl], cmap=plt.cm.terrain, vert_exag=6, blend_mode='soft', dx=DX, dy=DX), origin='upper'); a.set_title(t); a.axis('off')
    for p in paths:
        ax[1].plot(p[:, 0] - 380, p[:, 1] - 380, '-', color='cyan', lw=1.2)
    for c in rs:
        ys, xs = np.divmod(c, h.shape[0]); ax[0].plot(xs - 380, ys - 380, '-', color='cyan', lw=1.2)
    for a in ax: a.set_xlim(0, 520); a.set_ylim(520, 0)
    plt.tight_layout(); plt.savefig(f'{run}/meander.png', dpi=60)
