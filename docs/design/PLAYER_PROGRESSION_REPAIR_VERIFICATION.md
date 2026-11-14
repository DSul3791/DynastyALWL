# Player progression repair: verification report (GOALS-REPAIR R9)

**Status: FINAL for the mission's code (R0 to R9), pending the full test run on the final `dev` head and Dave's F6 pass.** First version merged with #1105 (`dev` `d4b2473`). This update reads `dev` `55c5b2a`, the tip the mission's final full test run was started on (14 Nov ~11:10Z): every mission PR is in, through R5 (#1106), R6 (#1111), the building pieces (#1107, #1110, #1112, #1113, #1118), the goal work Dave ruled on 14 Nov (#1117, #1121, #1122, #1125) the flora join fix (#1124) and the item check fix (#1128). Plumbing (#1120) and Hoe gardening (#1119, #1123) are follow-on work Dave added on 14 Nov around 06:30Z: they are outside the mission's completion criteria, but listed here because they need his play check (section 3, rows 22 and 23).

This is the R9 report that Dave's 14 Nov brief and [CATALOG_IMPLEMENTATION_PLAN.md](CATALOG_IMPLEMENTATION_PLAN.md) §2 R9 and §5 call for. The tracker is `docs/ai-team/missions/GOALS-REPAIR/STATE.md`, with its decisions in `REPAIR_DECISIONS.md`. The original audit (`PLAYER_GOALS_REWARDS_AUDIT.md`, `PLAYER_GOALS_AUDIT_LEDGER.csv`) is kept unchanged. Section 5 lists what this mission changed against it. The play checklist is [PLAYER_PROGRESSION_REPAIR_F6.md](PLAYER_PROGRESSION_REPAIR_F6.md).

## 1. How to read this report

**Status** (one per item):

| Status | Meaning |
|---|---|
| VERIFIED BY TEST | The rule is server-side, a headless Godot test plays it through the player's own actions, and the run passed on the exact SHA. Nothing about it needs eyes or feel. |
| NEEDS PLAYER VERIFICATION | Merged and tested headless, but part of it (looks, sound, motion, feel, on-screen text, the route as a person plays it) has only been checked by tests or by reading. Dave's F6 check decides it. |
| BLOCKED | Not in `dev` yet, or waiting on other work. The reason is given. |
| DEFERRED (needs Dave) | Waiting on a decision reserved to Dave. Section 6 lists it. |

**Evidence levels** (plan §5): STATIC_READ, AUTOMATED_TEST, HEADLESS_GODOT, PLAYED_F6, MULTIPLAYER_RESTART. Nothing here is passed on compile or on a static read. **No item has reached PLAYED_F6.** On 14 Nov, 00:43Z, Dave wrote "we will not be doing any plate here until we get all of this settled"; the coordinator reads "plate" as "play". No picture lane ran anywhere, so nothing in this report has been seen in a running game. Where a test calls the server directly or gives materials with admin powers, it proves only that one mechanic, not the player's route (COMMON brief rule 5). The rows say which tests walk the route.

**Lane.** Every run was on lane B, David4 (headless). The logs are on David4 under `/work/lanerun/` and are not in the repo. Names are as the lane reported them to the coordinator.

**Caveats that apply to every row:**

- **Tested at the branch head, merged later.** Each PR was tested at its own branch head and then merged after `dev` had moved on. The merge relied on a reviewer's clean-replay check, not a rerun, unless a later full run covers it.
- **The broad run on `dev` covers #1085 to #1100.** That run was on `0bc19301`: 384/384 (372 fast, 8 timing, 4 slow), no flakes, 1198 s. validate_items gave 0 errors and 114 warnings, the same as before. check_look_names passed, and the startup smoke showed 0 SCRIPT ERRORs. Logs: `broad_dev0bc1*`.
- **#1101 and later are covered by one full run on `dev` itself: `tools/release_check.sh` on `55c5b2a`, started 14 Nov ~11:10Z.** RESULT PENDING: its numbers go here when the run ends (this PR is not merged before then, so the tested SHA stays the tip).
- **Validator baseline.** On the R6 lane (`793e018`) validate_items gave 0 errors and 114 warnings, identical to `dev`; check_look_names passed (310 names, later 312 with #1112). #1128 (in `dev` at `55c5b2a`) makes validate_items count planting as a use (crop seeds, dug-up bushes and the felled-tree seeds of #1123): in its Python emulation 47 seeds and bushes leave the dead-end list and the unused materials go from 130 to 83. So the final run's validate_items line is expected to be shorter than before; its Godot count comes from the final run, not from the 114 baseline.
- **Obtainability (`python3 tools/encyclopedia_reach.py --check`, a static reach walk of the data).** #1122 fixed the smelter walk and regenerated `encyclopedia.json`. On `55c5b2a` (the lead's check, and rerun for this report) `--check` exits 0 and `--write` is a no-op.
  - 3 items are reached but marked future in `items.json`: `large_forge_kit`, `master_forge_kit`, `steel_striker`.
  - 28 are not reached: 22 water and garden pieces whose blueprints are locked; 4 retired log furniture pieces (`log_bench`, `log_shelf`, `log_table`, `log_trough`); and `bird_trap_set` and `fish_trap_set` (placed trap states with no recipe of their own).
  - **Reconciling with Dave's 24 kept blueprints (06:26Z).** They are those 22 locked pieces, plus `wool_rug` (its blueprint is locked, but its item is reached through the `wool_rug_kit` recipe, so the walk does not list it), plus `stone_well`. #1120 unlocked `stone_well` and renamed it Improved - Well; the Primitive and Advanced wells are new blueprints, not from the 24. So 23 of the 24 are still locked: 22 pieces whose items cannot be reached, and the Wool - Rug.
- **#1095's merged head was not lane-run as a branch.** It merged at `becd736`, one reviewed commit after the lane run at `2145537` (an unused local removed). `becd736` is an ancestor of `0bc19301` (checked with `git merge-base --is-ancestor`), so the broad run on `dev` does cover it. The coordinator's relay said otherwise; the git history shows the broad run includes it.

## 2. Work merged to `dev` in this mission

| PR | What | Lane run (head, count, logs) | dev merge |
|---|---|---|---|
| #1085, #1086 | R0 documentation cleanup and follow-up fixes | docs only; gate review PASS WITH MINOR NOTES | `d990abd`, `303980d` |
| #1087 | Admin and debug keys always need Ctrl+Shift | `c024edd`, 73/73; `pr1087_plan`, `pr1087_extra` | `a17bb4b` |
| #1088 | Goal list and goal_done to the client, any-order completion (protocol 119) | `0cca037`, 371/371; `pr1088_first`, `pr1088_rest` | `e7d4919` |
| #1089 | Farming from the client: sow, water, harvest | `77ea7f3`, 189/189; `pr1089c_g1`, `_g2`, `_rest`, `_extra`. First run failed at `f105fcb` (`pr1089_g1`..`g5`) | `8c2a28a` |
| #1090 | Discovered charcoal Map (protocol 120) | `f8f2787`, 375/375 (367 fast + 8 timing); map cost in `test_map`; log folder not relayed | `2c33569` |
| #1091 | Oak tannin bark, Scots pine tar, recipe water from containers | `c619968`, 219/219; `pr1091b_first`, `_rest`, `_extra`. First run failed at `a50d304`: one real bug (refund rows lost liquid keys on load), fixed | `77460e3` |
| #1092 | R2a: Primitive and Improved smelters work by themselves | `cf8166b`, 238/238; `pr1092d_a`, `_b`, `_rest`, `_extra`. Three earlier runs failed, all fixed | `596d156` |
| #1093 | Journal (J/G/M), Goals box, Goal Achieved placard and fanfare | `3d0881fa`, 73/73 + test_goal_ui; `pr1093c_goalui`, `_plan`, `_extra` | `55b1254` |
| #1095 | Primitive route: 3 m logs, site goal kind, hand-chop credit, fire tiers, route test | `2145537`, 223/223; `pr1095b_g1`, `_rest`, `_extra`. The merged head `becd736` is covered by the broad run on `0bc19301` | `b94b1e7` |
| #1096 | Corrected 651-goal catalog for Dave's review (R7 content) | docs only, static review | `69e941e` |
| #1097 | Map sketch drawn on a worker thread | `cf83be1`, 36/36; test_goal_ui and test_map run 3 separate times each (the coordinator's 02:46Z result relay); `pr1097_twice1`..`3`, `pr1097_rest` | `272278f` |
| #1099 | R2b: Copper pickaxe and Copper axe | `bd86f165`, 255/255; `pr1099_first`, `_rest`, `_extra` | `eedef36` |
| #1100 | Goals: first-hand got_item counter, feller credit, corrected live checks | `67c0fd0`, 204/204; `pr1100_first`, `_rest`, `_extra` | `0bc1930` |
| #1101 | R3: Improved smithy without iron, Iron anvil, smithy wear | `5df0e8fc`, 252/252; `pr1101_first`, `_rest`, `_extra`, `val_deveede.txt` vs `val_1101.txt` | `54b2c51` |
| #1102 | R4: Advanced smelter (wind, two lanes, steel carbon), Advanced smithy with the Iron anvil, Steel anvil (protocol 121) | `9859d612`, 381/381; `pr1102_first`, `_rest`, `_extra`; then a reviewed test-only rename (`91079173`), not lane-run on its own | `874be30` |
| #1103 | test_wood_sources parameter rename (warning) | lane `pr1103_extra`, `pr1103_test`; also the lane's warning check on #1105 | `e2c21b5` |
| #1104 | Space, Ctrl and ladder keys do nothing while a screen is open | lane regression run `pr1104_first`, `_rest`, `_extra` (nothing broken); no headless test of the keys themselves (the movement code reads live key state); PC check only | `4eb197d` |
| #1105 | This report, the F6 checklist, the catalog recheck, the map goal events | `b3fef84`, 24/24 (the 23 selected + test_goals), 0 SCRIPT ERRORs, validate_items 0 errors; `pr1105_*`. One new warning fixed in `8e2fddf` (reviewed rename, merged without a rerun) | `d4b2473` |
| #1106 | R5: Master smithy with the Steel anvil, smithy durability and "Needs repair", hammer repair of a smithy | David4 245/246 at `348f139`; one fault fixed in `b1ec840` (reviewed), retest 8/8 at `8fda5fc`; the merged head `bf06e46` adds #1107 as a clean replay | `f25aac5` |
| #1107 | GA-18 roof panel hint once a wall stands, and the roof wheel row in Controls | `a8e89a1`, 206/206, 0 SCRIPT ERRORs | `6df3051` |
| #1108, #1114, #1116 | R9 follow-up docs (second catalog recheck, roof naming), tracker updates, Dave's 14 Nov rulings and A-42 | docs only; gate reviews passed after fixes | `edbcb10`, `7d8fd8a`, `008def0` |
| #1110 | Tier roofs as post-free panels at 45° and 65°; the `made_item_any` goal check | `27609c1`, 262/262, validate_items 0 errors, look names 308, smoke clean | `83d682a` |
| #1111 | R6: Small, Medium and Large resource bins; smithy firing and smelter fuel pulls from stores within 30 m; `bellows_iron` event | `793e018`, 263/263, 0 SCRIPT ERRORs; validate_items 0 errors, 114 warnings (as `dev`); look names 310; smoke ground ready twice. Merged head `b0f5161` is an identical replay over docs-only #1108/#1114 | `242d4cf` |
| #1112 | Fortified - Roof 45 and Roof 65 (A-39) | `1612bb8`, 263/263, validate_items 0 errors, look names 312, smoke clean | `a19d3c1` |
| #1113 | A-40 tier pieces (Fortified Window, Ceiling, Stairs, Fence; Engineered Fence, Gate), the catalog's A-42 rewards, the 26 approved goals and the A-60 order fix | full run at `d9e627f` 252/253 (the gate refund check expected iron hinges; the refund gives the group's lowest member, Bronze hinges, by design; the test was fixed), recheck at `d893fc8` PASS; merged from `f684132` (dev `192c69b` merged clean) | `0574fab` |
| #1115 | Metalworking gap tests (copper bellows, carbon waiting for fuel, repair source order, Steel - Warhammer) | tests only; covered by the later lane runs of #1112 and #1113 | `71ae0c1` |
| #1117 | Own-hand gathering: a tree's feller is credited for everything it breaks into (Dave 06:20Z, Q6) | reviewer PASS; no separate lane count recorded (covered by #1113's full run, which included it) | `f7f89f0` |
| #1118 | Roof corners at both slopes (A-37), Fortified - Roof corner (A-40), the goal-order test | reviewer PASS; no separate lane count recorded (covered by #1113's full run, which included it) | `52717a1` |
| #1119 | Hoe Garden mode and stronger levelling (follow-on, G-1 to G-3) | full run 383 pass at `c43d8bd`, recheck PASS at `437f392e`; the merged head `bd4e706` adds only `dev` `c0622d8` (disjoint) | `02c04ca` |
| #1121 | Goals pay coins only, from one stage table (A-42) | reviewer PASS at `49a4e82`, later commits docs only; no lane count recorded in the PR (the final full run covers it) | `c0622d8` |
| #1122 | `encyclopedia_reach` reads the smelting jobs; `encyclopedia.json` regenerated | tool only; `--check` exits 0 at `192c69b` | `192c69b` |
| #1123 | Garden plots, row and grid planting with a preview, felled trees drop 1 to 5 seeds (follow-on, G-5 to G-12) | full run 384 pass at `cc9c7ee5`, rechecks PASS at `71d779f0` and `42542ee0`; merged head adds only docs | `448a0a1` |
| #1124 | Join crash fix: flora workers build plain data, meshes are made on the main thread | lane: 0 of 5 smokes on the fix showed RID, "mem" or crash lines (about 1 in 8 runs showed RID lines and 1 in 12 crashed before); exact SHA not recorded in the PR | `55b38a4` |
| #1125 | Goal events for the 26 approved goals, plus `tempered` and `station_repaired` (A-43 to A-46) | first run failed 55 checks, all test-setup faults (fixed in `176067d`, `5897e9a`); David4 177/177 at `5897e9a`, 0 SCRIPT ERRORs, "goal events: 0 failures", warnings as `dev` | `fbd5c3c` |
| #1120 | Plumbing PR 1: Primitive, Improved and Advanced - Well with a daily yield (follow-on, P-1 to P-6) | full selector run at `dc89b1b3` 268 pass + 1 look-cap fail (fixed in `30eeb546`, rechecked PASS); final check PASS at `55b34f5`; gate review PASS WITH NITS | `d4a60a2` |
| #1126, #1127 | Tracker update; `test_goal_events` too-far bush check made real (test only) | docs; test only | `268067c`, `4b19f8a` |
| #1128 | validate_items counts planting as a use; gardening open points for Dave | covered by the final full run on `55c5b2a` | `55c5b2a` |
| #1094, #1098 | Tracker documents | docs only | in `dev` |

**Open, not in `dev`:** this PR (held until the final run ends) and the lead's final tracker PR.

Work that was already in `dev` before this mission and is relied on below:

- **Doors** (BUGLIST-002): #1077 at `36a3250` and #1078 at `62c24e5`. The last lane run was `94596ec`: 214 pass, 0 fail (logs `bl002c_plan`, `bl002c_extra`, per `docs/ai-team/missions/BUGLIST-002/LEDGER.md`). Report and checklist: `/mnt/project-files/buglist-002/`.
- **Roofs and building placement** (BUGLIST-001): #1068 to #1076. Lane run `8e46c4b`: 370/370 (#1068–#1074), then #1075, #1076 and the pack change #1079. Report and checklist: `/mnt/project-files/buglist-001/`.
- **Catalog baseline** (Mission 001): Phases 0–10 in `dev` (`docs/ai-team/missions/M001/MISSION_REPORT.md`).

## 3. Item by item (Dave's brief, R0 to R9)

| # | Item (brief §3/§5) | Phase | PR → dev | Test evidence | Status | What is still open |
|---|---|---|---|---|---|---|
| 1 | **Oak tannin bark** | R1 | #1091 → `77460e3` | HEADLESS_GODOT `test_wood_sources` at `c619968`. A felled oak gives its 3 bark once, at the first axe blow on its logs or in the heap if it auto-splits. A saved `bark_taken` flag stops a second drop. A standing tree gives none. | NEEDS PLAYER VERIFICATION | The bark must be seen dropping in play, then followed through tanning to leather. Amount: A-2. |
| 2 | **Scots pine tar** | R1 | #1091 → `77460e3` | HEADLESS_GODOT `test_wood_sources`. Every species row rolls per log, so pine tar now drops. The resin roll is unchanged, and a test compares it. | NEEDS PLAYER VERIFICATION | The chain pine tar → tar → water wheel has not been played. The water wheel (64.8 kg of inputs) is above the 52.5 kg new-character carry cap. That gap existed before this mission (REPAIR_DECISIONS §5). |
| 3 | **Recipe water from filled containers** | R1 | #1091 → `77460e3` | HEADLESS_GODOT `test_liquid_ingredient`, plus the textile route, the walkthrough and the inventory tests. Water is taken only when a craft succeeds; salt water never counts; cancel and refund pour it back. | VERIFIED BY TEST | 500 mL per unit is A-1. Known limits: containers on the ground or inside bags don't count, and pooling is per inventory. |
| 4 | **Farming** (sow, water, harvest) | R1 | #1089 → `8c2a28a`; server side #1091 | HEADLESS_GODOT `test_farming` (flax from wild seed through the real route, seasons, refusals, save and restart) and `test_farm_prompt` at `77ea7f3` | NEEDS PLAYER VERIFICATION | The prompts and crop stage looks (placeholder boxes) have not been seen. The world starts in summer, when the grains can't be sown (A-4). Beds have no owner. A-6 and A-7 cover how you sow and water. |
| 5 | **Starting route** (gathering, tools, logs, blocks, firewood, fire sizes, shelter) | R1/R2 | #1095 → `b94b1e7`; #1100 → `0bc1930` | HEADLESS_GODOT `test_primitive_route` at `2145537` walks hand → Stone Axe → felled oak → logs → blocks → hammer → Chopping Block → firewood → medium fire → bonfire → charcoal → Lean-to → thatch floor, with no admin gives into the pack, and checks every goal count. A fresh character drinks within 10 s. Disclosed: the test sets a 150 kg body (so the 52.5 kg carry cap is not exercised), drops the stone, stick, fibre and thatch heaps into the world itself, and gives the berry it eats. | NEEDS PLAYER VERIFICATION | The look of the 3 m log, the shoulder log and the cut band. The plain-log mesh is still 1.0 m. How log carrying feels: species logs weigh 45/32/26 kg; the plain log is 18.4 kg (A-25). WP-PRIM findings F6–F8 and F10 are proposals for Dave and are not changed. |
| 6 | **Copper / Bronze / Iron / Steel progression** | R2–R4 | #1092 → `596d156`, #1099 → `eedef36`, #1101 → `54b2c51`; Steel: #1102 → `874be30` | HEADLESS_GODOT `test_smelters`, `test_bronze_path`, `test_iron_saw_route`, `test_copper_tools`, `test_tool_ladder`, and for steel `test_advanced_smelter` (lanes, calm, carbon) at `9859d612`. There is no ore cycle: stone tools mine copper and tin, Bronze tools mine iron. On the nine baked tiles both iron boulder bodies lie under the sea (`tools/encyclopedia_reach.py` ORE_NOT_IN_WORLD), so land iron ore comes from bog iron: digging wet lowland soil with a spade (`digging.json` `bog_iron`, 4% a dig). | NEEDS PLAYER VERIFICATION | The whole metal route has never been played from an empty character. The steel ratio is A-19 (owner decision, plan §4). |
| 7 | **3 smelter tiers** | R2–R4 | Primitive and Improved: #1092 → `596d156`. Advanced: #1102 → `874be30` | HEADLESS_GODOT `test_smelters`: 20/20 and ground output; 40/40/80; 20 s per ingot; bellows 1.30×; iron only while the bellows are worked; pause and resume; two players; save, load and old-layout migration; `test_advanced_smelter`: two lanes, no progress in a calm with time kept, carbon on the input, a bronze lane, no flapping | NEEDS PLAYER VERIFICATION | The Improved smelter look is a placeholder. Banked smelt time is lost if the game crashes between saves. Costs: A-8, A-9; fuel: A-10. |
| 8 | **4 smithy tiers** | R2–R5 | Primitive (bp 9) and Improved (bp 10): #1092, #1101 → `54b2c51`. Advanced (bp 301): #1102 → `874be30`. Master (bp 202): #1106 → `f25aac5` | HEADLESS_GODOT `test_iron_saw_route`: the Improved smithy is built without iron, makes the Iron anvil, and its wear is saved; R4 updated `test_blueprints`, `test_hammer_list` and the walkthrough. R5: the Master smithy (brick 30, stone 20, log 6, iron ingot 10, the Steel anvil) makes Tempered and +1/+2 items only there. `test_mission001_walkthrough` goes stone → copper → bronze → iron → steel with no metal spawned, builds the Master smithy at that cost and stops the Advanced smelter in a calm; it passed at R5 and R6. It is a test, not a played route | NEEDS PLAYER VERIFICATION (all four) | Carry feel: the Improved smithy needs 101.4 kg of materials, and the Primitive smithy and Improved smelter 61.8 kg each, against 52.5 kg carry. Sites take materials in 2–3 trips. Costs: A-8, A-15, A-20. |
| 9 | **Copper tools** | R2 | #1099 → `eedef36` | HEADLESS_GODOT `test_copper_tools` (rows, 1.5 stones per blow, ore without a cycle, felling) and `test_tool_ladder` | NEEDS PLAYER VERIFICATION | The looks are placeholders. The Copper pickaxe's "useful role" is speed only, so its value must be felt in play. The Copper axe needs a leather strap, so it depends on the tannin route. Roster and stats: A-13, A-14. |
| 10 | **Anvils** (Iron, Steel) | R3/R4 | Iron anvil #1307, recipe 724: #1101 → `54b2c51`. Steel anvil #1309, recipe 725: #1102 → `874be30` | HEADLESS_GODOT `test_iron_saw_route`, `test_advanced_smelter` | NEEDS PLAYER VERIFICATION | The Iron anvil's dead-end warning cleared with R4 (the Advanced smithy uses it). The Steel anvil's dead end cleared with R5 (the Master smithy uses it). Costs: A-16, A-21. |
| 11 | **Smelting rules** (conversions, capacities, ground output, rates, staffed bellows, wind, steel carbon vs hopper fuel) | R2–R4 | #1092 → `596d156`; wind and carbon: #1102 → `874be30` | HEADLESS_GODOT `test_smelters`: 1 ore → 1 ingot; 1 Cu + 1 Sn → 2 Bronze; ore and fuel are taken only when an ingot completes; jobs run in priority order with banked time kept; `test_advanced_smelter` for wind and carbon | VERIFIED BY TEST for the R2 rules (`test_smelters` at `cf8166b`). VERIFIED BY TEST at `9859d612` (David4 381/381, `/work/lanerun/pr1102_first`, `_rest`, `_extra`; the merged head adds one reviewed test-only rename, `91079173`, not lane-run on its own), for what `test_advanced_smelter` asserts: at 2 m/s (half of `wind_min_mps` 4) 60 s give no output, no banked time, and the ore and fuel are kept; at 6 m/s both lanes turn 2 Iron ore into 2 Iron ingots together in about 11.83 s; a calm mid-batch keeps both lanes' time and the wind back finishes the same batch; a calm holds even a finished ingot; Coal put plainly or onto a hopper slot goes to the hopper; Coal or Charcoal dragged onto an input slot goes into the input as carbon; Iron ore with hopper fuel only makes Iron; Iron ore with carbon makes 1 Steel ingot, taking the ore, carbon and fuel once; one lane Steel and one Iron together; carbon and lane time survive save and load. NEEDS PLAYER VERIFICATION: the exact 4 m/s edge (no test runs at it), the real world wind and the windmill look, and the drag gesture in the client | Ingots on the ground last 7200 s (A-11). Wind threshold 4 m/s is A-18; carbon is dragged onto the input (A-24, protocol 121). |
| 12 | **Wear and repair** | R3/R5 | Wear counter: #1101 → `54b2c51`. Durability, "Needs repair" and hammer repair: #1106 → `f25aac5`; repair source order tested in #1115 → `71ae0c1` | HEADLESS_GODOT `test_iron_saw_route` at `5df0e8fc` (the wear counter is saved); R5's tests at `348f139` and `8fda5fc` (durability by anvil, "Needs repair" on craft, store and take-down, repair at about half cost without the anvil, ground then stores then pack, all or nothing, War Hammer refused, save of a broken and a repaired smithy) | Wear counting and the repair rules: VERIFIED BY TEST. The gesture (right-click menu, Repair, left-click, A-41) and the notices: NEEDS PLAYER VERIFICATION | Durability per tier is A-26. A repair never asks for the anvil (A-27). A worn smithy can't be taken down (A-23). Iron work on a bronze anvil wears it ×3 (A-17). |
| 13 | **Resource bins and fuel pulls** | R6 | #1111 → `242d4cf`; gap tests #1115 | HEADLESS_GODOT at `793e018` (263/263): one material per bin and 1000/5000/10000 units; a second kind refused; smithy firing from Coal or Charcoal within 30 m; smelters top up the hopper every 300 s, never the ore or carbon input; a laid fire keeps its life after a draw; bins saved and reloaded | Rules: VERIFIED BY TEST. Bin looks (placeholders), the fill surface and the notices: NEEDS PLAYER VERIFICATION | A-28 to A-34. A bin saved with mixed contents before R6 refuses new puts until emptied |
| 14 | **Building tiers** | R9 scope | Roof 45/65 on every tier: #1110 → `83d682a`, Fortified pair #1112 → `a19d3c1`. Corners at both slopes and the Fortified corner: #1118 → `52717a1`. The six A-40 pieces: #1113 → `0574fab`. Roof hint: #1107 → `6df3051` | HEADLESS_GODOT `test_blueprints`, `test_hammer_list`, `test_tier_pieces`, the roof and corner placement tests and check_look_names in the lanes of #1110, #1112 and #1113 | NEEDS PLAYER VERIFICATION | Every tier now has a Roof 45, a Roof 65 and a corner, and the enclosing set of buildables_plan line 19. Old saved tier roofs and corners reload in the wrong place: take them down and rebuild (a fresh world has none). The icons of the new pieces need a PC re-render. Costs: A-35, A-37, A-39, A-40 |
| 15 | **Doors and roofs** | R9 scope | Doors: #1077 → `36a3250`, #1078 → `62c24e5`. Roofs: BUGLIST-001 (#1068–#1076) | HEADLESS_GODOT `test_doors`, `test_door_looks` at `94596ec`; BUGLIST-001 370/370 at `8e46c4b` | NEEDS PLAYER VERIFICATION | The look per tier, the arched curves and the frame rate. Icons are not baked. Roof naming is confirmed by Dave (05:29Z: every tier has "<Tier> - Roof 45" and "Roof 65"; no plain Roof). |
| 16 | **Goals** (automatic, any order, once per character, accurate how-to) | R7 | Runtime: #1088 → `e7d4919`, #1100 → `0bc1930`, credit hooks in #1092 and #1095. Content: #1096 → `69e941e` (docs) | HEADLESS_GODOT `test_goals`: out of order, Admin mode pauses counting, rejoin pays nothing twice, save and restart, exactly one goal_done each, first-hand got_item. The catalog itself: STATIC_READ only | Runtime: VERIFIED BY TEST. Corrected catalog going live: DEFERRED (Dave 06:41Z: it stays off while it is audited and reworked) | Dave ruled the catalog's decisions 1 to 5 on 14 Nov (section 6). Coins only and the stage table: #1121 → `c0622d8`. Own-hand gathering: #1117 → `f7f89f0` (the crown, bark, seeds, roots, sapling pieces and pick-cut kindling of a tree you felled count). Server goal events for every approved goal: #1125 → `fbd5c3c`, so every approved goal can complete (catalog section "Final R9 recheck"). Going live needs GA-49 event indexing or a timing measurement on the PC. Known limit: the feller of a trunk (`_fellers`) and the lighter of a kiln (`_kiln_lit_by`) are not saved, so a split or a kiln batch after a restart, or while that player is offline, credits no one. |
| 17 | **Journal** (J Index, G Goals, M Map, view-only, clickable prerequisites) | R8 | #1093 → `55b1254`; Map page #1090/#1097 | HEADLESS_GODOT `test_goal_ui` (J/G/M/Esc, view-only selection, Learn first, Leads to, Back, one window at a time) | NEEDS PLAYER VERIFICATION | Whether it matches the inventory screen; scrolling to the selected goal; small and large resolutions. |
| 18 | **HUD and placard** | R8 | #1093 → `55b1254` | HEADLESS_GODOT `test_goal_ui` (two-titles rule, placard queue, art, fanfare file, credit row, text fit) | NEEDS PLAYER VERIFICATION | The placard's look, spin and fanfare (Dave 06:18Z: the simple generated one from #1093); HUD clearance under the Comfort and food lines. HUD order: the first goal the player can do next, then what should come next (Dave 06:26Z) |
| 19 | **Ctrl+Shift admin keys** | R8 | #1087 → `a17bb4b` | HEADLESS_GODOT `test_key_bindings`: exact Ctrl+Shift for all 16 defaults, plain/Ctrl/Shift presses refused, saved-bind migration, rebind/swap/reset, Store All kept | NEEDS PLAYER VERIFICATION (the client-side key rules are fully tested headless) | `=`, `-` and `]` with Shift on Dave's keyboard layout; the editor intercepting F5 and F8. Findings not fixed (GA-83): the spring rate has no server admin check, and fly and the NPC teleport are client-only. |
| 20 | **Discovered charcoal Map** | R8 | #1090 → `2c33569`, #1097 → `272278f` | HEADLESS_GODOT `test_map` (3 runs at `cf83be1`) covers: a blank new map; only cells near the path are surveyed or sent; each player's map is their own; practice only from new cells; a skill gain alone redraws nothing; a revisit at +3 redraws; jump, dash and cave guards; quit/rejoin persistence; no seam at block edges. Cost (David4): 84 to 123 µs per survey, 4.3 to 4.5 ms and 4.8 KB per full map send, about 55 ms per block sketch on a worker thread | Discovery rules: VERIFIED BY TEST. The look and smooth opening: NEEDS PLAYER VERIFICATION | Map Scroll mechanics are left alone (unresolved). The two map goals' events come with this PR (section 7). Constants: A-5. |
| 21 | **Integration and post-repair verification** | R9 | this report | The broad run on `0bc19301` (384/384); each later PR's lane run (section 2) | BLOCKED | Waiting on: one full `tools/release_check.sh` on the final `dev` head (planned after this PR); a multiplayer restart test (MULTIPLAYER_RESTART); Dave's F6 pass |
| 22 | **Follow-on: Hoe gardening** (Dave 06:30Z; not a completion criterion) | — | #1119 → `02c04ca`, #1123 → `448a0a1` | HEADLESS_GODOT full runs at `c43d8bd` (383) and `cc9c7ee5` (384) | NEEDS PLAYER VERIFICATION | Garden mode, one-click till and sow, plots with the hoe, rows and grids with a preview, felled trees drop 1 to 5 seeds, stronger levelling. G-1 to G-12 in `HOE_GARDENING_DESIGN.md`. Picture lanes not run; the five fantasy trees drop no seeds (G-10, for Dave); `edits_near` cost to measure on the PC |
| 23 | **Follow-on: wells** (Dave 06:30Z; not a completion criterion) | — | #1120 → `d4a60a2` | HEADLESS_GODOT selector run at `dc89b1b3`, final check at `55b34f5` | NEEDS PLAYER VERIFICATION | Three wells (100/200/600 L a day, 6/25/40 m), the Improved - Well is the old Well. P-1 to P-6. Goals: `build:stone_well` renamed and unblocked, `build:primitive_well` and `build:advanced_well` added as PROPOSED (P-6, this PR). Data note: REPAIR_DECISIONS P-4 says the Primitive well takes 1 Bucket, but the data and PR #1120 take 1 Clay - Pot; the data is what the game uses. Well models and icons not looked at |

## 4. Multiplayer, conservation and failure recovery (brief §6)

| Check | Evidence | Status |
|---|---|---|
| Two players at one smelter: a second worker is refused, ore is taken out mid-smelt, logging out pauses iron | `test_smelters` (#1092) | VERIFIED BY TEST |
| Smithy wear, bins and their contents across save and load (a broken smithy stays broken; a bin keeps its one material and amount) | R5 and R6 tests (#1106, #1111) | VERIFIED BY TEST |
| Goal events count once per act and only for the player's own hand; Admin mode pauses them | `test_goal_events` (#1125, #1127) | VERIFIED BY TEST |
| No item lost or doubled across save and load (smelter stores, old-layout migration, liquid refunds, crop stages) | `test_smelters`, `test_liquid_ingredient`, `test_farming` | VERIFIED BY TEST |
| A goal pays once across retries, reconnects and saves | `test_goals` (#1088, #1100) | VERIFIED BY TEST |
| Each player's map is their own and survives quit/rejoin; the file name is hashed; a bad file is set aside | `test_map` (#1090) | VERIFIED BY TEST |
| A real two-client session restarted mid-play | not run | BLOCKED (no MULTIPLAYER_RESTART lane yet) |

## 5. Changed audit dispositions

The audit (`PLAYER_GOALS_REWARDS_AUDIT.md`, ledger CSV) is unchanged. The findings this mission addressed, in recovery-document numbering:

| Finding | Was | Now | Where |
|---|---|---|---|
| GA-01 Oak tannin bark | no legitimate source | real source, once per felled oak | #1091 |
| GA-02 Scots pine tar | never dropped | drops per log | #1091 |
| GA-03 Client farming | client could only till | sow, water, harvest | #1089 |
| GA-04 Recipe water | stackable water only | filled containers | #1091 |
| GA-40 `after` as a lock | locked goals | display order and links only | #1088 |
| GA-41, GA-47 Live checks and first-hand gathering | possession counted | first-hand `got_item` counter; corrected checks for fibre, fish, hammer, hoe, workbench | #1100 (partial: `shortcut:` for other ground pickups) |
| GA-54 Debug play earns goals | yes | Admin mode and free crafts count nothing | #1088 |
| GA-55 Once per character, atomic | unclear | done before paid, prompt save | #1088 |
| GA-80 to GA-86 Admin keys | mixed | all Ctrl+Shift | #1087 (GA-83 server checks reported, not fixed) |
| P2 primitive route gap (F1, F3, F4, F5) | site kind lost, hand chops and fire tiers not counted | counted | #1095 |
| GA-18 Roof wheel teaching | no hint | a roof panel hint once a wall stands, and a Controls row | #1107 |
| GA-38 Hand chop and block goals | chop not counted | a block of any species counts (`made_item_any`) | #1110 |
| Audit ADD-01 to ADD-26 | recommended | approved by Dave (06:26Z); every event emitted; ADD-16 merged into `activity:temper_steel` (A-43) | #1113 (rows), #1125 (events) |
| GA-49 Event-driven goal evaluation | — | still open, needed before the catalog goes live | R7 follow-up |

## 6. For Dave's review

Everything in the table below is **PROVISIONAL**: assumed on Dave's behalf under his 14 Nov 00:36Z standing order, for his later review. Each entry is in `REPAIR_DECISIONS.md` §4, with its precedent, the files it touches and how to change it. What Dave has ruled is listed after the table.

**First: ruling R-1.** The coordinator ruled that your 00:36Z message lets provisional catalog values go into data for features your brief names. Your message does not name the catalog freeze, so you need to confirm this reading. Until you do, these values merge to `dev` only.

| ID | Question | Provisional answer |
|---|---|---|
| A-1 | Millilitres of a filled container per recipe Water | 500 mL |
| A-2 | Tannin bark per oak, and from which action | 3, once per felled oak, when its logs are first cut |
| A-3 | Water per "water the bed" | up to 8000 mL, scaled by the crop's pour_pct |
| A-4 | The world starts in summer, when grains can't be sown. Change the seasons? | No; teach spring sowing; radish, lettuce and wild seeds come first |
| A-5 | Map constants and where the Mapping skill sits | `data/map.json` values; Mapping is a root skill raised only by surveying |
| A-6 | Which seed E on an empty bed sows | the seed in hand, else the first in the pack |
| A-7 | How a bed is watered | hold a filled container, E on the crop |
| A-8 | Primitive smithy cost | 2 Hide replaced by 2 Log |
| A-9 | Improved smelter cost | clay 24, stone 16, log 2, hide 3, bronze hinges 2, bronze nails 20 |
| A-10 | Smelting fuel | 1 Coal or Charcoal per ore |
| A-11 | How long ingots on the ground last | 7200 s |
| A-12 | Goal completions for old characters before protocol 119 | none |
| A-13 | Which Copper tools exist | Pickaxe and Axe only (no Knife or Hammer) |
| A-14 | Copper tool performance | between Stone and Bronze; no iron mining |
| A-15 | Improved smithy cost without iron | stone 16, clay 10, log 4, bronze ingot 6, bronze nails 20, bronze hinges 2 |
| A-16 | Iron anvil cost | iron ingot 5 + log 1 (from the obsolete bp 164) |
| A-17 | How much faster iron wears a bronze-anvil smithy | ×3 per craft |
| A-18 | Wind needed by the Advanced smelter | 4 m/s |
| A-19 | **Steel carbon quantity** (an owner decision, plan §4) | 1 Iron Ore + 1 Coal/Charcoal in the input → 1 Steel |
| A-20 | Advanced smithy cost | stone 24, clay 12, log 6, Iron anvil 1, nails 30, hinges 4 |
| A-21 | Steel anvil cost | 5 steel ingot + 1 log |
| A-22 | Taking down an old smithy refunds the new cost | yes |
| A-23 | A worn smithy can be taken down to reset wear | no; "Needs repair" |
| A-24 | How carbon goes into the input, not the hopper | drag it onto an input slot (protocol 121) |
| A-25 | Weight of a 3 m log | species logs unchanged at 45/32/26 kg; plain log 15 → 18.4 kg |
| A-26 | Smithy durability | stone 60, bronze 120, iron 240, steel 480 crafts |
| A-27 | Does a repair need the anvil again? | no |
| A-28 | How a smithy (no hopper) gets pulled fuel | the firing takes 1 Coal/Charcoal from within 30 m when the pack has none |
| A-29 | Which resources a bin holds | the existing open_storage_bin list |
| A-30 | Which fire fuel counts for pulls | Coal/Charcoal in an unlit fire only |
| A-31 | Does a lit kiln's finished charcoal count? | yes |
| A-32 | Bin storage form | units (1000/5000/10000), no kg cap |
| A-33 | Is the 300 s pull interval real or game time? | 300 real seconds |
| A-34 | A pull that empties someone's laid fire | the fire keeps its normal life |
| A-35, A-36 | Roof names and the Roof 65 above Crude (#1110) | Naming CONFIRMED by Dave (05:29Z). Still an assumption: a Roof 65 costs the same as its Roof 45 |
| A-37 | Roof corners | one item, two placed shapes (45 and 65), taking the pitch of the panel beside it (#1118) |
| A-39 | Fortified - Roof 45/65 cost | the Engineered - Roof 45 plus 4 Iron band; the 65 the same (#1112) |
| A-40 | The missing enclosing pieces (buildables_plan line 19) | Fortified Window, Ceiling, Stairs, Fence and Roof corner, Engineered Fence and Gate; Fortified = the Engineered piece + 2 Concrete + 4 Iron band (Fence + 2 Iron band; corner + 2 Iron band) (#1113, #1118) |
| A-41 | How the hammer repairs a smithy | right-click the hammer menu, pick Repair, left-click the station |
| A-42 | Coin amount per goal | one flat amount per stage: 5 / 10 / 15 / 20 copper (start, copper and bronze, iron, steel) |
| A-43 | Audit ADD-16 is the same act as `activity:temper_steel` | merged into `activity:temper_steel`; the ADD-16 row pays nothing |
| A-44 | How often Store all and a pick blow count | once per player act |
| A-45 | Who completes `jar_matured` | only the eater of a batch they sealed |
| A-46 | Who gets `kiln_charcoal` | the player who lit the kiln, if online when it finishes |
| A-60 | Five catalog rows came after a row that needs them | each moved to just after what it needs (the HUD's first goal must be doable) |
| G-1 to G-12 | Hoe gardening values (follow-on) | `docs/design/HOE_GARDENING_DESIGN.md`. REPAIR_DECISIONS still holds an older G-3 (17 spots, 1.2 m spheres, 8 edits); the design doc and #1119's constants (3 m reach, 4 edits of up to 0.5 m, 2.5 m spheres) are what is built |
| P-1 to P-6 | Well values (follow-on) | REPAIR_DECISIONS §4 and `docs/design/PLUMBING_DESIGN.md` §4. P-4's Primitive well "1 Bucket" differs from the built 1 Clay - Pot (row 23) |

These are also listed for your review: retirements made under the approved catalog (the standalone Smithy Bellows #909, the Blast furnace and `smelt_steel` 193, the Quenching trough), and the station display names Primitive smelter and Primitive smithy (REPAIR_DECISIONS §1).

**Ruled by Dave on 14 Nov (06:18Z to 06:41Z; `REPAIR_DECISIONS.md` §1):**

1. All goals pay coins only, no items or reputation (06:19Z); the amounts are ours (06:22Z), set as A-42.
2. No catch-up payouts: he plans to wipe characters, world edits and items before testing (06:18Z). That is his action; the team does not touch live saves.
3. Gathering counts only by the player's own hand (06:20Z), built in #1100 and #1117.
4. The HUD shows the first goal the player can do next, then what should come next (06:26Z).
5. The 26 audit goals are approved; the 24 locked water and garden blueprints are kept as future goals (06:26Z). The wells (#1120) since unlocked one of them, the Improved - Well; 23 stay locked.
6. Build costs stay assumed and adjustable (06:26Z). The fanfare is the simple generated one already in `dev` (06:18Z).
7. The corrected goal catalog stays off until he says (06:41Z).

**Still open for Dave:** the PROPOSED catalog rows (27: their wording and whether to keep them, including `activity:repair_station`, the map goals' count N and the two new well goals), the provisional values above and R-1.

**Earlier questions still open** (BUGLIST-001, PLAYTEST-001): backpack carry bonus 12/18 kg, the wicker basket (+8 kg) and rucksack (+24 kg) starting values, and the pickaxe kindling amounts (5 and 10 kindling per broken log, `docs/ai-team/missions/PLAYTEST-001/combat-tools.md`).

## 7. Recheck of the #1096 catalog rows against `dev` `54b2c51c`, then `d4b2473`, then `4b19f8a` (unchanged at `55c5b2a`)

#1096 flagged these rows for a recheck once the mechanics landed. Rows blocked by R3 (now in dev: `build:blacksmithy`, `craft:iron_anvil_part` and about 196 more) and the R1B, PRIM and GUIDE-UI rows were not rechecked in this first pass; the second recheck below covers them. This is a static read of `dev` data and code. **This PR applies the changes to `PLAYER_GOALS_CATALOG_CORRECTED.csv` and `.md`,** with the lead's agreement. A row that carries a text correction becomes FIX, otherwise OK. Rewards are untouched. Counts after this first recheck: OK 195, FIX 169, BLOCKED 287 (was 178, 163, 310).

| Row(s) | Catalog verdict | Recheck on `dev` | Proposed verdict |
|---|---|---|---|
| `build:stone_forge` | BLOCKED (R2, bp 9 cost and name) | bp 9 is "Primitive smithy", costs stone 24, clay 10, log 2, hammer tier 1, with no metal (A-8). The site path that dropped the kind is fixed (#1095 F1). | **FIX** (no longer blocked; it carries the cost correction) |
| `craft:copper_ingot`, `craft:tin_ingot`, `craft:bronze_ingot` | BLOCKED (R2 smelting jobs) | Smelting jobs are live (#1092), and the owner gets `_goal_made` per ingot. The GAP-METAL-OWNER caveat stands: credit goes to the station owner only, and only while online. | **FIX** (no longer blocked; they carry the smelting-job text; the caveat stays) |
| `craft:iron_ingot` | BLOCKED (R3, Improved smelter and bellows) | The Improved smelter (bp 300) is live and smelts iron while someone works the bellows. Same owner caveat. | **FIX** (no longer blocked; the caveat stays) |
| 17 `craft:bronze_*` rows (hammer, pickaxe, axe, knife, chisel, sword, mace, shield, helm, greaves, scale shirt, scythe, sickle, spear, arrow, hinges, nails) | BLOCKED (R2) | All are at station `forge`, which the Primitive smithy (`stone_forge`, forge level 1) serves. Bronze ingots come from the Primitive smelter. | **OK**, except `craft:bronze_arrow`: **FIX** (it carries a text correction) |
| `build:log_palisade_gate` | BLOCKED (R2, needs Hinges) | Hinges (recipe 149) are 1 iron ingot at `brick_forge` level 2, the Improved smithy (`blacksmithy`, bp 10, no iron in its cost since #1101). Iron comes from the Improved smelter. The chain is reachable without a cycle. | **OK**. The blocker was R3, not R2 |
| `build:improved_smelter` (PROPOSED) | ids not re-verified | item #1304 "Improved smelter", structure state 368, bp 300 all exist. The placed kind is `improved_smelter`. | refs **verified**. Stays PROPOSED (its reward is for Dave) |
| `craft:copper_pickaxe`, `craft:copper_axe` (PROPOSED) | "key TBD" | The keys are `copper_pickaxe` #1305 (recipe 722) and `copper_axe` #1306 (recipe 723), both at `forge`. The axe needs a leather strap. | refs **verified**. Stays PROPOSED |
| `build:smelter` | FIX (its correction says the Primitive smelter "arrives with R2") | The Primitive smelter is in dev (#1092) | correction text updated in the follow-up (it is shown as "Primitive smelter") |
| `activity:map_survey`, `activity:map_redraw` (PROPOSED) | GAP-MAP-SURVEY, GAP-MAP-REDRAW | The gap is closed in this PR. `server_map.gd` raises `map_surveyed` once per survey that finds never-seen ground (a survey runs every 8 m walked) and `map_redrawn` once per survey that redraws known ground at a higher skill. Both go through `_goal_event`, so Admin mode pauses them and each goal pays once. It counts each survey, not each cell, so a survey costs one goal check (GA-49). The catalog condition says so. New checks in `test_map` (and the real goal counters with Admin mode), David4 24/24 at `b3fef84`. Survey count N is for Dave. | stays PROPOSED (reward and N for Dave); event gap closed |

**Second recheck (`dev` `d4b2473`, static).** Every row still blocked by WP-METAL R3, WP-METAL R4, WP-R1B, the `got_item` gap or the `fire_tier` gap had its goal item or structure checked for reach from an empty character. The check uses the reach model of `tools/encyclopedia_reach.py`, with the smelting jobs added, since that tool does not know the self-running smelters yet. The 258 rows whose target is reachable are no longer blocked (119 OK, 139 FIX after the roof rename; 123 and 135 before it); all of them are NEEDS PLAYER VERIFICATION. Their correction text was spot-checked, not re-read row by row. The catalog now counts **OK 313, FIX 309, BLOCKED 29** (after the A-35 roof rename moved five OK rows to FIX); rewards are unchanged (15,670 copper). The 29 still blocked are the 24 locked water and garden blueprints (now all UNASSIGNED, Dave decision 2), R5 (`build:master_forge`, `activity:temper_steel`), R6 (`build:open_storage_bin`), `activity:operate_bellows` (no `bellows_iron` event) and `activity:chop_log_blocks` (no `made_item_any` check type).

**Final recheck (`dev` `4b19f8a`, static read of data and code; no Godot run; `55c5b2a` changes only the item check, a drops note and a design doc, so it holds there).** The reward pass and #1113 had already unblocked `activity:operate_bellows` (`bellows_iron`, #1111). This PR unblocks the rest that landed: `build:master_forge` and `activity:temper_steel` (R5, and `tempered` from #1125), `build:open_storage_bin` (R6), `activity:chop_log_blocks` (`made_item_any`, #1110), the 23 approved goals whose events #1125 emits (each row's `event_emitter` names the line; `activity:store_in_chest` narrowed to chests and crates, which is what `stored_item` counts), and `build:stone_well` (#1120, renamed "Build Improved - Well"). It adds `build:primitive_well` and `build:advanced_well` as PROPOSED (P-6). The catalog now has 704 rows; the 651 ORIGINAL count **OK 314, FIX 314, BLOCKED 23**, and the 23 still blocked are the locked water and garden blueprints, nothing else. The A-42 total is 6,540 copper over 703 paying rows (6,010 on the ORIGINAL rows). The order check (no row before a row it needs) and the station check were rerun and find only the known false positives (the hammer's blocks come from chopping; lumber and boards have a by-hand recipe; the campfire serves the first clay crafts).

## 8. Still to do before R9 is complete

1. The full `tools/release_check.sh` on `55c5b2a` (running): record its numbers in section 1, then merge this PR.
2. Run a multiplayer restart test.
3. Get Dave's F6 pass with [PLAYER_PROGRESSION_REPAIR_F6.md](PLAYER_PROGRESSION_REPAIR_F6.md), including section 8 (gardening and wells).
4. Get Dave's review of the provisional values in section 6 and the PROPOSED catalog rows.
5. Before the corrected catalog goes live, time `_goals_check` on the PC with all its goals: every map survey of new ground and every other goal event runs it (GA-49).
6. Icons for the tier roofs, the 65s, the corners and the six A-40 pieces need a PC re-render.
7. Keep counting the intermittent headless RID error in later smokes (`REPAIR_DECISIONS.md` §5): 0 of 5 since #1124, cause unconfirmed.
