# BLOCKER-001: Admin World Reset (brief and design record)

Requested by Dave in the project thread, 12 Nov 2026 19:15 UTC (priority CRITICAL, blocks the Mission 001 playtest). His words are the authority; this file records how the brief was read and the calls made where it is silent (Dave asked not to be asked: decide from the documents and record the reasoning).

## Ask (summary)
An Admin -> Reset World button usable in play. With explicit confirmation and the existing admin permission check, it must: reset every player terrain edit (digs, flattening, raising and other edits) to the generated ground; delete every player-dropped item with its saved record; delete every player-built or placed structure and object (foundations, walls, floors, doors, workstations, containers) with their contents. Whole active world, not only loaded regions. Keep the seed and generated terrain, characters (packs, skills, progression) and natural world content. Nothing may come back after a restart; server and clients stay in step; persisted modifications are cleared, not hidden.

## What was there
- Terrain: every dig, fill, hoe flatten and raise is one record in the ground edit log `digs.dat` (`src/stream/ground_ops.gd`). `ACT_RESET_EDITS` (Esc > Admin > Reset all terrain edits) already empties the log and rebuilds ground, water and the clients (`terrain_server.gd _reset_terrain_edits`, `net.ground_reset`).
- Dropped items, structures, campfires, remains, traps, carts, tilled beds and path patches are all rows of `_items` in `server_items.gd`, saved to `world_items.json`. Natural rows (scatter stones and sticks, boulders, shore and cave finds) carry `scatter`; trees and stumps `tree`; the showroom `showroom`; carcasses are `transient`. Scatter, trees, showroom and carcasses are never written to `world_items.json`.
- Container contents live in `_chests` by structure uid (`chests.json`); crops and bed moisture in `crops.json`; lights and kilns are flags on structure rows (`lights.json`, `kilns.json` are rebuilt from them).
- Every row of the world is in memory on the server at all times (the whole file is read at start), so working on `_items` covers the whole world, loaded or not.
- Admin permission: `server_admin.gd` (`admin_ok`), the same check as every other admin action.

## Design (smallest reliable)
- New action `ACT_RESET_WORLD := 79` (no protocol change, a new kind, like `ACT_CLEAR_DROPS`). Admin only; a non-admin is told no and nothing changes.
- `server_items.reset_world()`: lets go of carts, removes every row that is not natural (keeps `scatter`, `tree`, `showroom`, transient), removes their roofs and their `_chests` stores, clears crops and plot water, rebuilds the walk grid, water network, supports and pot links, clears per-player caches that name world ids, re-sends remains, then saves every store file synchronously (no queued older write may land after it).
- The action then calls the existing `_reset_terrain_edits` (log emptied on disk at once, ground and water rebuilt, every client reloads its ground). Every player is told.
- Clients learn of the removed rows through the normal world sync (removed ids), the same path as any take-down.
- Esc > Admin gets "Reset world (terrain, dropped items, buildings)", which opens a confirmation page (Yes / No), the same pattern as the terrain-edit reset.
- Testing hook only: `--dev-reset-world=S` on the terrain server runs the same two steps after S seconds with no player (used by the real-server check; normal play never passes it).

## Calls made where the brief is silent
1. **All loose items go, not only those a player let go.** After a save a loose row does not record who dropped it; loot, goblin den piles, split logs and stuck arrows are the same kind of row. They also expire on their own. Keeping some would need a new saved field (a schema change) for little gain.
2. **Remains go** (a dead character's pile): they are dropped items in the world, not the character's pack. The character record itself is untouched.
3. **Tilled beds and their crops go; path patches go**: both are player-placed structure rows. Saplings stay (`_saplings` mixes natural regrowth and replanted bushes and is flora, which the brief keeps).
4. **Trees stay as they are** (felled trees stay felled, stumps stay): trees are natural content and the brief does not ask for regrowth. Picked scatter marks, picked and bare plants, boulder and bog-iron counts stay for the same reason. Plants removed under buildings (`flora_removed.json`) are not restored.
5. **Characters are not touched at all**: packs, worn gear, vitals, skills, coins, learned recipes, craft queues and the spawn-bed record (a missing bed falls back to the world spawn as it does after any take-down).
6. **Admin-placed NPCs and markers** (`npc_admin.json`) are not player construction and stay.

## Acceptance
Unit test with restart (`test_reset_world.gd`), real terrain server reset and restart on a throwaway store (`reset_world_store.gd` + `--dev-reset-world`), game start smoke on an isolated user folder, related tests from `tools/tests_for_diff.py`, independent review on the exact SHA. Results: `RESULTS.md`.
