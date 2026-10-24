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
6. SCRATCH PAD: /mnt/project-files/goalpads/WhatamIDoingtoReachMyGoal_<Name>.txt holds the finer steps toward goal 1 (read after any reset, update at job start, step done, and every reminder). Tyler mirrors pads to docs/mirror/goalpads/ at 8 AM. EXCEPTION: Mike cannot write /mnt/project-files, so Mike's pad lives in git at docs/mirror/goalpads/WhatamIDoingtoReachMyGoal_Mike.txt (he pushes it on claude/mike-goalpad); Tyler merges it and copies it back to /mnt/project-files/goalpads/ at each handoff so the shared copy stays in sync.
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

## SAL. Ultimate (Dave 01:31): fill the world with the medieval tools, instruments, workbenches, building items, clothing and any other items we need to exist, thrive and adventure in this fantasy world.
1. ISLAND JOB (dedicated, stays first today): island checks, types tables, per-island layouts, sub-jobs from Sonny. Done when the check table runs on every bake.
2. ITEM LIST AND COMPLETENESS: one master list of every item the design needs (tools, instruments, workbenches, building items, clothing, food, weapons, containers, magic items) with status; audit each existing item for recipe, cost, inspect text, use, model name. Done when the list exists and the existing items have no empty cell.
3. TOOLS (5.3, ITEMS_DESIGN): hand tools, farm tools, mining tools, woodworking and smithing tools, tiers by material. Done when each tool class has its tiers, recipes and uses.
4. WORKBENCHES AND STATIONS (10.1, 11.1): sawmill with water power, woodworking table, forge, anvil, loom, kiln, tanning rack, cooking station, in daily batches. Done when each station crafts its first recipes.
5. BUILDING ITEMS: blueprint build 1c, all tiers (foundations, walls, doors, windows, ceilings, roofs, braces, stairs, furniture, storage). Done when each piece can be built in a test world.
6. CLOTHING AND GEAR (6.7, armour is parked): clothing by climate and class, boots, cloaks, packs; hot and cold resistance from gear (4.5). Done when a character can dress for each climate zone.
7. INSTRUMENTS AND CULTURE: musical instruments, tools of trades, books and journals (6.15), toys, game pieces, religious items. Done when the list has a recipe and a use for each.
8. FARMING, FOOD AND PRODUCTION CHAINS (5.1, 5.2, 11.2): pick, uproot, replant, patches, hoe grade, seasons, mine chain. Done when a small farm and the mine chain run in the rig.
9. SKILLS, QUALITY AND ECONOMY HOOKS (5.4, 13): quality depends on skill; coin values; a job doable by hand or by NPC (design principle 2).
Completed: showroom real items (build 773, Dave to confirm in game)

## KATHLEEN. Ultimate (Dave 01:30): make the world and everything in it look as amazing and photorealistic as possible, for a fantasy world filled with magic and gods.
1. SIMPLE ACCURATE MODELS FOR EVERYTHING, in daily batches: 1a inventory of every thing needing a model with status (day 1); 1b flora (shrubs, herbs, mushrooms, trees); 1c items and tools; 1d building pieces and stations; 1e creatures; 1f characters and clothing. Done when the inventory shows a model for each row.
2. UPGRADE EVERY MODEL to a reasonably better-looking real thing, same batch order. Done when Dave approves a before/after row per batch.
3. UPGRADE AGAIN to almost photorealistic quality, in the same order, with triangle budgets and LODs.
4. MAGIC LOOKS (design: 42 fantasy species 4.3, veilsight outlines, glowing wispbloom, magic items 6.7, granters such as dragon, wizard, spirit 6.10, familiars 6.11): a look for each magic plant and item, a veilsight shimmer effect, glow and spell effects with tier costs. Done when the fantasy species list has models and effects in a labelled row.
5. GODS AND TEMPLES (design: the temple 8.11, religions and homages 6.12, town spirit 8.12): temple, shrine and altar models, holy symbols, divine light and weather moods tied to town spirit. Done when a temple, a shrine and an altar exist with their light effects.
6. FALLEN CIVILIZATION RUINS (design 4.4 / ruins hinting at strong magic that fell): ruin pieces, poisoned-land look, weathered stone. Done when a ruin set of 5 pieces exists.
7. BASIC SOUND SET: every creature, tool, material, ambience, plus magic and temple sounds (Dave's own recordings first). Done when the sound manifest has no empty slot.
8. SOUND UPGRADE to near-real quality, 3D positional with Steve's engine.
9. WORLD LOOK PASSES: grass, water, weather, time of day, ground textures per ART_DIRECTION, each a day-sized pass.
Completed: (none yet)

## STEVE. Ultimate (Dave 01:35): pick up the slack if anyone is falling behind or needs a hand.
1. HOURLY SLACK CHECK (first thing every hour): read the five other scratch pads (/mnt/project-files/goalpads/), the queue in tech/JOBS.md and the merge list; name who is behind, blocked or idle (no DONE line for 60+ minutes, a goal step waiting, a test that keeps failing). Done when each hour has a one-line result in your pad.
2. HELP THE ONE MOST BEHIND: take a defined slice off their goal-1 steps (agree it in their pad under HANDED OFF, with their consent via the coordinator when it touches their code), finish it, push it on your own branch with a plan per BP-T52, and write the DONE line. Done when the slice is merged or accepted.
3. KEEP ENGINE FLOW SMOOTH for everyone: unblock rig flags, server actions, parse errors and protocol ids others need (ID_CLAIMS), within the hour.
4. WHEN NOBODY NEEDS HELP, work your own engine goals in this order: always playable (start-up smoke test, F2 Low under 33 ms); water and tunnels (water_flow_at users, dry river, collapse timer); directional 3D sound and mixer; multiplayer solid (join, sync, worn clothing, saves); senses and minimal HUD (6.14, readable on 55-inch 4K); rig flags (--flora, --pieces, --views); frame-cost budgets per tier.
Completed: parse_scan, water_flow_at, sunny switch (build 771)

## MIKE. Ultimate (Dave 01:34): support everyone else as Dave's computer operator: run tests as efficiently as possible by combining them (one test covering batches of questions), move files around, provide tile builds and push them, and manage our backups according to the current plan.
1. ONE COMBINED BATCH AT A TIME: collect every thread's REQUESTs (TEST_RECIPE template), run them as one launch sequence, report once with a PASS/FAIL line per request. Done when no request waits more than an hour and no test starts the engine for one question.
2. MERGE GATE: hourly merge-check list on the second clone (MERGE_CHECK pattern), one PASS/FAIL line per branch. Done when no branch waits more than 2 hours.
3. TILE BUILDS (BP-T53): bake or copy tiles and settled water into the second clone, commit and push claude/mike-bake-*; never copy into Dave's folder. Done when a bake reaches Tyler as a pushed branch with its hash line.
4. FILE MOVING: copy files between bake folders, the second clone and backups on request, with a one-line log of what moved. Done when each request has its log line.
5. BACKUPS per the plan (BACKUP_PLAN.md): 9 pm ADT nightly (retry 3x), restore test weekly, game and hidden server closed first. Done when last night's backup is verified and logged.
6. PERMISSIONS AND CLONES: user-level settings working, no run refused, both clones current, 8 AM reset.
7. BASELINES AND COVERAGE: frame-time table per build; one new groupable rig test per day; weekly regression run in one table.
Completed: v26 and v27 tile bakes; merge checks for builds 771, 772, 773

## TYLER. Ultimate (Dave 01:32): provide accurate, up-to-date, best-practices-driven, IMPROVED action plans back to anyone creating a new branch.
1. EVERY PLAN ANSWERED ONCE, FAST, WITH EVIDENCE: reply in the plan file within the hour, suggestions that improve the plan (not rubber-stamp), each backed by a source (our DECISIONS and design docs first, then official docs or engine docs fetched that day). Done when a full day passes with no plan waiting more than an hour and every reply has at least 3 concrete improvements.
2. BEST PRACTICES LIBRARY KEPT CURRENT: BEST_PRACTICES.md, the Godot and Voxel Tools notes, git and merge rules reviewed against current docs; stale entries fixed the same day; new lessons from each merge or failure added. Done when each entry has a date and a source and nothing contradicts a Dave ruling.
3. LEARN FROM OUTCOMES: after each branch merges or fails, compare the plan to what happened and feed the lesson into the next replies (a short LESSONS line). Done when every merged branch of the day has its line.
4. PLAN TEMPLATE AND CHECKLISTS: a short checklist per kind of work (terrain bake, item data, model/look, server/protocol, rig/test, docs) so replies are consistent and thorough. Done when each kind has a one-page checklist.
5. DESIGN COVERAGE MAP (weekly): each section of DESIGN_IDEAS gets an owner, a status and a next goal, so plans are checked against the design. Done when every section has a row.
6. SUPPORTING (the safety net, same quality bar): zero broken builds reach Dave (merge_check, parse_scan, local_check, Mike's PASS), QA page clean, daily audit targets, queues and goals refreshed at 8 AM and at each finished goal, documentation and release readiness (private repo steps, hosted page, backups).
Completed: builds 747-773 merged and logged; BP-T50 to BP-T53 written; plan replies given to Steve, Sal, Sonny and Kathleen tonight
