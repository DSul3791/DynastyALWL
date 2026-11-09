# Nothing placed from the spawn: wild fruit groves, a spawn clear of trees, and what the town point is

**Owner:** Steve. **Asked by:** the coordinator, 9 Nov 2026, after #803. **Status:** design. No code until the coordinator has read it, except section 2, which the coordinator has already approved.
**Rule (Dave, 9 Nov 2026):** "we should not be placing anything based on spawn because we don't know where spawn is going to be. right now its just temporary so nothing is ever based on where spawn is."

#803 took out the spawn clearing, the starter orchard, the town shift and the wolves' town keep-out. This note covers what is left.

## 1. Wild fruit groves (replaces the starter orchard)

**Today (read from `data/tables/flora.json` on main):**
- Every orchard variety already grows wild as single scattered trees, through its `per_hectare`. That is all 13 rows, ids 133 to 145:
  - apple: early, summer, autumn, keeping, cooking;
  - pear: summer, autumn, winter;
  - sour cherry, plum, damson, quince, medlar.
- They grow at 0.2 to 3 per hectare in temperate forest, temperate grassland and mixed forest. Quince also grows in dry scrub.
- So removing the orchard took away only the 12 planted trees by the spawn. No fruit is gone from the world.
- What the island lacks is a place where several fruit trees stand together, which is what the orchard gave a new player.

**Proposal:** a `stand` block (the existing mechanism for birch, alder and hazel; `flora_placer.gd`, data only) on the four summer varieties, so something is in season early in the year:

| species | in a grove | stand (every_m, chance, radius_m, spacing_m, fill, height) |
|---|---|---|
| apple_early | yes | 600, 0.2, [8, 14], 6.0, 0.6, [0.5, 0.9] |
| apple_summer | yes | 600, 0.2, [8, 14], 6.0, 0.6, [0.5, 0.9] |
| pear_summer | yes | 700, 0.15, [8, 12], 7.0, 0.5, [0.5, 0.9] |
| sour_cherry | yes | 600, 0.2, [6, 12], 5.0, 0.6, [0.4, 0.9] |
| apple_autumn, apple_keeping, apple_cooking, pear_autumn, pear_winter, plum, damson | no, scattered as today | — |
| quince, medlar | no, and made `rarity: "rare"` (today "uncommon"), since they are 0.2 to 0.3 per hectare already | — |

- **Where:** only where the species already grows. The stand rule places a grove only in a biome with that species' `per_hectare` above 0, and only on ground its moisture, slope and altitude rules accept. So groves stand in temperate forest and grassland, and never on the beach or the hills.
- **Size:** a grove of radius 8 to 14 m with trees 6 m apart and 60 % fill holds about 4 to 10 trees, close to the old orchard's 12. These numbers are judged.
- **How many:** one try every 600 m with a 20 % chance is about 0.55 per km² per species where the biome fits, so about 2 groves per km² over the four species on temperate ground. On the 15.36 km starter tile, with roughly half of it temperate, that is on the order of 200 groves. Dino's flora density run is the check. If that is too many, `chance` comes down.
- **No spawn anywhere:** the grove cells are hashed from the world seed and the chunk, like every stand. Nothing reads the spawn.
- **Flora layout version** rises by one when this ships (plants move).
- **Check:** in `test_flora_density`, at least one grove of each of the four species on the starter tile, each with 4 or more trees within its radius. Plus a hint check: `near_orchard` (four fruit trees within 25 m, `hints.json`) fires inside a grove.

## 2. A spawn clear of trees and shrubs (merged, #805)

- **The problem:** flora is placed at run time on the server and never baked. The spawn picker runs at bake time and cannot see it. Since #803 removed the spawn clearing, a new player can wake inside a shrub or a tree.
- **The rule:**
  - At server start, after `SpawnPointScript.use_world`, the server asks the flora placer for the trees and shrubs in the spawn's chunk and its neighbours.
  - When any of them stands within `clear_m` 2.0 m of the spawn (its trunk point), the spawn moves to the nearest clear spot. The search walks rings 1 m apart out to 30 m, with 16 points per ring.
  - **Clear** means:
    - no tree or shrub within `clear_m`;
    - ground within 0.5 m of the picked spot's height, so the spawn does not jump onto a ledge;
    - not in water (the tile's water class is 0);
    - not over the sea.
  - **Ties:** the first clear point in ring order wins, so the result is stable for one world.
  - **Small plants:** grass, flowers and herbs do not block, because they have no collider and a player can stand in them.
- **Where:** `terrain_server.gd` `_spawn_point`, with a small pure helper `spawn_point.gd` `clear_of(at, trunks, ground_at, wet_at, rules)`, so it can be tested without a scene. It is the spawn's own position, so it follows Dave's rule: nothing else is placed from it.
- **When none is clear:** the spawn stays where the picker put it, and the server log says so.
- **Check:** a new test with a stub flora list:
  - a shrub on the spawn moves it to the nearest clear point;
  - a ring of shrubs at 1.5 m moves it out past them;
  - no shrub leaves it where it was;
  - a ledge or a pond beside it is skipped.

## 3. The town point (island levels and the stray dog), and the big-game circle

**Today:**
- **The big-game circle:** nothing reads it any more. The comment at `terrain_server.gd` 679 ("big game keeps out of its exclusion circle") is stale. The last reader was the wolves' `near_town`, which #803 removes. The circle itself goes with that comment: remove (rule a).
- **`animals.starter`, set from the spawn, is still read in two places:**
  - `server_animals.gd` `island_level`: animal levels are 0 within `town_m` 800 m of the point and 1 at `far_m` 8000 m (Dave 6 Nov: low levels near the starter town). When it is unset, it falls back to `island_level.town` in `animals.json`, which holds the hand-set coordinates x 53301, z 68427, the old spawn.
  - `server_companions.gd` `_make_stray`: a player's stray dog turns up 60 to 150 m from the town point.

**Options for the centre:**
- **(a) The shipped town, recommended.** The town point is the middle of the NPC markers in `data/npcs/markers.json`. Today that is x 53270, z 68075, the mean of the 10 markers, a few metres from today's spawn. Dave's own words are "near the starter town", so the town is what he means. The markers are data that a person places, and the spawn picker never moves them. When the town is moved, the levels and the stray dog follow it. The hand-set `island_level.town` coordinates go.
  - In code, `server_npcs.gd` gains `town_point()` (the markers' mean). `terrain_server.gd` passes it to `animals.town` (renamed from `starter`) instead of the spawn. `island_level` and `_make_stray` read `town`.
- **(b) Danger by biome and tile.** Each biome, or each tile, has a danger level, and an animal's level follows the ground it stands on. This does not depend on any point. It is closer to the world danger map that `island_level`'s comment says should take over off the starter island. But it needs a table of levels per biome and a decision from Dave on which ground is hard. It is a bigger design, and the stray dog would still need a town point.
- **(c) A fixed coordinate in data,** as `island_level.town` is today. This is simple, but it is a hand-set point that no one keeps up to date, which is how the old spawn coordinates outlived the spawn.

**Recommendation:** (a) now, and (b) later as part of the world danger map, when there is more than one island.

**Decided (coordinator, 9 Nov 2026):** (a). `animals.starter` and `island_level.town` are deleted, and the big-game circle comment goes with them.

**Check:** `test_animal_spawn_wiring`'s island level lines read the town point from the markers. A test should show that moving the markers moves the levels, while moving the spawn leaves them alone.

## 4. Order

1. This note (coordinator reads).
2. The section 2 PR (approved).
3. Section 3 (a) and the circle comment (decided: (a)).
4. Section 1's stands, if approved: data only in `flora.json` plus the test, and the flora layout version bump.
