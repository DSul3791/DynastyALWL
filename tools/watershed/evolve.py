"""Stage B of the watershed rebuild (docs/water/watershed_rebuild_design.md): landscape evolution that makes the final ground.

Usage (on Dave's PC, never in the cloud):
  python tools/watershed/evolve.py INPUTS_DIR GEOLOGY_DIR OUT_DIR [params.json]

Starts from the landform (stage A1) and runs, per time step:
  1. routing: priority flood and steepest descent on the filled surface (tools/erosion_precarve/lem.py route, reused);
  2. discharge: rain-weighted drainage area, Q_i = sum over the cells draining through i of rain share x cell area;
  3. stream power with deposition, implicit (Braun and Willett 2013 for the erosion; the deposition term of the Davy and Lague
     2009 / Yuan et al. 2019 erosion-deposition model):
        dh/dt = U - K e Q^m S + (G / Q) * sum over the catchment of (U - dh/dt) * rain * cell
     solved node by node from the outlets up, with Gauss-Seidel sweeps for the sediment term;
     no fluvial erosion where the drainage area is under channel_area_m2 (hillslope only), so weak flows cut no gullies;
  4. hillslope diffusion (soil creep), explicit with sub-steps.
U is the uplift (stage A2), e the rock erodibility at each cell's current height (stage A3, rock.py), rain from stage A4.
The sea and its level never change.

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


@nb.njit(cache=True)
def _discharge(order, rec, sea, rain, cell, N):
    Q = np.zeros(N)
    for q in range(order.size):
        i = order[q]
        Q[i] = rain[i] * cell
    for q in range(order.size - 1, -1, -1):
        i = order[q]; d = rec[i]
        if d >= 0 and not sea[d]:
            Q[d] += Q[i]
    return Q


@nb.njit(cache=True)
def _channel_share(area, a_c):
    # 0 below half the channel area, 1 above it, smooth between: fluvial erosion only where a channel can hold.
    out = np.empty(area.size)
    for i in range(area.size):
        t = (area[i] - 0.5 * a_c) / (0.5 * a_c)
        t = 0.0 if t < 0.0 else (1.0 if t > 1.0 else t)
        out[i] = t * t * (3.0 - 2.0 * t)
    return out


@nb.njit(cache=True)
def _fluvial(h, h0, sea, order, rec, n, dx, dt, K, m, G, U, ery, Q, rain, share, cell, sweeps, tol):
    """Implicit stream power with deposition. h holds h0 on entry and the new heights on exit."""
    N = n * n
    up = np.zeros(N)          # sum over strictly upstream cells of (U - dh/dt) * rain * cell, from the previous sweep
    for s in range(sweeps):
        biggest = 0.0
        for q in range(order.size):                     # downstream first: a receiver is always solved before its donors
            i = order[q]; d = rec[i]
            if sea[i]:
                continue
            Qi = Q[i] if Q[i] > 0.0 else cell
            c = G * rain[i] * cell / Qi                  # the node's own share of the sediment term
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
            change = abs(x - h[i])
            if change > biggest:
                biggest = change
            h[i] = x
        # sediment from upstream for the next sweep: accumulate (U - dh/dt) * rain * cell up the tree, then shift by one node
        own = np.zeros(N)
        for q in range(order.size):
            i = order[q]
            own[i] = (U[i] - (h[i] - h0[i]) / dt) * rain[i] * cell
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


@nb.njit(cache=True)
def _diffuse(h, sea, n, dx, dt, D, ery):
    ns = int(np.ceil(D * dt / (dx * dx) / 0.2))
    if ns < 1:
        ns = 1
    kk = D * dt / ns / (dx * dx)
    for s in range(ns):
        b = h.copy()
        for r in range(1, n - 1):
            for c in range(1, n - 1):
                i = r * n + c
                if sea[i]:
                    continue
                lap = b[i - 1] + b[i + 1] + b[i - n] + b[i + n] - 4.0 * b[i]
                v = b[i] + kk * ery[i] ** 0.3 * lap      # creep depends only weakly on rock hardness (as lem.py)
                h[i] = v if v > 0.05 else 0.05


def sha(path):
    return hashlib.sha256(open(path, 'rb').read()).hexdigest()


def main():
    inputs_dir, geology_dir, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    P = json.load(open(sys.argv[4] if len(sys.argv) > 4 else os.path.join(HERE, 'params.json')))
    E = P['evolve']
    os.makedirs(out_dir, exist_ok=True)
    data = np.load(f'{inputs_dir}/inputs.npz')
    start = data['landform'].astype(np.float64)
    n = start.shape[0]
    dx = float(data['cell_m'])
    cell = dx * dx
    sea = data['sea'].ravel().astype(np.uint8)
    U = data['uplift'].astype(np.float64).ravel()
    rain = (data['rain'].astype(np.float64) / P['rain']['background_mm_yr']).ravel()
    h = start.ravel().copy()
    h[sea == 1] = np.minimum(h[sea == 1], -1.0)
    g = rock.load(geology_dir, E['cover_m'], E['cover_erodibility'])
    ery_fn = rock.make_fn(g, start, sea, dx)
    a_c = float(E['channel_area_m2'])
    steps = int(round(E['years'] / E['dt']))
    t0 = time.time()
    deposit = np.zeros(n * n)
    for s in range(steps):
        filled, rec, order = lem.route(h, sea, n)
        Q = _discharge(order, rec, sea, rain, cell, n * n)
        area = _discharge(order, rec, sea, np.ones(n * n), cell, n * n)
        share = _channel_share(area, a_c)
        ery = ery_fn(h)
        h0 = h.copy()
        _fluvial(h, h0, sea, order, rec, n, dx, E['dt'], E['K'], E['m'], E['G'], U, ery, Q, rain, share, cell, E['sweeps'], E['tol_m'])
        _diffuse(h, sea, n, dx, E['dt'], E['D'], ery)
        change = h - (h0 + U * E['dt'])
        deposit = np.maximum(deposit + change, 0.0)          # sediment lying on bedrock: grows where it lands, wears where it erodes
        ery_fn.update(change)
        if s % 25 == 0:
            print(f'step {s}/{steps} t {time.time() - t0:.0f} s, max h {h.max():.0f} m', flush=True)
    filled, rec, order = lem.route(h, sea, n)
    Q = _discharge(order, rec, sea, rain, cell, n * n)
    area = _discharge(order, rec, sea, np.ones(n * n), cell, n * n)
    hh = h.reshape(n, n)
    np.savez_compressed(f'{out_dir}/ground.npz', ground=hh.astype(np.float32), start=start.astype(np.float32),
                        discharge_m3_rain=Q.reshape(n, n).astype(np.float32), area_m2=area.reshape(n, n).astype(np.float32),
                        receiver=rec.reshape(n, n).astype(np.int32), pit_m=(filled - h).reshape(n, n).astype(np.float32),
                        sediment_m=deposit.reshape(n, n).astype(np.float32), sea=sea.reshape(n, n).astype(bool),
                        cell_m=dx, origin_x=float(data['origin_x']), origin_z=float(data['origin_z']))
    land = sea.reshape(n, n) == 0
    gy, gx = np.gradient(hh, dx)
    slope = np.degrees(np.arctan(np.hypot(gx, gy)))
    pits = (filled - h).reshape(n, n)
    summary = dict(seconds=time.time() - t0, steps=steps, summit_m=float(hh.max()), land_km2=float(land.sum() * cell / 1e6),
                   median_slope_deg=float(np.median(slope[land])), share_under_10deg_below_250m=float((slope[land & (hh < 250)] < 10).mean()),
                   closed_hollow_cells=int((pits[land] > 0.01).sum()), deepest_hollow_m=float(pits[land].max()),
                   sediment_km2_over_1m=float((deposit.reshape(n, n)[land] > 1.0).sum() * cell / 1e6),
                   max_cut_m=float((start - hh)[land].max()), max_fill_m=float((hh - start)[land].max()))
    json.dump(dict(params=P, inputs_sha256={'inputs.npz': sha(f'{inputs_dir}/inputs.npz')}, summary=summary),
              open(f'{out_dir}/evolve_manifest.json', 'w'), indent=1)
    print(json.dumps(summary, indent=1))

    import matplotlib; matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.colors import LightSource
    ls = LightSource(315, 40)
    fig, ax = plt.subplots(1, 3, figsize=(27, 9))
    for a, z, t in ((ax[0], start, 'landform (start)'), (ax[1], hh, 'final ground')):
        a.imshow(ls.shade(np.where(land, z, -30), cmap=plt.cm.terrain, vert_exag=3, blend_mode='soft', dx=dx, dy=dx)); a.set_title(t)
    ax[1].imshow(np.where(land & (area.reshape(n, n) > 0.5e6), 1, np.nan), cmap='winter', alpha=0.8)
    im = ax[2].imshow(np.where(land, deposit.reshape(n, n), np.nan), cmap='YlOrBr', vmax=10); ax[2].set_title('sediment (m): floodplains, fans, deltas')
    fig.colorbar(im, ax=ax[2], shrink=0.7)
    for a in ax: a.axis('off')
    plt.tight_layout(); plt.savefig(f'{out_dir}/evolve.png', dpi=70)


if __name__ == '__main__':
    main()
