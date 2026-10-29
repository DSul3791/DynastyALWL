# Review: Sal_Crafts (Radar's role: items, crafting, NPCs, buildings), 2026-10-22

## Keep
- Data in JSON + validators (BP-C40): a new item/recipe is a data edit and one test run.
- Pickable questions + TEST_QUEUE grouping (RULE 1/2): Dave is never asked for single tests.
- BUILD_LOG + handoff notes (BP-T04): a replaced thread restarts in minutes.
- "Fix only with evidence" (BP-C14): no wasted guesses.
- Never wait for Dave (BP-T07): park, take the next job.

## Change
1. Giant files. server_items.gd ~5,000 lines, inventory_view.gd ~3,800. Every edit = grep + partial reads. Fix: split by topic (trade, structures/pieces, fires, death, shop UI) as one Systems job, tests as the net. Saving: guess 20-30% of tokens per Items edit.
2. A new building piece touches 8 places (structures/items/recipes/weights json, piece_look, draw chain, CLEARING_NOT, STATE_KIND, ghost). Fix: structures.json carries look, clears_grass, sound; code reads it. Saving: guess 50% per piece, fewer misses.
3. Build-number collisions: everyone edits `const BUILD` + BUILD_LOG; I rebased 5 times in one evening. Fix: number assigned at merge (per-thread branches, C107). Saving: ~5 pushes/evening re-done.
4. Noisy baseline: quickkeys flakes, plantpick fails on a clean tree, 232 warnings. Fix: fix or list known-failing; run `check_warnings --changed`. Saving: 1-2 reruns per push.
5. Daily BP read is 80 entries. Fix: 2 KB role digest + changelog lines. Saving: guess 10-15 KB per thread per day.

## Missing
- Entry for "structure with a store" (fire/chest/station containers): server_items has 3 ways of doing it.
- Entry for adding a world-state number (who registers it where).
- Entry for save-format additions (I added a fire uid column; no rule on row layout compatibility).

## Conflicts
- BP-T10 "every post ends Still waiting on:" vs RULE 2 "never wait for Dave": the line is always "nothing".
- BP-C10/T22 "never edit another thread's code" vs reality: pieces need `piece_look.gd` (Art), `placed_sounds.gd` (Art), `terrain_client.gd` (Systems). Need a rule: one-line data hooks allowed, announce in BUILD_LOG.
- BP-C51 "E = Use, F = Open" was added after F was Fly in CONTROLS.md; now fixed (fly = G).

## Your area
Stations, chests, fires and remains each have separate code for their stores. Recommend one container model (uid + slots + accepts-list in structures.json). Not Dave's decision.

## Token moves
- Handoff: status + next job + gaps only (mine was fine at ~30 lines).
- Reports to Dave: result + restart note, 3 lines; test detail only in TEST_QUEUE.
- Read with grep/offset, never whole big files (a rule worth writing down).

## Verdict
Process good for now, needs changes 1-4 before the next big build run.
