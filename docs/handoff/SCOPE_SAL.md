# Scope: Sal, the items agent (written 1 Nov 2026)

Read `HANDOFF_SAL.md` first for the open risks and how to test. This file says what the job is, what has been done, and what is left.

## 1. What the job is, and where it starts and stops
I own the **data** that describes things in the game: what items exist, how they are made (recipes), what drops from what, what food does, what things cost, how crops grow, how comfort works, and every piece of player-facing item text (descriptions, hints, starter goals, the encyclopedia, tutorial wording).
- **Where it starts:** the files in `data/items/` (`items.json`, `recipes.json`, `drops.json`, `cooking.json`, `dishes.json`, `structures.json` rows, `comfort.json`, `hints.json`, `starter_goals.json`, `encyclopedia.json`, `descriptions_voice.json`, `looks.json` rows, `look_placeholders.json`, prices) and the design and balance documents about them.
- **Where it stops:** I do not write game code (Tyler), draw or model anything (Kathleen), or merge (the moderator). If data needs a new rule the code does not have, I write the data, say exactly which key to read, and ask Tyler. I only touch a script or test when it checks my data (for example the playthrough audit and `test_learn.gd`).
- Rules I follow: retire items, never delete them (numbers are append-only); never invent facts, sources or animals; never touch `main`; run the eight checks before every push.

## 2. What has been done (grouped)
**Lean-to and bed** (`c962cdde` model, `56905c19`, `ac8d2a7b`, `e9226d20`, `6d7d757e`, `44096dbf`): ridge-pole lean-to at 32 sticks, 8 leaves, 4 twine, roof 2.6 x 3.4 m; rough bed worded as a manger of sticks, branches and bedding.

**Comfort and furniture** (`9d378e57`, `60532b33`, `2d9947e3`, `6aa7055e`, `4e909964`, `e9226d20`, `6d7d757e`): comfort design and `comfort.json`; 15 furniture kits (items 487 to 501, recipes 319 to 333) and placed items 502 to 516 (states 59 to 73); `gap_exempt` flag; balance pass; fibre cloth (item 517, recipe 334) so the feather and canopy beds are makeable; wool rug stays future because there is no wool.

**Food and cooking** (`2fa1d1f2`, `ba4ca572`, `212909f6`, `1a7c524b`): berries 4 kcal; berries stew into Stewed berries; the campfire cooks only meat and fish; plant dishes moved to the pot, clay hearth or oven; nettles give fibre and leaves and make tea.

**Economy** (earlier, see `ECONOMY_PLAN.md`): dish price cap and regression guard `test_economy_guard.gd`.

**Text** (`549dd2fa`, `6d7d757e`, `484eb04d`, `3fd4071c`): 99 encyclopedia rows added, ten fruit lines reworded, 100 voice descriptions, hints and goals kept in step with recipes, tutorial steps 23 and 24 (pot and hearth), Camp bench trimmed to 16 sticks so steps 11 to 20 fit the bot's 60-stick budget.

**Checks and audits** (`e9226d20`, `26451218`, `2f494b0f`): item data audit (`AUDIT_ITEMS.md`), first-hour step status, playthrough audit and craft probe taught the learn system (F-01/F-24, F-19, S-craft now FIXED).

**Sounds:** placed sounds mapped to the five existing kinds in `structures.json` (Dave to judge by ear).

**Latest:** `9c68e947` stump drops by size (`drops.json` `stump.final_by_radius`) and the handoff document.

## 3. What I plan to do, in order
1. Carry-weight audit: find every recipe whose ingredients weigh more than a player can carry (carry is 0.7 x body kg, about 52 kg), and fix the stone wall, brick wall, brick floor and fireplace kits (cheaper, lighter, or craft from nearby stock, with Dave's call).
2. A text-versus-recipe checker: a script that finds numbers in hints, goals, descriptions, encyclopedia and tutorial text that no longer match the real recipes; fix what it finds.
3. Prices for the 34 live kits and structures that have no `value` (rule in `ECONOMY_PLAN.md`), then the shop stock proposals (fisher, hunter, healer).
4. Measure the first hour with a person and a stopwatch, then tune sticks, fibre and craft times (`FIRST_WEEK_WALK.md`, `CRAFT_PACING.md`).
5. Farming data: faster early crops and grow times so the first harvest is inside a week (`FIRST_WEEK_WALK.md`).
6. Re-run the structures, logs and spawn probes after each daily and fix data causes.
7. Follow-ups already flagged: fibre cloth look (Kathleen), the stump key (Tyler), the placed sounds by ear (Dave), historic docs with old numbers.
8. Wool and linen: when sheep, goats or flax cloth exist, write their recipes and unlock the wool rug.

## 4. Priorities, ranked
1. **Heavy kit weights:** four wall and fireplace kits cannot be carried, so those builds are impossible today.
2. **Keep the first hour makeable:** costs, hints and goals must agree with the recipes, or a new player gets stuck on the first day.
3. **Text matches data:** wrong numbers in hints and the encyclopedia mislead players and testers.
4. **Economy sanity:** unpriced kits and dish prices can be exploited at the one shop.
5. **Early farming pace:** a harvest 60 to 110 real hours away leaves the first week without crops.

## 5. Who I depend on, and who depends on me
- **I depend on Tyler** for any new data key to be read by the server (stump `final_by_radius`, server `gap_exempt` check), for hint triggers, and for fixes found by tests.
- **I depend on Kathleen** for looks (fibre cloth, any new kit or item) and models for new furniture.
- **I depend on Dave** for design calls (heavy kits, berry calories, cooking rules, sounds by ear) and on the moderator to merge `sal-items` into the daily.
- **Depending on me:** Tyler reads my data keys; Kathleen needs the item list and `look_placeholders.json`; the guide (playthrough) and Dave's play-tests use my recipes, hints and goals; the moderator needs my "APPROVED TO MERGE" note with tests.

## 6. How to tell the job is finished
- All eight checks pass (`validate_items`, `dishes`, `economy`, `server_items`, `first_hour`, `inventory`, `stations`, `save_compat`) plus `test_goals`, `test_learn` and `test_lumber_route`.
- The playthrough status shows no STILL BROKEN row owned by me.
- Every live item has a description, a price, a how-to-get line and a look (no entry in `look_placeholders.json`), and every recipe can be made by a carrying player.
- Numbers in all player-facing text match the recipes (the checker in plan item 2 finds nothing).
- A person has played the first hour and first week with a stopwatch, and the pace numbers in `CRAFT_PACING.md` are measured, not estimated.
- Remaining `future` items are only those whose source (animal, crop, building) does not exist yet.
