# Terrain review and proposal (Sonny, World), 2026-10-22. DOCS ONLY: no generator, tile or rule change. Freeze stays.
Dave's ask: (1) 9-tile bake max 30 min, (2) rivers and lakes from the natural lay of the land (catch basins, runoffs, brooks, streams, rivers; waterfalls only after), (3) climate by coordinates changes how water and ground behave. Order: terrain height, then water from terrain, then climate, then waterfalls.

## 0. Requirements (Dave, 2026-10-22 16:56: the water cycle) and which option covers them
Y = covered, P = partly, N = not.
| # | Requirement | A snap+deepen | B drainage from terrain | C rebuild |
|---|---|---|---|---|
| R1 | Rain and snowmelt on hillsides feed streams (melt by season and altitude) | N | Y (runoff map: rain + melt, zone coefficient) | Y |
| R2 | Streams gather water down hillsides into lakes and ponds | P | Y (flow accumulation on fine grid) | Y |
| R3 | Natural catch basins become deeper lakes (depression filling, depth from fill volume) | N | Y | Y |
| R4 | Plunge pools where steep channels land (rule from knickpoints, depth by drop) | P (today's pools) | Y | Y |
| R5 | Every lake has an outlet at its lowest rim, rivers leave lakes | N | Y | Y |
| R6 | Rivers carry water on to farmland (soak in) and to the ocean (runoff) | P | Y (infiltration by soil, rest to sea) | Y |
| R7 | Fertile flood plains: flat low land beside rivers, floods in big storms | N | Y (valley floor width from accumulation, soil alluvium, flood depth test) | Y |
| R8 | Streams, brooks and rivers good for waterwheels (steady flow, usable fall) and fishing (deep pools, slow reaches) | N | Y (per-reach flow, fall and depth tags written to the tile) | Y |
| R9 | Climate by coordinates (desert wadis, jungle dense, volcano springs) | N | Y | Y |
| R10 | Natural channel shape: deeper on the outside of bends (pools), shallow riffles and point bars on the inside, deeper at confluences and below drops, never a uniform ditch | N (one depth per width today) | Y (depth model below) | Y (erosion makes it) |
All requirements marked N in A mean A alone is not enough. B covers all ten. C covers all ten at much higher cost.
R10 depth model (option B): channel depth = base depth (from accumulation, stream power) x shape factors along the path: outer bend x(1 + k * curvature, capped 1.8), inner bend x(1 - 0.5 * k * curvature, floor 0.5) with the bed tilted across the channel (cross-section slope toward the outer bank, point bar on the inside); pool below every drop (existing plunge pool rule), x1.3 at the confluence and 3 widths below it; riffle (x0.6, wider, faster) in straight reaches between bends, spaced about 5 to 7 channel widths (natural riffle-pool spacing); small seeded noise so no two reaches match. Today: one depth per width plus a fixed floor (_stream_depth), so every reach is a uniform ditch. Option A could add the bend factor alone (curvature of the snapped path), the rest needs B's channel stage. Tile data: B stores bed depth per cell already (carved heights), no extra format.
Extra data B must write per tile for R6 to R8: reach tags (flow m3/s class, drop m per 100 m, pool depth) and a flood-plain mask, stored beside water_class (tile file section, WORLD_FORMAT_SPEC update needed).

## 1. How we make ground today (files)
Pipeline per tile (tile_baker.gd): height -> erosion -> ledges -> scree -> water -> climate -> geology -> sites.
- World level (once): world_elevation.gd builds a 160 m elevation map from the sketch; river_network.gd runs priority flood + drainage area on that 160 m map and makes river chains (threshold river_start_km2 = 0.5 km2, "rain falls evenly").
- tile_height.gd: Catmull-Rom upsample of the 160 m map to 8 m + detail noise.
- tile_erosion.gd: priority flood + stream power + diffusion on a 32 m copy, rock hardness from tile_geology.
- tile_water.gd (2,135 lines): the world's 160 m river chains are drawn as curves, each carved into the 8 m ground as a guide (width, bed, banks), plus premade head ponds, plunge pools, chutes (terrace), estuary. Climate (tile_climate.gd) runs AFTER water and does not influence it.

## 2. What is wrong (measured on baked tile 3,4, v25; probe in my scratchpad, to be committed as a probe)
- Rivers are drawn, not found. Of 2,079 river cells (32 m grid) only 663 (32%) lie on a channel the fine terrain would drain to (flow area > 0.5 km2), 463 more (22%) are within 64 m, so 46% are more than 64 m from where the ground itself drains. The 160 m path is carved into an 8 m land that does not agree with it.
- A 2 m rise floods 6 times the wet area: 2.0 km2 of river and lake cells grow to 12.9 km2 within 384 m. Valleys are shallow compared with the river size, so water leaves the channel (Dave's "2 m floods everything").
- Relief is not low overall (tile 3,4: 0.1 to 691 m, 8% of land steeper than 30 deg, only 11% under 2 deg) but it is uneven: the spawn 1 km box is 20% under 2 deg and 77% under 5 deg, height 1 to 308 m. The flat lowlands are where the rivers go, the steep land is where they come from, with few middle valleys.
- Natural basins exist but are ignored: 1,912 coarse cells are pits (2.8 million m3 to fill, deepest 20.5 m), yet lakes are premade (head ponds, plunge pools). Pools do not guarantee an outlet at the lowest rim (the south spill, build 617).
- Climate has no say: one river threshold and equal rain everywhere; desert, jungle and volcano get the same river rules.
- Bake time (cloud, one tile): setup 65 s once, tile 139 s: erosion 69 s (50%), ledges 18 s, water 16 s, climate 12 s, height 10 s, geology 9 s, scree 3 s. Estimate 9 tiles = 65 + 9 x 140 s = about 21 min single-thread on this machine. Threading plan (Steve_ProblemSolver's advice): (1) one tile per thread (WorkerThreadPool or Threads, cores minus 1): each tile erodes its own 32 m copy, 4 cores gives about 3x, so 9 tiles in about 8 to 10 min. (2) Safe in GDScript: pure functions over PackedFloat32Array, no node access, no shared RNG or noise objects; each tile seeds its own from (master seed, tile id). (3) Determinism: fixed erosion order, priority-flood ties by fixed index, no dictionary iteration order, results joined in tile order. (4) Edge rows are the hash risk: two-pass scheme (all tiles, then a border blend in tile order on the main thread) or keep border logic single-threaded; check identical hashes with 1 vs 4 threads before trusting the speedup (acceptance test 6). (5) Timings are from the cloud box. NOT measured on Dave's PC: MikeW to time one tile there and the full 9 (ask via coordinator). Under 30 min likely, but erosion is the part to speed up (threads per tile, 4 cores gives about 8 to 10 min).

## 3. Options (cost in work and bake time; sources at least 3 each; sources noted as "title read" were found by search, not read in full)
### A. Snap and deepen (small, days)
Keep everything. Snap each guide river to the nearest fine-terrain drainage channel before carving, deepen channels where flow is high, raise detail relief slightly. Lakes still premade, climate still cosmetic.
Cost: about 3 days; bake time unchanged. Fixes the 46% mismatch partly; does not fix premade lakes or climate.
Sources: Barnes 2014 Priority-Flood (https://ar5iv.arxiv.org/html/1511.04463); landlab FastscapeEroder doc (https://landlab.readthedocs.io/en/latest/reference/components/stream_power.html); Red Blob Games river drainage basins (https://www.redblobgames.com/x/1723-procedural-river-growing/).
### B. Drainage from the terrain (medium, 1 to 2 weeks) RECOMMENDED
Keep world sketch, 8 m height and erosion. Replace guide-carving with a drainage stage on the eroded fine grid (16 m): (1) priority flood with outlet recording, so every depression becomes a lake filled to its lowest rim and the spill point IS its outlet; (2) flow accumulation, rivers where accumulation x runoff coefficient passes a threshold; (3) incise channels by stream power (depth grows with accumulation) so valleys are deeper than the water they carry; (4) climate runoff: precipitation from the existing wet-air field times a coefficient per biome zone (desert near 0.05 with ephemeral wadis, temperate 0.4, jungle 0.7, volcanic rock high infiltration: springs at the base, lava channels separate); (5) waterfalls last: knickpoints where the incised channel slope passes a threshold, one chute plus plunge pool as today (BP-C31).
Cost: new stage about 600 lines replacing about 1,200 of tile_water.gd guide/pond/terrace code; bake +10 to 30 s per tile in GDScript (priority flood and accumulation on 0.9 M cells), water stage drops as carving shrinks, net about +0 to 20 s. Rebake 9 tiles, re-settle water (nine files), flora and cover re-place, saved test digs may no longer line up (test world only).
Sources: Cordonnier et al. 2016 uplift and fluvial erosion (https://hal.archives-ouvertes.fr/hal-01262376); Barnes 2014 Priority-Flood (https://ar5iv.arxiv.org/html/1511.04463); landlab PriorityFloodFlowRouter, fill or breach a DEM and accumulate flow (https://landlab.readthedocs.io/en/latest/_modules/landlab/components/priority_flood_flow_router/priority_flood_flow_router.html); Uni Bremen, landscapes with water bodies from artificial drainage basins (https://cgvr.informatik.uni-bremen.de/theses/finishedtheses/proceduralWaterBodies/); climate controls on river network branching (title read, https://stars.library.ucf.edu/scopus2015/10282).
### C. Rebuild the foundation (large, 4+ weeks)
World-scale uplift map plus stream-power erosion run for many steps (Cordonnier/FastScape style), tiles cut from the eroded world. Everything consistent, best long-term, climate fed into the erosion rate (wetter = more incision).
Cost: new world solver, more bake time (world pass minutes, per-tile faster), all tiles and the sketch redone, starter town re-found. Risky for a friend-session target.
Sources: Cordonnier 2016 (above); Braun and Willett 2013 FastScape implicit stream power (landlab doc https://landlab.readthedocs.io/en/latest/reference/components/stream_power.html and EGU abstract https://meetingorganizer.copernicus.org/EGU2013/EGU2013-6718.pdf); Physically-based analytical erosion for fast terrain generation (https://diglib.eg.org/handle/10.1111/cgf15033).

## 4. Recommendation
B. It fixes the cause Dave named (rivers from the land, lakes with natural outlets, climate-aware) at moderate cost and keeps the starter sketch and Dave's tile scope. Do A's relief and snap steps inside B only if B slips. Drop my held spill-chute patch under B (outlet by rule replaces it); keep its saddle finder idea. C only if Dave wants the whole world rebuilt after the friend session.
Prototype plan (no tile commits): one tile (3,4) in MikeW's second clone, flag-gated, compare with tools below.

## 5. Acceptance tests (all runnable headless; to be added to the probes folder)
1. Rivers flow downhill: bed never rises along a chain (existing river_min_fall test stays).
2. Every lake has an outlet at its lowest rim: for each filled depression, the spill cell is the lowest rim cell and a river starts there; a dry sim finds no second spill (generalises test_head_pond_fill).
3. 2 m flood test: raise all river cells by 2 m, flood within 384 m must stay under 3x the wet area (today 6.3x) on tile 3,4.
4. Drainage agreement: at least 90% of river cells within 64 m of a fine-terrain accumulation channel (today 54%).
5. Climate: desert tile shows fewer, ephemeral channels; jungle denser; same terrain, different runoff coefficient (unit test on one synthetic tile).
6. Bake: 9 tiles at or under 30 min on Dave's PC (MikeW timing), edge match on all 8 borders, tile hashes stable run to run.
8. Water cycle (R1, R2): a rain-and-melt run on one tile delivers more water to each lake than its direct springs; catchment area of every lake is above 0 and lakes high in snow zones fill in spring.
9. Catch basins and pools (R3, R4): every natural depression deeper than 2 m becomes a lake, deepest point at least 60% of fill depth; every chute lands in a pool at least 2 m deep and 0.4 x drop (cap 4 m), as today.
10. Soak and runoff (R6): water mass balance on a 6 h dry sim: spring + rain = evaporation + soaked + ocean outflow within 5%; farmland cells within 200 m of a river show a soaked-water value above the rest.
11. Flood plains (R7): a 3x storm flow floods a flat strip beside rivers (soil alluvium, fertility high) and stays at least 100 m away from the spawn hill and village; flood depth below 2 m outside the plain.
12. Waterwheel and fishing reaches (R8): at least one reach per river with flow class and fall tagged; at least one pool of 3 m depth with slow flow per major river.
13. Natural bends (R10): on 20 or more bends per tile, mean bed depth on the outer third of the channel at a bend apex is at least 1.3x the straight-reach depth, and the inner third at most 0.8x; pool depth below every drop at least 0.4 x drop; riffle and pool depths alternate in straight reaches (variation of depth along a straight reach at least 20%); two reaches of the same width never have the same depth profile (no copy).
7. Settled water: 6 h dry sim has no flooding of the starter plains beyond rivers and lakes (soak test).

## 6. Needs from others (via the coordinator)
- MikeW: time one tile and the 9-tile bake on Dave's PC now (baseline).
- Steve_ProblemSolver: advise on threading erosion across tiles and the per-tile cost.
- Tyler_Guru: BP check (BP-T32) of this review, then the 3-option card for Dave.
