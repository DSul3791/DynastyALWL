"""Unit tests for record.py's river carving (R6 item 3) and drainage area on tiny synthetic grids: a straight river to the sea, a
tributary joining it, a narrow brook left alone, and a reach that sinks. They need numpy, scipy and numba, as the watershed tools do,
and take a few seconds (numba compiles).

Run on David4 or Dave's PC, never in the cloud:
  python tools/watershed/test_record_rivers.py        (or: python -m pytest tools/watershed/test_record_rivers.py)
"""
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import record as rc    # noqa: E402

CV = dict(carve_min_width_m=8.0, bank_angle_deg_by_bed=[35.0, 45.0, 40.0, 35.0, 30.0, 25.0, 30.0], bank_extra_m=10.0, end_taper_points=3)
N16 = 21                     # 16 m cells; the 8 m grid is 2 * 21 - 1 = 41 samples
M = 2 * N16 - 1


def _net(width=12.0, depth=1.2, depth_mean=0.6, regime=1):
    full = lambda v: np.full((N16, N16), v, np.float32)
    return dict(width_m=full(width), depth_m=full(depth), depth_mean_m=full(depth_mean), bed=np.full((N16, N16), 3, np.uint8),
                regime=np.full((N16, N16), regime, np.uint8))


def _reach(rid, cells, ends, down=-1, lake=None, bed_y=None):
    """cells: (column, row) 16 m cells from the head; bed_y the polyline's bed_y per cell (default 10 m falling 0.1 m a cell)."""
    ys = bed_y if bed_y is not None else [10.0 - 0.1 * k for k in range(len(cells))]
    pl = [[16.0 * c, y, 16.0 * r, 12.0, 1.2, 1.0, 1.5, 0.5, 0.4] for (c, r), y in zip(cells, ys)]
    return dict(id=rid, down=down, ends=ends, lake=lake, area_km2=5.0, polyline=pl)


def _carve(network, net, g):
    segs, _ = rc.carve_rivers(network, net, 0.0, 0.0, M, {}, CV)
    cut = np.full(M * M, np.inf, np.float32)
    best_r = np.full(M * M, np.inf, np.float32)
    best_s = np.full(M * M, -1, np.int64)
    best_t = np.zeros(M * M, np.float32)
    rc._carve(segs, M, 0.0, 0.0, rc.SPACING, cut, best_r, best_s, best_t)
    keep = g > 0.0
    lower = (cut.reshape(M, M) < g) & keep
    g2 = np.where(lower, cut.reshape(M, M).astype(np.float64), g)
    code, level = rc.river_water(segs, best_s.reshape(M, M), best_t.reshape(M, M), best_r.reshape(M, M), g2, keep)
    return segs, g2, code, level


def test_straight_river_to_the_sea():
    """A river along row 10 from column 18 to the sea at column 0: the bed sits a bankfull depth under the bank top at the
    centre, the water a mean-flow depth over the bed, the level never rises downstream and reaches the sea at 0 or above."""
    g = np.full((M, M), 10.0)
    g[:, 0:2] = -2.0                                       # the sea down the west edge
    net = _net()
    reach = _reach(0, [(c, 10) for c in range(18, 0, -1)], 'sea')
    segs, g2, code, level = _carve(dict(reaches=[reach]), net, g)
    assert segs.shape[0] > 0
    row = 20                                                # 8 m row of 16 m row 10
    bank = np.minimum.accumulate(np.array([10.0 - 0.1 * k for k in range(18)]))
    j = 2 * 9                                               # 16 m column 9 is point 9 of the polyline
    assert abs(g2[row, j] - (bank[9] - 1.2)) < 1e-4, g2[row, j]
    assert code[row, j] == rc.RIVER
    assert abs(level[row, j] - (bank[9] - 1.2 + 0.6)) < 1e-4
    wet = np.isfinite(level[row, 4:36])
    lv = level[row, 4:36][wet]
    assert np.all(np.diff(lv) >= -1e-6), 'level rises downstream (toward lower columns)'
    assert lv.min() >= 0.0
    # the banks: a sample 16 m to the side stands higher than the bed, and the ground far off is untouched
    assert g2[row + 2, j] > g2[row, j]
    assert g2[row + 10, j] == 10.0


def test_tributary_meets_the_river_at_its_level():
    """A tributary down column 10 joins the main river at row 10: its last level is at or above the main river's there, and its
    trench reaches the main channel (no ground left between them higher than both levels)."""
    g = np.full((M, M), 10.0)
    g[:, 0:2] = -2.0
    net = _net()
    # Reaches run between confluences (network.py), so the main river is two reaches and the lower one starts at the junction.
    upper = _reach(0, [(c, 10) for c in range(18, 10, -1)], 'reach', down=2)
    lower = _reach(2, [(c, 10) for c in range(10, 0, -1)], 'sea')
    trib = _reach(1, [(10, r) for r in range(19, 10, -1)], 'reach', down=2, bed_y=[10.5 - 0.05 * k for k in range(9)])
    segs, g2, code, level = _carve(dict(reaches=[trib, upper, lower]), net, g)
    col = 20
    trib_levels = level[22:38, col][np.isfinite(level[22:38, col])]
    assert trib_levels.size > 0
    assert trib_levels.min() >= level[20, col] - 1e-6
    assert np.all(g2[20:24, col] < trib_levels.max())


def test_narrow_brook_is_left_to_r7():
    g = np.full((M, M), 10.0)
    g[:, 0:2] = -2.0
    segs, g2, code, level = _carve(dict(reaches=[_reach(0, [(c, 10) for c in range(18, 0, -1)], 'sea')]), _net(width=6.0), g)
    assert segs.shape[0] == 0
    assert np.all(g2 == g) and not code.any()


def test_seasonal_reach_is_class_8():
    g = np.full((M, M), 10.0)
    g[:, 0:2] = -2.0
    _, _, code, _ = _carve(dict(reaches=[_reach(0, [(c, 10) for c in range(18, 0, -1)], 'sea')]), _net(regime=2), g)
    assert (code == rc.SEASONAL_CHANNEL).any() and not (code == rc.RIVER).any()


def test_a_sinking_reach_tapers_out():
    """A reach that sinks at column 4: its cut is a full bankfull depth upstream and none at its end, and its water keeps its
    mean-flow depth upstream instead of rising to the bank top behind the dry end."""
    g = np.full((M, M), 10.0)
    reach = _reach(0, [(c, 10) for c in range(18, 3, -1)], 'sinks', bed_y=[10.0] * 15)
    _, g2, code, level = _carve(dict(reaches=[reach]), _net(), g)
    assert abs(g2[20, 2 * 12] - 8.8) < 1e-4
    assert abs(g2[20, 2 * 4] - 10.0) < 1e-4
    assert abs(level[20, 2 * 12] - 9.4) < 1e-4
    assert code[20, 2 * 4] == 0


def test_area():
    """Five cells in a chain to the sea: each drains itself and every cell above it."""
    rec = np.array([-1, 0, 1, 2, 3, 4], np.int64)
    a = rc._area(rec, 256.0)
    assert list(a) == [6 * 256.0, 5 * 256.0, 4 * 256.0, 3 * 256.0, 2 * 256.0, 256.0]


if __name__ == '__main__':
    for name, fn in sorted(globals().items()):
        if name.startswith('test_') and callable(fn):
            fn()
            print('ok', name)
