# Cave dens and abandoned mines

**Status: PROPOSED design with PROVISIONAL answers.** Dave asked for it on 19 Nov 2026 (thread "Plan caves and abandoned mines"): "we need to start adding stuff into the world for players to discover like natural caves or abandoned mines that already have bracing. we should research how they build mines in the medieval times just for the direction, slopes and depths and sizes." He added the same evening: "more than likely natural caves will become dens for animals or creatures." While he was away the coordinator answered the plan's questions for him under his 14 Nov standing rule. Those answers are recorded as **assumed on Dave's behalf** below, and he can change any of them. The research and the full plan are in the project Library at `caves-mines/PLAN.md`.

## Decisions (assumed on Dave's behalf, 19 Nov 2026, coordinator)
| ID | Decision | Status |
|---|---|---|
| CD-1 | Bears, wolves and foxes may den in caves. | PROVISIONAL |
| CD-2 | Dry natural caves stay off (Dave 7 Nov: "caves only at river starts"). Abandoned mines are the dry underground places. | PROVISIONAL (keeps his 7 Nov rule) |
| CD-3 | 70 % of the inland caves with passages that hold no goblin den hold an animal den. The animal follows the cave's size: large caves and lava tubes are bears, medium caves wolves, small caves foxes. The pick comes from a hash of the cave's id. | PROVISIONAL (thread's value) |
| CD-4 | No baked cave is held free for the goblin camp any more: since 21 Nov 2026 the camp brings its own dry cave (`camp_caves.gd`, cave kind `camp_cave`, never a den; docs/design/GOBLIN_CAMP.md GOBLIN-20). Before that 3,4#8006 and earlier 3,4#8013 were kept free. | PROVISIONAL |
| CD-5 | 2 to 4 abandoned mines per tile, with one about 1 km from the spawn. | PROVISIONAL |
| CD-6 | A mine's old timbers are looks only. They cannot be pulled down for wood for now. | PROVISIONAL |
| CD-7 | Bell pits wait for the iron work (bog iron, iron-stained outcrops). | PROVISIONAL |

## Stage 1: cave dens (built)
- **Rule:** `TileTerrainData.animal_den_species(cave)` (CD-3, CD-4). The server and the dressing read the same rule. Goblin caves are decided first and never hold an animal.
- **Signs a player can read:** droppings a few metres in from the mouth, to the side of the stream. A bear or wolf den also has old bones there, from kills brought home. A trampled bed of leaves, grass and fur lies at the den spot: the cave's dry branch, else its den nearest the entrance. These are `cave_bones` kinds 4 (droppings) and 5 (bedding), protocol 141, drawn by `src/client/cave_dressing.gd`.
- **The animals:**
  - A bear or fox top-up near a player takes an empty den mouth first (`server_animals.cave_den_spot`). The mouth must be within the normal spawn reach, never within `never_within_m` of a player, and on ground the species lives on (its biomes and habitat, as for any spawn spot). It is not taken while one of its kind, or that animal's den, is within `cave_den_claim_m` (40 m) of the mouth. A bear made there has the mouth as its den.
  - A wolf pack's 2 km cell uses a wolf cave inside it as the pack's den, if the mouth is wolf ground (`server_wolves._natural`, `server_animals.cave_den_in`). Otherwise the pack keeps its hashed spot.
- **Goblins and bears:** the goblins' old rule stays: no goblin band at a mouth with a bear within 120 m. Bear caves now make that happen more often near large caves; caves are at least 120 m apart, so it only bites when a bear wanders. The goblin camp's own cave has no dens (CD-4).
- **Not changed:** the bake, tile files and saves; the goblins' share and their floor rule; the ordinary habitat spawning.
- **Test:** `src/worldgen/tools/test_cave_animal_dens.gd`, plus the den looks in `test_cave_dressing.gd`.

## Stage 2: abandoned mines (built)
- **Where (CD-5):** `src/worldgen/runtime/mine_sites.gd` works out up to 2 to 4 mines per tile (the number from the tile's seed) when the tile loads, from its baked copper, tin and iron ore bodies (lens and halo shapes; a halo's adit drives for a point 0.6 of the way out on its ring) and its heights. A tile with no such ore under a fitting hillside gets fewer, or none. Nothing is baked and the tile files do not change. On a starter tile the ore body nearest the start area is tried first, so the nearest mine is as close to the spawn as the ore allows (outside the 400 m kept clear); "about 1 km" is not forced. Two mines' ore bodies are at least 400 m apart. A mouth is at least 150 m from any cave mouth and from each goblin camp's mouth and fire (`data/creatures/goblin_tribes.json`), and 400 m from the start area (Edda and Hob's camp), and the whole mine stays 300 m inside its tile.
- **The mouth:** on a dry hillside of 10 to 35 degrees whose ground rises toward the ore, at the level where the adit's climb meets the ore body. Past an open cut of 6 to 20 m (longer on gentler ground) the hill stands at least 2 m over the roof all the way in, with no water above. Drifts and stopes are held to the same rule: a drift stops where the hill would fall to less than 2 m over it or water lies above, and a stope that would break out is not cut. The first drift runs the way the hill rises.
- **The shape (from `caves-mines/PLAN.md` section 0):**
  - The adit is 1.8 m wide and 2.4 m tall. Agricola's is 1.15 m by 2.3 m; it is widened so the 1 m voxels never close it. It rises 1 in 100 inward, so water drains out of the mouth. It runs 20 m to about 330 m.
  - Sizes go by adit length: small up to 80 m (up to one drift and one stope), medium up to 160 m (up to two drifts and two stopes), large beyond that (up to two drifts, three or four stopes, and an air shaft), as far as the rock allows.
  - Drifts run 10 to 60 m along the ore body. Stopes are rooms 5 to 8 m across and up to 3.8 m tall, off the drifts or the adit's end, where the ore was taken out.
  - A large mine's air shaft rises from its first drift and has fallen in 3 m under the surface. A hollow on the hill marks it.
- **Timbers (CD-6, looks only):**
  - Sets of two posts, a cap and boards stand across the adit every 2.7 m from the mouth in: 6 m of it in a small mine, 10 m in a medium one and 15 m in a large one. Beyond that the adit is bare rock.
  - The deepest set of a medium (half of them) or large mine has fallen, with rubble beside it.
  - Each stope 3.6 m or taller has two props. A stope is as tall as the rock over it allows (2.4 to 3.8 m); one with less than 2 m of rock over its roof is not cut.
  - These are `cave_bones` kinds 6, 7 and 8, protocol 142, drawn by `cave_dressing.gd`. They have no collision and cannot be taken.
- **Left behind:**
  - A worn copper pickaxe lies at the far end, with three quarters of its life used up (copper, not bronze, so a mine never hands out a tier the player has not smelted).
  - A bucket, a rope or a burnt-out lantern may lie beside it.
  - Two to four pieces of the body's ore lie in each stope.
  - A spoil heap of about 30 stones and boulders is fanned out downhill of the mouth.
  - All of these are cave scatter rows (kind 2 for an item). The server lays them out like cave stones, and each is saved only once a player takes it. They are existing catalog items; nothing is added to the catalog.
- **Carving:** mines go through the caves' own carving, floor scatter, shelter and cave-air counts and flora clearing. TERRAIN_VERSION 77 drops the server's generated block cache once, and the shipped starter ground (`worlds/base_world/starter_cache`) is rebuilt for it with `tools/rebuild_starter_cache.sh`. Player digs in `digs.dat` replay on top. There is no wipe and no save change.
- **Risk:** a mine is carved into ground that players may already have built on. Only the start area is kept clear (400 m). A build that stands over a new adit can end up over a hollow. Past its open cut a mine is narrow (1.8 m) and at least 2 m under the surface, so this is unlikely, but it is not checked. The open cut itself is a trench up to 20 m long at the mouth, cleared of flora like a cave entrance. A mine's mouth is kept 150 m from cave mouths, but a long adit is not checked against a cave's inner passages.
- **Not changed:** the bake, ore bodies (mining an ore body still works as before), goblin and animal dens (a mine holds neither), bell pits (CD-7).
- **Test:** `src/worldgen/tools/test_mine_sites.gd`, plus the timber looks in `test_cave_dressing.gd`.
