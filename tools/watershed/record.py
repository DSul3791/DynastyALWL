"""Stage D of the watershed rebuild (docs/water/watershed_rebuild_design.md, R6 method): the island water record.

Usage (on Dave's PC, never in the cloud):
  python tools/watershed/record.py INPUTS_DIR B2_DIR R3_DIR R4_DIR OUT_DIR [params.json] [--network=R5_DIR]

Reads the chain of one run: inputs.npz (A), glacial.npz (B2, the post-glacial ground), lakes.npz and lakes.json (R3),
groundwater.npz (R4) and, once R5 exists, its network.json. Writes OUT_DIR/record/:
  manifest.json   record version, whether it is complete, every input's hash, this script's git sha, the params, the field
                  table (name, type, cell, scale, offset, no-data) and the summary below;
  climate.json    each island's climate (design A4; defaults from params record.climate until the island table exists);
  network.json    the island-wide vectors (design D): R5's network when given, else the lakes alone and complete = false;
  tiles/X_Z/NAME.TYPE  raw little-endian grids per game tile, (T+1) x (T+1) samples at 8 m with shared edge samples (the
                  export_raw_heights convention), row = z, column = x.

The steps (R6 method items 1 to 4):
1. The chain: each stage's manifest names the hashes of the files it read; they must be the files given here, so the record
   is one run's, never a mix. Any mismatch stops the writer.
2. The window must end at sea on every side (no land on its frame), so no river or groundwater divide is cut by its edge.
3. The 8 m ground: R3's 16 m ground (the post-glacial ground with leftover hollows filled) refined by a separable monotone
   cubic (PCHIP, Fritsch and Carlson 1980) along x and then z. It passes through every 16 m height and does not overshoot
   along either axis, so summits, ridges and channel beds keep their heights. Then fine roughness at 16 to 48 m on
   hillslopes only (the B1 start spectrum carried down), faded out near channels, lakes, wetlands and the sea. Then a
   priority flood: where roughness made a closed cell outside a lake, the roughness is taken out round it; any closed cell
   left is a fault, counted and listed, never filled silently.
4. Lakes at their R3 levels on the refined ground (their shores follow the 8 m ground), the sea at 0, wetlands, regime,
   discharge, water table depth, basin, distance to perennial fresh water (with R5, springs that run in the dry season
   count) and loose sediment, each encoded as listed in the manifest.
With --network (R5's network.py output of this same chain) the regime and discharge come from the network, which knows
the stream threshold and the losing beds, and the rivers wider than about 8 m are carved along R5's polylines and drawn as water
(class 3 perennial, 8 seasonal channel; carve_rivers), before the roughness and the flood. Without it the manifest lists the
network as missing, says the record is not complete, and the bake refuses it (water_record.gd checks `complete`). What the
runtime adds later (brooks under 8 m, cold-air pools, the snow window: R7) and R5's own refinements are listed under
summary.later and do not stop the bake. area_km2 (drainage area per sample) feeds the tile file's flow section.
"""
import sys, os, json, time, hashlib, subprocess
import numpy as np
import numba as nb
from scipy.interpolate import PchipInterpolator
from scipy.ndimage import distance_transform_edt

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'erosion_precarve'))
sys.path.insert(0, HERE)
import runoff    # noqa: E402
import springstore   # noqa: E402
import world   # noqa: E402

T = 1920          # samples per tile edge (8 m), as inputs.py
SPACING = 8.0
SECONDS_PER_YEAR = 3.15576e7
VERSION = 1
# Water class codes (design D, agreed with Steve's Stage E design #541).
OCEAN, LAKE, RIVER, SEASONAL_CHANNEL = 1, 2, 3, 8


def sha(path):
    return hashlib.sha256(open(path, 'rb').read()).hexdigest()


def git_sha():
    try:
        return subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=HERE, capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return 'unknown'


def check_chain(inputs_dir, b2_dir, r3_dir, r4_dir):
    """Every stage's manifest must name exactly the files given here (step 1). Returns the hashes."""
    h = {'inputs.npz': sha(f'{inputs_dir}/inputs.npz'), 'glacial.npz': sha(f'{b2_dir}/glacial.npz'),
         'lakes.npz': sha(f'{r3_dir}/lakes.npz'), 'groundwater.npz': sha(f'{r4_dir}/groundwater.npz')}
    wanted = [(f'{b2_dir}/glacial_manifest.json', ['inputs.npz']),
              (f'{r3_dir}/lakes_manifest.json', ['inputs.npz', 'glacial.npz']),
              (f'{r4_dir}/groundwater_manifest.json', ['inputs.npz', 'lakes.npz', 'glacial.npz'])]
    problems = []
    for path, names in wanted:
        read = json.load(open(path)).get('inputs', {})
        for name in names:
            if read.get(name) != h[name]:
                problems.append(f'{os.path.basename(path)} read a different {name} ({str(read.get(name))[:12]}, given {h[name][:12]})')
    if problems:
        raise SystemExit('record: the stages are not one run:\n  ' + '\n  '.join(problems))
    return h


def check_window(sea):
    """No land on the window's frame (step 2)."""
    frame = np.concatenate([sea[0, :], sea[-1, :], sea[:, 0], sea[:, -1]])
    if not frame.all():
        raise SystemExit(f'record: {int((~frame).sum())} land cells on the window frame; the window must end at sea on every side')


def refine(a):
    """16 m grid (n x n) to 8 m (2n - 1): monotone cubic along x, then along z (step 3)."""
    n = a.shape[0]
    coarse = np.arange(n, dtype=np.float64)
    fine = np.arange(2 * n - 1, dtype=np.float64) * 0.5
    along_x = PchipInterpolator(coarse, a.astype(np.float64), axis=1)(fine)
    return PchipInterpolator(coarse, along_x, axis=0)(fine)


def nearest(field, ground16):
    """A 16 m field on the 8 m samples. Even samples sit on a 16 m cell; an odd one lies midway between two and takes the
    lower one's value (water runs downhill), along x and then along z, so a category never shifts uphill by half a cell."""
    n = field.shape[0]
    m = 2 * n - 1
    idx = np.arange(m) // 2
    nxt = np.minimum(idx + 1, n - 1)
    odd = (np.arange(m) % 2) == 1
    # along x
    lower_x = np.where(odd[None, :] & (ground16[:, nxt] < ground16[:, idx]), nxt[None, :], idx[None, :])
    rows = np.arange(n)[:, None]
    fx = field[rows, lower_x]
    gx = ground16[rows, lower_x]
    # along z
    lower_z = np.where(odd[:, None] & (gx[nxt, :] < gx[idx, :]), nxt[:, None], idx[:, None])
    cols = np.arange(m)[None, :]
    return fx[lower_z, cols]


def roughness(shape, dx, R, E_start, seed):
    """Fine roughness with the spectrum of the B1 start roughness carried down (random phases, amplitude falling as
    wavelength^(H+1)), between R['shortest_m'] and R['longest_m']. Its rms slope continues the start's: the slope spectrum
    of such ground grows as k^(1-2H) per unit k, so a band's slope variance is the integral of that over its wavenumbers."""
    H = float(E_start['hurst'])
    p = 2.0 - 2.0 * H
    band = lambda a, b: ((1.0 / a) ** p - (1.0 / b) ** p) / p
    rms_slope = float(E_start['rms_slope']) * np.sqrt(band(R['shortest_m'], R['longest_m']) / band(E_start['shortest_m'], E_start['longest_m']))
    nz, nx = shape
    rng = np.random.default_rng(seed)
    kz = np.fft.fftfreq(nz, dx)[:, None]
    kx = np.fft.rfftfreq(nx, dx)[None, :]
    k = np.hypot(kz, kx)
    keep = (k >= 1.0 / R['longest_m']) & (k <= 1.0 / R['shortest_m'])
    amp = np.where(keep, np.power(np.maximum(k, 1e-12), -(H + 1.0)), 0.0)
    spec = amp * np.exp(2j * np.pi * rng.random(amp.shape))
    del amp, keep
    z = np.fft.irfft2(spec, s=shape)
    del spec
    gz, gx = np.gradient(z, dx)
    s = float(np.sqrt(np.mean(gx * gx + gz * gz)))
    return (z * (rms_slope / s) if s > 0 else z), rms_slope


@nb.njit(cache=True)
def _fill(h, surface, sink, n):
    """Priority flood (Barnes et al. 2014) with no epsilon, so a flat stays flat: each cell rises to the lowest level at which
    water could leave it for a sink (the sea at 0, a lake at its level). Sinks start at their water surface."""
    N = n * n
    filled = np.empty(N)
    seen = np.zeros(N, np.uint8)
    hv = np.empty(N + 8)
    hi = np.empty(N + 8, np.int64)
    sz = 0
    for i in range(N):
        if sink[i]:
            filled[i] = surface[i]
            seen[i] = 1
            k = sz
            sz += 1
            hv[k] = filled[i]
            hi[k] = i
            while k > 0:
                q = (k - 1) // 2
                if hv[q] > hv[k]:
                    t = hv[q]; hv[q] = hv[k]; hv[k] = t
                    t2 = hi[q]; hi[q] = hi[k]; hi[k] = t2
                    k = q
                else:
                    break
    while sz > 0:
        v = hv[0]
        i = hi[0]
        sz -= 1
        hv[0] = hv[sz]
        hi[0] = hi[sz]
        k = 0
        while True:
            a = 2 * k + 1
            b = a + 1
            j = k
            if a < sz and hv[a] < hv[j]:
                j = a
            if b < sz and hv[b] < hv[j]:
                j = b
            if j == k:
                break
            t = hv[j]; hv[j] = hv[k]; hv[k] = t
            t2 = hi[j]; hi[j] = hi[k]; hi[k] = t2
            k = j
        r = i // n
        c = i % n
        for dr in range(-1, 2):
            for dc in range(-1, 2):
                if dr == 0 and dc == 0:
                    continue
                rr = r + dr
                cc = c + dc
                if rr < 0 or rr >= n or cc < 0 or cc >= n:
                    continue
                j = rr * n + cc
                if seen[j]:
                    continue
                seen[j] = 1
                filled[j] = max(h[j], v)
                k = sz
                sz += 1
                hv[k] = filled[j]
                hi[k] = j
                while k > 0:
                    q = (k - 1) // 2
                    if hv[q] > hv[k]:
                        t = hv[q]; hv[q] = hv[k]; hv[k] = t
                        t2 = hi[q]; hi[q] = hi[k]; hi[k] = t2
                        k = q
                    else:
                        break
    return filled


def closed_cells(g, surface, sink, tol):
    """Land cells the flood raises by more than tol: closed hollows that drain to no sink."""
    n = g.shape[0]
    filled = _fill(g.ravel().astype(np.float64), np.nan_to_num(surface.ravel().astype(np.float64)), sink.ravel().astype(np.uint8), n)
    return ((filled.reshape(n, n) - g) > tol) & ~sink


def grow_lakes(lake8, lvl, g, passes):
    """The 16 m lake cells carried to 8 m end half a cell short of the refined shore; a neighbour of a lake sample whose
    ground lies under that lake's level joins it, so the shore follows the 8 m ground."""
    for _ in range(passes):
        wet = np.isfinite(lvl) & (lvl > g)
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                if dr == 0 and dc == 0:
                    continue
                nb_id = np.roll(np.roll(np.where(wet, lake8, -1), dr, 0), dc, 1)
                nb_lv = np.roll(np.roll(np.where(wet, lvl, np.nan), dr, 0), dc, 1)
                take = (lake8 < 0) & (nb_id >= 0) & (nb_lv > g)
                lake8 = np.where(take, nb_id, lake8)
                lvl = np.where(take, nb_lv, lvl)
    return lake8, lvl



@nb.njit(cache=True)
def _carve(segs, m, ox, oz, dx, cut, best_r, best_s, best_t):
    """Lowers `cut` (the lowest ground any river asks for at each 8 m sample) and keeps, per sample, the nearest segment and
    where along it the sample falls. A segment row: x0, z0, x1, z1, then at its two ends the bed, the level, the half-width
    of the flat bed, the tangent of the bank angle and the bank top, then the class code and the reach of the cut (see
    carve_rivers). The cross-section is a flat bed with banks at the bed material's angle, carried on up at that angle until
    it meets the ground."""
    for s in range(segs.shape[0]):
        x0 = segs[s, 0]; z0 = segs[s, 1]; x1 = segs[s, 2]; z1 = segs[s, 3]
        rr = segs[s, 15]
        ex = x1 - x0
        ez = z1 - z0
        L2 = ex * ex + ez * ez
        c_lo = max(int(np.floor((min(x0, x1) - rr - ox) / dx)), 0)
        c_hi = min(int(np.ceil((max(x0, x1) + rr - ox) / dx)), m - 1)
        r_lo = max(int(np.floor((min(z0, z1) - rr - oz) / dx)), 0)
        r_hi = min(int(np.ceil((max(z0, z1) + rr - oz) / dx)), m - 1)
        for r in range(r_lo, r_hi + 1):
            pz = oz + r * dx
            for c in range(c_lo, c_hi + 1):
                px = ox + c * dx
                t = 0.0
                if L2 > 0.0:
                    t = ((px - x0) * ex + (pz - z0) * ez) / L2
                    t = min(max(t, 0.0), 1.0)
                qx = x0 + t * ex
                qz = z0 + t * ez
                d = np.sqrt((px - qx) * (px - qx) + (pz - qz) * (pz - qz))
                if d > rr:
                    continue
                b = segs[s, 4] + t * (segs[s, 5] - segs[s, 4])
                bh = segs[s, 8] + t * (segs[s, 9] - segs[s, 8])
                ta = segs[s, 10] + t * (segs[s, 11] - segs[s, 10])
                v = b + max(0.0, d - bh) * ta
                k = r * m + c
                if v < cut[k]:
                    cut[k] = v
                if d < best_r[k]:
                    best_r[k] = d
                    best_s[k] = s
                    best_t[k] = t


def carve_rivers(network, net, ox, oz, m, lake_levels, CV):
    """R6 item 3, second step: rivers wider than CV['carve_min_width_m'] carved along their R5 polylines at their bankfull
    width and depth, with banks at the bed material's angle, and drawn as water at their mean-flow depth: class 3 where the
    reach is perennial, 8 (seasonal channel) where it is intermittent or ephemeral. Narrower brooks are left to R7, which draws
    them at voxel scale in the valleys B1 cut.

    Each reach's bank top is its polyline's bed_y (the 16 m ground along the channel, which holds the valley floor), made
    non-increasing downstream; the bed is that less the bankfull depth, the level the bed plus the mean-flow depth. A reach is
    joined to what it runs into: the next reach's first point, or one and a half cells on toward the sea or the lake, so no
    trench ends short of the water. Levels never rise downstream and never sit below what the reach runs into (the sea at 0,
    the lake at its level, the next reach's level), so a tributary meets its river at the river's level or above. Where a
    reach sinks or leaves its channel, the cut tapers to nothing over its last CV['end_taper_points'] points.

    Returns the segment rows (for _carve) and the class code per segment."""
    n16 = net['width_m'].shape[0]
    dx16 = 2.0 * SPACING
    W16, D16, Dm16 = (net[k].astype(np.float64) for k in ('width_m', 'depth_m', 'depth_mean_m'))
    bed16, reg16 = net['bed'].astype(np.int64), net['regime'].astype(np.int64)
    tan_bed = np.tan(np.radians(np.asarray(CV['bank_angle_deg_by_bed'], np.float64)))
    min_w, extra, taper = float(CV['carve_min_width_m']), float(CV['bank_extra_m']), int(CV['end_taper_points'])
    by_id = {int(r['id']): r for r in network['reaches']}

    # Downstream first: each reach after the one it runs into.
    hops = {}
    for rid in by_id:
        path, j = [], rid
        while j in by_id and j not in hops and len(path) <= len(by_id):
            path.append(j)
            d = by_id[j]
            j = int(d['down']) if d['ends'] == 'reach' and int(d['down']) in by_id else None
        base = hops.get(j, -1) if j is not None else -1
        for q in reversed(path):
            base += 1
            hops[q] = base
    first = {}      # reach id -> (x, z, bank top, bed, level) at its first point
    rows, codes = [], []
    for rid in sorted(by_id, key=lambda q: hops[q]):
        r = by_id[rid]
        pl = np.asarray(r['polyline'], np.float64)
        x, y, z = pl[:, 0], np.minimum.accumulate(pl[:, 1]), pl[:, 2]
        ci = np.clip(np.round((x - ox) / dx16).astype(np.int64), 0, n16 - 1)
        cj = np.clip(np.round((z - oz) / dx16).astype(np.int64), 0, n16 - 1)
        W, D, Dm = W16[cj, ci], D16[cj, ci], Dm16[cj, ci]
        ta = tan_bed[np.clip(bed16[cj, ci], 0, tan_bed.size - 1)]
        reg = reg16[cj, ci]
        D0 = np.where(W > min_w, D, 0.0)
        D = D0.copy()
        if r['ends'] in ('sinks', 'leaves its channel') and taper > 0:
            k = min(taper, D.size)
            D[-k:] *= np.linspace(1.0, 0.0, k + 1)[1:]
        b = y - D
        # The level from the untapered channel, so a reach that sinks keeps its depth upstream and runs out to nothing at its end
        # (the level is held at least at the bed below), rather than its dry end raising the water behind it.
        w = (y - D0) + np.minimum(Dm, D0)
        floor = None
        if r['ends'] == 'sea':
            floor = 0.0
        elif r['ends'] == 'lake' and r.get('lake') is not None and int(r['lake']) in lake_levels:
            floor = lake_levels[int(r['lake'])]
        elif r['ends'] == 'reach' and int(r['down']) in first:
            floor = first[int(r['down'])][4]
        # The join: the next reach's first point, or 1.5 cells on along the last step toward the sea or the lake.
        ext = None
        if r['ends'] == 'reach' and int(r['down']) in first:
            fx, fz, fy, fb, fw = first[int(r['down'])]
            ext = (fx, fz, min(y[-1], fy), min(b[-1], fb), fw)
        elif r['ends'] in ('sea', 'lake') and x.size >= 2 and floor is not None:
            ux, uz = x[-1] - x[-2], z[-1] - z[-2]
            ext = (x[-1] + 1.5 * ux, z[-1] + 1.5 * uz, min(y[-1], floor), min(b[-1], floor - D[-1]), floor)
        if ext is not None:
            x, z = np.append(x, ext[0]), np.append(z, ext[1])
            y, b, w = np.append(y, ext[2]), np.append(b, ext[3]), np.append(w, ext[4])
            W, D, ta, reg = np.append(W, W[-1]), np.append(D, D[-1]), np.append(ta, ta[-1]), np.append(reg, reg[-1])
        if floor is not None:
            w = np.maximum(w, floor)
        w = np.maximum.accumulate(w[::-1])[::-1]          # never rising downstream
        w = np.maximum(w, b)
        bh = np.maximum(0.5 * W - D / ta, W / 6.0)
        rr = bh + (D + extra) / ta
        first[rid] = (x[0], z[0], y[0], b[0], w[0])
        for k in range(x.size - 1):
            if D[k] <= 0.0 and D[k + 1] <= 0.0:
                continue
            code = RIVER if reg[k] == 1 else SEASONAL_CHANNEL
            rows.append([x[k], z[k], x[k + 1], z[k + 1], b[k], b[k + 1], w[k], w[k + 1], bh[k], bh[k + 1], ta[k], ta[k + 1],
                         y[k], y[k + 1], float(code), max(rr[k], rr[k + 1])])
            codes.append(code)
    return np.asarray(rows, np.float64).reshape(-1, 16), np.asarray(codes, np.uint8)


def river_water(segs, best_s, best_t, best_r, g, keep):
    """The river water on the carved ground: a sample is river where its nearest segment's channel holds water over it (within
    the channel's water width at that point, below the bank top) and `keep` (not sea, not lake). Returns the class code and
    the level per sample (0 and NaN off the rivers)."""
    m = g.shape[0]
    code = np.zeros(m * m, np.uint8)
    level = np.full(m * m, np.nan)
    idx = np.flatnonzero(best_s.ravel() >= 0)
    if idx.size == 0 or segs.shape[0] == 0:
        return code.reshape(m, m), level.reshape(m, m)
    S = segs[best_s.ravel()[idx]]
    t = best_t.ravel()[idx]
    lerp = lambda a, b_: S[:, a] + t * (S[:, b_] - S[:, a])
    b, w, bh, ta, top = lerp(4, 5), lerp(6, 7), lerp(8, 9), lerp(10, 11), lerp(12, 13)
    width = bh + np.maximum(np.minimum(w, top) - b, 0.0) / ta
    wet = (best_r.ravel()[idx] <= width) & (g.ravel()[idx] < w) & keep.ravel()[idx]
    code[idx[wet]] = S[wet, 14].astype(np.uint8)
    level[idx[wet]] = w[wet]
    return code.reshape(m, m), level.reshape(m, m)


@nb.njit(cache=True)
def _area(rec, cell):
    """Drainage area through each cell from R3's receivers (-1: none), upstream cells first (Kahn's order)."""
    N = rec.size
    indeg = np.zeros(N, np.int64)
    for i in range(N):
        if rec[i] >= 0:
            indeg[rec[i]] += 1
    area = np.full(N, cell)
    stack = np.empty(N, np.int64)
    sz = 0
    for i in range(N):
        if indeg[i] == 0:
            stack[sz] = i
            sz += 1
    while sz > 0:
        sz -= 1
        i = stack[sz]
        d = rec[i]
        if d >= 0:
            area[d] += area[i]
            indeg[d] -= 1
            if indeg[d] == 0:
                stack[sz] = d
                sz += 1
    return area


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    opts = dict(a[2:].split('=', 1) for a in sys.argv[1:] if a.startswith('--') and '=' in a)
    inputs_dir, b2_dir, r3_dir, r4_dir, out_dir = args[:5]
    P = json.load(open(args[5] if len(args) > 5 else os.path.join(HERE, 'params.json')))
    RC = P['record']
    t0 = time.time()
    hashes = check_chain(inputs_dir, b2_dir, r3_dir, r4_dir)

    b2 = np.load(f'{b2_dir}/glacial.npz')
    r3 = np.load(f'{r3_dir}/lakes.npz')
    r4 = np.load(f'{r4_dir}/groundwater.npz')
    lakes = json.load(open(f'{r3_dir}/lakes.json'))
    dx16 = float(r3['cell_m'])
    assert abs(dx16 - 2.0 * SPACING) < 1e-6, ('the record refines a 16 m model grid; this run is', dx16)
    ox, oz = float(r3['origin_x']), float(r3['origin_z'])
    g16 = r3['ground'].astype(np.float64)
    sea16 = r3['sea'].astype(bool)
    check_window(sea16)

    # 3. The 8 m ground.
    g = refine(g16)
    m = g.shape[0]
    lake16 = r3['lake_id'].astype(np.int64)
    lake8 = nearest(lake16, g16)
    by_id = np.full(int(max([lk['id'] for lk in lakes], default=-1)) + 2, np.nan)   # lakes.json levels by lake id; the last slot is "none"
    for lk in lakes:
        by_id[int(lk['id'])] = float(lk['level_m'])
    lvl = by_id[np.where(lake8 >= 0, lake8, by_id.size - 1)]
    lake8, lvl = grow_lakes(lake8, lvl, g, int(RC['lake_shore_passes']))
    # The sea: 8 m samples at or below 0 on or beside a 16 m sea cell (an inland sample below 0 is not sea, and the flood
    # below would list it).
    sea_near = nearest(sea16.astype(np.int8), g16).astype(bool)
    for dr in (-1, 0, 1):
        for dc in (-1, 0, 1):
            sea_near = sea_near | np.roll(np.roll(sea_near, dr, 0), dc, 1)
    ocean = sea_near & (g <= 0.0)
    # The network (R5), when given, must be of this same run; its regime (which takes the stream threshold and the losing
    # beds into account) and its flows replace R4's first regime and record.py's own discharge.
    network_dir = opts.get('network')
    net = None
    if network_dir:
        nman = json.load(open(os.path.join(network_dir, 'network_manifest.json')))
        bad = [k for k in ('inputs.npz', 'glacial.npz', 'lakes.npz', 'groundwater.npz') if nman['inputs'].get(k) != hashes[k]]
        if bad:
            raise SystemExit(f'record: the network was made from other files ({", ".join(bad)}); run network.py on this chain')
        net = np.load(os.path.join(network_dir, 'network.npz'))
        network = json.load(open(os.path.join(network_dir, 'network.json')))
    regime16 = (net['regime'] if net is not None else r4['regime']).astype(np.int8)
    regime8 = nearest(regime16, g16)
    wet8 = nearest(r4['wetland'].astype(np.int8), g16)
    lake_wet = np.isfinite(lvl) & (lvl > g)
    summit16, summit8_smooth = float(g16.max()), float(g.max())

    # Rivers wider than about 8 m carved along their R5 polylines and drawn as water (R6 item 3; carve_rivers). They need the
    # network: without it the record has no rivers and says so (missing), and the bake refuses it.
    river_code, river_level = np.zeros((m, m), np.uint8), np.full((m, m), np.nan)
    segs, carved_cells = np.zeros((0, 16)), 0
    if net is not None:
        segs, _ = carve_rivers(network, net, ox, oz, m, {int(lk['id']): float(lk['level_m']) for lk in lakes}, RC['rivers'])
        cut = np.full(m * m, np.inf, np.float32)
        best_r = np.full(m * m, np.inf, np.float32)
        best_s = np.full(m * m, -1, np.int64)
        best_t = np.zeros(m * m, np.float32)
        _carve(segs, m, ox, oz, SPACING, cut, best_r, best_s, best_t)
        keep = ~ocean & ~lake_wet
        lower = (cut.reshape(m, m) < g) & keep
        carved_cells = int(lower.sum())
        g = np.where(lower, cut.reshape(m, m).astype(np.float64), g)
        del cut, lower
        river_code, river_level = river_water(segs, best_s.reshape(m, m), best_t.reshape(m, m), best_r.reshape(m, m), g, keep)
        del best_r, best_s, best_t, keep

    Rr = RC['roughness']
    rough_rms_slope = 0.0
    if Rr.get('on', True):
        near = (regime8 > 0) | lake_wet | (wet8 > 0) | ocean | (river_code > 0)
        dist = distance_transform_edt(~near) * SPACING
        fade = np.clip(dist / float(Rr['fade_m']), 0.0, 1.0)
        fade = fade * fade * (3.0 - 2.0 * fade)
        z, rough_rms_slope = roughness(g.shape, SPACING, Rr, P['evolve']['start_roughness'], int(P['seed']) + int(Rr.get('seed_offset', 1)))
        rough = z * fade
        del z, dist
        sink = ocean | lake_wet | (river_code > 0)
        surface = np.where(ocean, 0.0, np.where(lake_wet, lvl, river_level))
        closed_before = closed_cells(g, surface, sink, float(RC['closed_tolerance_m']))
        g_rough = g + rough
        made = closed_cells(g_rough, surface, sink, float(RC['closed_tolerance_m'])) & ~closed_before
        # Take the roughness out round every closed cell it made (and the cells beside them), once.
        grow = made.copy()
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                grow |= np.roll(np.roll(made, dr, 0), dc, 1)
        g = np.where(grow, g, g_rough)
        roughness_removed_cells = int(grow.sum())
        del g_rough, rough
    else:
        roughness_removed_cells = 0
    lake8, lvl = grow_lakes(lake8, lvl, g, 1)    # roughness fades to nothing at a shore, but a shore sample may still dip under
    lake_wet = np.isfinite(lvl) & (lvl > g)
    river_wet = (river_code > 0) & ~lake_wet & ~ocean
    sink = ocean | lake_wet | river_wet
    faults = closed_cells(g, np.where(ocean, 0.0, np.where(lake_wet, lvl, river_level)), sink, float(RC['closed_tolerance_m']))
    fault_idx = np.flatnonzero(faults.ravel())
    worst = fault_idx[np.argsort(-g.ravel()[fault_idx])][:20] if fault_idx.size else []
    fault_list = [dict(x=ox + float(i % m) * SPACING, z=oz + float(i // m) * SPACING, ground_m=round(float(g.ravel()[i]), 2)) for i in worst]

    # 4. Water on the 8 m ground.
    wclass = np.zeros((m, m), np.uint8)
    wclass[wet8 > 0] = wet8[wet8 > 0].astype(np.uint8)
    wclass[river_wet] = river_code[river_wet]
    wclass[lake_wet] = LAKE
    wclass[ocean] = OCEAN
    level = np.where(ocean, 0.0, np.where(lake_wet, lvl, np.where(river_wet, river_level, np.nan)))
    ref_mm = runoff.reference_quick_mm(P['rain']['background_mm_yr'], P['water_budget'])
    if net is not None:
        q16 = net['q_mean_m3_s'].astype(np.float64)
    else:
        q16 = r3['quick_area_m2'].astype(np.float64) * ref_mm / 1000.0 / SECONDS_PER_YEAR + r4['baseflow_m3_s'].astype(np.float64)
    discharge = np.nan_to_num(nearest(np.where(regime16 > 0, q16, 0.0), g16))
    table = np.nan_to_num(nearest(r4['depth_to_table_m'].astype(np.float64), g16))
    basin = nearest(r3['basin_id'].astype(np.int64), g16)
    sediment = np.nan_to_num(nearest(b2['sediment_m'].astype(np.float64), g16))
    fresh_src = lake_wet | (regime8 == 1) | (river_wet & (river_code == RIVER))
    # Drainage area through each sample (R3's routing on the 16 m ground), for the tile file's flow section.
    area16 = _area(r3['receiver'].astype(np.int64).ravel(), dx16 * dx16).reshape(g16.shape)
    area8 = nearest(area16, g16) / 1e6
    if network_dir:
        # Springs that still run in the dry quarter are fresh water too (spring_store_build_plan.md section 5), at the 8 m
        # sample nearest each.
        fresh_src = fresh_src | springstore.spring_sources(network['springs'], ox, oz, SPACING, m, float(RC['fresh_spring_min_m3_s']))
    fresh = distance_transform_edt(~fresh_src) * SPACING if fresh_src.any() else np.full((m, m), 65535.0)

    E = RC['encoding']
    enc_q = lambda q: np.where(q >= 1e-4, np.clip(np.round((np.log10(np.maximum(q, 1e-4)) + 4.0) * float(E['discharge_codes_per_decade'])), 1, 65535), 0).astype('<u2')
    fields = [
        ('ground', g.astype('<f4'), 'f4', dict(units='m')),
        ('water_level', level.astype('<f4'), 'f4', dict(units='m', nodata='NaN')),
        ('water_class', wclass, 'u1', dict(codes='0 none, 1 ocean, 2 lake, 3 river, 4 marsh, 5 swamp, 6 fen, 7 bog, 8 seasonal channel, 9 seasonal pond, 10 salt marsh')),
        ('discharge', enc_q(discharge), 'u2', dict(units='m3/s', log10_m3_s='code / codes_per_decade - 4', codes_per_decade=float(E['discharge_codes_per_decade']), nodata=0)),
        ('regime', regime8.astype(np.uint8), 'u1', dict(codes='0 none, 1 perennial, 2 intermittent, 3 ephemeral')),
        ('table_depth', np.clip(np.round(np.maximum(table, 0.0) / float(E['table_depth_step_m'])), 0, 255).astype(np.uint8), 'u1',
         dict(units='m', scale=float(E['table_depth_step_m']), note=f"R4's regional table, a yearly mean; 0 = at the ground; 255 = {255 * float(E['table_depth_step_m'])} m or deeper")),
        ('basin', basin.astype('<i4'), 'i4', dict(nodata=-1)),
        ('fresh_m', np.clip(np.round(fresh), 0, 65535).astype('<u2'), 'u2', dict(units='m', scale=1.0, note='to a lake, regime 1 (perennial) water or a spring that runs in the dry season')),
        ('area_km2', area8.astype('<f4'), 'f4', dict(units='km2', note="drainage area through the sample, R3's routing on the 16 m ground")),
        ('sediment_m', np.clip(np.round(np.maximum(sediment, 0.0) / float(E['sediment_step_m'])), 0, 65535).astype('<u2'), 'u2', dict(units='m', scale=float(E['sediment_step_m']))),
    ]

    x0, z0, x1, z1 = P['tiles']
    assert m == (z1 - z0 + 1) * T + 1 and m == (x1 - x0 + 1) * T + 1, ('8 m grid', m, 'does not match the tiles', P['tiles'])
    rec_dir = os.path.join(out_dir, 'record')
    for tz in range(z0, z1 + 1):
        for tx in range(x0, x1 + 1):
            d = os.path.join(rec_dir, 'tiles', f'{tx}_{tz}')
            os.makedirs(d, exist_ok=True)
            r0, c0 = (tz - z0) * T, (tx - x0) * T
            for name, arr, typ, _ in fields:
                np.ascontiguousarray(arr[r0:r0 + T + 1, c0:c0 + T + 1]).tofile(os.path.join(d, f'{name}.{typ}'))

    if network_dir:
        hashes['network.json'] = sha(os.path.join(network_dir, 'network.json'))
        hashes['network.npz'] = sha(os.path.join(network_dir, 'network.npz'))
        missing, later = [], [f'R5: {m}' for m in nman.get('missing', [])]
    else:
        network = dict(reaches=[], heads=[], confluences=[], falls=[], springs=[], cave_springs=[], coast_outlets=[], cold_air_pools=[],
                       lakes=lakes)
        missing, later = ['network reaches, heads, falls, springs, outlets (R5), and with them the carved rivers (R6 item 3)'], []
    # complete: every field the tile bake reads is in (ground, water, flow, fresh water). What R7 and later stages add is listed
    # under later and does not stop the bake: R5's own refinements, seasonal ponds, and the cold-air pools and snow window the
    # runtime reads (design R7 item 7).
    later += ['seasonal ponds (class 9): closed hollows that hold water only in the wet season, from R3 levels by season',
              'brooks narrower than about 8 m (R7 draws them from the reach polylines)',
              'cold-air pools (stage D; read by R7)', 'snow window (A4 snow layer; read by R7)']
    complete = not missing
    json.dump(network, open(os.path.join(rec_dir, 'network.json'), 'w'), indent=1)
    # One sky (design A4): the island's latitude from its tile row on the world grid (world.py), never a fixed number, and
    # its sea-level annual mean from the world's temperature curve there, unless params set one.
    sky = world.sky(P, oz, float(g16.shape[0]) * dx16)
    climate = json.loads(json.dumps(RC['climate']))
    d = dict(climate['default'], latitude_deg=sky['latitude_deg'])
    if 'sea_level_mean_c' not in d:          # from the world's curve at that latitude (coordinator 8 Nov, #717 row 21)
        if sky['world_curve_sea_level_c'] is None:
            raise SystemExit('record: params give no sea_level_mean_c and world.json has no temperature curve')
        d['sea_level_mean_c'] = sky['world_curve_sea_level_c']
    climate['default'] = d
    json.dump(climate, open(os.path.join(rec_dir, 'climate.json'), 'w'), indent=1)

    land = g > 0.0
    summary = dict(seconds=round(time.time() - t0, 1), grid_8m=m, tiles=P['tiles'], sky=dict(sky, sea_level_mean_c=climate['default']['sea_level_mean_c'], snow_bias_c=climate['default'].get('snow_bias_c')),
                   summit_16m=summit16, summit_8m=float(g.max()), summit_8m_before_roughness=summit8_smooth,
                   roughness=dict(rms_slope=rough_rms_slope, removed_cells=roughness_removed_cells),
                   closed_cells_outside_lakes=int(fault_idx.size), closed_cells_highest=fault_list,
                   land_km2=float(land.sum() * SPACING * SPACING / 1e6), lake_km2=float(lake_wet.sum() * SPACING * SPACING / 1e6),
                   wetland_km2=float((wet8 > 0).sum() * SPACING * SPACING / 1e6), missing=missing, later=later,
                   rivers=dict(segments=int(segs.shape[0]), carved_cells=int(carved_cells),
                               river_km2=float((wclass == RIVER).sum() * SPACING * SPACING / 1e6),
                               seasonal_channel_km2=float((wclass == SEASONAL_CHANNEL).sum() * SPACING * SPACING / 1e6)),
                   # R5's island season shares (quick and base flow in the wet and dry quarters over their means), for the readers'
                   # dry-season and drought answers (docs/water/springs_and_drinking_water.md)
                   seasons=nman['summary'].get('seasons') if network_dir else None)
    manifest = dict(version=VERSION, complete=complete, record_sha=git_sha(), cell_m=SPACING, origin_x=ox, origin_z=oz,
                    tile_samples=T + 1, tiles=P['tiles'], inputs=hashes,
                    stage_manifests={k: (json.load(open(p)).get('inputs', json.load(open(p)).get('inputs_sha256')) if os.path.exists(p) else None) for k, p in
                                     (('inputs', f'{inputs_dir}/inputs_manifest.json'), ('glacial', f'{b2_dir}/glacial_manifest.json'),
                                      ('lakes', f'{r3_dir}/lakes_manifest.json'), ('groundwater', f'{r4_dir}/groundwater_manifest.json'))},
                    fields=[dict(name=nm, type=typ, file=f'{nm}.{typ}', **info) for nm, _, typ, info in fields],
                    params=RC, summary=summary)
    json.dump(manifest, open(os.path.join(rec_dir, 'manifest.json'), 'w'), indent=1)
    print(json.dumps(summary, indent=1))


if __name__ == '__main__':
    main()
