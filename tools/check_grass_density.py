#!/usr/bin/env python3
"""Fails if the meadow grass gets thinner, shorter in reach or costlier than the owner-approved numbers
(ART_DIRECTION.md section 33), per quality tier (Low, Medium, High, Ultra):
  - near-field coverage (cards per m2 times the near band's card width) not below the approved level and not
    below build 228's;
  - reach (QUALITY_GRASS_M) not below 40 / 80 / 120 / 160 m (owner 2026-10-20: Low 25 percent, Medium 50,
    High 75, Ultra 100 percent of the 160 m between his two screenshots);
  - the estimated cards on open meadow not above the caps (Low 25k, Medium 130k, High 250k, Ultra 400k).
Run before pushing any change to grass_view.gd or the QUALITY_GRASS_* tables: python3 tools/check_grass_density.py"""
import re, sys, pathlib, math

ROOT = pathlib.Path(__file__).resolve().parent.parent
client = (ROOT / "scenes/terrain_client/terrain_client.gd").read_text(encoding="utf-8")
view = (ROOT / "src/client/grass_view.gd").read_text(encoding="utf-8")

def table(name):
    m = re.search(r"const %s := \[([^\]]*)\]" % name, client)
    return [float(v) for v in m.group(1).split(",")]

def vtable(name):
    m = re.search(r"const %s := \[([^\]]*)\]" % name, view)
    return [float(v) for v in m.group(1).split(",")]

radius, points, density = table("QUALITY_GRASS_M"), table("QUALITY_GRASS_POINTS"), table("QUALITY_GRASS_DENSITY")
scale_big, scale_low, share = vtable("LOD_SCALE"), vtable("LOD_SCALE_SHORT"), vtable("BAND_SHARE")
cards = sum(int(re.search(r'"name": "%s".*?"per_point": (\d+)' % n, view).group(1)) for n in ("short", "tall"))

# The rules the bands follow; the asserts fail when grass_view.gd changes them without this script.
for needle in ("clampf(meters * 0.3, NEAR_END_MIN, NEAR_END_MAX)", "_mid_end = meters * 0.5", "_far_end = meters * 0.8",
               "_mid_end = meters * 0.65", "return [points_per_side, 3, 2, 1][lod]",
               "return [points_per_side, maxi(2, int(round(points_per_side * 0.5))), 2, 2][lod]"):
    assert needle in view, "band rule changed (%s): update check_grass_density.py" % needle
NEAR_MIN, NEAR_MAX = (float(re.search(r"const %s := ([\d.]+)" % n, view).group(1)) for n in ("NEAR_END_MIN", "NEAR_END_MAX"))

# Build 228: radius, points per cell side, cards per sample (8 + 3 per sample then).
B228 = [(14.0, 3, 0.68), (24.0, 5, 2.6), (34.0, 6, 3.0), (48.0, 7, 3.4)]
APPROVED_NEAR = [15.0, 39.0, 65.0, 100.0]          # cards per m2 in the near band (build 290 doubled the card counts)
APPROVED_REACH = [40.0, 80.0, 120.0, 160.0]
CAPS_K = [25.0, 130.0, 250.0, 400.0]
names = ["Low", "Medium", "High", "Ultra"]
bad = []

def bands(q):
    r = radius[q]
    big = r > 50.0
    ne = min(max(r * 0.3, NEAR_MIN), NEAR_MAX)
    me, fe = (r * 0.5, r * 0.8) if big else (r * 0.65, r)
    pts = points[q]
    pps = [pts, 3, 2, 1] if big else [pts, max(2, int(math.floor(pts * 0.5 + 0.5))), 2, 2]
    edges = [0.0, ne, me, fe, r]
    scales = scale_big if big else scale_low
    sh = share if big else [1.0, 1.0, 1.0, 1.0]
    return [(edges[b], edges[b + 1], pps[b], scales[b], sh[b]) for b in range(4)]

print("%-7s %-18s %9s %9s %9s" % ("tier", "band (m)", "cards/m2", "coverage", "k cards"))
for q in range(4):
    total = 0.0
    for b, (a, e, p, sc, sh) in enumerate(bands(q)):
        per_m2 = (p / 6.0) ** 2 * density[q] * cards * sh
        k = math.pi * (e * e - a * a) * per_m2 / 1000.0
        total += k
        print("%-7s %-18s %9.1f %9.1f %9.0f" % (names[q] if b == 0 else "", "%3.0f to %3.0f" % (a, e), per_m2, per_m2 * sc, k))
    near_cov = (points[q] / 6.0) ** 2 * density[q] * cards
    old = (B228[q][1] / 6.0) ** 2 * B228[q][2] * 11
    print("%-7s total %.0fk (cap %.0fk), near %.1f per m2 (approved %.0f, build 228 %.1f), reach %.0f m" % ("", total, CAPS_K[q], near_cov, APPROVED_NEAR[q], old, radius[q]))
    if near_cov < APPROVED_NEAR[q] or near_cov < old:
        bad.append("%s near field %.1f per m2 is below %.0f" % (names[q], near_cov, max(APPROVED_NEAR[q], old)))
    if radius[q] < APPROVED_REACH[q]:
        bad.append("%s reach %.0f m is below %.0f m" % (names[q], radius[q], APPROVED_REACH[q]))
    if total > CAPS_K[q]:
        bad.append("%s about %.0fk cards is over the %.0fk cap" % (names[q], total, CAPS_K[q]))

if bad:
    print("FAIL:")
    print("\n".join("  " + b for b in bad))
    sys.exit(1)
print("grass density check: ok")
