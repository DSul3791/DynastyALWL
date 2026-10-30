"""Fast landscape evolution: implicit stream power + diffusion + sediment into basins. numba."""
import numpy as np, numba as nb, heapq, time, sys
from scipy.ndimage import gaussian_filter

@nb.njit(cache=True, fastmath=False, parallel=False)
def route(h, sea, n):
    """priority-flood fill with epsilon; returns filled, receiver, order (downstream first)."""
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

@nb.njit(cache=True, fastmath=False, parallel=False)
def step(h, sea, n, dx, dt, K, m, U, D, ery, dep_frac, fill_out, area_out, dmul, rain):
    filled, rec, order = route(h, sea, n)
    N = n*n
    cell = dx*dx
    A = np.zeros(N)
    for q in order: A[q] = cell*rain[q]   # runoff per cell: 1 = the reference rain; deserts less, wet land more
    for q in range(order.size-1, -1, -1):
        i = order[q]; d = rec[i]
        if d >= 0 and not sea[d]: A[d] += A[i]
    h0 = h.copy()
    # uplift (land only)
    for i in range(N):
        if not sea[i]: h[i] += U[i]*dt
    # implicit stream power, downstream first
    for q in range(order.size):
        i = order[q]; d = rec[i]
        if d < 0: continue
        dist = dx
        if abs(d-i) != 1 and abs(d-i) != n: dist = dx*1.4142
        f = K*ery[i]*dt*A[i]**m/dist
        if filled[i] - filled[d] > 0 and h[i] > h[d]:
            h[i] = (h[i] + f*h[d])/(1+f)
    # hillslope diffusion (explicit, stable: D dt/dx^2 <= .2 via substeps)
    dmax = 1.0
    for i in range(N):
        if dmul[i] > dmax: dmax = dmul[i]
    ns = int(np.ceil(D*dmax*dt/(dx*dx)/0.2)); ns = max(ns, 1)
    kk = D*dt/ns/(dx*dx)
    for s in range(ns):
        b = h.copy()
        for r in range(1, n-1):
            for c in range(1, n-1):
                i = r*n+c
                if sea[i]: continue
                lap = b[i-1]+b[i+1]+b[i-n]+b[i+n]-4*b[i]
                h[i] = max(b[i]+kk*ery[i]*dmul[i]*lap, 0.05)
    # sediment: eroded volume travels downstream, drops in pits (filled-h > 0)
    Q = np.zeros(N)
    for i in range(N):
        if not sea[i]:
            e = (h0[i]+U[i]*dt) - h[i]
            if e > 0: Q[i] = e*cell
    for q in range(order.size-1, -1, -1):
        i = order[q]
        pit = filled[i]-h[i]
        if pit > 0.01 and Q[i] > 0:
            dep = min(Q[i], dep_frac*pit*cell)
            h[i] += dep/cell; Q[i] -= dep
        d = rec[i]
        if d >= 0 and not sea[d]: Q[d] += Q[i]
    for i in range(N):
        fill_out[i] = max(filled[i]-h[i], 0.0); area_out[i] = A[i]

def make_start(n, dx, seed=7, summit=1300.0):
    rng = np.random.default_rng(seed)
    L = n*dx
    y, x = np.mgrid[0:n, 0:n]*dx
    # island: lobed radius mask
    cx = cy = L/2
    ang = np.arctan2(y-cy, x-cx)
    rad = np.hypot(x-cx, y-cy)
    lob = 1+0.25*np.sin(3*ang+1.0)+0.15*np.sin(5*ang+2.0)
    edge = 0.40*L*lob
    mask = np.clip(1-rad/edge, 0, 1)
    noise = np.zeros((n, n))
    for sig, amp in ((n/6, 1.0), (n/14, 0.55), (n/40, 0.25), (n/100, 0.08)):
        f = gaussian_filter(rng.standard_normal((n, n)), sig, mode='wrap'); f /= f.std()
        noise += amp*f
    ridge = np.clip(mask, 0, 1)**0.8
    h = summit*ridge*(0.55+0.45*(noise/ noise.std()*0.5+0.5).clip(0, 1.4)) - 40
    h = gaussian_filter(h, 1.0)
    return h

def run_from(start_h, dx, years=1.0e6, dt=4000.0, K=1.2e-6, m=0.5, U=6e-4, D=0.02, seed=7, log=False, dep=0.3, off=0.7, coast_pow=1.5, basins=14, sub=3.0, ramp_m=12000.0, balance=0.0, bal_smooth=3.0, lowboost=0.0, low_from=150.0, low_to=350.0, tarn=False, rain_map=None, ery_map=None, uplift_map=None):
    return run(n=start_h.shape[0], dx=dx, years=years, dt=dt, K=K, m=m, U=U, D=D, seed=seed, log=log, dep=dep, off=off, coast_pow=coast_pow, basins=basins, sub=sub, ramp_m=ramp_m, start_h=start_h, balance=balance, bal_smooth=bal_smooth, lowboost=lowboost, low_from=low_from, low_to=low_to, tarn=tarn, rain_map=rain_map, ery_map=ery_map, uplift_map=uplift_map)

def run(n=720, dx=64.0, years=1.0e6, dt=4000.0, K=1.2e-6, m=0.5, U=6e-4, D=0.02, seed=7, log=True, dep=0.3, off=0.7, coast_pow=1.5, summit=1300.0, basins=14, sub=3.0, ramp_m=12000.0, start_h=None, balance=0.0, bal_smooth=3.0, lowboost=0.0, low_from=150.0, low_to=350.0, tarn=False, rain_map=None, ery_map=None, uplift_map=None):
    h = (start_h.copy() if start_h is not None else make_start(n, dx, seed, summit)).ravel().astype(np.float64)
    start = h.copy()
    sea = (h <= 0).astype(np.uint8)
    h[sea == 1] = np.minimum(h[sea == 1], -1.0)
    ery = np.ones(n*n) if ery_map is None else np.asarray(ery_map, dtype=np.float64).ravel().copy()   # rock hardness / cover: higher erodes faster
    rain = np.ones(n*n) if rain_map is None else np.asarray(rain_map, dtype=np.float64).ravel().copy()
    w = np.clip((h-low_from)/(low_to-low_from), 0, 1); w = w*w*(3-2*w)
    dmul = 1.0 + lowboost*(1.0-w)
    # uplift ramps up from the coast (distance to sea) so coastal land stays low and gentle
    from scipy.ndimage import distance_transform_edt
    dist = distance_transform_edt((sea == 0).reshape(n, n)).ravel()*dx
    Umap = U*np.clip(dist/ramp_m, 0, 1)**coast_pow
    if balance > 0:
        # uplift that would hold the starting surface in stream-power balance (keeps summits and relief bands)
        hs = np.maximum(h, 0.0)
        filled0, rec0, order0 = route(hs, sea, n)
        A0 = np.zeros(n*n)
        for q in order0: A0[q] = dx*dx
        for q in range(order0.size-1, -1, -1):
            i = order0[q]; d = rec0[i]
            if d >= 0 and sea[d] == 0: A0[d] += A0[i]
        S0 = np.zeros(n*n)
        for q in order0:
            d = rec0[q]
            if d >= 0:
                dd = dx*(1.4142 if abs(d-q) not in (1, n) else 1.0)
                S0[q] = max(filled0[q]-filled0[d], 0)/dd
        lap = (np.roll(hs.reshape(n, n), 1, 0)+np.roll(hs.reshape(n, n), -1, 0)+np.roll(hs.reshape(n, n), 1, 1)+np.roll(hs.reshape(n, n), -1, 1)-4*hs.reshape(n, n))/(dx*dx)
        Ub = K*A0**m*S0 - D*w*lap.ravel()
        Ub = np.clip(Ub, 0, 5*U if U > 0 else 1e-2); Ub[sea == 1] = 0; Ub = gaussian_filter(Ub.reshape(n, n), bal_smooth).ravel()
        Umap = balance*Ub
    if uplift_map is not None:
        Umap = np.asarray(uplift_map, dtype=np.float64).ravel().copy()   # uplift told to us (m/yr per cell), not worked out from the finished shape
    Uzero = np.zeros(n*n)
    # tectonic/glacial hollows: sink patches in the mid-lands become catch basins (lakes)
    rng = np.random.default_rng(seed+1); yy, xx = np.mgrid[0:n, 0:n]*dx; placed = 0
    d2 = dist.reshape(n, n); sink = np.zeros((n, n))
    while placed < basins:
        r, c = rng.integers(0, n, 2)
        ok = (15 < h.reshape(n, n)[r, c] < 220 and d2[r, c] > 300) if tarn else (2500 < d2[r, c] < 9000)
        if ok:
            rad = rng.uniform(150, 450) if tarn else rng.uniform(500, 1100)
            sink += np.exp(-((yy-r*dx)**2+(xx-c*dx)**2)/(2*(rad/1.6)**2)); placed += 1
    Umap = Umap - sub*(Umap[sea == 0].mean() if balance > 0 else U)*np.clip(sink, 0, 1).ravel()
    Umap[sea == 1] = 0
    fill = np.zeros(n*n); area = np.zeros(n*n)
    nsteps = int(years/dt); t0 = time.time()
    for s in range(nsteps):
        step(h, sea, n, dx, dt, K, m, Umap if s < off*nsteps else Uzero, D, ery, dep, fill, area, dmul, rain)
        if log and s % 50 == 0: print(s, nsteps, round(time.time()-t0, 1), 'max h', round(h.max()), flush=True)
    return start.reshape(n, n), h.reshape(n, n), sea.reshape(n, n), fill.reshape(n, n), area.reshape(n, n), time.time()-t0
