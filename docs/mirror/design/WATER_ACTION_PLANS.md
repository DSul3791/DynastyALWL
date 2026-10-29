# Water action plans (one per branch, for Tyler)

Rule BP-T52/T53: one plan per branch, a class of small things (now 6 with the catch-basin rule), Tyler answers once, then the thread does all of it. No merge, no bake during devstop. Design: WATER_LAND_TYPES.md (decisions in section 9).

## Plan 1: branch claude/water-r1-landmap  (R1 + dam test)
Owner: Steve (water code) with Sonny (baseline check). Cloud only, no tile baking.

1. **Signature (src/water):** per live tile, three 1-byte decayed averages per 8 m cell (depth, speed, wet share), updated once per game hour on the water thread over wet cells only; time constant about 30 game days. Saved at tile unload and about every 10 real minutes in a new versioned file next to the DWAT file. Counting starts only after the tile's settle stop test; a missing file means "natural".
2. **Classifier (pure function, with tests):** from signature + baked water_class, biome (marsh, peat), soil, moisture -> lake / river / marsh / swamp / bog / floodplain / dry (thresholds table, section 2; baked river/lake class is a floor; lake label needs 4+ joined cells). Headless test on the nine starter tiles, no NaN, no change on a dry-start refill.
3. **Admin overlay:** one admin toggle that colours the land types on the ground, so Dave can see the map. No plant change, no protocol change.
4. **Fish and drinking hook:** the classifier also answers "fishable water here?" (lake or deep river cell) for the spawn-point probe (Mike) and Sal's shore net. Read only.
5. **Dam test (headless):** add the sim-side set-ground-height step; scripted fills across a gully reach at least 1 km from tile edges; measure the water level upstream before and after; report whether it backs up. No barrier records yet.

6. **Catch-basin rule (Dave 24 Oct):** every spring (head, plateau move, feeder) must sit in a natural basin: at least 0.5 m below the lowest cell of the ring 3 cells around, else slide down the painted channel to the lowest painted cell within 10 cells; the admin overlay marks springs that fail; a settle test fails any tile whose wet sheet at a spring is much wider than the painted channel. Sonny owns the bake-time basin carve and a higher valley-floor freeboard on flat reaches (0.4 m to about 1.0 m where fall is under 2%), since the pond at x 53840 z 68520 is settled water spreading over a flat valley floor. Springs that cannot be fixed are listed for Sonny (basin carved at bake time, later bake). The dam test site must pass this rule.

Test: `test_water_land.gd` (tests 2 and 5) in tools; local_check clean; parse scan first. Risk: 11 MB per live tile of memory; cap check against the 1.2 GB limit. CHANGE_LABEL RESTART (server water code), no BAKE.

## Queued (one plan each, sent after Tyler answers Plan 1)
2. claude/water-stability (P1b): time step from wave + flow speed, outflow limited to donor water, scripted 3 m pond breach, mass balance test.
3. claude/water-plants (R2): biome rows swamp/bog/floodplain, per-type weights, wet/dry tolerance in flora.json, flora layout VERSION bump, new species and peat item (Kathleen, Sal).
4. claude/water-dams (P2): barrier records, load and capacity, warning, slow breach.
5. claude/water-succession (R3): node records, dead/sapling state byte (protocol number from Steve), chunk refresh, farmland flood timer (farm_flood_days = 14), dead-tree models.
6. claude/water-washaway (P3): client sweep, server damage check, item sync, structure ratings.
7. claude/water-bridges (P4): ford, plank, stone with piers, flood stage per river (Sal).

## Tyler reply to Plan 1 (once, 24 Oct 19:50 UTC) - GO
Approved: claude/water-r1-landmap (R1 + dam test), RESTART, no bake. Conditions: (1) memory: the 11 MB per live tile must be measured and stay under the 1.2 GB water limit; report the number. (2) Counting starts only after the dry-start settle, as planned; a missing signature file must never change the water. (3) The signature file is versioned; old saves load. (4) The "fishable water here" answer (item 4) is the ONE classifier fish plan B calls; say so in the notes. (5) Dam test is headless only and reports whether it backs up; no barrier records. (6) Tests: test_water_land.gd, test_water_flow/settle tests unchanged green, local_check 233, parse_scan; David3 runs them. Merge in 793 with fish A/B. Plans 2-7: send one per branch after this lands; P1b first.

## Tyler amendment (24 Oct 19:58 UTC) - Plan 1 now 6 items, still GO
Item 6 (catch-basin rule) confirmed. Steve's code part: overlay marks failing springs, settle test fails a tile whose wet sheet at a spring is much wider than the painted channel, failing springs are listed for Sonny. Basin carve and freeboard raise are Sonny's BAKE work (final bake 792), not in the 793 code merge. Dam test site must pass the rule. Same label RESTART, same tests, same one-answer rule.
