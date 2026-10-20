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

## Tool wear (build 195, protocol 14)

Dave 2026-10-20: tools wear out slowly and are repaired with materials. `durability` (uses) and `repair` (materials) are in items.json: stone axe 200 (1 stick + 1 twine), wooden spade 150 (1 stick), stone knife 120 (1 stone + 1 twine), stone spear 100 (1 stone + 1 twine), wooden spear 40 (1 stick). Wear is a number per inventory slot (`Inventory.wear`, 8 bytes per slot on the wire, `[number, count, wear]` in inventories.json version 2; version 1 files load with zero wear). The server adds one use per effective blow (tree hit, trunk blow, mining a stone, picking something that needs the tool, a throw). At full wear the tool is Broken: `_has_tool` skips it, the client treats it as no tool. The Repair button (ACT_REPAIR 13) spends the materials and wins back half the durability, also for a broken tool. A dropped, thrown or picked-up tool keeps its wear. The slot shows a green-to-red condition bar and a percent; the tooltip lists the repair cost.

## Lean-to and storage chest (builds 198 and the chest push)

Both are placed from kits (structures.json): left click with the kit held, yaw from where you look (count in ACT_PLACE), 2.5 m apart, caps per 256 m chunk (6 lean-tos, 8 chests). A lean-to adds a 2.2 x 1.9 m roof, 2.1 m high, to the Cover index on server and client (Water's roof API), so fires under it survive rain. A chest has 30 server-owned slots (chests.json, keyed by a stable uid saved in the world-item row); ACT_CHEST_OPEN / PUT / TAKE with a 4 m reach check, the full contents go only to the acting player (chest_contents RPC). A chest holding things cannot be taken down; anyone can open any chest until households exist. Sound hooks: `sound.placed.chest/container` from the chest screen, world rows are heard by item id.

## First chest is woven (Dave, 2026-10-20)

There are no boards without a saw mill, so the first storage chest is a woven basket chest: 10 sticks + 4 twine, 12 slots, item ids unchanged (`chest_kit`, `chest`; names "Woven chest kit" and "Woven chest"; material wicker). Taking an empty one down returns the kit. A plank chest (more slots, wood, boards plus nails or twine) is a later item with its own id after the saw mill. Art: the model should read as wicker, pale twigs bound with twine, a lid band of darker twine; Sounds: material is wicker, not wood.

## Chopping block (build 202)

Kit from 1 log (recipe 15), placed like the other structures (cap 4 per 256 m chunk, state 7, saved in the same world_items rows). E within 3 m with a usable axe turns one log into 4 firewood (item 26, stack 40, 300 s of fuel; E at a fire burns firewood, then sticks, then logs); hold E repeats every 0.6 s; each split wears the axe one use (ACT_USE_STRUCT 17). Saw mill (lumber) waits for the building design.

## Hunger, health and body weight (protocol 18)
Server-owned and saved per player (vitals.json). Energy balance: a stomach holds up to 2400 kcal; the daily need comes from body weight and exertion; surplus or deficit moves a slow body weight (7700 kcal per kg). A full stomach lasts about 1.07 game days (about 64 real minutes at the 24:1 clock) at ordinary work, longer at rest. No death from hunger: at zero only a warning and slower health recovery. Food kcal and heal values live in data/items/vitals.json. Eat: ACT_EAT (18). RPC vitals(hunger, health, weight_dkg). Events for Sounds: eat and heal via sound.itemfx.eat(item_id).

## Carrying weight (no protocol change)
Slots plus weight. data/items/weights.json gives kg per item (by_id, by_suffix, default). Comfortable load = 0.35 x body weight (placeholder for strength; 26 kg at 75 kg). Past it the walk slows smoothly (smoothstep) to 35 percent speed at 2x the comfortable load, which is also the hard cap: the server (give, pickup, chest take) will not take more. A heavy pack adds up to 30 percent work per comfortable load to exertion, so it burns more food. The client shows "Carrying x of y kg" in the inventory panel and item weights in tooltips. Shared rules: src/shared/carry_rules.gd.
