# Tree felling state: design note (2026-10-20, Items and crafting thread)

For Technical direction approval before any code (JOBS.md job 8). Rules are Dave's (DESIGN_IDEAS 5): trees are only cut with tools; a felled trunk stays on the ground and is processed with tools; a trunk rots after a real week (168 game days at 24:1); nothing respawns while trunks lie around; respawn is only as saplings near a standing tree of the same type, growing over a few game days.

## Identity
- A placer tree keeps its stable id `species << 16 | cell` inside its flora chunk (unchanged). Standing = in the placer list and not in `flora_removed.json`.
- Anything new gets its own id space so it can never clash: bit 31 set, then a counter kept by the server (`0x80000000 | n`).

## States
1. **Standing**: implicit, nothing stored.
2. **Felled**: the placer id goes into `flora_removed` (existing path, `flora.cut`, so clients already drop the standing model) and a trunk record is made: species, position, yaw (falls away from the chopper), length and radius from the species table and the tree's height, `felled_at` (game seconds), `logs_left`.
3. **Stump**: made at the same moment at the tree's position (species, radius). It stays until the trunk record rots, then both go.
4. **Sapling**: record with species, position, `planted_at` (game seconds). After 3 game days it is a **young tree**, after 12 a full **grown tree** drawn as a normal standing tree with a new-space id (so it can be felled like any other).

## Saved data
- `tree_states.json` in the server store: `{"version": 1, "next": n, "trunks": [...], "stumps": [...], "saplings": [...]}`; written atomically (temp then rename) every 30 s when changed and on quit; unreadable file kept as `.bad`, empty state used.
- `flora_removed.json` is unchanged. No tile or block format change, no `TERRAIN_VERSION` bump. Unknown species in a record is skipped and kept.
- Caps in one constants block: 32 trunks and 32 stumps per chunk (a chunk at the cap refuses further felling with a "too crowded" note), 64 saplings per chunk.

## Rot and respawn (lazy, no per-frame work)
- Rot: when a chunk's records are read (a player nearby, or every 60 s over loaded chunks), a trunk or stump older than 168 game days is deleted. Because only the game clock matters, a stopped server does not rot trunks.
- Respawn: also evaluated lazily when a chunk is loaded: for each rotted-away tree site, if the chunk has no trunk lying and a standing tree (placer or grown) of the same species is within 25 m, and a seeded dice roll says so, a sapling is placed within 6 m of that standing tree. Rolls use the seed, chunk and site so a restart gives the same answer. Nothing else spawns trees.
- Growth: sapling to young to grown is computed from `planted_at` when read; the client is told the current size when it receives the chunk.

## Network (no new message type)
- Chopping: `inventory_action` kind `ACT_HIT` (7): `a` = tree id, `b` = chunk x, `count` = chunk z. The server checks the player has an axe on the hotbar, is within 3.5 m of the tree, rate-limits to one hit per 0.4 s, and adds damage; hits needed come from the trunk radius (about 6 for a young tree, 40 for a big one). Progress is kept in memory only and resets after 60 s.
- Showing state: the existing `world_items` rows gain states 3 (trunk), 4 (stump), 5 (sapling/young/grown shown through the flora view) and an optional extra dictionary at the end of a row (species, yaw, length, size). Old clients ignore unknown rows. Sent to players within 100 m like other world items, so trunks and stumps do not count against the 64 per chunk item cap but have their own caps above.
- Saplings and grown trees are added to the flora view as ordinary tree instances with a size scale: this touches `flora_view.gd` (Art direction), so Art gets a heads-up and the hook is one function: `flora.add_dynamic_tree(id, species, position, size)`.

## Cost at Low
- Server: a few dictionaries per chunk, read lazily, one small file. No per-frame work.
- Client: a trunk or stump is one simple mesh (a handful per area); saplings and grown trees go through the existing MultiMesh per species, so no new draw calls beyond a few instances.
- Dave's rules respected: no digging under trees here; felled trees never vanish except by rot.

## Build order after approval
9 chop and fall (ACT_HIT, trunk and stump records, hit sounds hook); 10 process a trunk into logs, branches, bark, leaves, seeds (drop table); 11 rot, sapling respawn and lazy growth.
