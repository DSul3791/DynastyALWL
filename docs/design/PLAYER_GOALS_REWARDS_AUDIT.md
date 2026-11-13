# Player goals and rewards: audit

Audit of `docs/design/PLAYER_GOALS_REWARDS_DRAFT.md` (651 goals) and `docs/design/PLAYER_JOURNAL_GOALS_UI.md` against the approved catalog, the live data and the server code. Audit only: nothing in the game, its data or its UI was changed. The per-goal record is `docs/design/PLAYER_GOALS_AUDIT_LEDGER.csv`; every count below is generated from that file (`docs/ai-team/missions/GOALS-AUDIT/tools/write_report.py`).

Status: AUDIT REPORT (PROPOSAL-class findings and recommendations; not creator decisions). Mission GOALS-AUDIT, requested by Dave on 13 Nov 2026.

## 1. Executive summary

- **651 original goals reviewed** (118 main route, 533 additional), plus **26 recommended ADD goals** kept as separate records.
- **Design status:** PASS 230, NEEDS_CORRECTION 247, NEEDS_TEST 30, BLOCKED 144. On the main route: PASS 34, NEEDS_CORRECTION 68, NEEDS_TEST 0, BLOCKED 16.
- **Evidence:** 640 goals CODE_VERIFIED (data and code read at the baseline), 11 AUTOMATED_TESTED (legacy goals asserted by `test_goals.gd`, passed on David4 at the baseline), 0 GAMEPLAY_VERIFIED. No goal has been seen completing in a played game.
- **Runtime:** 624 goals can be detected by the existing goal engine; 23 need a new server event (gather and fire/chop activities); 4 need other implementation (paths that make the item without crediting the goal). Design status and runtime support are separate: 4 PASS goals still need runtime work before they can complete.
- **Blocked content:** 144 goals cannot be completed in play today: 81 because a raw ingredient has no in-game source (Tanbark, pine tar, grain crops and flax, obsidian, quill), 39 more because the `water` ingredient exists only as desert cactus water, and 24 because they target locked blueprints. 16 of them are on the main route (Leather, Tar, Water wheel, Sawmill, Concrete, the three swords and every Engineered/Fortified piece that needs concrete).
- **Top tutorial problems:** the Wooden - Hammer step cannot be done as written (axing a log gives large blocks; small blocks are never taught); no hunting step precedes 'Obtain hide'; firewood is taught by a path that never completes the goal; doors come before their frames and never say to aim at an empty doorway; burning stations (Smithy, Blast furnace, Master smithy) need fuel in the pack and the guide never says so; bronze comes after iron, contrary to the approved catalog; legacy `after` gating withholds credit for out-of-order play.
- **Top economy concerns:** the draft pays 15670 copper in total (main route 2826). On the ASSUMED effort model that is 14.6 times the picking wage over the modeled work and 1.70 times the net coin Hob could pay one player; real play time is unmeasured. Rewards follow dependency depth, not effort or significance; variants take most of the money. Recommended per-goal values (ledger column `recommended_reward_copper`) total 3056 (main route 1304). Coin values are unchanged by this audit (Dave's standing ruling).
- **Journal and HUD:** J, G and M are taken or unwired today; modifier handling would make Ctrl+Shift+G run Store All in the inventory; the client receives no goal state (protocol change needed); the upper-right HUD corner is occupied; no fanfare audio exists.
- **Readiness: NOT READY for implementation.** See section 18. The goal list needs its BLOCKED and NEEDS_CORRECTION rows resolved and 11 creator decisions (section 17) before the goal data can be written.

## 2. Scope and method

Scope: every row of the draft goal table, the draft's runtime/Journal sections, and the Journal/HUD/placard/keyboard design in `PLAYER_JOURNAL_GOALS_UI.md` and `ADMIN_KEYBINDINGS_POLICY.md`. Out of scope (brief): implementing goals, changing rewards, recipes, stations, progression or the UI, inventing acquisition methods or renaming items.

Method, in six passes (brief, section 'Passes'):
1. **Discovery.** `tools/goals_audit.py` parses all 651 rows (title, How-to, marker, reward text and copper) and cross-checks each row against `recipes.json`, `blueprints.json`, `structures.json`, `items.json`, `gathered.json` and `wood_species.json` (materials, keeps, units, station and level, blueprint known/locked, group labels, names).
2. **Dependencies.** `tools/pass2_deps.py` records each goal's real inputs, kept tools, stations and blueprint hammer tier, links each to the goal that teaches it, and reports untaught prerequisites and ordering inversions. An obtainability fixed point (`tools/consolidate.py`) propagates from items with a verified source through live recipes, buildable stations and add-on levels.
3. **Individual verification**, by seven independent workstreams, each reading code and data at the baseline: acquisition (every raw input's source), runtime (completion, persistence, migration, performance), catalog (status, names, duplicates, intermediates), Journal/HUD/placard/keyboard, economy (`tools/economy.py`), and two new-player walkthroughs (main 1-45 and side levels 1-5; main 44-118 and levels 6-17).
4. **Walkthrough** from an empty pack to the Fortified gate (section 5).
5. **Independent challenge** by reviewers who did not write the findings (section 15).
6. **Correction and consistency**: the findings are consolidated into stable IDs (GA-xx) by `tools/consolidate.py`; `tools/build_ledger.py` writes and validates the ledger; this report is generated from it.

Design status of a goal is the most severe effect among its findings: BLOCKED (cannot be completed in play today), NEEDS_CORRECTION (the instruction, ordering, completion rule or text is wrong or incomplete), NEEDS_TEST (believed correct but depends on content not yet verified in play), PASS (instruction, materials, stations and prerequisites match the code and data). Design status is independent of runtime support: a PASS gather goal still needs a new event before it can complete (column `runtime_support`). Economy findings never change design status; recommended coin values sit in their own column.

Evidence classes: CREATOR (Dave's own rulings), IMPLEMENTED (code and data at the baseline), PROPOSAL (the draft and agent documents), UNKNOWN. Godot was not run in the cloud. Automated evidence comes from one David4 run relayed by the coordinator (section 3).

Supporting material (not part of the deliverable, kept for review): `docs/ai-team/missions/GOALS-AUDIT/` (tools, workstream reports `work/ws_*.md`, machine results `work/*.json`, `STATE.md`).

## 3. Baseline and source versions

| Item | Version |
|---|---|
| Code and data baseline | `dev` at `dc2fa52374d49ce05ef1f31a300999d1da872d9d` (all `src/` and `data/` citations) |
| Draft goals | `docs/design/PLAYER_GOALS_REWARDS_DRAFT.md` at the baseline (651 rows, lines 28-757) |
| Journal design | `docs/design/PLAYER_JOURNAL_GOALS_UI.md`, `docs/design/ADMIN_KEYBINDINGS_POLICY.md` at the baseline |
| Approved catalog | `docs/design/DYNASTY_MASTER_ITEMS.md` (Draft 18), `data/items/catalog_ledger.json`, BUGLIST-002 door contract (`docs/ai-team/missions/BUGLIST-002/CONTRACT.md`) |
| Live goals | `data/items/starter_goals.json` (18), `data/items/camp_goals.json` (10), engine `src/stream/server_items.gd` ~15620-15840 |
| Protocol | 118 (`src/shared/terrain_net.gd:40`) |
| Automated evidence | David4 run at `dc2fa52`: 20/20 test scripts PASS (test_goals, test_mission001_walkthrough, test_fire_fuel_tiers, test_fire_wet_wood, test_campfire_pot, test_wanted_order, test_camp_bench_drink, test_cooking_route, test_iron_saw_route, test_lumber_route, test_textile_route, test_stations, test_blueprints, test_doors, test_bog_iron, test_stump_chop, test_logs_carry, test_auto_pickup, test_fishing, test_shore_gather) and `validate_items` 0 errors, 114 warnings. Relayed record: `docs/ai-team/missions/GOALS-AUDIT/work/david4_evidence_dc2fa52.md`. |
| Placard art | `GoalAchieved_Blank.png` and `GoalAchieved_Example.png` from Dave's PC, 1448x1086 RGBA, ~2.6 MB each (SHA-256 df9a3d87... and 4c20d281...) |

The audit branch changes only `docs/ai-team/missions/GOALS-AUDIT/` and the two deliverables, so every citation is identical at the branch head.

## 4. Inventory and coverage

| Class | Goals |
|---|---|
| IMPLEMENTED | 627 |
| APPROVED_BUT_NOT_IMPLEMENTED | 23 |
| FUTURE | 1 |
| RETIRED | 0 |
| UNKNOWN | 0 |

- APPROVED_BUT_NOT_IMPLEMENTED: the 23 approved-KEEP blueprints that exist as locked rows (water network, garden pieces). FUTURE: Wool - Rug. No goal targets a retired item, structure or recipe; the draft's KEEP/retired split agrees with the catalog ledger (clay bloomery and woodworking table consistently retired).
- By kind: craft 342, build 256, existing (legacy id) 28, gather 20, activity 5.
- Coverage of eligible content: every live tool ladder (knife, axe, pickaxe, hammer, saw, spade, hoe, sickle) is covered by a goal. Content with no goal is listed as 26 ADD records (section 7).
- Goal IDs: the draft has none. The ledger assigns stable IDs: the legacy runtime id for the 28 live goals, otherwise `<kind>:<key>` from each row's marker. All 651 are unique (validated).
- 70 craft goals are intermediate components (GA-58); 36 goals overlap another goal (GA-47, GA-48).
- The draft's own self-audit (its section 3, 43 'unconfirmed' sources) is inaccurate: 37 of the 43 are sourced; Tanbark, pine tar and obsidian, which it did not list, have no source (GA-59).

## 5. Progression chain

Main route as written, with each step's audit verdict. The full reasoning for each step is in the ledger row (columns `dependency_goal_ids`, `finding_ids`, `recommended_correction`).

| # | Goal | Title | Status | Findings |
|---|---|---|---|---|
| 1 | `gather:stick` | Gather sticks | PASS | GA-46 GA-57 |
| 2 | `gather:stone` | Gather stones | NEEDS_CORRECTION | GA-05 GA-46 GA-57 |
| 3 | `drink` | Drink at the water | NEEDS_CORRECTION | GA-36 |
| 4 | `fibre` | Gather plant fibre | NEEDS_CORRECTION | GA-19 GA-41 |
| 5 | `twine` | Twist twine | NEEDS_CORRECTION | GA-40 GA-42 GA-44 |
| 6 | `craft:stone_knife` | Craft Stone - Knife | PASS | GA-48 GA-57 |
| 7 | `axe` | Make a Stone - Axe | NEEDS_CORRECTION | GA-33 GA-40 GA-41 |
| 8 | `craft:stone_pickaxe` | Craft Stone - Pickaxe | PASS | GA-57 |
| 9 | `fell` | Fell a tree | NEEDS_CORRECTION | GA-16 GA-35 GA-40 GA-42 |
| 10 | `gather:log` | Collect a log | NEEDS_CORRECTION | GA-05 GA-12 GA-35 GA-46 GA-48 GA-57 |
| 11 | `activity:chop_log_blocks` | Chop a felled log into wooden blocks | NEEDS_CORRECTION | GA-10 GA-12 GA-45 GA-57 |
| 12 | `hammer` | Make a Wooden - Hammer | NEEDS_CORRECTION | GA-10 GA-40 GA-41 GA-47 |
| 13 | `craft:campfire_kit` | Craft Campfire | PASS | GA-34 GA-48 GA-57 |
| 14 | `activity:place_campfire` | Place your first campfire | NEEDS_CORRECTION | GA-14 GA-48 GA-57 |
| 15 | `fire` | Light a fire | PASS | GA-34 GA-40 |
| 16 | `craft:chopping_block` | Craft Chopping block | NEEDS_CORRECTION | GA-06 GA-10 GA-48 GA-57 |
| 17 | `activity:place_chopping_block` | Place and prepare your Chopping Block | NEEDS_CORRECTION | GA-14 GA-57 |
| 18 | `gather:log_oak` | Obtain hardwood logs | NEEDS_CORRECTION | GA-05 GA-12 GA-46 GA-57 |
| 19 | `craft:firewood` | Split your first firewood | NEEDS_CORRECTION | GA-13 GA-57 GA-58 |
| 20 | `activity:medium_fire` | Grow your fire into a medium campfire | PASS | GA-45 GA-57 |
| 21 | `activity:bonfire` | Grow your fire into a large bonfire | PASS | GA-45 GA-57 GA-74 |
| 22 | `berries` | Eat something wild | NEEDS_CORRECTION | GA-36 GA-40 GA-52 |
| 23 | `craft:wooden_spade` | Craft Wooden - Spade | PASS | GA-57 |
| 24 | `gather:thatch` | Gather thatch for building and bedding | NEEDS_CORRECTION | GA-19 GA-46 GA-57 |
| 25 | `shelter` | Build a lean-to | NEEDS_CORRECTION | GA-16 GA-40 |
| 26 | `bed` | Make a bed | NEEDS_CORRECTION | GA-14 GA-17 GA-40 GA-52 |
| 27 | `workbench` | Build a Workbench | NEEDS_CORRECTION | GA-33 GA-40 GA-47 |
| 28 | `build:thatch_floor` | Build Crude - Foundation | PASS | GA-57 |
| 29 | `build:thatch_wall` | Build Crude - Wall | PASS | GA-57 |
| 30 | `build:thatch_doorway` | Build Crude - Doorway | NEEDS_CORRECTION | GA-24 GA-25 GA-57 |
| 31 | `build:thatch_window` | Build Crude - Window | PASS | GA-57 |
| 32 | `build:thatch_roof` | Build Crude - Roof 45 | NEEDS_CORRECTION | GA-18 GA-57 |
| 33 | `build:thatch_roof_65` | Build Crude - Roof 65 | NEEDS_CORRECTION | GA-18 GA-25 GA-57 |
| 34 | `gather:clay` | Gather clay | NEEDS_CORRECTION | GA-05 GA-46 GA-57 |
| 35 | `gather:sand` | Gather sand | PASS | GA-32 GA-46 GA-57 |
| 36 | `craft:brick` | Craft Brick | NEEDS_CORRECTION | GA-19 GA-57 GA-58 |
| 37 | `craft:clay_pot` | Craft Clay - Pot | PASS | GA-57 |
| 38 | `build:campfire_pot` | Build Campfire pot | NEEDS_CORRECTION | GA-15 GA-57 |
| 39 | `build:drying_rack` | Build Drying rack | PASS | GA-57 |
| 40 | `build:smoker` | Build Smoker | PASS | GA-57 |
| 41 | `build:food_preparation_table` | Build Food preparation table | PASS | GA-37 GA-57 |
| 42 | `build:clay_hearth` | Build Clay hearth | NEEDS_CORRECTION | GA-19 GA-57 |
| 43 | `build:oven` | Build Oven | NEEDS_CORRECTION | GA-19 GA-33 GA-57 |
| 44 | `craft:thread` | Craft Thread | PASS | GA-32 GA-57 GA-58 |
| 45 | `gather:hide` | Obtain hide | NEEDS_CORRECTION | GA-11 GA-38 GA-46 GA-57 |
| 46 | `gather:flint` | Find flint for a hide scraper | NEEDS_CORRECTION | GA-05 GA-46 GA-57 |
| 47 | `craft:hide_scraper` | Craft Scraper | PASS | GA-57 |
| 48 | `craft:processed_hide` | Craft Scraped hide | PASS | GA-57 GA-58 |
| 49 | `gather:tannin_bark` | Find tannin bark for tanning leather | BLOCKED | GA-01 GA-05 GA-46 GA-57 |
| 50 | `build:tanning_rack` | Build Tanning rack | PASS | GA-37 GA-57 |
| 51 | `craft:leather` | Craft Leather | BLOCKED | GA-01 GA-04 GA-57 GA-58 |
| 52 | `build:leatherworking_table` | Build Leatherworking table | PASS | GA-32 GA-37 GA-57 |
| 53 | `build:tailors_table` | Build Tailor's table | PASS | GA-32 GA-37 GA-57 |
| 54 | `build:loom` | Build Loom | PASS | GA-32 GA-37 GA-57 |
| 55 | `build:preserving_jar` | Build Preserving jar | PASS | GA-32 GA-57 |
| 56 | `craft:charcoal` | Craft Charcoal | NEEDS_CORRECTION | GA-22 GA-30 GA-43 GA-57 GA-58 |
| 57 | `gather:iron_ore` | Obtain iron ore | NEEDS_CORRECTION | GA-05 GA-46 GA-57 |
| 58 | `build:smelter` | Build Smelter | PASS | GA-57 |
| 59 | `craft:iron_ingot` | Craft Iron ingot | NEEDS_CORRECTION | GA-19 GA-30 GA-57 GA-58 GA-72 |
| 60 | `build:blacksmithy` | Build Smithy | NEEDS_CORRECTION | GA-20 GA-37 GA-57 |
| 61 | `craft:iron_hammer` | Craft Iron - Hammer | NEEDS_CORRECTION | GA-20 GA-57 |
| 62 | `craft:hand_saw` | Craft Iron - Saw | NEEDS_CORRECTION | GA-20 GA-57 |
| 63 | `gather:log_spruce` | Obtain softwood logs | NEEDS_CORRECTION | GA-05 GA-12 GA-46 GA-57 |
| 64 | `craft:lumber` | Craft Plank | NEEDS_CORRECTION | GA-30 GA-57 GA-58 GA-72 |
| 65 | `craft:hardwood_board` | Craft Hardwood board | NEEDS_CORRECTION | GA-30 GA-57 GA-58 GA-72 |
| 66 | `craft:wooden_pin` | Craft Wooden pin | PASS | GA-57 GA-58 GA-72 |
| 67 | `build:log_workbench` | Build Carpenter's bench | NEEDS_CORRECTION | GA-28 GA-48 GA-57 |
| 68 | `craft:cobblestone` | Craft Cobblestone | PASS | GA-57 GA-58 |
| 69 | `craft:mortar` | Craft Clay mortar | NEEDS_CORRECTION | GA-22 GA-57 GA-58 |
| 70 | `build:stone_workbench` | Build Stone - Workbench | NEEDS_CORRECTION | GA-28 GA-57 |
| 71 | `build:stonecutters_bench` | Build Stonecutter's bench | NEEDS_CORRECTION | GA-27 GA-37 GA-57 |
| 72 | `craft:nails` | Craft Nails | NEEDS_CORRECTION | GA-19 GA-20 GA-57 GA-58 GA-72 |
| 73 | `craft:hinges` | Craft Hinges | NEEDS_CORRECTION | GA-20 GA-57 GA-58 GA-72 |
| 74 | `craft:iron_band` | Craft Iron band | NEEDS_CORRECTION | GA-19 GA-20 GA-57 GA-58 GA-72 |
| 75 | `gather:pine_tar` | Gather pine tar for mechanical parts | BLOCKED | GA-02 GA-19 GA-46 GA-57 |
| 76 | `craft:tar` | Craft Tar | BLOCKED | GA-02 GA-19 GA-48 GA-57 GA-58 |
| 77 | `craft:water_wheel` | Craft Water wheel | BLOCKED | GA-02 GA-28 GA-57 GA-58 |
| 78 | `build:saw_mill` | Build Sawmill | BLOCKED | GA-02 GA-21 GA-57 |
| 79 | `build:wood_foundation` | Build Refined - Foundation | NEEDS_CORRECTION | GA-26 GA-57 |
| 80 | `build:log_foundation` | Build Rustic - Foundation | NEEDS_CORRECTION | GA-26 GA-37 GA-57 |
| 81 | `build:foundation_section` | Build Sturdy - Foundation | NEEDS_CORRECTION | GA-26 GA-57 |
| 82 | `build:brick_foundation` | Build Superior - Foundation | NEEDS_CORRECTION | GA-26 GA-57 |
| 83 | `gather:copper_ore` | Gather copper ore | NEEDS_CORRECTION | GA-05 GA-23 GA-46 GA-57 |
| 84 | `gather:tin_ore` | Gather tin ore | NEEDS_CORRECTION | GA-05 GA-23 GA-46 GA-57 |
| 85 | `craft:copper_ingot` | Craft Copper ingot | NEEDS_CORRECTION | GA-23 GA-30 GA-57 GA-58 |
| 86 | `craft:tin_ingot` | Craft Tin ingot | NEEDS_CORRECTION | GA-23 GA-30 GA-57 GA-58 |
| 87 | `craft:bronze_ingot` | Craft Bronze ingot | PASS | GA-23 GA-57 GA-58 |
| 88 | `build:stone_forge` | Build Stone - Forge | PASS | GA-23 GA-57 |
| 89 | `craft:bronze_hammer` | Craft Bronze - Hammer | PASS | GA-23 GA-57 |
| 90 | `craft:bronze_pickaxe` | Craft Bronze - Pickaxe | PASS | GA-23 GA-57 |
| 91 | `craft:bronze_sword` | Craft Bronze - Sword | BLOCKED | GA-01 GA-04 GA-23 GA-57 |
| 92 | `craft:iron_pickaxe` | Craft Iron - Pickaxe | NEEDS_CORRECTION | GA-20 GA-57 |
| 93 | `craft:iron_sword` | Craft Iron - Sword | BLOCKED | GA-01 GA-04 GA-20 GA-57 |
| 94 | `build:kiln` | Build Kiln | NEEDS_CORRECTION | GA-22 GA-57 |
| 95 | `gather:limestone` | Find limestone for advanced construction | NEEDS_CORRECTION | GA-05 GA-46 GA-57 |
| 96 | `craft:lime_powder` | Craft Lime powder | PASS | GA-57 GA-58 |
| 97 | `build:mixer` | Build Mixer | PASS | GA-57 |
| 98 | `craft:concrete` | Craft Concrete | BLOCKED | GA-04 GA-19 GA-57 GA-58 GA-72 |
| 99 | `craft:clay_roof_tile` | Craft Clay roof tile | NEEDS_CORRECTION | GA-19 GA-57 GA-58 |
| 100 | `build:large_forge` | Build Blast furnace | NEEDS_CORRECTION | GA-20 GA-57 |
| 101 | `craft:steel_ingot` | Craft Steel ingot | NEEDS_CORRECTION | GA-20 GA-30 GA-57 GA-58 GA-72 |
| 102 | `craft:steel_hammer` | Craft Steel - Hammer | NEEDS_CORRECTION | GA-20 GA-57 |
| 103 | `craft:steel_pickaxe` | Craft Steel - Pickaxe | NEEDS_CORRECTION | GA-20 GA-57 |
| 104 | `craft:steel_sword` | Craft Steel - Sword | BLOCKED | GA-01 GA-04 GA-20 GA-57 |
| 105 | `build:master_forge` | Build Master smithy | NEEDS_CORRECTION | GA-20 GA-29 GA-37 GA-57 |
| 106 | `build:refined_door` | Build Refined - Door | NEEDS_CORRECTION | GA-24 GA-25 GA-26 GA-57 |
| 107 | `build:rustic_door` | Build Rustic - Door | NEEDS_CORRECTION | GA-24 GA-25 GA-26 GA-57 |
| 108 | `build:sturdy_door` | Build Sturdy - Door | NEEDS_CORRECTION | GA-24 GA-25 GA-26 GA-57 |
| 109 | `build:superior_door` | Build Superior - Door | NEEDS_CORRECTION | GA-24 GA-25 GA-57 |
| 110 | `build:engineered_foundation` | Build Engineered - Foundation | BLOCKED | GA-04 GA-57 |
| 111 | `build:engineered_wall` | Build Engineered - Wall | BLOCKED | GA-04 GA-57 |
| 112 | `build:engineered_roof` | Build Engineered - Roof | PASS | GA-57 |
| 113 | `build:engineered_door` | Build Engineered - Door | NEEDS_CORRECTION | GA-24 GA-25 GA-26 GA-57 |
| 114 | `build:fortified_foundation` | Build Fortified - Foundation | BLOCKED | GA-04 GA-57 |
| 115 | `build:fortified_wall` | Build Fortified - Wall | BLOCKED | GA-04 GA-57 |
| 116 | `build:fortified_doorway` | Build Fortified - Doorway | BLOCKED | GA-04 GA-25 GA-57 |
| 117 | `build:fortified_door` | Build Fortified - Door | NEEDS_CORRECTION | GA-24 GA-25 GA-57 |
| 118 | `build:fortified_gate` | Build Fortified - Gate | BLOCKED | GA-04 GA-57 |

**Walkthrough summary (new character, empty pack):**
- Steps 1-10 (sticks, stones, drink, fibre, twine, knife, axe, pickaxe, fell, log) work, with gaps: drinking counts only when thirsty and a new character starts full (GA-36); a sapling gives no log (GA-35); logs are never explained (shoulder carry, Q to put down, recipes use logs within 3 m: GA-12).
- Steps 11-16: what the axe gives depends on the tree. A key-species log gives large blocks, so the Wooden - Hammer needs the untaught 'Small wooden blocks' step; any other tree gives the plain Log and only small blocks, so the Chopping block (step 16) cannot be made (GA-10).
- Steps 13-43 (campfire, fires, lean-to, workbench, Crude building set, clay, bricks, hearth, oven) work with explanation gaps: kit placement (GA-14), the pot needs a small fire (GA-15), lean-to leaves (GA-16), roof snapping (GA-18), firewood credit (GA-13), quantities (GA-19), door order and aiming (GA-24).
- Step 45 'Obtain hide' is a hard stop for a player who follows only the main route: nothing on it can kill an animal (GA-11).
- Steps 46-79 (hide work, Smelter, bog iron, iron tools, Smithy, plank and board, Stone - Workbench) work once bog iron is taught (GA-05) and the Smithy's fuel is explained (GA-20). Leather (main) is BLOCKED by Tanbark and water (GA-01, GA-04).
- Steps 80-118 (bronze, construction tiers, steel, Blast furnace, Sawmill, Master smithy, Fortified set) contain the remaining blocks: Tar, Water wheel and Sawmill need pine tar (GA-02), concrete needs water (GA-04), the three swords need Leather. Bronze is placed after iron, which the approved catalog allows either way (GA-23, creator question Q11), and the construction tiers are taught as lone foundations (GA-26).
- No circular requirement exists. Every station in the route is reachable when the source gaps are closed. Highest outputs reachable today: steel tools and Engineered pieces that need no concrete; with the gaps closed, the Fortified gate.

**Side branches:** 39 side-branch goals are listed before the goal that teaches a prerequisite (GA-07); 109 goals need an ingredient whose source no goal teaches (GA-06, section 7).

Milestones on the main route (cumulative draft copper vs modeled hands-on minutes):

| Milestone | Main step | Draft copper | Recommended | Modeled work (min) |
|---|---|---|---|---|
| first shelter | 25 | 106 | 92 | 31.0 |
| first workbench | 27 | 124 | 110 | 37.9 |
| first hour of modeled work | 33 | 166 | 142 | 66.4 |
| first metal ingot | 59 | 409 | 362 | 157.9 |
| first steel | 101 | 1546 | 1009 | 440.6 |
| first fortified piece | 114 | 2426 | 1257 | 649.5 |
| end of main route | 118 | 2826 | 1304 | 797.3 |

## 6. Dependency findings

- **GA-06** (HIGH, confirmed defect): Ingredients whose source no goal teaches (the guide silently assumes them). Evidence: pass2_deps.json 'untaught' (no goal teaches acquiring the input); sources per ws_acquisition.json, e.g. feather/raw_meat/sinew/fur (carcass.json, needs a weapon and knife), soil/worm/gravel (digging.json), honeyspindle_nectar (summer only, knife on hotbar by the accidental 'tar' suffix rule, drops.json#tool_rules), egg/shellfish/crab/seaweed (shore nodes, blocked while a water container is carried: server_items.gd:13969-13977), wild herbs, fruit, nuts, mushrooms (season and biome locked). Goals (109): `build:antler_mount`, `build:brick_garden_plot`, `build:canopy_bed`, `build:feather_bed`, `build:flower_pot`, `build:hide_rug`, `build:stone_garden_plot`, `build:stone_planter`, `build:straw_bed`, `build:thatch_garden_plot`, `build:tusk_mount`, `build:wooden_garden_plot`, `build:wooden_planter_box`, `craft:acorn_mash` and 95 more (ledger column finding_ids). Correction: Add acquisition steps or group discovery goals (ADD records) and name the source in each How-to; the Journal prerequisite chain must link a verified source for every raw input.
- **GA-07** (MED, confirmed defect): Side-branch goals listed before the goals that teach their prerequisites. Evidence: Walkthrough verdicts (ws_walk_early.md section c 'problem'; ws_walk_late.md section d YES-WITH-UNTAUGHT-PREREQ/(acq)); pass2_report.txt document-order check (craft:herb_fish, craft:juniper_trout before fish; craft:stone_hoe before hoe). Dependency levels in the draft headings were computed from recipe depth, not from where the prerequisite is taught. Goals (39): `build:antler_mount`, `build:canopy_bed`, `build:engineered_roof_corner`, `build:feather_bed`, `build:stone_fence`, `craft:banana_fritter_batter`, `craft:bone_arrow`, `craft:bronze_arrow`, `craft:compost`, `craft:energy_bar`, `craft:fibre_cloth`, `craft:fire_arrow`, `craft:fishing_bait`, `craft:flour` and 25 more (ledger column finding_ids). Correction: Recompute section order from the position of each prerequisite's teaching goal; move hunting into the main route (GA-11).
- **GA-10** (HIGH, confirmed defect): Wooden - Hammer and Chopping block steps depend on which tree was felled: the 8 key species give LARGE blocks (hammer needs small), other trees give the plain Log and only small blocks (chopping block needs large). Evidence: server_items.gd:9223-9276 (_chop_loose_log: a shoulder log of the 8 key species oak, beech, birch, maple, walnut, Scots pine, spruce, tropical hardwood -> 3 Large wooden blocks; the plain Log (stack 5, not shoulder) -> 3 small softwood blocks); server_items.gd:6627-6633 (_log_number: a retired or missing species log falls back to the plain Log: alder, willow, rowan, balsam fir, acacia, mangrove, sweet chestnut, fruit trees); recipes.json chopping_block needs a Large wooden block and no recipe turns small blocks into large; recipes.json wooden_hammer needs the wooden_block group (Hardwood/Softwood block) (wood_species.json ingredient_groups.wooden_block); 'Small wooden blocks' (small_blocks_from_large) is the missing step, used by test_mission001_walkthrough.gd:482-484 (passed on David4 at dc2fa52). CONTROLS.md:72 says 4/12 blocks (stale; data 3/3). Goals (5): `activity:chop_log_blocks`, `craft:chopping_block`, `craft:wooden_block`, `craft:wooden_block_soft`, `hammer`. Correction: Name a key-species tree in rows 9-11 and 16; correct row 11's yield; move craft:wooden_block (and _soft) into the main route between rows 11 and 12.
- **GA-11** (HIGH, confirmed defect): 'Obtain hide' (main 45) has no hunting step before it: no main-route item can strike an animal. Evidence: server_items.gd:2243-2259 (_strike accepts kind weapon with damage only); stone axe/pickaxe/knife are kind tool (items.json); dressing needs a knife in hand (server_items.gd:2288-2296). Spear, snare and the legacy 'knife' kill goal are all in the additional sections. Goals (6): `craft:wooden_spear`, `gather:animal_fat`, `gather:bone`, `gather:hide`, `knife`, `spear`. Correction: Move craft:wooden_spear (or craft:snare) and the legacy knife kill-and-dress goal into the main route before row 45. Test: Hunt and dress a deer/rabbit with the listed tools.
- **GA-22** (MED, design recommendation): Kiln charcoal (the catalog's main fuel route) has no goal and the Kiln comes after the fuel-hungry metal steps. Evidence: structures.json kiln use kiln, per_log 100, batch_logs 6 (server_items.gd:9163-9164, 9400, 9421-9449, which also does not credit goals); master s2.6; the main route needs ~690 fuel (W-L04). Goals (3): `build:kiln`, `craft:charcoal`, `craft:mortar`. Correction: Move mortar and the Kiln before the Smelter; ADD 'Burn charcoal in the Kiln'.
- **GA-23** (MED, owner decision): Bronze comes after iron in the main route; the approved catalog supports both orders, and the Stone - Forge adds nothing at that point. Evidence: DYNASTY_MASTER_ITEMS.md s2.7 item 1 [D1] (Dave: a wilderness route to the Iron Hand Saw with no bronze step) and item 4 [C] (bronze is a real rung before iron, keeping that wilderness route); the draft follows item 1; structures.json blacksmithy also forge 1 (the Smithy already serves bronze recipes); test_stations.gd:103-122. Goals (9): `build:stone_forge`, `craft:bronze_hammer`, `craft:bronze_ingot`, `craft:bronze_pickaxe`, `craft:bronze_sword`, `craft:copper_ingot`, `craft:tin_ingot`, `gather:copper_ore`, `gather:tin_ore`. Correction: Creator decision (Q11): keep iron first (item 1) and present bronze as an optional side rung, or move main rows 83-91 directly after the Smelter (item 4).
- **GA-26** (MED, confirmed defect): Construction tiers in the main route are incoherent: four lone foundations, no walls/roofs for those tiers, doors placed after the Master smithy without a real dependency. Evidence: Main rows 79-82 and 106-118; costs per blueprints.json show Rustic/Refined/Sturdy doors need only planks/boards and iron, Engineered needs no steel (ws_walk_late.md construction matrix). Goals (8): `build:brick_foundation`, `build:engineered_door`, `build:foundation_section`, `build:log_foundation`, `build:refined_door`, `build:rustic_door`, `build:sturdy_door`, `build:wood_foundation`. Correction: Teach each tier as a block (foundation, wall, doorway, door, window, roof) at the point its materials first exist.
- **GA-27** (MED, confirmed defect): Stonecutter's bench is a dead end in the main route: every recipe keeps a Bronze - Chisel the route never makes. Evidence: recipes.json bench_stone_block, carved_stone_block, carved_stone_shingle keep bronze_chisel; master s2.1 chisel is sculpture/art only. Goals (1): `build:stonecutters_bench`. Correction: Move it to the side branch, or add craft:bronze_chisel before it.
- **GA-35** (LOW, confirmed defect): A tree too short for one log gives no log at all. Evidence: server_items.gd:6683, 6748 (split_trunk count <= 0 -> _split_small: firewood, kindling and sticks only). Goals (2): `fell`, `gather:log`. Correction: Say 'fell a full-grown tree'.
- **GA-37** (LOW, design recommendation): Log-cost builds rely on the 3 m log rule taught once (GA-12). Evidence: server_items.gd:8164, 15895-15928 (_pull_nearby_logs serves every blueprint and recipe that costs logs). Goals (34): `build:bellows`, `build:blacksmithy`, `build:board_rack`, `build:firewood_rack`, `build:food_preparation_table`, `build:grindstone`, `build:leatherworking_table`, `build:log_arched_doorway`, `build:log_doorway`, `build:log_double_arched_doorway`, `build:log_double_doorway`, `build:log_fence`, `build:log_floor`, `build:log_foundation` and 20 more (ledger column finding_ids). Correction: No per-row change once GA-12 is fixed; the Journal can link the rule.
- **GA-39** (LOW, unverified assumption): Wool goods depend on bighorn only (alpine and bare rock); whether a typical start can reach them is untested. Evidence: carcass.json wool from bighorn; data/animals/spawn_plan.json wild_sheep 'needs: spawn + model'. Goals (14): `build:ornate_chair`, `craft:travellers_rucksack`, `craft:wool_cap`, `craft:wool_cloak`, `craft:wool_cloth`, `craft:wool_coat`, `craft:wool_dress`, `craft:wool_mittens`, `craft:wool_robe`, `craft:wool_scarf`, `craft:wool_socks`, `craft:wool_trousers`, `craft:wool_tunic`, `gather:wool`. Correction: Keep; confirm a wool route in play or mark the wool family as regional. Test: Find and hunt a bighorn from a typical start.
- **GA-40** (HIGH, confirmed defect): `after` prerequisites gate completion, contrary to 'goals are guidance, not locks'. Evidence: server_items.gd:15740-15747 (_goal_open) used at 15763; legacy chain fibre -> twine -> axe -> fell -> ...; counters keep counting so event/made goals pay late, possession goals can be lost; test_goals.gd 'a goal done early waits for its after' (passed on David4). Goals (26): `axe`, `bed`, `berries`, `candle`, `dry_berries`, `fell`, `fire`, `fish`, `fur_for_winter`, `hammer`, `hoe`, `jerky`, `knife`, `night_walk` and 12 more (ledger column finding_ids). Correction: Drop `after` from the completion test; keep it only for display order and Journal prerequisite links. Test: Out-of-order: build a lean-to before gathering 12 fibre; confirm immediate credit.

Untaught ingredients, by number of goals that need them: water 20; honeyspindle nectar, feather, raw meat, wild garlic, soil, sinew, onion, hazelnuts, wild carrot, fur, herbs, egg, nettles and 27 more (pass 2, `work/pass2_report.txt`).

## 7. Missing goals and steps

Missing steps inside existing goals (corrections, not new goals): small wooden blocks before the hammer (GA-10), a hunting step before hide (GA-11), kiln charcoal before the metal steps (GA-22), sources for untaught ingredients (GA-06).

Recommended ADD goals (26). Each needs creator approval (catalog freeze); none is implemented by this audit.

| ID | Title | Route | Runtime | Why |
|---|---|---|---|---|
| `ADD-01 craft:kindling` | Craft Kindling | MAIN | EXISTING | Live hand craft with no goal (only legacy starter reward gives kindling). cooking.json lists kindling as a weak fuel class. Teaches fire lighting inputs. |
| `ADD-02 craft:tinder` | Craft Tinder | ADDITIONAL | EXISTING | Live hand craft with no goal; cooking.json tinder class. |
| `ADD-03 activity:cook_on_campfire` | Cook meat or fish on a campfire | ADDITIONAL | NEW_EVENT_REQUIRED | Roast Meat/Fish/Shellfish/Seal items (items.json roast_meat, roast_fish, roast_shellfish, roast_seal) have no recipe and no goal; this is the first cooking step before pots and hearths. Needs a new goal event (none emitted for cooking). |
| `ADD-04 activity:till_garden_bed` | Till soil into a garden bed with a hoe | ADDITIONAL | NEW_EVENT_REQUIRED | Farming starts with the hoe; build:*_garden_plot goals teach framed plots but not tilling. Needs a goal event. |
| `ADD-05 activity:sow_seed` | Sow a seed in a bed | ADDITIONAL | NEW_EVENT_REQUIRED | Seeds and 12 crops exist; no goal teaches sowing or harvesting. |
| `ADD-06 activity:harvest_crop` | Harvest a ripe crop | ADDITIONAL | NEW_EVENT_REQUIRED | Pairs with sowing; sickle ladder (Bronze, Iron, Steel) is only taught as three craft goals. |
| `ADD-07 activity:plant_bush` | Dig up a bush and replant it | ADDITIONAL | NEW_EVENT_REQUIRED | 23 live bush items (kind material) have no goal and no recipe. |
| `ADD-08 activity:set_snare` | Set a snare | ADDITIONAL | NEW_EVENT_REQUIRED | craft:snare (Additional) crafts the placeable but nothing teaches setting it; fish and bird traps are FUTURE and correctly absent. |
| `ADD-09 activity:sharpen_tool` | Sharpen a tool on a whetstone or grindstone | ADDITIONAL | NEW_EVENT_REQUIRED | craft:whetstone and build:grindstone exist as goals but the sharpening mechanic itself, central to metal tools, has no goal. |
| `ADD-10 activity:repair_tool` | Repair a worn or broken tool | ADDITIONAL | NEW_EVENT_REQUIRED | Break/repair rules are live (Phase 2c TESTED - ACCEPTED in ledger) and untaught. |
| `ADD-11 activity:repair_building` | Repair a damaged building piece with a hammer | ADDITIONAL | NEW_EVENT_REQUIRED | Live mechanic with no goal. |
| `ADD-12 activity:sleep_in_bed` | Sleep through a night in a bed or lean-to | ADDITIONAL | NEW_EVENT_REQUIRED | Legacy goals only place the lean-to and bed; sleeping (and its comfort rules) is never a goal. |
| `ADD-13 activity:store_in_chest` | Put items in a chest or crate | ADDITIONAL | NEW_EVENT_REQUIRED | Many storage build goals but no goal for using one. |
| `ADD-14 activity:set_container_code` | Lock a chest with a four-digit code | ADDITIONAL | NEW_EVENT_REQUIRED | Phase 9 TESTED - ACCEPTED (ledger); owner locks are a headline storage feature. |
| `ADD-15 activity:haul_with_handcart` | Move a loaded crate with a Handcart | ADDITIONAL | NEW_EVENT_REQUIRED | build:handcart, craft:axle, craft:wooden_cart_wheel exist; hauling does not. |
| `ADD-16 activity:craft_tempered_item` | Craft a Tempered steel item at a Smithy with a Quenching trough | ADDITIONAL | NEW_EVENT_REQUIRED | build:quenching_trough (Smithy add-on) exists but its purpose is never taught. Instance-level property, needs a new event. |
| `ADD-17 activity:craft_masterwork` | Craft a +1/+2 craftsmanship item at the Master smithy | ADDITIONAL | NEW_EVENT_REQUIRED | build:master_forge exists as a Main goal with no goal for what it unlocks. |
| `ADD-18 activity:burn_kiln_charcoal` | Burn a kiln batch of charcoal | ADDITIONAL | NEW_EVENT_REQUIRED | build:kiln has a goal but only for its brick/lime recipes; the log-to-charcoal batch is the kiln feature master s2.6 describes. |
| `ADD-19 activity:buy_from_trader` | Buy something from Hob | ADDITIONAL | NEW_EVENT_REQUIRED | Legacy goals teach selling and an order but not buying; 15 items are on sale. |
| `ADD-20 activity:preserve_in_jar` | Seal a batch in the Preserving jar and wait for it to mature | ADDITIONAL | NEW_EVENT_REQUIRED | craft:sauerkraut is a goal but the maturing mechanic (sealed batch, unusable until ready) is the point of the jar. |
| `ADD-21 activity:serve_platter` | Place a Serving platter with food on a table | ADDITIONAL | NEW_EVENT_REQUIRED | craft:serving_platter and eight board goals exist; placing and serving them is not taught. |
| `ADD-22 activity:eat_prepared_meal` | Eat a prepared meal for a temporary food effect | ADDITIONAL | NEW_EVENT_REQUIRED | Temporary food effects are the reason for ~90 cooked-food goals; no goal teaches reading or using them. |
| `ADD-23 activity:place_torch` | Wedge a torch into a wall or stand | ADDITIONAL | NEW_EVENT_REQUIRED | Two live state-only structure rows with no goal; legacy goals only craft and carry a torch. |
| `ADD-24 activity:forage_new_plant` | Forage a new herb, nut or fruit (discovery goals) | ADDITIONAL | NEW_EVENT_REQUIRED | Per-item gather goals would add ~165 goals; recommend a few counted discovery goals instead (for example 5 different herbs, 5 different nuts and fruits, 5 different mushrooms). Do not invent acquisition methods: each material needs the acquisition workstream first. |
| `ADD-25 activity:catch_different_fish` | Catch several kinds of fish | ADDITIONAL | NEW_EVENT_REQUIRED | Fishing methods: rod, net (craft:shore_net), hook; one legacy goal only. |
| `ADD-26 activity:mine_ore_with_pick` | Mine a boulder with a pickaxe | ADDITIONAL | NEW_EVENT_REQUIRED | gather:iron_ore, copper_ore, tin_ore, limestone text covers it by item; a single mining-action goal would teach tool-tier requirements (boulders.json ore needs_material). |

## 8. Invalid instructions

- **GA-05** (MED, confirmed defect): Gather instructions that are wrong, placeholder or incomplete. Evidence: iron ore: rock outcrops need a bronze/iron/steel pick (boulders.json#ore.needs_material.iron; server_items.gd:5616-5622); the early route is bog iron with any spade (digging.json#bog_iron; server_items.gd:3405-3445); flint and limestone How-tos still say 'under verification' although both are sourced (drops.json#ground_scatter.bank.flint; boulders.json#flint, #ore.rocks); copper/tin need a pick held in hand; wool comes only from bighorn (carcass.json; wild sheep never spawns); logs are shoulder items, Q puts one down, crafts use logs within 3 m (server_items.gd:898-927, 15839-15925); Tanbark is the data name (gathered.json tannin_bark); clay's How-to still carries the placeholder 'verify the specific terrain/material shown by the game' (loam, silt and alluvium give clay under the topsoil: digging.json). Goals (12): `gather:clay`, `gather:copper_ore`, `gather:flint`, `gather:iron_ore`, `gather:limestone`, `gather:log`, `gather:log_oak`, `gather:log_spruce`, `gather:stone`, `gather:tannin_bark`, `gather:tin_ore`, `gather:wool`. Correction: Rewrite each How-to from the acquisition evidence (ledger column acquisition_source_evidence).
- **GA-10** (HIGH, confirmed defect): Wooden - Hammer and Chopping block steps depend on which tree was felled: the 8 key species give LARGE blocks (hammer needs small), other trees give the plain Log and only small blocks (chopping block needs large). Evidence: server_items.gd:9223-9276 (_chop_loose_log: a shoulder log of the 8 key species oak, beech, birch, maple, walnut, Scots pine, spruce, tropical hardwood -> 3 Large wooden blocks; the plain Log (stack 5, not shoulder) -> 3 small softwood blocks); server_items.gd:6627-6633 (_log_number: a retired or missing species log falls back to the plain Log: alder, willow, rowan, balsam fir, acacia, mangrove, sweet chestnut, fruit trees); recipes.json chopping_block needs a Large wooden block and no recipe turns small blocks into large; recipes.json wooden_hammer needs the wooden_block group (Hardwood/Softwood block) (wood_species.json ingredient_groups.wooden_block); 'Small wooden blocks' (small_blocks_from_large) is the missing step, used by test_mission001_walkthrough.gd:482-484 (passed on David4 at dc2fa52). CONTROLS.md:72 says 4/12 blocks (stale; data 3/3). Goals (5): `activity:chop_log_blocks`, `craft:chopping_block`, `craft:wooden_block`, `craft:wooden_block_soft`, `hammer`. Correction: Name a key-species tree in rows 9-11 and 16; correct row 11's yield; move craft:wooden_block (and _soft) into the main route between rows 11 and 12.
- **GA-12** (MED, confirmed defect): Logs are never explained: species logs are shoulder-carried one at a time (the plain Log stacks to 5), Q puts one down, recipes and blueprints use logs within 3 m. Evidence: items.json log_<species> carry shoulder, stack 1; items.json log stack 5; server_items.gd:898-927, 15839-15925, 8164, 17005-17006; key_bindings.gd:30 (Q). Goals (4): `activity:chop_log_blocks`, `gather:log`, `gather:log_oak`, `gather:log_spruce`. Correction: Add one sentence on shoulder logs and the 3 m rule to the first log row and to the Journal's building basics (GA-33); later log-cost rows then need no change.
- **GA-13** (HIGH, confirmed defect): Firewood and small blocks: the taught action never completes the goal. Evidence: Two real firewood paths: E-split at the chopping block (server_items.gd:9170-9207, 2/4 firewood per block, no _goal_made) and the block's F Craft recipe chopping_hard_firewood (1 hardwood log -> 12, recipes.json). Main row 19 teaches the E split but cites the recipe; only the queued craft calls _goal_made (server_items.gd:17414). Axe on a loose log (9223-9278) is also uncredited. Title 'Split your first firewood' differs from the item name 'Hard firewood'. Goals (2): `craft:firewood`, `craft:firewood_soft`. Correction: Teach the recipe path (F at the block) or credit the hand split with a made/unit event; name the item 'Hard firewood'. Test: Split firewood both ways and confirm the goal completes.
- **GA-14** (MED, confirmed defect): Placing kits (campfire, chopping block, Thatch - Bed) is never explained. Evidence: kind placeable goes to the pack, not the hotbar; I, select, Use (E) to hold, left-click (CONTROLS.md:59, 67; hints.json place_fire). 2.5 m gap between structures, 2 m between fires (server_items.gd:8418; structures.json gap_m). Goals (3): `activity:place_campfire`, `activity:place_chopping_block`, `bed`. Correction: State the exact placement controls and spacing.
- **GA-15** (MED, confirmed defect): Campfire pot: only snaps to a small fire with no logs, but follows the bonfire step. Evidence: placement_rules.gd:10, 66-67, 731-743 (POT_FIRE_STATES excludes the bonfire); server_items.gd:8371-8379 ('The fire is too big for a pot'); test_campfire_pot.gd:166-172 (passed on David4 at dc2fa52). Goals (1): `build:campfire_pot`. Correction: Tell the player to use a small fire (no logs) or lay a second fire.
- **GA-16** (MED, confirmed defect): Lean-to cost and its 60 leaves are never taught. Evidence: blueprints.json lean_to cost 20 stick, 60 leaves, 6 twine; leaves come from felled broadleaf crowns (none from conifers, none in winter) or axing bushes (drops.json trunk crown_leaves, leaves_note, shrub_work). Goals (2): `fell`, `shelter`. Correction: Give the cost and the leaf source.
- **GA-17** (MED, unverified assumption): Thatch - Bed 'under cover' may be refused beside Crude pieces while the client ghost shows green. Evidence: server_items.gd:8406-8418 exempts beds from the 2.5 m gap only inside a lean-to box; placement_rules.gd:12, 745-765 checks only states 5/6/7 on the client; structures.json shelter_needed is read by no script. Goals (1): `bed`. Correction: Say 'inside your lean-to'; confirm in play. Test: Place a Thatch - Bed beside Crude walls and inside a lean-to.
- **GA-18** (MED, confirmed defect): Roof panels: must rest on a wall top or panel edge; mouse wheel flips rise/fall; never explained. Evidence: server_items.gd:3730; placement_rules.gd:306-338; held_item.gd:990-992; CONTROLS.md lacks the roof wheel. Goals (2): `build:thatch_roof`, `build:thatch_roof_65`. Correction: Add the snapping rule and the wheel control.
- **GA-19** (MED, confirmed defect): Quantities the player needs are not stated (fibre, thatch, bricks, iron, pine tar, fasteners, concrete). Evidence: Main rows 5-43 need 55 twine (165 fibre) and 145 thatch and 34 bricks (blueprints.json costs); row 4 asks for 12 fibre. Pine tar: Water wheel needs 4 Tar = 20 pine tar, How-to says 5 (recipes.json tar, water_wheel). Main route needs ~108 iron ingots, ~22 steel, ~690 fuel (ws_walk_late.md W-L12). Goals (12): `build:clay_hearth`, `build:oven`, `craft:brick`, `craft:clay_roof_tile`, `craft:concrete`, `craft:iron_band`, `craft:iron_ingot`, `craft:nails`, `craft:tar`, `fibre`, `gather:pine_tar`, `gather:thatch`. Correction: State the needed count on each producing row.
- **GA-24** (HIGH, confirmed defect): Doors: listed before their frames, How-to never says 'aim at an empty doorway', and each main-route single door needs its own empty single doorway. Evidence: placement_rules.gd:32, 587-627 (doorway_fit: a door needs an empty doorway of the same opening shape, any tier, one per frame); server_items.gd:3733-3740; test_doors.gd (passed on David4 at dc2fa52). Crude arched/double/double-arched doors sit at draft level 2, their doorways at level 4. Goals (29): `build:crude_arched_door`, `build:crude_door`, `build:crude_double_arched_door`, `build:crude_double_door`, `build:engineered_arched_door`, `build:engineered_door`, `build:engineered_double_arched_door`, `build:engineered_double_door`, `build:fortified_arched_door`, `build:fortified_door`, `build:fortified_double_arched_door`, `build:fortified_double_door`, `build:refined_arched_door`, `build:refined_door` and 15 more (ledger column finding_ids). Correction: Every door How-to: 'aim at the empty opening of a matching doorway (any tier); the door snaps in'; order each door after a frame of its shape; say a doorway is an empty frame.
- **GA-30** (LOW, confirmed defect): Group ingredients are named by their key item (Spruce log, Oak log, Hardwood block, Knife, Axe, Fuel) instead of the in-game labels. Evidence: wood_species.json group_labels (Softwood log, Hardwood log, Wooden block, Any knife, Any axe, Any saw; item_table.gd cost_name); static flag GROUP_SHOWN_AS_KEY_ITEM in goals_parsed.json. Goals (21): `craft:bark_shingle`, `craft:charcoal`, `craft:copper_ingot`, `craft:firewood_soft`, `craft:fishing_spear`, `craft:hardwood_board`, `craft:heavy_crossbow`, `craft:iron_ingot`, `craft:leather_strap`, `craft:light_crossbow`, `craft:lumber`, `craft:quarterstaff`, `craft:serving_platter`, `craft:spyglass` and 7 more (ledger column finding_ids). Correction: Use the group label and list the accepted members once.
- **GA-34** (LOW, design recommendation): Fire row text: the placed kit already holds sticks; 'add sticks with F' is unnecessary; the kit description still says 'light it with fibre'; rain is never mentioned. Evidence: server_items.gd:3822-3828; CONTROLS.md:73; items.json campfire_kit description; server_items.gd:7589-7611 (an uncovered fire in rain goes out; drizzle makes lighting a chance roll). Goals (2): `craft:campfire_kit`, `fire`. Correction: Simplify to 'Press E on the laid fire'.
- **GA-36** (MED, confirmed defect): Drink and eat goals only count when the player is thirsty or hungry, and a new character starts full. Evidence: _new_vitals sets fed and wet to their caps (server_items.gd:10218-10219); _drink_water refuses at the cap ('You have had enough water.', 18408-18412) and refuses salt water (18386-18387); a held container with room fills instead (18396-18406); ACT_DRINK / ACT_EAT emit the goal only if the vital rose (1098-1109); test_goals.gd:85 lowers wet first. Goals (2): `berries`, `drink`. Correction: Say 'when you are thirsty, drink fresh water (not the sea) with no empty container in hand' and 'once you are hungry'. Test: First minutes of a new character at a river.
- **GA-51** (LOW, confirmed defect): Legacy goal text does not match its live check or recipe. Evidence: smoke_fish: live recipe cook_smoked_fish = 1 fish + 1 Salt at the Smoker; dry_berries: 3 berries at the Drying rack; salted_fish needs Trout; fish: rod needs a hook (recipes.json fishing_rod); story counts only Edda (server_items.gd:15200-15223); night_walk counts a torch in the pack (15185-15186); fur_for_winter is worn warmth >= 0.7. Goals (7): `dry_berries`, `fish`, `fur_for_winter`, `night_walk`, `salted_fish`, `smoke_fish`, `story`. Correction: Rewrite from the live recipes and checks.
- **GA-52** (LOW, design recommendation): Loose legacy checks (bed not under cover, path not camp-to-water, any food for berries, torch crafted not carried, any knife). Evidence: ws_runtime.json goals entries; server_items.gd checks. Goals (5): `bed`, `berries`, `knife`, `path`, `torch_night`. Correction: Accept, or tighten when the catalog is implemented.

## 9. Unobtainable ingredients

Computed by a fixed point over verified sources (`tools/consolidate.py`). Counts per ingredient assume every other gap is closed:

| Ingredient | Goals that need it | Note |
|---|---|---|
| tannin_bark | 63 | GA-01, leather chain |
| pine_tar | 4 | GA-02 |
| crops | 14 | GA-03 (wheat, barley, oats, rye, flax together) |
| water | 104 | GA-04, any non-desert start |
| obsidian | 0 | no goal depends on it alone |
| quill | 0 | no goal depends on it alone |

Total BLOCKED by sources: 120 goals (81 by the no-source items, 39 more by water). The per-ingredient counts overlap.

- **GA-01** (HIGH, confirmed defect): Tanbark (tannin_bark) cannot be obtained, so the leather chain cannot be completed. Evidence: drops.json#harvest_yield.oak gives tannin_bark x3 but E-harvest is refused on any tree not in drops.json#fruit_tree (scenes/terrain_server/terrain_server.gd:1862-1865; src/client/harvest.gd:277-279); no trunk, felling, carcass, shop (data/npcs/shops.json hob.stock) or recipe row produces it; route tests hand it out (test_mission001_walkthrough.gd:606 'no route test proves stripping bark'; docs/ai-team/missions/M001/T19_RESULTS.md:35). Goals (63): `build:bellows`, `build:iron_bench`, `build:iron_chair`, `build:ornate_chair`, `craft:bronze_axe`, `craft:bronze_greaves`, `craft:bronze_helm`, `craft:bronze_scale_shirt`, `craft:bronze_sword`, `craft:fine_leather`, `craft:heavy_leather`, `craft:iron_axe`, `craft:iron_battleaxe`, `craft:iron_breastplate` and 49 more (ledger column finding_ids). Correction: Creator decision on the bark mechanism (see Q1); until then mark these goals blocked and do not publish their How-to. Test: After a fix: strip/harvest tanbark in play, tan a hide.
- **GA-02** (HIGH, confirmed defect): Pine tar cannot be obtained (Scots pine trunk only ever drops resin), so Tar, Water wheel and Sawmill are blocked. Evidence: data/tables/flora.json scots_pine yields [resin, pine_tar]; the trunk seed roll gives only the first drops.json#trunk.by_species row (src/stream/server_items.gd:6527-6533, 6886-6900): resin. E on a tree is refused (terrain_server.gd:1862-1865). Not sold by Hob. Goals (4): `build:saw_mill`, `craft:tar`, `craft:water_wheel`, `gather:pine_tar`. Correction: Engineering fix (roll every by_species row) or creator decision; until then mark blocked. Test: Fell Scots pines and confirm pine tar drops.
- **GA-03** (HIGH, confirmed defect): Grain crops (wheat, barley, oats, rye) and flax cannot be harvested in play: the client never sends sow/harvest/water actions. Evidence: crops.json is the only source; the server implements sow/harvest (src/stream/server_items.gd:14635, 14757) but the client sends only ACT_TILL (src/client/held_item.gd:2064); no client code sends ACT_SOW, ACT_HARVEST or ACT_WATER_BED. Wild flax (E) gives plant fibre, linseed and flax seeds, never `flax`. test_farming.gd calls the server directly. Goals (14): `craft:barley_broth`, `craft:breakfast_platter`, `craft:linen`, `craft:linen_apron`, `craft:linen_dress`, `craft:linen_headwrap`, `craft:linen_shirt`, `craft:linen_skirt`, `craft:linen_trousers`, `craft:oat_cakes`, `craft:oat_porridge`, `craft:oilcloth_cloak`, `craft:unbaked_oatcakes`, `gather:flax`. Correction: Engineering: wire the farming client actions (implementation work, needs assignment); until then mark blocked. Test: Sow, water and harvest a crop in play.
- **GA-04** (HIGH, confirmed defect): The `water` ingredient is obtainable only from desert cactus; filling a container never creates it. Evidence: Only E on a cactus (flora.json cactus: hot_desert, dry_scrub) gives `water` items; filling a bucket/waterskin stores millilitres as slot wear (src/stream/server_items.gd:18396-18405); no craft code reads container water; water_bed consumes the item (14673-14690). Route tests give water directly (test_textile_route.gd:209; test_mission001_walkthrough.gd:612, 831). Goals (104): `build:bellows`, `build:engineered_arched_doorway`, `build:engineered_doorway`, `build:engineered_double_arched_doorway`, `build:engineered_double_doorway`, `build:engineered_floor`, `build:engineered_foundation`, `build:engineered_pillar`, `build:engineered_stairs`, `build:engineered_wall`, `build:engineered_window`, `build:fortified_arched_doorway`, `build:fortified_doorway`, `build:fortified_double_arched_doorway` and 90 more (ledger column finding_ids). Correction: Creator/engineering decision: let a filled container supply the `water` ingredient (recommended) or remove water from these recipes; until then mark blocked for non-desert starts. Test: Draw water at a river and craft Leather / Concrete.

## 10. Station and tier defects

- **GA-20** (HIGH, confirmed defect): Burning stations: Smithy, Blast furnace and Master smithy craft only while lit; a cold one needs Charcoal or Coal in the pack to light it, which the guide never mentions. Evidence: structures.json blacksmithy/large_forge/master_forge craft_needs_lit, fuel 'fuel', fuel_s 1800; server_items.gd:13066-13092, 13209-13220; test_stations.gd:131, 162-163 (passed on David4 at dc2fa52). Goals (79): `build:blacksmithy`, `build:large_forge`, `build:master_forge`, `craft:hand_saw`, `craft:heavy_crossbow`, `craft:hinges`, `craft:iron_arrow`, `craft:iron_axe`, `craft:iron_band`, `craft:iron_battleaxe`, `craft:iron_bolt`, `craft:iron_breastplate`, `craft:iron_brigandine`, `craft:iron_buckler` and 65 more (ledger column finding_ids). Correction: Add 'the station must be lit, or keep Charcoal or Coal in your pack and crafting here lights it (1 fuel per 30 min)' to the station rows and the Journal station detail.
- **GA-21** (HIGH, confirmed defect): Sawmill placement rules (a foundation raised at least 0.5 m beside fast deep water) are not taught. Evidence: structures.json saw_mill needs_base_lift_m 0.5, needs_running_water; server_items.gd:3786-3792, 3835-3875 (refusals; _station_site accepts any foundation:true piece lifted 0.5 m, so the Crude - Foundation of main row 28 qualifies: structures.json thatch_floor max_rise_m 0.6); data/water_flow.json. Goals (1): `build:saw_mill`. Correction: Tell the player to raise a Crude - Foundation 0.5 m at a fast river bank first; say the Sawmill is optional (hand saw yields are equal). Test: Place a Sawmill in a typical world; record whether a qualifying river is usually reachable.
- **GA-23** (MED, owner decision): Bronze comes after iron in the main route; the approved catalog supports both orders, and the Stone - Forge adds nothing at that point. Evidence: DYNASTY_MASTER_ITEMS.md s2.7 item 1 [D1] (Dave: a wilderness route to the Iron Hand Saw with no bronze step) and item 4 [C] (bronze is a real rung before iron, keeping that wilderness route); the draft follows item 1; structures.json blacksmithy also forge 1 (the Smithy already serves bronze recipes); test_stations.gd:103-122. Goals (9): `build:stone_forge`, `craft:bronze_hammer`, `craft:bronze_ingot`, `craft:bronze_pickaxe`, `craft:bronze_sword`, `craft:copper_ingot`, `craft:tin_ingot`, `gather:copper_ore`, `gather:tin_ore`. Correction: Creator decision (Q11): keep iron first (item 1) and present bronze as an optional side rung, or move main rows 83-91 directly after the Smelter (item 4).
- **GA-26** (MED, confirmed defect): Construction tiers in the main route are incoherent: four lone foundations, no walls/roofs for those tiers, doors placed after the Master smithy without a real dependency. Evidence: Main rows 79-82 and 106-118; costs per blueprints.json show Rustic/Refined/Sturdy doors need only planks/boards and iron, Engineered needs no steel (ws_walk_late.md construction matrix). Goals (8): `build:brick_foundation`, `build:engineered_door`, `build:foundation_section`, `build:log_foundation`, `build:refined_door`, `build:rustic_door`, `build:sturdy_door`, `build:wood_foundation`. Correction: Teach each tier as a block (foundation, wall, doorway, door, window, roof) at the point its materials first exist.
- **GA-27** (MED, confirmed defect): Stonecutter's bench is a dead end in the main route: every recipe keeps a Bronze - Chisel the route never makes. Evidence: recipes.json bench_stone_block, carved_stone_block, carved_stone_shingle keep bronze_chisel; master s2.1 chisel is sculpture/art only. Goals (1): `build:stonecutters_bench`. Correction: Move it to the side branch, or add craft:bronze_chisel before it.
- **GA-28** (LOW, confirmed defect): Workbench levels are not explained; the draft implies the Carpenter's bench is needed for the Stone - Workbench. Evidence: structures.json workbench/log_workbench/stone_workbench station_level 1/2/3, add-ons tool_rack/vice +1 each (server_items.gd:13184-13190); water_wheel and spyglass need L3; test_stations.gd:80, 117. Goals (6): `build:log_workbench`, `build:stone_workbench`, `build:tool_rack`, `build:vice`, `craft:spyglass`, `craft:water_wheel`. Correction: State the level each station or add-on gives and what it unlocks; offer Workbench + Tool rack + Vice as the cheap level 3.
- **GA-29** (LOW, confirmed defect): Add-on rows do not say which station they attach to or what they do. Evidence: structures.json bellows/quenching_trough addon_of brick_forge (adds_level false; within 5 m of a Smithy), fireplace_cooking_crane addon_of fireplace; smithing.json temper; server_items.gd:13064-13065. Goals (4): `build:bellows`, `build:fireplace_cooking_crane`, `build:master_forge`, `build:quenching_trough`. Correction: One placement-and-effect sentence each (Master smithy: +1/+2 craftsmanship).
- **GA-31** (HIGH, confirmed defect): 24 goals target blueprints that no player can build (locked water network, garden pieces, Wool - Rug). Evidence: blueprints.json rows known:false, locked:true; server_items.gd:8138 (_can_blueprint refuses unknown rows); test_blueprints.gd:199. 23 are approved catalog KEEP (buildables_plan.md B6), Wool - Rug is FUTURE. Goals (24): `build:clay_pipe_elbow`, `build:clay_pipe_run`, `build:clay_pipe_tee`, `build:iron_deep_well_pump`, `build:iron_hand_pump`, `build:iron_pipe`, `build:iron_pipe_elbow`, `build:iron_tap`, `build:stone_channel`, `build:stone_channel_corner`, `build:stone_channel_tee`, `build:stone_cistern`, `build:stone_raised_cistern`, `build:stone_trough` and 10 more (ledger column finding_ids). Correction: Keep them out of the active guide (future list) until the blueprints are made learnable.
- **GA-32** (LOW, design recommendation): Main-route rows without a purpose at that point (sand at 35, thread at 44, Leatherworking table, Tailor's table, Loom, Preserving jar). Evidence: First consumers come much later (mortar at main 69; thread consumers in side branches). Goals (6): `build:leatherworking_table`, `build:loom`, `build:preserving_jar`, `build:tailors_table`, `craft:thread`, `gather:sand`. Correction: Move each next to its first use or state its purpose.
- **GA-33** (LOW, design recommendation): Generic station rules (2.5 m spacing, hotbar tools, oven near the hearth) should appear once in the guide. Evidence: structures.json gap_m 2.5; server_items.gd:8418, 5979-5983, 8155-8156. Goals (3): `axe`, `build:oven`, `workbench`. Correction: Add a short 'building basics' Journal entry.

## 11. Server completion, persistence and payout

How the engine works today: goals live in `starter_goals.json` and `camp_goals.json`; `_goal_event` and `_goal_made` increment per-character counters (`event:<name>[:<what>]`, `made:<item>`); `_goals_check` tests every goal for the player after each event and on the 0.25 s slow tick; a completed id goes into `goals_done` and its reward is paid once. Goals, counters and coins are saved together in one atomic `characters.json` write. The client receives only the notice text.

- **GA-40** (HIGH, confirmed defect): `after` prerequisites gate completion, contrary to 'goals are guidance, not locks'. Evidence: server_items.gd:15740-15747 (_goal_open) used at 15763; legacy chain fibre -> twine -> axe -> fell -> ...; counters keep counting so event/made goals pay late, possession goals can be lost; test_goals.gd 'a goal done early waits for its after' (passed on David4). Goals (26): `axe`, `bed`, `berries`, `candle`, `dry_berries`, `fell`, `fire`, `fish`, `fur_for_winter`, `hammer`, `hoe`, `jerky`, `knife`, `night_walk` and 12 more (ledger column finding_ids). Correction: Drop `after` from the completion test; keep it only for display order and Journal prerequisite links. Test: Out-of-order: build a lean-to before gathering 12 fibre; confirm immediate credit.
- **GA-41** (HIGH, confirmed defect): Possession checks lose credit and accept bought/admin/chest items. Evidence: server_items.gd:15715-15734 (have_item, have_item_any, or_have); starter_goals.json fibre have 12, hammer/hoe have_item_any, winter_store hold 5, fish fallback, axe or_have; Hob sells plant fibre, stone axe, twine, torch (data/npcs/shops.json). Goals (6): `axe`, `fibre`, `fish`, `hammer`, `hoe`, `winter_store`. Correction: Use history counters (made:, got:) instead of current possession; winter_store's 'hold 5' is a creator call. Test: Make twine as fibre arrives; confirm the fibre goal still completes.
- **GA-42** (HIGH, owner decision): Legacy item rewards conflict with money-only rewards (twine pays 4 sticks, fell pays 3 kindling, story's +1 reputation is ignored). Evidence: starter_goals.json twine/fell reward.item; camp_goals.json story reward.rep (ignored at server_items.gd:15766-15775); test_goals.gd asserts the sticks and kindling (passed on David4). Dave's standing ruling: coin rewards stay as they are until he says otherwise. Item rewards save to inventories.json before characters.json (server_items.gd:1490, 1545): a crash between them can pay an item reward twice. Goals (3): `fell`, `story`, `twine`. Correction: Recommend the draft's own coin values (twine 4, fell 6, story 3 copper) replace the item and reputation rewards (Q3).
- **GA-43** (MED, confirmed defect): Some item-making paths never credit craft goals (kiln charcoal, fire cooking, pick yields, legacy instant craft). Evidence: _goal_made is called only from _craft_tick (server_items.gd:17414); uncredited: 9170-9203, 9223-9278, 9421-9449, 9834-9864, 7650-7668, 1218 (ACT_CRAFT). Goals (2): `craft:charcoal`, `craft:roast_forage`. Correction: Add one made-credit helper to the player-driven paths; decide whether purchases count (they should not). Test: Make charcoal in the Kiln; roast food on a fire.
- **GA-44** (MED, confirmed defect): Made counts are per craft action, not per item: count>1 goals mean 'crafts', not 'items'. Evidence: server_items.gd:17414 (one _goal_made per finished craft), 17396-17401 (a sealed batch counts once); jerky needs 2 crafts = 4 jerky; twine 2; dry_berries 3. Goals (3): `dry_berries`, `jerky`, `twine`. Correction: Count units produced (recommended) or say 'crafts' in the text.
- **GA-45** (MED, confirmed defect): Activity goals for log chopping and fire size have no server event. Evidence: Only drink, ate_food, fire_lit, carcass_worked, dug_under, path_laid, tree_felled, fish_caught, placed, wanted_order, sold are emitted (_goal_event calls). Fire tiers verified: 3 firewood-class pieces -> medium, 3 logs -> bonfire, a hung pot caps at medium, damp wood one tier lower (cooking.json min_pieces 3, fire_tiers; server_items.gd:7345-7365, 7354-7355, 7361, 7614); tier changes in ~10 places (2460, 4127, 4544, 7440/7443, 7484, 7512, 7548, 7581, 7614, 9819). Goals (3): `activity:bonfire`, `activity:chop_log_blocks`, `activity:medium_fire`. Correction: New events: log_chopped in _chop_loose_log; one fire-tier helper emitting fire_tier with the acting peer (store last_peer on the fire). Medium = tier >= medium. Test: Grow a fire to medium and bonfire; chop a log.
- **GA-46** (MED, owner decision): Gather goals have no acquisition event; which acquisitions count is undecided. Evidence: No pickup/harvest path calls a goal hook; _report_gains (server_items.gd:4929-4947) only feeds the client; chest withdrawals are reported as pickup (10042-10066). Goals (20): `gather:animal_fat`, `gather:bone`, `gather:clay`, `gather:copper_ore`, `gather:flax`, `gather:flint`, `gather:hide`, `gather:iron_ore`, `gather:limestone`, `gather:log`, `gather:log_oak`, `gather:log_spruce`, `gather:pine_tar`, `gather:sand` and 6 more (ledger column finding_ids). Correction: Add got:<item> counters for first-hand sources only (pickup, harvest, dig, mine, carcass, fishing, crop); creator to confirm bought/looted/chest items do not count (Q6).
- **GA-47** (MED, confirmed defect): One item pays two milestones (legacy any-of checks overlap the new tier goals); data lists a non-item. Evidence: starter_goals.json hammer have_item_any [wooden_hammer, wooden_hammer_soft, stone_hammer] (wooden_hammer_soft is a recipe id, not an item); hoe [wooden_hoe, stone_hoe, steel_hoe] (iron_hoe missing); workbench what_any [workbench, log_workbench] (test_goals.gd 'a log workbench also completes the workbench goal'). Goals (3): `hammer`, `hoe`, `workbench`. Correction: Each legacy goal checks only its own basic item; each upgrade pays only its own goal.
- **GA-48** (LOW, design recommendation): Overlapping goal chains (craft/place/light campfire; craft/place chopping block; bed and Thatch - Bed; knife and Stone - Knife; fell and Collect a log; pine tar and Tar; winter store). Evidence: ws_catalog.md section 5; legacy knife check is carcass_worked while its title crafts the knife. Goals (13): `activity:place_campfire`, `build:log_workbench`, `craft:campfire_kit`, `craft:chopping_block`, `craft:rough_bed_kit`, `craft:steel_hoe`, `craft:stone_hammer`, `craft:stone_hoe`, `craft:stone_knife`, `craft:tar`, `gather:log`, `knife`, `winter_store`. Correction: Keep each only where it teaches a distinct action; otherwise group (owner decision with the reward model, Q2).
- **GA-49** (MED, confirmed defect): Performance: every goal is re-checked for every player 4 times a second and on every event. Evidence: server_items.gd:15792-15822 (_goals_tick), 15749-15789 (_goals_check loop), slow tick 0.25 s (376, 1395); estimate 2-5 ms per player per tick at 651 goals, 65-170 ms for 32 players (not measured; the _goals_detail slow-tick split can measure it). Correction: Index goals by counter key; test only goals listed under the changed key; full catch-up once at join. Test: Measure _goals_detail with the 651-goal data on David4.
- **GA-50** (MED, owner decision): Goals are per character: every new character can earn the whole catalog again, and coins can move between characters. Evidence: identity_provider.gd:1-24 (character = account key); server_items.gd:593-604 (forget_key), 9948 (looting remains), 12811-12815 (death moves the purse). Correction: Creator decision (Q5): accept, or cap rewards per account.
- **GA-53** (LOW, confirmed defect): Stale metadata: needs_code true on four working goals; '_about: read by nothing yet' in both goal files. Evidence: camp_goals.json needs_code on jerky, salted_fish, story, night_walk; server_items.gd:15635-15640 reads both files; test_goals.gd covers story and night_walk. Goals (4): `jerky`, `night_walk`, `salted_fish`, `story`. Correction: Fix when the canonical goal file replaces them.
- **GA-54** (LOW, design recommendation): Admin actions earn goals (admin give, free crafts, free-build placements). Evidence: server_items.gd:1232-1241, 8435. Correction: Exclude admin actions or flag admin characters.
- **GA-55** (MED, confirmed defect): Save window: goals, coins and counters are saved together atomically, but up to ~30 s can be lost on a crash. Evidence: server_items.gd:18178, 5221-5260 (one atomic characters.json write), 50 and 1425-1435 (30 s autosave when dirty); clean shutdown saves synchronously (terrain_server.gd:2943). Correction: Bring the next save forward after a completion. Test: Kill the server after a completion; confirm state on restart.
- **GA-56** (HIGH, owner decision): Migration: existing characters' counters would complete many new goals at once. Evidence: made:* and event:placed:* counters exist since 31 Oct 2026; keep the 28 legacy ids and counter formats (hints.json 14 goal references; test_goals.gd); add a goals_v version and run catch-up once at join. Correction: Creator decision (Q4): pay, grandfather without pay, or pay main route only; never re-pay a done id.
- **GA-57** (MED, confirmed defect): The draft has no stable goal IDs. Evidence: PLAYER_GOALS_REWARDS_DRAFT.md rows carry only an HTML marker (craft:<item>, build:<structure>, ...); goal ids from structure keys no longer match names (build:thatch_* = Crude). Goals (623): `activity:bonfire`, `activity:chop_log_blocks`, `activity:medium_fire`, `activity:place_campfire`, `activity:place_chopping_block`, `build:antler_mount`, `build:apothecary_cabinet`, `build:armour_stand`, `build:bellows`, `build:bench`, `build:blacksmithy`, `build:board_rack`, `build:bookcase`, `build:bottle_and_jar_rack` and 609 more (ledger column finding_ids). Correction: Adopt the ledger's IDs (legacy ids unchanged; others '<kind>:<key>'); never derive display names from ids.
- **GA-38** (MED, design recommendation): One carcass dressing would pay several goals at once (legacy knife plus hide, bone, animal fat once got: counters exist); site-finish credit goes to the finisher, not the placer. Evidence: carcass_worked (server_items.gd:2335) completes the legacy knife goal; the same dressing yields hide, bone, fat and sinew (carcass.json); site finish 8452-8474, 8954. Goals (4): `gather:animal_fat`, `gather:bone`, `gather:hide`, `knife`. Correction: Accept as a teaching burst with small gather rewards, or merge into one 'dress your first carcass' goal (part of Q2).

Migration plan (recommended): keep the 28 legacy ids and counter formats (hints and tests depend on them); add a `goals_v` version to the character; on first join after the change, run one catch-up check from the stored counters and decide (creator) whether those completions pay; never pay a done id twice; queue the resulting notices (GA-89).

## 12. Economy, with recommendations in copper

All values in integer copper (10 copper = 1 bronze, 10 bronze = 1 silver, 10 silver = 1 gold). The model is `tools/economy.py` (deterministic). Gathering rates are ASSUMED (nobody has timed them); real play time is UNKNOWN and probably several times the modeled time.

| Scope | Goals | Draft | Recommended |
|---|---|---|---|
| All goals | 651 | 15670 | 3056 |
| Main route | 118 | 2826 | 1304 |
| Additional | 533 | 12844 | 1752 |

Reference wages: picking about 0.2 copper/min (Dave's rule: 4 hours of full-time picking pays about 40 to 60 copper, `docs/ECONOMY_FIRST_DAY.md:3-6`; 0.2 is the midpoint Sal used); Hob's daily wanted order about 8.4/h; Hob's purse ceiling 300 then +100 per real hour (`data/npcs/shops.json`, `server_trade.gd:397-414`). Goal coin bypasses the purse (`server_items.gd:15771-15772`).

- **GA-70** (HIGH, owner decision): Total payout 15,670 copper is far above ordinary earning (ASSUMED model: 14.6x the picking wage over the modeled work; 1.70x the net coin Hob could pay one player). Evidence: tools/economy.py -> work/ws_economy.json totals. Picking wage: Dave's rule '4 hours of full-time picking pays about 40 to 60 copper' (0.17-0.25/min; docs/ECONOMY_FIRST_DAY.md:3-6), 0.2/min is the midpoint used by Sal (line 38). Hob: purse 300 then +100 per real hour (data/npcs/shops.json; server_trade.gd:397-414), so over the modeled 89 h at most 300 + 8,915 = 9,215 net (buying from Hob refills the purse: server_trade.gd:335, 517; the purse is shared by all players, so this is a single-player ceiling). Goal coin bypasses the purse (server_items.gd:15771-15772). Both ratios rest on the ASSUMED effort model (a lower bound): if real play takes 1.7x the modeled time or more, Hob's ceiling exceeds the draft total, though the picking-wage ratio stays above 8x until play takes 1.8x longer. Correction: Recommended ~3,056 copper (main route 1,304) with class bands and a family-lead model (Q2). Test: Time real play to calibrate.
- **GA-71** (HIGH, design recommendation): Rewards follow dependency depth, not effort or significance; variants take most of the money; stations are not monotone. Evidence: Spearman reward vs level 0.886, vs effort 0.319 (additional route); L15 79/84 pay 60, L17 all 120; Crude chair/table/bench/stool 80 each vs Smithy 40; Stone - Workbench 120 vs Blast furnace 40; furniture/placeables 4,827 and building pieces 4,275 of 15,670 (ws_economy.md E-02..E-04). Correction: Price by class (ws_economy.md bands), family leads pay the band, variants 1-2 plus a small effort top-up.
- **GA-72** (MED, design recommendation): Tier-entry materials are priced inversely (Wooden pin 30 vs first Iron ingot 7; Concrete 40; Steel 15). Evidence: goals_parsed.json coin_copper; ws_economy.json recommended. Goals (9): `craft:concrete`, `craft:hardwood_board`, `craft:hinges`, `craft:iron_band`, `craft:iron_ingot`, `craft:lumber`, `craft:nails`, `craft:steel_ingot`, `craft:wooden_pin`. Correction: Iron 15, steel 25, concrete 15, plank/board 8, fasteners 7.
- **GA-73** (MED, owner decision): Early cash shock: by main goal 38 the draft has paid 200 copper, enough to buy one of everything Hob sells (198). Evidence: ws_economy.md milestones; Hob stock prices (data/npcs/shops.json). Correction: Creator: should the first hour pay about one picking day? (Q2)
- **GA-74** (LOW, design recommendation): Bonfire pays twice the medium fire for about two minutes more work. Evidence: goals_parsed.json activity:bonfire 10, activity:medium_fire 5. Goals (1): `activity:bonfire`. Correction: 5 copper.
- **GA-75** (LOW, design recommendation): Catalog/economy notes outside this audit's authority (report only). Evidence: Crude door 50 stick + 100 twine (350 copper of inputs) vs Rustic 5 planks; Fortified double door 1,800 of inputs; charcoal value 0.15 rounds to 0 (server_trade.gd:371); species logs sell for 24-48 with no lot rule (E-10); steel_striker live recipe for a FUTURE item (recipes.json #183; recipe_table.gd:49 no future filter); four Log furniture items live while their structures are retired. Correction: For the catalog owner; no change proposed here (catalog freeze).

Legacy item rewards: see GA-42 in section 11.

Recommended bands (copper):

| Goal class | Lead | Variant |
|---|---|---|
| First gather of a raw material | 3 (5 for ores, limestone, flint, pine tar, Tanbark, hide, fat, wool, flax) | - |
| Teaching action (place, chop, fire size) | up to 5 | - |
| Station tier 1 / 2 / 3 / 4 | 10 / 20 / 40 / 80 | - |
| Station add-on | half the station band | - |
| Tier-entry material | iron ingot 15, steel 25, bronze 10, copper/tin 5, concrete 15, plank/board 8, leather 8, charcoal 5, brick 4 | - |
| Other intermediate, material tier 1-5 | 3 / 4 / 5 / 7 / 10 | - |
| Building piece, tier lead (Crude / Rustic / Sturdy / Superior / Refined / Engineered / Fortified) | 7 / 7 / 10 / 12 / 15 / 25 / 40 | 2 |
| Door of a tier | half the piece band (min 3; 5 on the main route) | 1 |
| Metal tools and weapons (bronze / iron / steel) | 10 / 12 / 15 on the main route; off-route working tools 5 | 3 / 3 / 4 |
| Food (first dish per cooking station) | 5 | 2 |
| Clothing, containers, medicine, placeables (first per family) | 3 / 5 / 8 / 10 / 12 by material tier | 2 |
| Every non-legacy goal | plus half the picking wage for the modeled work |  |

These are recommendations only. Coin rewards stay as they are until Dave decides (section 17, Q2 and Q3).

## 13. Journal, HUD, placard and keyboard

- **GA-80** (HIGH, confirmed defect): J, G and M are taken or unwired: J = jitter test, bare G = Admin Fly (and Store All in the inventory), Ctrl+Shift+G = GPU probe; M unused. Evidence: key_bindings.gd:50, 53, 65, 66; terrain_client.gd:4289-4293 (the inventory branch returns first, so plain-G Store All is safe). Correction: Move admin/debug actions per ADMIN_KEYBINDINGS_POLICY.md before adding J/G/M.
- **GA-81** (HIGH, confirmed defect): Modifiers are ignored for held and inventory actions: Ctrl+Shift+G with a container open runs Store All; Ctrl+Shift+R runs Repair. Evidence: key_bindings.gd:200-201 (matches() skips modifiers for held/inventory rows). Correction: Reject events holding both Ctrl and Shift for those rows.
- **GA-82** (HIGH, confirmed defect): Admin defaults break the Ctrl+Shift rule today, and hard-coded keys bypass the binding table. Evidence: key_bindings.gd:53-70; terrain_client.gd:4347-4349 (plain +, numpad +/- spring controls); terrain_preview.gd:228 (bare G fly in a dev scene). Correction: Apply the policy map; remove hard-coded keys.
- **GA-83** (HIGH, confirmed defect): Several admin actions have no server-side authority check (fly, NPC teleport, jitter teleport, spring water rate). Evidence: terrain_server.gd:1138 (spring rate, no admin check); check_admin false today so everyone is admin; dig, rabbit, spyglass and starter items are checked. Correction: Add server checks; a chord is not authorisation (security-sensitive: Dave's approval).
- **GA-84** (HIGH, confirmed defect): Saved key bindings can keep non-compliant admin chords; loader and editor accept any modifiers. Evidence: key_bindings.gd loader/set_binding/swap; user://key_bindings.json. Correction: Sanitise on load; force Ctrl+Shift on the admin group; block swapping a plain key onto it.
- **GA-85** (MED, confirmed defect): Help strings and docs name old keys (HELP_TEXT 'G or F'; Shift+F3 missing from CONTROLS.md; PROTOCOL.md header says 56, code is 118). Evidence: key_bindings.gd HELP_TEXT; CONTROLS.md; PROTOCOL.md; terrain_net.gd:40. Correction: Update in the same change.
- **GA-86** (LOW, unverified assumption): Ctrl+Shift+= and Ctrl+Shift+] cannot be typed on some layouts; editor/driver capture of F5/F8 chords untested. Evidence: ADMIN_KEYBINDINGS_POLICY.md map; German QWERTZ. Correction: Choose layout-safe primary keys; test on Dave's PC.
- **GA-87** (HIGH, confirmed defect): The design documents the Journal is told to copy are not what the live Inventory/Crafting uses. Evidence: Live inventory is drawn by art_kit.gd (redesign v4, leather/brass palette) which differs from src/client/ui/dynasty_theme.gd and INVENTORY_CRAFTING_LOOK.md; most painted art is still code placeholders. Correction: Build the Journal with ArtKit, not the cited docs.
- **GA-88** (HIGH, confirmed defect): The client receives only notice text; goals_state() is never sent; a protocol change is needed. Evidence: server_items.gd:15825 (goals_state, unused); terrain_net.gd:40 protocol 118. Correction: Three messages: join snapshot, progress deltas, a separate goal-achieved event that alone triggers placards (protocol bump: Dave's approval).
- **GA-89** (HIGH, confirmed defect): Reconnect must not replay placards and a migration would flood them. Evidence: Placards must be driven by a one-shot achieved event, not by state diff; migration may complete dozens at once (GA-56). Correction: Queue with a cap and a summary line.
- **GA-90** (MED, confirmed defect): The upper-right corner already holds the Comfort/Rested label. Evidence: HUD code (ws_ui.md U-12). Correction: Move or stack it; keep the Goals box as specified.
- **GA-91** (MED, owner decision): Which two goals the HUD shows: the draft has no display-order field; with this draft, document order and main-first are identical; legacy additional goals (fish, spear, hoe, ...) never show until all 118 main goals are done. Evidence: goals_parsed.json (118 MAIN rows precede all 533 additional); legacy after gating conflicts (GA-40). Correction: Keep the literal rule with an explicit display_order field (main route first); anything else is Dave's call (Q7).
- **GA-92** (MED, owner decision): No in-game World Map exists for the M / Map page. Evidence: No world-map UI in src/client (ws_ui.md U-05). Correction: Show Map greyed as 'coming later', or omit it until a map exists (Q8).
- **GA-93** (MED, confirmed defect): Placard: text areas, long names (up to 40 characters), denomination format and the missing coin icon. Evidence: Blank art 1448x1086 RGBA: centre panel approx. x 280-1160, y 410-560; reward box approx. x 360-1100, y 715-860 (measured on the staged image, +-20 px); the Example shows a coin stack the Blank lacks; draft text '2 silver + 4 bronze' vs game format '2 silver, 4 bronze' (_coin_words); some legacy rewards are items/rep. Correction: Two-line shrink-to-fit title; format from the copper value; coin icon from existing coin_*.png (Q9).
- **GA-94** (LOW, owner decision): Placard art is slightly translucent (body alpha 240-254), conflicting with the 23 Oct 'solid panels' rule; 2.6 MB at full size. Evidence: Alpha histogram of GoalAchieved_Blank.png (lead measurement); ws_ui.md U-17, U-18. Correction: Import only the Blank, cropped and downscaled; Dave to accept the translucency or ask for a solid version (Q9).
- **GA-95** (MED, confirmed defect): No fanfare or trumpet audio exists in the repo. Evidence: docs/SOUND_MAP.md:44 ('Goal done: none?'); no matching asset found. Correction: Commission/obtain an original or properly licensed clip with a credits entry; ship silent until then.

Key-conflict summary (contexts: world, inventory open, menu or text field, blueprint list, inspection, photo):

| Key | Today | Proposed | Verdict |
|---|---|---|---|
| J | jitter test | Journal index | OK once jitter moves to Ctrl+Shift+J |
| G | Admin Fly (world); Store All (inventory) | Journal Goals (world); Store All kept | OK: the inventory branch handles G first |
| M | unused | Journal Map | OK; no world map exists (GA-92) |
| Ctrl+Shift+G | GPU probe | Fly | Fires Store All in the inventory until GA-81 is fixed |
| Ctrl+Shift+R | - | Admin rabbit | Fires Repair in the inventory until GA-81 is fixed |
| Ctrl+Shift+= / - / ] | plain keys plus hard-coded +/numpad | spring controls, starter items | Remove hard-coded keys; layout-fragile (GA-82, GA-86) |
| Ctrl+Shift+F2..F8, N, X, L, P, J | various plain/Ctrl keys | admin and debug group | OK; editor capture of F5/F8 untested |

HUD ordering: in this draft all 118 main rows precede all 533 additional rows, so 'document order' and 'main first' give the same two goals. Legacy additional goals (fish, spear, hoe, story...) never reach the HUD until the main route is done. Recommended: an explicit `display_order` field in the approved goal data (GA-91).

Placard: 'Goal Achieved' and 'Reward' are baked into the art; title and reward text go into the centre panel and the reward box; titles run to 40 characters, so two-line shrink-to-fit; rewards are formatted from the copper value in the game's existing words ('2 silver, 4 bronze'). This audit does not design the goal UI; Dave designs the goal section himself.

## 14. Corrections with stable finding IDs

Severity: HIGH (blocks a player or pays wrongly), MED (misleads or needs a decision), LOW (polish). Class: CONFIRMED_DEFECT, UNVERIFIED_ASSUMPTION, DESIGN_RECOMMENDATION, OWNER_DECISION. Effect: the design status the finding gives its goals.

| ID | Severity | Class | Effect | Goals | Finding | Sources |
|---|---|---|---|---|---|---|
| GA-01 | HIGH | CONFIRMED_DEFECT | BLOCKED | 63 | Tanbark (tannin_bark) cannot be obtained, so the leather chain cannot be completed | A-01 |
| GA-02 | HIGH | CONFIRMED_DEFECT | BLOCKED | 4 | Pine tar cannot be obtained (Scots pine trunk only ever drops resin), so Tar, Water wheel and Sawmill are blocked | A-02 |
| GA-03 | HIGH | CONFIRMED_DEFECT | BLOCKED | 14 | Grain crops (wheat, barley, oats, rye) and flax cannot be harvested in play: the client never sends sow/harvest/water actions | A-04 |
| GA-04 | HIGH | CONFIRMED_DEFECT | BLOCKED | 104 | The `water` ingredient is obtainable only from desert cactus; filling a container never creates it | A-03 |
| GA-05 | MED | CONFIRMED_DEFECT | NEEDS_CORRECTION | 12 | Gather instructions that are wrong, placeholder or incomplete | A-06..A-10, A-14..A-16, W-L01, W-L14, C-05 |
| GA-06 | HIGH | CONFIRMED_DEFECT | NEEDS_CORRECTION | 109 | Ingredients whose source no goal teaches (the guide silently assumes them) | A-11..A-13, A-23, pass 2 |
| GA-07 | MED | CONFIRMED_DEFECT | NEEDS_CORRECTION | 39 | Side-branch goals listed before the goals that teach their prerequisites | W-18, W-L side branches |
| GA-10 | HIGH | CONFIRMED_DEFECT | NEEDS_CORRECTION | 5 | Wooden - Hammer and Chopping block steps depend on which tree was felled: the 8 key species give LARGE blocks (hammer needs small), other trees give the plain Log and only small blocks (chopping block needs large) | W-01 |
| GA-11 | HIGH | CONFIRMED_DEFECT | NEEDS_CORRECTION | 6 | 'Obtain hide' (main 45) has no hunting step before it: no main-route item can strike an animal | W-02 |
| GA-12 | MED | CONFIRMED_DEFECT | NEEDS_CORRECTION | 4 | Logs are never explained: species logs are shoulder-carried one at a time (the plain Log stacks to 5), Q puts one down, recipes and blueprints use logs within 3 m | W-04, A-14 |
| GA-13 | HIGH | CONFIRMED_DEFECT | NEEDS_CORRECTION | 2 | Firewood and small blocks: the taught action never completes the goal | W-05, R-05, C-05 |
| GA-14 | MED | CONFIRMED_DEFECT | NEEDS_CORRECTION | 3 | Placing kits (campfire, chopping block, Thatch - Bed) is never explained | W-06, W-16 |
| GA-15 | MED | CONFIRMED_DEFECT | NEEDS_CORRECTION | 1 | Campfire pot: only snaps to a small fire with no logs, but follows the bonfire step | W-07 |
| GA-16 | MED | CONFIRMED_DEFECT | NEEDS_CORRECTION | 2 | Lean-to cost and its 60 leaves are never taught | W-08 |
| GA-17 | MED | UNVERIFIED_ASSUMPTION | NEEDS_TEST | 1 | Thatch - Bed 'under cover' may be refused beside Crude pieces while the client ghost shows green | W-09 |
| GA-18 | MED | CONFIRMED_DEFECT | NEEDS_CORRECTION | 2 | Roof panels: must rest on a wall top or panel edge; mouse wheel flips rise/fall; never explained | W-10 |
| GA-19 | MED | CONFIRMED_DEFECT | NEEDS_CORRECTION | 12 | Quantities the player needs are not stated (fibre, thatch, bricks, iron, pine tar, fasteners, concrete) | W-11, W-L12 |
| GA-20 | HIGH | CONFIRMED_DEFECT | NEEDS_CORRECTION | 79 | Burning stations: Smithy, Blast furnace and Master smithy craft only while lit; a cold one needs Charcoal or Coal in the pack to light it, which the guide never mentions | W-L02 |
| GA-21 | HIGH | CONFIRMED_DEFECT | NEEDS_CORRECTION | 1 | Sawmill placement rules (a foundation raised at least 0.5 m beside fast deep water) are not taught | W-L03 |
| GA-22 | MED | DESIGN_RECOMMENDATION | NEEDS_CORRECTION | 3 | Kiln charcoal (the catalog's main fuel route) has no goal and the Kiln comes after the fuel-hungry metal steps | W-L04, R-05, C add #18 |
| GA-23 | MED | OWNER_DECISION | NONE | 9 | Bronze comes after iron in the main route; the approved catalog supports both orders, and the Stone - Forge adds nothing at that point | W-L05, reviewer round 1 |
| GA-24 | HIGH | CONFIRMED_DEFECT | NEEDS_CORRECTION | 29 | Doors: listed before their frames, How-to never says 'aim at an empty doorway', and each main-route single door needs its own empty single doorway | W-03, W-L06, C-02 |
| GA-25 | MED | UNVERIFIED_ASSUMPTION | NEEDS_TEST | 57 | Door, doorway and Crude - Roof 65 content is implemented but not yet player-verified | C-02 |
| GA-26 | MED | CONFIRMED_DEFECT | NEEDS_CORRECTION | 8 | Construction tiers in the main route are incoherent: four lone foundations, no walls/roofs for those tiers, doors placed after the Master smithy without a real dependency | W-L07 |
| GA-27 | MED | CONFIRMED_DEFECT | NEEDS_CORRECTION | 1 | Stonecutter's bench is a dead end in the main route: every recipe keeps a Bronze - Chisel the route never makes | W-L08 |
| GA-28 | LOW | CONFIRMED_DEFECT | NEEDS_CORRECTION | 6 | Workbench levels are not explained; the draft implies the Carpenter's bench is needed for the Stone - Workbench | W-L10 |
| GA-29 | LOW | CONFIRMED_DEFECT | NEEDS_CORRECTION | 4 | Add-on rows do not say which station they attach to or what they do | W-L11, W-L16, C-07 |
| GA-30 | LOW | CONFIRMED_DEFECT | NEEDS_CORRECTION | 21 | Group ingredients are named by their key item (Spruce log, Oak log, Hardwood block, Knife, Axe, Fuel) instead of the in-game labels | W-L13, W-14, pass 1 |
| GA-31 | HIGH | CONFIRMED_DEFECT | BLOCKED | 24 | 24 goals target blueprints that no player can build (locked water network, garden pieces, Wool - Rug) | C-01, W-17, W-L15 |
| GA-32 | LOW | DESIGN_RECOMMENDATION | NONE | 6 | Main-route rows without a purpose at that point (sand at 35, thread at 44, Leatherworking table, Tailor's table, Loom, Preserving jar) | W-13, W-L18 |
| GA-33 | LOW | DESIGN_RECOMMENDATION | NONE | 3 | Generic station rules (2.5 m spacing, hotbar tools, oven near the hearth) should appear once in the guide | W-15, W-16 |
| GA-34 | LOW | DESIGN_RECOMMENDATION | NONE | 2 | Fire row text: the placed kit already holds sticks; 'add sticks with F' is unnecessary; the kit description still says 'light it with fibre'; rain is never mentioned | W-12, R-13 |
| GA-35 | LOW | CONFIRMED_DEFECT | NEEDS_CORRECTION | 2 | A tree too short for one log gives no log at all | reviewer round 1 |
| GA-36 | MED | CONFIRMED_DEFECT | NEEDS_CORRECTION | 2 | Drink and eat goals only count when the player is thirsty or hungry, and a new character starts full | reviewer round 1 |
| GA-37 | LOW | DESIGN_RECOMMENDATION | NONE | 34 | Log-cost builds rely on the 3 m log rule taught once (GA-12) | reviewer round 1 |
| GA-38 | MED | DESIGN_RECOMMENDATION | NONE | 4 | One carcass dressing would pay several goals at once (legacy knife plus hide, bone, animal fat once got: counters exist); site-finish credit goes to the finisher, not the placer | reviewer round 1 |
| GA-39 | LOW | UNVERIFIED_ASSUMPTION | NEEDS_TEST | 14 | Wool goods depend on bighorn only (alpine and bare rock); whether a typical start can reach them is untested | A-16, reviewer round 1 |
| GA-40 | HIGH | CONFIRMED_DEFECT | NONE | 26 | `after` prerequisites gate completion, contrary to 'goals are guidance, not locks' | R-01, U-13 |
| GA-41 | HIGH | CONFIRMED_DEFECT | NEEDS_CORRECTION | 6 | Possession checks lose credit and accept bought/admin/chest items | R-02, C-11 |
| GA-42 | HIGH | OWNER_DECISION | NEEDS_CORRECTION | 3 | Legacy item rewards conflict with money-only rewards (twine pays 4 sticks, fell pays 3 kindling, story's +1 reputation is ignored) | R-03, E-09 |
| GA-43 | MED | CONFIRMED_DEFECT | NONE | 2 | Some item-making paths never credit craft goals (kiln charcoal, fire cooking, pick yields, legacy instant craft) | R-05 |
| GA-44 | MED | CONFIRMED_DEFECT | NEEDS_CORRECTION | 3 | Made counts are per craft action, not per item: count>1 goals mean 'crafts', not 'items' | R-06 |
| GA-45 | MED | CONFIRMED_DEFECT | NONE | 3 | Activity goals for log chopping and fire size have no server event | R-07 |
| GA-46 | MED | OWNER_DECISION | NONE | 20 | Gather goals have no acquisition event; which acquisitions count is undecided | R-08 |
| GA-47 | MED | CONFIRMED_DEFECT | NEEDS_CORRECTION | 3 | One item pays two milestones (legacy any-of checks overlap the new tier goals); data lists a non-item | R-09, C-03 |
| GA-48 | LOW | DESIGN_RECOMMENDATION | NONE | 13 | Overlapping goal chains (craft/place/light campfire; craft/place chopping block; bed and Thatch - Bed; knife and Stone - Knife; fell and Collect a log; pine tar and Tar; winter store) | C-03, W-19 |
| GA-49 | MED | CONFIRMED_DEFECT | NONE | 0 | Performance: every goal is re-checked for every player 4 times a second and on every event | R-10 |
| GA-50 | MED | OWNER_DECISION | NONE | 0 | Goals are per character: every new character can earn the whole catalog again, and coins can move between characters | R-11 |
| GA-51 | LOW | CONFIRMED_DEFECT | NEEDS_CORRECTION | 7 | Legacy goal text does not match its live check or recipe | R-12, C-06, A-24 |
| GA-52 | LOW | DESIGN_RECOMMENDATION | NONE | 5 | Loose legacy checks (bed not under cover, path not camp-to-water, any food for berries, torch crafted not carried, any knife) | R-12 |
| GA-53 | LOW | CONFIRMED_DEFECT | NONE | 4 | Stale metadata: needs_code true on four working goals; '_about: read by nothing yet' in both goal files | R-13 |
| GA-54 | LOW | DESIGN_RECOMMENDATION | NONE | 0 | Admin actions earn goals (admin give, free crafts, free-build placements) | R-14 |
| GA-55 | MED | CONFIRMED_DEFECT | NONE | 0 | Save window: goals, coins and counters are saved together atomically, but up to ~30 s can be lost on a crash | R-04 |
| GA-56 | HIGH | OWNER_DECISION | NONE | 0 | Migration: existing characters' counters would complete many new goals at once | R-11 migration plan, U-11 |
| GA-57 | MED | CONFIRMED_DEFECT | NONE | 623 | The draft has no stable goal IDs | pass 1, C-05 |
| GA-58 | LOW | DESIGN_RECOMMENDATION | NONE | 70 | 70 craft goals are intermediate components that could be grouped | C-04 |
| GA-59 | LOW | CONFIRMED_DEFECT | NONE | 0 | Draft self-audit statements are inaccurate | A, E-13 |
| GA-63 | MED | DESIGN_RECOMMENDATION | NONE | 0 | Eligible content and interactions with no goal (26 ADD recommendations) | C add candidates |
| GA-70 | HIGH | OWNER_DECISION | NONE | 0 | Total payout 15,670 copper is far above ordinary earning (ASSUMED model: 14.6x the picking wage over the modeled work; 1.70x the net coin Hob could pay one player) | E-01 |
| GA-71 | HIGH | DESIGN_RECOMMENDATION | NONE | 0 | Rewards follow dependency depth, not effort or significance; variants take most of the money; stations are not monotone | E-02, E-03, E-04 |
| GA-72 | MED | DESIGN_RECOMMENDATION | NONE | 9 | Tier-entry materials are priced inversely (Wooden pin 30 vs first Iron ingot 7; Concrete 40; Steel 15) | E-05 |
| GA-73 | MED | OWNER_DECISION | NONE | 0 | Early cash shock: by main goal 38 the draft has paid 200 copper, enough to buy one of everything Hob sells (198) | E-06, E-07 |
| GA-74 | LOW | DESIGN_RECOMMENDATION | NONE | 1 | Bonfire pays twice the medium fire for about two minutes more work | E-11 |
| GA-75 | LOW | DESIGN_RECOMMENDATION | NONE | 0 | Catalog/economy notes outside this audit's authority (report only) | E-08, E-10, E-12, C-08, C-09 |
| GA-80 | HIGH | CONFIRMED_DEFECT | NONE | 0 | J, G and M are taken or unwired: J = jitter test, bare G = Admin Fly (and Store All in the inventory), Ctrl+Shift+G = GPU probe; M unused | U-01, U-02, U-04 |
| GA-81 | HIGH | CONFIRMED_DEFECT | NONE | 0 | Modifiers are ignored for held and inventory actions: Ctrl+Shift+G with a container open runs Store All; Ctrl+Shift+R runs Repair | U-03 |
| GA-82 | HIGH | CONFIRMED_DEFECT | NONE | 0 | Admin defaults break the Ctrl+Shift rule today, and hard-coded keys bypass the binding table | U-20 |
| GA-83 | HIGH | CONFIRMED_DEFECT | NONE | 0 | Several admin actions have no server-side authority check (fly, NPC teleport, jitter teleport, spring water rate) | U-21 |
| GA-84 | HIGH | CONFIRMED_DEFECT | NONE | 0 | Saved key bindings can keep non-compliant admin chords; loader and editor accept any modifiers | U-23 |
| GA-85 | MED | CONFIRMED_DEFECT | NONE | 0 | Help strings and docs name old keys (HELP_TEXT 'G or F'; Shift+F3 missing from CONTROLS.md; PROTOCOL.md header says 56, code is 118) | U-24, U-09 |
| GA-86 | LOW | UNVERIFIED_ASSUMPTION | NONE | 0 | Ctrl+Shift+= and Ctrl+Shift+] cannot be typed on some layouts; editor/driver capture of F5/F8 chords untested | U-22 |
| GA-87 | HIGH | CONFIRMED_DEFECT | NONE | 0 | The design documents the Journal is told to copy are not what the live Inventory/Crafting uses | U-06, U-07, U-08 |
| GA-88 | HIGH | CONFIRMED_DEFECT | NONE | 0 | The client receives only notice text; goals_state() is never sent; a protocol change is needed | U-09, U-10 |
| GA-89 | HIGH | CONFIRMED_DEFECT | NONE | 0 | Reconnect must not replay placards and a migration would flood them | U-11, U-16, R-15 |
| GA-90 | MED | CONFIRMED_DEFECT | NONE | 0 | The upper-right corner already holds the Comfort/Rested label | U-12 |
| GA-91 | MED | OWNER_DECISION | NONE | 0 | Which two goals the HUD shows: the draft has no display-order field; with this draft, document order and main-first are identical; legacy additional goals (fish, spear, hoe, ...) never show until all 118 main goals are done | U-13 |
| GA-92 | MED | OWNER_DECISION | NONE | 0 | No in-game World Map exists for the M / Map page | U-05 |
| GA-93 | MED | CONFIRMED_DEFECT | NONE | 0 | Placard: text areas, long names (up to 40 characters), denomination format and the missing coin icon | U-14, U-15 |
| GA-94 | LOW | OWNER_DECISION | NONE | 0 | Placard art is slightly translucent (body alpha 240-254), conflicting with the 23 Oct 'solid panels' rule; 2.6 MB at full size | U-17, U-18 |
| GA-95 | MED | CONFIRMED_DEFECT | NONE | 0 | No fanfare or trumpet audio exists in the repo | U-19 |

80 findings: 26 HIGH, 34 MED, 20 LOW. Each goal's findings, corrections and tests are in its ledger row.

## 15. Reviewer objections and their resolution

**Round 1, challenger A** (independent general-purpose agent, read-only, did not author findings; checked HIGH findings, economy and main steps 1-20 at bc66eff). Confirmed GA-11, GA-13, GA-24 rule, GA-40, GA-41, GA-44, GA-45, GA-81, GA-88 and the draft totals (15,670; main 2,826). Ten objections, all accepted in whole or part.

| # | Objection | Resolution |
|---|---|---|
| 1 | GA-10 overstated: only the 8 key species give large blocks; other trees drop the plain Log, which chops to small blocks, so the hammer works for them. | Accepted. GA-10 rewritten to cover both cases; GA-12 corrected (plain Log stacks to 5). |
| 2 | Missed: a player who felled a plain-Log tree cannot make the Chopping block (needs a Large block; no small-to-large recipe). | Accepted. Folded into GA-10 (name a key-species tree in rows 9-11 and 16). |
| 3 | Missed: a tree too short for one log gives no log (server_items.gd:6683, 6748). | Accepted as GA-35 (fell, gather:log). |
| 4 | GA-21: 'its foundations come after it' is false; a Crude - Foundation raised 0.5 m qualifies. | Accepted. Ordering claim removed; correction names the Crude - Foundation. |
| 5 | GA-23: the approved catalog item 1 [D1] (Dave) supports the iron-first wilderness route; bronze order is a creator choice. | Accepted. Reclassified OWNER_DECISION with no status effect; new creator question Q11. |
| 6 | GA-20: a lit station needs no fuel; only a cold one needs Charcoal or Coal to light it. | Accepted. Wording corrected. |
| 7 | GA-70: Hob ceiling omits the starting 300 (1.70x, not 1.76x); depends on the ASSUMED effort model; single-player; net of purchases; picking wage is Dave's 40-60 per 4 h with 0.2 as Sal's midpoint. | Accepted. GA-70 and the summary now say 1.70x, label both ratios ASSUMED, give the sensitivity and cite the wage's true origin. |
| 8 | GA-42 recommended fell 3 copper though the draft already proposes 6. | Accepted. Recommendation is now the draft's own values (twine 4, fell 6, story 3). |
| 9 | activity:medium_fire is PASS though GA-45 says it has no completion event. | Kept by design: the brief makes design status and runtime support independent columns. The row is runtime NEW_EVENT_REQUIRED; section 1 now states how many PASS goals need runtime work. |
| 10 | Fire row never mentions rain. | Accepted into GA-34 (LOW). |

**Round 1, challenger B (gate-reviewer)** (independent gate-reviewer agent, read-only; checked all 28 main PASS rows, about 40 additional PASS rows, 20 BLOCKED/NC rows and report/ledger consistency at bc66eff). GA-01 to GA-04 source claims held against a code-wide search; headline counts reconcile; overall NOT READY verdict stands. Twelve objections; PASS inflation found on drink and berries.

| # | Objection | Resolution |
|---|---|---|
| 1 | drink is over-passed: a new character starts with full water, so drinking at once does not count; salt water and held containers also block it. | Accepted (verified server_items.gd:10218, 18408-18412, 1104-1109). New GA-36; drink and berries now NEEDS_CORRECTION. |
| 2 | berries: same mechanism with hunger. | Accepted into GA-36. |
| 3 | GA-12 applied to two log-cost builds but not the other ~20. | Accepted. GA-12 now applies only where logs are first taught; the shared rule is GA-37 (no status effect) on every log-cost build. |
| 4 | gather:clay How-to still holds a placeholder. | Accepted. Added to GA-05; now NEEDS_CORRECTION. |
| 5 | craft:wooden_block(_soft) runtime is EXISTING: the small-block recipe runs through _craft_tick. | Accepted. Runtime overridden to EXISTING; removed from GA-13 (GA-10 still applies). |
| 6 | GA-10 over-generalised (same as challenger A). | Accepted (see above). |
| 7 | GA-40 attributed to 28 goals; drink and fibre have no after. | Accepted. Now computed from the data (26). |
| 8 | GA-24 door/doorway counts imprecise. | Accepted. Count claim removed from the title. |
| 9 | Missed: one carcass dressing pays knife plus hide, bone and fat; site finish credits the finisher. | Accepted as GA-38 (design recommendation). |
| 10 | Wool goods rest on bighorn only. | Accepted as GA-39: the wool family is NEEDS_TEST (computed from the dependency graph). |
| 11 | GA-18 evidence is roof-only but was attached to floor and wall. | Accepted. Narrowed to the two roof goals. |
| 12 | GA-42 duplicated in sections 11 and 12; milestone table order. | Accepted. Fixed in the report generator. |


## 16. Evidence gaps and required tests

- **No goal is GAMEPLAY_VERIFIED.** Every completion claim needs a played check before the goal list ships.
- AUTOMATED_TESTED covers only the 11 legacy goals asserted by `test_goals.gd`: `drink`, `fibre`, `twine`, `axe`, `fell`, `fire`, `shelter`, `workbench`, `story`, `night_walk`, `fish`.
- Gathering rates and play time are ASSUMED; time a real first session before setting rewards (GA-70).
- The goal-check cost at 651 goals is estimated, not measured (GA-49).
- Door, doorway and Crude - Roof 65 content awaits Dave's BUGLIST-002 F6 check (GA-25).
- Editor capture of F5/F8 chords and keyboard layouts are untested (GA-86).

Gameplay tests named by findings:

- After a fix: strip/harvest tanbark in play, tan a hide. (GA-01)
- Fell Scots pines and confirm pine tar drops. (GA-02)
- Sow, water and harvest a crop in play. (GA-03)
- Draw water at a river and craft Leather / Concrete. (GA-04)
- Hunt and dress a deer/rabbit with the listed tools. (GA-11)
- Split firewood both ways and confirm the goal completes. (GA-13)
- Place a Thatch - Bed beside Crude walls and inside a lean-to. (GA-17)
- Place a Sawmill in a typical world; record whether a qualifying river is usually reachable. (GA-21)
- Dave's BUGLIST-002 F6 checklist (doors, doorways, Roof 65). (GA-25)
- First minutes of a new character at a river. (GA-36)
- Find and hunt a bighorn from a typical start. (GA-39)
- Out-of-order: build a lean-to before gathering 12 fibre; confirm immediate credit. (GA-40)
- Make twine as fibre arrives; confirm the fibre goal still completes. (GA-41)
- Make charcoal in the Kiln; roast food on a fire. (GA-43)
- Grow a fire to medium and bonfire; chop a log. (GA-45)
- Measure _goals_detail with the 651-goal data on David4. (GA-49)
- Kill the server after a completion; confirm state on restart. (GA-55)
- Time real play to calibrate. (GA-70)

220 ledger rows name a gameplay test (column `gameplay_test_required`).

## 17. Creator questions

| # | Decision | Alternatives | Recommendation |
|---|---|---|---|
| Q1 | How should the missing ingredients be obtained: Tanbark, pine tar, `water` from a container, grain crops and flax? | (a) Engineering fixes that follow existing data: strip Tanbark from felled oak, roll every pine trunk drop, let a filled bucket or waterskin supply the `water` ingredient, wire the farming client actions. (b) Remove the affected goals until the content works. (c) Change the recipes (catalog change). | (a). Each fix follows data that already says the item comes from that source; until fixed, keep these 120 goals out of the active guide. |
| Q2 | What total should goals pay, and should variants pay like their family lead? | (a) Keep the draft (15,670 copper). (b) The recommended bands (about 3,056; main route 1,304). (c) Group variants into family goals with one payment. | (b), with (c) for the largest variant families (building sets, doors, furniture). |
| Q3 | Should the legacy item rewards become coin? | (a) Keep twine = 4 sticks, fell = 3 kindling, story = reputation (ignored today). (b) Twine 4 copper, fell 3 copper, drop the reputation. | (b): one reward type, and no double payment on a crash (GA-42). |
| Q4 | On migration, should goals that existing characters already earned by their counters pay out? | (a) Pay them all at once (queued placards). (b) Mark them done without payment. (c) Pay main-route goals only. | (b): this is a new game with no live economy to protect, and it avoids a placard flood. |
| Q5 | Are goals per character (a new character can earn everything again) acceptable? | (a) Accept. (b) Pay once per account. | (a) for now; revisit if alt farming appears. |
| Q6 | Which acquisitions count for gather goals? | (a) First-hand only (pick up, harvest, dig, mine, carcass, fishing, crops). (b) Also bought, looted or taken from a chest. | (a). |
| Q7 | Which two goals does the HUD show? | (a) The first two unfinished in an explicit display order, main route first (equals the literal rule for this draft). (b) Skip goals whose prerequisites are unmet. (c) Mix in legacy additional goals. | (a), with `after` used only for Journal links. |
| Q8 | What should the Map page (M) show while no world map exists? | (a) Greyed 'coming later'. (b) Omit the page until a map exists. | (a). |
| Q9 | Placard art and sound: accept the slightly translucent art, add a coin icon, and how to source a fanfare? | (a) Accept translucency; coin icon from existing coin art; commission an original fanfare, silent until then. (b) Ask for a solid version of the art. | (a). |
| Q10 | Should the 24 goals on locked blueprints stay in the guide? | (a) Hide them as future goals until the blueprints are learnable. (b) Drop them. | (a). |
| Q11 | Should bronze come before or after iron on the main route? | (a) Keep iron first (catalog s2.7 item 1, the wilderness route to the Iron Hand Saw) and show bronze as an optional side rung. (b) Move bronze directly after the Smelter (s2.7 item 4). | (a): it keeps the route the draft already teaches and costs no reordering; the Stone - Forge then becomes optional. |

## 18. Readiness assessment

**NOT READY for implementation.** Evidence:
- 144 goals (22%) are BLOCKED: they cannot be completed in play today (sections 9, 10).
- 247 goals (38%) need their instruction, order, completion rule or text corrected (sections 6, 8, 11).
- On the main route only 34 of 118 goals PASS; 16 are BLOCKED and the route has a hard stop at step 45.
- 27 goals need new server events or other implementation before they can complete (section 11).
- 11 creator decisions are open (section 17), including the reward budget.
- The Journal needs a protocol change, key moves and a server-authority fix first (section 13).
- No goal has been played (section 16).

Recommended order: (1) creator decisions Q1-Q4; (2) fix the acquisition gaps and corrected route order in the approved goal list; (3) engine work: no award gating, history counters, new events, event index, protocol messages; (4) key moves and server checks; (5) the Journal and HUD from Dave's design; (6) a played first-session check with timings, then set rewards.

What already works: 230 goals PASS on code and data (34 on the main route); the tool ladders and station chains have no circular requirements; the legacy engine pays once and persists atomically; 11 legacy goals are automated-tested.
