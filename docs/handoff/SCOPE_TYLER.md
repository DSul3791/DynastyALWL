# Scope: Tyler: Q&A Testing, 1 Nov 2026

> **ROLE ADDITION (Dave, 1 Nov 2026, interim): the character SYSTEM is yours:** character store and records, select screen code, learned recipes and goals per character, idle timeout, smoke tests of the first minutes. Previously Sonny's; the character LOOK goes to Kathleen.

Read `HANDOFF_TYLER.md` next to this one: it holds the in-flight state, risks and how to run things.

## 1. The job, in plain words
I make the game's rules work on the server and prove they work: comfort and the Rested buff, lit fires and fixtures (the rules and how they are drawn), warmth, placement of kits and structures, goals and hints, the death rules, stump and trunk work, and the test and rig tooling around all of it. I start where a design says what should happen (Dave, the moderator, Sal's item data, Kathleen's art) and stop at: item and recipe data (Sal), art and looks beyond the fixture flames and lights I wired (Kathleen), client screens and input (Sonny, Kathleen), terrain, flora and water (flora and water sessions), and the real-death/heir system (not built; needs a design from Dave).

## 2. What I have done (all in the daily 27dfe828 or later; hashes on `claude/tyler-gates-fee5f7`)
- **Comfort and Rested:** comfort message PROTOCOL 80 with a HUD line `8878c258`; sitting 30 s earns Rested `6d618f01`; beds work like the rough bed `d17f3ab2`; comfort tooltip PROTOCOL 81 `0695a1f3` (cosmetic fix `8a0f5a1f`); Rested work pace and cold-stress hooks `1d00381b`.
- **Lit fixtures and fire light:** lit state saved in lights.json `a6f1bf68`; lit fixtures drawn with flames and warm light `e5172fe9`, flame tuning `eb9f4a39 a6a6f4d9 02e7d317`; short-range falloff light `ed07d89f`; fireplace as a front-only shadowed spot `ceeb057e`; unlocked torch, chandelier, fireplace, beds `a76b2992`; fire-light pictures `43a551ee`.
- **Placement:** lean-to 2.6 x 3.4, ridge 1.5 `b806c0e6 48ebde89`, sloped roof collider `3f091f8e`, lean-to materials `e9226d20`; testing-only `--dev-place` `ff85e5c5` with `art/playthrough/RIG_PLACE.md`.
- **Goals and hints:** camp goals `8da135d3`; hint triggers `has_plant_food_at_fire`, `campfire_pot_placed` `b740e66f`.
- **Death:** novice-grace rule in `data/items/death.json`, default `always` `4061ea86`.
- **Tooling and stability:** the Guide's first-hour fixes incl. rig warm shader cache `3b36c441`; join freeze fix (server `_cover_at` on a worker thread) and rig kit placement `e18630d7`; slot guard `tools/godot_slot.sh`; queued-test lists `TYLER_QUEUED_TESTS.md`.
- **Since the last daily (pushed with the handoff commit):** `ACT_ADMIN_ENERGY` (56), the sleep self-test starts tired and a `sleep` entry in `tools/items_check.py` (chest and sleep PASS); stump rule: `_chop_stump` now reads `final_by_radius` (Sal's rows), the stump is erased, nothing falls, the player gets firewood, kindling and sticks; test `test_stump_chop.gd`.

## 3. What I plan to do, in order
1. Push the lane-verified energy setter, stump change, handoff and this scope (first thing).
2. Time-cap the ground scatter on join (about 0.75 s on the first tick).
3. `test_cover_async.gd` (unmade chunk answers at once; right after the worker finishes) and a "no items-tick step over 250 ms on first join" check.
4. Server test and PROTOCOL.md note for `ACT_ADMIN_ENERGY` (admin only).
5. Run the never-run checks: mutation checks (`tools/mutation_check.sh`) for comfort, goals, lights, dev-place, hints, novice grace; creator-preview lighting look in the editor.
6. Check the client side of the stump rule (the stump model vanishes at once; Kathleen/Sonny own the drawing).
7. Speed up the two slowest tests (`test_worldgen` about 290 s, `test_flora_density` about 115 s).
8. Real death: write a design question list for Dave (heir, children, final-death client flow), then build the client flow and server hooks once he decides.
9. Stump rule status: server DONE; client verification open (item 6).

## 4. Priorities (1 first)
1. Keep joins smooth (no server or client freeze): a freeze on join ruins every first impression.
2. Keep the first hour playable end to end (goals, hints, comfort, fire): it is what Dave and new players see first.
3. Keep tests fast and trustworthy (3-job slot cap, no flaky timing): the daily merge gate depends on them.
4. Finish the unrun checks (mutation, creator look): they are the only unverified shipped features.
5. Real death and heirs: big and needs Dave's design, so it waits on his answers.

## 5. Dependencies
- **I depend on:** Sal (item, recipe, drops, hints data), Kathleen and Sonny (client drawing, input, ghost reasons, E at the sea edge), the flora/water sessions (chunk placing speed, terrain), the moderator (merging my branch into the daily, the voxel-build Godot exe), Dave (death/heir design, play-test verdicts).
- **Depend on me:** Sal (hint trigger names, stump and cooking rules in `server_items.gd`), Kathleen (dev-place and rig for pictures), the Guide (first-hour fixes, rig), the moderator (green lanes and `tools/run_tests.sh`).

## 6. How to tell the job is finished
- Full test run green on the voxel build and `items_check` PASS for chest, gather, eat, leanto, sleep.
- Three rig joins in a row on a quiet PC with no `STALL`, `WATCHDOG` or new crash report and no `items tick slow` line.
- A new player can play the first hour (the playability bot's 11 steps and Guide's step list pass) with fire, shelter, bed and Rested working and tooltips correct.
- Mutation checks catch deliberate breakage of comfort, goals, lights, hints and novice grace.
- Dave has made the real-death decision and it is built, or he has said it is out of scope.
