# Cave dens and abandoned mines

**Status: PROPOSED design with PROVISIONAL answers.** Dave asked for it on 19 Nov 2026 (thread "Plan caves and abandoned mines"): "we need to start adding stuff into the world for players to discover like natural caves or abandoned mines that already have bracing. we should research how they build mines in the medieval times just for the direction, slopes and depths and sizes." He added the same evening: "more than likely natural caves will become dens for animals or creatures." While he was away the coordinator answered the plan's questions for him under his 14 Nov standing rule. Those answers are recorded as **assumed on Dave's behalf** below, and he can change any of them. The research and the full plan are in the project Library at `caves-mines/PLAN.md`.

## Decisions (assumed on Dave's behalf, 19 Nov 2026, coordinator)
| ID | Decision | Status |
|---|---|---|
| CD-1 | Bears, wolves and foxes may den in caves. | PROVISIONAL |
| CD-2 | Dry natural caves stay off (Dave 7 Nov: "caves only at river starts"). Abandoned mines are the dry underground places. | PROVISIONAL (keeps his 7 Nov rule) |
| CD-3 | 70 % of the inland caves with passages that hold no goblin den hold an animal den. The animal follows the cave's size: large caves and lava tubes are bears, medium caves wolves, small caves foxes. The pick comes from a hash of the cave's id. | PROVISIONAL (thread's value) |
| CD-4 | Cave 3,4#8013 is kept free of animals, because it is proposed for the goblin trading camp (separate thread). | PROVISIONAL, pending Dave's OK on the camp |
| CD-5 | 2 to 4 abandoned mines per tile, with one about 1 km from the spawn. | PROVISIONAL |
| CD-6 | A mine's old timbers are looks only. They cannot be pulled down for wood for now. | PROVISIONAL |
| CD-7 | Bell pits wait for the iron work (bog iron, iron-stained outcrops). | PROVISIONAL |

## Stage 1: cave dens (built)
- **Rule:** `TileTerrainData.animal_den_species(cave)` (CD-3, CD-4). The server and the dressing read the same rule. Goblin caves are decided first and never hold an animal.
- **Signs a player can read:** droppings a few metres in from the mouth, to the side of the stream. A bear or wolf den also has old bones there, from kills brought home. A trampled bed of leaves, grass and fur lies at the den spot: the cave's dry branch, else its den nearest the entrance. These are `cave_bones` kinds 4 (droppings) and 5 (bedding), protocol 141, drawn by `src/client/cave_dressing.gd`.
- **The animals:**
  - A bear or fox top-up near a player takes an empty den mouth first, within the normal spawn reach, never within `never_within_m` of a player and never twice (`server_animals.cave_den_spot`). A bear made there has the mouth as its den.
  - A wolf pack's 2 km cell uses a wolf cave inside it as the pack's den, if the mouth is wolf ground (`server_wolves._natural`, `server_animals.cave_den_in`). Otherwise the pack keeps its hashed spot.
- **Not changed:** the bake, tile files and saves; the goblins' share and their floor rule; the ordinary habitat spawning.
- **Test:** `src/worldgen/tools/test_cave_animal_dens.gd`, plus the den looks in `test_cave_dressing.gd`.

## Stage 2: abandoned mines (next)
These are to be built after stage 1 merges, following `caves-mines/PLAN.md` sections 0 and 3:
- an adit 2.0 to 2.2 m high and 1.2 to 1.5 m wide, rising 1 % inward toward an ore body that exists;
- drifts and stopes along the ore body;
- an air shaft on large mines;
- timber sets at the mouth and in soft ground;
- a spoil heap, a few ore rocks and old tools.

Mines are carved from the seed when a tile loads, with one terrain version step. There is no world wipe, and player digs are kept.
