"""Stage B of the watershed rebuild (docs/water/watershed_rebuild_design.md): landscape evolution that makes the final ground.

Usage (on Dave's PC, never in the cloud):
  python tools/watershed/evolve.py INPUTS_DIR GEOLOGY_DIR OUT_DIR [params.json] [--calibrate=PREV_RUN_DIR] [--set.BLOCK.KEY=VALUE ...]
--set.BLOCK.KEY=VALUE: one parameter changed for this run only (VALUE read as JSON, e.g. --set.evolve.D=0.01); the manifest
records the parameters as run, so a variant needs no edited params file.
--calibrate: the uplift is calibrated from a previous run's result so the eroded island keeps the landform's heights at the
scale of the massifs (see calibrated_uplift).

Starts from the landform (stage A1) and runs, per time step:
  1. routing: priority flood and steepest descent on the filled surface (tools/erosion_precarve/lem.py route, reused);
  2. discharge: the QUICK runoff of the one water budget (stage A5, runoff.py: rain minus evaporation, times the rock's quick
     share) accumulated downstream, in units of the reference quick runoff times area, so permeable and dry ground cuts less;
  3. stream power with deposition, implicit (Braun and Willett 2013 for the erosion; the deposition term of the Davy and Lague
     2009 / Yuan et al. 2019 erosion-deposition model):
        dh/dt = U - K e Q^m S + (G / Q) * sum over the catchment of (U - dh/dt) * cell
     solved node by node from the outlets up, with Gauss-Seidel sweeps for the sediment term;
     fluvial erosion only where a channel has begun: a channel begins where Q * S^theta passes a threshold (the slope-area rule
     of Montgomery and Dietrich 1988: steeper hollows need less water) and then continues downstream whatever the slope, so
     weak flows cut no gullies and wet hills carry more channels than dry or permeable ones;
     threshold hillslopes, inside the same solve: no cell may stand steeper than the threshold slope above its receiver
     (landslides; see _fluvial), and what a slide removes joins the sediment carried down the same tree;
  4. hillslope diffusion (soil creep), implicit (one backward-Euler sweep along rows, then along columns).
U is the uplift (stage A2), e the rock erodibility at each cell's current height (stage A3, rock.py), Q from stages A4 and A5.
The sea and its level never change. Sediment reaching the sea leaves the model; its flux through each river mouth is saved
(sediment_flux_m3_yr) so stage C8 can tell a delta (high supply, low slope) from a rocky outlet.

Writes OUT_DIR/ground.npz (final ground, discharge, receivers, sediment thickness, and the start), evolve.png and
evolve_manifest.json. Note (7 Nov 2026): the Yuan et al. (2019) PDF could not be fetched from the cloud session; the deposition
term above is the published form of the Davy and Lague model as Yuan et al. use it, to be checked against the paper on the next
research pass (docs/knowledge/water.md)."""
import sys, os, json, time, hashlib
import numpy as np
import numba as nb

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'erosion_precarve'))
import lem    # noqa: E402  (route: priority flood + receivers)
import rock   # noqa: E402
import runoff  # noqa: E402  (stage A5: the one water budget)


@nb.njit(cache=True)
def _discharge(order, rec, sea, w, cell, N):
    Q = np.zeros(N)
    for q in range(order.size):
        i = order[q]
        Q[i] = w[i] * cell
    for q in range(order.size - 1, -1, -1):
        i = order[q]; d = rec[i]
        if d >= 0 and not sea[d]:
            Q[d] += Q[i]
    return Q


@nb.njit(cache=True)
def _channel_share(Q, h, rec, order, sea, n, dx, c_ch, theta):
    """How much of each cell is channel (0 hillslope, 1 channel). A channel begins where Q * S^theta passes c_ch (smoothly
    from half of it), with S the slope to the receiver, and once begun it continues downstream at any slope."""
    out = np.zeros(Q.size)
    for q in range(order.size):
        i = order[q]; d = rec[i]
        if d < 0:
            continue
        dist = dx
        if abs(d - i) != 1 and abs(d - i) != n:
            dist = dx * 1.4142135623730951
        s = (h[i] - h[d]) / dist
        if s < 0.0:
            s = 0.0
        t = (Q[i] * s ** theta / c_ch - 0.5) / 0.5
        t = 0.0 if t < 0.0 else (1.0 if t > 1.0 else t)
        out[i] = t * t * (3.0 - 2.0 * t)
    for q in range(order.size - 1, -1, -1):          # upstream first: a channel carries on down to the sea or a lake
        i = order[q]; d = rec[i]
        if d >= 0 and not sea[d] and out[i] > out[d]:
            out[d] = out[i]
    return out


@nb.njit(cache=True)
def _hollows(pit, rec, sea, n, min_depth):
    """Closed hollows of the final ground: 8-connected groups of land cells lying more than min_depth below the filled surface.
    For each: its deepest cell, depth and size, and its outlet, the first cell out of the hollow on the receiver path from the
    deepest cell (the sill or dam the water would spill over)."""
    N = n * n
    lab = np.full(N, -1, np.int64)
    stack = np.empty(N, np.int64)
    deep = np.empty(N, np.int64)
    size = np.empty(N, np.int64)
    k = 0
    for s in range(N):
        if lab[s] >= 0 or sea[s] or pit[s] <= min_depth:
            continue
        lab[s] = k
        stack[0] = s
        top = 1
        best = s
        cnt = 0
        while top > 0:
            top -= 1
            i = stack[top]
            cnt += 1
            if pit[i] > pit[best]:
                best = i
            r = i // n
            c = i % n
            for dr in range(-1, 2):
                for dc in range(-1, 2):
                    rr = r + dr
                    cc = c + dc
                    if rr < 0 or rr >= n or cc < 0 or cc >= n:
                        continue
                    j = rr * n + cc
                    if lab[j] < 0 and not sea[j] and pit[j] > min_depth:
                        lab[j] = k
                        stack[top] = j
                        top += 1
        deep[k] = best
        size[k] = cnt
        k += 1
    outlet = np.full(k, -1, np.int64)
    for q in range(k):
        i = deep[q]
        steps = 0
        while i >= 0 and lab[i] == q and steps < N:
            i = rec[i]
            steps += 1
        outlet[q] = i
    return lab, deep[:k], size[:k], outlet


@nb.njit(cache=True)
def _fluvial(h, h0, sea, order, rec, n, dx, dt, K, m, G, U, ery, Q, share, cell, sweeps, tol, Sc):
    """Implicit stream power with deposition. h holds h0 on entry and the new heights on exit.
    Returns the sediment flux through each cell (m3/yr, own cell included) from the last sweep.

    Threshold hillslopes (Sc per cell, the tangent of the threshold angle; 0 turns it off there). Where uplift outpaces erosion, real
    hillslopes do not steepen without end: past a threshold angle they fail by landslides, so their mean angle stays near that
    threshold whatever the erosion rate (Burbank et al. 1996, Nature 379:505; Montgomery 2001, Am. J. Sci. 301:432). Linear
    creep alone has no such limit, and run 624bd23c grew a ridge more than 1,000 m above its landform with 40 to 45 degree
    flanks. So each cell, solved after its receiver, is capped at the receiver's height plus Sc times the distance. The cap
    lowers the cell; the volume it loses counts as eroded material in the sediment sum below, so the slide debris travels down
    the same tree and is laid down where the water cannot carry it (talus and fans at the slope foot, as the hybrid landslide
    model of Campforts et al. 2020, GMD 13:3863, routes it), instead of vanishing. Against the sea, the cap is measured from sea
    level, not from the sea floor, which this model does not evolve."""
    N = n * n
    up = np.zeros(N)
    total = np.zeros(N)          # sum over strictly upstream cells of (U - dh/dt) * cell, from the previous sweep
    for s in range(sweeps):
        biggest = 0.0
        for q in range(order.size):                     # downstream first: a receiver is always solved before its donors
            i = order[q]; d = rec[i]
            if sea[i]:
                continue
            Qi = Q[i] if Q[i] > 0.0 else cell
            c = G * cell / Qi                            # the node's own share of the sediment term (its own eroded volume)
            dist = dx
            if d >= 0 and abs(d - i) != 1 and abs(d - i) != n:
                dist = dx * 1.4142135623730951
            F = 0.0
            if d >= 0:
                F = K * ery[i] * share[i] * Qi ** m / dist
            hr = h[d] if d >= 0 else h0[i]
            num = h0[i] * (1.0 + c) / dt + U[i] * (1.0 + c) + F * hr + G / Qi * up[i]
            x = num / ((1.0 + c) / dt + F)
            if x < hr and F > 0.0:                       # never cut below the receiver: no erosion there, only deposition
                x = (h0[i] * (1.0 + c) / dt + U[i] * (1.0 + c) + G / Qi * up[i]) / ((1.0 + c) / dt)
                if x > hr:
                    x = hr
            if Sc[i] > 0.0 and d >= 0:
                base = hr
                if sea[d] and base < 0.0:
                    base = 0.0
                if x > base + Sc[i] * dist:
                    x = base + Sc[i] * dist
            change = abs(x - h[i])
            if change > biggest:
                biggest = change
            h[i] = x
        # sediment from upstream for the next sweep: accumulate the eroded volume (U - dh/dt) * cell up the tree, then shift by
        # one node. It is a volume of rock and soil, so it is NOT weighted by rain; the rain enters through Q (the water that
        # carries it): deposition rate = G * sediment flux / Q (Davy and Lague 2009 in the form of Yuan et al. 2019, with Q the
        # quick-runoff-weighted area, so G stays dimensionless). Little water carries little sediment: dry ground fills.
        own = np.zeros(N)
        for q in range(order.size):
            i = order[q]
            own[i] = (U[i] - (h[i] - h0[i]) / dt) * cell
        total = own.copy()
        for q in range(order.size - 1, -1, -1):
            i = order[q]; d = rec[i]
            if d >= 0 and not sea[d]:
                total[d] += total[i]
        for i in range(N):
            up[i] = total[i] - own[i]
            if up[i] < 0.0:
                up[i] = 0.0                              # net erosion upstream brings sediment; it never removes it
        if biggest < tol:
            break
    return total


@nb.njit(cache=True)
def _thomas(a, b, c, d, x, m):
    """Solve a[i] x[i-1] + b[i] x[i] + c[i] x[i+1] = d[i] for i in 0..m-1 (a[0] and c[m-1] unused). Overwrites c and d."""
    c[0] = c[0] / b[0]
    d[0] = d[0] / b[0]
    for i in range(1, m):
        w = b[i] - a[i] * c[i - 1]
        c[i] = c[i] / w
        d[i] = (d[i] - a[i] * d[i - 1]) / w
    x[m - 1] = d[m - 1]
    for i in range(m - 2, -1, -1):
        x[i] = d[i] - c[i] * x[i + 1]


@nb.njit(cache=True, parallel=True)
def _creep_sweep(h, fixed, k, n, along_rows):
    """One backward-Euler creep step along every row (or every column), each a tridiagonal solve. k[i] = dt * D_i / dx^2.
    Fixed cells (sea and the model frame) keep their height. Face coefficients are the mean of the two cells, so the
    exchange is conservative between land cells."""
    out = np.empty_like(h)
    for line in nb.prange(n):
        a = np.zeros(n)
        b = np.ones(n)
        c = np.zeros(n)
        d = np.empty(n)
        x = np.empty(n)
        for j in range(n):
            i = line * n + j if along_rows else j * n + line
            d[j] = h[i]
            if fixed[i]:
                continue
            if j > 0:
                im = i - 1 if along_rows else i - n
                kf = 0.5 * (k[i] + k[im])
                a[j] = -kf
                b[j] += kf
            if j < n - 1:
                ip = i + 1 if along_rows else i + n
                kf = 0.5 * (k[i] + k[ip])
                c[j] = -kf
                b[j] += kf
        _thomas(a, b, c, d, x, n)
        for j in range(n):
            i = line * n + j if along_rows else j * n + line
            out[i] = x[j]
    return out


def _diffuse(h, fixed, dx, dt, D, ery):
    """Soil creep, implicit (one backward-Euler sweep along the rows, then one along the columns), so it is stable at any time
    step. The earlier explicit form needed sub-steps in proportion to D dt / dx^2 (26 a step at dt 16 kyr), and its first
    version blew up when the sub-steps ignored the softer ground (Dino, 7 Nov). Creep runs at D * ery^0.3 (depends only
    weakly on rock hardness, as in lem.py)."""
    n = int(round(np.sqrt(h.size)))
    k = np.where(fixed, 0.0, dt * D * ery ** 0.3 / (dx * dx))
    hr = _creep_sweep(h, fixed, k, n, True)
    hc = _creep_sweep(hr, fixed, k, n, False)
    land = ~fixed
    h[land] = np.maximum(hc[land], 0.05)


def calibrated_uplift(U, start, prev_dir, sea, dx, P):
    """Uplift calibrated from a previous run (stage A2's one free choice, design B1). The real uplift of the island is
    unknown; the landform says how high its massifs should stand. At steady state the height of the ground scales with the
    uplift (relief about U/K), so the uplift is multiplied by the ratio of the landform to the previous result, both smoothed
    at the uplift's own scale (uplift.smooth_m, so no hill-scale pattern enters, R1's rule) and both offset by
    calibration_offset_m so the low coast does not give wild ratios. The valleys, ridges and slopes still come only from
    the erosion. One pass is expected to be enough; the summary reports how far the result still is from the landform."""
    from scipy.ndimage import gaussian_filter
    u = P['uplift']
    prev = np.load(f'{prev_dir}/ground.npz')
    U_prev = prev['uplift'].astype(np.float64).ravel() if 'uplift' in prev.files else U
    g_prev = prev['ground'].astype(np.float64)
    if g_prev.shape != start.shape:
        raise SystemExit('evolve: the run to calibrate from is on another grid')
    s = u['smooth_m'] / dx
    off = float(u['calibration_offset_m'])
    want = gaussian_filter(np.maximum(start, 0.0), s)
    got = gaussian_filter(np.maximum(g_prev, 0.0), s)
    lo, hi = u['calibration_clip']
    f = np.clip((want + off) / (got + off), lo, hi).ravel()
    f[sea == 1] = 0.0
    return U_prev * f, f, sha(f'{prev_dir}/ground.npz')


def sha(path):
    return hashlib.sha256(open(path, 'rb').read()).hexdigest()


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    opts = dict(a[2:].split('=', 1) for a in sys.argv[1:] if a.startswith('--') and '=' in a)
    inputs_dir, geology_dir, out_dir = args[0], args[1], args[2]
    P = json.load(open(args[3] if len(args) > 3 else os.path.join(HERE, 'params.json')))
    for key, val in opts.items():                          # --set.BLOCK.KEY=VALUE overrides, recorded in the manifest's params
        if key.startswith('set.'):
            *path, last = key[4:].split('.')
            node = P
            for part in path:
                node = node[part]
            if last not in node:
                raise SystemExit(f'evolve: --{key}: no such parameter')
            node[last] = json.loads(val)
            print(f'parameter {key[4:]} = {node[last]!r} for this run', flush=True)
    E = P['evolve']
    os.makedirs(out_dir, exist_ok=True)
    data = np.load(f'{inputs_dir}/inputs.npz')
    start = data['landform'].astype(np.float64)
    n = start.shape[0]
    dx = float(data['cell_m'])
    cell = dx * dx
    sea = data['sea'].ravel().astype(np.uint8)
    U = data['uplift'].astype(np.float64).ravel()
    calib = None
    if 'calibrate' in opts:
        U, factor, prev_sha = calibrated_uplift(U, start, opts['calibrate'], sea, dx, P)
        calib = dict(from_dir=opts['calibrate'], from_ground_sha256=prev_sha,
                     factor_land_min=float(factor[sea == 0].min()), factor_land_mean=float(factor[sea == 0].mean()),
                     factor_land_max=float(factor[sea == 0].max()), uplift_max_m_per_kyr=float(U.max()) * 1e3)
        print(f'calibrated uplift from {opts["calibrate"]}: factor {calib["factor_land_min"]:.2f} to {calib["factor_land_max"]:.2f}', flush=True)
    # uplift_share: how much of the A2 uplift still acts during the run. 0 = the landform is the land as uplifted, and the run
    # is its dissection by rivers and slopes (see the params note).
    U = U * float(E.get('uplift_share', 1.0))
    rain_mm = data['rain'].astype(np.float64).ravel()
    W = P['water_budget']
    q_ref = runoff.reference_quick_mm(P['rain']['background_mm_yr'], W)
    h = start.ravel().copy()
    # Initial roughness: a smooth landform drains in straight parallel lines (steepest descent on a plane); small uncorrelated
    # roughness, fixed by world position, lets the channels find each other and branch, as on any real surface. The erosion
    # then removes it: it is a starting condition, not detail laid on the result.
    if E.get('start_roughness_m', 0.0) > 0.0:
        col = int(round(float(data['origin_x']) / dx)) + np.arange(n, dtype=np.int64)
        row = int(round(float(data['origin_z']) / dx)) + np.arange(n, dtype=np.int64)
        C, R = np.meshgrid(col, row)
        k = (C * 73856093) ^ (R * 19349663) ^ int(P['seed'])
        k = ((k ^ (k >> 13)) * 1274126177) & 0x7FFFFFFF
        k = (k ^ (k >> 16)) & 0xFFFFFF
        rough = (k.astype(np.float64) / float(0xFFFFFF) - 0.5) * 2.0 * E['start_roughness_m']
        h = np.where(sea == 1, h, np.maximum(h + rough.ravel(), 0.05))
    h[sea == 1] = np.minimum(h[sea == 1], -1.0)
    g = rock.load(geology_dir, E['cover_m'], E['cover_erodibility'])
    bfi = runoff.bfi_by_rock_id(g['names'], W['bfi_by_rock'])
    ery_fn = rock.make_fn(g, start, sea, dx)
    CH = E['channel_head']
    theta = float(CH['slope_exponent'])
    c_ch = float(CH['area_m2_at_ref_slope']) * float(CH['ref_slope']) ** theta
    Sc = float(np.tan(np.radians(E['threshold_slope_deg']))) if E.get('threshold_slope_deg', 0.0) > 0.0 else 0.0
    # Hard rock holds steeper walls than soft rock or loose cover (Schmidt and Montgomery 1995): the threshold by rock, with
    # the plain threshold_slope_deg for loose sediment over 1 m and for any rock not listed.
    by = E.get('threshold_slope_deg_by_rock', {})
    sc_rock = np.full(max(g['names']) + 1, Sc)
    for k_, nm in g['names'].items():
        if nm in by and Sc > 0.0:
            sc_rock[k_] = float(np.tan(np.radians(by[nm])))
    steps = int(round(E['years'] / E['dt']))
    t0 = time.time()
    deposit = np.zeros(n * n)
    land0 = sea == 0
    frame = np.zeros((n, n), bool); frame[0, :] = frame[-1, :] = frame[:, 0] = frame[:, -1] = True
    fixed = (sea == 1) | frame.ravel()                     # creep leaves the sea and the model frame as they are
    track = []                                             # (step, summit, mean land height): is the ground still rising?
    # Which process lowers the ground: the river solve (with the slides of the slope limit) or creep, summed over the run.
    by_river = np.zeros(n * n)
    by_creep = np.zeros(n * n)
    def write(od, years_done):
        """All outputs for the ground as it stands: ground.npz, the summary (evolve_manifest.json) and evolve.png."""
        os.makedirs(od, exist_ok=True)
        filled, rec, order = lem.route(h, sea, n)
        rid = rock.rock_ids(g, h)
        wb = runoff.budget(rain_mm, rid, bfi, W)
        Q = _discharge(order, rec, sea, wb['quick'] / q_ref, cell, n * n)
        share = _channel_share(Q, h, rec, order, sea, n, dx, c_ch, theta)
        area = _discharge(order, rec, sea, np.ones(n * n), cell, n * n)
        hh = h.reshape(n, n)
        np.savez_compressed(f'{od}/ground.npz', ground=hh.astype(np.float32), start=start.astype(np.float32),
                            quick_area_m2=Q.reshape(n, n).astype(np.float32), area_m2=area.reshape(n, n).astype(np.float32),
                            channel=share.reshape(n, n).astype(np.float32), rock=rid.reshape(n, n).astype(np.int16),
                            et_mm=wb['et'].reshape(n, n).astype(np.float32), quick_mm=wb['quick'].reshape(n, n).astype(np.float32),
                            recharge_mm=wb['recharge'].reshape(n, n).astype(np.float32),
                            receiver=rec.reshape(n, n).astype(np.int32), pit_m=(filled - h).reshape(n, n).astype(np.float32),
                            sediment_m=deposit.reshape(n, n).astype(np.float32), sea=sea.reshape(n, n).astype(bool),
                            sediment_flux_m3_yr=flux.reshape(n, n).astype(np.float32), uplift=U.reshape(n, n).astype(np.float32),
                            cell_m=dx, origin_x=float(data['origin_x']), origin_z=float(data['origin_z']))
        land = sea.reshape(n, n) == 0
        gy, gx = np.gradient(hh, dx)
        slope = np.degrees(np.arctan(np.hypot(gx, gy)))
        pits = (filled - h).reshape(n, n)
        # Hollows (R3 gives each a cause or fills it): is the sill that holds each one sediment (a fan, floodplain or delta laid
        # across the valley, a real cause) or rock? 0.1 m and deeper, so the 1 mm-per-cell slope the fill puts on flats is not
        # counted as a hollow. The ten deepest are listed in world metres so they can be looked at.
        pr = pits.ravel()
        lab, deep, size, outlet = _hollows(pr, rec, sea, n, 0.1)
        chmax = np.zeros(deep.size)
        inside = lab >= 0
        np.maximum.at(chmax, lab[inside], share[inside])
        sill_sed = np.where(outlet >= 0, deposit[np.maximum(outlet, 0)], 0.0)

        def _group(sel):
            return dict(count=int(sel.sum()), km2=float(size[sel].sum() * cell / 1e6),
                        deepest_m=float(pr[deep[sel]].max()) if sel.any() else 0.0)
        ox, oz = float(data['origin_x']), float(data['origin_z'])
        hollows = dict(min_depth_m=0.1, all=_group(np.ones(deep.size, bool)),
                       sill_on_sediment_over_1m=_group(sill_sed > 1.0), sill_on_rock_or_thin_cover=_group(sill_sed <= 1.0),
                       on_a_channel=_group(chmax > 0.5), off_channels=_group(chmax <= 0.5),
                       deepest_ten=[dict(x=ox + float(deep[q] % n) * dx, z=oz + float(deep[q] // n) * dx, depth_m=float(pr[deep[q]]),
                                         km2=float(size[q] * cell / 1e6), sill_sediment_m=float(sill_sed[q]),
                                         floor_sediment_m=float(deposit[deep[q]]), on_a_channel=bool(chmax[q] > 0.5))
                                    for q in np.argsort(-pr[deep])[:10]])
        # Threshold check: the share of land within 10% of the threshold slope above its receiver (where landslides set the form).
        # 10%, not exactly at it, because creep runs after the cap each step and rounds the capped slopes a little.
        hr_ = np.where(rec >= 0, h[np.maximum(rec, 0)], h)
        hr_ = np.where((rec >= 0) & (sea[np.maximum(rec, 0)] == 1), np.maximum(hr_, 0.0), hr_)
        step_ = np.abs(rec - np.arange(n * n))
        dist_ = np.where((step_ == 1) | (step_ == n), dx, dx * np.sqrt(2.0))
        s_rec = np.where(rec >= 0, (h - hr_) / dist_, 0.0).reshape(n, n)
        # Steady state check: how fast the summit and the mean land height still change over the last tenth of the run. Near zero
        # means uplift and erosion balance (a mature landscape); a rise near the uplift rate means erosion never reached the tops.
        k = max(len(track) // 10, 1)
        span_kyr = k * E['dt'] / 1e3
        from scipy.ndimage import gaussian_filter
        sm = P['uplift']['smooth_m'] / dx
        mismatch = (gaussian_filter(np.maximum(hh, 0.0), sm) - gaussian_filter(np.maximum(start, 0.0), sm))[land]
        # Are the peaks kept and the valleys cut? Land height percentiles against the landform's, and the local relief (highest
        # minus lowest ground within 2 km) over the high ground (landform above 600 m): deep glens between tall peaks raise it.
        from scipy.ndimage import maximum_filter, minimum_filter
        win = int(round(2000.0 / dx)) | 1
        pct = (50, 90, 99, 99.9)

        def _relief(z):
            r = (maximum_filter(z, win) - minimum_filter(z, win))[land & (start > 600.0)]
            return dict(p50=float(np.percentile(r, 50)), p90=float(np.percentile(r, 90))) if r.size else {}
        # The landform's peaks (highest point within 1 km, above 600 m): is each still standing? Its loss is the landform height
        # less the highest ground now within 200 m of it (a peak may shift a cell or two as its faces wear). The summit rule:
        # erosion carves valleys but does not take the peaks below the landform's heights.
        top = (start == maximum_filter(start, int(round(1000.0 / dx)) | 1)) & land & (start > 600.0)
        pk = np.flatnonzero(top.ravel())
        loss = start.ravel()[pk] - maximum_filter(hh, int(round(200.0 / dx)) | 1).ravel()[pk]
        rid2 = rid.reshape(n, n).ravel()
        near_pk = maximum_filter(top, int(round(200.0 / dx)) | 1).ravel() & (sea == 0)
        peaks = dict(count=int(pk.size), lost_over_25m=int((loss > 25.0).sum()), lost_over_100m=int((loss > 100.0).sum()),
                     mean_loss_m=float(loss.mean()) if pk.size else 0.0, worst_loss_m=float(loss.max()) if pk.size else 0.0,
                     highest_ten=[dict(x=ox + float(q % n) * dx, z=oz + float(q // n) * dx, landform_m=float(start.ravel()[q]),
                                       loss_m=float(lq), rock=g['names'][int(rid2[q])])
                                  for q, lq in sorted(zip(pk, loss), key=lambda t: -start.ravel()[t[0]])[:10]])
        lowering = {name: dict(river_and_slides_m=float(by_river[msk].mean()), creep_m=float(by_creep[msk].mean()))
                    for name, msk in (('near_landform_peaks', near_pk), ('all_land', sea == 0)) if msk.any()}
        summary = dict(seconds=time.time() - t0, steps=len(track), years=years_done, summit_m=float(hh.max()), landform_summit_m=float(start.max()),
                       uplift_calibration=calib,
                       massif_scale_height_mismatch_m=dict(mean=float(mismatch.mean()), p5=float(np.percentile(mismatch, 5)),
                                                           p95=float(np.percentile(mismatch, 95))),
                       last_tenth_summit_change_m_per_kyr=(track[-1][1] - track[-1 - k][1]) / span_kyr if len(track) > k else None,
                       last_tenth_mean_land_change_m_per_kyr=(track[-1][2] - track[-1 - k][2]) / span_kyr if len(track) > k else None,
                       uplift_max_m_per_kyr=float(U.max()) * 1e3, mean_land_m=float(hh[land].mean()), landform_mean_land_m=float(start[land].mean()),
                       land_height_percentiles_m={str(q): float(np.percentile(hh[land], q)) for q in pct},
                       landform_height_percentiles_m={str(q): float(np.percentile(start[land], q)) for q in pct},
                       local_relief_2km_on_high_ground_m=_relief(hh), landform_local_relief_2km_on_high_ground_m=_relief(start),
                       landform_peaks=peaks, height_change_by_process=lowering,
                       land_km2=float(land.sum() * cell / 1e6),
                       median_slope_deg=float(np.median(slope[land])), share_under_10deg_below_250m=float((slope[land & (hh < 250)] < 10).mean()),
                       closed_hollow_cells=int((pits[land] > 0.01).sum()), deepest_hollow_m=float(pits[land].max()), hollows=hollows,
                       threshold_slope_deg=float(E.get('threshold_slope_deg', 0.0)),
                       share_of_land_near_threshold=float((s_rec[land] >= 0.9 * np.where(deposit > 1.0, Sc, sc_rock[rid]).reshape(n, n)[land]).mean()) if Sc > 0.0 else 0.0,
                       threshold_slope_deg_by_rock=E.get('threshold_slope_deg_by_rock', {}),
                       share_of_land_steeper_than_deg={str(a): float((slope[land] > a).mean()) for a in (25, 30, 35, 40)},
                       max_slope_deg=float(slope[land].max()),
                       sediment_km2_over_1m=float((deposit.reshape(n, n)[land] > 1.0).sum() * cell / 1e6),
                       reference_quick_mm_yr=q_ref,
                       water_mm_yr={k: float(wb[k].reshape(n, n)[land].mean()) for k in ('et', 'runoff', 'quick', 'recharge')},
                       drainage_density_km_per_km2=float((share.reshape(n, n)[land] > 0.5).sum() * dx / 1e3 / (land.sum() * cell / 1e6)),
                       drainage_density_by_rock={g['names'][int(k)]: float(((share > 0.5) & (rid == k) & (sea == 0)).sum() * dx / 1e3
                                                                         / max(((rid == k) & (sea == 0)).sum() * cell / 1e6, 1e-9))
                                                 for k in np.unique(rid[sea == 0])},
                       max_cut_m=float((start - hh)[land].max()), max_fill_m=float((hh - start)[land].max()))
        json.dump(dict(params=P, inputs_sha256={'inputs.npz': sha(f'{inputs_dir}/inputs.npz')}, summary=summary),
                  open(f'{od}/evolve_manifest.json', 'w'), indent=1)
        print(json.dumps(summary, indent=1))

        import plots
        plots.ground_picture(f'{od}/ground.npz', f'{od}/evolve.png')

    snaps = {int(round(y / E['dt'])): y for y in E.get('snapshot_years', [])}
    for s in range(steps):
        filled, rec, order = lem.route(h, sea, n)
        rid_now = rock.rock_ids(g, h)
        quick = runoff.budget(rain_mm, rid_now, bfi, W)['quick'] / q_ref    # the rock at today's surface
        sc = np.where(deposit > 1.0, Sc, sc_rock[rid_now])
        Q = _discharge(order, rec, sea, quick, cell, n * n)
        share = _channel_share(Q, h, rec, order, sea, n, dx, c_ch, theta)
        ery = ery_fn(h)
        h0 = h.copy()
        flux = _fluvial(h, h0, sea, order, rec, n, dx, E['dt'], E['K'], E['m'], E['G'], U, ery, Q, share, cell, E['sweeps'], E['tol_m'], sc)
        h1 = h.copy()
        _diffuse(h, fixed, dx, E['dt'], E['D'], ery)
        by_river += h1 - (h0 + U * E['dt'])
        by_creep += h - h1
        change = h - (h0 + U * E['dt'])
        deposit = np.maximum(deposit + change, 0.0)          # sediment lying on bedrock: grows where it lands, wears where it erodes
        ery_fn.update(change)
        track.append((s, float(h.max()), float(h[land0].mean())))
        if s % 25 == 0:
            print(f'step {s}/{steps} t {time.time() - t0:.0f} s, max h {h.max():.0f} m, mean land {track[-1][2]:.0f} m', flush=True)
        # Fail loudly, never carry on: uplift alone over the whole run cannot lift any cell more than U * years above its start.
        bound = float(start.max()) + float(U.max()) * E['years'] + 100.0
        if not np.isfinite(h).all() or h.max() > bound:
            raise SystemExit(f'evolve: unstable at step {s}: max height {h.max():.3g} m is above the physical bound {bound:.0f} m')
        if s + 1 in snaps and s + 1 < steps:              # the ground part way through, for choosing the run length
            write(f'{out_dir}/t{int(round(snaps[s + 1] / 1e3))}k', (s + 1) * E['dt'])
    write(out_dir, E['years'])

if __name__ == '__main__':
    main()
