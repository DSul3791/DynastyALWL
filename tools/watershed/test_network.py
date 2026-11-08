"""Unit tests for network.py (R5) on tiny synthetic grids: the tree walks, the flows with losses, the sizes of meanders,
waves and seasons, and the twelfths (quick runoff by twelfth and the reaches' report on them). They need numpy, scipy and numba, as the watershed tools do, and take a few seconds (numba compiles).

Run on David4 or Dave's PC, never in the cloud:
  python tools/watershed/test_network.py        (or: python -m pytest tools/watershed/test_network.py)
"""
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import network as nw    # noqa: E402

COAST = dict(wind_stress_m_s=10.0)


def _chain():
    """Cell 0 is sea; cells 1 to 5 drain one into the next toward it (5 -> 4 -> 3 -> 2 -> 1 -> sea)."""
    rec = np.array([-1, 0, 1, 2, 3, 4], np.int64)
    outlet = np.array([True, False, False, False, False, False])
    return rec, outlet


def test_order_downstream_first():
    rec, outlet = _chain()
    order, cnt, don = nw._order(rec, outlet)
    assert list(order) == [1, 2, 3, 4, 5]
    assert list(don[cnt[1]:cnt[2]]) == [2]


def test_flow_and_loss():
    rec, outlet = _chain()
    order, _, _ = nw._order(rec, outlet)
    src = np.array([0.0, 1, 1, 1, 1, 1])
    Q, lost = nw._flow(order, rec, outlet, src, np.zeros(6))
    assert np.allclose(Q[1:], [5, 4, 3, 2, 1]) and not lost.any()
    cap = np.zeros(6)
    cap[3] = 1.5                                   # 3 arrives at cell 3 (2 from above, 1 its own); 1.5 is lost there
    Q, lost = nw._flow(order, rec, outlet, src, cap)
    assert np.isclose(lost[3], 1.5) and np.isclose(Q[3], 1.5) and np.isclose(Q[1], 3.5)
    cap[4] = 10.0                                  # a cap above the flow takes all of it, never more
    Q, lost = nw._flow(order, rec, outlet, src, cap)
    assert np.isclose(lost[4], 2.0) and np.isclose(Q[4], 0.0) and (Q >= 0).all()


def test_accumulate_keeps_sign():
    rec, outlet = _chain()
    order, _, _ = nw._order(rec, outlet)
    acc = nw._accumulate(order, rec, outlet, np.array([0.0, 1, 1, -3, 1, 1]))
    assert np.isclose(acc[1], 1.0) and np.isclose(acc[3], -1.0)


def test_main_donor_and_strahler():
    # A Y: heads 3 and 4 join at 2, which drains through 1 to the sea at 0; 4 drains more area than 3.
    rec = np.array([-1, 0, 1, 2, 2], np.int64)
    outlet = np.array([True, False, False, False, False])
    order, _, _ = nw._order(rec, outlet)
    A = np.array([0.0, 10, 9, 3, 5])
    md = nw._main_donor(order, rec, outlet, A)
    assert md[2] == 4 and md[1] == 2 and md[3] == -1
    so = nw._strahler(order, rec, outlet, np.ones(5, bool))
    assert so[3] == 1 and so[4] == 1 and so[2] == 2 and so[1] == 2


def test_window_slope_on_a_straight_bed():
    n, dx = 1, 16.0                                # one row: column index = cell; every step is dx
    rec, outlet = _chain()
    order, _, _ = nw._order(rec, outlet)
    h = np.array([0.0, 1.6, 3.2, 4.8, 6.4, 8.0])   # slope 0.1
    md = nw._main_donor(order, rec, outlet, np.array([0.0, 5, 4, 3, 2, 1]))
    s = nw._window_slope(np.array([3], np.int64), h, rec, md, outlet, np.array([32.0]), np.array([32.0]), n, dx)
    assert abs(s[0] - 0.1) < 1e-9


def test_floor_width_of_a_trough():
    n, dx = 21, 16.0
    rows = np.arange(n)[:, None] * np.ones((1, n))
    h = (np.abs(rows - 10) * 5.0).ravel()          # a trough along x, walls rising 5 m a cell
    rec = np.full(n * n, -1, np.int64)
    for c in range(1, n):
        rec[10 * n + c] = 10 * n + c - 1           # the bed drains toward column 0
    sea = np.zeros(n * n, bool)
    w = nw._floor_width(np.array([10 * n + 10], np.int64), h, rec, sea, np.array([7.0]), 2000.0, 3, n, dx)
    assert 30.0 <= w[0] <= 50.0                    # the bed row and one row either side lie within 7 m of the bed


def test_fetch_open_and_closed():
    n, dx = 40, 16.0
    water = np.full(n * n, -1, np.int64)
    water[:20 * n] = -2                            # sea over the top half, reaching the window's edge
    best, opened = nw._fetch(20, 20, water, -2, n, dx, 16, 60000.0)
    assert opened and best > 0
    lake = np.full(n * n, -1, np.int64)
    lake[(np.arange(n * n) // n >= 21) & (np.arange(n * n) // n <= 25)] = 7   # a lake band, 5 cells wide, inside the window
    best, opened = nw._fetch(20, 20, lake, 7, n, dx, 16, 60000.0)
    assert not opened and 0 < best < n * dx


def test_waves_match_the_knowledge_page():
    Hs, Tp = nw.waves(0.0, True, COAST)
    assert abs(Hs - 0.2433 * 100 / 9.81) < 1e-9 and abs(Tp - 8.134 * 10 / 9.81) < 1e-9
    Hs, Tp = nw.waves(2000.0, False, COAST)
    q = 90.0 * Hs ** 2.4 * Tp ** 0.2
    assert 1.5 < q < 5.0                           # #599: about 2 kg/s at 2 km of fetch
    Hs, Tp = nw.waves(50000.0, False, COAST)
    q = 90.0 * Hs ** 2.4 * Tp ** 0.2
    assert 60.0 < q < 250.0                        # #599: about 100 kg/s at 50 km


def test_meanders():
    T = nw.MT
    assert abs(T['sinuosity'][0] - 1.0) < 1e-3
    assert (np.diff(T['amp_over_lambda']) > 0).all() and (np.diff(T['radius_over_lambda'][T['omega'] <= 1.2]) < 0).all()
    M = dict(wavelength_widths=11.0, wavelength_widths_cohesive=8.0, wavelength_widths_loose=13.0, amplitude_coefficient=2.7,
             amplitude_exponent=1.1, min_bend_radius_widths=2.0, riffle_spacing_widths=6.0)
    m = nw.meander(10.0, M, T, False, False)
    assert m['wavelength_m'] == 110.0 and m['sinuosity'] > 1.05 and m['amplitude_m'] > 0
    k = int(np.argmin(np.abs(T['sinuosity'] - m['sinuosity'])))
    assert T['radius_over_lambda'][k] * m['wavelength_m'] >= 2.0 * 10.0 - 1.0   # the tightest bend stays 2 widths or more
    assert nw.meander(10.0, M, T, True, False)['wavelength_m'] == 80.0


def test_seasons():
    rain = np.full(100, 1200.0)
    et = np.full(100, 450.0)
    SN = dict(samples=24, rain_swing_share=0.33, rain_wettest_year_phase=0.8, et_swing_share=0.9, baseflow_recession_days=45.0)
    s = nw.seasons(rain, et, np.ones(100, bool), SN, 0.375)
    assert (s['quick_wet'] > 1.0).all() and (s['quick_dry'] < 1.0).all() and (s['quick_dry'] >= 0.0).all()
    assert s['base_dry'] < 1.0 < s['base_wet']
    assert s['base_wet'] - s['base_dry'] < s['quick_wet'][0] - s['quick_dry'][0]   # the store evens the baseflow out
    assert s['evap_dry'] > s['evap_wet']


def test_main_keeps_the_stores_name():
    """main() reads the spring stores as `st` when it writes the spring rows, long after it builds the reaches, so nothing in
    between may reuse the name (a stretch dict once did, which would have stopped the spring rows on the PC)."""
    import ast
    tree = ast.parse(open(nw.__file__).read())
    main = next(f for f in tree.body if isinstance(f, ast.FunctionDef) and f.name == 'main')
    stores = [x.lineno for x in ast.walk(main) if isinstance(x, ast.Name) and x.id == 'st' and isinstance(x.ctx, ast.Store)]
    assert len(stores) == 2, stores        # the stores from groundwater.npz, or None for an R4 run without them

def test_quick_month_and_twelfths():
    rain = np.array([1200.0, 1700.0, 300.0, 0.0])
    et = np.array([450.0, 458.0, 450.0, 450.0])
    SN = dict(samples=24, rain_swing_share=0.33, rain_wettest_year_phase=0.8, et_swing_share=0.9, baseflow_recession_days=45.0)
    s = nw.seasons(rain, et, np.ones(4, bool), SN, 0.375)
    qm = np.array([nw.quick_month(rain, et, s, m) for m in range(12)])
    assert np.allclose(qm[:, :3].mean(axis=0), 1.0, rtol=0.0, atol=1e-12)     # the twelfths keep the year's quick runoff
    assert (qm[:, 3] == 1.0).all()                                            # nothing left over all year: 1, as the quarters
    dm, wm = nw.twelfths_in(s['_dk']), nw.twelfths_in(s['_wk'])
    assert dm == [2, 3, 4] and wm == [8, 9, 10]                               # around the rain's low (0.3) and peak (0.8)
    assert np.allclose(qm[dm].mean(axis=0), s['quick_dry'], rtol=0.0, atol=1e-12)
    assert np.allclose(qm[wm].mean(axis=0), s['quick_wet'], rtol=0.0, atol=1e-12)
    assert int(np.argmin(qm[:, 1])) in (3, 4)                                 # driest between the rain's low and the warmest phase


def test_months_summary():
    qm = np.zeros((12, 3))
    qm[:, 0], qm[:, 1], qm[:, 2] = 2e-3, 1.05e-3, 3e-3
    qm[5, 2] = 1e-3
    qbm = np.zeros((12, 3))
    qbm[:, 0], qbm[:, 1], qbm[:, 2] = 1e-3, 0.5e-3, 2e-3
    qbm[5, 2] = 0.5e-3
    before = qbm.copy()
    bands = {3: 0.4 * before, 6: 0.6 * before}
    q_mean = np.array([2e-3, 1e-3, qm[:, 2].mean()])
    q_dry = np.array([2e-3, 1e-3, 3e-3])
    q_wet = np.array([2e-3, 1e-3, 3e-3])
    base_dry = np.array([1e-3, 0.5e-3, 1.5e-3])
    lost_up = np.array([0.0, 1e-4, 0.0])                                       # reach 1 loses water upstream
    area = np.array([[1e6, 1e6, 0.1e6], [0.0, 0.1e6, 1e6]])
    out = nw._months_summary(qm, qbm, before, bands, q_mean, q_wet, q_dry, base_dry, lost_up, [8, 9, 10], [2, 3, 4], 1e-3,
                             np.array([1000.0, 1200.0, 2500.0]), ['granite', 'chalk'], area)
    assert out['dry_quarter_twelfths'] == [3, 4, 5] and out['wet_quarter_twelfths'] == [9, 10, 11]
    assert out['reaches_flowing'] == 3 and out['reaches_without_losses'] == 2 and out['bands_used'] == 2
    assert out['months_keep_the_mean']['without_losses'] < 1e-12 and abs(out['months_keep_the_mean']['with_losses'] - 0.05) < 1e-9
    assert abs(out['months_agree_with_quarters']['dry_all'] - 0.05) < 1e-9 and out['months_agree_with_quarters']['dry_without_losses'] < 1e-12
    assert out['bands_sum_to_the_base_flow'] < 1e-12
    assert out['driest_twelfth_under_perennial'] == dict(reaches=1, km=2.5)    # reach 2: dry quarter 2 L/s, its driest twelfth 0.5
    g, c = out['by_rock']['granite'], out['by_rock']['chalk']
    assert g['reaches'] == 2 and g['base_flow_index_median'] == 0.488 and g['driest_twelfth_base_share_median'] == 0.488
    assert c['reaches'] == 1 and c['base_flow_index_median'] == 0.662 and c['driest_twelfth_base_share_median'] == 0.5

if __name__ == '__main__':
    tests = [v for k, v in sorted(globals().items()) if k.startswith('test_') and callable(v)]
    for t in tests:
        t()
        print('ok', t.__name__)
    print(f'{len(tests)} tests passed')
