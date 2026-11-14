# Item and recipe number reservations (BP-T61). Update BEFORE coding; Tyler keeps this file.
Current heads (generator-v2 build 791): items highest 266, next 267; recipes highest 169, next 170.
Never reuse: recipes 162, 164 (skipped). Reserved: recipe 165 = campfire pot (Sal, sal-cooking-tripod).
Next free blocks: items 267-299 = Sal; items 300-329 = Steve (fish, bed, bow rules); items 330-349 = Kathleen; recipes 170-199 = Sal; recipes 200-219 = Steve.
Claim a block here by line in the plan; if your branch needs numbers outside it, ask me once.
25 Oct 11:28 UTC: items 267 (oven) and 268 (oven_kit) = Sal (hearth/oven plan); structure state 45 = oven (Sal); blueprint ids 13 (clay hearth), 14 (oven) = Sal (ids 9-12 are the four stations in sal-hand-fine-blueprint-stations); action 49 = ACT_SHOOT and protocol 79 = ACT_SHOOT (Steve, claimed at merge).

## Snare (25 Oct, Tyler GO)
Sal: items 276 snare, 277 snare_trap; recipe 177; world state 46 (structure kind snare_trap). Next free after this: items 278, recipes 178, state 47.

## Item cut (25 Oct, Tyler GO)
Sal: items 278 beam, 279 sickle, 280 scythe (next 281); recipes 178 sickle, 179 scythe (next 180); blueprints 15 large forge, 16 master forge (next 17).

## Building tiers (25 Oct, Tyler GO)
Sal: items 350-399; recipes 180-186; blueprints 17-34; world states 47-75. Items 300-349 = Steve and Kathleen. Next free: items 400, recipes 187, blueprints 35, states 76.
25 Oct 17:55 UTC: Sal world state range extended to 47-76 (76 = thatch_doorway_open). Next free states 77. Merge note: item cut (next items 281, recipes 180) and building tiers p1 (items to 363, recipes to 186) both edit next_number; take the max (items 364, recipes 187) at merge.

## BUGLIST-001 (13 Nov 2026, construction-pieces)
Structure state 91 (`thatch_doorway_open`) is RETIRED and never reused: the Crude doorway is an open frame with no door (BUG-010); a saved one loads as `thatch_doorway` (`legacy_kinds`). New: blueprint 251, item 1255, state 291 = `thatch_roof_65` (Crude - Roof 65, BUG-011). Next free: blueprint 252, item 1256.

## BUGLIST-002 (13 Nov 2026, separate doors and empty doorway frames)
Structure states 28 (`door_open`), 82, 84, 86, 140, 142, 144, 214 and 224 are RETIRED and never reused: the nine old open twins are gone (no dead twin); each kind is in `legacy_kinds` of its doorway frame, so a saved one loads as the empty frame (state 91, `thatch_doorway_open`, was retired in BUGLIST-001). New: blueprints 252-271 / items 1256-1275 / states 292-311 = 20 empty doorway frames (double, single arched, double arched per tier; Refined has no new double); blueprints 272-299 / items 1276-1303 / states 312-367 = 28 doors (single, double, single arched, double arched per tier; shut state 312+2i, open 313+2i). Next free: blueprint 300, item 1304, structure state 368.

## GOALS-REPAIR WP-METAL (14 Nov 2026, metalworking tiers R2-R6)
R2a (PR #1092): item 1304 `improved_smelter`, blueprint 300, structure state 368. Recipes 185, 190, 191 and 192 (the old craft-queue smelts) are RETIRED and never reused; smelting is the stations' own (`src/stream/server_smelter.gd`). Next free: blueprint 301, item 1305, structure state 369.
R2b: items 1305 `copper_pickaxe`, 1306 `copper_axe`; recipes 722, 723. Next free: item 1307, recipe 724.
R3: item 1307 `iron_anvil_part` (the Iron anvil component; #827 `iron_anvil` stays the retired placed Anvil); recipe 724. Next free: item 1308, recipe 725.
R4: items 1308 `advanced_smithy`, 1309 `steel_anvil_part`; blueprint 301 (Advanced smithy); structure state 369; recipe 725 (Steel anvil). `large_forge` #93 / blueprint 201 / state 20 is now the Advanced smelter. Recipe 193 `smelt_steel` (2 Iron ingot to steel) is RETIRED and never reused: steel is the Advanced smelter's `steel` job. Protocol 121. Next free: item 1310, recipe 726, blueprint 302, state 370.
R6: items 1310 `medium_resource_bin`, 1311 `large_resource_bin`; blueprints 302, 303; structure states 370, 371. Item 1232 `open_storage_bin` / blueprint 227 / state 267 is now the Small resource bin (same id). Next free was item 1312, recipe 726, blueprint 304, state 372; see the later blocks below for the current next numbers.

## GOALS-REPAIR WP-GUIDE-UI (14 Nov 2026, tier roof panels A-35/A-36)
Block from the lead (items from 1320, blueprints from 310, states from 380, recipes from 740), clear of WP-METAL's next numbers: items 1320-1324 `log_roof_65`, `roof_section_65`, `stone_roof_65`, `brick_roof_65`, `engineered_roof_65`; blueprints 310-314; structure states 380-384 (same order). No recipes (blueprint-only, like `thatch_roof_65`). next_number is now items 1325, blueprints 315 (above every number in use); numbers below the block that nobody has used yet (items 1312-1319, blueprints 304-309, states 372-379; R6 took 1310-1311, 302-303 and 370-371) stay free for whoever reserves them here. Next free above this block: item 1325, blueprint 315, structure state 385.
