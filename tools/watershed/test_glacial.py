"""Unit tests for glacial.py's swath (the glacier's footprint) on tiny synthetic valleys: with the old rule a big glacier's
flux and ice reach up a steep head wall within half its width; with swath_below_ice_surface they stop at the glacier's own
surface, and on a gentle floor both rules give the same swath. Also: the cold step's
threaded kernels (cut A2) against the numpy lines they replaced. They need numpy and numba (glacial.py's own imports) and take
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



def test_cold_step_kernels_match_the_numpy_lines():
    """Cut A2 (docs/design/glacial_speed_design.md): each threaded kernel of the cold step must give exactly the arrays of the
    numpy lines it replaced (kept here as they were), on random cells with ice and without, melt and gain, sea and land."""
    eq = np.array_equal
    r = np.random.default_rng(7)
    N, cell = 400, 256.0
    h = r.uniform(-20.0, 1500.0, N)
    h[:10] = -5.0                                              # land under the 0.05 m floor (below)
    ice = np.where(r.random(N) < 0.3, r.uniform(0.0, 200.0, N), 0.0)
    ela, rain = r.uniform(600.0, 900.0, N), r.uniform(500.0, 3000.0, N)
    Hf, He, BR, p0 = 1400.0, 800.0, 1.56, 1200.0
    surf, p_ice, ice_src = np.empty(N), np.empty(N), np.empty(N)
    gl._cold_sources(h, ice, ela, rain, Hf - He, BR, cell, p0, surf, p_ice, ice_src)
    s_old = h + ice
    frac = np.minimum((s_old - ela) / (Hf - He), 1.0)
    frac = np.where(frac < 0.0, frac * BR, frac)
    p_old = rain * frac
    assert eq(surf, s_old) and eq(p_ice, p_old) and eq(ice_src, cell * p_old / p0)
    assert (p_old < 0.0).any() and (frac == 1.0).any()          # melt and the full-ice cap both happen
    et = r.uniform(100.0, 800.0, N)
    Ai = np.where(r.random(N) < 0.4, r.uniform(0.0, 1e6, N), 0.0)
    wq = np.empty(N)
    gl._cold_water(rain - et, p_ice, Ai, 321.0, wq)
    w = np.maximum(rain - et - np.maximum(p_old, 0.0), 0.0)
    w = w + np.maximum(-p_old, 0.0) * (Ai > 0.0)
    assert eq(wq, w / 321.0)
    A = r.uniform(0.0, 5e6, N)
    Asw = np.where(r.random(N) < 0.3, r.uniform(0.0, 4e6, N), 0.0)
    Qw = np.where(r.random(N) < 0.2, 0.0, r.uniform(0.0, 1e7, N))
    eps, m, a0, alpha, delta, w0 = 0.25, 0.5, 2500.0, 0.3, 0.25, 50.0
    Aeff, am, Qwi, qm, thick = gl._cold_powers(A, Asw, Qw, cell, eps, m, a0, alpha, delta, w0, N)
    Aeff_old = np.where(Asw > 0.0, np.maximum(A, cell) ** eps * Asw ** (1.0 - eps), 0.0)
    Qwi_old = np.where(Qw > 0.0, Qw, cell)
    thick_old = np.where(Aeff_old > 0.0, delta * w0 * (Aeff_old / a0) ** alpha, 0.0)
    assert eq(Aeff, Aeff_old) and eq(am, Aeff_old ** m) and eq(Qwi, Qwi_old) and eq(qm, Qwi_old ** m) and eq(thick, thick_old)
    sea = r.random(N) < 0.2
    sea[:10] = False
    thick[sea] = 0.0
    thick_old[sea] = 0.0
    er, ec, share = r.uniform(0.05, 1.5, N), np.full(N, 5.0), r.uniform(0.0, 1.0, N)
    Kg, K, tau, thr = 0.667 * 1.2e-5, 1.2e-5, 10.0, 0.7
    outs = [np.empty(N) for _ in range(6)]
    gl._cold_coefficients(h, thick, Aeff, am, Qwi, qm, er, ec, share, Kg, K, tau, thr, *outs)
    x_old = h + thick_old
    want = [Kg * er * Aeff_old ** m + K * er * share * Qwi_old ** m, Kg * ec * Aeff_old ** m + K * ec * share * Qwi_old ** m,
            Qwi_old + tau * Aeff_old, np.where(thick_old > 0.0, 0.0, K * er * share * thr), x_old, x_old]
    for k_, (got, w_) in enumerate(zip(outs, want)):
        assert eq(got, w_), k_
    land = ~sea
    hn = np.empty(N)
    gl._cold_ground(x_old, thick_old, land, hn)
    h_old = x_old - thick_old
    h_old[land] = np.maximum(h_old[land], 0.05)
    assert eq(hn, h_old) and (hn[land] == 0.05).any()
    U, dt = r.uniform(0.0, 1e-3, N), 2000.0
    dep, cut = r.uniform(0.0, 5.0, N), r.uniform(-5.0, 5.0, N)
    imax, cmax, fmax = r.uniform(0.0, 100.0, N), r.uniform(0.0, 100.0, N), r.uniform(0.0, 1e6, N)
    h_after = h_old + r.normal(0.0, 3.0, N)                    # creep moved it
    cut_kernel = cut.copy()
    outs = [np.empty(N) for _ in range(5)]
    gl._cold_after(h_after, h_old, U, dt, dep, cut_kernel, thick_old, Ai, imax, cmax, fmax, *outs)
    change = h_after - (h_old + U * dt)
    want = [change, np.maximum(dep + change, 0.0), np.maximum(imax, thick_old), np.maximum(cmax, thick_old), np.maximum(fmax, Ai)]
    for k_, (got, w_) in enumerate(zip(outs, want)):
        assert eq(got, w_), k_
    cut -= change
    assert eq(cut_kernel, cut)


if __name__ == '__main__':
    tests = [v for k_, v in sorted(globals().items()) if k_.startswith('test_')]
    for t in tests:
        t()
        print('ok  ', t.__name__)
    print(f'{len(tests)} passed')
