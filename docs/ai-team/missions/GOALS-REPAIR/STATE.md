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
| WP-R1B | R1 | GA-03 client farming: sow, water, harvest, crop stage looks (A-6, A-7) | lead worker | WP-R1A (water_bed adapter) | IN REVIEW (rebase after #1091) | #1089 | | gate CHANGES REQUIRED; fixes 2/4/5/6 at `835cb0f`, 1 after rebase |
| WP-METAL | R2–R6 | Smelters, Smithies, Copper tools, Anvils, wear/repair, bins, fuel pulls (A-8..A-11 so far) | thread "Build the metalworking progression" | — | IN REVIEW (PR 1: R2a + Improved smelter) | #1092 | | |
| WP-GUIDE-UI | R7 runtime + R8 | Goal sync (protocol 119), Journal J/G/M, HUD, placard (A-12) | thread "Build the Journal, goal HUD and placard" | WP-KEYS for J/G/M | IN DEV | #1088, #1093 | #1088 → `e7d4919`; #1093 → `55b1254` | #1088 David4 371/371; #1093 David4 73/73 + test_goal_ui, check_look_names, validate_items 0 errors (HEADLESS_GODOT); picture lane not run; look/motion/sound NEEDS PLAYER VERIFICATION |
| WP-MAP | R8 | Discovered charcoal Map foundation (protocol 120, A-5) | thread "Build the discovered charcoal map" | #1088 | IN REVIEW (Journal map hookup folded in; new head and lane B pending) | #1090 | | gate PASS WITH NOTES (4 passes, on `0788ed1`; merge to `5f81dce` re-checked PASS) |
| WP-PRIM | R1/R2 | Primitive route: F1 site goal kind, F2 3 m logs, F3 manual firewood credit, F4 fire tier events, F5/P2 route tests, F9 text (baseline/PRIMITIVE_ROUTE_d990abd.md); F6-F8, F10 proposals only | lead worker | #1088, #1091 (both in dev) | IN PROGRESS | goals-repair/wp-prim | | |
| WP-GOALS | R7 | 651-row catalog correction (328 rule-only rows individually), new-station coverage, completion conditions, migration; creator-review package | lead worker | mechanics PRs (content work started in parallel) | IN PROGRESS | goals-repair/wp-goals | | |

## Next actions

1. Finish baselines; assign first ready packages (R1 sources/water/farming, admin Ctrl+Shift shortcuts, goal-state sync foundation).
2. Ask the coordinator to start separate threads for large independent packages (Journal/HUD/placard UI; charcoal Map; smelting/smithy chain) with self-contained briefs.
