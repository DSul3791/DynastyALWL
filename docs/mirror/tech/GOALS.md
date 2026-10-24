# GOALS (Tyler, rewritten 24 Oct 2026 01:45 UTC after Dave 01:29: "Tyler breaks the ultimate goal into smaller goals per role, reachable on a daily basis")
Checked against DESIGN_IDEAS (sections 4 world, 5 farming/crafting/skills, 6 characters/senses/sound, 7 time, 8 towns/NPCs, 9 law, 10 building/fire, 11 production, 12 threats, 13 economy), ART_DIRECTION, ITEMS_DESIGN, DESIGN_PRINCIPLES, BIG_PICTURE.

## ULTIMATE GOAL (whole team)
An amazing, well-rounded game that fits our design documents: a persistent rough-medieval multiplayer world with a "Sims vibe" (survival, exploration, town building, family and dynasty), safe-kind-generous, near-photoreal fantasy look, many islands worth travelling to. Present focus stays: movement, physics, water, tunnels, ready to play.

## The rule (Dave)
1. Everyone works the FIRST goal on their list above all else, OCD-diligent, never idle, awake at every half-hour reminder.
2. Break-offs go to a subordinate (Sal or Mike) while you keep advancing goal 1.
3. A goal moves to "Completed" ONLY when it is truly done (its "Done when" check, confirmed by Tyler). Then the next goal becomes first.
4. Today's island terrain job stays top for Sonny and Sal until complete.
5. Moderator reminder every 30 minutes: awake, not idle, first goal first, update your scratch pad.
6. SCRATCH PAD: /mnt/project-files/goalpads/WhatamIDoingtoReachMyGoal_<Name>.txt holds the finer steps toward goal 1 (read after any reset, update at job start, step done, and every reminder). Tyler mirrors pads to docs/mirror/goalpads/ at 8 AM.
7. Every goal below is DAILY-SIZED: one working day. If a goal turns out bigger, Tyler splits it the same day, in this file.

## SONNY. Ultimate: the epic fantasy land, caves and oceans we play on, filled with cool resources and reasons to travel the world gathering and exploring.
1. ISLAND 1 TERRAIN (today): ranges, passes, gullies, foothills, prairies, ravines, canyons, volcanoes, beaches. Done when Sal's check table passes and Dave approves the baked island.
2. CAVES: natural cave systems and lair sites (4.4), depth and heat (4.5); walkable, with water and ore. Done when one island has caves a player can enter, explore and come out of, table passes.
3. OCEANS AND COASTS: sea floor sketch (4.12), at sea (4.11), sandy beaches on hot islands, rocky shores on polar, temperate mix. Done when you can swim or sail from the coast to open deep water and the shore types match the island climate.
4. RESOURCES AND TRAVEL REASONS: geology and surveying (4.9): ore veins by region, different regions hold different things, clues and follow-the-vein hooks, so players want to travel. Done when a resource map lists what each region offers and the generator places it.
5. ZONES AND LIFE: climate zones (4.2), soil/flora/fauna (4.3), danger by region (4.13). Done when every zone has its flora set, fauna list and danger rating.
6. WATER WORLD: rivers from ravines to the sea, lakes, floods, flooding tunnels, rain loop. Done when the dry-river and river-to-sea checks pass on all baked tiles.
7. ISLAND 2, 3, ... one per day: a different peak layout each (central peak, three peaks end to end, ...), types table row, checks, one-tile test, 9-tile bake.
Completed: v26 and v27 world bakes delivered (builds 764, 772)

## SAL. Ultimate: everything a player can make, build, grow and trade works, is fun, and fits the design (crafting, building, farming, production, economy).
1. ISLAND JOB (dedicated): island checks, types tables, per-island layouts, sub-jobs from Sonny. Done when the check table runs on every bake.
2. ITEM COMPLETENESS: audit every item: recipe, cost, inspect text, use, model name. Done when the audit table has no empty cell for the items in the game today.
3. BLUEPRINT BUILD 1c: all tiers, foundations, walls, doors, windows, ceilings, roofs, braces with their look names (10.1). Done when each piece can be built in a test world.
4. FARMING AND HARVEST (5.1, 5.2): pick, uproot, replant, patches, hoe grade, seasons. Done when a small farm runs a full season in the rig.
5. PRODUCTION CHAIN: sawmill step 2 with water power, woodworking table, mine chain (11.1, 11.2). Done when logs become boards through the chain.
6. SKILLS AND CRAFT PROGRESSION (5.3, 5.4). Done when a crafted item's quality depends on the skill.
7. ECONOMY HOOKS (13, design principle 2: do it yourself or hire it out): coin values, a job doable by hand or by NPC. Done when one job works both ways.
Completed: showroom real items (build 773, Dave to confirm in game)

## KATHLEEN. Ultimate: the world looks and sounds like near-photoreal fantasy medieval (ART_DIRECTION), on the minimum machine.
1. SIMPLE ACCURATE MODELS FOR EVERYTHING, in daily batches: 1a inventory of every thing needing a model with status (day 1); 1b flora (shrubs, herbs, mushrooms, trees); 1c items and tools; 1d building pieces and stations; 1e creatures; 1f characters and clothing. Done when the inventory shows a model for each row.
2. UPGRADE EVERY MODEL to a reasonably better-looking real thing, same batch order. Done when Dave approves a before/after row per batch.
3. UPGRADE AGAIN to almost photorealistic fantasy medieval, in the same order, with triangle budgets and LODs.
4. BASIC SOUND SET: every creature, tool, material and ambience has a sound (Dave's own recordings first). Done when the sound manifest has no empty slot.
5. SOUND UPGRADE: near-real quality, 3D positional with Steve's engine.
6. WORLD LOOK PASSES: grass, water, weather, time of day, ground textures per ART_DIRECTION, each a day-sized pass.
Completed: (none yet)

## STEVE. Ultimate: a fast, stable, safe multiplayer engine so the friend session is playable, with tools that measure everything.
1. ALWAYS PLAYABLE: start-up smoke test in every merge, F2 Low frame time under 33 ms on the minimum machine. Done when 3 builds in a row start clean and meet the number.
2. REAL-TIME WATER AND TUNNELS: water_flow_at users, dry river, collapse timer, drainage. Done when the live dump in Dave's world shows flowing rivers.
3. SOUND ENGINE: directional 3D sound for everything, HUD readout, mixer. Done when Dave confirms direction by ear.
4. MULTIPLAYER SOLID: join, sync, other players' worn clothing, save integrity, characters.json batching, admin tools separable.
5. SENSES AND MINIMAL HUD (6.14): prompts, inspect, readable on a 55-inch 4K display.
6. RIG: look_rig flags for every kind of row (--flora, --pieces, --views). Done when a request can be photographed without code.
7. FRAME-COST BUDGETS for flora, water, sound per quality tier (ARCHITECTURE_BUDGET).
Completed: parse_scan, water_flow_at, sunny switch (build 771)

## MIKE. Ultimate: nothing reaches Dave untested, and every system is verified by the rig, not by hand.
1. HOURLY MERGE GATE: one fixed list, a PASS/FAIL line per branch (MERGE_CHECK_NEXT.md pattern). Done when no branch waits more than 2 hours.
2. BAKES THROUGH THE SECOND CLONE (BP-T53): bake, commit, push claude/mike-bake-*; never copy into Dave's folder.
3. PERMISSIONS, BACKUP AND RESET: user-level settings working, 9 pm ADT backup, 8 AM reset, no run refused.
4. FRAME-TIME BASELINE per build in one table.
5. RIG COVERAGE: one new groupable test per day (T-GROUND, T-BERRIES, pieces row...), until every system has one.
6. WEEKLY REGRESSION: the whole test list in one run, one pass/fail table.
Completed: v26 and v27 tile bakes; merge checks for builds 771, 772, 773

## TYLER. Ultimate: the team ships a well-rounded game that matches the design documents, with no wasted motion.
1. ZERO BROKEN BUILDS reach Dave: merge_check, parse_scan, local_check and Mike's PASS before every merge. Done when a full day passes with none.
2. EFFICIENCY: one plan per class, QA page clean, daily audit targets met (tech/AUDITS). Done when all 7 targets in the efficiency plan pass for a day.
3. GOALS AND QUEUES refreshed at 8 AM AND at every finished goal; each thread always has a next job. Done when no thread is idle for 10 minutes.
4. DESIGN COVERAGE MAP (weekly): each section of DESIGN_IDEAS gets an owner, a status and a next goal, so the game stays well-rounded and nothing in the design is forgotten. Done when every section has a row.
5. DOCUMENTATION CURRENT: HANDOFF, DECISIONS, TEAM_AND_RULES, BEST_PRACTICES, daily handoff at 8 AM Atlantic.
6. RELEASE READINESS for the friend session: repo private (numbered steps), hosted page, backups restore-tested.
Completed: builds 747-773 merged and logged; BP-T50 to BP-T53 written
