# Scope: Flora (plants and density), 1 Nov 2026
Written by the moderator on Flora's behalf from her reports; Flora may correct it.

## 1. The job
Make the world look real and alive with plants: how many trees, bushes, fruit, herbs, flowers and grass sit where, how thick they are near the spawn, how they are drawn at range, and that they cost little to draw. Starts at plant data (`data/tables/flora.json`), placement rules and the flora view (`src/flora/`); stops at how a plant's art looks (Kathleen), what a plant gives when gathered (Sal) and server action rules (Tyler).

## 2. Done so far
Density near the spawn (grown trees within 50 m / 100 m: 8 / 44), tall grass clumps and the player-clear radius, conifer nurseries (layout v22), meadow flowers enabled and verified, crown variety hooked up with Kathleen, the `_decimate_task` crash fix (`4458a7c0`), the grass shader guard (`fb90e7c5`), seven flora tests green. Commit list: `git log --author` on `claude/flora-density-v2`, plus `docs/FLORA_HANDOVER.md`.

## 3. Planned, in order
1. Pictures: blueberry (F-13), chamomile, orchard, crown close-ups, with QA cards for yarrow, blueberry, orchard, crowns.
2. Get Kathleen's fix for the glassy flower stems and faceted heads, then re-shoot yarrow.
3. Far tall grass at 40 m (weak): stronger clump or lower-detail fill at range.
4. Confirm the decimate fix on the `client_eat` path; find which model has no index array.
5. Look for more life: seasonal changes, bush and herb variety near the first-hour route, density in every biome the player can reach in the first hour.

## 4. Priorities
1. The first hour near the spawn looks full and alive (grass, trees, herbs, berries).
2. No crashes or stalls from flora (join freeze was flora chunks on the main thread, fixed by Tyler).
3. Pictures with honest ratings for Dave on the QA page.
4. Far-distance look (40 m grass).
5. Cost: stay under the flora budget (`test_flora_budget`).

## 5. Dependencies
On Kathleen for plant art; on Sal for gather results and fibre plants; on Tyler for server placement and tests; on the moderator for merges and Dave's answers. Others depend on her for density numbers (Guide's playthrough, Tyler's first hour).

## 6. Finished when
The first hour has plenty of every plant a new player needs within sight, Dave rates the pictures good, the seven flora tests stay green on the voxel build, and the far grass and flower art problems are closed.
