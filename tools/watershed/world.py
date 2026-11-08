"""The island's place on the world grid: its signed latitude from its tile row, and what in the watershed tools hangs on
the hemisphere (design A4, one sky; Dave 8 Nov 2026: the world is 21 by 21 tiles with the centre row the equator).

The rule is the game's own (WORLD_FORMAT_SPEC.md sections 2 and 3; src/worldgen/settings/world_settings.gd latitude_for_z):
- north is -z;
- the equator line runs through the middle of the equator row (z = equator_tile_row x tile_size_m + tile_size_m / 2);
- the latitude fraction is -(z - equator z) / (half the world's north-south span), wrapped into one world period, so it
  runs from -1 at the south pole through 0 at the equator to +1 at the north pole, the poles meeting at the wrap seam.
Degrees are the fraction times degrees_at_pole (90): 8.57 degrees a row on the 21-row world. The geometry is read from the
world's own world.json (params world.world_json), so the watershed tools and the game share one source.

On the starter island (tiles z 3 to 5, rows south of the equator) the island's middle, z 69,120 m, is at 34.3 S: the
noon sun stands in the north and the shady lee quarter is the south-east (shady_bearing_deg 135).

What reads it: glacial.py's aspect term and peaks.py's shady/sunny lines (the shady bearing), and record.py's climate.json
(latitude_deg, which the game's sun, moon and shade read). sea_level_c gives the world's sea-level temperature curve at the
island, which the record reports beside the climate it carries; nothing in the physics reads it yet."""
import os, json
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..'))


def load(W):
    """The world geometry and temperature curve from world.json (W: params world; world_json relative to the repo)."""
    path = W['world_json'] if os.path.isabs(W['world_json']) else os.path.join(REPO, W['world_json'])
    w = json.load(open(path))
    geo, cl = w['geometry'], w.get('climate', {})
    return dict(tile_size_m=float(geo['tile_size_m']), tiles_z=int(geo['tiles_z']), equator_tile_row=int(cl.get('equator_tile_row', 0)),
                temperature_by_abs_latitude=[[float(a), float(b)] for a, b in cl.get('temperature_by_abs_latitude', [])],
                degrees_at_pole=float(W['degrees_at_pole']),
                shady_bearing_north_deg=float(W['shady_bearing_north_deg']), shady_bearing_south_deg=float(W['shady_bearing_south_deg']))


def latitude_fraction(z_m, G):
    """+1 at the north pole, 0 at the equator, -1 at the south pole (world_settings.gd latitude_for_z), wrapped."""
    T = G['tile_size_m']
    eq = G['equator_tile_row'] * T + 0.5 * T
    half = G['tiles_z'] * T * 0.5
    off = (np.asarray(z_m, float) - eq + half) % (2.0 * half) - half
    return -off / half


def latitude_deg(z_m, G):
    """Signed latitude in degrees, south negative."""
    return latitude_fraction(z_m, G) * G['degrees_at_pole']


def shady_bearing_deg(lat_deg, G):
    """The middle of the shady lee quarter (facing the pole, in the lee of the westerlies): north-east north of the equator,
    south-east south of it. The equator line itself takes the northern value."""
    return G['shady_bearing_north_deg'] if float(lat_deg) >= 0.0 else G['shady_bearing_south_deg']


def sea_level_c(lat_deg, G):
    """The world's sea-level annual mean temperature at a latitude (world_settings.gd sample_curve: smoothstep between the
    control points over |fraction|, the end values held outside them). None without a curve."""
    pts = G['temperature_by_abs_latitude']
    if not pts:
        return None
    x = min(abs(float(lat_deg)) / G['degrees_at_pole'], 1.0)
    if x <= pts[0][0]:
        return pts[0][1]
    for k in range(1, len(pts)):
        if x <= pts[k][0]:
            t = min(max((x - pts[k - 1][0]) / max(pts[k][0] - pts[k - 1][0], 1e-6), 0.0), 1.0)
            t = t * t * (3.0 - 2.0 * t)
            return pts[k - 1][1] + (pts[k][1] - pts[k - 1][1]) * t
    return pts[-1][1]


def sky(P, origin_z, extent_m):
    """The island's one sky from its grid (origin_z and north-south extent in world metres): the tile row of its middle, its
    latitude there, the shady bearing that latitude gives, and the world curve's sea-level temperature (reported only)."""
    G = load(P['world'])
    z = float(origin_z) + 0.5 * float(extent_m)
    lat = float(latitude_deg(z, G))
    sl = sea_level_c(lat, G)
    return dict(middle_z_m=round(z, 1), tile_row=int(np.floor(z / G['tile_size_m'])), latitude_deg=round(lat, 2),
                shady_bearing_deg=shady_bearing_deg(lat, G), world_curve_sea_level_c=None if sl is None else round(sl, 2))
