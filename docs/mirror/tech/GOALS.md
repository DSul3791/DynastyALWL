# GOALS (Tyler, 24 Oct 2026 01:35 UTC; from Dave's ruling 01:24 and BIG_PICTURE, DESIGN_PRINCIPLES, ART_DIRECTION, ISLAND_SHAPE_PLAN, ITEMS_DESIGN, PROJECT_ROADMAP)
High-level only. Detailed jobs are decided day to day in tech/JOBS.md and in action plans (BP-T52). The first goal on your list is the ONLY thing that matters.

## The rule (Dave)
1. Everyone works the FIRST goal on their list above all else, OCD-diligent, never idle, awake at every half-hour reminder.
2. If you must break off for a reason, hand that work to a subordinate (Sal or Mike) and keep advancing goal 1. The subordinate works while you carry on with goal 1.
3. A goal moves to "Goals completed" ONLY when it is truly done (Tyler confirms with the check named in the goal). Only then does the next goal become first.
4. Today's island terrain job stays top for Sonny and Sal until it is complete.
5. Moderator reminder every 30 minutes: "awake, not idle, first goal first, update your scratch pad".
6. SCRATCH PAD (Dave 01:26): every agent keeps /mnt/project-files/goalpads/WhatamIDoingtoReachMyGoal_<Name>.txt (Kathleen, Sonny, Sal, Steve, Mike, Tyler; already created). It holds the finer steps toward goal 1, what was handed off and to whom, and DONE lines with a UTC time. Read it first after any reset, update it at job start, at each finished step and at every half-hour reminder. Tyler mirrors the pads to docs/mirror/goalpads/ at the 8 AM handoff.

## Kathleen (art + sound)
1. Simple, reasonably accurate-to-real models for EVERYTHING in the game that needs one (plants, trees, tools, items, building pieces, creatures, characters).
2. Upgrade every model to a reasonably better-looking version of the real thing.
3. Upgrade everything again to almost photorealistic quality for fantasy medieval.
4. Complete basic sound set: every creature, tool, material and ambience has a sound (Dave's recordings first), levels balanced.
5. Sound upgrade to near-real quality, fully 3D positional with Steve's engine.
Completed: (none yet)

## Sonny (world + water)
1. ISLAND TERRAIN (today's job, Dave 00:47): grand, varied, unpredictable islands: epic mountain ranges, passes, gullies, foothills, rolling prairies, ancient ravines and canyons, volcanoes, sprawling beaches on hot islands, rocky shores on polar islands, different peak layouts per island. Done when the checks table passes and Dave approves the baked island.
2. Every planned island designed, baked and checked (types table, 9-tile bakes through the second clone, seam-free).
3. Water world complete: rivers rise in ravines and reach the sea, lakes, floods, tunnels flood, rain closes the loop.
4. Flora and ecology across biomes: patches, altitude and slope rules, seasons, fruit by season.
5. Resource richness: ore, caves, ancient ravines and canyon features worth exploring.
Completed: v26 and v27 world bakes delivered (builds 764, 772; Dave's look still to come)

## Sal (items, crafting, buildings; subordinate for Sonny's island job)
1. ISLAND JOB (dedicated, Dave 00:47): island checks, types tables, per-island layouts, tests; take the sub-jobs Sonny hands over.
2. Every item in the game exists with recipe, cost, inspect text and a working use (survival to medieval trades), nothing shown that cannot be used.
3. Complete building system: blueprint build (all tiers, foundations, walls, doors, windows, ceilings, roofs, braces), sawmill chain and stations.
4. Farming and harvest: pick, uproot, replant, patches, hoe grade, seasons.
5. Hire-it-out economy hooks (design principle 2): jobs doable by hand or by NPC, coins.
Completed: showroom real items (build 773, Dave to confirm in game)

## Steve (server, network, performance, water code, rig)
1. Always playable: no build reaches Dave broken, F2 Low frame time under 33 ms on the 1050-class minimum machine, start-up smoke test in every merge.
2. Friend-session multiplayer solid: server, network, saves, join, sync, admin tools separable.
3. Water simulation and tunnels correct: water_flow_at, dry river fixed, collapse, drainage.
4. Sound engine: directional 3D sound for everything, HUD readout, mixer.
5. Test rig that measures and photographs everything in one labelled row (--flora, --pieces, --views).
Completed: parse_scan, water_flow_at, sunny switch (builds 771)

## Mike (testing, PC, bakes, backups; subordinate)
1. One-gate testing: one hourly merge-check batch on a fixed list with a PASS/FAIL line per branch; every test groupable (TEST_RECIPE).
2. Bakes through the second clone: bake, commit, push claude/mike-bake-*, never copy into Dave's folder (BP-T53).
3. Reliable nightly backup (9 pm ADT) and 8 AM reset; permissions file working so no run is refused.
4. Frame-time baseline per build on the test machine.
5. Rig coverage for every system: nothing is tested by hand twice.
Completed: v26 and v27 tile bakes, 9-branch merge check (builds 771, 772, 773)

## Tyler (process, merges, docs)
1. Zero broken builds reach Dave: merge_check, parse_scan, local_check and Mike's PASS before every merge.
2. Efficiency: one plan per class of work, QA page clean (no repeat questions), daily audit with targets met (tech/AUDITS).
3. Ready queues and goals current; every thread always has a next job.
4. Documentation current: HANDOFF, DECISIONS, TEAM_AND_RULES, BEST_PRACTICES, daily handoff at 8 AM Atlantic.
5. Release readiness for the friend session: repo private (numbered steps), hosted page, backups.
Completed: builds 747-773 merged and logged; BP-T50 to BP-T53 written
