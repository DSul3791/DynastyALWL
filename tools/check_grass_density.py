#!/usr/bin/env python3
"""Fails if the near-field meadow grass (the near distance band, which runs to 0.35 of the radius) is thinner
than it was in build 228, the density the owner liked, or the reach is shorter than 228's, per quality tier
(Low, Medium, High, Ultra). Coverage = cards per square metre times the distance band's card width scale. The
middle and far bands are printed for information (they are thinner on purpose to pay for the reach).
Run before pushing any change to grass_view.gd or the QUALITY_GRASS_* tables:
python3 tools/check_grass_density.py   (ART_DIRECTION.md section 31)"""
import re, sys, pathlib, math

ROOT = pathlib.Path(__file__).resolve().parent.parent
client = (ROOT / "scenes/terrain_client/terrain_client.gd").read_text(encoding="utf-8")
view = (ROOT / "src/client/grass_view.gd").read_text(encoding="utf-8")

def table(name):
    m = re.search(r"const %s := \[([^\]]*)\]" % name, client)
    return [float(v) for v in m.group(1).split(",")]

radius, points, density = table("QUALITY_GRASS_M"), table("QUALITY_GRASS_POINTS"), table("QUALITY_GRASS_DENSITY")
scales = [float(v) for v in re.search(r"const LOD_SCALE := \[([^\]]*)\]", view).group(1).split(",")]
cards = sum(int(re.search(r'"name": "%s".*?"per_point": (\d+)' % n, view).group(1)) for n in ("short", "tall"))

# The rules the bands follow; the asserts fail when grass_view.gd changes them without this script.
assert "clampf(radius_m * 0.35, 14.0, 26.0)" in view and "radius_m * 0.65" in view, "band limits changed: update check_grass_density.py"
m = re.search(r"return \[points_per_side, maxi\((\d+), int\(round\(points_per_side \* ([\d.]+)\)\)\), (\d+)\]\[lod\]", view)
assert m, "_lod_points changed: update check_grass_density.py"
mid_min, mid_share, far_pts = int(m.group(1)), float(m.group(2)), int(m.group(3))

# Build 228 (Low, Medium, High, Ultra): radius, points per 6 m cell side, cards per sample.
B228 = [(14.0, 3, 0.68), (24.0, 5, 2.6), (34.0, 6, 3.0), (48.0, 7, 3.4)]
names = ["Low", "Medium", "High", "Ultra"]
bad = []

def coverage(q, d):
    r, pts = radius[q], points[q]
    near_end = min(max(r * 0.35, 14.0), 26.0)
    far_start = r * 0.65
    band = 0 if d < near_end else (1 if d < far_start else 2)
    pps = [pts, max(mid_min, math.floor(pts * mid_share + 0.5)), far_pts][band]
    return (pps / 6.0) ** 2 * density[q] * cards * scales[band]

print("grass coverage (cards per m2 x band width), now vs build 228")
print("%-7s %-9s %8s %8s" % ("tier", "distance", "now", "b228"))
for q in range(4):
    r228, p228, d228 = B228[q]
    for a, b in ((0, 10), (10, 20), (20, 40)):
        if a >= r228:
            continue
        samples = [a + (b - a) * k / 10.0 for k in range(10)]
        samples = [d for d in samples if d < r228]
        now = min(coverage(q, d) for d in samples)
        old = (p228 / 6.0) ** 2 * d228 * cards
        print("%-7s %2d-%2d m   %8.1f %8.1f" % (names[q], a, b, now, old))
        near_end = min(max(radius[q] * 0.35, 14.0), 26.0)
        near_only = min((coverage(q, d) for d in samples if d < near_end), default=old)
        if near_only < old - 1e-6:
            bad.append("%s %d-%d m: %.1f < %.1f" % (names[q], a, b, now, old))
    if radius[q] < r228:
        bad.append("%s reach %.0f m is shorter than build 228's %.0f m" % (names[q], radius[q], r228))

if bad:
    print("FAIL: the near-field grass is thinner than build 228:")
    print("\n".join("  " + b for b in bad))
    sys.exit(1)
print("grass density check: ok")
