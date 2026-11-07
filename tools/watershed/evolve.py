"""Stage B of the watershed rebuild (docs/water/watershed_rebuild_design.md): landscape evolution that makes the final ground.

Usage (on Dave's PC, never in the cloud):
  python tools/watershed/evolve.py INPUTS_DIR GEOLOGY_DIR OUT_DIR [params.json]

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
  4. hillslope diffusion (soil creep), explicit with sub-steps.
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
def _fluvial(h, h0, sea, order, rec, n, dx, dt, K, m, G, U, ery, Q, share, cell, sweeps, tol):
    """Implicit stream power with deposition. h holds h0 on entry and the new heights on exit.
    Returns the sediment flux through each cell (m3/yr, own cell included) from the last sweep."""
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
def _diffuse(h, sea, n, dx, dt, D, ery):
    # Explicit creep is stable only while D_eff dt / dx^2 stays under 0.25 for the softest ground, so the sub-steps are set by
    # the largest D_eff = D * ery^0.3 (as lem.py does). The first R2 run counted D alone: soil cover (ery up to 5) put
    # D_eff dt / dx^2 near 0.3 per sub-step and the ground grew in a chequer until it overflowed (Dino, 7 Nov).
    dmax = 1.0
    for i in range(h.size):
        if not sea[i] and ery[i] ** 0.3 > dmax:
            dmax = ery[i] ** 0.3
    ns = int(np.ceil(D * dmax * dt / (dx * dx) / 0.2))
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
    steps = int(round(E['years'] / E['dt']))
    t0 = time.time()
    deposit = np.zeros(n * n)
    for s in range(steps):
        filled, rec, order = lem.route(h, sea, n)
        quick = runoff.budget(rain_mm, rock.rock_ids(g, h), bfi, W)['quick'] / q_ref    # the rock at today's surface
        Q = _discharge(order, rec, sea, quick, cell, n * n)
        share = _channel_share(Q, h, rec, order, sea, n, dx, c_ch, theta)
        ery = ery_fn(h)
        h0 = h.copy()
        flux = _fluvial(h, h0, sea, order, rec, n, dx, E['dt'], E['K'], E['m'], E['G'], U, ery, Q, share, cell, E['sweeps'], E['tol_m'])
        _diffuse(h, sea, n, dx, E['dt'], E['D'], ery)
        change = h - (h0 + U * E['dt'])
        deposit = np.maximum(deposit + change, 0.0)          # sediment lying on bedrock: grows where it lands, wears where it erodes
        ery_fn.update(change)
        if s % 25 == 0:
            print(f'step {s}/{steps} t {time.time() - t0:.0f} s, max h {h.max():.0f} m', flush=True)
        # Fail loudly, never carry on: uplift alone over the whole run cannot lift any cell more than U * years above its start.
        bound = float(start.max()) + float(U.max()) * E['years'] + 100.0
        if not np.isfinite(h).all() or h.max() > bound:
            raise SystemExit(f'evolve: unstable at step {s}: max height {h.max():.3g} m is above the physical bound {bound:.0f} m')
    filled, rec, order = lem.route(h, sea, n)
    rid = rock.rock_ids(g, h)
    wb = runoff.budget(rain_mm, rid, bfi, W)
    Q = _discharge(order, rec, sea, wb['quick'] / q_ref, cell, n * n)
    share = _channel_share(Q, h, rec, order, sea, n, dx, c_ch, theta)
    area = _discharge(order, rec, sea, np.ones(n * n), cell, n * n)
    hh = h.reshape(n, n)
    np.savez_compressed(f'{out_dir}/ground.npz', ground=hh.astype(np.float32), start=start.astype(np.float32),
                        quick_area_m2=Q.reshape(n, n).astype(np.float32), area_m2=area.reshape(n, n).astype(np.float32),
                        channel=share.reshape(n, n).astype(np.float32), rock=rid.reshape(n, n).astype(np.int16),
                        et_mm=wb['et'].reshape(n, n).astype(np.float32), quick_mm=wb['quick'].reshape(n, n).astype(np.float32),
                        recharge_mm=wb['recharge'].reshape(n, n).astype(np.float32),
                        receiver=rec.reshape(n, n).astype(np.int32), pit_m=(filled - h).reshape(n, n).astype(np.float32),
                        sediment_m=deposit.reshape(n, n).astype(np.float32), sea=sea.reshape(n, n).astype(bool),
                        sediment_flux_m3_yr=flux.reshape(n, n).astype(np.float32),
                        cell_m=dx, origin_x=float(data['origin_x']), origin_z=float(data['origin_z']))
    land = sea.reshape(n, n) == 0
    gy, gx = np.gradient(hh, dx)
    slope = np.degrees(np.arctan(np.hypot(gx, gy)))
    pits = (filled - h).reshape(n, n)
    summary = dict(seconds=time.time() - t0, steps=steps, summit_m=float(hh.max()), landform_summit_m=float(start.max()),
                   land_km2=float(land.sum() * cell / 1e6),
                   median_slope_deg=float(np.median(slope[land])), share_under_10deg_below_250m=float((slope[land & (hh < 250)] < 10).mean()),
                   closed_hollow_cells=int((pits[land] > 0.01).sum()), deepest_hollow_m=float(pits[land].max()),
                   sediment_km2_over_1m=float((deposit.reshape(n, n)[land] > 1.0).sum() * cell / 1e6),
                   reference_quick_mm_yr=q_ref,
                   water_mm_yr={k: float(wb[k].reshape(n, n)[land].mean()) for k in ('et', 'runoff', 'quick', 'recharge')},
                   drainage_density_km_per_km2=float((share.reshape(n, n)[land] > 0.5).sum() * dx / 1e3 / (land.sum() * cell / 1e6)),
                   drainage_density_by_rock={g['names'][int(k)]: float(((share > 0.5) & (rid == k) & (sea == 0)).sum() * dx / 1e3
                                                                     / max(((rid == k) & (sea == 0)).sum() * cell / 1e6, 1e-9))
                                             for k in np.unique(rid[sea == 0])},
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
    ax[1].imshow(np.where(land & (share.reshape(n, n) > 0.5), 1, np.nan), cmap='winter', alpha=0.8)
    im = ax[2].imshow(np.where(land, deposit.reshape(n, n), np.nan), cmap='YlOrBr', vmax=10); ax[2].set_title('sediment (m): floodplains, fans, deltas')
    fig.colorbar(im, ax=ax[2], shrink=0.7)
    for a in ax: a.axis('off')
    plt.tight_layout(); plt.savefig(f'{out_dir}/evolve.png', dpi=70)


if __name__ == '__main__':
    main()
