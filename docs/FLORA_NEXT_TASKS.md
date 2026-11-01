# Flora and fauna: findings and backlog (MikeW, updated 2026-11-01 Phase 1)

Owner of every row: MikeW (Flora and Fauna Density, Placement and Behaviour) unless another owner is named. Rules: never merge to main; at most 3 heavy Godot jobs (tools/godot_slot.sh); how things LOOK is Kathleen's (report with a picture).

## Phase 1 results (no Godot)
- `claude/flora-wet-test`: PORTED and RUN (see Phase 2). PORTED to this branch (cherry-picks of 11de78b1 and 3ccb2d4a). One fix: `species_by_id(instance id)` became `species_of(instance id)` because items carry species<<16 ids now. NOT RUN yet.
- `claude/flora-density` (old v1, one commit 2cc62ac8): DROPPED. Every file it touches (flora_density.gd, flora_diag.gd, test_flora_density.gd, flora_density_report.py, flora.json, placer) is in the daily in the rewritten v2 form; merging would revert v2.
- Fauna measurement tool written: `src/worldgen/tools/fauna_near.gd` (biome mix within 100 m and 500 m of a spot, per-species mean weight, share and expected held count at day, dusk, night). NOT RUN yet.
- test_flora_wet RAN on tile (3,4) (about 35 min, run it with `timeout 3300`; it is NOT in any gate list): 5,115,211 flora instances, 2088 (0.04 percent) on a wet cell (blueberry, fern, owlpetal and similar plants, at altitudes 46-286 m, so mountain streams and lakes), 29,101 trees or shrubs beside water only (reported, allowed: shores are meant to have trees). Result: FAIL on the 2088. Likely cause (read, not proven): the test calls a whole 25 m cell wet from its nearest-cell value, while the placer tests the point's real ground height against the water level plus WET_FOOT_M, so bank plants beside a wet cell count. Next step (MikeW): change the test to count a plant only when `surface_height(x,z) < water level + WET_FOOT_M` (the placer's own rule), re-run; if still above 0, fix the placer. Why: plants standing in a stream would look wrong, but 0.04 percent on the banks is minor.
- Dino #5 (`_decimate_task` cast): the log is older than fix 4458a7c0. Re-run pending.

## Phase 2 results (Godot, 2026-11-01)
- fauna_near.gd RAN at (53301,68427): 92-95 percent temperate forest, 4-8 percent ocean within 500 m. Expected held (rough ceiling): rabbit 1.7 day / 3.4 dusk, deer 1.9 / 4.8, songbirds 3.8 day, boar 1.5 only at dusk and night, frogs 3.8 dusk and night, duck 0.5 at every hour. Duck has no biome row, so it gets full weight in forest (confirms gap 1). Output: E:/Software/godotDev/DynastyALWL_Evidence/alive_check/fauna_near_spawn.txt.
- client_eat self-test RAN (headless client, throwaway server, `--eat`): passes, no script errors, no `_decimate_task` cast error. The old error was seen once, so this is "not reproduced", not proof.
- F-13 blueberry: a real blueberry shot at (53331,68359) shows a small bush about 30 cm tall with blue berries, matching data (0.25-0.5 m). The 3 m golden shrub in the old 02b picture is not a blueberry by data (raspberry is 1.5-2.5 m); the rig row label is the likely mistake. Closed unless Dave says the size looks wrong.
- Pictures shot (alive_check/final3): yarrow with crowns 3/5 (crowns 4/5), chamomile spot 3.5/5, orchard rows 3/5 (dark, no fruit visible), blueberry 3.5/5. QA cards posted on the qa branch (eb5b58bb): pic-flora-yarrow, pic-flora-chamomile, pic-flora-orchard-rows, pic-flora-blueberry-size.
- Dave's earlier QA answers: apples "not spheres" (No) and crowns "Yes but still low quality, want photorealistic": both are Kathleen's look work.

## Fauna behaviour audit (read-only: data/animals/animals.json, server_animals.gd)
Config today: 13 live species; active radius 200 m, despawn 300 m, spawn 150-250 m out of sight, never within 60 m; 40 percent of spawns are "near" (60-120 m); per-player cap 30, server cap 150; wolves are placed by cells (cell 2000 m, excluded 1500 m round the spawn), not by the top-up loop. Biome weights and day/dusk/night chances are in the rows and the loop reads them (`biome_weight`, line ~731). Sal's spawn_plan.json (about 17 more species, hare, red squirrel...) is not wired and has no models.
Gaps found by reading (all unmeasured):
1. `duck` has no `biomes` or `habitat` row (only `flock`): where ducks spawn must be checked; they may appear away from water. Next step: run fauna_near.gd, then read the duck branch of the top-up loop.
2. `rabbit`, `fox` and `moose` have no herd row; rabbits (target 6) spread singly, so a warren feel is missing. Next step: decide with Dave whether rabbits get a loose group of 2-4.
3. `wolf` `target_per_player` 0 and `natural: false`: wolves exist only through the den cells; first-hour safety is by the 1500 m exclusion. Not a bug; keep.
4. Day chances are low for most prey (rabbit 0.5, deer 0.4, boar 0.02): a noon player may see few animals. Next step: measure with fauna_near.gd at the spawn at day, then raise day weights or add a day-active species near the start.
5. No seasonal rules in the animal rows (hours only). Next step: add a `seasons` key if Dave wants migrating or hibernating animals; needs the season clock the flora already uses.
6. Behaviour numbers (spook_m, safe_m, flee_run_m, graze_s) are per row and untuned by play: audit by shots after Phase 2.

## Backlog (owner, exact next step, why)
| # | task | owner | exact next step | why |
|---|---|---|---|---|
| 1 | refine test_flora_wet (2088 on wet cells, see Phase 1 results) | MikeW | count by ground height vs water level as the placer does, re-run with timeout 3300 | the test fails on likely bank plants |
| 2 | confirm `client_eat` has no cast error | MikeW | re-run the client_eat probe on the daily after 4458a7c0 | Dino saw the error in an older log |
| 3 | blueberry size (F-13) | MikeW with Kathreen | shoot (53331.5,68359) facing north, agl 1.0, pitch -15; find the 3 m golden shrub labelled Blueberry | reported size bug |
| 4 | chamomile, orchard, crown pictures and QA cards | MikeW | shots at (53326.7,68442.2) from the south (default camera), (53376,68521), crown close-up; cards on the qa branch | Dave judges by the QA page |
| 5 | pale glassy flower stems, blue-grey yarrow heads | Kathleen | warmer head colour, upward normals, matte stems; picture alive_check/final2/n_yarrow.png | looks are Kathleen's |
| 6 | wild rose drop: petals only or hips too | Sal | decide; branch claude/sal-no-rose-berries commit 1174dd91 | Sal owns drops |
| 7 | orchard picking and thinning in the real game | MikeW | a client probe that picks a tree and checks the "(N left)" prompt | only test_fruit_tree covers it |
| 8 | month-level fruit calendar | MikeW | extend `season` rows to months in flora.json and gather_rules.gd, with Sal's seasons.json | calendar is by season name only |
| 9 | 40 m tall-grass clump readable in shade | Kathleen (look) | picture alive_check tall_grass_for_dave/v8_*; bigger or brighter clump | looks |
| 10 | flowers in the open meadow middle | MikeW | add a patch rule with a smaller `every_m` for open grassland; shoot to check | flowers sit at the forest edge |
| 11 | elder thickets to 90 percent in clumps | MikeW | tune clump sizes in flora.json, run flora_density | at 88 percent |
| 12 | meadow draw calls (+21 percent) | MikeW | far-tree merging, then lower TREE_DENSITY only if a weak PC needs it | cost |
| 13 | models and rows for fig, olive, pomegranate, mango, orange, lemon | Kathleen (models), MikeW (rows) | models first; rows are in flora.json with `future: true` | placed only once a model exists |
| 14 | animal gaps 1, 2, 4, 5 above | MikeW | after row 1 results | density and behaviour are mine |
| 15 | wire Sal's spawn_plan species | MikeW with Kathleen and Sal | one species at a time once a model and row exist | new species |
