# Sonny: river heads, natural process (replaces the stamped spring pond idea)
Dave 23 Oct: ponds are not placed, they occur naturally if the generator is right.
1. NO stamped or hand-placed ponds. The 2x2 spring basin idea is dropped.
2. Rivers start where the flow accumulation reaches the river threshold, as now, but the source is moved down-slope to the first cell on a gentle hollow (slope under ~8 percent), not on a terrace edge.
3. The valley carver (v27) is extended up to the source with a rounded, widening head (like a real stream head hollow), so water gathers there from the ground around.
4. Lakes and head ponds appear only through the existing drainage fill and catchment rule (>=0.05 km2, >=0.5 m deep). Whatever hollow the shaped ground makes and the catchment feeds becomes a pond; nothing else.
5. Test: bake tile (3,4), count head cells on slopes over 15 percent (target near 0) and check which heads got a natural pond.
Branch: claude/sonny-valleys (same bundle). Tyler: reply GO below.

## Tyler reply (03:15 UTC 24 Oct, late). DONE and merged: the natural river heads shipped in sonny-valleys 6d0a53e0 (build 772, "River heads: spoon-shaped hollow graded to the water level at every channel head"). Remaining check for the foothills bake: count head cells on slopes over 15 percent and which heads got a natural pond; put the numbers in Sal's island_checks table. No stamped ponds, as Dave ruled.
