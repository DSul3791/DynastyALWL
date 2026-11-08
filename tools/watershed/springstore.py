"""Each spring's own store (docs/water/spring_store_build_plan.md): the pure functions R4, R5 and R6 call.

- R4 (groundwater.py): the near-surface zones on tight rock (transmissivity and the specific yield at the water table),
  the groundwater catchments on R4's own head field, and each discharge block's stores: a diffuse store with Rorabaugh's
  response time tau = 4 S_y L^2 / (pi^2 T), and on cave-forming rock a conduit store and a matrix store in parallel.
- R5 (network.py): the wet- and dry-quarter shares of each store's outflow, from the island's recharge shape through a
  linear store of its own tau (one FFT per tau bin), so a reach's dry flow is the sum of its own springs' shares; each
  spring row's flow in each twelfth of the year, and the catchment's recharge and rain for the game's storm pulse.
- The game (docs/design/r7_plan.md section 4.1): drought_stores and storm_pulse are the reference sums its live springs
  follow.
- R6 (record.py): the springs that still run in the dry quarter, as fresh-water sources for fresh_m.

Numbers and sources are in params.json groundwater.near_surface, groundwater.specific_yield and groundwater.karst_stores
(Jamie's #686 and #713). Unit tests: test_springstore.py (numpy and scipy only; run on David4 or Dave's PC, never in the
cloud).
"""
import numpy as np

DAY_S = 86400.0
YEAR_DAYS = 365.25
YEAR_S = YEAR_DAYS * DAY_S


# ---------------------------------------------------------------------------------------------------------------------------
# R4: the layers

def tight_rock_mask(rid, names, NS):
    """True on cells whose rock is one of near_surface.rocks (the tight rocks, where the flow is in the broken top)."""
    tight_ids = [k for k, v in names.items() if v in set(NS['rocks'])]
    return np.isin(rid, tight_ids)


def near_surface_T(dcov, Kc, NS):
    """Transmissivity (m2/s) of loose cover dcov (m) at Kc (m/s) over the soil and the rock's near-surface zones: the soil
    and head make up whatever the cover leaves of soil.thickness_m, then zone after zone to its depth below the rock's top
    (GSI 2015 zones 1 to 3; Jamie's #713). The rock below the last zone adds nothing that counts."""
    soil = NS['soil']
    t = Kc * dcov + float(soil['k_m_day']) / DAY_S * np.maximum(float(soil['thickness_m']) - dcov, 0.0)
    top = 0.0
    for z in NS['zones']:
        t = t + float(z['k_m_day']) / DAY_S * (float(z['to_m']) - top)
        top = float(z['to_m'])
    return t


def sy_at_depth(depth, dcov, sy_cover, tight, sy_rock, NS):
    """The specific yield where the water table sits, at depth (m) below the ground: the loose cover's (sy_cover) within
    dcov; on tight rock then the soil's up to soil.thickness_m and each zone's to its depth below the rock's top, the last
    zone's below; elsewhere the rock's own (sy_rock). The table rises and falls there, so the column's mean would overstate
    the store (#713). All arguments are arrays of one shape (or scalars)."""
    depth = np.maximum(np.asarray(depth, float), 0.0)
    soil_m = float(NS['soil']['thickness_m'])
    rock_top = np.where(tight, np.maximum(dcov, soil_m), dcov)
    below = depth - rock_top
    sy_tight = np.full(np.broadcast(depth, dcov).shape, float(NS['zones'][-1]['sy']))
    for z in reversed(NS['zones']):
        sy_tight = np.where(below < float(z['to_m']), float(z['sy']), sy_tight)
    sy_tight = np.where(below < 0.0, float(NS['soil']['sy']), sy_tight)
    out = np.where(tight, sy_tight, sy_rock)
    return np.where(depth < dcov, sy_cover, out)


def sy_by_rock_id(names, SY):
    """Specific yield per rock id from groundwater.specific_yield (#686). An unlisted rock stops the run."""
    out = np.full(max(names) + 1, np.nan)
    missing = []
    for k, name in names.items():
        if name == 'air':
            continue
        if name not in SY:
            missing.append(name)
            continue
        out[k] = float(SY[name])
    if missing:
        raise SystemExit(f'springstore: no specific yield for rock(s) {sorted(set(missing))}; add them to params.json groundwater.specific_yield')
    return out


# ---------------------------------------------------------------------------------------------------------------------------
# R4: the groundwater catchments and their stores

_NB = ((-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1))


def catchments(H, ends, dx, own_share=0.5):
    """On a block grid of heads H: each block passes its water to its steepest-descent neighbour in H (the D8 rule the
    surface routing uses) until it reaches an end block (ends: discharge, sea or lake blocks). Returns, per block, the end
    block it reaches (flat index, -1 if none) and the flow distance to it (m), counting own_share of a block for the water
    born inside the end block itself and the walk between block centres for the rest. A block with no lower neighbour that
    is not an end keeps -1 (none in a converged solve: such a block would be a seepage face)."""
    nr, nc = H.shape
    N = nr * nc
    Hf = H.ravel()
    best = np.zeros(N)
    rec = np.full(N, -1, np.int64)
    idx = np.arange(N).reshape(nr, nc)
    for dr, dc in _NB:
        d = dx * (np.sqrt(2.0) if dr and dc else 1.0)
        a0, a1 = max(-dr, 0), nr - max(dr, 0)
        b0, b1 = max(-dc, 0), nc - max(dc, 0)
        src = idx[a0:a1, b0:b1].ravel()
        dst = idx[a0 + dr:a1 + dr, b0 + dc:b1 + dc].ravel()
        s = (Hf[src] - Hf[dst]) / d
        take = s > best[src]
        best[src[take]] = s[take]
        rec[src[take]] = dst[take]
    endf = ends.ravel()
    rec[endf] = -1
    end = np.where(endf, np.arange(N), -1)
    dist = np.where(endf, own_share * dx, 0.0)
    r_, c_ = np.divmod(np.arange(N), nc)
    for i in np.argsort(Hf, kind='stable'):                    # lowest first: every receiver is done before its donors
        j = rec[i]
        if j < 0:
            continue
        end[i] = end[j]
        dist[i] = dist[j] + dx * (np.sqrt(2.0) if (r_[i] != r_[j] and c_[i] != c_[j]) else 1.0)
    return end.reshape(nr, nc), np.where(end >= 0, dist, np.nan).reshape(nr, nc)


def rorabaugh_tau_days(sy, L, T):
    """Rorabaugh's (1960) slowest recession time of a strip aquifer of length L (m), transmissivity T (m2/s) and specific
    yield sy: 4 S_y L^2 / (pi^2 T), in days."""
    return 4.0 * np.asarray(sy, float) * np.asarray(L, float) ** 2 / (np.pi ** 2 * np.asarray(T, float)) / DAY_S


def stores(end, dist, T, sy, recharge, karst, KS, dx, rain=None):
    """The stores of every discharge block, from its groundwater catchment (blocks with end == it).
    The diffuse store: the catchment's blocks off cave-forming rock, recharge-weighted for the flow distance and S_y, and
    the harmonic mean for T (flow in series); L is twice the mean distance (a strip with even recharge has a mean of L/2).
    On cave-forming rock (karst) the recharge splits between conduits (conduit_share, conduit_tau_days: pipe flow, the
    measured time, not Rorabaugh's) and the matrix (Rorabaugh with matrix_sy, matrix_path_m to the nearest conduit and the
    matrix T = matrix_k_m_s x matrix_thickness_m).
    Returns a dict of block arrays (NaN where a block is not an end of anything): share and tau_days of the diffuse,
    conduit and matrix stores, the diffuse store's sy and flow_path_m (L), and catchment_m2, the whole groundwater
    catchment (karst blocks included), with that catchment's mean recharge_mm_yr and (from rain, mm/yr per block, when
    given) rain_mm_yr, which the game's storm pulse reads (docs/design/r7_plan.md section 4.1)."""
    shp = end.shape
    e = end.ravel()
    ok = e >= 0
    w = np.where(ok, np.maximum(recharge.ravel(), 0.0), 0.0)
    kf = karst.ravel().astype(bool)
    N = e.size
    ee = np.where(ok, e, 0)
    cnt = np.bincount(ee[ok], minlength=N).astype(float)
    tot = np.bincount(ee, weights=w, minlength=N)
    off = ok & ~kf
    w_off = np.where(off, w, 0.0)
    r_off = np.bincount(ee, weights=w_off, minlength=N)
    n_off = np.bincount(ee[off], minlength=N).astype(float)
    d_off = np.bincount(ee, weights=w_off * np.nan_to_num(dist.ravel()), minlength=N)
    s_off = np.bincount(ee, weights=w_off * sy.ravel(), minlength=N)
    inv_t = np.bincount(ee[off], weights=1.0 / np.maximum(T.ravel()[off], 1e-30), minlength=N)
    has = cnt > 0
    karst_share = np.where(tot > 0.0, 1.0 - r_off / np.maximum(tot, 1e-30), np.where(n_off > 0, 0.0, 1.0))
    L = np.where(r_off > 0.0, 2.0 * d_off / np.maximum(r_off, 1e-30), np.nan)
    sy_d = np.where(r_off > 0.0, s_off / np.maximum(r_off, 1e-30), np.nan)
    T_d = np.where(n_off > 0, n_off / np.maximum(inv_t, 1e-30), np.nan)
    tau_d = np.where(n_off > 0, rorabaugh_tau_days(np.nan_to_num(sy_d), np.nan_to_num(L), np.where(n_off > 0, T_d, 1.0)), np.nan)
    c = float(KS['conduit_share'])
    T_m = float(KS['matrix_k_m_s']) * float(KS['matrix_thickness_m'])
    tau_m = float(rorabaugh_tau_days(float(KS['matrix_sy']), float(KS['matrix_path_m']), T_m))
    nan = np.full(N, np.nan)
    out = dict(diffuse_share=np.where(has, 1.0 - karst_share, nan), diffuse_tau_days=np.where(has, tau_d, nan),
               conduit_share=np.where(has, c * karst_share, nan), conduit_tau_days=np.where(has, float(KS['conduit_tau_days']), nan),
               matrix_share=np.where(has, (1.0 - c) * karst_share, nan), matrix_tau_days=np.where(has, tau_m, nan),
               sy=np.where(has, sy_d, nan), flow_path_m=np.where(has, L, nan), catchment_m2=np.where(has, cnt * dx * dx, nan),
               recharge_mm_yr=np.where(has, tot / np.maximum(cnt, 1.0) * 1000.0 * YEAR_S, nan))
    if rain is None:
        out['rain_mm_yr'] = nan
    else:
        rr = np.bincount(ee[ok], weights=np.asarray(rain, float).ravel()[ok], minlength=N)
        out['rain_mm_yr'] = np.where(has, rr / np.maximum(cnt, 1.0), nan)
    return {k: v.reshape(shp) for k, v in out.items()}


STORE_KINDS = ('diffuse', 'conduit', 'matrix')
FIELDS = tuple(f'{k}_{v}' for k in STORE_KINDS for v in ('share', 'tau_days')) + ('sy', 'flow_path_m', 'catchment_m2', 'recharge_mm_yr', 'rain_mm_yr')
# R4 writes each as groundwater.npz gw_<field> at its discharge cells (NaN elsewhere); R5 reads them back.


# ---------------------------------------------------------------------------------------------------------------------------
# R5: season shares by store

def store_response(shape, tau_days):
    """The outflow of a linear store with time constant tau_days fed by recharge of the year's shape (one sample per
    1/S of a year, mean 1): the shape filtered harmonic by harmonic by 1 / (1 + 2 pi i k tau). Its mean stays 1 (the
    store keeps the water it is given), so mean flows never change with tau."""
    shape = np.asarray(shape, float)
    F = np.fft.rfft(shape)
    k = np.arange(F.size)
    return np.fft.irfft(F / (1.0 + 2j * np.pi * k * float(tau_days) / YEAR_DAYS), n=shape.size)


def quarter_shares(shape, wk, dk, tau_days):
    """(wet, dry): the store's mean outflow in the wet and the dry quarter over its year's mean."""
    r = store_response(shape, tau_days)
    return float(r[wk].mean()), float(r[dk].mean())


def month_means(shape, tau_days):
    """The store's outflow over its year's mean in each twelfth of the climate year, from phase 0 (the phase that
    record.climate's warmest_year_phase counts from): the mean of the response's samples that fall in each twelfth. The
    year's samples must be a multiple of 12, so every twelfth holds the same number and the twelve values average to 1."""
    r = store_response(shape, tau_days)
    S = r.size
    if S % 12:
        raise ValueError(f'springstore.month_means: {S} samples a year is not a multiple of 12')
    return r.reshape(12, S // 12).mean(axis=1)


def tau_bins(BN):
    """The tau grid the shares are read from: bins log-spaced from min_days to max_days."""
    return np.geomspace(float(BN['min_days']), float(BN['max_days']), int(BN['count']))


def shares_for(tau_days, shape, wk, dk, bins):
    """Wet and dry shares for an array of tau (days), interpolated in log tau between the bins' exact responses. Below the
    first bin the response is the shape itself to well under 0.1%, above the last it is flat to the same, so the ends are
    read from the end bins. NaN tau gives NaN."""
    wet_b = np.empty(bins.size)
    dry_b = np.empty(bins.size)
    for q, t in enumerate(bins):
        wet_b[q], dry_b[q] = quarter_shares(shape, wk, dk, t)
    lt = np.log(np.clip(np.asarray(tau_days, float), bins[0], bins[-1]))
    lb = np.log(bins)
    wet = np.interp(lt, lb, wet_b)
    dry = np.interp(lt, lb, dry_b)
    bad = ~np.isfinite(np.asarray(tau_days, float))
    return np.where(bad, np.nan, wet), np.where(bad, np.nan, dry)


def kind_shares(st, shape, wk, dk, bins):
    """Per store kind, the (wet, dry) quarter shares of that store's own outflow at every cell, from its tau."""
    return {kind: shares_for(st[f'{kind}_tau_days'], shape, wk, dk, bins) for kind in STORE_KINDS}


def cell_shares(st, ks):
    """Per cell, the wet and dry shares of its groundwater outflow: each store's share of the recharge times its own quarter
    shares (ks, from kind_shares), summed over the stores (st: dict of the R4 store arrays). NaN where the cell has no
    stores. Each store keeps the water it is given, so the year's mean share stays the sum of the shares, 1."""
    wet = np.zeros(np.shape(st['diffuse_share']))
    dry = np.zeros_like(wet)
    any_ = np.zeros(wet.shape, bool)
    for kind in STORE_KINDS:
        s = np.asarray(st[f'{kind}_share'], float)
        w, d = ks[kind]
        use = np.isfinite(s) & (s > 0.0) & np.isfinite(w)
        wet = wet + np.where(use, s * np.nan_to_num(w), 0.0)
        dry = dry + np.where(use, s * np.nan_to_num(d), 0.0)
        any_ |= use
    return np.where(any_, wet, np.nan), np.where(any_, dry, np.nan)


# ---------------------------------------------------------------------------------------------------------------------------
# R5: the reaches' flow in each twelfth and their store bands (docs/design/spring_to_river_flow.md section 2)

def month_bins(shape, bins):
    """(bins, 12): month_means at each tau bin, the table month_share_at reads between."""
    return np.array([month_means(shape, t) for t in bins])


def month_share_at(tau_days, mb, bins, m):
    """Twelfth m's share of a store's outflow over its year's mean, for an array of tau (days): read in log tau between the
    bins' exact month_means (mb, from month_bins), as shares_for reads the quarters. NaN tau gives NaN."""
    tau = np.asarray(tau_days, float)
    good = np.isfinite(tau)
    lt = np.log(np.clip(np.where(good, tau, bins[0]), bins[0], bins[-1]))
    return np.where(good, np.interp(lt, np.log(bins), mb[:, m]), np.nan)


def cell_month_share(st, mb, bins, m):
    """Per cell, twelfth m's share of its groundwater outflow over its year's mean: each store's share of the recharge times
    its own month share, summed over the stores (cell_shares for one twelfth; st: the store arrays, already taken at the
    cells wanted). NaN where the cell has no stores. Over the twelve twelfths it averages the sum of the shares, 1."""
    out = np.zeros(np.shape(st['diffuse_share']))
    any_ = np.zeros(out.shape, bool)
    for kind in STORE_KINDS:
        s = np.asarray(st[f'{kind}_share'], float)
        v = month_share_at(st[f'{kind}_tau_days'], mb, bins, m)
        use = np.isfinite(s) & (s > 0.0) & np.isfinite(v)
        out = out + np.where(use, s * np.nan_to_num(v), 0.0)
        any_ |= use
    return np.where(any_, out, np.nan)


def store_bands(BD):
    """The tau band edges (days) that a reach's base_stores rows group the stores into: per_decade bands a decade on exact
    decade fractions from min_days, the last ending at or above max_days (network.season.store_bands)."""
    lo, hi, pd = np.log10(float(BD['min_days'])), np.log10(float(BD['max_days'])), float(BD['per_decade'])
    nb = max(int(np.ceil((hi - lo) * pd - 1e-9)), 1)
    return 10.0 ** (lo + np.arange(nb + 1) / pd)


def band_of(tau_days, edges):
    """Band index of each tau (days); tau beyond the ends goes in the first or last band, NaN gives -1."""
    tau = np.asarray(tau_days, float)
    good = np.isfinite(tau)
    b = np.clip(np.searchsorted(edges, np.where(good, tau, edges[0]), side='right') - 1, 0, edges.size - 2)
    return np.where(good, b, -1)


def _band_split(st, q, edges):
    """For each store kind with a share: (its flow q share, its tau, its band) at each cell."""
    q = np.asarray(q, float)
    for kind in STORE_KINDS:
        s = np.asarray(st[f'{kind}_share'], float)
        tau = np.asarray(st[f'{kind}_tau_days'], float)
        use = np.isfinite(s) & (s > 0.0) & np.isfinite(tau)
        if use.any():
            yield np.where(use, q * np.nan_to_num(s), 0.0), tau, np.where(use, band_of(tau, edges), -1)


def band_means(st, q, edges):
    """The groundwater q (m3/s) put out at each cell, split by tau band: {band: (mean flow, mean flow times ln tau)} at each
    cell, the sources R5 sums down the network for a reach's base_stores rows (the second sums to the band's flow-weighted
    geometric-mean tau). Bands no store falls in are left out. Over the bands the flows sum to q times the stores' shares."""
    out = {}
    for f, tau, b in _band_split(st, q, edges):
        for band in np.unique(b[b >= 0]):
            w = b == band
            a = np.where(w, f, 0.0)
            ln = np.where(w, f * np.log(np.where(w, tau, 1.0)), 0.0)
            if int(band) in out:
                out[int(band)] = (out[int(band)][0] + a, out[int(band)][1] + ln)
            else:
                out[int(band)] = (a, ln)
    return out


def band_month(st, q, edges, mb, bins, m):
    """As band_means, each band's flow in twelfth m at each cell: {band: q share month_share_at(tau)}, summed exactly from each
    cell's own stores, so over the bands it is q times cell_month_share."""
    out = {}
    for f, tau, b in _band_split(st, q, edges):
        v = f * np.nan_to_num(month_share_at(tau, mb, bins, m))
        for band in np.unique(b[b >= 0]):
            a = np.where(b == band, v, 0.0)
            out[int(band)] = out[int(band)] + a if int(band) in out else a
    return out


def spring_row(st, ks, i, q, rnd, shape=None):
    """The store keys of the spring row at flat cell i with mean outflow q (m3/s), rounded by rnd:
    - stores: [kind, share of the recharge, tau_days, its dry-quarter flow m3/s] for each store with a share, and with the
      year's recharge shape given, a fifth item: that store's mean flow in each twelfth of the year (12 values, m3/s);
    - q_base_dry_m3_s: their dry flows summed, the dry quarter's mean;
    - q_month_m3_s (with the shape): the stores' twelfths summed, the flow the game puts in through the year;
    - tau_days: the tau of the store that gives most of the dry flow (the matrix on karst), for a one-store drought reader;
      the exact drought is the sum of each store's flow at the spell's start times exp(-t / its tau) (drought_stores);
    - karst_share, the diffuse store's sy and flow_path_m (L), and catchment_km2, the whole groundwater catchment;
    - recharge_mm_yr and rain_mm_yr, the catchment's means, which size the game's storm pulse (storm_pulse)."""
    rows = []
    for kind in STORE_KINDS:
        s = float(st[f'{kind}_share'][i])
        if np.isfinite(s) and s > 0.0:
            tau = float(st[f'{kind}_tau_days'][i])
            rows.append([kind, round(s, 3), rnd(tau), q * s * float(ks[kind][1][i]),
                         None if shape is None else q * s * month_means(shape, tau)])
    out = dict(q_base_dry_m3_s=rnd(sum(r[3] for r in rows)), tau_days=max(rows, key=lambda r: r[3])[2] if rows else None,
               karst_share=round(1.0 - float(np.nan_to_num(st['diffuse_share'][i])), 3) if rows else None)
    if shape is not None and rows:
        out['q_month_m3_s'] = [rnd(v) for v in np.sum([r[4] for r in rows], axis=0)]
    for k, scale, name in (('sy', 1.0, 'sy'), ('flow_path_m', 1.0, 'flow_path_m'), ('catchment_m2', 1e-6, 'catchment_km2'),
                           ('recharge_mm_yr', 1.0, 'recharge_mm_yr'), ('rain_mm_yr', 1.0, 'rain_mm_yr')):
        v = float(st[k][i]) if k in st else np.nan
        out[name] = rnd(v * scale) if np.isfinite(v) else None
    out['stores'] = [[r[0], r[1], r[2], rnd(r[3])] + ([] if r[4] is None else [[rnd(v) for v in r[4]]]) for r in rows]
    return out


def drought(q_base_dry, tau_days, t_days):
    """Flow t_days into a rain-free spell from a store giving q_base_dry at its start: q exp(-t / tau)."""
    return np.maximum(np.asarray(q_base_dry, float), 0.0) * np.exp(-np.asarray(t_days, float) / np.asarray(tau_days, float))


def drought_stores(q_start, tau_days, t_days):
    """A spring's flow t_days into a rain-free spell: each store falls on its own from its flow at the spell's start,
    sum over the stores of q_start_k exp(-t / tau_k) (q_start and tau_days: one value per store)."""
    q = np.maximum(np.asarray(q_start, float), 0.0)
    tau = np.asarray(tau_days, float)
    t = np.asarray(t_days, float)
    return (q[:, None] * np.exp(-t.reshape(1, -1) / tau[:, None])).sum(axis=0).reshape(t.shape)


def storm_pulse(q_mean, share, tau_days, storm_recharge_mm, recharge_mm_yr, t_days):
    """The extra outflow (m3/s) of one store t_days after a storm, on top of its usual flow: the storm's recharge as a
    share of the year's, times the store's year of outflow, released at the store's own tau:
    q_mean share (storm_recharge / mean daily recharge) / tau exp(-t / tau). Its volume is q_mean share YEAR_S
    storm_recharge / recharge_mm_yr, so the year's mean is unchanged when the storm is part of the year's rain. The
    storm's recharge is its rain times recharge_mm_yr / rain_mm_yr (the spring row's catchment means)."""
    daily = float(recharge_mm_yr) / YEAR_DAYS
    tau = float(tau_days)
    t = np.asarray(t_days, float)
    return float(q_mean) * float(share) * (float(storm_recharge_mm) / daily) / tau * np.exp(-t / tau)


# ---------------------------------------------------------------------------------------------------------------------------
# R6: springs as fresh water

def spring_sources(springs, ox, oz, spacing, m, min_q):
    """A boolean m x m mask with the nearest sample of each spring row whose q_base_dry_m3_s is at least min_q: the springs
    that still run in the dry quarter, as fresh-water sources. Rows outside the window, or without the key, mark nothing."""
    mask = np.zeros((m, m), bool)
    for s in springs:
        q = s.get('q_base_dry_m3_s')
        if q is None or float(q) < float(min_q):
            continue
        i = int(round((float(s['pos'][0]) - ox) / spacing))
        j = int(round((float(s['pos'][2]) - oz) / spacing))
        if 0 <= i < m and 0 <= j < m:
            mask[j, i] = True
    return mask
