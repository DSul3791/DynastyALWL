# Items and inventory: design note (2026-10-20, Items and crafting thread)

Short note for Technical direction approval before code. Stats are placeholders until skills exist.

## Items
- One table, `data/items/items.json`: each item has a string id (`stone`, `stick`, `plant_fibre`, `log`, `stone_axe`, `spear`, `campfire_kit`...), a number (stable, never reused), name, stack size, kind (material, tool, weapon, placeable), and a look-alike list for inspection mode.
- Shared code: `src/shared/item_table.gd` (loads the table), `src/shared/inventory.gd` (slots, add, remove, move; pure data, no scene code, so server and client use the same rules).
- Tool and weapon items carry placeholder numbers (damage, dig strength, durability) from the table.

## Inventory
- 30 slots, each `{item number, count}`; tools stack to 1. Later weight can be added without changing the layout.
- **Server owns it.** The client only asks (pick up, drop, move, craft, use) and shows what the server says.
- Until accounts exist, the client keeps a random player key in `user://player_key.txt` and sends it once after connecting; the server files the inventory under that key.

## Network (protocol 9 to 10, tolerant decode)
- client to server: `hello(player_key)`, `inventory_action(kind, a, b, count)` (move, drop, craft, use).
- server to client: `inventory(bytes)`, the whole inventory, sent only when it changes (about 100 bytes).
- Dropped and harvested things appear as small world items: `world_item_spawned(id, item, position)` and `world_item_removed(id)`, sent only to players within 100 m. Pick-up is a request the server checks against distance (3 m).
- Harvest (stone, sticks, fibre, wood) reuses `cut_flora` ids: the server turns a removed flora item into drops from a drop table (`data/items/drops.json`), so tree fall can use the same table later.

## Save
- `inventories.json` and `world_items.json` in the server store folder, written every 30 s and on quit, atomic (write temp, rename), each with a `version` field. No change to tile, block or flora formats; no `TERRAIN_VERSION` bump.

## Cost at Low
- Server: a dictionary per player and one small file; no per-frame work.
- Client: inventory panel is built when opened (I key) and hidden otherwise; world items within 30 m are a few meshes (one MultiMesh if over 50). No change to the render budget.

## Light budget (job 20, 2026-10-20)

All item lights are `OmniLight3D` with `shadow_enabled = false`. Per-frame cost is the number of lit lights that reach the screen.

| Tier | Fire lights (nearest first) | Held light | Most item lights at once |
|------|----------------------------|-----------|--------------------------|
| Low | 1 | 1, but off while a fire light is within 8 m | 1 near a fire, 2 apart from one |
| Medium | 2 | 1 | 3 |
| High / Ultra | 3 | 1 | 4 |

Fires are server records (8 per 256 m chunk); only the nearest few get a light, the rest are drawn as flame meshes. The held torch is one light with a flicker set from the clock (no timer, no allocation). No GPU timings: the cloud has no graphics, so Dave's F8 tables decide whether Low needs a lower cap. A lantern (when it exists) uses the same single held light, so the table does not change.
