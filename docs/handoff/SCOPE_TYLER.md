# Scope: Tyler: Q&A testing and tooling, 1 Nov 2026

> **CURRENT FLOW (fact check, 5 Nov 2026; supersedes the branch and merge lines below):** there is no daily branch: `DailyDev_20261029` was merged into `main` (PR #11, `a8c4d545`) and deleted on 1 Nov, so "the daily" below means `main`. Each agent cuts a new branch from `origin/main` each day and opens one pull request per job into `main`; agents never merge themselves. Tyler merges when CI is green and `tools/run_tests.sh` passes on the merged result. "Never merge to main" below means "never merge it yourself", not "never open a PR". Commit heads, test counts and "in the daily" claims below are as of the date in the title; `git log origin/main` and CI are the truth now. Priorities and job owners: `/mnt/project-files/BACKLOG.md`.

> Role history (Dave, 1 Nov 2026): the sub-systems (character system, comfort and Rested, food and drink, warmth, sleep and energy, lit fire/fixture RULES, kit and structure placement rules, death and respawn rules, goal and hint triggers, stump and trunk work) moved to **Steve: Systems** (`SCOPE_STEVE.md`). Fire and flame LOOKS are Kathleen's. Animal placement and behaviour are MikeW's; I keep only the shared server rules animals plug into (damage and death handling, carcass, protocol). The character LOOK is Kathleen's.

Read `HANDOFF_TYLER.md` next to this one: it holds the in-flight state, risks and how to run things.

## 1. The job, in plain words
I own the test suite and the full test passes, the rigs and probes, regressions, the join freeze and stability, and the merge gates (what must be green before the moderator merges into the daily). I start where someone changes code and end when the change is proven to work (or broken, with the exact failing check). I stop at designing or writing game systems (Steve), looks (Kathleen), item data (Sal), animals (MikeW), terrain, flora and water (their sessions). I may still fix a bug I find in tooling or in stability (for example the join stall) and write the tests that pin a system's behaviour, but the system's rules are Steve's.

## 2. What I have done (hashes on `claude/tyler-gates-fee5f7`, all in the daily)
- **Systems built before the role change (now Steve's to own):** comfort and Rested `8878c258 6d618f01 0695a1f3 1d00381b`; lit state saving `a6f1bf68`; lit fixtures drawn, light shape, unlock `e5172fe9 ed07d89f ceeb057e a76b2992` (looks now Kathleen's); lean-to 2.6 x 3.4 `b806c0e6 48ebde89 3f091f8e`; camp goals `8da135d3`; hint triggers `b740e66f`; novice-grace death rule `4061ea86`; stump `final_by_radius` + `test_stump_chop` and `ACT_ADMIN_ENERGY` + tired sleep self-test `7834e327`.
- **Tooling and stability (mine):** `--dev-place` testing flag `ff85e5c5` with `art/playthrough/RIG_PLACE.md`; slot guard `tools/godot_slot.sh` (3 heavy jobs at once); rig warm shader cache `3b36c441`; join freeze fix (server `_cover_at` on a worker thread), rig kit placement fix and the `items tick slow` log line `e18630d7`; `items_check.py` sleep entry; the queued-test lists `TYLER_QUEUED_TESTS.md`; fire-light and rig pictures in `art/CRITIQUES/fire_light_2026-10-31/`.

## 3. What I plan to do, in order (after RESTART; no Godot until then)
1. Re-run what Dave's kill aborted: the 7 tests with no FAIL lines (`test_warmth test_edible_offer test_flora_density test_ingredient_groups test_look_table test_river_ore test_stairs_climb`), then the diff lane over `terrain_net / server_items / inventory_view / items_check`, `items_check --only chest,gather,eat,leanto,sleep`, and one rig join (`join_final`) checking no `STALL`/`WATCHDOG`/new crash report.
2. Full test pass on the voxel build (`godot.windows.editor.x86_64.exe`), reported to the moderator as the merge gate.
3. Join stability: time-cap the ground scatter on join (about 0.75 s), `test_cover_async.gd`, and a check that no items-tick step runs over 250 ms on first join.
4. Run the never-run checks: `tools/mutation_check.sh` cases for comfort, goals, lights, dev-place, hints, novice grace (tell Steve which survive).
5. Speed up the slowest tests (`test_worldgen` about 290 s, `test_flora_density` about 115 s) and keep the 3-job cap honest.
6. Regression watch: after each merge run the lanes, bisect red ones, and send the exact failing check to the owner.
7. Rigs: keep `rig.sh` and `look_rig.sh` working (kit placement, dev-place, shader cache); a headless smoke test of the first minutes (join, move, pickup, first hint) with the slow-step line checked.

## 4. Priorities (1 first)
1. A green, trustworthy merge gate: the daily must never break unseen.
2. No freeze on join: the first impression and the rig both depend on it.
3. Tests that fail only for real reasons (no flaky timing, no overload kills): a red you cannot trust costs everyone time.
4. Fast feedback: slow tests and heavy lanes trimmed, the 3-job cap respected.
5. Mutation checks and smoke tests of the early game: they find what green tests miss.

## 5. Dependencies
- **I depend on:** the moderator (merges, the voxel Godot exe, when Dave frees the PC), Steve (system fixes when my tests find a bug in a system), Kathleen, Sonny, MikeW and Sal (fixes in their areas), Dave (RESTART, play-test verdicts).
- **Depend on me:** the moderator (merge gates and lane reports), Steve (tests and rigs for his systems), Kathleen (rig and dev-place for pictures), everyone (the join not freezing, the slot guard).

## 6. How to tell the job is finished
- Full test run green on the voxel build and `items_check` PASS for every client scene, on two merges in a row.
- Three rig joins in a row on a quiet PC with no `STALL`, `WATCHDOG` or new crash report and no `items tick slow` line.
- Mutation checks catch deliberate breakage of each system's key rule.
- No test over about 120 s on the diff lane, and a first-minutes smoke test in the gate.

## 7. Handed to Steve (1 Nov 2026, message sent)
Character system (no code by me yet; suggested plan: map the records into `docs/CHARACTER_SYSTEM.md`, save-compat test, per-character recipes and goals, idle-timeout test, select-screen and first-minutes smoke tests), comfort/Rested mutation checks, a server test for `ACT_ADMIN_ENERGY`, real death (client flow and heirs; needs Dave), client side of the stump rule. Each system's tests stay mine to run; the rules are his to change.

## 8. Dino's findings assigned to me (FINDINGS_REPORT.md, via the moderator; do these first after RESTART, #12 and #4 first)
- **#12 join freeze:** confirm with a real windowed join (rig joins x3 on a quiet PC; high priority if it returns).
- **#4 chest self-test:** `Invalid access 'numbers' on Nil` at `inventory_view.gd:4562` in the shared-server run (log `smoke/logs/client_chest_shared_server.log`). It passed for me on a fresh server (`items_check --only chest`); find the shared-server path where `inventory` is nil (the retry/null guards in `run_chest_test` may not cover it) and fix.
- **#6 sleep self-test:** now starts tired through `ACT_ADMIN_ENERGY` (`7834e327`); verify it passes in the shared-server run too (it passed alone).
- **#7 shared-server self-tests leave pieces at the spawn,** so later bed/snare tests fail "not set down": run each self-test on a clean server, or clear the spawn between them.
- **#10 bot budget:** steps 11-20 need about 62 sticks and `GATHER_BUDGET` is 60, so the bot stops before the bench (`test_playability_bot.gd`); raise to 70 (Sal's proposal) once he agrees, and check the 11 steps still pass.
- **#11 camp bench and drink** have no automated check: add one (server-level test, then a client scene entry in `items_check.py`).
