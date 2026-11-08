"""Unit tests for peaks.py (rule 6 peak checks) on small synthetic peaks: valley heads on a ring, a dome's flat cap against a
pyramid's, a cirque headwall on a profile, the retreat rates, and the glacial check end to end on files in a temporary
folder. They need numpy and scipy only (the landform's hollow count, which needs evolve.py and numba, is not tested here)
and take a few seconds.

Run on David4 or Dave's PC, never in the cloud:
  python tools/watershed/test_peaks.py        (or: python -m pytest tools/watershed/test_peaks.py)
"""
import os, sys, json, tempfile
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import peaks as pk    # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
P = json.load(open(os.path.join(HERE, 'params.json')))
Q = P['peaks']
DX = 16.0


def _grid(n):
    """Distance from the centre cell (m) and compass bearing (radians, 0 north = -row, pi/2 east = +col)."""
    c = n // 2
    rr, cc = np.mgrid[0:n, 0:n]
    return np.hypot(rr - c, cc - c) * DX, np.arctan2(cc - c, -(rr - c)), c


def _star(n=301, cone=0.5, valley=120.0):
    """A peak 1,500 m high falling at `cone`, with four valley heads at bearings 45, 135, 225 and 315 degrees, deepest
    `valley` m about 800 m out and nothing at the top or 1,600 m out."""
    r, b, c = _grid(n)
    hump = np.where(r < 1600.0, np.sin(np.pi * r / 1600.0) ** 2, 0.0)
    return 1500.0 - cone * r - valley * hump * (0.5 - 0.5 * np.cos(4.0 * b)), c


def test_ring_heads_four_valleys_through_noise():
    b = np.arange(0.0, 360.0, 2.0)
    t = np.radians(b)
    v = 100.0 * np.cos(4.0 * t) + 20.0 * np.cos(t) + 5.0 * np.sin(37.0 * t)
    heads = pk.ring_heads(v, b, 50.0)
    assert len(heads) == 4
    for hd, want in zip(sorted(heads, key=lambda x: x['bearing_deg']), (45.0, 135.0, 225.0, 315.0)):
        assert abs(hd['bearing_deg'] - want) <= 6.0 and hd['depth_m'] >= 150.0


def test_ring_heads_tilted_and_flat():
    b = np.arange(0.0, 360.0, 2.0)
    heads = pk.ring_heads(60.0 * np.cos(np.radians(b)), b, 50.0)
    assert len(heads) == 1 and heads[0]['bearing_deg'] == 180.0 and abs(heads[0]['depth_m'] - 120.0) < 1e-9
    assert pk.ring_heads(60.0 * np.cos(np.radians(b)), b, 200.0) == []
    assert pk.ring_heads(np.full(b.size, 5.0), b, 1.0) == []


def test_facing():
    assert pk.facing(45) == 'shady' and pk.facing(360) == 'shady' and pk.facing(225) == 'sunny' and pk.facing(135) == 'other'
    # south of the equator (the starter island, 57 S) the shady lee quarter is round the south-east
    assert pk.facing(135, 135.0) == 'shady' and pk.facing(170, 135.0) == 'shady' and pk.facing(315, 135.0) == 'sunny' and pk.facing(45, 135.0) == 'other'
    assert pk._compass(135.0) == 'SE' and pk._compass(315.0) == 'NW' and pk._compass(359.0) == 'N'
    assert pk._checks(P)['shady_bearing_deg'] == float(P['glacial']['shady_bearing_deg'])


def test_plateau_dome_and_pyramid():
    r, _, c = _grid(241)
    land = np.ones(r.shape, bool)
    dome = 1000.0 - r * r / 6000.0                      # radius of curvature 3 km: under 20 degrees out to about 1,090 m
    w = pk.plateau_m(dome, pk._slope_deg(dome, DX), land, c, c, 100.0, 20.0, DX)
    assert w > 1000.0                                   # the cap within 100 m of the top is about 1,550 m across
    pyramid = 1000.0 - 1.5 * r                          # 56-degree faces: only the top cell reads flat
    assert pk.plateau_m(pyramid, pk._slope_deg(pyramid, DX), land, c, c, 100.0, 20.0, DX) < 50.0


def test_headwall_on_a_cirque_profile():
    r, _, c = _grid(241)
    h = np.where(r < 400.0, 1000.0 - 0.2 * r, np.where(r < 520.0, 920.0 - 2.0 * (r - 400.0), 680.0 - 0.05 * (r - 520.0)))
    hw = pk.headwalls(h, pk._slope_deg(h, DX), c, c, [90.0], DX, Q)[0]
    assert 392.0 <= hw['headwall_m'] <= 408.0           # the wall's top edge, 400 m out
    assert abs(hw['depth_m'] - 264.0) < 2.0 and abs(hw['floor_m'] - 656.0) < 2.0   # 920 m less the floor 600 m beyond
    flat = pk.headwalls(1000.0 - 0.2 * r, pk._slope_deg(1000.0 - 0.2 * r, DX), c, c, [0.0], DX, Q)[0]
    assert flat['headwall_m'] is None and flat['depth_m'] is None


def test_summits_axes_and_shapes_on_a_star_peak():
    h, c = _star()
    sea = np.zeros(h.shape, bool)
    tops = pk.summits(h, sea, DX, 787.0)
    assert tops == [(c, c)]
    ax = pk.axes(h, sea, DX, tops, Q)
    assert sorted(round(b / 45.0) for b in ax[0]) == [1, 3, 5, 7]       # bearings 45, 135, 225, 315 (to the ring's 2 degrees)
    s = pk.shapes(h, h, sea, DX, 0.0, 0.0, tops, ax, Q)[0]
    assert s['heads_within_m'] == 4 and abs(s['top_change_m']) < 1e-9 and s['plateau_m'] < 50.0
    assert len(s['heads']['300']) == 0                  # 37 m deep at 300 m: under the 50 m a head needs
    assert abs(s['slope_near_top_deg'] - np.degrees(np.arctan(0.5))) < 6.0


def test_retreat_rates_and_depth_slowdown():
    def shape(headwall, depth):
        return [dict(x=0.0, z=0.0, headwalls=[dict(bearing_deg=45.0, facing='shady', headwall_m=headwall, depth_m=depth,
                                                    floor_m=None if depth is None else 700.0)])]
    series = [(0, 0.0, shape(None, None)), (1, 40000.0, shape(400.0, 150.0)), (3, 120000.0, shape(380.0, 180.0)),
              (10, 400000.0, shape(200.0, 200.0))]
    hd = pk.retreat(series, Q)[0]['heads'][0]
    assert abs(hd['rate_mm_yr'] - 1000.0 * 200.0 / 360000.0) < 1e-9
    assert abs(hd['depth_rate_early_mm_yr'] - 1.5) < 1e-9 and abs(hd['depth_rate_late_mm_yr'] - 1000.0 * 20.0 / 280000.0) < 1e-9
    assert hd['facing'] == 'shady' and hd['floor_m'] == 700.0


def test_snowline_and_history_years():
    G = dict(glacial=dict(ela_m=487.0, years=100000.0))
    assert pk.snowline(G) == 487.0 and pk._history_years(G) == [100000.0]
    H = dict(glacial=dict(ela_m=487.0, history=[dict(cycles=39, active_years=16400.0, ela_offset_m=150.0),
                                                 dict(cycles=10, active_years=40000.0, ela_offset_m=0.0)]))
    y = pk._history_years(H)
    assert pk.snowline(H) == 487.0 and len(y) == 49 and y[38] == 39 * 16400.0 and y[-1] == 39 * 16400.0 + 400000.0


def test_check_glacial_end_to_end():
    lf, _ = _star(cone=0.5)
    after, _ = _star(cone=1.2, valley=200.0)            # steeper faces, deeper heads, the same top
    sea = np.zeros(lf.shape, bool)
    with tempfile.TemporaryDirectory() as d:
        np.savez_compressed(f'{d}/inputs.npz', landform=lf.astype(np.float32), sea=sea, cell_m=DX, origin_x=0.0, origin_z=0.0)
        np.savez_compressed(f'{d}/glacial.npz', ground=after.astype(np.float32))
        json.dump(dict(params=dict(glacial=dict(ela_m=487.0, years=100000.0)), summary={}), open(f'{d}/glacial_manifest.json', 'w'))
        out = pk.check_glacial(d, d, P)
    res = {ln['line']: ln['result'] for ln in out['lines']}
    assert [res[k] for k in (4, 5, 6, 7)] == ['PASS'] * 4, out['lines']
    assert [res[k] for k in (8, 9, 10)] == ['N/A'] * 3, out['lines']   # one cold stage: no headwall stood before it


if __name__ == '__main__':
    tests = [v for k, v in sorted(globals().items()) if k.startswith('test_') and callable(v)]
    for t in tests:
        t()
        print('ok', t.__name__)
    print(f'{len(tests)} tests passed')
