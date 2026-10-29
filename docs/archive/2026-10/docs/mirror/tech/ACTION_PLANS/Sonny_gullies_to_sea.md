# Sonny action plan: more gullies carved by river systems (one plan, whole class)

Branch: claude/sonny-foothills. Class: valley, canyon and gully carving along the drainage network (drainage_channels.gd _valleys, _canyons, _heads; tile_rules water.drainage keys; erosion hardness).
Dave 24 Oct 03:39 UTC: mountainous style approved; "more gullies carved by river systems running out to the oceans".

## Plan (numbered)
1. Lower the start catchment for valleys and canyons (valley_start_km2 1.0 -> 0.4, canyon_start_km2 0.6 -> 0.3) so smaller streams carve gullies too.
2. Depth scales with catchment and rock hardness: soft rock cuts deep, hard rock stays narrow (reuse the tile_erosion hardness table and hardness_by_height); cap stays canyon_cut_max_m 90 and rim 160.
3. Gully density: add a second, small-stream tier (catchment 0.1 to 0.4 km2) cutting 3 to 12 m V-shaped gullies on slopes over 8 degrees only, so plains stay clear.
4. Keep the checks safe: spawn_keep untouched, river gate (Sal), steep share <= limit, every land region reachable (gully walls <= 45 deg).
5. Test: Mike 1-tile bake of (3,4); Sal tile table; compare steep share and gully count per km2 before/after in one labelled row.
6. Rides in the single 9-tile rebake with the seam fix and the climate beaches.

## Question for best practice (one reply please)
- Is a second small-stream tier better than only lowering the thresholds (noise vs control)?

## Tyler reply (24 Oct 03:50 UTC) GO, with these changes (answered once)
Answer to the question: YES, a second small-stream tier is better than only lowering thresholds, with one condition: it must be driven by the same flow network (catchment), not by free noise. Lowering thresholds only makes the existing valley profile appear on more cells, so every gully looks alike and the count jumps in steps; a separate tier with its own width/depth curve gives control over density and shape. Free noise would break "carved by river systems running out to the sea" (Dave's words) because gullies would not connect to anything. Real landscapes show drainage density and channel width following a power law of catchment (Hack's law, slope-area scaling, standard in landscape-evolution models), so tier depth should be a smooth function of catchment, not a switch.
Improvements:
1. One curve, three zones: depth = f(catchment) continuous from 0.1 km2 up through valley and canyon, with hardness as a multiplier. Do not hard-switch at 0.3/0.4 km2; blend over a band, or the tier boundary shows as a step in the wall height.
2. Every gully must drain to a river or the sea: add a check row to island_checks (follow each tier-2 channel downhill, count how many end in a sink that is not water). Target 0 dead ends, or list them, as with the river ends.
3. Slope gate over 8 degrees: use a smooth ramp 6 to 10 degrees so there is no seam at 8, and keep the 45 degree wall limit measured, not assumed.
4. Lower thresholds in stages and measure: valley 1.0 to 0.6, then to 0.4; look at steep share and gully count per km2 at each stage in ONE labelled table, so you keep the lowest setting that gives the look, not the maximum.
5. Seam safety: gullies depend on catchment, so this plan needs the seam edge-flow fix first (Sonny_seam_edge_flow). Order the code: seam seeding, then gullies; one 9-tile rebake (as you planned), test seams (heights under 0.5 m) on the gully tiles specifically.
6. Cost: report bake time and tile size before and after (BP: generation time and tile size reported); a fine tier can grow tile size.
Label BAKE (TERRAIN_VERSION bump). Test: Mike 1-tile bake (3,4), then Sal table. Go.
