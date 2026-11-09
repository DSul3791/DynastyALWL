"""Glacial cuts A3 and R (docs/design/glacial_speed_design.md): evolve._solve on nine threads by river basin, its bookkeeping on
land cells only, and _slope_ceiling over a land index must give exactly what the one-thread code gave; so must D8-LTD with its
facets on threads (_ltd_receivers) and the flood without the D8 receivers (lem.fill_order, lem.route, evolve.route). The old code is copied
below verbatim (bar its docstrings) and both run on small routed islands: cover and bare rock, ice lift, sea receivers,
hollows, every sweep and an early stop, at one thread and at nine (or as many as there are), and once with an order where a
receiver comes after its donor, which must fall back to one bucket. Every array must be equal (np.array_equal), not close.
They need numpy and numba (evolve.py's own imports) and take a few seconds, most of it numba compiling.

Run on David4 or Dave's PC, never in the cloud:
  python tools/watershed/test_evolve.py        (or: python -m pytest tools/watershed/test_evolve.py)
"""
import os, sys
import numpy as np
import numba as nb

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import evolve as ev    # noqa: E402

DX = 16.0


@nb.njit
def _old_slope_ceiling(h0, lift, Sc, sea, n, dx):
    """The code of evolve._slope_ceiling before glacial cut A3 (main 2e01a944), verbatim but for its docstring."""
    N = n * n
    val = h0 - lift
    for i in range(N):
        if sea[i] and val[i] < 0.0:
            val[i] = 0.0
    src = np.arange(N)
    root2 = 1.4142135623730951
    for p in range(64):
        changed = False
        for sweep in range(2):
            for q in range(N):
                i = q if sweep == 0 else N - 1 - q
                if sea[i] or Sc[i] <= 0.0:
                    continue
                r = i // n
                c = i % n
                best = val[i]
                bs = src[i]
                for dr in range(-1, 2):
                    rr = r + dr
                    if rr < 0 or rr >= n:
                        continue
                    for dc in range(-1, 2):
                        cc = c + dc
                        if (dr == 0 and dc == 0) or cc < 0 or cc >= n:
                            continue
                        j = rr * n + cc
                        v = val[j] + Sc[i] * dx * (root2 if dr != 0 and dc != 0 else 1.0)
                        if v < best:                     # from the neighbour itself
                            best = v
                            bs = j
                        s = src[j]
                        if s != j and (sea[s] or Sc[s] == Sc[i]):
                            a = float(s // n - r)
                            b = float(s % n - c)
                            v = val[s] + Sc[i] * dx * np.sqrt(a * a + b * b)
                            if v < best:                 # straight from the neighbour's source
                                best = v
                                bs = s
                if best < val[i] - 1e-6:
                    val[i] = best
                    src[i] = bs
                    changed = True
        if not changed:
            break
    return val + lift


@nb.njit
def _old_solve(h, h0, sea, order, rec, n, dx, dt, kq, kc, kq_c, cover, G, U, Qd, cell, sweeps, tol, Sc, lift):
    """The code of evolve._solve before glacial cut A3 (main 2e01a944), verbatim but for its docstring."""
    N = n * n
    ceiling = _old_slope_ceiling(h0 + U * dt, lift, Sc, sea, n, dx)
    up = np.zeros(N)
    total = np.zeros(N)          # sum over strictly upstream cells of (U - dh/dt) * cell, from the previous sweep
    for s in range(sweeps):
        biggest = 0.0
        for q in range(order.size):                     # downstream first: a receiver is always solved before its donors
            i = order[q]; d = rec[i]
            if sea[i]:
                continue
            Qi = Qd[i]
            c = G * cell / Qi                            # the node's own share of the sediment term (its own eroded volume)
            dist = dx
            if d >= 0 and abs(d - i) != 1 and abs(d - i) != n:
                dist = dx * 1.4142135623730951
            F = 0.0
            if d >= 0:
                F = kq[i] / dist
            hr = h[d] if d >= 0 else h0[i]
            A = (1.0 + c) / dt
            rest = U[i] * (1.0 + c) + G / Qi * up[i]
            B = h0[i] * (1.0 + c) / dt + rest
            if cover[i] > 0.0:
                Fc = kq_c[i] / dist if d >= 0 else 0.0
                x = ev._cell_height(B, A, Fc, hr, 0.0)      # loose cover: its own rate, no threshold
                if h0[i] - x > cover[i]:                 # cut through it: the cover's volume is gone, the rest at the rock's rate
                    x = ev._cell_height(B - cover[i] / dt, A, F, hr, kc[i])
            else:
                x = ev._cell_height(B, A, F, hr, kc[i])
            if d >= 0 and h0[i] < hr and x > hr:         # a hollow fills to its sill, no higher
                x = hr
            if Sc[i] > 0.0 and d >= 0:
                base = hr - lift[d]                      # the receiver's ground
                if sea[d] and base < 0.0:
                    base = 0.0
                if x - lift[i] > base + Sc[i] * dist:
                    x = base + Sc[i] * dist + lift[i]
            if x > ceiling[i]:                           # and against every neighbour (_slope_ceiling)
                x = ceiling[i]
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


# Cut R (9 Nov 2026): the one-thread D8-LTD kernel and lem.route as they were on main ba517797, verbatim bar the docstrings.
@nb.njit
def _old_ltd_receivers(filled, order, sea, n, dx, lam, facets):
    N = n * n
    rec = np.full(N, -1, np.int64)
    acc = np.ones(N)
    main = np.zeros(N)
    drift_in = np.zeros(N)
    root2 = 1.4142135623730951
    for q in range(order.size - 1, -1, -1):
        i = order[q]
        r = i // n
        c = i % n
        e0 = filled[i]
        smax = 0.0
        fx = 0.0
        fy = 0.0
        k1 = -1
        k2 = -1
        for f in range(8):
            c1 = c + facets[f, 0]; r1 = r + facets[f, 1]; c2 = c + facets[f, 2]; r2 = r + facets[f, 3]
            if c1 < 0 or c1 >= n or r1 < 0 or r1 >= n or c2 < 0 or c2 >= n or r2 < 0 or r2 >= n:
                continue
            e1 = filled[r1 * n + c1]
            e2 = filled[r2 * n + c2]
            s1 = (e0 - e1) / dx
            s2 = (e1 - e2) / dx
            a = np.arctan2(s2, s1)
            if a < 0.0:
                a = 0.0
                s = s1
            elif a > 0.25 * np.pi:
                a = 0.25 * np.pi
                s = (e0 - e2) / (dx * root2)
            else:
                s = np.sqrt(s1 * s1 + s2 * s2)
            if s > smax:
                smax = s
                ux = float(facets[f, 0]); uy = float(facets[f, 1])
                wx = float(facets[f, 2] - facets[f, 0]); wy = float(facets[f, 3] - facets[f, 1])
                fx = np.cos(a) * ux + np.sin(a) * wx
                fy = np.cos(a) * uy + np.sin(a) * wy
                k1 = r1 * n + c1
                k2 = r2 * n + c2
        best = -1
        drift = 0.0
        for t in range(2):
            k = k1 if t == 0 else k2
            if k < 0 or filled[k] >= e0:
                continue
            ox = float(k % n - c) * dx
            oy = float(k // n - r) * dx
            d = lam * drift_in[i] + (fx * oy - fy * ox)          # sideways drift of the path if it steps to k
            if best < 0 or abs(d) < abs(drift):
                best = k
                drift = d
        if best < 0:
            bd = 0.0
            for dr in range(-1, 2):
                for dc in range(-1, 2):
                    rr = r + dr; cc = c + dc
                    if (dr == 0 and dc == 0) or rr < 0 or rr >= n or cc < 0 or cc >= n:
                        continue
                    j = rr * n + cc
                    g = (e0 - filled[j]) / (root2 if dr != 0 and dc != 0 else 1.0)
                    if g > bd:
                        bd = g
                        best = j
            drift = 0.0
        rec[i] = best
        if best >= 0:
            acc[best] += acc[i]
            if acc[i] > main[best]:
                main[best] = acc[i]
                drift_in[best] = drift
    return rec


@nb.njit
def _old_lem_route(h, sea, n):
    N = n*n
    EPS = 1e-3
    filled = np.empty(N); seen = np.zeros(N, np.uint8)
    # simple binary heap on (value, idx)
    hv = np.empty(N+8); hi = np.empty(N+8, np.int64); sz = 0
    for i in range(N):
        if sea[i]:
            filled[i] = min(h[i], 0.0); seen[i] = 1
    for i in range(N):
        if sea[i]: continue
        r = i//n; c = i % n
        seed = r == 0 or c == 0 or r == n-1 or c == n-1
        if not seed:
            for dr in range(-1, 2):
                for dc in range(-1, 2):
                    if sea[(r+dr)*n+c+dc]: seed = True
        if seed:
            seen[i] = 1; filled[i] = max(h[i], EPS)
            # push
            k = sz; sz += 1; hv[k] = filled[i]; hi[k] = i
            while k > 0:
                p = (k-1)//2
                if hv[p] > hv[k] or (hv[p] == hv[k] and hi[p] > hi[k]):
                    t = hv[p]; hv[p] = hv[k]; hv[k] = t
                    t2 = hi[p]; hi[p] = hi[k]; hi[k] = t2; k = p
                else: break
    order = np.empty(N, np.int64); no = 0
    while sz > 0:
        v = hv[0]; i = hi[0]; sz -= 1
        hv[0] = hv[sz]; hi[0] = hi[sz]
        k = 0
        while True:
            l = 2*k+1; rr = l+1; m = k
            if l < sz and (hv[l] < hv[m] or (hv[l] == hv[m] and hi[l] < hi[m])): m = l
            if rr < sz and (hv[rr] < hv[m] or (hv[rr] == hv[m] and hi[rr] < hi[m])): m = rr
            if m == k: break
            t = hv[m]; hv[m] = hv[k]; hv[k] = t
            t2 = hi[m]; hi[m] = hi[k]; hi[k] = t2; k = m
        if not sea[i]:
            order[no] = i; no += 1
        r = i//n; c = i % n
        for dr in range(-1, 2):
            for dc in range(-1, 2):
                if dr == 0 and dc == 0: continue
                rr2 = r+dr; cc = c+dc
                if rr2 < 0 or rr2 >= n or cc < 0 or cc >= n: continue
                j = rr2*n+cc
                if seen[j]: continue
                seen[j] = 1
                filled[j] = max(h[j], v+EPS)
                k = sz; sz += 1; hv[k] = filled[j]; hi[k] = j
                while k > 0:
                    p = (k-1)//2
                    if hv[p] > hv[k] or (hv[p] == hv[k] and hi[p] > hi[k]):
                        t = hv[p]; hv[p] = hv[k]; hv[k] = t
                        t2 = hi[p]; hi[p] = hi[k]; hi[k] = t2; k = p
                    else: break
    # pop order is ascending filled value = downstream first
    rec = np.full(N, -1, np.int64)
    for q in range(no):
        i = order[q]; r = i//n; c = i % n
        best = -1; bd = 0.0
        for dr in range(-1, 2):
            for dc in range(-1, 2):
                if dr == 0 and dc == 0: continue
                rr2 = r+dr; cc = c+dc
                if rr2 < 0 or rr2 >= n or cc < 0 or cc >= n: continue
                j = rr2*n+cc
                d = filled[i]-filled[j]
                if dr != 0 and dc != 0: d /= 1.4142
                if d > bd: bd = d; best = j
        rec[i] = best
    return filled, rec, order[:no]


def _island(n, seed, bumps=9):
    """A rough island on an n x n grid: a few hills on a dome, the sea where it falls below 0 and round the frame."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:n, 0:n] / (n - 1.0)
    h = 60.0 * (1.0 - ((x - 0.5) ** 2 + (y - 0.5) ** 2) * 6.0)
    for _ in range(bumps):
        cx, cy, r, a = rng.uniform(0.2, 0.8), rng.uniform(0.2, 0.8), rng.uniform(0.04, 0.15), rng.uniform(-25.0, 40.0)
        h += a * np.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (r * r))
    h += rng.normal(0.0, 1.5, h.shape)
    h = h.ravel()
    sea = (h <= 0.0).astype(np.uint8)
    frame = np.zeros((n, n), bool)
    frame[0, :] = frame[-1, :] = frame[:, 0] = frame[:, -1] = True
    sea[frame.ravel()] = 1
    return h, sea, rng


def _case(n, seed, ice):
    """Everything _solve takes, from a routed island. ice: a lift (ice thickness) on part of the land."""
    h, sea, rng = _island(n, seed)
    N = n * n
    _, rec, order = ev.route(h, sea, n, DX, 0.8)
    land = sea == 0
    kq = rng.uniform(1e-4, 5e-3, N)
    kc = np.where(rng.random(N) < 0.5, 0.0, rng.uniform(0.0, 2e-3, N))
    kq_c = kq * rng.uniform(2.0, 50.0, N)
    cover = np.where(rng.random(N) < 0.5, 0.0, rng.uniform(0.01, 2.0, N))
    U = np.where(land, rng.uniform(0.0, 2e-3, N), 0.0)
    Qd = rng.uniform(DX * DX, 1e5, N)
    Sc = np.where(rng.random(N) < 0.2, 0.0, rng.uniform(0.3, 1.2, N))
    lift = np.where(land & (rng.random(N) < 0.4), rng.uniform(0.0, 80.0, N), 0.0) if ice else np.zeros(N)
    x0 = h + lift
    return dict(h0=x0, sea=sea, order=order, rec=rec, n=n, kq=kq, kc=kc, kq_c=kq_c, cover=cover, U=U, Qd=Qd, Sc=Sc, lift=lift)


def _run(fn, c, dt, sweeps, tol):
    h = c['h0'].copy()
    total = fn(h, c['h0'], c['sea'], c['order'], c['rec'], c['n'], DX, dt, c['kq'], c['kc'], c['kq_c'], c['cover'], 0.9, c['U'],
               c['Qd'], DX * DX, sweeps, tol, c['Sc'], c['lift'])
    return h, total


def _threads():
    return [1, min(9, nb.config.NUMBA_NUM_THREADS)]


def test_slope_ceiling_matches_the_old_loop():
    for seed in range(4):
        c = _case(40, seed, ice=seed % 2 == 1)
        a = ev._slope_ceiling(c['h0'], c['lift'], c['Sc'], c['sea'], c['n'], DX)
        b = _old_slope_ceiling(c['h0'], c['lift'], c['Sc'], c['sea'], c['n'], DX)
        assert np.array_equal(a, b), seed


def test_basin_buckets_keep_each_tree_whole_and_in_order():
    c = _case(48, 11, ice=False)
    ptr, cells, largest, count = ev._basin_buckets(c['order'], c['rec'], c['sea'], 9)
    assert ptr.size == 10 and ptr[-1] == c['order'].size and count > 9 and 0 < largest <= c['order'].size
    assert np.array_equal(np.sort(cells), np.sort(c['order']))
    pos = np.full(c['rec'].size, -1)
    pos[c['order']] = np.arange(c['order'].size)
    bucket = np.full(c['rec'].size, -1)
    for b in range(9):
        part = cells[ptr[b]:ptr[b + 1]]
        assert np.all(np.diff(pos[part]) > 0), b              # the order of order, within each bucket
        bucket[part] = b
    for i in c['order']:
        d = c['rec'][i]
        if d >= 0 and not c['sea'][d]:
            assert bucket[d] == bucket[i]                      # a receiver on land is in its donor's bucket


def test_solve_matches_the_old_solve_at_every_thread_count():
    for seed in range(6):
        c = _case(48, 100 + seed, ice=seed % 2 == 1)
        for sweeps, tol in ((4, 0.0), (4, 0.05), (1, 0.0)):
            h_old, t_old = _run(_old_solve, c, 2000.0, sweeps, tol)
            for k in _threads():
                nb.set_num_threads(k)
                h_new, t_new = _run(ev._solve, c, 2000.0, sweeps, tol)
                assert np.array_equal(h_new, h_old), (seed, sweeps, tol, k)
                assert np.array_equal(t_new, t_old), (seed, sweeps, tol, k)
    nb.set_num_threads(nb.config.NUMBA_NUM_THREADS)


def test_a_receiver_after_its_donor_falls_back_to_one_bucket():
    c = _case(40, 7, ice=False)
    order = c['order'].copy()
    pos = np.full(c['rec'].size, -1)
    pos[order] = np.arange(order.size)
    for q in range(order.size):                                 # swap the first donor with a land receiver: it now comes first
        d = c['rec'][order[q]]
        if d >= 0 and not c['sea'][d]:
            order[q], order[pos[d]] = order[pos[d]], order[q]
            break
    c['order'] = order
    ptr, cells, _, count = ev._basin_buckets(order, c['rec'], c['sea'], 9)
    assert count == 0 and list(ptr) == [0, order.size] and np.array_equal(cells, order)   # one bucket: order as it is
    h_old, t_old = _run(_old_solve, c, 2000.0, 4, 0.0)
    h_new, t_new = _run(ev._solve, c, 2000.0, 4, 0.0)
    assert np.array_equal(h_new, h_old) and np.array_equal(t_new, t_old)


def test_solve_buckets_reports_shares():
    c = _case(48, 11, ice=False)
    bucket, basin, basins = ev.solve_buckets(c['order'], c['rec'], c['sea'], 9)
    assert 0.0 < basin <= bucket <= 1.0 and basins > 9


def test_ltd_receivers_match_the_old_kernel_at_every_thread_count():
    for seed in range(6):
        h, sea, _ = _island(48, 200 + seed)
        filled, _, order = _old_lem_route(h, sea, 48)
        for lam in (0.0, 0.8, 1.0):
            old = _old_ltd_receivers(filled, order, sea, 48, DX, lam, ev._FACETS)
            for k in _threads():
                nb.set_num_threads(k)
                new = ev._ltd_receivers(filled, order, sea, 48, DX, lam, ev._FACETS)
                assert np.array_equal(new, old), (seed, lam, k)
    nb.set_num_threads(nb.config.NUMBA_NUM_THREADS)


def test_fill_order_and_both_routes_match_the_old_flood():
    for seed in range(4):
        h, sea, _ = _island(44, 300 + seed)
        f0, r0, o0 = _old_lem_route(h, sea, 44)
        f1, o1 = ev.lem.fill_order(h, sea, 44)
        assert np.array_equal(f1, f0) and np.array_equal(o1, o0), seed
        f2, r2, o2 = ev.lem.route(h, sea, 44)
        assert np.array_equal(f2, f0) and np.array_equal(r2, r0) and np.array_equal(o2, o0), seed
        f3, r3, o3 = ev.route(h, sea, 44, DX, 0.8)
        assert np.array_equal(f3, f0) and np.array_equal(o3, o0), seed
        assert np.array_equal(r3, _old_ltd_receivers(f0, o0, sea, 44, DX, 0.8, ev._FACETS)), seed


if __name__ == '__main__':
    for name, f in list(globals().items()):
        if name.startswith('test_') and callable(f):
            f()
            print('ok  ', name)
    print('test_evolve: all passed')
