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

There are no boards without a saw mill, so the first storage chest is a woven basket chest: 10 sticks + 4 twine, 12 slots, item ids unchanged (`chest_kit`, `chest`; names "Woven chest" (kit and placed); material wicker). Taking an empty one down returns the kit. A plank chest (more slots, wood, boards plus nails or twine) is a later item with its own id after the saw mill. Art: the model should read as wicker, pale twigs bound with twine, a lid band of darker twine; Sounds: material is wicker, not wood.

## Chopping block (build 202)

Kit from 1 log (recipe 15), placed like the other structures (cap 4 per 256 m chunk, state 7, saved in the same world_items rows). E within 3 m with a usable axe turns one log into 4 firewood (item 26, stack 40, 300 s of fuel; E at a fire burns firewood, then sticks, then logs); hold E repeats every 0.6 s; each split wears the axe one use (ACT_USE_STRUCT 17). Saw mill (lumber) waits for the building design.

## Hunger, health and body weight (protocol 18)
Server-owned and saved per player (vitals.json). Energy balance: a stomach holds up to 2400 kcal; the daily need comes from body weight and exertion; surplus or deficit moves a slow body weight (7700 kcal per kg). A full stomach lasts about 1.07 game days (about 64 real minutes at the 24:1 clock) at ordinary work, longer at rest. No death from hunger: at zero only a warning and slower health recovery. Food kcal and heal values live in data/items/vitals.json. Eat: ACT_EAT (18). RPC vitals(hunger, health, weight_dkg). Events for Sounds: eat and heal via sound.itemfx.eat(item_id).

## Carrying weight (no protocol change)
Slots plus weight. data/items/weights.json gives kg per item (by_id, by_suffix, default). Comfortable load = 0.35 x body weight (placeholder for strength; 26 kg at 75 kg). Past it the walk slows smoothly (smoothstep) to 35 percent speed at 2x the comfortable load, which is also the hard cap: the server (give, pickup, chest take) will not take more. A heavy pack adds up to 30 percent work per comfortable load to exertion, so it burns more food. The client shows "Carrying x of y kg" in the inventory panel and item weights in tooltips. Shared rules: src/shared/carry_rules.gd.

## Exertion, over-exertion and fainting (protocol 20)
Server-owned strain (data/items/exertion.json, not saved). Effort is movement speed, tool work and pack load (uncapped); strain climbs while effort is above rest_effort (running, heavy packs, long chopping) and falls below it. Walking is sustainable. States: 0 normal, 1 over-exerted at strain 1.0 (client caps speed to 3 m/s, no sprint, "You are exhausted" note) until under 0.75, 2 fainted at 1.4 (movement locked 8 s: vision fades over the first 5 s, the heartbeat over the last 3), 3 waking for 12 s (control stays locked, vision returns, strain restarts at 1.1 and falls at 0.4x pace until under 0.75). Thresholds scale with body weight and a fitness factor (placeholder 1.0). No death.
RPC strain(strain_pm, state, fade_pm), sent only on change. Client reads (inventory_view): strain, strain_state, strain_fade, faint_state(), move_cap(); the picture is Art's client.faint.set_state(name, strain, progress) (states normal, over_exerted, fainting, fainted, waking; faint.blackout for Sounds); sound.breath.set_exertion(strain) is called every 0.1 s. For Sounds: heartbeat gain while fainted = 1 - clamp((fade - vision_frac) / (1 - vision_frac), 0, 1); while waking the heart races (strain is above 1). For Art: replace the plain black overlay (inventory_view _black) with a vignette using blackness().

### Stance and rest (protocol 21)
ACT_STANCE (20, a = 0 stand, 1 crouch, 2 sit, 3 lie); the server's answer is the new last field of strain(). Fainting forces lying and a fainted or waking player cannot choose; walking off faster than 1.5 m/s stands a sitting or lying player up. Strain rests faster sitting (x2) and lying (x3) with no floor, so it reaches 0; standing or crouching under a heavy pack only rests down to about half (floor 0.5 x load ratio). A pack adds load_effort x ratio^1.5 to the effort of anyone moving, even at the crawl a full pack allows (min speed 25 percent), so a pack at the limit tires you quickly. Client: items.request_stance(s), items.stance_confirmed, items.stance_event (Ground owns keys C crouch, X sit, Z lie and the camera height).

Regression: python3 tools/items_check.py runs the item unit tests and the headless client scenarios (chest, gather, lean-to, eat); exit 1 on any failure.
Placeholders for the saw mill era (job 28, data only): lumber (27), plank chest kit (28) and plank chest (29, 20 slots, structure plank_chest, row state 6 like the woven chest), recipes marked known false with a station (saw_mill, workbench) until those exist. No client art or station code yet.

## Naming rule (Dave 2026-10-20)
Item and recipe names are the plain item name only, with no verb: "Basic torch", "Wooden spear", "Stone axe", "Campfire", "Small shelter", "Stone knife", "Wooden spade", "Comfrey poultice". Never "Bind a...", "Carve a...", "Chip a...", "Pound a...", "Make a...". The crafting list and its detail heading show just that name. Ids do not change.

## Real pickup meshes and natural scatter (2026-10-20)
- Dave's `assets/natural_pickups/*.glb` (3 smooth stones, 3 rough stones, 3 forest sticks, 3 driftwood; metres, Y up, contact at Y=0, vertex colours, 970 to 1,700 triangles each) are the shapes of loose stones and sticks. The client picks one by world id (`_natural_mesh`), turns, scales, tilts and part-buries it (`_dress_natural`). One shared mesh per variant, import-made LODs, hidden beyond 45 m (stones) and 70 m (sticks), no shadow casting. Missing files fall back to the procedural shapes. Driftwood is imported but not placed yet (waits for a server water-bank query).
- Server scatter (`_scatter_spot`, odds in `data/items/drops.json` ground_scatter): counts unchanged. Sticks prefer spots under tree crowns (`cover_at`) and avoid bare rock; stones prefer slopes, bare rock (`rock_at`) and hollows at the foot of a rise; some of each stay in open ground.

## Fall damage and refused actions (job 62, protocol 23)
- The client reports a hard landing (`sound.landing.hurt`, from 6 m) with ACT_FALL; the server alone decides: nothing under `fall.safe_m` (6 m), `per_m` (8) health per metre beyond it, a faint from `faint_m` (12 m). Health stops at 1. Limited to one report per 2 s; a client that stays silent only spares itself (a server-side height tracker can replace this later).
- `reject(reason)` goes to the player when the server refuses a pickup, mining or felling for reach (0), a missing tool (1) or a full pack (2); the client calls `sound.itemfx.reject`, which limits itself to one cue per 600 ms. The text notices stay as they were.
