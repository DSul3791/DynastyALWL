# Handoff: Sal (items agent), written 1 Nov 2026

> **CURRENT FLOW (fact check, 5 Nov 2026; supersedes the branch and merge lines below):** there is no daily branch: `DailyDev_20261029` was merged into `main` (PR #11, `a8c4d545`) and deleted on 1 Nov, so "the daily" below means `main`. Each agent cuts a new branch from `origin/main` each day and opens one pull request per job into `main`; agents never merge themselves. Tyler merges when CI is green and `tools/run_tests.sh` passes on the merged result. "Never merge to main" below means "never merge it yourself", not "never open a PR". Commit heads, test counts and "in the daily" claims below are as of the date in the title; `git log origin/main` and CI are the truth now. Priorities and job owners: `/mnt/project-files/BACKLOG.md`.

## My role
I own the item data: items, recipes, drops, cooking and dishes, economy and prices, crops, comfort design, descriptions, hints and starter goals, and the encyclopedia. I do not own code (Tyler) or art (Kathleen). My branch is `sal-items`. The moderator ("More Dynasty") merges it into `DailyDev_20261029`. I never touch `main`.

## Done and merged (latest first)
- `2f494b0f`: the playthrough audit, craft probe and status scripts now understand the learn system. F-01/F-24, F-19 and S-craft read FIXED. No recipe data changed.
- Stump drops (this commit, see "Stump rule" below).
- `484eb04d` / `3fd4071c`: Camp bench is now 16 sticks (steps 11 to 20 need 58 sticks, under the bot's 60). Tutorial steps 23 and 24 teach the pot and hearth. Tyler wired the two hint triggers afterwards.
- `549dd2fa`: ten fruit-tree encyclopedia lines reworded.
- `6d7d757e` and earlier: lean-to is 32 sticks, 8 leaves, 4 twine (2.6 x 3.4 m roof); rough bed wording; 15 comfort furniture kits (items 487 to 501, recipes 319 to 333) and their placed rows (items 502 to 516, states 59 to 73); fibre cloth (item 517, recipe 334) for the feather and canopy beds; 99 encyclopedia rows; placed sounds mapped; furniture balance pass; item data audit.
- Food: berries are 4 kcal each; the campfire cooks only meat and fish; all plant dishes need a pot, clay hearth or oven.

## Stump rule (Dave, 1 Nov)
Chopping a stump still in the ground destroys it and gives firewood and kindling, no fallen log. Tyler's `_chop_stump` already does this using `data/items/drops.json` key `"stump"` (`blows_*`, `chip`, `final`). I added a new key `stump.final_by_radius`: a list of rows `{max_radius_m, rows}`; the first row whose `max_radius_m` is at or above the stump radius gives its drops, and the last row has no limit.
- Small (up to 0.2 m): 1-2 firewood, 2-3 kindling, 1-2 sticks.
- Medium (up to 0.4 m): 2-4 firewood, 2-4 kindling, 1-3 sticks.
- Large: 3-5 firewood, 3-5 kindling, 2-3 sticks.
Item ids are `firewood` (turned into the tree's own species wood by the code) and `kindling` and `stick`. **Tyler must still read `final_by_radius`**; until he does, the code uses the old `final` row (the medium size), so nothing breaks. validate_items and server_items passed.

## In flight or not done
- Nothing is half edited. Everything is committed and pushed to `sal-items`.
- Unstarted: a carry-weight audit of recipes (see "Open risks").

## Open bugs and risks
1. **Heavy build kits cannot be carried.** Carry is 0.7 x body kg (about 52 kg for a 75 kg player). The stone wall kit needs 12 cut stone blocks at 25 kg each plus mortar, about 314 kg. The brick wall, brick floor and fireplace kits are heavy too. Needs a design call (cheaper kits, lighter blocks, or crafting from nearby stock). I only flagged it.
2. **Fibre cloth has a grey placeholder look** (`look_placeholders.json`). Kathleen to draw it.
3. **Wool rug stays `future` and its recipe `locked`:** there are no sheep or goats, so no wool source. Test `test_learn.gd` guards this.
4. **Lean-to pace is unmeasured.** 32 sticks may be slow or fast in the real first hour; only a stopwatch run by a person can tell. See `FIRST_WEEK_WALK.md`.
5. **Server gap check for `gap_exempt`** furniture is Tyler's (Tyler said he would add it).
6. **Berries at 4 kcal and the campfire cooking only meat** are Dave's decisions but have not been play-tested.
7. `hints.json` has `place_fire` twice (different triggers, same text). Harmless.
8. Older docs still mention old costs and sizes (`ITEMS_DESIGN.md`, `ITEM_DECISION_LOG.md`, `PLAYTHROUGH_FINDINGS.md`, `PLAYTHROUGH_GUIDE.md`). They are history; the current numbers are in `BALANCE_SHEET.md`.

## How to test
Run from the repo root (my worktree is `.claude/worktrees/sal-items-c65419`). Cap of 3 heavy Godot jobs, always through `tools/godot_slot.sh`.
- The eight checks (through `tools/godot.cmd`, which runs the VOXEL build; data checks also pass on the standard exe):
  `python tools/items_check.py --godot "$PWD/tools/godot.cmd" --only validate_items,dishes,economy,server_items,first_hour,inventory,stations,save_compat`
- Single test: `bash tools/godot_slot.sh bash tools/run_one_test.sh test_goals 600 <out dir>` with `GODOT_EXE=/c/GodotInstaller/godot.windows.editor.x86_64.exe`.
- Craft probe and status: `art/playthrough/run_status.sh` (about 6 minutes) uses the voxel build `godot.windows.editor.x86_64.exe`.
- Standard exe is enough for all data tests. The voxel build is only needed for world tests.
- Before each push all eight checks must pass. Push with `git push origin HEAD:sal-items`, then message the moderator "APPROVED TO MERGE" with branch, commit and tests.

## Read first
`LEARN_SYSTEM_SPEC.md`, `docs/COMFORT_DESIGN.md`, `FURNITURE_BALANCE.md`, `AUDIT_ITEMS.md`, `BALANCE_SHEET.md`, `CRAFT_PACING.md`, `FIRST_HOUR_FOOD.md`, `FIRST_WEEK_WALK.md`, `ECONOMY_PLAN.md`, `TUTORIAL_FIRST_30_MIN.md`, `PLAYTHROUGH_STATUS.md`.

## Decisions by Dave: do not re-open
- Items are never deleted: retire them (`retired: true`) so numbers stay.
- Lean-to is round thin logs and poles with a ridge pole, 2.6 x 3.4 m (Dave's photos). Rough bed is sticks, branches and bedding, like a manger.
- The campfire cooks only meat and fish; plants need a pot, hearth or oven.
- Berries are 4 kcal each.
- Chopping a standing stump destroys it and gives firewood and kindling.
- Comfort: level 0 to 20, radius 9 m, each kind counts once, the Rested buff always lasts 45 real minutes.
- Never merge into `main`; the moderator merges the daily.

## Skipped or not verified
- No human stopwatch run of the first hour; every pace number is from data.
- Probes for structures, logs and spawn were not re-run after the last daily; only the craft probe was.
- Placed sounds were chosen from existing kinds; Dave should judge them by ear.
- I did not check `lumber_by_hand` (needs a hand saw that cannot be made yet).

## The next tasks I would have done
1. Carry-weight audit: list every recipe whose ingredients weigh more than a player can hold, and fix the stone and brick kits.
2. A text-versus-recipe check: a script that compares numbers in hints, goals, descriptions and tutorial text with the real recipes.
3. Give the 34 valueless kits a price by the rule in `ECONOMY_PLAN.md`.
