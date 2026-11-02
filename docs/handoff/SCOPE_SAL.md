# Scope: Sal, the items agent (written 1 Nov 2026)

> **CLARIFIED (Dave, 1 Nov 2026): you are responsible for ALL items in the game: what they are, how they are made, and how they work** (use, eat, wear, place; numbers and text). Kathleen and Kathreen handle how they look. When an item needs a new code rule, you write the data and the spec and hand the code to the system owner (Steve for sub-systems).

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
7. Follow-ups already flagged: fibre cloth look (Kathleen), the stump key (Steve), the placed sounds by ear (Dave), historic docs with old numbers.
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
- **Depending on me:** Steve and Tyler read my data keys; Kathleen and Kathreen need the item list and `look_placeholders.json`; Dino (playthrough) and Dave's play-tests use my recipes, hints and goals; the moderator needs my "APPROVED TO MERGE" note with tests.

## 6. How to tell the job is finished
- All eight checks pass (`validate_items`, `dishes`, `economy`, `server_items`, `first_hour`, `inventory`, `stations`, `save_compat`) plus `test_goals`, `test_learn` and `test_lumber_route`.
- The playthrough status shows no STILL BROKEN row owned by me.
- Every live item has a description, a price, a how-to-get line and a look (no entry in `look_placeholders.json`), and every recipe can be made by a carrying player.
- Numbers in all player-facing text match the recipes (the checker in plan item 2 finds nothing).
- A person has played the first hour and first week with a stopwatch, and the pace numbers in `CRAFT_PACING.md` are measured, not estimated.
- Remaining `future` items are only those whose source (animal, crop, building) does not exist yet.

## 7. Backlog at handoff (1 Nov 2026, CLOSING_PLAN)
Everything below is written down with an owner, the exact next step and why. Specs for code are in `docs/handoff/SAL_SPECS_FOR_STEVE.md`.

| Item | Owner | Next step | Why not done |
|---|---|---|---|
| Phase 2 checks: eight `items_check` steps, `test_goals`, `test_learn`, `test_lumber_route` on the merged daily | Sal | Run once the moderator sends PHASE 2 (see HANDOFF_SAL "How to test") | Godot held while Dave play-tests |
| Fire tiers 1 to 3 judged by eye | Dave | Answer QA cards `fire-tier-1-survival`, `-2-campfire`, `-3-bonfire` | Needs a person in the game |
| Heavy kits (stone wall, brick wall, brick floor, fireplace) | Dave then Steve | Answer card `heavy-kits-carry`; then Steve spec 2 | Design call, then code |
| Lean-to pace; berries and pot | Dave | Cards `leanto-pace`, `berries-stew-cook` | Needs a stopwatch run by a person |
| Stump `final_by_radius` | Steve | Spec 1 | Server code |
| `gap_exempt` check | Steve | Spec 3 | Server code |
| Bridges, plank tier and thatch window, no stack caps | Steve | Spec 4 | Code or design call |
| `sow_season`, `needs_material`, quality grades | Steve | Spec 5 | Code or design call |
| Fibre cloth look (grey) | Kathleen | Draw it, remove its row from `look_placeholders.json` | Art |
| Placed sounds judged by ear | Jason, Dave | Jason's sound review cards | Needs listening |
| Wool and linen, wool rug | Sal (later) | When sheep, goats or flax exist write the recipes, unlock the wool rug | No source exists |
| Text-versus-recipe checker | Sal | DONE 1 Nov: `tools/text_vs_recipe.py` (encyclopedia how_to_get lines vs recipes); fixed lean-to, camp bench, iron/copper/tin ingot lines. Extend to hints, goals, descriptions | Heuristic covers encyclopedia only |
| Prices for unpriced kits | Sal | DONE (stale row): all 58 `_kit` items already have a `value`; the 59 without are placed structures, which are not traded | None |
| Carry-weight audit script | Sal (later) | `tools/economy_first_day.py` and `docs/CARRY_WEIGHTS.md` cover the weights; a script for every recipe is not written | Not started |
| Rose hips | Sal, decided | Keep. To reverse: port `1174dd91`, set `rose_hips` future, run `validate_items` | Dave's call, no action |
| Branch `claude/sal-no-rose-berries` | Moderator | Delete, as hips stay | Decision made |

### Open at end of 1 Nov 2026 (what is left)
- **Text checker coverage:** `tools/text_vs_recipe.py` covers encyclopedia how-to-get lines only. Still to cover: hints, starter goals, descriptions (need a way to tell which recipe a sentence means).
- **Carry-weight audit script:** a script that checks every recipe's ingredients against the carry cap (0.7 x body kg). Not written; `docs/CARRY_WEIGHTS.md` has the manual findings.
- **QA cards waiting on Dave:** `softwood-boards` (fine vs plank board value; recommend leave until furniture needs it), `first-day-lots`, `sell-lots-value1`, `heavy-kits-carry`; also fire-tier, `leanto-pace`, `berries-stew-cook` cards above.
- **Dave's note, done:** softwood is better for boards than for firewood. Spruce and pine lumber now 7 per log in 5 s, beams 6 s (commit b4d23a8c, `ITEM_DECISION_LOG.md`). Open question is only the value split on the card.
- **Lumber route:** spruce log saws to about 30 copper at Hob, fastest purse filler, capped by his purse; see `docs/ECONOMY_FIRST_DAY.md`. No change made.

