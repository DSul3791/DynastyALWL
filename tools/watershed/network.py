"""Stages C5, C7 and C8 of the watershed rebuild (docs/water/watershed_rebuild_design.md, R5 method): the stream network.

Usage (on Dave's PC, never in the cloud):
  python tools/watershed/network.py INPUTS_DIR GEOLOGY_DIR B2_DIR R3_DIR R4_DIR OUT_DIR [params.json]

Reads one run's chain (record.py's chain check: every stage read exactly the files given here): inputs.npz (A: rain),
glacial.npz (B2: rock at the surface, loose cover, ice, sediment flux, the one water budget), lakes.npz and lakes.json (R3),
groundwater.npz (R4: groundwater coming out, depth to the table, transmissivity, wetlands). Writes to OUT_DIR:
  network.json           the island-wide vectors for the record (design D): reaches with their polylines, heads, confluences,
                         falls, springs, lakes with their inflow and outlet reaches, and the outlets to the sea and into lakes,
                         each with the seven answers of the watershed document (section 13, principle 8);
  network.npz            the same on the 16 m grid, for record.py --network: stream class, reach id, flows, sizes, reach type,
                         pattern, bed, regime;
  network_manifest.json  input hashes, params, summary, never-see checks, and what is still missing;
  follow_the_water.md    the success test (item 12): contrasting basins followed from the top of their main stem to the sea;
  network.png            the picture.

The method is the design's R5 method, items 1 to 12, with numbers from docs/knowledge/rivers-floodplains.md (#599) and
docs/knowledge/upland-streams-numbers.md (#612) unless params.json marks them judged. There is no random number in this stage:
every stream, size, type, fall and outlet follows from the ground, the rock, the water budget and the groundwater.
"""
import sys, os, json, time
import numpy as np
import numba as nb
from scipy.ndimage import uniform_filter, maximum_filter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'erosion_precarve'))
sys.path.insert(0, HERE)
import rock      # noqa: E402
import evolve    # noqa: E402
import record    # noqa: E402
import springstore   # noqa: E402

YEAR_S = 3.15576e7
VERSION = 1
RIVER, SEASONAL_CHANNEL = 3, 8                      # the record's water class codes (design D)
TYPES = ('none', 'cascade', 'step-pool', 'plane-bed', 'pool-riffle', 'dune-ripple')
PATTERNS = ('none', 'confined', 'meandering', 'braided')
BEDS = ('none', 'boulders', 'cobbles', 'gravel', 'sand', 'silt', 'peat')
REGIMES = ('none', 'perennial', 'intermittent', 'ephemeral')
BANKS = ('grass', 'trees 1 to 5%', 'trees 5 to 50%', 'trees over 50% or incised')
# Typical bed of each reach type (Montgomery and Buffington 1997, table 1): cascade boulder; step-pool cobble and boulder
# (the coarser kept, it sets the steps); plane-bed gravel and cobble (cobble, the armour); pool-riffle gravel; dune-ripple sand.
BED_OF_TYPE = np.array([0, 1, 1, 2, 3, 4], np.uint8)
PEAT_WETLANDS = (6, 7)                              # fen and bog (R4 codes)
EVIDENCE = {1: 'boulders and bare rock, white water, scoured banks', 2: 'boulder steps with plunge pools between them',
            3: 'an even cobble bed with few bars', 4: 'gravel bars and riffles between pools',
            5: 'a sand bed with ripples and dunes'}


# ---------------------------------------------------------------------------------------------------------------------------
# Trees on the 16 m grid (cells are flat indices, row = z, column = x)

@nb.njit(cache=True)
def _step_m(a, b, n, dx):
    if a // n != b // n and a % n != b % n:
        return dx * 1.4142135623730951
    return dx


@nb.njit(cache=True)
def _order(rec, outlet):
    """Land cells downstream first, from the receivers alone, and the donors of each cell (CSR: don[cnt[i]:cnt[i + 1]]).
    Roots are the cells whose receiver is an outlet (the sea or a closed lake) or none. Cells never reached (a cycle) are
    left out, and the caller counts them."""
    N = rec.size
    cnt = np.zeros(N + 1, np.int64)
    for i in range(N):
        d = rec[i]
        if not outlet[i] and d >= 0 and not outlet[d]:
            cnt[d + 1] += 1
    for i in range(N):
        cnt[i + 1] += cnt[i]
    don = np.empty(cnt[N], np.int64)
    fill = cnt[:N].copy()
    for i in range(N):
        d = rec[i]
        if not outlet[i] and d >= 0 and not outlet[d]:
            don[fill[d]] = i
            fill[d] += 1
    out = np.empty(N, np.int64)
    k = 0
    for i in range(N):
        if outlet[i]:
            continue
        d = rec[i]
        if d < 0 or outlet[d]:
            out[k] = i
            k += 1
    q = 0
    while q < k:
        i = out[q]
        q += 1
        for j in range(cnt[i], cnt[i + 1]):
            out[k] = don[j]
            k += 1
    return out[:k], cnt, don


@nb.njit(cache=True)
def _accumulate(order, rec, outlet, src):
    """Sum src down the tree (src in absolute units per cell: m2, m3/s, ...); any sign."""
    acc = src.copy()
    for q in range(order.size - 1, -1, -1):
        i = order[q]
        d = rec[i]
        if d >= 0 and not outlet[d]:
            acc[d] += acc[i]
    return acc


@nb.njit(cache=True)
def _flow(order, rec, outlet, src, cap):
    """Flow (m3/s) leaving each cell: what arrives plus src, less up to cap taken there (water lost to the bed, or a lake's
    evaporation and seepage). Returns the flow and the loss at each cell."""
    N = rec.size
    Q = np.zeros(N)
    lost = np.zeros(N)
    for q in range(order.size - 1, -1, -1):
        i = order[q]
        v = Q[i] + src[i]
        if v < 0.0:
            v = 0.0
        t = cap[i]
        if t > v:
            t = v
        lost[i] = t
        v -= t
        Q[i] = v
        d = rec[i]
        if d >= 0 and not outlet[d]:
            Q[d] += v
    return Q, lost


@nb.njit(cache=True)
def _main_donor(order, rec, outlet, A):
    """Each cell's donor with the largest drainage area (ties to the lower index): the main stem upstream."""
    md = np.full(rec.size, -1, np.int64)
    for q in range(order.size):
        i = order[q]
        d = rec[i]
        if d >= 0 and not outlet[d]:
            m = md[d]
            if m < 0 or A[i] > A[m] or (A[i] == A[m] and i < m):
                md[d] = i
    return md


@nb.njit(cache=True)
def _window_slope(cells, h, rec, md, stop, up_m, down_m, n, dx):
    """Bed slope over a window along the main stem: up the largest donor up_m metres and down the receivers down_m metres,
    stopping at lakes and the sea (stop). A cell-to-cell slope on a 16 m grid is mostly noise; a reach is judged over its
    own length."""
    out = np.zeros(cells.size)
    for k in range(cells.size):
        i = cells[k]
        j = i
        dd = 0.0
        while dd < down_m[k]:
            d = rec[j]
            if d < 0 or stop[d]:
                break
            dd += _step_m(j, d, n, dx)
            j = d
        u = i
        du = 0.0
        while du < up_m[k]:
            a = md[u]
            if a < 0 or stop[a]:
                break
            du += _step_m(a, u, n, dx)
            u = a
        L = dd + du
        if L > 0.0:
            s = (h[u] - h[j]) / L
            out[k] = s if s > 0.0 else 0.0
    return out


@nb.njit(cache=True)
def _floor_width(cells, h, rec, sea, rise, max_m, ahead, n, dx):
    """Width of the valley floor across each stream cell: the ground within rise[k] metres of the bed, walked out on both
    sides square to the flow (the flow direction is taken over `ahead` cells downstream), in half-cell steps."""
    out = np.zeros(cells.size)
    for k in range(cells.size):
        i = cells[k]
        j = i
        for _ in range(ahead):
            d = rec[j]
            if d < 0:
                break
            j = d
        r0 = i // n
        c0 = i % n
        fr = float(j // n - r0)
        fc = float(j % n - c0)
        L = np.sqrt(fr * fr + fc * fc)
        if L == 0.0:
            fr, fc, L = 0.0, 1.0, 1.0
        pr = -fc / L
        pc = fr / L
        top = h[i] + rise[k]
        w = 0.0
        for side in range(2):
            sg = -1.0 if side == 0 else 1.0
            t = 0.0
            while t < max_m:
                t += 0.5 * dx
                rr = int(np.floor(r0 + sg * pr * t / dx + 0.5))
                cc = int(np.floor(c0 + sg * pc * t / dx + 0.5))
                if rr < 0 or rr >= n or cc < 0 or cc >= n:
                    break
                q = rr * n + cc
                if sea[q] or h[q] > top:
                    break
            w += t - 0.25 * dx
        out[k] = w
    return out


@nb.njit(cache=True)
def _strahler(order, rec, outlet, vis):
    """Strahler order of the visible streams."""
    N = rec.size
    so = np.zeros(N, np.int64)
    top = np.zeros(N, np.int64)
    cnt = np.zeros(N, np.int64)
    for q in range(order.size - 1, -1, -1):
        i = order[q]
        if not vis[i]:
            continue
        if top[i] == 0:
            so[i] = 1
        elif cnt[i] >= 2:
            so[i] = top[i] + 1
        else:
            so[i] = top[i]
        d = rec[i]
        if d >= 0 and not outlet[d] and vis[d]:
            if so[i] > top[d]:
                top[d] = so[i]
                cnt[d] = 1
            elif so[i] == top[d]:
                cnt[d] += 1
    return so


@nb.njit(cache=True)
def _fetch(r0, c0, water, target, n, dx, rays, max_m):
    """The longest straight run over the water `target` (a lake id, or -2 for the sea) from a mouth at (r0, c0), over `rays`
    directions, and whether such a run left the window over water (the open ocean beyond: a fully developed sea)."""
    best = 0.0
    opened = False
    for k in range(rays):
        a = 2.0 * np.pi * k / rays
        dr = np.sin(a)
        dc = np.cos(a)
        t = 0.0
        on = False
        left = False
        while t < max_m:
            t += 0.5 * dx
            rr = int(np.floor(r0 + dr * t / dx + 0.5))
            cc = int(np.floor(c0 + dc * t / dx + 0.5))
            if rr < 0 or rr >= n or cc < 0 or cc >= n:
                left = on
                break
            if water[rr * n + cc] == target:
                on = True
            elif on:
                break
            elif t > 3.0 * dx:
                break                                   # this ray points inland
        if on:
            if left:
                opened = True
            if t > best:
                best = t
    return best, opened


# ---------------------------------------------------------------------------------------------------------------------------
# Numbers

def seasons(rain, et, land, SN, warmest_phase):
    """Wet- and dry-season shares of the quick runoff per cell, and of the baseflow island-wide (R5 item 2).
    Rain and evaporation each follow the year on a cosine around their annual means (rain peaking at
    rain_wettest_year_phase, evaporation at the warmest phase of the island's climate). The water left over, never below 0,
    runs off quickly within days, so a cell's quick runoff in a season is its share of the year's leftover water. The
    groundwater evens it out: the island's recharge through one linear store (recession time baseflow_recession_days) gives
    the island's baseflow season shares, used only for an R4 run written before each spring's own stores; with them, main()
    puts the recharge shape (_shape, _wk, _dk, returned for it) through each spring's stores (springstore.py). The wet season
    is the quarter of the year centred on the rain peak, the dry season the quarter opposite."""
    S = int(SN['samples'])
    t = (np.arange(S) + 0.5) / S
    phw = float(SN['rain_wettest_year_phase'])

    def quarter(c):
        return np.abs((t - c + 0.5) % 1.0 - 0.5) <= 0.125 + 1e-9
    wk, dk = quarter(phw), quarter(phw + 0.5)
    rs = 1.0 + float(SN['rain_swing_share']) * np.cos(2.0 * np.pi * (t - phw))
    es = 1.0 + float(SN['et_swing_share']) * np.cos(2.0 * np.pi * (t - warmest_phase))
    tot = np.zeros_like(rain)
    wet = np.zeros_like(rain)
    dry = np.zeros_like(rain)
    shape = np.zeros(S)
    for k in range(S):
        ex = np.maximum(rain * rs[k] - et * es[k], 0.0)
        tot += ex
        if wk[k]:
            wet += ex
        if dk[k]:
            dry += ex
        shape[k] = float(ex[land].mean()) if land.any() else 1.0
    tot /= S
    wet /= wk.sum()
    dry /= dk.sum()
    f_wet = np.where(tot > 0.0, wet / np.maximum(tot, 1e-12), 1.0)
    f_dry = np.where(tot > 0.0, dry / np.maximum(tot, 1e-12), 1.0)
    shape = shape / max(float(shape.mean()), 1e-12)
    base_wet, base_dry = springstore.quarter_shares(shape, wk, dk, float(SN['baseflow_recession_days']))
    return dict(quick_wet=f_wet, quick_dry=f_dry, base_wet=base_wet, base_dry=base_dry,
                evap_wet=float(es[wk].mean()), evap_dry=float(es[dk].mean()), _shape=shape, _wk=wk, _dk=dk)


def _stores_summary(source, gw, base_wet, base_dry, sea_sn, island_days, springs, perennial_km, perennial_km_island, perennial_q):
    """The manifest's report on the springs' own stores (spring_store_build_plan.md section 6, item 4): which store was used,
    the island's flow-weighted wet and dry shares against the old island store, the perennial kilometres both ways, and the
    springs whose own dry flow passes the perennial threshold both ways. Reported, not judged."""
    q = float(gw.sum())
    dry_q = [s['q_base_dry_m3_s'] for s in springs]
    return dict(source=source,
                flow_weighted=dict(wet=r3(float((gw * base_wet).sum()) / max(q, 1e-30)), dry=r3(float((gw * base_dry).sum()) / max(q, 1e-30))),
                island_store=dict(days=island_days, wet=r3(sea_sn['base_wet']), dry=r3(sea_sn['base_dry'])),
                perennial_km=dict(own_stores=perennial_km, island_store=perennial_km_island),
                springs_over_perennial=dict(own_stores=sum(1 for v in dry_q if v >= perennial_q),
                                            island_store=sum(1 for s in springs if s['m3_s'] * sea_sn['base_dry'] >= perennial_q)),
                springs_by_main_store={k: sum(1 for s in springs if s.get('stores') and max(s['stores'], key=lambda r: r[3])[0] == k)
                                       for k in springstore.STORE_KINDS})


def meander_table():
    """The sine-generated curve (Langbein and Leopold 1966): direction theta = omega cos(2 pi s / M) along the arc length s.
    For each omega: the wavelength over the arc length (J0(omega), so sinuosity 1 / J0), the lateral extent peak to peak over
    the wavelength, and the tightest bend radius over the wavelength (1 / (2 pi omega J0))."""
    om = np.linspace(0.02, 2.0, 400)
    s = np.linspace(0.0, 1.0, 4001)
    ds = s[1] - s[0]
    th = om[:, None] * np.cos(2.0 * np.pi * s[None, :])
    x = np.cumsum(np.cos(th), axis=1) * ds
    y = np.cumsum(np.sin(th), axis=1) * ds
    lam = x[:, -1]
    return dict(omega=om, sinuosity=1.0 / lam, amp_over_lambda=(y.max(axis=1) - y.min(axis=1)) / lam,
                radius_over_lambda=1.0 / (2.0 * np.pi * om * lam))


def meander(width, M, T, banks_cohesive, banks_loose):
    """Wavelength, amplitude (peak to peak), sinuosity and riffle spacing of a meandering stretch of bankfull width `width`
    (R5 item 5): wavelength about 11 widths (tighter in cohesive banks, longer in loose gravel), amplitude 2.7 W^1.1, with
    the tightest bend kept at least min_bend_radius_widths widths."""
    per = float(M['wavelength_widths_cohesive'] if banks_cohesive else (M['wavelength_widths_loose'] if banks_loose else M['wavelength_widths']))
    lam = per * width
    amp = float(M['amplitude_coefficient']) * width ** float(M['amplitude_exponent'])
    want = amp / lam
    # The bend radius over the wavelength falls with omega up to about 1.25 rad and rises again toward the loops (omega J0
    # peaks there), so the limit is the first omega whose bend is too tight, not the last that is wide enough.
    tight = np.flatnonzero(T['radius_over_lambda'] < float(M['min_bend_radius_widths']) * width / lam)
    k_max = max(int(tight[0]) - 1, 0) if tight.size else T['omega'].size - 1
    k = int(np.searchsorted(T['amp_over_lambda'], want))
    k = min(k, k_max, T['omega'].size - 1)
    return dict(wavelength_m=round(lam, 1), amplitude_m=round(float(T['amp_over_lambda'][k] * lam), 1),
                sinuosity=round(float(T['sinuosity'][k]), 3), max_angle_deg=round(float(np.degrees(T['omega'][k])), 1),
                riffle_spacing_m=round(float(M['riffle_spacing_widths']) * width, 1))


def waves(fetch_m, opened, C):
    """Significant height and peak period of wind waves in deep water (Shore Protection Manual, CERC 1984, fetch-limited
    growth): g Hs / U^2 = 1.6e-3 (g F / U^2)^0.5 and g Tp / U = 0.2857 (g F / U^2)^(1/3), up to the fully developed sea
    (0.2433 and 8.134). A fetch that leaves the window is open ocean: fully developed."""
    g = 9.81
    U = float(C['wind_stress_m_s'])
    if opened:
        return 0.2433 * U * U / g, 8.134 * U / g
    x = g * max(fetch_m, 1.0) / (U * U)
    return min(1.6e-3 * x ** 0.5, 0.2433) * U * U / g, min(0.2857 * x ** (1.0 / 3.0), 8.134) * U / g


def r3(v, k=3):
    return float(f'{float(v):.{k}g}')


# ---------------------------------------------------------------------------------------------------------------------------

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    inputs_dir, geology_dir, b2_dir, r3_dir, r4_dir, out_dir = args[:6]
    P = json.load(open(args[6] if len(args) > 6 else os.path.join(HERE, 'params.json')))
    NW, E, G = P['network'], P['evolve'], P['groundwater']
    climate = P['record']['climate']['default']
    os.makedirs(out_dir, exist_ok=True)
    t0 = time.time()
    hashes = record.check_chain(inputs_dir, b2_dir, r3_dir, r4_dir)

    A_in = np.load(f'{inputs_dir}/inputs.npz')
    b2 = np.load(f'{b2_dir}/glacial.npz')
    l3 = np.load(f'{r3_dir}/lakes.npz')
    g4 = np.load(f'{r4_dir}/groundwater.npz')
    lakes = json.load(open(f'{r3_dir}/lakes.json'))
    geo = rock.load(geology_dir, E['cover_m'], E['cover_erodibility'])
    names, er = geo['names'], geo['er']

    n = l3['ground'].shape[0]
    N = n * n
    dx = float(l3['cell_m'])
    cell = dx * dx
    ox, oz = float(l3['origin_x']), float(l3['origin_z'])
    h = l3['ground'].astype(np.float64).ravel()
    sea = l3['sea'].astype(bool).ravel()
    land = ~sea
    lake_id = l3['lake_id'].astype(np.int64).ravel()
    lake = lake_id >= 0
    by_id = {int(lk['id']): lk for lk in lakes}
    closed_ids = np.array([k for k, lk in by_id.items() if not lk['full']], np.int64)
    closed = np.isin(lake_id, closed_ids) & lake
    rid = b2['rock'].astype(np.int64).ravel()
    sed = np.nan_to_num(b2['sediment_m'].astype(np.float64).ravel())
    till = np.nan_to_num(b2['till_m'].astype(np.float64).ravel())
    outwash = np.nan_to_num(b2['outwash_m'].astype(np.float64).ravel())
    ice = np.nan_to_num(b2['ice_max_m'].astype(np.float64).ravel())
    sflux = np.nan_to_num(b2['sediment_flux_m3_yr'].astype(np.float64).ravel())
    channel_share = b2['channel'].astype(np.float64).ravel()
    gw = np.nan_to_num(g4['gw_discharge_m3_s'].astype(np.float64).ravel())
    depth_table = np.nan_to_num(g4['depth_to_table_m'].astype(np.float64).ravel())
    K_local = np.nan_to_num(g4['transmissivity_m2_s'].astype(np.float64).ravel()) / float(G['thickness_m'])
    wetland = g4['wetland'].astype(np.int64).ravel()
    basin_id = l3['basin_id'].astype(np.int64).ravel()
    treeline = float(G['treeline_m'])

    # Routing. The final ground's routing (R3, D8-LTD over a priority flood), with the closed lakes as outlets like the sea, so
    # the water of a closed basin ends in its lake instead of crossing the dry flat a fill would lay over the basin.
    outlet = sea | closed
    _, rec, _ = evolve.route(h, outlet.astype(np.uint8), n, dx, evolve.flow_memory(E))
    rec = np.asarray(rec, np.int64)
    rec = np.where(outlet, -1, rec)
    order, dcnt, dons = _order(rec, outlet)
    unreached = int(land.sum() - closed.sum() - order.size)
    if unreached:
        raise SystemExit(f'network: {unreached} land cells are not on a tree to an outlet (a cycle in the routing)')
    to = np.maximum(rec, 0)
    r_, c_ = np.divmod(np.arange(N), n)
    step = np.where((rec >= 0) & (r_ != to // n) & (c_ != to % n), dx * np.sqrt(2.0), dx)
    zero = np.zeros(N)
    A = _accumulate(order, rec, outlet, np.where(land, cell, 0.0))

    # 2. Flows. Quick runoff and groundwater by season; a full lake loses its evaporation and seepage at its exit.
    SN = NW['season']
    quick_mm = np.nan_to_num(b2['quick_mm'].astype(np.float64).ravel())
    recharge_mm = np.nan_to_num(b2['recharge_mm'].astype(np.float64).ravel())
    rain = A_in['rain'].astype(np.float64).ravel()
    et = np.nan_to_num(b2['et_mm'].astype(np.float64).ravel())
    sea_sn = seasons(rain, et, land, SN, float(climate['warmest_year_phase']))
    q_cell = np.where(land, quick_mm, 0.0) / 1000.0 / YEAR_S * cell
    # Each spring's own stores (R4's gw_* fields; springstore.py, docs/water/spring_store_build_plan.md sections 3 and 7):
    # the groundwater's wet and dry shares at a cell are its stores' shares through their own response times. An R4 run
    # written before the stores falls back to the island's one store, and the manifest says which was used.
    if all(f'gw_{k}' in g4.files for k in springstore.FIELDS):
        st = {k: g4[f'gw_{k}'].astype(np.float64).ravel() for k in springstore.FIELDS}
        ks = springstore.kind_shares(st, sea_sn['_shape'], sea_sn['_wk'], sea_sn['_dk'], springstore.tau_bins(SN['tau_bins']))
        base_wet, base_dry_share = springstore.cell_shares(st, ks)
        lacking = int(((gw > 0.0) & ~np.isfinite(base_dry_share)).sum())
        if lacking:
            raise SystemExit(f'network: {lacking} cells put groundwater out but have no stores in groundwater.npz (R4 and its stores disagree)')
        base_wet, base_dry_share = np.nan_to_num(base_wet, nan=1.0), np.nan_to_num(base_dry_share, nan=1.0)
        store_source = 'each spring (groundwater.npz stores)'
    else:
        st = ks = None
        base_wet, base_dry_share = np.full(N, sea_sn['base_wet']), np.full(N, sea_sn['base_dry'])
        store_source = f"the island's one store of {SN['baseflow_recession_days']:g} days (an R4 run without stores)"
    src = dict(mean=q_cell + gw, wet=q_cell * sea_sn['quick_wet'] + gw * base_wet,
               dry=q_cell * sea_sn['quick_dry'] + gw * base_dry_share)
    exits = {}
    leaves = lake & ~closed & ((rec < 0) | (lake_id[to] != lake_id))
    for i in np.flatnonzero(leaves):
        L = int(lake_id[i])
        if L not in exits or A[i] > A[exits[L]]:
            exits[L] = int(i)
    lake_cap = dict(mean=zero.copy(), wet=zero.copy(), dry=zero.copy())
    for L, i in exits.items():
        loss = float(by_id[L]['losses_m3_s'])
        lake_cap['mean'][i] = loss
        lake_cap['wet'][i] = loss * sea_sn['evap_wet']
        lake_cap['dry'][i] = loss * sea_sn['evap_dry']
    Q0 = {s: _flow(order, rec, outlet, src[s], lake_cap[s])[0] for s in ('mean', 'wet', 'dry')}

    # The flood that sizes the channel: QMED from the mean flow by catchment size and permeability (FEH 2008), cut by the
    # lakes on the way (FARL), and bankfull at 0.9 QMED. Losing reaches lose little of a flood, so the flood uses Q0.
    Qn = NW['qmed']
    rech_acc = _accumulate(order, rec, outlet, np.where(land, recharge_mm, 0.0) * cell)
    quick_acc = _accumulate(order, rec, outlet, np.where(land, quick_mm, 0.0) * cell)
    bfi_c = rech_acc / np.maximum(rech_acc + quick_acc, 1e-12)
    farl_src = zero.copy()
    for L, i in exits.items():
        alpha = max(1.0 - np.sqrt(float(by_id[L]['area_km2']) * 1e6 / max(A[i], 1.0)), float(Qn['farl_alpha_floor']))
        farl_src[i] = np.log(alpha) * A[i]
    ln_farl = _accumulate(order, rec, outlet, farl_src) / np.maximum(A, 1.0)
    tq = np.clip((bfi_c - float(Qn['bfi_tight'])) / (float(Qn['bfi_permeable']) - float(Qn['bfi_tight'])), 0.0, 1.0)
    r10 = np.exp((1.0 - tq) * np.log(float(Qn['over_mean_at_10km2_tight'])) + tq * np.log(float(Qn['over_mean_at_10km2_permeable'])))
    ratio = r10 * (np.maximum(A / 1e6, float(Qn['area_floor_km2'])) / 10.0) ** float(Qn['area_exponent']) * np.exp(float(Qn['farl_exponent']) * ln_farl)
    qmed = ratio * Q0['mean']
    qbf = float(Qn['bankfull_over_qmed']) * qmed

    # 3. Size: width from the banks (Hey and Thorne 1986), depth from Parker (2007); at-a-station below bankfull
    # (Leopold and Maddock 1953: width ~ Q^0.26, depth ~ Q^0.40).
    S3 = NW['size']
    channel = land & ~lake & ~closed & (channel_share > 0.5)
    wet_bank = np.isin(wetland, (4, 5, 6, 7))
    bank = np.where((h >= treeline) | wet_bank, 0, 2).astype(np.int64)            # judged until the biome map is read
    coef = np.array([S3['width_coefficient'][k] for k in ('grass', 'trees_1_5', 'trees_5_50', 'trees_over_50_or_incised')])
    Wbf = coef[bank] * np.sqrt(qbf)
    Dbf = float(S3['depth_coefficient']) * qbf ** float(S3['depth_exponent'])

    def at_flow(q, full, expo):
        return full * np.minimum(q / np.maximum(qbf, 1e-12), 1.0) ** expo

    # 1. Losing reaches: where the bed lies well above the water table on ground that takes water, the bed leaks at the
    # streambed's conductivity under unit gradient (a disconnected stream, Brunner et al. 2009), or at the ground's own
    # if that is lower. R4 does not yet take this water back as recharge (listed as missing).
    LS = NW['loss']
    losing = channel & (depth_table > float(LS['disconnected_depth_m']))
    rate = np.where(losing, np.minimum(float(LS['bed_k_m_s']), K_local), 0.0)
    Q, lost = {}, {}
    for s in ('mean', 'wet', 'dry'):
        cap = rate * at_flow(Q0[s], Wbf, float(S3['at_station_width_exponent'])) * step + lake_cap[s]
        Q[s], lost[s] = _flow(order, rec, outlet, src[s], cap)
    cap_dry = rate * at_flow(Q0['dry'], Wbf, float(S3['at_station_width_exponent'])) * step + lake_cap['dry']
    base_dry, _ = _flow(order, rec, outlet, gw * base_dry_share, cap_dry)
    base_dry_island, _ = _flow(order, rec, outlet, gw * sea_sn['base_dry'], cap_dry) if st is not None else (base_dry, None)

    # 1. Which channels are streams: wet-season flow over one island threshold, set so the streams run
    # stream_density_km_per_km2 (Plynlimon's perennial network, #612).
    land_km2 = float(land.sum() * cell / 1e6)
    target_m = float(NW['stream_density_km_per_km2']) * land_km2 * 1000.0
    ch = np.flatnonzero(channel & (Q['wet'] > 0.0))
    srt = ch[np.argsort(-Q['wet'][ch], kind='stable')]
    run = np.cumsum(step[srt])
    k_at = int(np.searchsorted(run, target_m))
    q_vis = float(Q['wet'][srt[min(k_at, srt.size - 1)]]) if srt.size else np.inf
    vis = channel & (Q['wet'] >= q_vis) & (Q['wet'] > 0.0)
    perennial = vis & (base_dry >= float(G['perennial_baseflow_m3_s']))
    regime = np.zeros(N, np.uint8)
    r4reg = g4['regime'].astype(np.int64).ravel()
    regime[channel & ~vis] = np.where(np.isin(r4reg[channel & ~vis], (1, 2)), 2, 3)   # gullies: never perennial
    regime[vis] = 2
    regime[perennial] = 1
    stream = np.zeros(N, np.uint8)
    stream[vis] = SEASONAL_CHANNEL
    stream[perennial] = RIVER

    # 4. Reach type from the slope over about ten widths; 5. pattern; 3. incised banks.
    vc = np.flatnonzero(vis)
    md = _main_donor(order, rec, outlet, A)
    stop = sea | lake | closed
    half = np.maximum(float(NW['slope_window_widths']) * Wbf[vc], float(NW['slope_window_min_m'])) / 2.0
    S_vc = _window_slope(vc, h, rec, md, stop, half, half, n, dx)
    slope = np.zeros(N)
    slope[vc] = S_vc
    VF = NW['valley_floor']
    floor = np.zeros(N)
    floor[vc] = _floor_width(vc, h, rec, sea, float(VF['above_bed_depths']) * Dbf[vc], float(VF['max_m']), int(VF['ahead_cells']), n, dx)
    incised = vis & (floor < float(S3['incised_floor_widths']) * Wbf)
    bank[incised] = 3
    Wbf = coef[bank] * np.sqrt(qbf)
    RT = NW['reach_slope']
    rtype = np.zeros(N, np.uint8)
    rtype[vis] = np.select([slope[vis] >= RT['cascade'], slope[vis] >= RT['step_pool'], slope[vis] >= RT['plane_bed'],
                            (slope[vis] < RT['dune_ripple']) & (sed[vis] >= float(NW['loose_cover_m']))], [1, 2, 3, 5], 4)
    bed = np.zeros(N, np.uint8)
    bed[vis] = BED_OF_TYPE[rtype[vis]]
    peat_cell = np.isin(wetland, PEAT_WETLANDS)
    bed[vis & peat_cell] = 6
    BR, MW = NW['braid'], NW['meander']
    amp = float(MW['amplitude_coefficient']) * Wbf ** float(MW['amplitude_exponent'])
    braided = vis & (slope * qbf ** float(BR['exponent']) > float(BR['threshold'])) & \
        ((outwash >= float(NW['loose_cover_m'])) | (sed >= float(NW['loose_cover_m']))) & (h >= treeline)
    meandering = vis & ~braided & np.isin(rtype, (4, 5)) & (floor >= amp + Wbf)
    pattern = np.zeros(N, np.uint8)
    pattern[vis] = 1
    pattern[meandering] = 2
    pattern[braided] = 3
    so = _strahler(order, rec, outlet, vis)
    peat_acc = _accumulate(order, rec, outlet, np.where(peat_cell, cell, 0.0)) / np.maximum(A, 1.0)
    sed_acc = sflux                                                                 # B2's flux leaving each cell (m3/yr)

    # 8. Falls: a step more than steeper_than_above times steeper than the reach above, at least min_height_m high, pinned at
    # a hard bed over softer rock or at a hanging valley's lip; anything else steep is a cascade.
    FL = NW['falls']
    s1 = np.zeros(N)
    good = vis & (rec >= 0) & ~stop[to]
    s1[good] = (h[good] - h[to[good]]) / step[good]
    steep = good & (s1 >= float(FL['min_slope']))
    lips = np.flatnonzero(steep & ((md < 0) | ~steep[np.maximum(md, 0)]))
    above = _window_slope(lips, h, rec, md, stop, np.full(lips.size, float(FL['above_window_m'])), np.zeros(lips.size), n, dx)
    falls, unpinned = [], dict(count=0, highest_m=0.0)
    lip_at = {}
    for li, lip in enumerate(lips):
        cells = [int(lip)]
        j = int(lip)
        while True:
            d = int(rec[j])
            if d < 0 or not steep[d]:
                break
            cells.append(d)
            j = d
        foot = int(rec[j]) if rec[j] >= 0 else j
        height = float(h[lip] - h[foot])
        length = float(sum(step[c] for c in cells))
        if height < float(FL['min_height_m']) or height / max(length, 1.0) < float(FL['steeper_than_above']) * float(above[li]):
            continue
        lr = int(rid[lip])
        below = [int(rid[c]) for c in cells[1:]] + [int(rid[foot])]
        soft = [b for b in below if b != lr and er[lr] <= float(FL['hard_ratio']) * er[b]]
        down = [foot]
        for _ in range(int(FL['foot_cells'])):
            nx = int(rec[down[-1]])
            if nx < 0 or stop[nx]:
                break
            down.append(nx)
        ice_foot = float(max(ice[c] for c in down))
        hanging = ice_foot >= float(FL['trough_ice_m']) and ice[lip] <= float(FL['hanging_ice_ratio']) * ice_foot
        if sed[lip] >= float(NW['loose_cover_m']):
            cause = None                                                            # a loose bed cannot hold a step
        elif soft:
            cause = 'hard bed over softer rock'
        elif hanging:
            cause = 'hanging valley lip'
        else:
            cause = None
        if cause is None:
            unpinned['count'] += 1
            unpinned['highest_m'] = max(unpinned['highest_m'], round(height, 1))
            continue
        drops = [(float(h[c] - h[int(rec[c])]), int(rid[c])) for c in cells]
        hard_share = sum(dz for dz, r in drops if r == lr) / max(height, 1e-9)
        changes = sum(1 for a, b in zip(drops[:-1], drops[1:]) if a[1] != b[1])
        form = 'plunge' if hard_share >= float(FL['plunge_share']) else ('tiered' if changes >= 2 else 'cascade fall')
        lip_at[int(lip)] = len(falls)
        falls.append(dict(id=len(falls), lip=int(lip), foot=foot, x=ox + float(lip % n) * dx, z=oz + float(lip // n) * dx,
                          lip_y=round(float(h[lip]), 2), foot_x=ox + float(foot % n) * dx, foot_z=oz + float(foot // n) * dx,
                          foot_y=round(float(h[foot]), 2), height_m=round(height, 1), length_m=round(length, 1), form=form,
                          cause=cause, rock=names.get(lr, str(lr)), rock_below=names.get(soft[0], str(soft[0])) if soft else names.get(lr, str(lr)),
                          hard_share=round(hard_share, 2), slope_above=round(float(above[li]), 4),
                          q_mean_m3_s=r3(Q['mean'][lip]), q_bankfull_m3_s=r3(qbf[lip]), width_m=round(float(Wbf[lip]), 2)))
    # Never a staircase of equal steps: three or more falls in a row on one stream, equal in height and spacing.
    fall_next = {}
    for f in falls:
        j, dist = f['foot'], 0.0
        while j >= 0 and vis[j] and not stop[j]:
            if j in lip_at and j != f['lip']:
                fall_next[f['id']] = (lip_at[j], dist)
                break
            d = int(rec[j])
            if d < 0:
                break
            dist += float(step[j])
            j = d
    tol = float(FL['staircase_tolerance'])
    staircases = []
    for f in falls:
        if f['id'] not in fall_next:
            continue
        b, d1 = fall_next[f['id']]
        if b not in fall_next:
            continue
        c, d2 = fall_next[b]
        hs = [f['height_m'], falls[b]['height_m'], falls[c]['height_m']]
        if max(hs) <= (1 + tol) * min(hs) and max(d1, d2) <= (1 + tol) * max(min(d1, d2), 1.0):
            staircases.append(dict(falls=[f['id'], b, c], x=f['x'], z=f['z'], heights_m=hs, spacing_m=[round(d1), round(d2)]))

    # Reaches between heads, confluences, lakes and the sea.
    ok = vis & (rec >= 0) & ~outlet[to]
    nvd = np.bincount(to[ok & vis[to]], minlength=N)
    starts = np.flatnonzero(vis & (nvd != 1))
    reach_of = np.full(N, -1, np.int64)
    pts, ends = [], []
    for k, s in enumerate(starts):
        cells = [int(s)]
        reach_of[s] = k
        j = int(rec[s])
        while j >= 0 and not outlet[j] and vis[j] and nvd[j] == 1:
            cells.append(j)
            reach_of[j] = k
            j = int(rec[j])
        pts.append(cells)
        ends.append(j)

    def where(i):
        return ox + float(i % n) * dx, oz + float(i // n) * dx

    reaches = []
    for k, cells in enumerate(pts):
        j = ends[k]
        last = cells[-1]
        if j < 0 or sea[j]:
            end, down, lk = ('sea', None, None)
        elif lake[j]:
            end, down, lk = ('lake', None, int(lake_id[j]))
        elif vis[j]:
            end, down, lk = ('reach', int(reach_of[j]), None)
        else:
            end, down, lk = ('sinks' if channel[j] else 'leaves its channel', None, None)
        c = np.array(cells)
        runs = []
        key_prev = None
        for idx, ci in enumerate(cells):
            key = (int(rtype[ci]), int(pattern[ci]), int(regime[ci]), int(bed[ci]))
            if key != key_prev:
                runs.append([idx, TYPES[key[0]], PATTERNS[key[1]], REGIMES[key[2]], BEDS[key[3]]])
                key_prev = key
        stretches = []
        for a_, run_ in enumerate(runs):
            b_ = runs[a_ + 1][0] if a_ + 1 < len(runs) else len(cells)
            sd = dict(start=run_[0], end=b_ - 1, type=run_[1], pattern=run_[2], regime=run_[3], bed=run_[4])
            if run_[2] == 'meandering':
                seg = c[run_[0]:b_]
                coh = bool(np.mean((till[seg] >= 0.5 * np.maximum(sed[seg], 1e-9)) & (sed[seg] > 0.0) | peat_cell[seg]) > 0.5)
                loose = bool(np.mean(outwash[seg] >= float(NW['loose_cover_m'])) > 0.5)
                sd['meander'] = meander(float(Wbf[seg].mean()), MW, MT, coh, loose)
                if bool(np.mean(sed[seg] >= float(NW['loose_cover_m'])) > 0.5):
                    sd['floodplain'] = dict(plain_above_bed_m=round(float(Dbf[seg].mean()), 2),
                                            levee_height_m=round(float(NW['levee_height_depths']) * float(Dbf[seg].mean()), 2),
                                            levee_width_m=round(float(Wbf[seg].mean()), 1), valley_floor_m=round(float(floor[seg].mean()), 1))
            stretches.append(sd)
        # One row per 16 m cell, in point_fields order: [x, bed_y, z] first, the reader's point convention (water_record.gd).
        polyline = [[round(where(ci)[0], 1), round(float(h[ci]), 2), round(where(ci)[1], 1), round(float(Wbf[ci]), 2),
                     round(float(Dbf[ci]), 3), r3(Q['mean'][ci]), r3(Q['wet'][ci]), r3(Q['dry'][ci]), r3(base_dry[ci])] for ci in cells]
        length = float(step[c].sum())
        reaches.append(dict(id=k, down=-1 if down is None else down, ends=end, lake=lk, order=int(so[last]), basin=int(basin_id[last]),
                            length_m=round(length, 1), drop_m=round(float(h[cells[0]] - h[last]), 2),
                            area_km2=r3(A[last] / 1e6), q_m3_s=dict(mean=r3(Q['mean'][last]), wet=r3(Q['wet'][last]), dry=r3(Q['dry'][last]),
                                                                     base_dry=r3(base_dry[last]),
                                                                     qmed=r3(qmed[last]), bankfull=r3(qbf[last])),
                            width_m=dict(top=round(float(Wbf[cells[0]]), 2), bottom=round(float(Wbf[last]), 2)),
                            depth_m=dict(top=round(float(Dbf[cells[0]]), 3), bottom=round(float(Dbf[last]), 3)),
                            banks=BANKS[int(np.bincount(bank[c], minlength=4).argmax())],
                            groundwater_share=round(float(bfi_c[last]), 2), peat_share=round(float(peat_acc[last]), 3),
                            sediment_flux_m3_yr=r3(sed_acc[last]), lost_m3_s=r3(lost['mean'][c].sum()),
                            losing=bool(lost['mean'][c].sum() > 0.0), stretches=stretches, polyline=polyline))
    reach_end_cell = [p[-1] for p in pts]

    # Heads and confluences
    gw2 = (uniform_filter(gw.reshape(n, n), size=5, mode='constant') * 25.0).ravel()
    wet_near = (maximum_filter((wetland > 0).reshape(n, n), size=3) > 0).ravel()
    heads, confluences, lake_outlet_reach = [], [], {}
    for k, s in enumerate(starts):
        s = int(s)
        dn = dons[dcnt[s]:dcnt[s + 1]]
        if nvd[s] >= 2:
            ins = sorted({int(reach_of[d]) for d in dn if vis[d]})
            ar = sorted([float(A[d]) for d in dn if vis[d]])
            x, z = where(s)
            confluences.append(dict(pos=[x, round(float(h[s]), 2), z], reaches_in=ins, reach_out=k, tributary_area_ratio=round(ar[-2] / max(ar[-1], 1.0), 3)))
            continue
        lk_d = [int(lake_id[d]) for d in dn if lake[d]]
        if lk_d:
            kind = 'lake outlet'
            lake_outlet_reach[lk_d[0]] = k
        elif gw2[s] >= float(G['spring_m3_s']):
            kind = 'spring'
        elif wet_near[s]:
            kind = 'wetland outlet'
        elif gw2[s] > 0.0:
            kind = 'seep or damp hollow'
        else:
            kind = 'gathered from seasonal rills'
        x, z = where(s)
        heads.append(dict(reach=k, pos=[x, round(float(h[s]), 2), z], kind=kind, lake=lk_d[0] if lk_d else None,
                          area_km2=r3(A[s] / 1e6), q_wet_m3_s=r3(Q['wet'][s]), groundwater_m3_s=r3(gw2[s])))
    # A full lake's outlet reach may start below a short dry gap (its exit cell's receiver is not yet a stream).
    for L, i in exits.items():
        if L in lake_outlet_reach:
            continue
        j = int(rec[i])
        while j >= 0 and not outlet[j] and not vis[j]:
            j = int(rec[j])
        if j >= 0 and not outlet[j] and vis[j]:
            lake_outlet_reach[L] = int(reach_of[j])
    # A reach into a full lake goes on through the lake's outlet reach, so the reader's `down` walk (water_record.gd downstream())
    # follows the water to the sea; -1 is the sea, a closed lake or a sink.
    for r in reaches:
        if r['ends'] == 'lake' and by_id.get(r['lake'], {}).get('full') and lake_outlet_reach.get(r['lake']) not in (None, r['id']):
            r['down'] = int(lake_outlet_reach[r['lake']])

    # 11. Outlets: to the sea and into lakes, with deltas where the sand supply beats the waves (Nienhuis et al. 2015).
    C = NW['coast']
    water = np.where(sea, -2, np.where(lake, lake_id, -1)).astype(np.int64)
    sea2 = sea.reshape(n, n)
    rad = int(round(float(C['estuary_radius_m']) / dx))
    tc = int(round(float(C['tidal_creek_m']) / dx))
    wl2 = wetland.reshape(n, n)
    outlets = []
    for k, rc_ in enumerate(reaches):
        if rc_['ends'] not in ('sea', 'lake'):
            continue
        m = reach_end_cell[k]
        r0, c0 = divmod(m, n)
        target = -2 if rc_['ends'] == 'sea' else int(rc_['lake'])
        fetch, opened = _fetch(r0, c0, water, target, n, dx, int(C['fetch_rays']), float(C['max_fetch_m']))
        Hs, Tp = waves(fetch, opened, C)
        q_wave = float(C['nienhuis_k']) * Hs ** 2.4 * Tp ** 0.2
        sand = float(sed_acc[m]) * float(C['rock_density_kg_m3']) * float(C['sand_share']) / YEAR_S
        R = sand / max(q_wave, 1e-12)
        s_mouth = max(float(slope[m]), 1e-4)
        o = dict(reach=k, pos=[where(m)[0], round(float(h[m]), 2), where(m)[1]], into=rc_['ends'], lake=rc_['lake'], area_km2=rc_['area_km2'],
                 q_mean_m3_s=rc_['q_m3_s']['mean'], fetch_m=None if opened else round(fetch), open_ocean=bool(opened),
                 wave_height_m=round(Hs, 2), wave_period_s=round(Tp, 2), sand_kg_s=r3(sand), waves_kg_s=r3(q_wave), R=r3(R))
        if R > 1.0:
            o['kind'] = 'Gilbert delta' if rc_['ends'] == 'lake' else 'delta'
            o['backwater_m'] = round(float(Dbf[m]) / s_mouth)
        elif rc_['ends'] == 'lake':
            o['kind'] = 'lake inflow'
        else:
            a0, a1, b0, b1 = max(r0 - rad, 0), min(r0 + rad + 1, n), max(c0 - rad, 0), min(c0 + rad + 1, n)
            yy, xx = np.ogrid[a0:a1, b0:b1]
            disk = (yy - r0) ** 2 + (xx - c0) ** 2 <= rad * rad
            sea_share = float(sea2[a0:a1, b0:b1][disk].mean())
            salt = bool((wl2[max(r0 - tc, 0):r0 + tc + 1, max(c0 - tc, 0):c0 + tc + 1] == 10).any())
            if salt:
                o['kind'] = 'tidal creek'
            elif sea_share < float(C['estuary_sea_share']):
                o['kind'] = 'estuary'
            elif sed[m] >= float(C['beach_sediment_m']) and s_mouth < float(C['beach_slope']):
                o['kind'] = 'beach-blocked mouth'
            else:
                o['kind'] = 'rocky outlet'
            o['sea_share_within_m'] = [round(float(C['estuary_radius_m'])), round(sea_share, 2)]
        outlets.append(o)
    outlet_of = {o['reach']: o for o in outlets}

    # Lakes with their reaches; springs
    lake_rows = []
    for lk in lakes:
        L = int(lk['id'])
        row = dict(lk)
        row['inflow_reaches'] = [r['id'] for r in reaches if r['ends'] == 'lake' and r['lake'] == L]
        row['outlet_reach'] = lake_outlet_reach.get(L)
        row['basin_component'] = None
        lake_rows.append(row)
    near_reach = maximum_filter(reach_of.reshape(n, n), size=5).ravel()
    springs = []
    for i in np.flatnonzero(gw >= float(G['spring_m3_s'])):
        x, z = where(i)
        row = dict(pos=[x, round(float(h[i]), 2), z], m3_s=r3(gw[i]), rock=names.get(int(rid[i]), str(int(rid[i]))),
                   feeds_reach=int(near_reach[i]) if near_reach[i] >= 0 else None)
        if st is not None:
            row.update(springstore.spring_row(st, ks, int(i), float(gw[i]), r3))
        else:
            row['q_base_dry_m3_s'] = r3(gw[i] * sea_sn['base_dry'])
        springs.append(row)

    # Destinations and the seven answers (principle 8)
    def destination(k, seen=None):
        seen = seen or set()
        path = []
        while k is not None and k not in seen:
            seen.add(k)
            r = reaches[k]
            path.append(k)
            if r['ends'] == 'reach':
                k = r['down']
            elif r['ends'] == 'lake':
                lk = by_id.get(r['lake'])
                nxt = lake_outlet_reach.get(r['lake'])
                if lk is not None and lk['full'] and nxt is not None:
                    k = nxt
                else:
                    return path, f"ends in closed lake {r['lake']} ({lk['cause'] if lk else 'unknown'}), where evaporation and seepage take its water"
            elif r['ends'] == 'sea':
                o = outlet_of.get(k)
                return path, f"reaches the sea at {r['polyline'][-1][0]:.0f}, {r['polyline'][-1][2]:.0f} as a {o['kind'] if o else 'mouth'}"
            else:
                return path, f"{r['ends']} at {r['polyline'][-1][0]:.0f}, {r['polyline'][-1][2]:.0f} (water lost to the bed)"
        return path, 'a loop in the reach list (a defect)'

    for r in reaches:
        last = reach_end_cell[r['id']]
        path, dest = destination(r['id'])
        st0 = r['stretches'][0]
        rk = names.get(int(rid[last]), '?')
        lakes_on = sorted({reaches[p]['lake'] for p in path if reaches[p]['ends'] == 'lake' and reaches[p]['lake'] is not None})
        ev = '; '.join(sorted({EVIDENCE.get(TYPES.index(s['type']), '') for s in r['stretches']} - {''}))
        if any(s['pattern'] == 'meandering' for s in r['stretches']):
            ev += '; point bars and cut banks on the bends'
        if any(s['pattern'] == 'braided' for s in r['stretches']):
            ev += '; bare gravel bars between several threads'
        if r['losing']:
            ev += '; a bed that dries in drought where it loses water to the ground'
        r['answers'] = {
            'supply': f"{r['area_km2']} km2 upstream; {round(100 * r['groundwater_share'])}% of its water comes through the ground",
            'why_here': ('its valley gathers enough wet-season flow to pass the island stream threshold '
                         f"({r3(q_vis)} m3/s), on the lowest line of the final ground"),
            'controls': (f"its bed ({st0['bed']}) on {rk}; it ends {'at a confluence' if r['ends'] == 'reach' else 'in ' + r['ends']}"
                         + (f" (lake {r['lake']})" if r['lake'] is not None else '')),
            'terrain': f"{rk}, {', '.join(sorted({s['type'] for s in r['stretches']}))}; {r['drop_m']} m drop over {r['length_m']} m",
            'storm_normal_drought': (f"bankfull {r['q_m3_s']['bankfull']}, wet season {r['q_m3_s']['wet']}, mean {r['q_m3_s']['mean']}, "
                                     f"dry season {r['q_m3_s']['dry']} m3/s; {', '.join(sorted({s['regime'] for s in r['stretches']}))}"),
            'evidence': ev,
            'connection': dest + (f"; through lakes {lakes_on}" if lakes_on else '') + f"; {len(path)} reaches to its end"}
    for f in falls:
        k = int(reach_of[f['lip']])
        f['reach'] = k
        f['answers'] = {'supply': f"the stream above it, {r3(A[f['lip']] / 1e6)} km2", 'why_here': f"{f['cause']} ({f['rock']} over {f['rock_below']})",
                        'controls': f"the {f['rock']} lip at {f['lip_y']} m", 'terrain': f"{f['height_m']} m {f['form']} over {f['length_m']} m",
                        'storm_normal_drought': f"bankfull {f['q_bankfull_m3_s']}, mean {f['q_mean_m3_s']} m3/s",
                        'evidence': 'a plunge pool and a gorge cut back below it' if f['form'] == 'plunge' else 'stepped rock and spray',
                        'connection': destination(k)[1] if k >= 0 else 'not on a reach (a defect)'}
        del f['lip'], f['foot']                                     # the 16 m cell indices; the record gives points
        f['lip'] = [f.pop('x'), f.pop('lip_y'), f.pop('z')]
        f['foot'] = [f.pop('foot_x'), f.pop('foot_y'), f.pop('foot_z')]
    for hd in heads:
        hd['answers'] = {'supply': f"{hd['area_km2']} km2 above it" + (f", {hd['groundwater_m3_s']} m3/s from the ground" if hd['groundwater_m3_s'] else ''),
                         'why_here': f"{hd['kind']}: the wet-season flow passes the stream threshold here",
                         'controls': 'the gullies and hollows above it' if hd['kind'] != 'lake outlet' else f"lake {hd['lake']}'s spill",
                         'terrain': names.get(int(rid[int(starts[hd['reach']])]), '?'),
                         'storm_normal_drought': f"wet season {hd['q_wet_m3_s']} m3/s; {reaches[hd['reach']]['stretches'][0]['regime']}",
                         'evidence': 'damp ground and rushes' if hd['kind'] in ('seep or damp hollow', 'spring') else 'a gully that runs in rain',
                         'connection': destination(hd['reach'])[1]}
    for o in outlets:
        o['answers'] = {'supply': f"{o['area_km2']} km2, mean {o['q_mean_m3_s']} m3/s, sand {o['sand_kg_s']} kg/s",
                        'why_here': f"its river meets the {'sea' if o['into'] == 'sea' else 'lake'} here",
                        'controls': f"waves of {o['wave_height_m']} m and {o['wave_period_s']} s carry {o['waves_kg_s']} kg/s (R = {o['R']})",
                        'terrain': o['kind'], 'storm_normal_drought': 'floods push sand and gravel out; calm seas let a bar build',
                        'evidence': {'delta': 'a lobe of sand with split channels', 'Gilbert delta': 'a flat sandy top and a steep front into the lake',
                                     'estuary': 'a long inlet with mud at its head', 'tidal creek': 'salt marsh and muddy creeks',
                                     'beach-blocked mouth': 'a beach bar the river breaks through in floods'}.get(o['kind'], 'bare rock at the mouth'),
                        'connection': 'the coast' if o['into'] == 'sea' else f"lake {o['lake']}"}

    # 12. Follow the water: contrasting basins, the main stem from its top to the sea.
    RP = NW['report']
    mouths = [(float(A[reach_end_cell[k]]), k) for k, r in enumerate(reaches) if r['ends'] == 'sea']
    mouths.sort(reverse=True)
    picked, rocks_seen = [], set()
    for _, k in mouths:
        m = reach_end_cell[k]
        stem = [m]
        while md[stem[-1]] >= 0:
            stem.append(int(md[stem[-1]]))
        dom = int(np.bincount(rid[np.array(stem)]).argmax())
        if not picked or dom not in rocks_seen:
            picked.append((k, stem[::-1], dom))
            rocks_seen.add(dom)
        if len(picked) >= int(RP['basins']):
            break
    for _, k in mouths:
        if len(picked) >= int(RP['basins']):
            break
        if k not in [p[0] for p in picked]:
            m = reach_end_cell[k]
            stem = [m]
            while md[stem[-1]] >= 0:
                stem.append(int(md[stem[-1]]))
            picked.append((k, stem[::-1], int(np.bincount(rid[np.array(stem)]).argmax())))
    report = []
    lines = ['# Follow the water', '', f"Stream threshold {r3(q_vis)} m3/s in the wet season; streams {round(float(step[vis].sum()) / 1000 / land_km2, 2)} km/km2.", '']
    for k, stem, dom in picked:
        events, dist, prev = [], 0.0, None
        lake_in, wet_in = None, None
        for idx, i in enumerate(stem):
            if idx:
                dist += float(step[stem[idx - 1]])
            x, z = where(i)
            base = dict(distance_m=round(dist), x=round(x), z=round(z), y=round(float(h[i]), 1), area_km2=r3(A[i] / 1e6), q_mean_m3_s=r3(Q['mean'][i]))
            if vis[i] and (idx == 0 or not vis[stem[idx - 1]]):
                kinds = [hd['kind'] for hd in heads if hd['reach'] == int(reach_of[i])]
                events.append(dict(base, what='stream begins', kind=kinds[0] if kinds else 'below a lake or a gap'))
            if vis[i]:
                key = (TYPES[rtype[i]], PATTERNS[pattern[i]], REGIMES[regime[i]])
                if key != prev:
                    events.append(dict(base, what='reach', type=key[0], pattern=key[1], regime=key[2], width_m=round(float(Wbf[i]), 1)))
                    prev = key
            if i in lip_at:
                f = falls[lip_at[i]]
                events.append(dict(base, what='fall', height_m=f['height_m'], form=f['form'], cause=f['cause']))
            L = int(lake_id[i]) if lake[i] else None
            if L != lake_in:
                if L is not None:
                    events.append(dict(base, what='lake', lake=L, cause=by_id[L]['cause'], level_m=round(float(by_id[L]['level_m']), 1)))
                lake_in = L
            wt = int(wetland[i]) if wetland[i] > 0 else None
            if wt != wet_in:
                if wt is not None:
                    events.append(dict(base, what='wetland', code=wt))
                wet_in = wt
            if gw2[i] >= float(G['spring_m3_s']) and vis[i]:
                events.append(dict(base, what='spring or seep', m3_s=r3(gw2[i])))
            if vis[i] and nvd[i] >= 2 and idx:
                trib = [float(A[d]) for d in dons[dcnt[i]:dcnt[i + 1]] if vis[d] and d != stem[idx - 1]]
                if trib:
                    events.append(dict(base, what='tributary joins', tributary_km2=r3(max(trib) / 1e6)))
        o = outlet_of.get(k)
        events.append(dict(distance_m=round(dist), what='outlet', kind=o['kind'] if o else 'sea', R=o['R'] if o else None))
        report.append(dict(reach=k, rock=names.get(dom, str(dom)), area_km2=reaches[k]['area_km2'], length_km=round(dist / 1000, 2), events=events))
        lines += [f"## Basin of reach {k}: {names.get(dom, dom)}, {reaches[k]['area_km2']} km2, main stem {round(dist / 1000, 2)} km", '',
                  '| km | y m | km2 | Q mean m3/s | what |', '|---|---|---|---|---|']
        for e in events:
            what = e['what'] + ''.join(f", {kk} {vv}" for kk, vv in e.items() if kk not in ('distance_m', 'x', 'z', 'y', 'area_km2', 'q_mean_m3_s', 'what'))
            lines.append(f"| {e['distance_m'] / 1000:.2f} | {e.get('y', '')} | {e.get('area_km2', '')} | {e.get('q_mean_m3_s', '')} | {what} |")
        lines.append('')

    # Never-see checks over the island
    km = lambda m: round(float(step[m].sum()) / 1000.0, 1)
    sea_deltas = [o for o in outlets if o['kind'] == 'delta']
    checks = dict(
        streams_running_uphill_cells=int((vis & (rec >= 0) & ~outlet[to] & (h[to] > h + 0.05) & ~lake[to]).sum()),
        heads_at_lakes_share=round(sum(1 for hd in heads if hd['kind'] == 'lake outlet') / max(len(heads), 1), 3),
        heads_by_kind={kk: sum(1 for hd in heads if hd['kind'] == kk) for kk in sorted({hd['kind'] for hd in heads})},
        waterfall_staircases=staircases[:20], waterfall_staircase_count=len(staircases),
        braided_km=km(braided), braided_below_treeline_km=km(braided & (h < treeline)),
        open_coast_deltas_under_500km2=sum(1 for o in sea_deltas if o['area_km2'] < 500.0 and (o['open_ocean'] or (o['fetch_m'] or 0) > 5000)),
        meanders_on_steep_reaches_km=km(meandering & (slope > RT['plane_bed'])),
        floodplains_on_steep_brooks_km=km(meandering & (slope > RT['plane_bed']) & (Wbf < 3.0)),
        streams_that_sink=[dict(reach=r['id'], x=r['polyline'][-1][0], z=r['polyline'][-1][2], rock=names.get(int(rid[reach_end_cell[r['id']]]), '?'))
                           for r in reaches if r['ends'] in ('sinks', 'leaves its channel')][:30],
        large_flow_from_small_area=[dict(x=hd['pos'][0], z=hd['pos'][2], area_km2=hd['area_km2'], q_wet_m3_s=hd['q_wet_m3_s']) for hd in heads
                                    if hd['area_km2'] < 0.05 and hd['q_wet_m3_s'] > 0.05][:20])
    by_type = {TYPES[t]: km(vis & (rtype == t)) for t in range(1, len(TYPES))}
    by_pattern = {PATTERNS[t]: km(vis & (pattern == t)) for t in range(1, len(PATTERNS))}
    hts = np.array([f['height_m'] for f in falls]) if falls else np.zeros(1)
    balance = dict(sources_m3_s=r3(src['mean'][land].sum()), to_sea_m3_s=r3(Q['mean'][land & (rec >= 0) & sea[to]].sum()),
                   into_closed_lakes_m3_s=r3(Q['mean'][land & ~closed & (rec >= 0) & closed[to]].sum()),
                   lake_losses_m3_s=r3(lost['mean'][list(exits.values())].sum() if exits else 0.0),
                   lost_to_the_bed_m3_s=r3(lost['mean'][losing].sum()))
    summary = dict(seconds=round(time.time() - t0, 1), land_km2=round(land_km2, 1), stream_threshold_wet_m3_s=r3(q_vis),
                   seasons={k: (r3(float(np.mean(v[land]))) if isinstance(v, np.ndarray) else r3(v)) for k, v in sea_sn.items() if not k.startswith('_')},
                   stores=_stores_summary(store_source, gw, base_wet, base_dry_share, sea_sn, float(SN['baseflow_recession_days']), springs, km(perennial),
                                          km(vis & (base_dry_island >= float(G['perennial_baseflow_m3_s']))), float(G['perennial_baseflow_m3_s'])),
                   density_km_per_km2=dict(streams=round(km(vis) / land_km2, 2), perennial=round(km(perennial) / land_km2, 2),
                                           intermittent=round(km(vis & ~perennial) / land_km2, 2), all_channels=round(km(channel) / land_km2, 2)),
                   r4_perennial_now_gullies_km=km(channel & ~vis & (r4reg == 1)),
                   reaches=len(reaches), heads=len(heads), confluences=len(confluences), highest_order=int(so.max()) if vis.any() else 0,
                   km_by_type=by_type, km_by_pattern=by_pattern,
                   falls=dict(count=len(falls), by_cause={c: sum(1 for f in falls if f['cause'] == c) for c in ('hard bed over softer rock', 'hanging valley lip')},
                              by_form={c: sum(1 for f in falls if f['form'] == c) for c in ('plunge', 'tiered', 'cascade fall')},
                              height_m=dict(p50=round(float(np.percentile(hts, 50)), 1), p90=round(float(np.percentile(hts, 90)), 1), max=round(float(hts.max()), 1)),
                              steep_steps_without_a_cause=unpinned),
                   outlets={kk: sum(1 for o in outlets if o['kind'] == kk) for kk in sorted({o['kind'] for o in outlets})},
                   largest_river=max(([r['q_m3_s']['mean'], r['area_km2'], r['width_m']['bottom']] for r in reaches if r['ends'] == 'sea'), default=None),
                   springs=len(springs), balance=balance)
    missing = ['snowmelt in the wet and dry seasons (A4 snow layer)', 'faults (not in the geology export), so no fault-pinned falls',
               'cave springs, karst sinks and LOD 2 passage sizes (item 10)', 'floodplain raster, levees and oxbows drawn (item 6)',
               'fan checks and terraces (item 9)', 'distributaries in deltas (item 11)', 'bank trees from the biome map (judged from the treeline)',
               'water lost to the bed not yet returned to the groundwater solve (R4)']

    network = dict(version=VERSION, cell_m=dx, origin_x=ox, origin_z=oz,
                   points=('every point is [x, y, z] in world metres, y up (pos, lip, foot); each reach polyline row is point_fields; '
                           'down is the next reach the water enters, through a full lake, -1 for none'),
                   point_fields=['x', 'bed_y', 'z', 'bankfull_width_m', 'bankfull_depth_m', 'q_mean_m3_s', 'q_wet_m3_s', 'q_dry_m3_s',
                                 'q_base_dry_m3_s'],
                   reaches=reaches, heads=heads, confluences=confluences, falls=falls, springs=springs, cave_springs=[],
                   coast_outlets=[o for o in outlets if o['into'] == 'sea'], lake_inflows=[o for o in outlets if o['into'] == 'lake'],
                   lakes=lake_rows, cold_air_pools=[])
    json.dump(network, open(f'{out_dir}/network.json', 'w'))
    R = lambda a, t=np.float32: np.asarray(a).reshape(n, n).astype(t)
    np.savez_compressed(f'{out_dir}/network.npz', stream=R(stream, np.uint8), reach_id=R(reach_of, np.int32), regime=R(regime, np.uint8),
                        q_mean_m3_s=R(np.where(land, Q['mean'], 0.0)), q_wet_m3_s=R(np.where(land, Q['wet'], 0.0)),
                        q_dry_m3_s=R(np.where(land, Q['dry'], 0.0)), q_base_dry_m3_s=R(np.where(land, base_dry, 0.0)), q_bankfull_m3_s=R(np.where(land, qbf, 0.0)),
                        width_m=R(np.where(vis, Wbf, 0.0)), depth_m=R(np.where(vis, Dbf, 0.0)),
                        width_mean_m=R(np.where(vis, at_flow(Q['mean'], Wbf, float(S3['at_station_width_exponent'])), 0.0)),
                        depth_mean_m=R(np.where(vis, at_flow(Q['mean'], Dbf, float(S3['at_station_depth_exponent'])), 0.0)),
                        reach_type=R(rtype, np.uint8), pattern=R(pattern, np.uint8), bed=R(bed, np.uint8), slope=R(slope),
                        valley_floor_m=R(floor), losing=R(losing, bool), ground=R(h), sea=R(sea, bool), lake=R(lake, bool),
                        cell_m=dx, origin_x=ox, origin_z=oz)
    hashes_out = dict(hashes)
    hashes_out['geology.json'] = record.sha(f'{geology_dir}/geology.json')
    manifest = dict(version=VERSION, network_sha=record.git_sha(), inputs=hashes_out,
                    outputs={'network.json': record.sha(f'{out_dir}/network.json'), 'network.npz': record.sha(f'{out_dir}/network.npz')},
                    codes=dict(stream='0 none, 3 river (perennial), 8 seasonal channel (intermittent)', reach_type=list(TYPES),
                               pattern=list(PATTERNS), bed=list(BEDS), regime=list(REGIMES)),
                    params=dict(network=NW, climate=climate), summary=summary, never_see=checks, missing=missing)
    json.dump(manifest, open(f'{out_dir}/network_manifest.json', 'w'), indent=1)
    json.dump(report, open(f'{out_dir}/follow_the_water.json', 'w'), indent=1)
    open(f'{out_dir}/follow_the_water.md', 'w').write('\n'.join(lines) + '\n')
    print(json.dumps(dict(summary=summary, never_see={k: v for k, v in checks.items() if not isinstance(v, list)}), indent=1))
    import plots
    plots.network_picture(f'{out_dir}/network.npz', f'{out_dir}/network.json', f'{out_dir}/network.png')


MT = meander_table()

if __name__ == '__main__':
    main()
