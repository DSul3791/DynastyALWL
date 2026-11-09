# A faster settle: threads, fewer ticks, no rounds (design note; Sonny, 9 Nov 2026)

The coordinator asked for this after #810. Settle + refilm stays in the bake until R7 seeds the live water from the record ([generation cost audit](../water/generation_cost_audit.md), section 2: the live springs pour about 1,000 times the record's flow). The audit puts the first full world at about 4 h, and up to 2.6 h of that is the settle (26 rounds × 363 s). This note says how to cut the settle without changing what it makes. It proposes no code yet: one measurement on Dino (about 12 min, below) decides which parts go ahead.

**Decided (coordinator, 9 Nov, for Dave):**
- The queue of nine instead of rounds: yes.
- Refilm folded into the settle: yes, if Dino's cmp shows the same bytes.
- Fewer ticks: only on a PASS against the bar below.
- No threading in the C++ core unless the first three fall short.

## What a settle costs today (from the code, and one old log)

- Each tile is one Godot process: `settle_water.gd` (get the tile, `WaterSettler.build`, tick, film, save), then a second process, `refilm_water.gd --film` (get the tile again, read the `.water`, film, save).
- The ticks run in the C++ core (`addons/water_core`, `WaterCore.step`) on **one thread per tile**. A tick costs about the number of active cells.
  - Tile 3,4 on 23 Oct had about 200,000 active cells, and 7,100 ticks took 266.6 s: about 37 ms a tick. "Ready in" (tile load and build) was 8.9 s. That was the old rule bake, so these numbers are only a guide.
- The stop rule (`data/water_settle.json` `stop`): at least 7,200 ticks, then blocks of 600 until the stored water changes by less than 5% of what the springs poured, twice running, and at most 21,600.
- ws580v: 363 s for settle + refilm on the nine tiles at once. That is the slowest tile, almost surely 3,4 (it holds most of the water and 211 of the 351 spring heads). The per-tile times weren't logged separately, because the nine shared one terminal.

## Where the 2.6 h comes from, and why it is too high

"26 rounds × 363 s" takes every one of the 227 tiles to be as wet as 3,4, and makes each round wait for its slowest tile. Neither holds:
- **The cost follows the water, and the water follows the land.** The world has 4,398 km² of land, which is 12.1 times the starter's 362 km². So the ticks for the whole world cost about 12.1 times the starter's nine tiles added together, not 227/9 rounds of its slowest tile.
- **A queue instead of rounds.** Nine workers each take the next tile as soon as they finish one, starting with the wettest. Then the wall time is the total divided by nine, plus at most one tile.
- **Upper bound with the queue (estimate):** the starter's nine tiles took at most 9 × 363 s between them. 12.1 × 363 s ≈ 73 min. Each extra tile adds a fixed cost: about two Godot starts and two tile loads, perhaps 20 to 30 s a tile, not measured. That adds about 5 min across nine workers. **So about 1 h 20 min at most, against 2.6 h.** The measurement below gives the real per-tile sums, and the bound will come down.

## The cuts, in order

| cut | changes the files? | saving (estimate) | needs |
|---|---|---|---|
| 1. A queue of nine workers, wettest tile first (the runner, #792, or the bake job) | no | full world 2.6 h → at most about 1 h 20 min; nine tiles unchanged | nothing new: this is how the jobs are run |
| 2. Fold refilm into the settle: the settle's own film rule set to refilm's (`film.min_seen_m` 0, `film.min_km2` 0), and refilm_water.gd retired | no (same bytes, see below) | one Godot start and one tile load per tile: about 10 to 20 s a tile; on nine tiles, the refilm step's share of the 363 s | Dino's cmp of the nine files against main's |
| 3. Fewer ticks, when the measurement shows they are enough (`stop.min_ticks` 7,200 → 3,600, or 1,800) | yes, within the bar | the ticks are most of a settle, so about half of it at 3,600 | the measurement's verdict |
| 4. Threads inside one tile's ticks (the C++ core) | yes, by float rounding, so judged by the bar | the long pole on nine tiles (3,4); little on a full world, where the queue already keeps nine threads busy | code in the core, a rebuild of both binaries, and a gate; only if 1 to 3 leave the nine-tile settle too slow |

**Why cut 2 gives the same bytes.**
- refilm `--film` calls `WaterSettler.film_floor` with `min_seen_m` 0 and `min_km2` 0, on the depths read back from the file, which are rounded to whole centimetres.
- The settle calls the same function before it saves, with 0.005 and 0.05.
- With the settle's rule set to 0 and 0, every painted river cell under 13 cm is raised to 13 cm before the save. That is what the refilm does after it.
- Rounding to the centimetre gives the same stored value either way:
  - a depth from 12.5 to 13 cm already rounds to 13;
  - a depth under 12.5 cm is raised to 13 cm by both;
  - a depth of 13 cm or more is left alone by both.
- Dino's cmp settles it.
- *Found by that cmp (9 Nov):* refilm also re-saved the file it had loaded. `WaterStore` keeps cells over 4 mm, so a cell of 4 to 5 mm is stored as 0 cm, loads as 0, and drops out on the re-save. A folded settle kept those 0 cm entries: its files were larger, but they load to the same water. The settle now leaves out depths that round to 0 cm, as the re-save did.

**Why cut 3 needs proof.** The 7,200 minimum dates from 23 Oct: "600 left the river middle dry (still filling); 7200 is settled". That was on the old rule bake with other springs. With today's springs at 1,000 times the record's flow, the rivers fill faster, so fewer ticks may be enough. The bar is the one PR C used, applied to the short run against the full settle (`compare_seed_settle.py`):
- every lake within 10 cm;
- 90% of the river cells within 10 cm;
- no new body of water of 0.5 ha or more in one file and not the other.

**Cut 4, if it is needed.** Today a tick adds each face's flow to the cells on both sides (a scatter), which can't be split between threads safely. The threaded tick would:
- work out each face once, from the old depths;
- have each cell sum its own four faces (a gather);
- split the active cells into row bands, one per thread;
- merge the wake and sleep lists in band order, so the result does not depend on the thread count.

The sum order changes, so the files differ by rounding. They would be judged by the bar above, not by bytes. The live server runs the same core, so this would also cut its water CPU. That is a bigger change, so it waits until cuts 1 to 3 have been measured.

## The measurement (Dino, about 12 min; job: `water/settle_speed_job.md` in the shared folder)

On main (the ws580v tiles and water are there since #799), in three scratch copies of the world, nine at once, with one log per tile:
1. The settle as it is today, then refilm. Every file must be the same bytes as main's: this checks that the settle repeats itself exactly. The logs give each tile's ready time, its ticks and why it stopped, its ms per tick, and its refilm time.
2. The same with `--ticks=3600`, then refilm; compared with main's files.
3. The same with `--ticks=1800`; compared the same way.

**Then (estimates until it runs):**
- Step 1's sums replace the 1 h 20 min bound in the audit. *(Done 9 Nov, below: about 35 to 40 min.)*
- Step 1 must repeat main's bytes. If it does, cut 2 can be byte-checked.
- If step 2 passes, `min_ticks` goes to 3,600. If step 3 also passes, it goes to 1,800.
- With cuts 1 to 3, the nine-tile settle falls from 363 s to perhaps 2 to 3 min, and a full world's settle to well under an hour.

## Measured, and what was done (9 Nov)

Dino ran the measurement on main e0b05747 (`settle_speed_job.md`; the files are at the shared folder's top level).
- **Step 1, today's settle:** 6 min 13 s for the nine at once, and refilm 8 s. All nine files came out byte for byte the same as main's, so the settle repeats itself.
  - Each tile stops on its own: 3,4 after 14,400 ticks, 2,3, 3,3, 4,3 and 4,5 after 8,400, and 2,4, 2,5, 3,5 and 4,4 after 7,800, all on "stored water steady". 3,4 is the long pole.
- **Steps 2 and 3, fewer ticks:** both fail the bar. At 3,600 ticks (1 min 56 s) the volume is +16.7%, 40 of 107 lakes move more than 10 cm, and 82.7% of river cells are within 10 cm. At 1,800 ticks (1 min 21 s) it is +41.7%, with 65 lakes moved and 58.6%. **Cut 3 is off:** `stop.min_ticks` stays at 7,200.
- **Cut 1, the queue:** `tools/settle_tiles.sh --tiles="3,4 ..."` settles the tiles nine at a time as a queue, in the order given, wettest first. On the starter's nine it is the same as nine at once. It gains on more than nine tiles.
- **Cut 2, refilm in the settle:** `data/water_settle.json` film is v13, with `min_seen_m` 0 and `min_km2` 0, and `refilm_water.gd` goes to `proposed_removals/`. The first cmp (`settle_fold_job.md`) found seven files larger than main's. They held the 0 cm entries that refilm's re-save dropped (above), so the settle now leaves those out too. The cmp runs again at the new head.
- **Per tile, through the runner** (`settle_fold3_ws580v.txt`, nine at once, 371 s wall): 2,4 51 s, 2,5 52, 3,5 56, 4,3 58, 4,4 60, 2,3 66, 3,3 111, 4,5 175, 3,4 371. That is 1,000 s between them.
  - The two empty tiles show a fixed cost of about 51 s a tile: a Godot start, a tile load and 7,800 ticks with nothing to move. The other 541 s follow the water.
  - Full world (estimate): 227 tiles × 51 s, plus 541 s × 12.1 for the land, is about 18,100 s of tile time. Over nine workers that is about 34 min, plus at most one long tile, so **about 35 to 40 min**, against the 1 h 20 min bound above.
- **Cut 4** stays unneeded for now. On nine tiles 3,4 sets the time, and on a full world the queue keeps the nine threads busy.
- **The bookkeeping gap.** 3,4's settle reports 2,097,873 m³ "unaccounted" of 19,005,075 m³ supplied (11%). The likely cause: a spring pours over a 5 × 5 patch, and a patch square off the tile or on the sea gets nothing (`WaterCore.step`), while the settle counts the full flow as supplied. The settle now prints that part on its "settle done" line. The water does not change, because the stop rule still reads the full supply. If the printed part does not close the gap, the next suspect is the depth clamp at 0 in the step.

## What stays

- The settle itself, and the springs at today's rates. Those are R7's to change.
- The stop rule's steady check and its 21,600 maximum.
- One settle per tile, with water free to leave at the tile's edge, as today.
