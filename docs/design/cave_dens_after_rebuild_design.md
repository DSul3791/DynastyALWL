# Goblin dens and bear dens after the spring-cave retirement (design)

Steve, 9 Nov 2026. This answers the knock-on in `docs/water/watershed_rebuild_design.md` section 7, "Caves and dens". That line says goblin dens and bear caves are placed from spring caves, and that they need a new source now that spring caves are few. This note is design only; there is no code in it.

## 1. What the code does today (read on main 54950227)

**Bears do not use caves.**
- A bear's den is the place where it spawned: `server_animals.gd` sets `animals[id]["den"] = pos`.
- It spawns by habitat: in forest, on a slope up to 0.6, within `near_fresh_water_m` 60 m of fresh water (`animals.json` `species.bear.habitat`).
- It ranges 80 m round that den and goes fishing half the time.
- No code reads a cave for a bear. The cave `habitat` key is still in `HABITAT_KEYS_LATER`, which means it is not built yet.
- The section 7 line and the two `count_note` lines in `tile_rules.json` ("Goblins, bears and cave life use the spring caves") are wrong about bears. The retirement removes nothing from them.
- The one bear item still open is a separate one, Stage E row 49 (`docs/water/stage_e_readers_design.md`): the den should read a baked `fresh_m` distance instead of live sim water. That stays as it is.

**Goblin dens already take any inland cave.**
- `tile_terrain_data.gd` gives a den to `GOBLIN_DEN_PERCENT` (60 %) of the caves that have a dry spot, picked by the cave's id:
  - in a spring cave, the end of a dry side branch, never the stream passage;
  - in a karst cave or a lava tube, a dead end.
- Goblins come out of `goblin_den_mouths`. No group is made at a mouth with a bear within 120 m (`lair.avoid_m`).
- The code needs no new source. What matters is how many caves there are.

**What caves a tile baked from the water record has:**

| cave | on the record tiles | den for goblins |
|---|---|---|
| spring cave | `record_cave_share` 0.10 of the R5 spring heads, under the usual rules (way inland, a hillside, no lake beside it, spacing, room). ws580v: 28 caves, 21 of them on tile 3,4 | only with a dry side branch. A "small" cave has 0 to 1 branches, so some have none |
| karst | off, `count` [0, 0] (Dave 7 Nov: "caves only at river starts") | none |
| sea cave | off, for the same reason | never (the tide) |
| lava tube | only at a `volcanic_vent` feature, and the starter tiles have none that I know of | none in practice |
| rock shelter | 4 to 8 per tile | never (there is no passage) |

So on the starter island, goblin dens come from the record's spring caves alone. The number is somewhere between 0 and about 17 over the nine tiles (60 % of 28, less the caves with no dry branch). No one has counted it yet.

## 2. Options

- **(a) Spring caves stay the only source, and the count is measured. Recommended.** This follows Dave's two rules: caves only at river starts, and "a few here and there randomly but not for most springs". It needs no placement change. First, the den count is measured on the ws580v tiles (section 3). Then, only if it is too low, these knobs are turned in this order:
  1. A record spring cave always gets at least one dry side branch (`spring_cave.sizes.small.branches` [0, 1] to [1, 1]). This is data only and needs a bake class re-bake on Dave's PC. Every spring cave can then hold goblins, and the water does not change.
  2. `GOBLIN_DEN_PERCENT` 60 to 100: every spring cave with a dry branch holds a den.
  3. A higher `record_cave_share`. This is last, because it changes the springs (Sonny's call, and Dave's "not for most springs").
- **(b) Dry karst caves back on, in limestone only.** These are caves with no water. This breaks "caves only at river starts", so it is Dave's call. It is the right answer if the island needs more caves for other reasons (bats, cave climate, ore). It is not the right answer for goblins alone.
- **(c) Dens with no cave**, such as a hut or a hollow under a rock shelter. That is a new kind of den, and `goblin_den_life_design.md` would need a surface den. It is a bigger design, and nothing asks for it yet.

## 3. The check

- `island_checks` gets one INFO row per baked tile: "caves: N spring caves, M with a dry branch, K goblin dens (60 %)". K is worked out by the same id rule that `tile_terrain_data.gd` uses, so the row and the game agree.
- It reads the tiles only. It runs on Dave's PC as part of the usual island_checks run, so there is no bake and nothing runs in the cloud.
- Bar (judged): tile 3,4 has at least 6 goblin dens, about one per 40 km² of land. Each other land tile has at least 1. Below that, (a) step 1 comes first.

## 4. Steps (as first planned)

1. This note. The section 7 line in the watershed design points here.
2. A small PR with the island_checks row, plus the corrected comments: the `count_note` lines in `tile_rules.json` say spring caves are for goblins and cave life only, and the `lair_mouths` comment in `terrain_server.gd` says "inland caves with a goblin den". David4 gates it, and Dino runs island_checks on the ws580v tiles and posts the row.
3. Only if the bar fails: (a) step 1, then step 2.

## 5. The count, and what was decided (9 Nov 2026)

**The count from #809 on ws580v:**
- 28 spring caves, 16 of them with a dry branch, and 6 goblin dens, all of them on tile 3,4.
- Tile 4,5 has 6 caves and 0 dens. Tile 3,5 has 1 cave and no dry branch.
- 2,3, 3,3, 4,3, 2,4, 2,5 and 4,4 have no spring cave at all.
- Sonny's note `/mnt/project-files/water/record_cave_floor_note.md` explains why a higher `record_cave_share` mostly drills more holes in 3,4.

**Decided by Sonny and the coordinator:**
1. `record_cave_share` stays at 0.1.
2. Every record spring cave gets a dry branch: `spring_cave.sizes.small.branches` changes from [0, 1] to [1, 1].
3. **A floor of one cave per tile** (`spring_cave.record_cave_min_per_tile` 1). When a tile's roll makes no spring cave, `tile_sites.gd` `_make_record_springs` tries its other heads:
   - in the same order (biggest spring first), with the same cave rules and spacing;
   - it keeps the first cave that has a dry den branch (the floor counts only caves with one, since an arm can fail for room);
   - that head is then a cave and no longer a ground spring, so #802's bushes skip it.
4. **The tile's first spring cave with a dry branch always holds a goblin den** (`TileTerrainData.goblin_den_nodes`, a runtime rule). The other caves keep the 60 % by id. island_checks counts the dens with the same function.
5. **TERRAIN_VERSION 73.** The nine tiles are rebaked on Dave's PC. The bake takes about 59 s from the setup cache. The settle doesn't read caves, so Dino compares the `.water` files with cmp.

**The bar, restated:**
- Every tile with at least one spring cave has 1 den or more.
- Tile 3,4 has 6 or more.
- A tile with no cave is INFO, not a failure: once the floor is in, no cave means no head there passed the cave rules. Only dens with no cave, or dry karst, would reach those tiles, and both are off the table.

**The most caves the rules allow per tile** (Dino, the nine ws580v tiles baked with the share at 1.0, `cave_count_ws580v.log`):

| tile | spring heads | caves at share 1.0 |
|---|---|---|
| 2,3 | 7 | 3 |
| 3,3 | 20 | 5 |
| 4,3 | 19 | 1 |
| 3,4 | 211 | 96 |
| 3,5 | 25 | 3 |
| 4,5 | 68 | 43 |
| 4,4 | 1 | 0 |
| 2,4 | 0 | — |
| 2,5 | 0 | — |

So the floor can reach 2,3, 3,3, 4,3 and 3,5. Tiles 4,4, 2,4 and 2,5 have no head that the cave rules allow, so they get no cave and no goblin den. The coordinator accepted that under the restated bar on 9 Nov 2026.
