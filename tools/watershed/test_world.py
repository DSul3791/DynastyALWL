"""Unit tests for world.py (the island's latitude from its tile row on the world grid, design A4 one sky; Dave 8 Nov 2026):
the equator line, degrees a row, the starter island's row and hemisphere, the wrap at the poles, the shady bearing and the
world's sea-level temperature curve. They read the repo's params.json and world.json, need numpy only, and take well
under a second.

Run on David4 or Dave's PC, never in the cloud:
  python tools/watershed/test_world.py        (or: python -m pytest tools/watershed/test_world.py)
"""
import os, sys, json
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import world    # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
P = json.load(open(os.path.join(HERE, 'params.json')))
G = world.load(P['world'])
T = 15360.0


def test_world_json_geometry():
    assert G['tile_size_m'] == T and G['tiles_z'] == 21 and G['equator_tile_row'] == 0
    assert G['temperature_by_abs_latitude'][0] == [0.0, 30.0] and G['temperature_by_abs_latitude'][-1][0] == 1.0


def test_equator_and_degrees_a_row():
    assert abs(float(world.latitude_deg(0.5 * T, G))) < 1e-12              # the middle of row 0 is the equator line
    north = float(world.latitude_deg(0.5 * T - T, G))                       # one row north (-z)
    assert abs(north - 90.0 / 10.5) < 1e-9                                  # 8.57 degrees a row, the pole at row 10.5
    assert float(world.latitude_deg(0.5 * T + T, G)) == -north              # one row south


def test_starter_island_is_south_at_34():
    x0, z0, x1, z1 = P['tiles']
    n = ((z1 - z0 + 1) * 1920 + 1) // 2 + 1                                 # inputs.py: tiles inclusive, 16 m model grid
    s = world.sky(P, z0 * T, n * 16.0)
    assert s['tile_row'] == 4 and -34.4 < s['latitude_deg'] < -34.2, s      # Jamie 8 Nov: tile centre 34.3 S
    assert s['shady_bearing_deg'] == 135.0                                  # noon sun north, shade on the south-east
    assert 14.0 < s['world_curve_sea_level_c'] < 14.4, s                    # the world curve there, about 14.2 C
    spawn = float(world.latitude_deg(68080.0, G))
    assert -33.8 < spawn < -33.6                                            # Jamie 8 Nov: spawn 33.7 S


def test_north_mirror_and_wrap():
    s = world.sky(P, -5 * T, 3 * T)                                         # the mirror rows north of the equator
    assert s['latitude_deg'] > 0.0 and s['shady_bearing_deg'] == 45.0
    assert abs(float(world.latitude_deg(10.5 * T, G)) + float(world.latitude_deg(-9.5 * T, G))) < 1e-9   # rows 10 and -10 meet at the pole
    z = np.array([-150000.0, 3000.0, 69120.0, 160000.0])
    assert np.allclose(world.latitude_deg(z + 21 * T, G), world.latitude_deg(z, G), rtol=0.0, atol=1e-9)   # one world period
    assert np.abs(world.latitude_deg(np.linspace(-10 * T, 11 * T, 400), G)).max() <= 90.0 + 1e-9
    assert world.shady_bearing_deg(0.0, G) == 45.0 and world.shady_bearing_deg(-0.01, G) == 135.0


def test_sea_level_curve():
    assert world.sea_level_c(0.0, G) == 30.0 and world.sea_level_c(-90.0, G) == -18.0 and world.sea_level_c(95.0, G) == -18.0
    assert abs(world.sea_level_c(0.43 * 90.0, G) - 13.0) < 1e-9                                         # on a control point
    v = [world.sea_level_c(x, G) for x in np.linspace(0.0, 90.0, 91)]
    assert all(b <= a + 1e-12 for a, b in zip(v, v[1:]))                     # never warmer toward the poles
    assert world.sea_level_c(34.3, G) == world.sea_level_c(-34.3, G)         # the same either side of the equator


if __name__ == '__main__':
    tests = [v for k, v in sorted(globals().items()) if k.startswith('test_') and callable(v)]
    for t in tests:
        t()
        print('ok', t.__name__)
    print(f'{len(tests)} tests passed')
