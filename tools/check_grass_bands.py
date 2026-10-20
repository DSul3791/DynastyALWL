#!/usr/bin/env python3
"""Fails if the grass distance-band hysteresis in grass_view.gd can flip a cell between two bands at every rescan
(build 272 to 282 had it backwards and the grass popped in front of the player). It checks the two slack lines
are the right way round and simulates the rule: a cell that has settled must not change band on a rescan.
Run before pushing any change to _lod_of: python3 tools/check_grass_bands.py"""
import re, sys, pathlib

src = (pathlib.Path(__file__).resolve().parent.parent / "src/client/grass_view.gd").read_text(encoding="utf-8")
near = re.search(r"var slack_near: float = LOD_HYSTERESIS_M if held == 0 else \(-LOD_HYSTERESIS_M if held >= 1 else 0\.0\)", src)
far = re.search(r"var slack_far: float = -LOD_HYSTERESIS_M if held == 2 else \(LOD_HYSTERESIS_M if held >= 0 else 0\.0\)", src)
if not near or not far:
    print("FAIL: the slack lines in _lod_of changed; a cell must stay in its band until it is LOD_HYSTERESIS_M past the boundary")
    sys.exit(1)

H = 3.0
def band(d, held, ne=26.0, fs=40.0):
    sn = H if held == 0 else (-H if held >= 1 else 0.0)
    sf = -H if held == 2 else (H if held >= 0 else 0.0)
    if d < ne + sn:
        return 0
    return 1 if d < fs + sf else 2

bad = []
for k in range(0, 200):
    d = k * 0.5
    held = -1
    seen = []
    for _ in range(6):
        held = band(d, held)
        seen.append(held)
    if len(set(seen[1:])) > 1:
        bad.append(d)
if bad:
    print("FAIL: cells flip bands at distances", bad[:8])
    sys.exit(1)
print("grass bands check: ok")
