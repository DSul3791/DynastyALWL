# Island shape plan (Sonny + Guru, 23 Oct, Dave's "flat then a wall" note)
Companion to ISLAND_SHAPE_RESEARCH.md (Guru: real islands, types table). This file: my sources, why OUR land is flat-then-wall, what the generator can do, cost, and the joint plan.

## 1. What Dave is looking at (correction)
The screenshot (x 52361 z 68193, build 727) is NOT the centre island. It is the inner starter island, id 8 in island_list.json, tile (3,4), peak 707 m, 95.7 km2, feature shelf_p_p. The same beach profile is used by every starter island. The centre island (tile 0,0) is a separate case (see 5).

## 2. Why it is flat then a wall: it is our profile formula
world_elevation.gd `_island_height` (beach side): for the first 50% of the way from coast to peak (`plain_width` 0.5) the ground is a ramp of only 28 m (`plain_m`), then it climbs to the peak with `pow(x, 0.75)`. An exponent under 1 is steepest right at its start. Worked example, starter island, about 4.7 km coast to peak, peak 560 m:

| metres inland | now | proposed |
|---|---|---|
| 300 | 5 m | 6 |
| 1000 | 13 | 40 |
| 2000 | 25 | 131 |
| 2350 | 28 | 172 |
| 2600 | 127 | 205 |
| 3500 | 339 | 339 |
So from 2350 m to 2600 m the ground jumps 100 m in 250 m (about 22 degrees), straight after 2 km of near-flat. That is exactly Dave's picture. Real islands do the opposite: a concave curve, gentle at the beach, steeper steadily inland.

## 3. Real islands (sources fetched today)
- Shield volcano flanks are 2-3 degrees at the base, steepening to about 10 degrees, flat only near the summit; height about 1/20 of width ([Wikipedia, Shield volcano](https://en.wikipedia.org/wiki/Shield_volcano); Mauna Loa also about 1 in 9 overall, [App State](https://appstate.edu/~abbottrn/vlcns/vlcnos.html)). So even the gentlest big island climbs from the shore.
- Hawaii by age ([UH landforms](https://www2.hawaii.edu/~dennis/GeoLab_online/landforms/landforms.htm), [UH natural environment](https://www2.hawaii.edu/~dennis/GeoBook/chapter11/hawaii.htm)): young = well spaced steep V valleys with wide flat original slope between; middle = valleys widen into amphitheatre heads; old = flat plains near sea level and tall palis (Kauai Napali sea cliffs over 4,000 ft, Waimea Canyon over 3,600 ft, [Kauai numbers](https://kauaiseatours.com/kauai-by-the-numbers-island-dimensions-that-matter/)). Kauai is roughly circular, 33 x 25 miles, summit 5,243 ft.
- La Reunion Mafate cirque: about 15 x 8 km, walls from several hundred m to over 1,000 m, peaks 2,200-2,950 m, lava stack 900-1,000 m thick ([Univ. Reunion](https://geosciences.univ-reunion.fr/fileadmin/Fichiers/geosciences/Research_activity/Geosites/Geomorphologie/Mafate.pdf)).
- Japan: mountains over 80% of land, short fast rivers, towns in narrow valleys and few coastal plains ([Stanford SPICE](https://spice.fsi.stanford.edu/docs/geography_of_japan)).
- NOT found online: ridge spacing, foothill widths, exact elevation-vs-distance. Numbers like Guru's 20-60 m in the first km and 150-400 m by 3 km are judgement; they match common maps but are unsourced. Pages gave no spacing numbers, so valley spacing below is a starting guess, to tune by looking.

## 4. Island types and what we already have
The sketch already makes most types (sketch_rules.json): hotspot chains (young high, old atoll after age 0.55 when warm), volcanic arcs (peak 250-1450 m, steeper), continental shelf hills (rounded, 270-740 m, long beaches), seamount islets (10-260 m), mid-ocean ridge. Missing: glacial/fjord, fault-block (one steep side), delta/barrier flats. The starter islands add a beach side (equator-facing) and rocky side (poleward).
Danger already steepens things (`danger_effects`: profile_exponent 0.9-1.6, cliff 0-140 m, shore shelf 600-120 m).
Agreed with Guru: add a `type` per feature that picks a profile set, not one formula for all.

## 5. Generator: what each step costs
1. Profile fix (the main one): change beach branch in `_island_height` to a concave curve `peak * u^e` (e about 1.5-1.8), keep only a thin terrace (about 8% of the way, 5-10 m) at the beach. Files: world_elevation.gd + sketch_rules.json (`profile_exponent`, `plain_width` 0.5 to 0.08, `plain_m` 28 to 6). Cost: small edit, rerun tools/build_sketch.gd (about minutes), tests. EFFECT: every island's 160 m heights change, so the 9 tiles must be rebaked. Spawn and buildings sit on those tiles: fine pre-launch, saved digs shift, Dave clears.
2. Foothill belt: the existing ridged noise (`0.18 * peak * inland * ridged`) already scales with height; raise it in the middle band, add radial ridges toward the coast. Cost: same rerun, tune by section pictures.
3. Valleys before ridges: Terrain B rivers already follow the 160 m land; stage 3b (valleys deeper than the water they carry) cuts real V valleys into the new foothills. This stage is already on my list; the new profile makes it worthwhile (today rivers cross a flat plain).
4. Rocky vs beach side: exists (facing); extend with "beach only where slope under 5 degrees plus a river or bay" (needs a coast pass after step 1).
5. Centre island: today a broad shield of peak 480 m (`exp` 0.85) plus a steep cone, radius 0.48 of the half width, apex set so the rim is 1,900-1,981 m. Same flat-then-wall problem. Fix: lower cone share, widen the cone skirt, concave shield (Kauai/La Reunion look: ridges and a cirque or two).
6. Test: 1-tile bake by MikeW in the second clone (BAKE-1), then Tyler schedules one batched 9-tile bake (Dave said rebuilds no longer need his permission, BP-T48; Guru decides timing).
Not possible now without bigger work: windward/leeward wetter side (needs climate hook per feature), fjords, fault-block tilt. Park.

## 6. Result of steps 1-2 (branch claude/sonny-island-shape, 23 Oct 15:45 UTC)
Finding changed the fix: the wall was not the starter formula (my first edit changed nothing on tile 3,4) but the shelf hills, which stood untouched inside the island next to the flat plain. New `_shape_coast_profile` in world_elevation.gd caps heights near each starter island by a concave function of distance from the sea (chamfer distance on the 160 m grid): cap = 6 + 340 * (d/3500)^(1.7*0.91) m. The beach terrace is now 6 m / 8%. Rules: sketch_rules.json starter_islands beach_profile_exponent 1.7, beach_cap_m 1100.
West-coast line from spawn toward the peak (160 m map), metres inland: height. Before: 0:27 600:43 1000:65 1200:405 2000:523 3000:701. After: 0:27 600:43 1000:65 1200:121 2000:179 3000:297 3400:344. Island peak now 398 m (was 707): inside the starter peak rule (300-560). Spawn (53301, 68427) is about 440 m inland on this line: 30 m, gentle.
Needs: sketch + tile plan + island list regenerated (committed), TERRAIN_VERSION 26 (Tyler approved), 1-tile test bake of (3,4) by MikeW, then 9-tile bake. Foothill ridges (step 2 proper), valleys, coast rules and centre island still to do after seeing the bake.
