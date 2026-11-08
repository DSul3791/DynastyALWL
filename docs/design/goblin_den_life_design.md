# Goblin den life: sleep in the den, watch at the firelight edge, forage berries (design)

Steve, 8 Nov 2026. This builds three things Dave already described in `docs/GOBLINS.md` (Behaviour, 7 Nov) that are not built yet. The coordinator agreed the order on 8 Nov. **Runtime only, no rebake, no protocol change.** Stealing stays out until Dave answers its open questions.

## 1. Today

- **Spawning:** a group of 2 to 5 is made at the mouth of a cave that has a goblin den (`lair_mouths`, `tile_terrain_data.goblin_den_mouths`).
  - By day the group beds down at the mouth (`resting()`). At night it ranges up to 70 m round the mouth.
  - It keeps out of fire light, watches a player from 60 m (ALERT), and runs at 30 m.
- **The den is the mouth.** The server had no cave floor height, so goblins never went inside.
  - The dressed den (bones, sticks, thatch, a small fire, #543) sits in the cave, empty.
- **Nothing makes a goblin seek a fire to watch, or go to a berry bush.**

## 2. What changes

### 2.1 Den by day (cave walking)

- **The path:** each goblin den gets a **path**, the floor points of the cave skeleton from the mouth node to the den node.
  - `tile_terrain_data.goblin_den_paths` holds one per den, parallel to `goblin_den_mouths`.
  - It is a breadth-first walk over the cave's segments. Each point is a node's floor: node y minus half its height.
  - The cave skeleton is the exact shape that is carved (#555), so the path is always open.
- **Moving along it:** a goblin **in the cave** moves only along this path. Its position is interpolated along the path at the floor height, with no surface steering. The client draws whatever position the server sends, y included.
- **By day:** goblins are made in the den, or walk in from the mouth at dawn, and rest there.
- **At dusk:** they walk out to the mouth and become ordinary surface goblins round it.
- **The den ring is now underground.** `_in_den` also needs the player within `den_m` vertically, so a player on the hill above the den isn't "in" it.
  - Inside the cave, a goblin reacts only to players on its own level (`cave_level_m` 6 m vertically).
  - **Further in:** a player who comes inside `spook_m` drives the band further in, toward the den.
  - **Fighting:** a player inside the threat range, or one who corners them at the den end, gets a short warning and then a strike (`defend.warn_s`, `hit_m`, `damage`). Backing off during the warning avoids it, the same contract as the big-game charge, without moving through rock.
- **Claiming a cave:** a group belongs to its cave (`lair` key) and no longer to "goblins within 40 m of the mouth". So a group sleeping 100 m inside still holds its cave.

### 2.2 Watch at the firelight edge (night)

- **Picking a fire:** at night, when a surface goblin finishes idling, it may pick (`watch_share`) a burning fire within `watch_reach_m` of its home. Torch bearers count too: the server's `fires` list.
- **Where it stands:** it creeps to a spot at the fire's keep-off radius plus `watch_gap_m`, on the side toward its cave. It never stands inside any fire's radius.
- **Watching:** it stands in ALERT facing the fire for `watch_s`. While watching it bolts only when a player comes within `watch_spook_m`, so the people at the fire can see the eyes at the edge of the light. That is the guiding doc's goblin sign, "glinting eyes".

### 2.3 Forage berries (night)

- **Picking a bush:** otherwise it may pick a berry bush within `forage_m` of home, outside every fire's radius. The bushes come from the flora chunks the server has already made (`berry_bushes`). Berry plants are the species with a `berry_yield` row in `drops.json`.
- **Eating:** it walks there and stands for `forage_s`.
- **The bush is not stripped.** Stripping it would take berries from players, which is a gameplay change for Dave, so this step leaves the bush as it is.

## 3. Data (`animals.json` goblin, a new `den_life` block)

`{"cave_level_m": 6, "watch_share": 0.5, "watch_reach_m": 150, "watch_gap_m": 2, "watch_s": [60, 180], "watch_spook_m": 6, "forage_m": 70, "forage_s": [20, 60]}`

## 4. Systems touched

| file | change |
|---|---|
| `tile_terrain_data.gd` | `goblin_den_paths` |
| `terrain_server.gd` | `animals.lair_path`, `animals.berry_bushes` (cached per chunk like `_trees_near_cached`) |
| `server_animals.gd` | the den-life hook in `_step`, path and claim in `_top_up_lair`, the vertical check in `_in_den`, the surface range centre in `_den_target` |
| `server_goblins.gd` (new) | cave walking, watch and forage |
| `animals.json` | `den_life` |

Nothing else changes for other species: every new branch keys on `den_life` or on a cave path.

## 5. How we know it works (David4 headless, then Dino)

- **Headless test (`test_goblin_den_life.gd`):**
  - a den path starts at the mouth and ends at the den (a made-up cave; that a real den path is open at LOD 0 is checked on the PC);
  - by day a new group is in the den, at floor height;
  - at night they walk out and become surface animals at the mouth;
  - a player on the hill above the den is not "in the den";
  - a player inside the threat range in the cave gets warned, and is struck only if still close when the warning ends;
  - a watching goblin stands outside the fire's radius and facing the fire;
  - a foraging goblin's target is a berry bush.
- **On the PC:**
  - a night picture of a goblin at the edge of a campfire's light;
  - a torch-lit picture of the band asleep in the den;
  - 0 shader errors.

## 6. Must not break

- Goblins never enter light.
- No bear within 120 m of a lair.
- Respawn stays at 30 min.
- Other species' dens (bear) keep their behaviour. The vertical check only matters where the den is far above or below the player.

## 7. Later (not in this step)

- Sleep and forage clips (`Sleep_Normally`, `Collect_Object`) need client states (MikeW).
- Stealing (Dave's questions).
- Fighting bears.
- The goblin whistle (Jason).
