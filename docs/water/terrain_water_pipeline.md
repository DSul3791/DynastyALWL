# Terrain then water: one pipeline (design, Sonny, 7 Nov 2026)

Dave, 7 Nov after his test play: "the water and the land are the only priority now ... I want naturally systemic fixes not patches. no area specific patches. we have to make a better terrain generator and then manage the water better on how it flows."

This document lists why the bugs he saw happen, proposes one pipeline that removes the causes, says which patches it retires, and splits the work into small PRs. The foundation stays Dave's guide (`Sullivans_Guide_to_Better_Water_in_Godot_Edition_3.md`). Nothing here runs in the cloud: every bake and test runs on Dino or David4.

## 1. Root causes (what the play test showed)

All of these come from the same three faults: **the ground keeps changing after the water is decided**, **water is placed by rules rather than by flow**, and **every reader works its own water out again from a different copy**.

| Bug (Dave, 7 Nov) | Where | Root cause |
|---|---|---|
| River trench 12 m deep with steep walls; land "impressively too lumpy" | 53545,68378; 53453,68888 | The carve is a stamped parabola plus a flat 5 m `river_extra_depth_m`. It is a cut into the land, not a valley the land drains into. Rolling bumps (2.2 + 1.5 + 0.65 m) and hills are added AFTER the water, then patched near water with fades. |
| Bank dykes with ponds behind them | 54413,66833 | `banks` raises dry cells beside water by up to 3 m to keep the settled water in a bed that was cut too shallow for its flow. That patch makes its own new hollows. |
| Ponds on shelves above the river, no stream in or out | 53453,68888 | Every closed hollow draining 0.05 km² kept a lake, but a river starts only at 0.35 km², so the outlet never showed. Hollows made by later passes were never drained. |
| River with no pond, lake or cave at its head | 53724,69473 | Heads are decided by a rule ladder (pond up, pond down, cave, "kept"), and the "kept" branch left a river with no source. |
| Lake with a cave on its shore and no outlet | 55520,68920 | The cave placer searched the finished water map for heads on its own, and did not read the drainage's choice. |
| Water buried at a lip; river vanishes up close; drink prompt on dirt | 53017; 54162 | The ground is drawn with Catmull-Rom curves and the water with straight lines, so the ground bulges over the water between samples. (#523 fixes it.) |
| Fall does not flow over the top | 55200,68469 | The fall ribbon starts where the drop gets steep (about 37°). The lip between the pool and the drop is a separate thin film, and the ground can hide it. |
| Ribbed water sheets standing up banks | 54204,69155; 54849,67771 | The live sheet's dry edge vertex sat at the bank's height, not the water's. (#526 fixes it.) |
| Roar of a fall in a calm lake | (no position yet) | Falls and sounds read the baked chunk levels; the live sim may draw something else there. Two copies of the truth. |

What runs today (in `tile_baker.gd` order): erosion pre-carve → strata → scree → **water** (fill, flow, rule-placed head ponds and lakes, stamped channels, banks) → **rolling bumps and hills** → pond-level clamp → river mend → mouths → corner joins → valley drain → (in #524) hollow drain → climate → sites (caves re-detected from the water map). There are six ground-moving passes after the water, and each one needs a patch to put the water back.

## 2. The pipeline

Three stages run in order. A stage never changes what an earlier stage decided; it only reads it.

### Stage A: land, finished before any water

1. Elevation, then the world-scale erosion pre-carve (`erosion_delta`; the slow1 stream-power run from 29 Oct: K 4e-6, 4 M years). This is where valleys come from: the land is eroded by water, so it already drains.
2. Strata, scree, and the rolling ground and hills move HERE, before the water. Every bump exists before the rivers are routed, so no fade-near-water and no "drain new hollows" pass is needed.
3. One smoothing rule for the lowlands (Dave: "lumpy and unnatural") instead of three octaves of bumps: low ground gets broad swells only (wavelength 300 m and up). Short-wavelength bumps go to rock and highland only.

The output is the final ground. Nothing after this point raises or lowers it, except the river's own channel in Stage B.

### Stage B: water from the flow network (one pass, one record)

Built on the `drainage_natural.gd` stage that already exists. It is switched off today, but it was tested on all nine tiles on 30 Oct with 0 seam failures and 57 of 61 rivers reaching the sea, a lake or the edge.

1. **Route** over the finished ground (priority flood, D8 receivers, catchment). The same code runs in every frame, by world position, so tiles agree.
2. **Basins.** Each closed hollow is either a lake or filled in. It is a lake only if its catchment reaches `river_start_km2`, so a river always leaves it at its outlet. Every other hollow is filled to its spill. No rule decides where ponds go.
3. **Sources.** Every river head gets exactly one source, decided here and written down:
   - The head sits in a basin: the lake is the source (a spring in the lake).
   - The head is at the foot of, or on the side of, a hill with room under cover: a spring cave.
   - Otherwise: a spring pool. The flood fills the head's own small bowl, the same way a lake is made, only smaller.
   There is no "kept" branch. If no source fits, the head moves down its own line to the first spot that fits, and the reach above it is not a river.
4. **Channels.** Width, depth and bed come from the flow (`drainage_natural`: bed never rises downstream, parabolic section, banks blended into the land). The depth is the river's own: no extra-depth knob and no banks rule. Valley walls are the erosion's, not the stamp's.
5. **Falls** are found HERE, on the reach line: wherever the bed drops more than `fall_drop_m` within one cell along a reach, a fall is recorded with its lip (the upstream water surface), its foot and its pool. The fall starts at the lip by construction.
6. **One record per tile: the water network.** Reaches (polyline, width, depth, flow, water level per point), lakes (cells, level, outlet), sources (kind, position, flow), falls (lip, foot, pool, width, flow). It is written into the tile file next to the water map. Every reader uses it:
   - the settle and the live sim (springs from sources, outflow at outlets),
   - the falls ribbon and fall sounds,
   - the cave placer (caves only at sources of kind cave),
   - the client's water sounds and drink prompts.
   Nothing re-derives heads, falls or caves from a height map again.

### Stage C: live water draws from the network and the sim

1. The sim (8 m window and 2 m regions) is fed by the sources and drained by the outlets in the record.
2. The sheet draws the sim. Its edges tuck to the water level (#526). The ground under water is drawn bilinear, like the water (#523).
3. Falls draw from the record's falls whenever the sim has water at the lip, so a fall shows exactly when water reaches its lip. Sounds use the same test, so no roar plays without a drawn fall.
4. Caves read the record's sources, so a cave stream always joins its river at the mouth.

## 3. What this retires

| Patch today | Retired by |
|---|---|
| `river_extra_depth_m`, `max_depth_m` stamp, `_soften_banks` (#524) | B4: the depth comes from flow and the valley from erosion |
| `banks` raise (off in #524), `valley_drain` raise | A1 + B4: the land already drains to the river |
| `rolling` fade near water, `_drain_new_hollows`, `drain_hollows` (#524) | A2: the bumps come before the routing |
| Rule-placed head ponds, `_carve_basins`, `_source_spot` ladder, `_dry_unsourced` (#524), `_cut_brook` | B2 + B3 |
| `tile_pond_level.clamp_to_spill`, `tile_river_mend`, corner joins | B1 + B2: levels come from the flood itself and are never moved afterwards |
| `tile_sites._brook_heads` re-detection (#524's `cave_head` mask) | B6: the placer reads the sources |
| `water_falls.find` scanning chunk levels for drops | B5 + C3 |

The river mouths (`tile_river_mouth.gd`) stay: the sea entering an estuary is a real feature, and B can call it on the reach end.

## 4. Interim state

#523, #524 and #526 stay on their way to main. They fix what Dave sees now, and each one is a small step toward this design:
- #523 (ground drawn like the water) is permanent; it is Stage C2.
- #524 (6 m carve, no dykes, outlet-less lakes filled, cave heads from the drainage, karst and sea caves off) is the interim bake. Its `lake_needs_river_out` rule and `cave_head` mask are exactly B2 and B6 in small form.
- #526 (sheet tucks to the water) is permanent; it is Stage C2.

## 5. Work split (small PRs, each tested on David4, pictures on Dino)

| PR | What | Rebake? | Gate |
|---|---|---|---|
| P1 | Move rolling and hills before the water (A2), calm lowland bumps (A3). Water code unchanged. | Yes, 9 tiles | test_worldgen, edge_match, Dino pictures at the 7 Nov spots |
| P2 | Commit the slow1 erosion delta (A1); turn `natural.enabled` on, with routing over the finished ground. | Yes | test_drainage_natural, edge_match, river reach counts (rivers stranded ≤ 5 percent) |
| P3 | Basins and sources in natural mode (B2, B3): lakes need a river out, a source for every head, no "kept". | Yes | New test: every river head has one source; every lake has an outlet river; no hollow left dry on land |
| P4 | Falls on the reach line (B5) and the water-network record in the tile file (B6), with a tile format version bump. | Yes | Format round-trip test; every fall's lip is within one cell of water |
| P5 | Readers switch to the record: cave placer, falls ribbon, water sounds, settle springs (C1, C3, C4). | Client and server only, if P4 is in | Existing cave, fall and sound tests; Dino pictures and sound HUD at falls and lakes |
| P6 | Delete the retired patches (section 3) and their rules. | No (P2 to P5 already baked without them) | Full lane run on David4 |

P1 and P2 can be done this week. P3 and P4 are the bulk. P6 is cleanup.

## 6. Checks that prove it (run on David4 after each bake)

- No river cell whose head has no source.
- No lake without an outlet river, and no closed dry hollow deeper than 5 cm on land.
- No ground higher than the water within one cell inside a river (the "buried water" check).
- Every fall has its lip within one cell of reach water.
- Every spring cave is at a source of kind cave.
- Seams: edge_match with 0 hard failures.
