"""Unit tests for glacial.py's swath (the glacier's footprint) on tiny synthetic valleys: with the old rule a big glacier's
flux and ice reach up a steep head wall within half its width; with swath_below_ice_surface they stop at the glacier's own
surface, and on a gentle floor both rules give the same swath. They need numpy and numba (glacial.py's own imports) and take
a few seconds, most of it numba compiling.

Run on David4 or Dave's PC, never in the cloud:
  python tools/watershed/test_glacial.py        (or: python -m pytest tools/watershed/test_glacial.py)
"""
import os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import glacial as gl    # noqa: E402

DX = 16.0
W0, A0, ALPHA, DELTA = 50.0, 2500.0, 0.3, 0.25


def _column(heights):
    """One row of cells draining left to right (cell k to k + 1), the last one the outlet, on an n x n grid with only that
    row used. Returns the ground, receivers, order (downstream first) and donors."""
    n = len(heights)
    N = n * n
    ground = np.full(N, 5000.0)
    rec = np.full(N, -1, np.int64)
    for k in range(n):
        ground[k] = heights[k]
        if k < n - 1:
            rec[k] = k + 1
    order = np.array(list(range(n - 1, -1, -1)) + list(range(n, N)), np.int64)
    ptr, don = gl._donors(rec, order, N)
    return ground, order, ptr, don, n


def _head_valley():
    """A 57-degree head wall (25 m a cell) rising from a flat floor: cells 0 to 5 the wall (top first), 6 to 15 the floor."""
    wall = [6 * 24.6 - 24.6 * k for k in range(6)]
    floor = [0.0] * 10
    return [h + 100.0 for h in wall + floor]


def test_old_rule_lays_the_floor_flux_up_the_wall():
    ground, order, ptr, don, n = _column(_head_valley())
    Ai = np.zeros(n * n)
    Ai[6:16] = 4.0e6                          # a big glacier on the floor (about 460 m wide), nothing made on the wall
    out, _ = gl._swath(Ai, ptr, don, order, n, DX, W0, A0, ALPHA, ground, DELTA, False)
    assert out[0] == 4.0e6 and out[5] == 4.0e6          # half its width (229 m, 14 cells) climbs the whole 148 m wall


def test_below_surface_stops_at_the_glacier_top():
    ground, order, ptr, don, n = _column(_head_valley())
    Ai = np.zeros(n * n)
    Ai[6:16] = 4.0e6
    out, surf = gl._swath(Ai, ptr, don, order, n, DX, W0, A0, ALPHA, ground, DELTA, True)
    w = 2.0 * 0.5 * W0 * (4.0e6 / A0) ** ALPHA
    top = 100.0 + DELTA * w                   # the floor plus delta x width: about 214 m
    for k in range(6):
        if ground[k] < top:
            assert out[k] == 4.0e6 and abs(surf[k] - top) < 1e-9   # wall below the ice surface: in the glacier
        else:
            assert out[k] == 0.0 and surf[k] == ground[k]          # wall above it: bare rock, its own (no) ice
    assert out[1] == 0.0 and out[5] == 4.0e6


def test_same_swath_on_a_gentle_floor():
    hs = [100.0 + 0.5 * (15 - k) for k in range(16)]   # a floor falling 0.5 m a cell
    ground, order, ptr, don, n = _column(hs)
    Ai = np.zeros(n * n)
    Ai[:16] = np.linspace(1.0e5, 4.0e6, 16)
    a, _ = gl._swath(Ai, ptr, don, order, n, DX, W0, A0, ALPHA, ground, DELTA, False)
    b, _ = gl._swath(Ai, ptr, don, order, n, DX, W0, A0, ALPHA, ground, DELTA, True)
    assert np.array_equal(a, b)


def test_small_glacier_keeps_its_own_cell():
    ground, order, ptr, don, n = _column(_head_valley())
    Ai = np.zeros(n * n)
    Ai[8] = 500.0                             # half-width 15.4 m, under one cell: no swath
    out, surf = gl._swath(Ai, ptr, don, order, n, DX, W0, A0, ALPHA, ground, DELTA, True)
    assert out[7] == 0.0 and out[8] == 500.0 and surf[8] > ground[8]


if __name__ == '__main__':
    tests = [v for k_, v in sorted(globals().items()) if k_.startswith('test_')]
    for t in tests:
        t()
        print('ok  ', t.__name__)
    print(f'{len(tests)} passed')
