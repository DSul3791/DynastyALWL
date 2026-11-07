"""Stage C1 and C2 of the watershed rebuild (docs/water/watershed_rebuild_design.md, step R3): routing, basins, and lakes by
water balance, only where a hollow has a cause.

Usage (on Dave's PC, never in the cloud):
  python tools/watershed/lakes.py INPUTS_DIR GEOLOGY_DIR B2_DIR OUT_DIR [params.json]
B2_DIR holds glacial.py's glacial.npz (the final ground and each hollow's cause). Writes OUT_DIR/lakes.npz, lakes.json (the
lake table), lakes.png and lakes_manifest.json.

1. Hollows with no cause (glacial.py labels each one: ice-scoured floor, glacial deposit sill, other sediment sill, or none)
   are numerical leftovers, not lakes (design C2): their ground is raised to the spill surface, with the priority flood's
   small slope toward the outlet so they drain. They are listed, with the deepest, so a missing cause shows up.
2. The depression tree (Barnes, Callaghan and Wickert 2020, Earth Surface Dynamics, part 2): cells are visited from the lowest
   up; each local minimum starts a depression, two depressions that meet at a saddle become children of a new one, and a
   depression that meets the sea (or the model frame) spills there. Each depression knows its spill height and the cells it
   holds below it.
3. Fill, spill and merge (Barnes et al. 2021, part 3): each depression gets the runoff of its catchment (the cells whose
   steepest descent ends in it; rain less evaporation, from the one water budget, with the groundwater recharge of cave-forming
   rock taken away because it leaves through the caves, to come back at a cave spring in R4 and R5). It loses open-water
   evaporation and seepage through its floor over the area it covers. If the inflow wins at the spill height it is full, and
   the rest spills: into its sibling across the saddle, or, at the top, down the land to the next lake or the sea. If both
   children of a saddle are full, the water above the saddle fills the merged depression. A depression that cannot fill
   stands at the level where loss equals inflow: a closed (terminal) lake, which needs that reason (document section 6).
4. Every lake gets its cause: cirque (an ice-scoured floor near or above the snowline), glacial rock basin (an ice-scoured floor
   lower down), moraine or till dam, fan or delta dam. The table keeps level, area, volume, depth, inflow, losses, outflow,
   the spill point and where the outflow goes.
5. Basins: every cell's outlet to the sea, routed through the lakes (C1).
"""
import sys, os, json, time
import numpy as np
import numba as nb

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'erosion_precarve'))
import lem      # noqa: E402
import rock     # noqa: E402
import runoff   # noqa: E402
import evolve   # noqa: E402

CAUSES_B2 = ('ice-scoured floor', 'glacial deposit sill', 'other sediment sill', 'none')


@nb.njit(cache=True)
def _find(uf, a):
    r = a
    while uf[r] != r:
        r = uf[r]
    while uf[a] != r:                                   # path compression
        b = uf[a]
        uf[a] = r
        a = b
    return r


@nb.njit(cache=True)
def _merge_tree(h, order, ocean, n):
    """The depression tree. order: every cell from the lowest up. ocean: sea and model frame (where water leaves).
    Returns, per cell, the depression it joined (0 = the ocean), and per depression: parent (0 = spills to the ocean),
    spill height, outlet cell (the lowest ocean-side neighbour of the spill cell, or the saddle cell between siblings),
    the number of its own cells below the spill, and its first (lowest) cell. Depression 0 is the ocean."""
    N = n * n
    M = N // 2 + 16                                    # local minima are never neighbours, so fewer than N/2 depressions
    cnode = np.full(N, -1, np.int64)
    uf = np.arange(M)
    top = np.arange(M)
    parent = np.full(M, -1, np.int64)
    spill = np.full(M, np.inf)
    outlet = np.full(M, -1, np.int64)
    own_full = np.zeros(M, np.int64)
    own_now = np.zeros(M, np.int64)
    minc = np.full(M, -1, np.int64)
    tops = np.empty(8, np.int64)
    for i in range(N):
        if ocean[i]:
            cnode[i] = 0
    k = 1
    for q in range(order.size):
        c = order[q]
        if ocean[c]:
            continue
        r = c // n
        cc = c % n
        nt = 0
        for dr in range(-1, 2):
            for dc in range(-1, 2):
                if dr == 0 and dc == 0:
                    continue
                rr = r + dr
                c2 = cc + dc
                if rr < 0 or rr >= n or c2 < 0 or c2 >= n:
                    continue
                j = rr * n + c2
                if cnode[j] < 0:
                    continue
                t = top[_find(uf, cnode[j])]
                dup = False
                for z in range(nt):
                    if tops[z] == t:
                        dup = True
                if not dup:
                    tops[nt] = t
                    nt += 1
        if nt == 0:                                     # a local minimum: a new depression
            if k >= M:
                raise ValueError('lakes: too many depressions')
            cnode[c] = k
            minc[k] = c
            own_now[k] = 1
            k += 1
            continue
        if nt == 1:
            t = tops[0]
            cnode[c] = t
            if t != 0:
                own_now[t] += 1
            continue
        has_ocean = False
        for z in range(nt):
            if tops[z] == 0:
                has_ocean = True
        if has_ocean:                                   # the others spill to the ocean side here
            best = -1
            bh = np.inf
            for dr in range(-1, 2):
                for dc in range(-1, 2):
                    rr = r + dr
                    c2 = cc + dc
                    if (dr == 0 and dc == 0) or rr < 0 or rr >= n or c2 < 0 or c2 >= n:
                        continue
                    j = rr * n + c2
                    if cnode[j] >= 0 and top[_find(uf, cnode[j])] == 0 and h[j] < bh:
                        bh = h[j]
                        best = j
            for z in range(nt):
                t = tops[z]
                if t == 0:
                    continue
                spill[t] = h[c]
                parent[t] = 0
                outlet[t] = best
                own_full[t] = own_now[t]
                uf[_find(uf, t)] = _find(uf, 0)
            top[_find(uf, 0)] = 0
            cnode[c] = 0
        else:                                           # a saddle between depressions: they become children of a new one
            if k >= M:
                raise ValueError('lakes: too many depressions')
            P = k
            k += 1
            for z in range(nt):
                t = tops[z]
                spill[t] = h[c]
                parent[t] = P
                outlet[t] = c
                own_full[t] = own_now[t]
                uf[_find(uf, t)] = P
            top[P] = P
            cnode[c] = P
            own_now[P] = 1
            minc[P] = c
    return cnode, parent[:k], spill[:k], outlet[:k], own_full[:k], minc[:k]


@nb.njit(cache=True)
def _steepest(h, ocean, n):
    """Steepest-descent receiver on the ground itself (not filled): -1 at a local minimum or where water leaves."""
    N = n * n
    rec = np.full(N, -1, np.int64)
    for i in range(N):
        if ocean[i]:
            continue
        r = i // n
        c = i % n
        best = -1
        bd = 0.0
        for dr in range(-1, 2):
            for dc in range(-1, 2):
                if dr == 0 and dc == 0:
                    continue
                rr = r + dr
                c2 = c + dc
                if rr < 0 or rr >= n or c2 < 0 or c2 >= n:
                    continue
                j = rr * n + c2
                d = h[i] - h[j]
                if dr != 0 and dc != 0:
                    d /= 1.4142135623730951
                if d > bd:
                    bd = d
                    best = j
        rec[i] = best
    return rec


@nb.njit(cache=True)
def _catchments(order_desc, rec8, src, ocean, cnode, K):
    """Runoff (m3/yr) reaching each depression by steepest descent: summed down from the highest cell; where the descent
    ends at a local minimum the water enters that cell's depression. Water reaching the ocean is dropped."""
    acc = src.copy()
    inflow = np.zeros(K)
    for q in range(order_desc.size):
        i = order_desc[q]
        if ocean[i]:
            continue
        d = rec8[i]
        if d >= 0:
            if not ocean[d]:
                acc[d] += acc[i]
        elif cnode[i] > 0:
            inflow[cnode[i]] += acc[i]
    return inflow


def _land_at(start, rec8, ocean, cnode):
    """Follow the steepest descent from a cell to where it ends; returns the depression there (0 = the ocean)."""
    i = int(start)
    for _ in range(rec8.size):
        if i < 0 or ocean[i]:
            return 0
        d = int(rec8[i])
        if d < 0:
            return int(cnode[i])
        i = d
    return 0


def fill_spill_merge(h, cnode, parent, spill, outlet, own_full, minc, order, inflow, rate, cell, rec8, ocean):
    """Settle every depression: full (water spills on) or standing at its balance level. rate: loss per cell (m/yr) of a lake
    over it (open-water evaporation plus floor seepage). Returns per depression: level (nan dry), full, and outflow (m3/yr)."""
    K = parent.size
    sys.setrecursionlimit(max(10000, 4 * K))           # give and spill_kids nest only across siblings
    # own cells of each depression, lowest first (the order they joined)
    land = cnode > 0
    seq = order[land[order]]
    nd = cnode[seq]
    srt = np.argsort(nd, kind='stable')
    own = seq[srt]
    ptr = np.zeros(K + 1, np.int64)
    np.add.at(ptr, nd + 1, 1)
    ptr = np.cumsum(ptr)
    loss_full = np.zeros(K)
    for d in range(1, K):
        a = ptr[d]
        loss_full[d] = float(rate[own[a:a + own_full[d]]].sum()) * cell
    kids = [[] for _ in range(K)]
    for d in range(1, K):
        if parent[d] > 0:
            kids[parent[d]].append(d)
    I = inflow.astype(np.float64).copy()
    level = np.full(K, np.nan)
    full = np.zeros(K, bool)
    out = np.zeros(K)
    passed = np.zeros(K, bool)

    def settle(d):
        if I[d] <= 0.0:
            level[d] = np.nan; full[d] = False; out[d] = 0.0
        elif I[d] >= loss_full[d]:
            level[d] = spill[d]; full[d] = True; out[d] = I[d] - loss_full[d]
        else:
            a = ptr[d]
            cum = np.cumsum(rate[own[a:a + own_full[d]]]) * cell
            j = int(np.searchsorted(cum, I[d]))
            j = min(j, own_full[d] - 1)
            level[d] = float(h[own[a + j]]); full[d] = False; out[d] = 0.0

    def ready(d):                                     # can this depression's own cells take water?
        return len(kids[d]) == 0 or all(full[c] for c in kids[d])

    def spill_kids(d):
        """Children of d that are full spill into a sibling that is not; once all are full, what is left fills d."""
        changed = True
        while changed:
            changed = False
            for c in kids[d]:
                if full[c] and not passed[c] and out[c] > 0.0:
                    others = [x for x in kids[d] if x != c and not full[x]]
                    if others:
                        passed[c] = True
                        give(min(others, key=lambda x: h[minc[x]]), out[c])   # into the sibling with the lowest floor
                        changed = True
        if kids[d] and all(full[c] for c in kids[d]):
            I[d] += sum(out[c] for c in kids[d] if not passed[c])
            for c in kids[d]:
                passed[c] = True
        settle(d)

    def give(d, x):
        """Water arriving in depression d from a sibling across the saddle: it lands in the lowest part that can take it."""
        path = [d]
        while not ready(path[-1]):
            path.append(min((c for c in kids[path[-1]] if not full[c]), key=lambda c: h[minc[c]]))
        I[path[-1]] += x
        settle(path[-1])
        for e in reversed(path[:-1]):
            spill_kids(e)

    roots = [d for d in range(1, K) if parent[d] == 0]
    roots.sort(key=lambda d: -spill[d])               # higher spills first: their overflow runs down to lower ones
    dest = np.zeros(K, np.int64)
    done = np.zeros(K, bool)
    lost = 0.0
    for r in roots:
        post, stack = [], [r]                            # children before parents, without deep recursion
        while stack:
            d = stack.pop()
            post.append(d)
            stack.extend(kids[d])
        for d in reversed(post):
            spill_kids(d)
            done[d] = True
        if full[r] and out[r] > 0.0:
            t = _land_at(outlet[r], rec8, ocean, cnode)
            dest[r] = t
            if t > 0:
                if done[t]:
                    lost += out[r]                       # only on equal spill heights; reported in the summary
                else:
                    I[t] += out[r]                       # a lower lake's tree, settled later
    return level, full, out, dest, kids, lost


def main():
    inputs_dir, geology_dir, b2_dir, out_dir = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
    P = json.load(open(sys.argv[5] if len(sys.argv) > 5 else os.path.join(HERE, 'params.json')))
    E, W, L, GL = P['evolve'], P['water_budget'], P['lakes'], P['glacial']
    os.makedirs(out_dir, exist_ok=True)
    t0 = time.time()
    data = np.load(f'{inputs_dir}/inputs.npz')
    b2 = np.load(f'{b2_dir}/glacial.npz')
    n = b2['ground'].shape[0]
    N = n * n
    dx = float(b2['cell_m'])
    cell = dx * dx
    sea = b2['sea'].ravel().astype(np.uint8)
    frame = np.zeros((n, n), bool); frame[0, :] = frame[-1, :] = frame[:, 0] = frame[:, -1] = True
    ocean = ((sea == 1) | frame.ravel()).astype(np.uint8)
    land = sea == 0
    h = b2['ground'].astype(np.float64).ravel().copy()
    cause_b2 = b2['hollow_cause'].astype(np.int64).ravel()
    rain_mm = data['rain'].astype(np.float64).ravel()
    cave = data['cave_forming'].astype(bool).ravel() if 'cave_forming' in data.files else np.zeros(N, bool)
    g = rock.load(geology_dir, E['cover_m'], E['cover_erodibility'])
    bfi = runoff.bfi_by_rock_id(g['names'], W['bfi_by_rock'])

    # 1. leftovers: hollows with no cause are filled to the spill surface (with the flood's slope to the outlet).
    filled, rec, order_f = lem.route(h, sea, n)
    pit = filled - h
    leftover = land & (pit > 0.0) & ~((cause_b2 >= 0) & (cause_b2 <= 2))
    lab0, deep0, size0, _ = evolve._hollows(np.where(leftover, pit, 0.0), rec, sea, n, 0.1)
    ox, oz = float(b2['origin_x']), float(b2['origin_z'])
    leftovers = dict(cells=int(leftover.sum()), deeper_than_0_1m=int(deep0.size),
                     deepest_ten=[dict(x=ox + float(deep0[q] % n) * dx, z=oz + float(deep0[q] // n) * dx, depth_m=float(pit[deep0[q]]),
                                       km2=float(size0[q] * cell / 1e6)) for q in np.argsort(-pit[deep0])[:10]])
    h = np.where(leftover, filled, h)

    # 2. the depression tree on the ground with only caused hollows left
    order = np.argsort(h, kind='stable')
    cnode, parent, spill, outlet, own_full, minc = _merge_tree(h, order, ocean, n)
    K = parent.size

    # 3. water: runoff from the one water budget; cave-forming rock loses its recharge underground
    rid = rock.rock_ids(g, h)
    wb = runoff.budget(rain_mm, rid, bfi, W)
    src = (wb['quick'] + np.where(cave, 0.0, wb['recharge'])) / 1000.0 * cell          # m3/yr per cell
    rec8 = _steepest(h, ocean, n)
    inflow = _catchments(order[::-1].copy(), rec8, src, ocean, cnode, K)
    soluble_ids = [k for k, v in g['names'].items() if v in P['rock']['soluble']]
    seep = np.where(cave, L['seepage_mm_yr_cave_forming'],
                    np.where(np.isin(rid, soluble_ids), L['seepage_mm_yr_other_soluble'], L['seepage_mm_yr_other']))
    rate = (L['open_water_factor'] * W['pet_mm_yr'] + seep) / 1000.0                     # m/yr of lake loss over each cell
    level, full, out, dest, kids, lost = fill_spill_merge(h, cnode, parent, spill, outlet, own_full, minc, order, inflow, rate, cell,
                                                    rec8, ocean)

    # water level per depression as seen from its cells: a wet parent covers its children
    eff = level.copy()
    lake_of = np.full(K, -1, np.int64)
    pre = [d for d in range(1, K) if parent[d] == 0]
    while pre:
        d = pre.pop()
        p = parent[d]
        if p > 0 and np.isfinite(eff[p]):
            eff[d] = eff[p]
            lake_of[d] = lake_of[p]
        elif np.isfinite(level[d]):
            lake_of[d] = d
        pre.extend(kids[d])
    cn = np.maximum(cnode, 0)
    wl = np.where(cnode > 0, eff[cn], np.nan)
    wet = land & np.isfinite(wl) & (wl > h)
    lake = np.where(wet, lake_of[cn], -1)

    # 4. the lake table
    ela = float(GL['ela_m'])
    lakes = []
    ids = np.unique(lake[lake >= 0])
    for d in ids:
        cells = np.flatnonzero(lake == d)
        lv = float(eff[d])
        depth = lv - h[cells]
        lo = cells[np.argmin(h[cells])]
        cb = int(cause_b2[lo])
        floor = float(h[lo])
        if cb == 0:
            cause = 'cirque' if floor >= ela - float(L['cirque_floor_below_ela_m']) else 'glacial rock basin'
        elif cb == 1:
            cause = 'moraine or till dam'
        elif cb == 2:
            cause = 'fan or delta dam'
        else:
            cause = 'unexplained'                      # should not happen once leftovers are filled: listed to be looked at
        loss = float(rate[cells].sum() * cell)
        o = int(outlet[d]) if full[d] else -1
        tgt = int(dest[d]) if (full[d] and parent[d] == 0) else -1
        lakes.append(dict(id=int(d), cause=cause, level_m=lv, area_km2=float(cells.size * cell / 1e6),
                          volume_m3=float(depth.sum() * cell), max_depth_m=float(depth.max()),
                          deepest_x=ox + float(lo % n) * dx, deepest_z=oz + float(lo // n) * dx,
                          full=bool(full[d]), outflow_m3_s=float(out[d]) / 3.15576e7, losses_m3_s=loss / 3.15576e7,
                          inflow_m3_s=(float(out[d]) + loss) / 3.15576e7,
                          spill_x=ox + float(o % n) * dx if o >= 0 else None, spill_z=oz + float(o // n) * dx if o >= 0 else None,
                          spills_to=('sea' if tgt == 0 else (f'lake {int(lake_of[tgt])}' if tgt > 0 and lake_of[tgt] >= 0 else
                                     ('a dry hollow' if tgt > 0 else ('its neighbour across the saddle' if full[d] else None)))),
                          closed_reason=None if full[d] else 'evaporation and floor seepage equal the inflow below the spill'))

    # 5. basins: each cell's outlet to the sea, routed through the lakes
    filled2, rec2, order2 = lem.route(h, sea, n)
    basin = _basins(order2, rec2, sea, N)
    bid, barea = np.unique(basin[land & (basin >= 0)], return_counts=True)
    rank = np.argsort(-barea)
    relabel = np.full(N, -1, np.int64)
    relabel[bid[rank]] = np.arange(bid.size)
    basin_id = np.where(basin >= 0, relabel[np.maximum(basin, 0)], -1)
    Q = evolve._discharge(order2, rec2, sea, wb['quick'] / runoff.reference_quick_mm(P['rain']['background_mm_yr'], W), cell, N)

    R = lambda a, t=np.float32: a.reshape(n, n).astype(t)
    np.savez_compressed(f'{out_dir}/lakes.npz', ground=R(h), water_level=R(np.where(wet, wl, np.nan)), lake_id=R(lake, np.int32),
                        basin_id=R(basin_id, np.int32), leftover_filled_m=R(np.where(leftover, pit, 0.0)),
                        quick_area_m2=R(Q), receiver=R(rec2, np.int32), sea=R(sea, bool), cell_m=dx, origin_x=ox, origin_z=oz)
    json.dump(lakes, open(f'{out_dir}/lakes.json', 'w'), indent=1)
    by_cause = {}
    for lk in lakes:
        c = by_cause.setdefault(lk['cause'], dict(count=0, km2=0.0, largest_km2=0.0))
        c['count'] += 1; c['km2'] += lk['area_km2']; c['largest_km2'] = max(c['largest_km2'], lk['area_km2'])
    summary = dict(seconds=time.time() - t0, depressions=int(K - 1), lakes=len(lakes), lake_km2=float(wet.sum() * cell / 1e6),
                   by_cause=by_cause, closed_lakes=[lk for lk in lakes if not lk['full']][:20],
                   largest_ten=sorted(lakes, key=lambda lk: -lk['area_km2'])[:10], leftovers_filled=leftovers,
                   basins_over_1km2=int((barea * cell / 1e6 > 1.0).sum()), largest_basins_km2=[float(a * cell / 1e6) for a in barea[rank][:10]],
                   unexplained_lakes=sum(1 for lk in lakes if lk['cause'] == 'unexplained'),
                   overflow_lost_m3_s=float(lost) / 3.15576e7)
    json.dump(dict(params=P, inputs={'inputs.npz': evolve.sha(f'{inputs_dir}/inputs.npz'), 'glacial.npz': evolve.sha(f'{b2_dir}/glacial.npz')},
                   summary=summary), open(f'{out_dir}/lakes_manifest.json', 'w'), indent=1)
    print(json.dumps(summary, indent=1))
    import plots
    plots.lakes_picture(f'{out_dir}/lakes.npz', f'{out_dir}/lakes.json', f'{out_dir}/lakes.png')


@nb.njit(cache=True)
def _basins(order, rec, sea, N):
    """Each cell's outlet to the sea (the cell id of the last land cell before the sea), from the downstream-first order."""
    basin = np.full(N, -1, np.int64)
    for q in range(order.size):
        i = order[q]
        d = rec[i]
        if d < 0 or sea[d]:
            basin[i] = i
        else:
            basin[i] = basin[d]
    return basin


if __name__ == '__main__':
    main()
