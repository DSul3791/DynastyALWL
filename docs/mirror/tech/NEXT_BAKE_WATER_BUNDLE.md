# Next bake bundle: water side proposal (Sonny, 2026-10-22) - for Steve and the coordinator to decide

Nothing here is built. Generator freeze holds until Steve names the next bake. Each item says what it needs.

## Finding that changes the lip item
The 300 m waterfall near x 53640 z 69150 is NOT a baked river. tile_3_4: water class 0 on every cell from the pocket at z 69260 down the flank to z 69040 (ground 440 m to 51 m); the water there is simulation water (0.1 to 0.4 m films, pockets up to 1.7 m) running down bare mountain ground from the spring pond above. So "widen the lip" in `_carve_guides` (river_min_width_m, monotone bed) cannot reach it: the guide river stops where the pond outlet ends. Dave's rule (ridge the same shape and height as the river bed coming out; fall as wide as the river) needs the carved bed to continue.

## Proposed items
1. Guide river continues down the fall line (generator, tile-changing). From the head pond outlet, keep the guide river going down the steep flank to the next flat water (the plunge pool), using the existing guide code: min width 24 m is too wide for a mountain stream, so use the Q10 width rule (10 to 14 m) above 300 m elevation; bed monotone downhill; lip bed = upstream bed (no ridge); single chute, no steps (Dave 2026-10-21). Edge match and the 882-test suite must pass. Cost: one bake (about 260 s per tile; changes only tile 3,4 and maybe 4,4).
2. River mouth recheck on the real bake: done today (bays dry and clean, estuary 300 m at -2.5 m). No change proposed.
3. Runtime only (already shipped, no bake): fall width from drawn or thin water (584), river smoothing (571), nine-tile live sim (564).

## Risks
- Item 1 changes ground under the existing waterfall and spawn-adjacent terrain: needs Willy's review of the hillshade before and after, as for the mask removal.
- If the chute becomes one clean channel, the fall list shrinks from 12 chained segments to 1 to 2, which also lightens the draw.

## Decision needed
ANSWERED YES by Dave (2026-10-22 01:04): carve the channel in the next bake. Item 1 is approved by Dave; it still waits for Steve naming the bake and for Willy's hillshade review. Code is prepared only when Steve names the bake (generator freeze holds).

## Item 0 (found 2026-10-22, pond report; REVISED after reading the chute code)
The "new lake in front of the head pond" is the PLUNGE POOL of the first chute (the 21 Oct merged push: a basin up to 40 m wide and up to 4 m deep at the foot of every clean chute), at x 53640-53700, z 69300-69376, ground 401-402 m, 25 m below the head pond (east bowl, x ~53800, surface 427 m, unchanged). The old tile (before the chute push) had a gentle ramp there (408-410 m). It is designed, not a bug. The real bug was only the runtime spring landing in it (fixed in build 623, no bake).
What is left for the bake: the pool is not closed on its south side. Its water stands at about 404.7 m and its south wall (x 53664-53696, z 69280-69300) is 401-403 m, so it spills south down the valley to the 300 m flank: this is the "300 m fall" Dave named. Two ways, Steve decides:
 A. Seal: after the plunge pool is stamped, raise every pool-edge cell to at least pool level + 1 m except along the river channel (a generic rule for all pools). The south fall then disappears; all water goes down the west chute.
 B. Carve (Dave's answered yes): extend a guide chute from the pool's lowest non-river rim cell down the fall line (10-14 m wide, bed monotone, lip bed equal to the pool bed). Two outlets split the flow.
Recommendation: B only if Dave still wants the south fall seen; otherwise A. DECIDED 05:25 (Steve): B, see DECISIONS.md.
