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
Slots plus weight. data/items/weights.json gives kg per item (by_id, by_suffix, default). The most a body carries is 0.7 x body weight (placeholder for strength; 52.5 kg at 75 kg): the server (give, pickup, chest take) will not take more. **Up to 80 percent of that limit (42 kg at 75 kg) nothing hinders at all** (Dave 2026-10-21): full walk, jog and run speed and no extra effort. Above 80 percent the walk slows smoothly (smoothstep) to 25 percent speed at the limit, and a moving player's effort gets load_effort (0.6) x fraction^1.5 added, where fraction runs from 0 at 80 percent to 1 at the limit (so a pack at the limit tires you quickly even at a crawl). The old rule (hindrance from 50 percent of the limit, effort from the first kilogram) made even a few kilograms count; the loads 0, 2 kg, 79%, 80%, 81%, 90% and 100% are asserted in test_server_items.gd ("carry loads:" line). The client shows "Carrying x of y kg you can carry" in the inventory panel and item weights in tooltips. Shared rules: src/shared/carry_rules.gd.

## Exertion, over-exertion and fainting (protocol 20)
Server-owned strain (data/items/exertion.json, not saved). Effort is movement speed, tool work and pack load (uncapped); strain climbs while effort is above rest_effort (running, heavy packs, long chopping) and falls below it. Walking is sustainable. States: 0 normal, 1 over-exerted at strain 1.0 (the pace drops about 10 percent (over_speed_factor 0.9) but the player may keep running and keep raising strain until the blackout, "You are exhausted" note) until under 0.75, 2 fainted at 1.4 (movement locked 8 s: vision fades over the first 5 s, the heartbeat over the last 3), 3 waking for 12 s (control stays locked, vision returns, strain restarts at 1.1 and falls at 0.4x pace until under 0.75). Thresholds scale with body weight and a fitness factor (placeholder 1.0). No death.
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

## Persistence drills and stress (jobs 63, 64)
- Every item save keeps `<name>.prev` (the save before it); a torn file is restored from it. Drills: src/worldgen/tools/test_persistence_drills.gd (in tools/items_check.py).
- Stress with simulated players: src/worldgen/tools/stress_items_players.gd; numbers in /mnt/project-files/items/STRESS_20_PLAYERS.md (20 players: 0.47 ms average tick, 3.2 ms worst).

## Lazy sapling growth and trunk rot (job 66)
Nothing ticks per frame for either. A sapling's size is computed from `planted_at` whenever it is looked at (young at 3 game days, full tree and fellable at 12). Felled trunks and stumps rot in a pass every 60 s that looks only at felled records (`rot_scanned`, `rot_removed` count the work); after any gap (server off, nobody near) the first pass removes every stump past 168 game days, and a stump's sapling is dated from the moment it rotted (`felled_at + 168 days`), so it has grown by the time anyone sees it. Tested over 7 and 170 game days in test_server_items.gd.

## Container rules (job 73)
In structures.json each container has `slots` (stacks it holds), `max_kg` (weight it takes: woven chest 40 kg, plank chest 150 kg, placeholders) and `who` (only "anyone"; "owner" and "town" come with ownership). A put past the weight puts what fits (stack by stack) and refuses the rest with the pack-full cue; a full chest or a pack at its carry cap moves nothing and loses nothing (tests in test_server_items.gd). The validator checks the three fields.

## Skill hooks (job 70)
data/items/skills.json maps each action (gather_plant, fell_tree, work_trunk, split_log, mine_rock, craft) to a skill and an effect (yield, or speed). The server asks `skill_factor(peer, action)`, which calls the `skill_level(peer, skill)` callable once the skill system provides it; until then it is 1.0 everywhere, so nothing changes. Factor is limited to 0.25 to 4. New skill-affected actions: add a row and call `skill_factor`.

## Placement ghost and footprint table (jobs 69 and 76)

Footprints (`footprint_x`, `footprint_z`) and the fire gap and cap now live in `data/items/structures.json`. `src/shared/placement_rules.gd` holds the one rule set: `blocked(cfg, kit_id, spot, rows)` returns "", "close" or "crowded". The ghost in `held_item.gd` uses it (yellow in the open, green under cover, red when blocked); the server reads the same numbers. `test_placement_rules.gd` checks that the ghost and the server agree for every kit across 60 spots within reach. Sounds and Water can read the same footprint table.

## Thirst (job 67, Dave 2026-10-21)

Simple thirst: a blue bar under health, drink at the water's edge, and at least one drink per game day of something. The server owns "wet" (ml, cap 2400 in vitals.json "thirst"). It falls 1000 ml a game day at rest plus 1200 ml x exertion, so a full body lasts a whole game day even at full exertion (2200 ml). Drinking at the water (E, ACT_DRINK) gives 300 ml a mouthful; the scene's `water_near` callable says whether water (the live sim, else the baked water file) lies within 3 m of the feet. Drink items go in vitals.json "drink" (ml per item, by id or suffix) and are used with Eat; none exist yet. Empty thirst stops health recovering (like an empty stomach) and shows "You are parched"; nothing else and nothing deadly yet (no sickness from water, as Dave decided). The client shows the bar, a drop symbol in the status row under 15%, and the "Press E to drink" prompt, which wins over plant gathering only when water is ahead. Unit tests in test_server_items.gd cover the day length, parched, drinking, refusal and saving.

## Bank stones (Dave 2026-10-21)

Art's drawn boulders and pebbles are gone; every rock in the world is a real pickable stone. `_lay_out_bank_stones` (server_items.gd, odds in drops.json ground_scatter "bank") adds stones along water: in a cell with water within 24 m it tries 60 spots, and a dry spot within 3 m of water takes a stone with chance 0.5, up to 6 a cell. The scene's `water_near` callable is the bank test (live water sim, else the baked water file). Stones are the normal stone item at the 3x size. Twigs and leaf cards under tree crowns stay Art's non-carryable floor litter. Checked in test_server_items.gd (four cells by a stream).

## Luck (job 77, Dave 2026-10-21)

Luck applies to ALL rolls: chance, loot, fate. Design note: /mnt/project-files/items/LUCK_DESIGN.md. A whole number from -10 to +10 stored per character in characters.json, rolled once at first sight (two dice of -5..5) and never changed; the creation screen will send a chosen value later. `src/shared/luck.gd` turns a draw into a nudged one (`u` raised to exp(luck x strength)); the server wraps it as `roll_chance(peer, rng, p)`, `roll_amount(peer, rng, lo, hi)` and the `fate(peer, kind, p)` hook (counted by kind in `fate_counts`). Strength is 0.04 in data/items/luck.json (0 switches luck off): +10 luck takes a 50 percent chance to about 63 percent. Routed so far: plant yields, trunk branches, bark, seeds and roots. Which yield a plant bears, world layout and regrowth are exempt and marked `# luck-exempt: reason`; `python3 tools/check_luck.py` (part of items_check) fails on any other raw random draw in server code. Still to route when they exist: tool wear rolls, falls, combat and rare world events (through `fate`).

## Driftwood (job 71, 2026-10-21)

Water's bank query turned out not to be needed: the server's `water_near` (live water sim, else baked water) is the bank test. A new item, Driftwood (number 30, stack 20, 2 kg, plain material), lies along the banks: 12 percent of the bank spots in drops.json ground_scatter "bank" hold driftwood instead of a stone, using Dave's three driftwood meshes at stick size. It is dry fuel: 15 game minutes in a fire, after firewood and before sticks in the fuel order. Nothing else uses it yet.

## First-hour script (job 78)

`test_first_hour.gd` (in items_check as first_hour) plays a new character's first real hour on the server: gather by hand, hand-craft a stone axe, fell a tree and work the trunk, craft and place a campfire, get thirsty and drink at the water, twist twine, build a lean-to and a woven chest. Each step is asserted and the vitals curve is printed as "first hour:" lines (hunger and thirst percent, weight). At the data's numbers a full stomach is about 37 percent after 36 minutes of mixed work, and thirst falls about as fast as hunger.

## Inventory screen audit (job 82)

`_audit_text` (run by the texttest scenario) reads every visible control in the inventory window at the current text scale. Findings and fixes: tooltips used the engine's 16 px font, so the window's theme now sets TooltipLabel to the body size minus 6 (24 px at 1080); the vitals warning line was 22 px and is now 28 px. The check asserts the smallest font in the window is at least 24 px, tooltips at least 24 px, six sort options, and that the Split (S), Drop (D), Use (E) and Repair (R) buttons exist; CONTROLS.md lists them with Transfer (T), the Text -/+ buttons and the sort drop-down.

## Tools, hotbar, carry bar, fitness (2026-10-21)

- Hotbar: the first ten pack slots, keys 1 to 9 and 0, drawn as a strip along the bottom of the screen with the held slot lit. A slot's key holds it; the same key again puts it away (empty hands). Items go onto the hotbar by dragging them from the inventory or another slot (ACT_MOVE). Server and client both look for tools in those ten slots. Use (E) in the inventory on a tool, weapon or kit holds it; deeper in the pack it first moves into a free hotbar slot (or into the slot in hand). Slots are saved with the character because they are plain pack slots. First-person arms are a separate step (Art's rig has hand mounts).
- Over-exerted is a slow-down, not a stop: the pace drops 10 percent (exertion.json over_speed_factor 0.9), running continues and exertion keeps rising until the blackout threshold.
- Carry bar: carried weight against the gross weight you can carry (52 kg at 75 kg body weight), green, yellow from 70 percent, red from 80 percent of it. On the inventory screen under the weight text and on the Tab screen beside "Can carry".
- Fitness: a character attribute, -10 to +10 (0 average, new characters start at 0), stored in characters.json beside luck. The exertion rise per second is multiplied by exp(-fitness x 0.05) (data/items/fitness.json): +10 is about 61 percent of the normal rise, -10 about 165 percent. Recovery is untouched. server_items.set_fitness() is the hook for training, which is not designed yet. Protocol 26 sends it with vitals.

## First-person arms (2026-10-21)

held_item.gd puts Art's first-person arms (`Ragdoll.new(true)`) on the camera (ARMS_POS, ARMS_PITCH_DEG; hidden in third person via `set_first_person`). The held spear, axe, knife or torch is parented to `hand_mount_r`, the hand on the viewer's right (the rig's right is +X, naming fixed in build 354), with the grip at the mount origin and the tool tipped TOOL_TILT_DEG up. Left click plays swing (axe), jab (spear) and throw on the arms, timed to the existing hit timers; otherwise idle. Without arms the old offsets are used. Placeables and other kits are not drawn in the hand yet. The pose was checked in software-rendered stills (idle, jab, swing), not on a real GPU: ARMS_POS, ARMS_PITCH_DEG, TOOL_TILT_DEG and GRIP_ALONG_Y are the knobs.
