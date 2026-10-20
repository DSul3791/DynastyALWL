#!/usr/bin/env python3
"""Fails if the grass distance-band hysteresis in grass_view.gd can flip a cell between two bands at every rescan
(build 272 to 282 had it backwards and the grass popped in front of the player). It checks the slack rule line
is unchanged and simulates it: a cell that has settled must not change band on a rescan, at any distance.
Run before pushing any change to _lod_of: python3 tools/check_grass_bands.py"""
import re, sys, pathlib

src = (pathlib.Path(__file__).resolve().parent.parent / "src/client/grass_view.gd").read_text(encoding="utf-8")
rule = "var slack: float = LOD_HYSTERESIS_M if held == band else (-LOD_HYSTERESIS_M if held > band else (LOD_HYSTERESIS_M if held >= 0 else 0.0))"
if rule not in src:
    print("FAIL: the slack line in _lod_of changed; a cell must stay in its band until it is LOD_HYSTERESIS_M past the boundary")
    sys.exit(1)

H = 3.0
def band_of(d, held, limits, last):
    for b in range(3):
        slack = H if held == b else (-H if held > b else (H if held >= 0 else 0.0))
        if d < limits[b] + slack:
            return b
    return last

bad = []
for limits, last in (([14.0, 26.0, 40.0], 2), ([20.0, 40.0, 64.0], 3), ([20.0, 80.0, 128.0], 3)):
    for k in range(0, 400):
        d = k * 0.5
        held, seen = -1, []
        for _ in range(6):
            held = band_of(d, held, limits, last)
            seen.append(held)
        if len(set(seen[1:])) > 1:
            bad.append((limits[0], d))
if bad:
    print("FAIL: cells flip bands (near limit, distance):", bad[:8])
    sys.exit(1)
print("grass bands check: ok")
