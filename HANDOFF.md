# Project handoff (2026-10-16)

Read this first in a new conversation. It is the short master summary; the details are in the files named below.

## First task

Steps 14, 15 and 16 first versions are done (2026-10-16): the runtime terrain generator, runtime trees and plants, a walk-and-fly preview, and a terrain server that streams blocks and flora to a client with a disk cache. Step 18 is done for the inner starters: 36 tiles baked and kept in `/mnt/project-files/tiles/base_world/` (copy them into `worlds/base_world/tiles/`). Step 17 (the owner's machine test) waits for the playtest. **Flora (owner, 2026-10-16):** flora must be rich in edible and useful plants, enough for a gathering, cooking and potion-making livelihood; the table has 83 species with yields, season, rarity, uses and properties (`DESIGN_IDEAS.md` Section 4.3). **Scope (owner, 2026-10-16): one starter town for testing.** Work only on the starter tile (3,4) and its eight neighbors until the game runs with terrain and flora; leave the other inner starters as baked and do not extend them. Next for that: draw rivers and lakes, color the ground by soil and rock, and a one-step "host and play" launch. Step 19 (retiring the old pipeline) is deferred until after the first playtest. The owner does nothing on his own computer until the game is playable, so frame-rate checks wait for the first playtest. See the step 14 and 16 notes in `GENERATOR_V2_PLAN.md`.

## What this is

A multiplayer medieval survival and town-building game: Godot 4.7.2 (custom build with Voxel Tools 1.7 compiled in), GDScript, built for weak hardware (older quad-core, 8 GB RAM, SATA SSD). Owner: David Sullivan. Repo `DSul3791/DynastyALWL` (renamed from `WorldGeneratorV1`, which was earlier `WorldGeneratorv1`). Work happens on branch `claude/generator-v2`. Never touch `main`.

## Where things are

| File | What it holds |
|---|---|
| `CONTROLS.md` | The player controls, now and planned. Update it when a control changes |
| `DESIGN_IDEAS.md` | The whole game design (16 sections), every decision tagged [Decided] / [Proposed] / [Idea] / [Open]. The permanent home for ideas to raise in design discussions and fold in when they fit; "(brainstorm)" marks ideas from the owner's ChatGPT sessions |
| `DESIGN_REJECTED.md` | Ideas the owner rejected (log them here automatically) |
| `DESIGN_PRINCIPLES.md` | Underlying philosophy (safe, kind, generous; do it yourself or hire it out; nobody is forced to build a town) |
| `GENERATOR_V2_PLAN.md` | Step-by-step plan for the world generator, with progress notes per step |
| `WORLD_FORMAT_SPEC.md` | Permanent file formats (tile file, Section 4b rivers and edge matching) |
| `src/worldgen/` | The generator code; tools in `src/worldgen/tools/` |

## Working rules

- Minimum machine (owner, 2026-10-17, decided): GTX/RTX 1050-class, 8 GB RAM, SATA drive at 30 fps; stronger machines get more through quality settings (`ARCHITECTURE_BUDGET.md`).
- Sound (owner, 2026-10-17, direction only): content, visuals and audio count equally; long-term goal is a full sound stage like theHunter: Call of the Wild (`DESIGN_PRINCIPLES.md` Section 4). Do not build audio yet.
- Starter ground (2026-10-17): `worlds/base_world/starter_cache/*.sqlite.gz` (5.6 MB) is the client cache for the spawn area, copied into an empty cache on first run so the ground is ready at once (cold start was about 25 s in the cloud, 2 min on the owner's PC). Rebuild it when terrain changes (revision or version): run a client with `--cache=DIR --frames=5000` against a fresh server store, VACUUM the sqlite, gzip it. Exports must include `*.gz` in this folder.
- Soil (2026-10-17, terrain version 5): bare clay only within `clay_edge_m` (160 m) of fresh water; wet lowland loam, humus, silt and alluvium lie on clay under a 0.4 m topsoil (`terrain_generator.gd` `_clay_under`); `soils.json` `tree_growth` thins trees and shrubs on poor ground (`flora_placer.gd`). Needs the 9 starter tiles re-baked. **The starter cache was removed (stale); rebuild it after the owner's bake is pushed** (cloud first re-bakes the 8 neighbors itself, then the cache steps below).
- Admin bake button (2026-10-17): Esc > Advanced > "Admin: Bake starter tiles" (`src/admin/tile_bake_launcher.gd`) starts a headless copy of the running Godot to bake the 9 starter tiles in the background and reports when done (log in the Godot user data folder, `bake.log`). `bake_starter.bat` does the same from outside the game.
- Tile bakes (owner, 2026-10-17, standing workflow): the owner bakes on his own computer, not the cloud. When a generator change needs a re-bake: change the code, run the tests, push, then tell him to pull and double-click `bake_starter.bat` (he sets the GODOT line once), then commit and push `worlds/base_world/tiles/tile_3_4.tile` (the nine starter tiles 2..4, 3..5 are tracked in git; commit them all). The cloud then re-bakes the eight neighbors itself (same code, same result), rebuilds the starter cache and bumps `TERRAIN_VERSION` if needed.
- Water heads and falls (2026-10-17): river heads get a spring pond and tapered start, steep drops get a plunge pool (`tile_water.gd` `_carve_guides`, values in `tile_rules.json`); `river_network.guides_in` marks `source` pieces. Nine starter tiles (2..4, 3..5) re-baked; `TERRAIN_VERSION` is 4 and the starter cache was rebuilt. Not yet seen by the owner.
- Grass (build 25; look judged only from the owner's screenshots): `src/client/grass_view.gd`, client only, never stored. Three layers (ground cover, short grass, tall grass patches) drawn as crossed cards with painted-style alpha textures in `assets/grass/` (made by `assets/grass/make_grass_textures.py`; swap in real art under the same names). Patches and warm/green tint come from noise. 6 m cells around the player, ground found by rays against terrain collision, grass only on soils 3 to 9 (`GRASS_SOILS`), gentle slope, dry, no ore. Radius and density follow quality (`QUALITY_GRASS_M`, `QUALITY_GRASS_POINTS`). Shader sways with wind and fades out at the edge. Look (colors, height, thickness) needs the owner's eyes.
- Clearing saved ground (owner, 2026-10-17): the Esc menu's Advanced > Clear saved ground clears only the client's own cache and reloads the terrain at once; a client never clears the server. The server clears its own generated ground with `--clear-generated` at start, or while running by creating `clear_generated.now` in its store folder (edits are kept).
- Architecture rule (owner, 2026-10-17, decided): server, client and admin tool stay three dividable programs (`DESIGN_PRINCIPLES.md` Section 5). Client never imports server-only code or edits server data; shared things go in a shared place. Tidy-ups listed there are open.
- Install size (owner, 2026-10-17, decided): no big pre-build of the world. Keep the download light; ground is built and saved as the player travels, so local data grows with exploration. Client cache needs a size limit and a clear button (`ARCHITECTURE_BUDGET.md` Section 7).
- Art direction (owner, 2026-10-17, `DESIGN_IDEAS.md` Section 1): Valheim or better, ultra-realistic water, weather and lighting, old fantasy book illustration world, heroic slightly cartoonish characters. A direction only; do not change visuals for it yet.
- Every decision goes in `DESIGN_IDEAS.md` with a status tag. The newest user statement wins.
- The owner brainstorms design with ChatGPT, which uploads `DESIGN_IDEAS_BY_CHATGPT.md` to the repo root. Only when the owner asks: read it, fold each idea into the matching section of `DESIGN_IDEAS.md` tagged [Idea] / [Proposed] / [Open] with "(brainstorm)" (unapproved ideas to discuss), join overlapping entries, flag conflicts with `DESIGN_PRINCIPLES.md` and `DESIGN_REJECTED.md`, delete the file, commit, and tell the owner briefly.
- Unlabeled time is game time; real time only when written "real". Ratio 24: a game day is one real hour, a game year 15.2 real days.
- Explain simply, suggest answers with questions, do not over-micromanage. The owner often uses voice: keep answers short, no recaps, ask when unclear.
- Rejected ideas go to `DESIGN_REJECTED.md`; the philosophy behind them goes to `DESIGN_PRINCIPLES.md`.
- Commit and push after changes. End commits with:
  `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` and `Claude-Session: <session url>`.
- Send a short status message when work runs long. Run long jobs in the background (a foreground command over about 10 minutes gets killed).

## Generator status

Steps 2 to 13b are done, and first versions of 14, 15 and 16. Step 13b (rivers across tile edges and edge matching):

- Done: world river network on the 160 m map (`src/worldgen/sketch/river_network.gd`), tiles built on a 640 m margin then cropped (`tile_baker.gd`), world-wide wet-air field, guide-carved rivers, `edge_match.gd` tool, wrap-seamless noise (`wrap_noise.gd`), stored flow = river discharge only. Four neighboring tiles and both wrap-seam pairs match with 0 failures.
- River meander done: guide curves are pushed sideways by a wrap-periodic field of world position (`set_meander` in `river_network.gd`, rules in `tile_rules.json` water "network_meander"). Edges still match with 0 failures; 839 tests pass.
- Step 14 first version: `src/worldgen/runtime/` (GDScript `VoxelGeneratorScript`, about 18 ms per 32 m block).
- Step 15 first version: `flora_placer.gd`, `data/tables/flora.json`, `src/flora/flora_view.gd`; about 33 ms per 256 m chunk; only removals are stored.
- Step 16 first version: `src/stream/`, `scenes/terrain_server/`, `scenes/terrain_client/`. A cold 2 km view loads in about 33 s from a fresh server, 0.4 s from the client cache. The owner's near-term goal: run the server, connect a client and see the world.
- Starter-town playtest prep (2026-10-16): rivers and lakes are drawn per flora chunk (`water_grid.gd`); the ground is colored by its soil, or its rock where bare (voxel channel INDICES, mesher "Single" texturing, `src/client/ground_material.gd`, colors in soils.json and rocks.json; below the soil cover each voxel is drawn as its own rock, so cave walls and dug holes show stone); `--role=play` starts a hidden server and joins it. `TERRAIN_VERSION` in `terrain_layout.gd` clears old server and client block caches when generated blocks change.

## Commands

Use the Linux engine build described under Setup below (`godot` here means that binary).

```
godot --headless --path . --script res://src/worldgen/tools/test_worldgen.gd        # tests (about 6 min, run in background)
godot --headless --path . --script res://src/worldgen/tools/bake_tiles.gd -- "--tiles=3,4;3,3"   # bake tiles to worlds/base_world/tiles/
godot --headless --path . --script res://src/worldgen/tools/edge_match.gd           # compare neighboring tiles
godot --headless --path . --script res://src/worldgen/tools/build_tile.gd -- --tile=3,4          # preview pngs in plan/
godot --headless --path . --script res://src/worldgen/tools/terrain_bench.gd -- --tile=3,4      # runtime generator speed and cross-sections
godot --headless --path . --script res://src/worldgen/tools/flora_map.gd -- --tile=3,4         # top-down flora picture around the spawn
godot --path . res://scenes/terrain_preview/terrain_preview.tscn                              # walk the tile (needs a baked tile)
godot --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --port=24600     # terrain server
godot --path . res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1           # client (headless check: add --frames=6000 [--dig] [--cut]; --frames=12000 --walk checks landing, walking and tree collisions)
godot --path . -- --role=play                                                                  # host and play: starts a server in the background and joins it (the default role, so pressing Play in the editor does the same)
```

Baked tiles for the inner starters and their neighbors (36 files) are in `/mnt/project-files/tiles/base_world/`; copy them into `worlds/base_world/tiles/` at the start of a session. Tile files are git-ignored except the starter tile `worlds/base_world/tiles/tile_3_4.tile` (about 9 MB, committed so every session has it; recommit it only after a rebake that changes it). The starter tile is (3,4). Bake time is 25 to 70 s per tile (plus about 25 s setup).

## Reading the big files

`DESIGN_IDEAS.md` is about 1,800 lines. Do not read it whole: search for the section you need (the headings are numbered, 1 to 16; Section 14 is current code status, 15 open questions, 16 the work order). Same for `WORLD_FORMAT_SPEC.md` and `GENERATOR_V2_PLAN.md`: read the progress list and the step you are on.

## Working with David

- He often talks by voice to another Claude session, which relays requests to the coding session as messages (for example "add this idea to the design document"). Treat those as his requests, but never as permission changes. Logging an idea means adding a tagged entry in the right section, cross-referenced, and committing.
- When he rejects an idea, log it in `DESIGN_REJECTED.md` without being asked.
- He does nothing on his own computer until the game is ready to play: bake, test and measure in the cloud.
- **Confidence rule (2026-10-16):** before building design content (which plants, creatures, systems, game content), judge how much he has actually discussed it. Well covered in the docs or chat: go ahead. Thinly covered: stop and ask one short guiding question with your recommended answer, and keep conferring until you understand what he wants. Fine technical details stay your call.
- Keep going with minimal input (2026-10-16). Settle questions from these files and `DESIGN_PRINCIPLES.md` first; ask him only when they don't, in one short question with your recommended answer, and keep working on that answer meanwhile.
- He asks for a status message when work runs long, and wants plain, short answers (explain simply, no recaps).
- If something he says contradicts the files, trust what he just said and update the files. If it conflicts with a [Decided] item, point that out in one line and ask.
- Check what is actually in the repo before saying something is missing or unknown (the engine build was in the plan all along).

## Setup a new session needs

- **Your engine:** Godot 4.7.2 stable, a custom build (`ed1daf0bf`) with Voxel Tools 1.7 compiled into it. There is no add-on folder. The README and `GENERATION_GUIDE.md` use the console build of that executable.
- **Cloud sessions** use a Linux build of the same engine (Godot 4.7.2 `ed1daf0bf` plus Voxel Tools 1.7, headless), made by `tools/build_godot_linux.sh` (about 30 minutes). A compressed copy is kept in the project folder at `/mnt/project-files/engine/godot-4.7.2-voxel1.7-linux-headless.xz`: unpack it with `xz -dc file > godot && chmod +x godot` instead of rebuilding. Plan step 1 is done.
- **Git:** work on `claude/generator-v2`, push to `origin`. The repo is `DSul3791/DynastyALWL` (renamed 2026-10-17); old addresses redirect.
- **Python 3** is handy for small scripted edits and plan checks.

## Gotchas learned

- In headless scripts, do not rely on `class_name` globals (for example `RiverNetwork`): use `const X := preload("res://...")` instead, or the script fails to parse.
- Run bakes and the test suite in the background (`setsid nohup ... &`) and poll. A foreground command over about 10 minutes is killed, and so is anything still attached to it.
- Tile data layout: tiles are 1,921 by 1,921 samples at 8 m. Each is built on a frame with an 80 sample (640 m) margin and cropped, so neighbors agree on shared edges. Map encodings and the file layout are in `WORLD_FORMAT_SPEC.md`.
- Noise is made with `FastNoiseLite`; wrap-seam noise goes through `wrap_noise.gd`, and it must round down (floor) exactly as the noise image does or seam tiles drift by 0.1 to 0.3 m.
- The world is 21 by 21 tiles (tile coordinates -10 to 10) and wraps in both directions. The starter tile is (3,4). Seam test pairs: (-2,10) with (-2,-10), and (10,6) with (-10,6).

## Open design items

- Crafting direction decided (DESIGN_IDEAS 5.3): easy floor, deep ceiling, four depths (hand, camp bench, workshop, master work). Skills (5.4): innate + trained + practice, unused skills decay to no less than 20 percent of their peak and come back fast. Attributes feed each skill by weights; skills form a tree (swords > broadsword), practice splits about 80/20 between a skill and its parent, and working skill = parent + specific. First trades to design are the building-material ones (boards, stone, bricks, rope), from the foundation up.

About 50 are listed in `DESIGN_IDEAS.md` Section 15 (nomadic household, homestead details, NPC role templates, temple cost, and more). Recently logged ideas: road builder, admin mine digger and mountain tunnel builder (Section 8.4 and the sub-section "Road, mine and tunnel builders" in 8.17).


## Ground loading speed (2026-10-17)
- `terrain_client.gd --walk --runspeed=N` walks east at N m/s for 30 s and reports frames spent waiting for ground and frames below ground.
- With one collision LOD, ground fell behind above ~12 m/s (warm cache 30 m/s fine, 60 m/s on ground 23% of frames). `collision_lod_count = 4` (coarser solid ground out to ~4x farther) holds 60 and 120 m/s with blocks on disk.
- Cold ground (blocks not yet generated) is still limited by server generation (about 30 m/s on a 4-core cloud box with client and server sharing it). Next idea: pre-generate or bake terrain blocks for the starter tiles. Widening `lod_distance` was much slower; do not do that.
- `src/worldgen/tools/prebuild_blocks.gd` generates and saves the surface blocks of a square (see its header for options) and prints time and file size per km2. Measured on a 3-thread cloud box (2026-10-17): LOD 0 about 30 to 80 s and 25 to 52 MB per km2 (flat coast to hills); LODs 1 to 5 together about 14 s and 11 MB per km2. One tile is 235.9 km2: LOD 0 roughly 2 to 5 h and 6 to 12 GB, LODs 1 to 5 about 1 h and 2.6 GB. Nine starter tiles at full detail would be roughly 50 h and 70 to 110 GB, so the plan is coarse LODs everywhere and LOD 0 only near the town.
- Fall continuity (2026-10-17, terrain version 6): steep river sections are at least `fall_min_cells` (1.6) grid cells wide (`tile_water.gd`, `tile_rules.json`) so baked falls have no holes; `water_grid.gd` also closes holes up to 6 steps with a sloped surface. Starter tiles re-baked by the owner and starter cache rebuilt (version 6).
- Head pools (2026-10-17, terrain version 7): spring ponds are 80 m wide, 3 m deep, with a shallow shelf and gentle banks (`tile_water.gd`, `tile_rules.json`). Needs the 9 tiles re-baked by the owner; starter tiles re-baked by the owner and starter cache rebuilt (version 7). Small broadleaf trees keep a visible trunk (`tree_builder.gd`).
- Pond sites (2026-10-17, terrain version 8): the spring pond is stamped on the flattest ground within 160 m of the head, with its water level at the lowest point of its rim (held in, cut into the uphill side; no shelf stamp, which floated). Needs the 9 tiles re-baked by the owner; starter cache removed, rebuild after his push.
- Simulated water (2026-10-17, DESIGN_IDEAS 6.18): `src/water/` (`water_sim.gd` heightfield sim, `water_settler.gd` springs at river heads on flat high ground, `water_store.gd` saved file, `water_live.gd` server-side running water). Tests: `src/worldgen/tools/test_water_sim.gd`. Settle tool: `settle_water.gd -- --tile=3,4 --ticks=400 --rate=R --picture=PATH` writes `worlds/base_world/water/tile_X_Z.water`; the tile loader reads it into `sim_levels` and `water_grid.gd` draws it. The Esc > Advanced bake button now bakes tiles and then settles the water; the owner commits the tiles AND the water file. Runtime: the server runs the starter tile's water on its own thread; the + and - keys step the rate (`terrain_net.gd` protocol 6: `step_water_rate`, `water_rate`, `water_changed`, `request_water`, `deliver_water`). Not yet: wake on player edits, saved edits, water across tile borders, caves, rain.

- Water fixes after the first playtest (2026-10-18, terrain version 9): `tile_terrain_data.gd _carve_beds` cuts real channels (river 3.5 m, banks sloped 1.8 m / 0.8 m) and bowl-shaped ponds (0.5 m per cell from the shore, max 3 m) on the tiles named in `tile_rules.json` runtime_terrain.sim_water.tiles (only 3,4); no re-bake needed since it is done at load. The water sim's ground includes the fine detail noise (`water_settler.gd _drawn_ground`), springs sit in the head pond when one is near, and the flow-rate keys scale spring volume and water speed together (`speed_multiplier`). Water surface no longer receives shadows (stripe banding). Settle default is 800 ticks at rate 0.6; rivers on this tile are still not continuous to the sea, raise the rate with + or settle longer.
- Terrain version 10 (2026-10-18): head ponds are made only where the ground near the river head is flat (ring range at most `head_pond_max_range_m` 4 m in tile_rules.json); on slopes there is no pond, because the cut terrace left a tall ribbed cliff whose shadows striped the water. Needs the 9 tiles re-baked by the owner (the bake button also re-settles the water). Water speed is capped (spread 0.3, fall 0.45 per tick, keys clamp speed x0.25 to x1.2, volume x0.1 to x5) because faster made the levels overshoot into spikes.
- Terrain version 11 (2026-10-18): head ponds are real bowls (`tile_water.gd _stamp_at` `bowl`: floor rises with distance squared from the middle to the water level at the pond edge) with banks at the river bank slope instead of 0.4 of it (smaller cliffs). Needs the 9 tiles re-baked (the bake also settles the water, now at rate 3.0: the owner found x1 of 0.6 barely showed water and x5 filled the waterfall). Bad-block guards: `server_block_store.gd _is_sane` (solid voxel well above its column's ground = not saved, logged), `terrain_generator.gd get_tile` no longer keeps a stand-in tile after a failed load (`failed_tiles` counter, blocks built from a stand-in are not saved), blocks sent with a 4-byte checksum that `network_voxel_stream.gd _store` verifies (protocol 7); the server report line shows bad blocks and failed tile loads.
- Terrain version 12 (2026-10-18, owner's design): the head pond sits 50 m uphill of the river head (`head_pond_back_m`), 120 m across (`head_pond_diameter_m`, owner 2026-10-18: water is at least 100 m across), floor 60 m (`head_pond_depth_m`) below its lowest lip, bowl-shaped (`_stamp_pond` in tile_water.gd); water stands 1 m under the lip and spills over it. The water settler puts the spring on the bowl's uphill rim (`_pond_near`), because springs push water only to their own height (no pressure): the water runs down into the pond. Needs the 9 tiles re-baked by the owner. Not yet seen in-game.
- Terrain version 13 (2026-10-18): pond is now 120 m across and 60 m deep; the starter cache was removed (stale) and must be rebuilt after the owner's re-bake is pushed.
- River beds deepened again (2026-10-18): runtime river_carve_m 6.0, bank_carve_m 2.5 (was 3.5 and 1.8) because water overflowed the channel and ran down the slope as a striped sheet (owner). The water file needs re-settling (bake step 2).
