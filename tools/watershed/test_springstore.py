"""Unit tests for springstore.py (each spring's own store; docs/water/spring_store_build_plan.md section 8): the near-surface
transmissivity and the specific yield at the water table on tight rock, the groundwater catchments on a block grid, Rorabaugh's
response time on a strip, karst's two stores, the store response and its tau bins, the drought recession, the params against
Jamie's #713 recession times, and the springs that count as fresh water. They use small synthetic arrays and the repo's
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


if __name__ == '__main__':
    tests = [v for k, v in sorted(globals().items()) if k.startswith('test_') and callable(v)]
    for t in tests:
        t()
        print('ok', t.__name__)
    print(f'{len(tests)} tests passed')
