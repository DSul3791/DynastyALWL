"""Unit tests for the rock lookups in tools/erosion_precarve/rock.py, which run on numba's threads (glacial speed cut A1,
docs/design/glacial_speed_design.md). On a small made-up geology (three provinces, one with no layers, intrusions, a
limestone layer that turns to marble at depth) every threaded lookup must give exactly the numbers of the one-cell rule
_rock_at run cell by cell in plain Python, and rock_ids with the sea given must leave the sea at id 0 and the land as it was.
They need numpy and numba and take a few seconds, most of it numba compiling.

Run on David4 or Dave's PC, never in the cloud:
  python tools/watershed/test_rock.py        (or: python -m pytest tools/watershed/test_rock.py)
"""
import os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'erosion_precarve'))
import rock    # noqa: E402

N_SIDE = 24
KEYS = ('prov', 'surf', 'gran', 'basa', 'cycle', 'repeat', 'base', 'marble', 'ptr', 'lrock', 'lbot', 'gid', 'bid', 'lid', 'mid')


def _geology(seed=3):
    """Rock ids 0 granite, 6 basalt, 4 limestone, 5 marble, 1 to 3 the province bases. Province 0 has three layers in a 60 m
    cycle that repeats to 500 m, province 1 two layers in a 40 m cycle, province 2 none (its base all the way down)."""
    r = np.random.default_rng(seed)
    N = N_SIDE * N_SIDE
    return dict(prov=r.integers(0, 3, N).astype(np.int32), surf=r.uniform(50.0, 400.0, N),
                gran=np.where(r.random(N) < 0.1, 300.0, -1e9), basa=np.where(r.random(N) < 0.1, 200.0, -1e9),
                er=np.array([0.08, 0.5, 0.7, 0.9, 1.2, 0.3, 0.2]), cycle=np.array([60.0, 40.0, 1.0]),
                repeat=np.array([500.0, 300.0, 1.0]), base=np.array([1, 2, 3], np.int32), marble=np.array([100.0, 1e9, 0.0]),
                ptr=np.array([0, 3, 5, 5], np.int32), lrock=np.array([4, 5, 1, 4, 2], np.int32),
                lbot=np.array([20.0, 45.0, 60.0, 15.0, 40.0]), gid=0, bid=6, lid=4, mid=5, cover_m=4.0, cover_ery=5.0)


def _heights(seed=4):
    r = np.random.default_rng(seed)
    return r.uniform(-50.0, 450.0, N_SIDE * N_SIDE)     # above the old surface, in the layers, below the repeat, in the sea


def _one_by_one(g, h):
    return np.array([rock._rock_at.py_func(i, float(h[i]), *[g[k] for k in KEYS[:-4]], *[int(g[k]) for k in KEYS[-4:]])
                     for i in range(h.size)], np.int32)


def test_rock_ids_on_threads_match_the_one_cell_rule():
    g, h = _geology(), _heights()
    want = _one_by_one(g, h)
    got = rock.rock_ids(g, h)
    assert got.dtype == np.int32 and np.array_equal(got, want), np.flatnonzero(got != want)[:10]
    assert len(set(want.tolist())) >= 6, sorted(set(want.tolist()))      # the made-up geology reaches most of its rocks
    assert np.array_equal(rock.rock_ids(g, h.reshape(N_SIDE, N_SIDE)), want)   # a grid gives the same as a flat array


def test_rock_ids_with_the_sea_leaves_it_out():
    g, h = _geology(), _heights()
    sea = h < 0.0
    want = _one_by_one(g, h)
    got = rock.rock_ids(g, h, sea.astype(np.uint8))      # glacial.py passes its uint8 sea
    assert np.array_equal(got[~sea], want[~sea]) and (got[sea] == 0).all()
    assert sea.any() and (want[sea] != 0).any()          # so the test can tell a skipped cell from a looked-up one


def test_erodibility_on_threads_matches_the_one_cell_rule():
    g, h = _geology(), _heights()
    sea = (h < 0.0).astype(np.uint8)
    start = np.random.default_rng(5).uniform(0.0, 40.0, (N_SIDE, N_SIDE))   # steep enough in places for no cover
    fn = rock.make_fn(g, start, sea, 16.0)
    rock_out, cover_ery, cover = fn.parts(h)
    ids = _one_by_one(g, h)
    want_rock = np.where(sea == 1, 1.0, g['er'][ids])
    assert np.array_equal(rock_out, want_rock)
    top = fn(h)
    want_top = np.where(sea == 1, 1.0, np.where(cover > 0.0, cover_ery, g['er'][ids]))
    assert np.array_equal(top, want_top)
    assert (cover > 0.0).any() and ((cover == 0.0) & (sea == 0)).any()     # both branches of the cover rule are used


if __name__ == '__main__':
    tests = [v for k_, v in sorted(globals().items()) if k_.startswith('test_')]
    for t in tests:
        t()
        print('ok  ', t.__name__)
    print(f'{len(tests)} passed')
