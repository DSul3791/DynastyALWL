# Mission 001 report: master items catalog implementation

Mission lead report, 12 Nov 2026. Brief: Dave's "MISSION 001 — MASTER ITEMS CATALOG IMPLEMENTATION" (12 Nov 05:33Z), with his rulings that this is a new game (05:41), that questions are decided from the documents (05:42), and that everything goes to `dev`, nothing to `main` (05:43). Detail: `STATE.md`, each task's `T*_BRIEF.md` / `T*_RESULTS.md`, and `docs/design/catalog_ledger.json`.

## Status

**Functionally complete for Phases 0–10 and 1b; not yet declared MISSION COMPLETE.** Every in-scope catalog entry is implemented, independently reviewed and covered by passing automated server-side tests, including one integrated walkthrough of the whole progression in a single world. Two mission-completion criteria are still open because they need a person at the game:
- **In-game visual, UI and two-client checks: NOT RUN.** Nothing in this mission was looked at in a running client.
- **Final art: not done.** Most new pieces, stations, furniture grades, weapons, armour, bags, foods and the Handcart use marked placeholder looks (`data/items/look_placeholders.json`, `worn.json` "placeholder").

## Ledger (1,069 entries)
| State | Rows |
|---|---|
| TESTED - ACCEPTED (automated + review; see the acceptance note in the ledger) | 230 |
| RETIRED - MIGRATION VERIFIED (numbers kept, new game: no old-save migration) | 23 |
| FUTURE-GATED | 65 |
| NO CHANGE (catalog KEEP) | 498 |
| RETIRED BEFORE CATALOG | 253 |
| NOT STARTED / IN DEVELOPMENT / BLOCKED | 0 |

Future-gated (dependencies recorded per row): the 20 animal tack rows and Riding - Boots (Phase 11 animal keeping); 9 animal vehicles and the Reinforced wagon wheel (Phase 11); Steel bolt, Iron - Lance; Ploughman's Board (dairy); and existing FUTURE rows such as coins, dairy (Milk, Butter, Cheese, Cheese press), traps, coop, fodder trough, spinning wheel, magic tonic, Obsidian - Knife, Steel - Striker, Copper pot and Fish soup. Magical enchantment application and effects stay Phase 12; the two permanent magic slots exist, are saved, and refuse replacement, but no magic works.

## Dev checkpoints (all on Dave's PC, voxel Godot 4.7.2)
`537ddb2b0` (Phases 0, 1, 1b, 2a) → `b62db1e7c` (2b, 3) → `5285e2e20` (2c) → `fefee0aa2` (4a) → `c2fc59a73` (6, 9) → `aa0ce7d2d` (4b) → `d21a4bcaa` (5) → `81f7fee01` (7, 8) → `746a36883` (10) → `0b19357cf` (2 remainders) → this PR (walkthrough, ledger acceptance, report). Each with a full or affected-test plan, `validate_items`, `merge_check`, ledger check, and a startup smoke (world loads, client joins, 0 script errors; headless exit abnormal, a known pre-existing issue).

Final evidence at `aa8113c33`: full suite 358/360 (2 known flakes), `test_mission001_walkthrough` 7/7 steps (early survival; bog iron → Smelter → fired Smithy → Iron - Saw → Planks and Hardwood boards; stations, furniture, layered armour, bags, Tempered steel; cooking, preserving, platters; three food effects; locks, Warehouse desk, Handcart moving a loaded crate; save and reload with every piece and worn item intact).

## For Dave to look at (tuning and design calls; nothing here blocks play)
1. Tier-1 desserts can give more energy than the energy drain removes (the [D17] values).
2. Hide clothing in heavy rain is much colder than before (layered warmth by fabric).
3. Kiln timings (300 s per log, self-burn 150 s) are placeholders; the catalog says kiln times are yours.
4. Charcoal on the 100-per-log scale: value rounds to 0, so Hob does not buy it; 5 fuel per smelt makes coal costly.
5. Station products now stay in the station (s2.5): a real change in feel.
6. Residual risks recorded in task results: character keys are client-supplied (a scripted client can reset its lock-guess wait); full bags dropped in the world never despawn; the Handcart passes through pieces that do not block walking; tool wear shows wrong on the client above 65,535.
7. Known test issues: `test_npc_view` crashes at quit after passing; `test_flora_density` times out under three parallel jobs and passes alone.

## AI team evaluation (mission section 13)
- **Work:** 19 tasks (T00–T19) in 11 dev merges, all through branch → independent review → PC tests → PR into `dev`. Nothing touched `main`, Dave's checkout or his saves.
- **Reviews earned their cost:** 10 of 16 reviewed tasks failed their first review, every time on a real defect or a real evidence gap: a number clash with gathered items, wrong-Smithy fuel use, an ineligible Tempered Cuirass, campfire heat counted as overheating, food batches lost on the ground, clothes weight exhausting walkers, full bags despawning, infinite energy by swapping food groups (twice), a slope-creeping cart, chain crafts losing parts at stations. Two pre-existing bugs were fixed on the way (shoulder-log duplication, craft-cancel ages), and the final walkthrough found one more (unbuilt blueprint sites working as stations).
- **Rework and conflicts:** the shared data files conflicted at almost every parallel merge; number ranges per branch prevented collisions after the first. A mission-lead script error once reset every ledger phase; `--check` now guards it.
- **Owner interruptions:** none after the autonomy direction; decisions are recorded in `STATE.md`.
- **Process limits found:** `run_tests.sh` does not run `validate_items` (run it explicitly); fresh clones lack `.import` files and world data; the smoke run's terrain server must be stopped by PID; agents twice tried to stop processes (their own) and were correctly blocked.
- **Efficiency:** heavy model use (opus engineers and reviewers for code; sonnet for data and verification reviews). Token use was high; measured totals are in the session, not in the repo.

## Recommendations for the next mission
1. A short in-game visual and UI pass by Dave on the newest dev (stations, Make-as card, food HUD, lock and desk windows, Handcart), then an Art Direction task for the placeholder looks.
2. A tuning pass from playtest notes on the items in "For Dave to look at".
3. Fix `test_npc_view`'s exit crash and give `test_flora_density` its own lane, so a clean run is 100 %.
4. A protected `dev` or a bot identity for AI merges, if Dave wants GitHub to enforce the review gate.
5. Phase 11 (animal keeping) needs a design for Dave's approval before any build.
