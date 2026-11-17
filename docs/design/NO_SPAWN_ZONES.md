# No spawning near what players put down

**Status:** Dave's ruling, 17 Nov 2026 (project thread "Block spawning near player builds"). Built on `dev`; nobody has played it yet.

**Dave's words:**
- "anything a player puts down like building peices, crafting stations, chopping blocks etc have to block spawning of trees, animals, rocks and anything else for at least 20 meters radius fromt he item placed. we can adjust this number if we must later."
- "it should remove grass but not trees or rocks but if a player harvest the trees or rocks they should not respawn"
- "if the items blocking repawns is removed then stuff is allowed to respawn"
- On how far grass goes: "only close and under it."

## What it does
- One number: `no_spawn_m` (20 m) in `data/items/structures.json`.
- Within that distance of anything put down, nothing wild appears or regrows: no sapling from a rotted stump, no animal, herd, goblin group, wolf pack or wolf pup, and no stray dog.
- Trees, rocks, sticks and stones already standing there stay. What a player harvests there does not come back, as before.
- When the last piece near a spot is gone (taken down, destroyed, burnt out), spawning there comes back.
- Grass, leaf litter and small plants are cleared only close round a piece and under it. This is client-side ground cover, `data/look/placed_clearing.json` `radius_m` (now 3 m from the piece's spot, bare for the first 2 m, thinning to 3 m). Floor tiles and paths clear only their own footprint, as before.

## How (server)
- `src/stream/spawn_zones.gd`: a hash of 16 m squares. Each piece put down is filed by id in every square its 20 m circle touches, so a spawn check reads one square. No scan of all structures.
- Pieces are added where they are placed, finished, laid or loaded. That covers structures, blueprint sites, torches, path patches, tilled beds and fires. So the zones are right after a restart and for structures already in a save.
- Removal needs no call. A check asks the server's item list whether the id still stands and forgets it if not (the same way `structure_grid.gd` works).
- `server_items.spawn_blocked(x, z)` is the one question. The sapling seeding (`_maybe_sapling`), the animal top-up, goblin lairs, wolf dens and pups and the stray dog ask it.
- It replaces the old sapling-only rule: a 50 m scan of every item for each rotted stump (BUG-013, `REGROW_EXCLUDE_M`), which is deleted.
- Another no-spawn rule, such as the surveyed path's, can register its own rows through `_zone_add`.

## What already never respawns (checked, no change)
- Felled trees: a removal is stored in `flora_removed.json` for good. The only tree that ever appears later is a sapling from a rotted stump, which is now blocked.
- Loose stones, sticks, bank stones, cave stones, boulders and the copper and tin ore rocks: they are laid out per scatter cell from the world seed, and what is taken is remembered in `_taken` or `_boulder_left` and never comes back. They are not blocked from being laid out, because the layout is the same ground that was there before the build. Blocking it would delete them after a restart, and Dave said those stay.

## For Dave (assumed on his behalf, provisional; change in data)
- NS-1: blueprint sites (not yet built) count as put down from the moment they are placed. So do torches, path patches made with the hoe, tilled garden beds and campfires. Dropped items, carts and barrows (they move), a body's remains and carcasses do not count.
- NS-2: Hob's town pieces and other world pieces count like a player's, so nothing sprouts or spawns inside the town.
- NS-3: player planting is never blocked. Seeds, dug-up bushes, saplings a player plants and garden crops grow next to a house as before.
- NS-4: grass is cleared 3 m round a piece's spot (was 5 m), bare for the first 2 m.
- NS-5: animals are only stopped from spawning there. They can still walk in. Young born with their mother are part of her spawn, and admin-placed animals are not blocked.
- NS-6: saplings now keep 20 m away from builds, not 50 m (one number for everything). Raise `no_spawn_m` if trees grow back too close.
- NS-7: the refills of a fixed spot are not spawns and are unchanged: berries and herbs bearing again, birds' nests, tide-line finds, fish, bog iron, and stones broken off bare rock.
- NS-8: if a new world layout version ever adds scatter (as the copper rocks did), new rocks can appear near old builds once. Nothing does this in normal play.

## Tests
- `src/worldgen/tools/test_spawn_zones.gd`: the grid (20 m edge, fire, remains and dropped items, removal, a moved piece), the server after a save and a load, saplings blocked then allowed again, and animals.
- `test_server_items`: the sapling ban now at 20 m.
