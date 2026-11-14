# GOALS-REPAIR (CCR05 repair) — execution state

Lead thread "Repair progression and build player guide" (project DynastyALWL2), started 14 Nov 2026 00:34Z from Dave's brief. Lead branch `claude/project-thread-21lhdk`. Decisions and assumptions: [REPAIR_DECISIONS.md](REPAIR_DECISIONS.md). Final evidence report (created when tests begin): `docs/design/PLAYER_PROGRESSION_REPAIR_VERIFICATION.md`.

Ledger states: NOT STARTED / IN PROGRESS / IN REVIEW / IN DEV / BLOCKED. Evidence levels (repair plan §2): STATIC_READ, AUTOMATED_TEST, HEADLESS_GODOT, PLAYED_F6, MULTIPLAYER_RESTART. Nothing is passed on compile alone; admin-spawned or direct-server tests do not prove the player route.

## Standing instructions for this mission

- Dave 14 Nov 00:34Z: the brief (implement, independently review and integrate the approved repairs and player guide into `dev`; `main` untouched).
- Dave 14 Nov 00:35Z: work autonomously from the documents; he checks in for updates.
- Dave 14 Nov 00:36Z (verbatim in REPAIR_DECISIONS.md §3 intro): questions meant for him are answered from his earlier rulings with a reasonable assumption and logged in REPAIR_DECISIONS.md, section "Assumed on Dave's behalf, for his review". Not for `main`, destructive or security-sensitive actions, or live/retrospective payouts. Reach into catalog data: ruling R-1.
- Dave 14 Nov 00:43:53Z (verbatim: "OK, we will not be doing any plate here until we get all of this settled"; coordinator reads "plate" as "play"): no interim F6 checks from Dave. Items stay NEEDS PLAYER VERIFICATION; one consolidated playtest checklist is produced at the end.
- Godot tests only on Dave's machines (lane B David4 preferred, via the coordinator with an exact reviewed SHA). Never in the cloud.

## Baseline (R0)

| Item | Value |
|---|---|
| Starting `dev` | `1382118e` (13 Nov 22:34 -04:00) |
| PR #1085 (CCR05 doc cleanup, head `86d23cf`) | Independent gate review PASS WITH MINOR NOTES (7 minor); merge-check green; merged to `dev` at **`d990abd`** (14 Nov). Minor findings 1-6 fixed in #1086; 7 optional, left. |
| Overlapping doc PRs | #1084 (claude/docs-cleanup-gameplay-rules-20261113): competing edit of the same Appendix A; its useful points (Appendix retitle, `forge` labelling, item 827 note) are now carried by the #1085 follow-up, so #1084 is **superseded** (left open for its owner to close). #1083 (entry-point docs: START_HERE, RULES, WORKFLOW, DOCUMENT_AUTHORITY): no overlap with this mission's files except one table row in DOCUMENT_CONTRADICTIONS; not reviewed here. #1082 (door docs, based on older `cdd7eca`): not in this mission's path; door behaviour itself is in `dev` (PRs #1077, #1078). |
| Protocol at baseline | 118 (`src/stream/terrain_net.gd`); now 119 in dev (#1088) |
| Already in `dev` and retained | Door system (empty frames, 28 separate doors, Iron/Steel doorways retired; #1077/#1078); packs without slots (#1079); BUGLIST-001 and PLAYTEST-001 fixes; Admin Reset World; catalog Mission 001 baseline. All still NEEDS PLAYER VERIFICATION per their ledgers. |
| Earlier "Add current goal display" thread | Stopped by Dave pending his design; PLAYER_JOURNAL_GOALS_UI.md is that design now. Branch check in baseline below. |

Baseline investigations (read-only, in progress): R1 resources/water/farming; goal runtime + Journal/HUD + keys; metalworking stations/bins. Results feed the work packages below.

## Shared-file ownership

`src/stream/server_items.gd` (18.5k lines) and shared `data/items/*.json` carry a per-file owner lock (CATALOG_IMPLEMENTATION_PLAN §1). D-E1 is adopted (coordinator, 14 Nov 00:44Z): **per-section** lock on server_items.gd, one owner per shared JSON, one protocol bump owner at a time (numbers assigned by the lead). Rebase on `dev` before merge; the reviewer confirms the diff stays in its sections. `src/stream/terrain_net.gd` `PROTOCOL_VERSION` + `PROTOCOL.md`: one bump owner at a time, assigned here.

| Shared file / section | Current owner | Since |
|---|---|---|
| server_items.gd: farming handlers + world-item row extras for crops | lead → WP-R1B (farming) | 14 Nov |
| server_items.gd: goals section (`_goals_*`, `_goal_event`, `_goal_made`, `goals_state`) | thread "Build the Journal, goal HUD and placard" | 14 Nov |
| server_items.gd: smelting/craft-queue stations (`_queue_craft`, queue tick, `station_near`/`serving_station`, `_speed_factor`/`_addon_factor`), station stores/out-slots, kiln, `_repair_struct`/structure wear, hopper/fuel pulls. Boundary: queue code calls the WP-R1A ingredient helpers and does not edit them | thread "Build the metalworking progression" | 14 Nov |
| server_items.gd: one hook for discovery record (new module) | thread "Build the discovered charcoal map" | on request |
| data/items/{items,structures,blueprints,recipes,boulders,smithing,building_wear}.json | metalworking thread | 14 Nov |
| data/items/drops.json, tree/trunk/log processing, `_after_built`/site paths, chopping-block split branch, fire tier hooks | WP-PRIM (from WP-R1A) | 14 Nov |
| server_items.gd ingredient stock helpers, shared `Inventory` fill helpers | WP-R1A (in dev; changes via the lead) | 14 Nov |
| src/client/key_bindings.gd, key_bindings_page.gd, game_menu.gd, CONTROLS.md, terrain_client.gd input dispatch | WP-KEYS (lead) | 14 Nov |
| src/client/held_item.gd, harvest.gd | WP-R1B (farming) | 14 Nov |
| PROTOCOL_VERSION | 119 → guide-UI thread (#1088); 120 → map thread (#1090, after 119); 121 → WP-METAL R4 (slot-targeted station put, after 120); next number on request | 14 Nov |

## Work packages

| WP | Phase | Scope | Owner | Depends on | State | Branch / PR | dev SHA | Evidence |
|---|---|---|---|---|---|---|---|---|
| WP-00 | R0 | #1085 review + merge, follow-up fixes, tracker, ruling R-1, briefs | lead | — | IN DEV | lead branch / #1086 | #1085 → `d990abd`; #1086 → `303980d` | gate review 14 Nov |
| WP-KEYS | R8 | Every admin/debug key Ctrl+Shift (defaults, saved binds, hardcoded paths), free J/G, keep inventory G | lead worker | — | IN DEV | goals-repair/wp-keys / #1087 | `a17bb4b` | gate PASS after fixes; David4 73/73, validate_items 0 errors (HEADLESS_GODOT) |
| WP-R1A | R1 | GA-02 pine tar drop, GA-01 oak bark once per felled tree, GA-04 recipe water from containers (A-1..A-3) | lead worker | — | IN DEV | goals-repair/wp-r1a / #1091 | `77460e3` | gate PASS WITH FIXES (fixed); David4 a50d304 FAILED 3 (refund rows lost liquid keys on load: real bug; 2 test faults), fixed; David4 `c619968` 219/219, validate_items 0 errors, smoke clean (HEADLESS_GODOT). Full fast run owed to post-merge broad run (terrain_net comment edit) |
| WP-R1B | R1 | GA-03 client farming: sow, water, harvest, crop stage looks (A-6, A-7) | lead worker | WP-R1A | IN DEV 8c2a28a (#1089, head 77ea7f3). David4 189/189 at 77ea7f3; replayed over #1099 (disjoint, reviewer PASS); crop looks NEEDS PLAYER VERIFICATION | #1089 | | gate CHANGES REQUIRED, then PASS WITH FIXES, then PASS |
| WP-METAL | R2–R6 | Smelters, Smithies, Copper tools, Anvils, wear/repair, bins, fuel pulls (A-8..A-11, A-13..A-24, A-26, A-27) | thread "Build the metalworking progression" | — | R2a+Improved smelter IN DEV; R2b Copper Pickaxe/Axe IN DEV; R3 Improved smithy, Iron anvil, smithy wear IN DEV; R4 Advanced smelter/smithy, Steel anvil, protocol 121 IN DEV; R5 #1106 on lane; R6 (bins, fuel pulls, A-28..A-34) reviewed locally, pushed one at a time | #1092, #1099, #1101, #1102, #1106 | #1092 → `596d156`; #1099 → `eedef36`; #1101 → `54b2c51`; #1102 → `874be30` | #1092 David4 238/238 on `cf8166b`; #1099 David4 255/255 on `bd86f165`; #1101 David4 252/252 on `5df0e8fc` (merged over 0bc1930, clean replay); #1102 David4 381/381 on `9859d612` (+ reviewed test-only rename 9107917); merged with dev b94b1e7 without retest (reviewer: clean replay); tool looks NEEDS PLAYER VERIFICATION |
| WP-GUIDE-UI | R7 runtime + R8 | Goal sync (protocol 119), Journal J/G/M, HUD, placard (A-12) | thread "Build the Journal, goal HUD and placard" | WP-KEYS for J/G/M | IN DEV, incl. #1100 (got_item counter, feller credit for auto-split logs, corrected live checks, food id on ate_food). Shortcuts pending GA-41: non-scatter ground pickups and offline-feller splits not counted | #1088, #1093, #1100 | #1088 → `e7d4919`; #1093 → `55b1254`; #1100 → `0bc1930` | #1100 David4 204/204 on 67c0fd0, merged head cf0997c clean replay (reviewer PASS); #1088 David4 371/371; #1093 David4 73/73 + test_goal_ui, check_look_names, validate_items 0 errors (HEADLESS_GODOT); picture lane not run; look/motion/sound NEEDS PLAYER VERIFICATION |
| WP-MAP | R8 | Discovered charcoal Map (protocol 120, A-5), wired into the Journal Map page | thread "Build the discovered charcoal map" | #1088, #1093 | IN DEV | #1090, #1097 | #1090 → `2c33569`; #1097 (sketch on a worker thread, David4 36/36) → `272278f` | gate PASS on `f8f2787`; David4 375/375 (HEADLESS_GODOT), test_map cost 84 us/survey, 4.3 ms / 4.8 KB map send, 55 ms per block sketch; validate_items 0 errors; visuals NEEDS PLAYER VERIFICATION |
| WP-PRIM | R1/R2 | Primitive route: F1 site goal kind, F2 3 m logs (A-25), F3 manual firewood credit, F4 fire tier events, F5/P2 route tests, F9 text (items.json text passed to WP-METAL); F6-F8, F10 proposals only | lead worker | #1088, #1091 (both in dev) | IN DEV b94b1e7 (#1095, head becd736). David4 223/223 at 2145537; unused-local fix becd736 reviewed PASS, covered by the post-merge broad run | goals-repair/wp-prim / #1095 | | |
| WP-GOALS | R7 | 651-row catalog correction (328 rule-only rows individually), new-station coverage, completion conditions, migration; creator-review package | lead worker | mechanics PRs | IN DEV 69e941e (#1096, head 268bbaa; gate re-review PASS). Catalog for Dave: 178 OK, 163 FIX, 310 blocked by mechanics, 11 proposed. Follow-ups: catalog go-live needs GA-49 event indexing or a PC timing measurement (reviewer S1); 6 OK rows with GA-19 status lack a note (S2); recheck R2 rows, build:improved_smelter and map goals against current dev | goals-repair/wp-goals / #1096 | | static review only |
| WP-BUILD | R9 scope (brief: building tiers, doors, roofs) | Seven-tier enclosing sets per buildables_plan §1-§3, Roof 45/65 no-leg attachment, roof corners, GA-18 roof wheel teaching; doors verify only (BUGLIST-002) | thread "Build the Journal, goal HUD and placard" (reassigned 14 Nov 04:21Z) | — | BUILDING (#1104 Space/Ctrl/ladder under screens IN DEV 4eb197d, NEEDS PLAYER VERIFICATION; #1107 GA-18 in review; audit /mnt/project-files/goals-repair/BUILDING_TIERS_AUDIT.md; A-35..A-37 roofs 45/65 + panel corners, GA-18 text; A-38 Fortified/Engineered gaps for Dave; numbers items 1320+, bp 310+, states 380+, recipes 740+) | | | |
| WP-VERIFY | R9 | PLAYER_PROGRESSION_REPAIR_VERIFICATION.md + consolidated F6 checklist + Dave review list (A-1..A-34) + #1096 recheck vs current dev | thread "Build the discovered charcoal map" (reassigned 14 Nov 04:21Z) | all WPs | IN REVIEW #1105 (head 86922e3; also map_surveyed/map_redrawn goal events in server_map.gd and catalog recheck: OK 195, FIX 169, BLOCKED 287). R4-R6 and building rows follow in a later PR | #1105 | | |
| WP-CLEAN | — | #1103 test_wood_sources SHADOWED_VARIABLE (from #1091) | lead | — | IN DEV e2c21b5 (#1103; David4 PASS, 0 warnings) | #1103 | `e2c21b5` | |

## Lane rule (from 14 Nov 02:51Z)

The lane runs `godot --check-only` on every changed .gd file before tests. Cloud gdparse (gdtoolkit) cannot parse `src/client/inventory_view.gd` even on dev (shader string), so a clean cloud parse is not evidence; parse_scan.py catches only duplicate/clash patterns. Lane requests need an independent review pass on the exact SHA (an author read does not count).

## Post-merge broad run (DONE)

David4 ran the release_check set (`tests_for_diff.py --paths project.godot --full`, broader than `--all`) on dev `0bc193016610d753fafcbec11ddd5e20146d7fa2`, which has #1085–#1100 but not #1101. It passed 384/384 (372 fast, 8 timing, 4 slow) with no flakes in 1198 s. validate_items had 0 errors and 114 warnings, the same as before. check_look_names passed. The startup smoke showed 0 SCRIPT ERRORs. Picture lanes were not run. Logs are in /work/lanerun/broad_dev0bc1*. This clears the debt from #1091 terrain_net, #1092 and the R1 merges.

Seven files are over the warning baseline. `test_wood_sources.gd` came in with #1091 and is fixed in PR #1103. The other six (server_items.gd 9/8, test_serving_platter, test_item_instances, test_storage_locks, storage_dialogs, item_slot) are pre-existing, and `tools/warning_baseline.txt` looks stale. Those six are unrelated to this mission and are not fixed here.

## Next actions

1. Finish baselines; assign first ready packages (R1 sources/water/farming, admin Ctrl+Shift shortcuts, goal-state sync foundation).
2. Ask the coordinator to start separate threads for large independent packages (Journal/HUD/placard UI; charcoal Map; smelting/smithy chain) with self-contained briefs.

## Temporary warnings to clear
- CLEARED by #1102: #1101 (R3) adds `iron_anvil_part` (recipe 724) and validate_items warns it is a dead-end until R4 bp 301 (Advanced smithy) uses it. Accepted as temporary; R4's lane result must show the warning gone.
- #1102 (R4) adds `steel_anvil_part` dead-end warning until R5 (#1106) uses it for the Master smithy.
