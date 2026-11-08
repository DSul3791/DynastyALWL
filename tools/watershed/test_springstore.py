"""Unit tests for springstore.py (each spring's own store; docs/water/spring_store_build_plan.md section 8): the near-surface
transmissivity and the specific yield at the water table on tight rock, the groundwater catchments on a block grid, Rorabaugh's
response time on a strip, karst's two stores, the store response and its tau bins, the drought recession, the params against
Jamie's #713 recession times, and the springs that count as fresh water, and the game's spring sums (flow by month, a drought over the stores, a storm's
pulse; docs/design/r7_plan.md section 4.1), and R5's twelfths and store bands for the reaches (docs/design/spring_to_river_flow.md). They use small synthetic arrays and the repo's
params.json, read no run files, need numpy only, and take a second or two.

Run on David4 or Dave's PC, never in the cloud:
  python tools/watershed/test_springstore.py        (or: python -m pytest tools/watershed/test_springstore.py)
"""
import os, sys, json
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import springstore as ss    # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
P = json.load(open(os.path.join(HERE, 'params.json')))
G = P['groundwater']
NS, SY, KS = G['near_surface'], G['specific_yield'], G['karst_stores']
DAY = 86400.0
DXC = 64.0
KC = 10.0 ** -G['log10_k_m2_negated']['coarse unconsolidated'] * 7.5e6      # coarse cover, m/s (as groundwater.py)


def _r3(v):
    return float(f'{float(v):.3g}')


def _year(S=24, phw=0.8, amp=0.8):
    """A cosine recharge shape over S samples (mean 1, peak at phase phw) and the wet and dry quarter masks, built the way
    network.seasons builds them."""
    t = (np.arange(S) + 0.5) / S

    def quarter(c):
        return np.abs((t - c + 0.5) % 1.0 - 0.5) <= 0.125 + 1e-9
    return 1.0 + amp * np.cos(2.0 * np.pi * (t - phw)), quarter(phw), quarter(phw + 0.5), t


def _strip(T, karst=None, sy=0.01, cols=8):
    """One row of `cols` blocks falling east, the east block discharging: (end, dist) and the stores."""
    H = (100.0 - np.arange(cols, dtype=float))[None, :]
    ends = np.zeros((1, cols), bool)
    ends[0, -1] = True
    end, dist = ss.catchments(H, ends, DXC, float(G['own_block_path_share']))
    T = np.broadcast_to(np.asarray(T, float), (1, cols))
    k = np.zeros((1, cols), bool) if karst is None else np.asarray(karst, bool).reshape(1, cols)
    st = ss.stores(end, dist, T, np.full((1, cols), sy), np.full((1, cols), 1e-9), k, KS, DXC)
    return end, dist, st


def test_tight_rock_transmissivity():
    names = {0: 'air', 1: 'granite', 2: 'slate', 3: 'basalt', 4: 'shale', 5: 'coal', 6: 'sandstone', 7: 'chalk', 8: 'limestone', 9: 'sediment'}
    mask = ss.tight_rock_mask(np.arange(10), names, NS)
    assert mask.tolist() == [False, True, True, True, True, True, False, False, False, False]
    # no cover: soil 1 m x 0.3 + zone 1 2 m x 0.1 + zone 2 13 m x 0.01 + zone 3 85 m x 0.001 m/day
    assert abs(ss.near_surface_T(0.0, KC, NS) * DAY - 0.715) < 1e-9
    # 3 m of coarse cover: the soil zone is gone, the cover's K x 3 m is added, the zones are measured from the rock's top
    assert abs(ss.near_surface_T(3.0, KC, NS) * DAY - (KC * 3.0 * DAY + 0.415)) < 1e-9
    # half a metre of cover: the soil makes up the other half metre
    assert abs(ss.near_surface_T(0.5, KC, NS) * DAY - (KC * 0.5 * DAY + 0.15 + 0.415)) < 1e-9
    # sandstone is not tight, so groundwater.py keeps Gleeson's K x (50 m - cover) there (mask above)


def test_sy_at_the_table():
    depths = np.array([0.5, 2.0, 10.0, 50.0, 150.0])
    got = ss.sy_at_depth(depths, 0.0, 0.22, True, 0.002, NS)
    assert np.allclose(got, [0.05, 0.02, 0.005, 0.002, 0.002], rtol=0.0, atol=1e-12)
    # under 3 m of coarse cover a table at 1 m sits in the cover; at 4 m it is 1 m into the rock (zone 1)
    assert np.allclose(ss.sy_at_depth(np.array([1.0, 4.0]), 3.0, 0.22, True, 0.002, NS), [0.22, 0.02], rtol=0.0, atol=1e-12)
    # sandstone: the cover's, then the rock's own #686 value
    assert np.allclose(ss.sy_at_depth(np.array([1.0, 10.0]), 3.0, 0.22, False, float(SY['sandstone']), NS), [0.22, 0.08], rtol=0.0, atol=1e-12)


def test_sy_by_rock_id():
    names = {i: v for i, v in enumerate(['air'] + list(G['rock_class']))}
    sy = ss.sy_by_rock_id(names, SY)
    assert np.isnan(sy[0]) and np.isfinite(sy[1:]).all()
    assert sy[[k for k, v in names.items() if v == 'chalk'][0]] == 0.01
    try:
        ss.sy_by_rock_id({0: 'air', 1: 'unobtainium'}, SY)
    except SystemExit:
        pass
    else:
        raise AssertionError('an unlisted rock must stop the run')


def test_catchments_on_a_plane():
    n = 6
    H = np.tile(100.0 - np.arange(n, dtype=float), (n, 1))
    ends = np.zeros((n, n), bool)
    ends[:, -1] = True
    end, dist = ss.catchments(H, ends, DXC, 0.5)
    rows = np.arange(n)[:, None]
    assert (end == rows * n + (n - 1)).all()
    assert np.allclose(dist, (n - 1 - np.arange(n))[None, :] * DXC + 0.5 * DXC)


def test_catchments_on_a_mound():
    n = 6
    rr, cc = np.mgrid[0:n, 0:n]
    H = 100.0 - np.hypot(rr - 2.5, cc - 2.5)
    ends = np.zeros((n, n), bool)
    ends[0, :] = ends[-1, :] = ends[:, 0] = ends[:, -1] = True
    end, dist = ss.catchments(H, ends, DXC, 0.5)
    assert (end >= 0).all()                                     # none left out
    er, ec = np.divmod(end, n)
    assert ends[er, ec].all()                                   # every block ends at an edge
    assert (H.ravel()[end.ravel()] <= H.ravel() + 1e-12).all()  # downhill of it
    assert np.allclose(dist[ends], 0.5 * DXC) and (dist[~ends] >= 1.5 * DXC - 1e-9).all()


def test_rorabaugh_strip():
    T0 = 1e-5
    end, dist, st = _strip(T0)
    assert np.isnan(st['diffuse_share'][0, :-1]).all()          # only the discharge block has stores
    L = 2.0 * float(np.mean(dist))                              # (7 + ... + 0) / 8 blocks + half a block = 4 blocks
    assert abs(L - 8 * DXC) < 1e-9 and abs(st['flow_path_m'][0, -1] - L) < 1e-9
    want = 4.0 * 0.01 * L ** 2 / (np.pi ** 2 * T0) / DAY
    assert abs(st['diffuse_tau_days'][0, -1] - want) < 1e-9 * want
    assert st['diffuse_share'][0, -1] == 1.0 and st['conduit_share'][0, -1] == 0.0 and st['matrix_share'][0, -1] == 0.0
    assert abs(st['catchment_m2'][0, -1] - 8 * DXC * DXC) < 1e-6 and abs(st['sy'][0, -1] - 0.01) < 1e-12
    # two halves in series: the harmonic mean of T
    T1, T2 = 1e-5, 4e-5
    _, _, st2 = _strip(np.array([T1] * 4 + [T2] * 4))
    Th = 2.0 / (1.0 / T1 + 1.0 / T2)
    assert abs(st2['diffuse_tau_days'][0, -1] - 4.0 * 0.01 * L ** 2 / (np.pi ** 2 * Th) / DAY) < 1e-9 * want


def test_karst_two_stores():
    _, _, st = _strip(1e-5, karst=[True] * 8)
    tau_m = 4.0 * KS['matrix_sy'] * KS['matrix_path_m'] ** 2 / (np.pi ** 2 * KS['matrix_k_m_s'] * KS['matrix_thickness_m']) / DAY
    assert 250.0 < tau_m < 256.0                                # about 253 days
    assert st['diffuse_share'][0, -1] == 0.0 and np.isnan(st['diffuse_tau_days'][0, -1])
    assert abs(st['conduit_share'][0, -1] - 0.55) < 1e-12 and st['conduit_tau_days'][0, -1] == 5.0
    assert abs(st['matrix_share'][0, -1] - 0.45) < 1e-12 and abs(st['matrix_tau_days'][0, -1] - tau_m) < 1e-9 * tau_m
    # half the recharge on karst
    _, _, sh = _strip(1e-5, karst=[True] * 4 + [False] * 4)
    got = [sh[f'{k}_share'][0, -1] for k in ss.STORE_KINDS]
    assert np.allclose(got, [0.5, 0.275, 0.225], rtol=0.0, atol=1e-12)
    # the diffuse store there is the off-karst half: L from those blocks only (distances 3.5 .. 0.5 blocks, mean 2)
    assert abs(sh['flow_path_m'][0, -1] - 4.0 * DXC) < 1e-9


def _exact_cosine(t, wk, dk, phw, amp, tau_days):
    """The store's sampled response to 1 + amp cos(2 pi (t - phw)), worked by hand: 1 + amp (cos th + b sin th) / (1 + b^2),
    b = 2 pi tau / year. Its wet and dry quarter means."""
    b = 2.0 * np.pi * tau_days / ss.YEAR_DAYS
    th = 2.0 * np.pi * (t - phw)
    r = 1.0 + amp * (np.cos(th) + b * np.sin(th)) / (1.0 + b * b)
    return float(r[wk].mean()), float(r[dk].mean())


def test_store_response_limits():
    shape, wk, dk, t = _year()
    clipped = np.maximum(1.5 * np.cos(2.0 * np.pi * (t - 0.8)) + 0.3, 0.0)
    clipped = clipped / clipped.mean()
    for tau in (0.0, 0.1, 5.0, 45.0, 365.25, 36525.0):           # the store keeps the water: the mean stays 1
        assert abs(ss.store_response(shape, tau).mean() - 1.0) < 1e-12
        assert abs(ss.store_response(clipped, tau).mean() - 1.0) < 1e-12
    w0, d0 = ss.quarter_shares(clipped, wk, dk, 0.0)             # no store: the recharge's own quarter means
    assert abs(w0 - clipped[wk].mean()) < 1e-12 and abs(d0 - clipped[dk].mean()) < 1e-12
    w, d = ss.quarter_shares(shape, wk, dk, 36525.0)             # 100 years: flat to 0.5% of the mean flow
    assert abs(w - 1.0) < 0.005 and abs(d - 1.0) < 0.005
    # 45 days, the old island store (network.seasons uses quarter_shares for it): matches the response worked by hand
    w, d = ss.quarter_shares(shape, wk, dk, 45.0)
    ew, ed = _exact_cosine(t, wk, dk, 0.8, 0.8, 45.0)
    assert abs(w - ew) < 1e-12 and abs(d - ed) < 1e-12 and d < 1.0 < w


def test_bins_interpolate():
    shape, wk, dk, t = _year()
    bins = ss.tau_bins(P['network']['season']['tau_bins'])
    assert bins.size == 48 and abs(bins[0] - 0.1) < 1e-12 and abs(bins[-1] - 36525.0) < 1e-6
    rng = np.random.default_rng(7)
    taus = np.exp(rng.uniform(np.log(0.1), np.log(36525.0), 200))
    w, d = ss.shares_for(taus, shape, wk, dk, bins)
    exact = np.array([_exact_cosine(t, wk, dk, 0.8, 0.8, x) for x in taus])
    # within 0.5% of the year's mean flow (the shares are over that mean); log-linear between bins 1.31 apart in tau
    assert np.abs(w - exact[:, 0]).max() < 0.005 and np.abs(d - exact[:, 1]).max() < 0.005
    wn, dn = ss.shares_for(np.array([np.nan, 1e-3, 1e7]), shape, wk, dk, bins)
    assert np.isnan(wn[0]) and np.isnan(dn[0]) and np.isfinite(wn[1:]).all()   # outside the bins: the end bins


def test_cell_shares_and_spring_row():
    shape, wk, dk, t = _year()
    bins = ss.tau_bins(P['network']['season']['tau_bins'])
    nan = np.nan
    st = dict(diffuse_share=np.array([1.0, 0.0, nan]), diffuse_tau_days=np.array([400.0, nan, nan]),
              conduit_share=np.array([0.0, 0.55, nan]), conduit_tau_days=np.array([5.0, 5.0, nan]),
              matrix_share=np.array([0.0, 0.45, nan]), matrix_tau_days=np.array([253.0, 253.0, nan]),
              sy=np.array([0.02, nan, nan]), flow_path_m=np.array([200.0, nan, nan]), catchment_m2=np.array([4.1e5, 8.2e5, nan]))
    ks = ss.kind_shares(st, shape, wk, dk, bins)
    wet, dry = ss.cell_shares(st, ks)
    d400 = ss.shares_for(np.array([400.0]), shape, wk, dk, bins)[1][0]
    d5, d253 = (ss.shares_for(np.array([x]), shape, wk, dk, bins)[1][0] for x in (5.0, 253.0))
    assert abs(dry[0] - d400) < 1e-12 and abs(dry[1] - (0.55 * d5 + 0.45 * d253)) < 1e-12 and np.isnan(dry[2])
    assert d5 < d253 < d400 <= 1.0 + 1e-9                          # a slow store keeps more for the dry quarter
    row = ss.spring_row(st, ks, 1, 0.002, _r3)
    assert [r[0] for r in row['stores']] == ['conduit', 'matrix'] and row['tau_days'] == 253.0 and row['karst_share'] == 1.0
    assert abs(row['q_base_dry_m3_s'] - _r3(0.002 * (0.55 * d5 + 0.45 * d253))) < 1e-12
    assert row['sy'] is None and row['flow_path_m'] is None and abs(row['catchment_km2'] - 0.82) < 1e-12
    r0 = ss.spring_row(st, ks, 0, 0.001, _r3)
    assert r0['stores'][0][:3] == ['diffuse', 1.0, 400.0] and r0['karst_share'] == 0.0 and r0['flow_path_m'] == 200.0


def test_drought_recession():
    q, tau = 2e-3, 30.0
    assert abs(ss.drought(q, tau, 0.0) - q) < 1e-15
    assert abs(ss.drought(q, tau, tau) - q / np.e) < 1e-15
    days = np.arange(0.0, 200.0, 5.0)
    f = ss.drought(q, tau, days)
    assert (np.diff(f) < 0.0).all() and (f > 0.0).all()
    assert ss.drought(-1e-4, tau, 5.0) == 0.0                     # never negative


def test_params_give_713_times():
    T = ss.near_surface_T(0.0, 0.0, NS)                          # bare tight rock, m2/s
    sy1 = float(NS['zones'][0]['sy'])                             # a hillside table in zone 1
    year = ss.YEAR_DAYS
    t50, t200 = (float(ss.rorabaugh_tau_days(sy1, L, T)) for L in (50.0, 200.0))
    assert 14.0 <= t50 <= year / 4.0, t50                         # 2 weeks to 3 months (about 28 days)
    assert year / 2.0 <= t200 <= 2.0 * year, t200                 # 6 months to 2 years (about 450 days)
    tm = float(ss.rorabaugh_tau_days(KS['matrix_sy'], KS['matrix_path_m'], KS['matrix_k_m_s'] * KS['matrix_thickness_m']))
    assert year / 4.0 <= tm <= 2.0 * year, tm                     # karst matrix: 3 months to 2 years (about 253 days)
    assert 2.0 <= float(KS['conduit_tau_days']) <= 10.0
    for x in (t50, t200, tm, float(KS['conduit_tau_days'])):      # nothing reads hours or millennia
        assert 1.0 < x < 1000.0 * year


def test_fresh_spring_sources():
    ox = oz = 1000.0
    sp = 8.0
    min_q = float(P['record']['fresh_spring_min_m3_s'])
    springs = [dict(pos=[ox + 3 * sp, 50.0, oz + 7 * sp], q_base_dry_m3_s=2e-5),
               dict(pos=[ox + 10 * sp + 2.0, 50.0, oz + 12 * sp - 3.0], q_base_dry_m3_s=5e-6),
               dict(pos=[ox + 25 * sp, 0.0, oz], q_base_dry_m3_s=1e-3),
               dict(pos=[ox + 5 * sp, 40.0, oz + 5 * sp], m3_s=1e-3)]
    mask = ss.spring_sources(springs, ox, oz, sp, 20, min_q)
    assert mask.shape == (20, 20) and int(mask.sum()) == 1 and mask[7, 3]



def test_stores_recharge_and_rain():
    end, dist, st = _strip(1e-5)
    assert set(st) == set(ss.FIELDS)
    assert abs(st['recharge_mm_yr'][0, -1] - 1e-9 * 1000.0 * ss.YEAR_S) < 1e-9 and np.isnan(st['rain_mm_yr'][0, -1])
    cols = end.shape[1]
    st2 = ss.stores(end, dist, np.full((1, cols), 1e-5), np.full((1, cols), 0.01), np.full((1, cols), 1e-9), np.zeros((1, cols), bool),
                    KS, DXC, rain=np.linspace(1000.0, 1700.0, cols)[None, :])
    assert abs(st2['rain_mm_yr'][0, -1] - 1350.0) < 1e-9 and np.isnan(st2['rain_mm_yr'][0, 0])


def test_month_means():
    shape, wk, dk, t = _year()
    for tau in (0.0, 5.0, 45.0, 253.0, 36525.0):
        m = ss.month_means(shape, tau)
        assert m.shape == (12,) and abs(m.mean() - 1.0) < 1e-12        # the store keeps the water: the twelfths average 1
    assert np.allclose(ss.month_means(shape, 0.0), shape.reshape(12, 2).mean(axis=1), rtol=0.0, atol=1e-12)
    assert np.abs(ss.month_means(shape, 36525.0) - 1.0).max() < 0.005
    fast, slow = ss.month_means(shape, 5.0), ss.month_means(shape, 120.0)
    assert int(np.argmax(fast)) == 9 and int(np.argmax(slow)) == 11     # the recharge peaks at phase 0.8; 120 days lags it
    assert np.ptp(slow) < 0.5 * np.ptp(fast)                            # and evens it out
    try:
        ss.month_means(np.ones(10), 5.0)
    except ValueError:
        pass
    else:
        raise AssertionError('a year of 10 samples has no equal twelfths')


def test_spring_row_months_and_storm_fields():
    shape, wk, dk, t = _year()
    bins = ss.tau_bins(P['network']['season']['tau_bins'])
    nan = np.nan
    st = dict(diffuse_share=np.array([nan, 0.0]), diffuse_tau_days=np.array([nan, nan]),
              conduit_share=np.array([nan, 0.55]), conduit_tau_days=np.array([nan, 5.0]),
              matrix_share=np.array([nan, 0.45]), matrix_tau_days=np.array([nan, 253.0]),
              sy=np.array([nan, nan]), flow_path_m=np.array([nan, nan]), catchment_m2=np.array([nan, 8.2e5]),
              recharge_mm_yr=np.array([nan, 900.0]), rain_mm_yr=np.array([nan, 1500.0]))
    ks = ss.kind_shares(st, shape, wk, dk, bins)
    row = ss.spring_row(st, ks, 1, 0.002, _r3, shape)
    qm = np.array(row['q_month_m3_s'])
    assert qm.size == 12 and abs(qm.mean() / 0.002 - 1.0) < 3e-3     # the twelfths average the mean flow (to 3 figures)
    conduit, matrix = row['stores']
    assert conduit[0] == 'conduit' and matrix[0] == 'matrix' and len(conduit[4]) == 12 and len(matrix[4]) == 12
    assert np.allclose(np.array(conduit[4]) + np.array(matrix[4]), qm, rtol=0.01, atol=0.0)   # each rounded to 3 figures
    assert np.ptp(matrix[4]) < 0.25 * np.ptp(conduit[4])                # the matrix carries the dry months
    assert row['recharge_mm_yr'] == 900.0 and row['rain_mm_yr'] == 1500.0 and abs(row['catchment_km2'] - 0.82) < 1e-12
    assert 'q_month_m3_s' not in ss.spring_row(st, ks, 1, 0.002, _r3)    # no shape, no months


def test_drought_stores():
    t = np.array([0.0, 10.0, 60.0])
    f = ss.drought_stores([1e-3, 2e-3], [5.0, 250.0], t)
    assert np.allclose(f, [ss.drought(1e-3, 5.0, x) + ss.drought(2e-3, 250.0, x) for x in t], rtol=1e-12, atol=0.0)
    assert abs(f[0] - 3e-3) < 1e-15
    assert ss.drought_stores([1e-3], [5.0], 14.0) < 0.1 * 1e-3          # a karst conduit is gone in two weeks
    assert ss.drought_stores([2e-3], [250.0], 30.0) > 0.85 * 2e-3       # its matrix holds through a dry month


def test_storm_pulse_volume_and_shape():
    q, R = 2e-3, 900.0
    storm = 30.0 * 0.9                                                   # 30 mm of rain at a recharge share of 0.9
    tau = 5.0
    tt = np.linspace(0.0, 60.0 * tau, 600001)
    p = ss.storm_pulse(q, 0.55, tau, storm, R, tt)
    vol = float(((p[1:] + p[:-1]) * 0.5 * np.diff(tt)).sum()) * ss.DAY_S
    want = q * 0.55 * ss.YEAR_S * storm / R                              # the storm's share of the store's year of outflow
    assert abs(vol / want - 1.0) < 1e-6
    assert abs(p[0] / (q * 0.55 * storm / (R / ss.YEAR_DAYS) / tau) - 1.0) < 1e-12 and (np.diff(p) < 0.0).all()
    # r7_plan section 5: a karst spring a week after the storm runs under twice its usual flow
    week = q + ss.storm_pulse(q, 0.55, 5.0, storm, R, 7.0) + ss.storm_pulse(q, 0.45, 253.0, storm, R, 7.0)
    assert q < week < 2.0 * q
    # and a chalk or gravel spring (one store of months) rises less than 20% on the first day
    assert ss.storm_pulse(q, 1.0, 120.0, storm, R, 0.0) < 0.2 * q


# R5: the reaches' twelfths and store bands (docs/design/spring_to_river_flow.md section 2)

def _three_cells():
    nan = np.nan
    return dict(diffuse_share=np.array([1.0, 0.0, nan, 0.5]), diffuse_tau_days=np.array([453.0, nan, nan, 28.0]),
                conduit_share=np.array([0.0, 0.55, nan, 0.25]), conduit_tau_days=np.array([5.0, 5.0, nan, 5.0]),
                matrix_share=np.array([0.0, 0.45, nan, 0.25]), matrix_tau_days=np.array([253.0, 253.0, nan, 253.0]))


def test_month_share_at_reads_the_bins():
    shape, wk, dk, t = _year()
    bins = ss.tau_bins(P['network']['season']['tau_bins'])
    mb = ss.month_bins(shape, bins)
    assert mb.shape == (48, 12) and np.allclose(mb.mean(axis=1), 1.0, rtol=0.0, atol=1e-12)
    for m in (0, 4, 10):
        assert np.allclose(ss.month_share_at(bins, mb, bins, m), mb[:, m], rtol=0.0, atol=1e-12)   # exact at the bins
    rng = np.random.default_rng(11)
    taus = np.exp(rng.uniform(np.log(0.1), np.log(36525.0), 100))
    got = np.array([ss.month_share_at(taus, mb, bins, m) for m in range(12)])
    exact = np.array([ss.month_means(shape, x) for x in taus]).T
    assert np.abs(got - exact).max() < 0.005                                   # as the quarters (test_bins_interpolate)
    assert np.allclose(got.mean(axis=0), 1.0, rtol=0.0, atol=1e-12)             # the twelfths still average 1
    v = ss.month_share_at(np.array([np.nan, 1e-3, 1e7]), mb, bins, 3)
    assert np.isnan(v[0]) and np.isfinite(v[1:]).all()


def test_cell_month_share():
    shape, wk, dk, t = _year()
    bins = ss.tau_bins(P['network']['season']['tau_bins'])
    mb = ss.month_bins(shape, bins)
    st = _three_cells()
    cm = np.array([ss.cell_month_share(st, mb, bins, m) for m in range(12)])
    assert np.isnan(cm[:, 2]).all() and np.isfinite(cm[:, [0, 1, 3]]).all()
    assert np.allclose(cm[:, [0, 1, 3]].mean(axis=0), 1.0, rtol=0.0, atol=1e-12)
    want = 0.55 * ss.month_means(shape, 5.0) + 0.45 * ss.month_means(shape, 253.0)
    assert np.abs(cm[:, 1] - want).max() < 0.005
    # the dry quarter's twelfths average the cell's dry share, the wet quarter's its wet share
    wet, dry = ss.cell_shares(st, ss.kind_shares(st, shape, wk, dk, bins))
    dm = [m for m in range(12) if dk[2 * m:2 * m + 2].all()]
    wm = [m for m in range(12) if wk[2 * m:2 * m + 2].all()]
    assert len(dm) == 3 and len(wm) == 3
    assert np.allclose(cm[dm][:, [0, 1, 3]].mean(axis=0), dry[[0, 1, 3]], rtol=0.0, atol=1e-12)
    assert np.allclose(cm[wm][:, [0, 1, 3]].mean(axis=0), wet[[0, 1, 3]], rtol=0.0, atol=1e-12)


def test_store_bands():
    edges = ss.store_bands(P['network']['season']['store_bands'])
    assert abs(edges[0] - 0.1) < 1e-12 and edges[-1] >= 36525.0 and edges[-2] < 36525.0
    assert np.allclose(edges[1:] / edges[:-1], np.sqrt(10.0), rtol=1e-12, atol=0.0)    # two a decade
    assert edges.size - 1 == 12
    b = ss.band_of(np.array([0.01, 0.1, 5.0, 253.0, 453.0, 36525.0, 1e7, np.nan]), edges)
    assert list(b) == [0, 0, 3, 6, 7, 11, 11, -1]


def test_band_sums():
    shape, wk, dk, t = _year()
    bins = ss.tau_bins(P['network']['season']['tau_bins'])
    mb = ss.month_bins(shape, bins)
    edges = ss.store_bands(P['network']['season']['store_bands'])
    st = _three_cells()
    q = np.array([2e-3, 2e-3, 0.0, 1e-3])
    means = ss.band_means(st, q, edges)
    assert sorted(means) == [3, 4, 6, 7]                    # 5, 28, 253 and 453 days
    tot = np.sum([v[0] for v in means.values()], axis=0)
    assert np.allclose(tot, [2e-3, 2e-3, 0.0, 1e-3], rtol=1e-12, atol=0.0)
    q6, ln6 = means[6]
    q7, ln7 = means[7]
    assert abs(q6[1] - 0.45 * 2e-3) < 1e-15 and abs(np.exp(ln6[1] / q6[1]) - 253.0) < 1e-9 and q6[0] == 0.0
    assert abs(np.exp(ln6[3] / q6[3]) - 253.0) < 1e-9 and abs(np.exp(ln7[0] / q7[0]) - 453.0) < 1e-9
    months = [ss.band_month(st, q, edges, mb, bins, m) for m in range(12)]
    for m in range(12):
        assert sorted(months[m]) == [3, 4, 6, 7]
        summed = np.sum(list(months[m].values()), axis=0)
        assert np.allclose(summed, q * np.nan_to_num(ss.cell_month_share(st, mb, bins, m)), rtol=1e-12, atol=1e-18)
    for band in means:                                      # each band's twelfths average its mean flow
        year = np.mean([months[m][band] for m in range(12)], axis=0)
        assert np.allclose(year, means[band][0], rtol=1e-12, atol=1e-18)
    assert np.ptp([months[m][3][1] for m in range(12)]) > 3.0 * np.ptp([months[m][6][1] for m in range(12)])   # conduits swing, the matrix holds

if __name__ == '__main__':
    tests = [v for k, v in sorted(globals().items()) if k.startswith('test_') and callable(v)]
    for t in tests:
        t()
        print('ok', t.__name__)
    print(f'{len(tests)} tests passed')
