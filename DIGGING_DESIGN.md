# Digging the ground with a spade (design note, Ground loading, 2026-10-21)

Goal (Dave): hold a spade, dig the ground in front of you, the hole is real for everyone, it survives a server restart and a re-bake, and the grass and pebbles on it vanish.

## Who does what

- Client: spade in hand, left click swings the arms (already plays), then sends `inventory_action(ACT_DIG, slot, 0, 0, point)` with the ground point under the crosshair. Nothing is edited locally; the hole appears when the server answers (about one round trip, it already works this way for the admin dig).
- Server checks, then digs: the player holds a spade (any slot of the 8 hotbar slots, not broken), the point is within 3.5 m of the player's last reported position, one dig per 0.7 s per player, point inside the loaded world. Wears the spade (`drops.json` tool_wear, use "dig"). A refused dig answers with `reject`.
- Server digs a sphere of 0.9 m radius centred 0.25 m below the point (a shovel-sized pit; a few digs make a hole), tells everyone with the existing `dug(center, radius)` and `tile_changed`, and calls `water_live.dig` so water can fall in.
- Client on `dug`: unchanged (`_on_dug` edits the voxels, plays the dig sound, calls `GrassView.ground_changed`, so pebbles and grass vanish).
- The old `dig` RPC (any peer, radius up to 8 m) stays for the admin Ctrl+X tool only and is refused for a normal player once the spade works (server checks the admin flag).

## How edits are saved (the part that has to survive re-bakes)

Today an edit stores the whole 16 m block in `edits.sqlite`. That block then hides any later re-bake of the ground under it (its old copy of the terrain wins).

New: the server owns a dig log, `digs.dat` in the store folder, version 1. It is an append-only list of records `x, y, z, radius` (four float32) after a header (`DIGS1`, record count). The log is the truth, not the blocks.

- `load_block` makes the base block as before (generated or from the base cache, never saved with digs in it), then replays the log records that touch that block, in order, with the same sphere maths `dig_sphere` uses today. A re-bake changes the base; the holes are cut again on top of the new ground.
- An index (block key to record numbers) is built at start and extended on each dig, so a load only looks at records near it.
- Old saves: blocks already in `edits.sqlite` are still read first as the base for that block, then the log is replayed over them. Nothing is lost; no migration.
- Tile revisions rise on each dig as today, so client caches reload the changed tiles.
- Fill, building foundations and water edits will add record kinds later (record gets a kind byte in version 2); `digs.dat` is versioned for that.

## Cost

- Client at Low: nothing per frame. One RPC per swing, one voxel sphere edit (same as the admin dig) and two grass redraws of the cells around.
- Server: replay is a few hundred voxel writes per touched block; only blocks with records pay.

## Protocol

New `ACT_DIG = 25` (inventory_action: a = pack slot of the spade, at = ground point). PROTOCOL_VERSION +1, PROTOCOL.md updated. New save file `digs.dat` documented under Save formats.

## Not in this job

Dirt as an item, piling the dug soil, refilling, deeper tool classes (pick for rock), trampled-hole collision for creatures.
