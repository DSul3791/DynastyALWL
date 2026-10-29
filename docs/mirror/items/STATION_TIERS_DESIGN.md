# Crafting stations beyond the camp bench (design note, no code)

Built so far (builds 435 and 438, protocols 41 and 43): a recipe may name a `station` and a `station_level`. A station is a placed structure with `station`, `reach_m` and `station_level` (structures.json). Its level is 1 plus the number of different add-on kinds (`addon_of`) within `addon_reach_m`. The server checks the reach (+1 m); a station craft waits while you are away. Camp bench: level 1 bare, 2 with a tool rack or vice, 3 with both. Backpack, plank chest and hide cloak need level 2 today.

DESIGN_IDEAS 5.3 has four depths: hand, camp bench, workshop (smithy, apothecary, kitchen) and master work. Tyler's rule for gating: gate only what physically needs the station, keep the simplest things in the hand, show greyed recipes so players know what to build.

## Stations, what each gates, and its levels
| Station | Needs to build | Level 1 | Level 2 (add-ons) | Level 3 |
|---|---|---|---|---|
| Camp bench (built) | sticks, cordage | stone spade, tool kits | tool rack, vice: backpack, hide cloak, plank chest, hafted heads | plank stack: planks, tool handles, nets, fish traps |
| Saw mill | lumber, stone, iron | lumber from logs (4 per log), planks | water wheel or a second saw: beams, long planks | frames for buildings |
| Drying rack | sticks, cordage | dried herbs and fish (spoilage x4 or more) | smoke hut: smoked meat and fish (weeks) | salting barrel |
| Kiln | clay, stone | fired clay pot, brick | bigger kiln: tiles, glazed pots | |
| Tannery (frame and pit) | stakes, bark, a pit | scraped hide to rawhide | tanning bath (oak bark): leather | oiled leather, boots and armour |
| Loom | planks, cordage | woven cloth from fibre | wool cloth | linen, wool cloak |
| Forge | stone, clay, bellows | knives and arrow heads from iron ingots | anvil: tools, pickaxes | steel, swords |
| Kitchen oven | brick, clay | bread, pies | | |

Order I would build in: drying rack (needs nothing new and keeps the fish), saw mill (planks unlock bench level 3), kiln, tannery (needs hunting), forge and smelting (needs ore chain), loom last.

## Rules that stay
- Stations are structures with an `owner` (ownership and locking come with the town system); a per-player cap of 4 per kind keeps the world clean.
- Add-ons are placed within 5 m; they do not have to touch.
- Repairs of carried items never need a station.
- Upgrading is placing add-ons, not a menu; level numbers are data in structures.json and recipes.json.
- Speed bonuses (a better station crafts faster) are possible later; the main use is unlocking recipes.

## Decided by Dave (2026-10-21): four placeable tiers
Every station is placeable, in four sizes: small, medium, large, epic. Epic can be a whole predesigned building with its add-ons already in it. Look: this is a fantasy game, so medieval stone and iron work, or log and timber work. Nothing modern.

| Tier | Built | Gives | Make it from | Make it at |
|---|---|---|---|---|
| Small | Camp bench | workbench 1 (add a rack and a vice beside it for 2 and 3) | 12 sticks, 3 cordage | by hand |
| Medium | Log workbench (rack and vice built in) | workbench 2 | 4 logs, 6 cordage, 6 sticks | camp bench |
| Large | Stone forge (hearth, anvil block, bellows, bench) | workbench 3 and forge 1 | 36 stone, 10 clay, 2 hides | workbench 2 |
| Epic | Blacksmithy (stone walls, timber frame and roof, forge, anvil, quench trough, long bench, rack, vice) | workbench 4 and forge 2 (steel), and a roof you can shelter and respawn under | 30 stone, 10 logs, 10 clay | workbench 3 |

How it works: one structure can carry several stations (`also` in structures.json), so the forge and bench are one thing. Add-ons still raise a bench, so a lone character has a cheaper path. The kits weigh 30, 45 and 40 kg (placeholder: the heavy parts are delivered where it is raised; a 70 kg body carries about 49 kg, so the stone forge is a real hauling job). Steel pickaxe now needs forge 2. Caps per chunk: 3, 2, 1. No iron is needed to build any of them, so a new player can reach all four.

Still to come on the same pattern: saw mill, drying rack, kiln, tannery and loom as small, medium, large, epic variants; town workshops later give speed.

## Look notes for Mandy (placeholder boxes exist; swap for finished models)
- Log workbench: hewn plank top on two log trestles, peg rack on posts at the back, wooden vice at one end. About 2 by 1 m.
- Stone forge: dry-laid stone hearth with a hooded stone chimney, anvil block on a tree stump, leather-and-wood bellows, a plank bench alongside. About 3.2 by 2 m.
- Blacksmithy: open-fronted hall about 6 by 5 m and 3.2 m to the ridge. Fieldstone plinth, stone back and left walls, thick timber posts and beams, pitched plank roof, forge and tall chimney in the back wall, anvil on a stump in the middle, quench trough of stone, a long bench with rack and vice at the front. Iron only for the anvil, tools and fittings.
- Smoke and glow from the forge are worth having when it is lit (later).


## Option for tier 4 (Dave 2026-10-21): a better forge instead of a roofed building (prepared, no code changed)
- Name: Masonry forge (item masonry_forge_kit, structure masonry_forge, state 18 reused, so saves and the protocol stay as they are).
- Look (Mandy): stone hearth with a tall stone chimney stack, iron anvil on a log block beside it, leather bellows, wooden quench trough. Medieval stone and iron, no roof, no walls.
- Size: footprint 4.2 x 3.0 m (was 6 x 5), reach 6 m, cap 1 per chunk; delete half_x, half_z, height and "shelter": true (no cover roof, so no weather shelter, a plain open yard forge).
- Tier rules unchanged: station_level 4 (workbench), also forge 2, tier "epic".
- Recipe unchanged (stone, log, clay); it only gets renamed. The test set and Admin list entry follow the new id.
- Work for the change: structures.json, items.json (name, description), recipes.json rename, held_item kit model, inventory_view look (_make_smithy swaps its roof/walls for chimney, anvil, trough), stations test. One build, no protocol bump.


## Four forge tiers from Dave's pictures (2026-10-21), APPROVED by Steve and built in 477 (protocol 50)
Camp bench (workbench 1) and Log workbench (workbench 2) stay exactly as they are. The forge line becomes four forges named as in Dave's pictures. Internal ids never change, so saves are safe.

| New name | Look (Dave) | Station levels | Current id it takes over | Footprint (m, x z) and height | Reach | Kit recipe (hand craft at a Log workbench or better) |
|---|---|---|---|---|---|---|
| Basic Forge | clay and rough stone dome, small log lean-to roof | workbench 3, forge 1 | stone_forge / stone_forge_kit (item numbers unchanged) | 2.4 x 2.0, 2.6 high | 5 | stone, clay, hide (as now) |
| Medium Forge | dressed stone, stepped hood, iron straps | workbench 4, forge 2 | blacksmithy / blacksmithy_kit (the Masonry forge, numbers 89 and 90) | 3.2 x 2.2, 3.0 high | 5 | 30 stone, 10 log, 10 clay (as now) |
| Large Forge | big arched hearth, riveted iron frame, brick-lined firebox | workbench 4, forge 3 | NEW id large_forge (next free item numbers) | 3.8 x 2.6, 3.4 high | 6 | 40 stone, 20 clay, 6 iron bars once metals exist; admin list only until then |
| Master Forge | ornate black iron and gold, red gems, glowing | workbench 4, forge 4 | NEW id master_forge | 4.6 x 3.0, 4.2 high | 6 | late-game, admin list only; recipe when gems and gold exist |

Notes. The Basic Forge's lean-to roof is part of its look only (no weather shelter; shelter stays a lean-to job). Forge level already works as "this level or higher" (steel needs forge 2), so recipes that need forge 3 or 4 can come later with no code change. Old placed stone forges and masonry forges keep working and just take the new names and meshes. Both new tiers are added to the Admin build list at once.

### How Dave's meshes plug in
- File: glTF binary (.glb), one file per forge, in assets/stations/forge_basic.glb, forge_medium.glb, forge_large.glb, forge_master.glb. Textures embedded or next to the file (PNG, power-of-two sides up to 2048).
- Scale: 1 unit = 1 metre, real size as in the table above (Y up). Pivot at the centre of the footprint on the ground (feet at y 0). The front (the fire opening) faces -Z in Godot, so a forge placed with yaw 0 opens toward -Z.
- Parts: one mesh per material is fine; name a node `Fire` at the firebox (an empty marks where the flame, sparks and warm light go, the game adds them so it can turn them off at Low), and optional `Glow` surfaces with an emissive material (Master gems). No lights, cameras or animations in the file.
- Cost budget (Steve, at Low): at most 6000 triangles each, textures at most 1024 px, one draw (two with a glow material), emissive glow only, no real light in the file (the game adds the flame light inside its nearby-fire cap), no shadow casting. Mandy checks the meshes before they are wired.
- Collision: the game builds its own box from the footprint in structures.json (footprint_x, footprint_z), you do not model collision. Keep the visible stone inside that box plus 0.2 m.
- Wiring (my part, after your files arrive and Steve agrees): `_make_forge` and `_make_smithy` in src/client/inventory_view.gd load the glb for their id and fall back to today's box models if the file is missing; the held kit stays the rolled plan.


### Dave's real meshes (installed 2026-10-21, build 484)
Measured from the files: they are Z up with the fire opening toward -Y and the footprint centre off the origin, so the loader (inventory_view.gd `_forge_glb`) stands them up, turns the opening toward -Z, centres the footprint on the pivot with the base on the ground and takes the flame light and smoke from the Fire and Smoke empties. Sizes (width x height x depth, m): Basic 2.94 x 3.20 x 2.40, Medium 3.32 x 3.61 x 2.61, Large 4.31 x 4.02 x 3.09, Master 4.88 x 4.32 x 3.24; footprints in structures.json now match (3.0 x 2.4, 3.4 x 2.7, 4.4 x 3.1, 4.9 x 3.3). Triangles: Basic 8076, Medium 7300, Large 15860, Master 16108, so all four are over Steve's 6000 budget at Low (Large and Master by a lot); textures about 0.5 to 0.75 MB PNG each, 22 PNG files. Mandy and Steve to decide: decimate in Blender, or accept for the admin-only Large and Master.

Decision (coordinator, 2026-10-21 19:20): accept Dave's meshes as delivered (8k, 7.3k, 16k, 16k triangles); do not decimate his art. If the cost shows in the probe table at Ultra we revisit; for Low and Medium Mandy adds a simpler distance version (LOD) later. This replaces the 6000 triangle budget for these four forges.
