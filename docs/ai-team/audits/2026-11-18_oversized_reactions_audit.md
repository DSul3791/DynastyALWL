# Audit: small actions with oversized reactions (18 Nov 2026)

Report only (ponytail-audit, `docs/PONYTAIL_RULES.md`). No game code changed. Findings are backlog proposals for Dave to pick from. Each finding now also has a research block (added 18 Nov 2026 at Dave's request): how reputable games solved the same problem, with sources, and the pick for Dynasty judged by what it gives the player. Nothing gets built until Dave decides.

- **Audited:** `origin/dev` at `e8a0cce879e9b881de9f92a0f3f447deac55de1b` (other threads were changing dev at the time; line numbers are for this SHA).
- **Asked for by:** Dave, 18 Nov 2026, after the terrain wall by the stream: "We should be checking our entire project for logic mistakes like this."
- **The class of mistake:** a small local action (one dig, one pickup, one pipe) that sets off work sized to something huge (a 15 km tile, every item in the world, every player), or a repeating cost that grows with world size or session length instead of with the size of the change.
- **Measured:** nothing. Godot does not run in the cloud. Every cost below is read from the code; the scale ones are `unmeasured risk` with the trigger named. A soak run on a lane (world with about 20,000 items, timing the slow tick and the 30 s save) would settle findings 2 and 3.

What this area does: the server (`scenes/terrain_server/terrain_server.gd`, `src/stream/`) owns ground edits, world items, saves, water and animals; clients (`scenes/terrain_client/terrain_client.gd`, `src/client/`, `src/flora/`) cache ground blocks per tile and draw what the server sends. Load assumed: one shared server running for weeks, a few to 20 players, a built-up world with roads, bases and dropped items (there is no item cap: Dave 16 Nov "there should be no limit", boulders unlimited 17 Nov).

## Must fix

### 1. Rejoining throws away the whole saved island ground after any dig (`src/stream/client_block_cache.gd:148`)
- **What this is:** each client keeps one ground file per 15 km tile, named by the tile's revision (`tile_X_Z_rN.sqlite`, `:321`). At the join the server sends every tile's revision (`terrain_server.gd:969`) and `set_revisions` deletes any file whose revision differs.
- **Problem:** every dig, fill, hoe stroke or road piece raises the tile revision (`server_block_store.gd:633`). Today's fix (`0359cf13`, `forget_area` at `:179`) stops the in-session wipe, but the file name never advances, so at the **next join** the whole tile file is deleted and every block round the player is fetched again. Any edit by anyone on the tile counts, including your own from last session. This is the same symptom Dave saw (ground missing for minutes), moved to the join.
- **Fix (S to M):** at the join, send the edit spheres made since the client's revision (the edit log `ground_ops.gd` already numbers edits; it needs a per-tile revision-to-sequence map, since revisions count per tile and the log counts for the whole world) and forget only those areas, then rename the file to the current revision. Fall back to the whole-tile wipe only when the gap is too large or a re-bake changed the tile stamp. Belongs with the terrain thread ("Fix terrain wall by the stream").
- **If we skip it:** every join after any building or digging reloads the island's ground from scratch.
- **How others solved it:**
  - [Minecraft Bedrock client blob cache (Mojang)](https://gist.github.com/Tomcc/4be79d3eafcd158c5059abd4ab2e8d35): every 16 m cube of ground is named by a hash of its contents. On join the server sends only the hashes, the client says which ones it already holds, and only the missing cubes are sent. A client keeps its cubes between sessions, and even between servers.
  - Catch-up from an edit log, which is what PR #1253 builds: the server keeps a numbered log of digs and fills, and a returning client asks for "everything on my tile since revision N" and reloads only those spots. A full wipe happens only for a re-bake or a reset.
- **Pick for Dynasty: PR #1253's catch-up log, now.** It uses the edit log the server already keeps, and a returning player reloads only the spots dug while they were away. The Bedrock hash cache is the stronger long-term design (it would also spare a re-download after a re-bake that leaves most ground unchanged), but it is a new cache and protocol. Worth revisiting only if re-bakes keep making players wait.

### 2. Every save rewrites the whole world on the server's main thread (`src/stream/server_items.gd:1562`)
- **What this is:** every 30 s (`SAVE_EVERY_S`, `:49`) `save()` runs if `_dirty` is set.
- **Problem:** there is one `_dirty` flag for everything (`_dirty = true` appears about 200 times). One pickup, one item ageing out or one moved log makes the next save turn every inventory, world item, chest, tree, character, crop, light, kiln, smelter and smithy into JSON on the tick (`_write_atomic`, `:6197`: "the snapshot is taken now, on the tick"; only the disk write is in the background). A 675 ms save in one tick was already logged on 5 Nov. The cost grows with everything ever built or dropped.
- **Fix (M):** one dirty flag per file, so a pickup saves `inventories.json` only; world items and chests only when they changed. Later, world items as SQLite rows (only changed rows written).
- **If we skip it:** a server freeze every 30 s that every player feels as a hitch, longer each week the world is played.
- **How others solved it:**
  - Factorio pauses the whole game for every autosave. Its fix was [Factorio non-blocking save](https://forums.factorio.com/viewtopic.php?p=341647): the game copies itself (fork) and the copy writes the save while play goes on. It is only on Linux and Mac, still marked experimental, and players report crashes. A whole-world snapshot stays expensive however it is moved.
  - Minecraft keeps the world in [Minecraft region file format](https://minecraft.fandom.com/wiki/Region_file_format): each 16 m chunk has its own slot and its own "last changed" time, so one chunk can be written without touching the rest. [Paper incremental chunk saving](https://ayakael.net/mirrors/papermc/commit/6f2c8a6449ab611291af948092fa692e88e75c0d) goes further, writing only chunks not saved recently, at most 24 per tick, spread over many ticks, so no single moment freezes.
- **Pick for Dynasty: the Minecraft and Paper way.** Keep world items in areas (for example the existing 100 m sync cells) and save only the areas that changed, a few per tick. A save then costs the size of what changed, not the size of the world, so the hitch disappears for good. This changes the save format. Dynasty is a new game with no migration needed, but it needs Dave's yes. The contained step that could ship first (and is written but not pushed) moves the JSON work off the server's main loop. That shortens the freeze, but it does not stop its growth.

### 3. The server's quarter-second tick walks every item in the world many times (`src/stream/server_items.gd:1453`)
- **What this is:** the slow tick runs every 0.25 s (`SLOW_TICK_S`, `:386`).
- **Problem:** each pass loops over every world item to find a few: `_fires` (`:4988`, copies all keys, plus `_refresh_pots` `:8627` two more full passes), `_lights_tick` (`:17176`, copies all keys), `_expire_items` (`:5063`, copies all keys). That is about 6 full passes every 0.25 s. On top: `_sync_world_items` (`:5703`) and the scatter clean-up (`:6325`) every second, and `_on_path` (`:13127`) once a second per player. The item count has no cap and grows with play: a road leaves a `path_patch` item every 0.7 m (`PATH_SPACING_M`, `:3379`), loose stones and sticks are laid out within 96 m of each player and kept to 250 m, dropped items have no limit. 20,000 items means roughly half a million dictionary visits a second before any real work. `unmeasured risk`.
- **Fix (M):** keep small id sets per kind (fires, lights, items that expire, path patches, pots), updated where items are added and erased; near-a-point questions read the `_sync_grid` (`:227`) that already exists.
- **If we skip it:** server lag for everyone that grows with how much the world holds, with no single action to blame.
- **How others solved it:**
  - Factorio runs `update()` only on "each active entity each tick" ([Factorio developer Rseding91 on active entities](https://forums.factorio.com/viewtopic.php?p=228959)). Entities with nothing to do are left off the update list, so a huge base of idle chests costs nothing per tick.
  - [Factorio Friday Facts #271, fluid systems](https://cf-www.factorio.com/blog/post/fff-271): fluids moved into their own manager, so machines connected to pipes "no longer need to update every tick just for pipe flow". Pipe updates got about 6.5 times faster on a heavy map.
- **Pick for Dynasty: Factorio's active lists.** Keep a short list per job (burning fires, lit lights, pots) that changes only when one is lit, put out, placed or removed. For things that age, store the moment they expire and look only at the next one due, rather than counting every item down 4 times a second. Each tick then costs what is actually happening, so a big built-up world plays as smoothly as a new one.

## Should fix

### 4. Building a road makes the whole world sync four times as often (`src/stream/server_items.gd:3880`)
- **Problem:** while one player's road builds, `_sync_in = minf(_sync_in, ROAD_SYNC_S)` runs the full world sync (grid of every item, every player's nearby list and signatures) every 0.25 s instead of every 1 s, for everyone. Each station (`_road_station`, `:4071`) also loops over every world item, as does each hoe path stroke (`_hoe_path`, `:3413`).
- **Fix (S):** push the road's new pieces straight to the players near the road and leave the 1 s sync alone; station checks use the grid.
- **If we skip it:** road building gets slower and laggier for everyone as the world fills; it is the action Dave was doing when the ground went missing.
- **How others solved it:**
  - [Unreal Engine Replication Graph (Fortnite)](https://docs.unrealengine.com/4.27/InteractiveExperiences/Networking/ReplicationGraph): Fortnite has about 100 players and 50,000 replicated actors. Checking every actor against every player stalled the server, so actors are filed into grid cells and each player is served from the cell they are in ([Unreal grid spatialization node](https://dev.epicgames.com/documentation/unreal-engine/API/Plugins/ReplicationGraph/UReplicationGraphNode_GridSpatia-?lang=en-US)).
  - Minecraft sends block changes for a chunk section in one batch, only to players who have that chunk loaded ([Paper multi block change](https://ayakael.net/mirrors/papermc/src/commit/5f0932b6c8ac9a3c900075fc40f77b506c63ed82/patches/server/0647-Multi-Block-Change-API-Implementation.patch)).
- **Pick for Dynasty: the Replication Graph grid.** A new road piece is pushed straight away only to players near the road, and the world sync for everyone else stays at once a second. The road builder sees the road appear just as quickly, and nobody else pays for it.

### 5. Placing one pipe or channel rebuilds the water network of the whole world (`src/stream/server_items.gd:16178`)
- **Problem:** once any piece with ports exists anywhere (`_water_has_ports`, `:16050`), every new water piece calls `_water_relink` (`:16071`), which rebuilds the network from all pieces. Each `WaterNetwork.add` compares the new piece with every piece (`water_network.gd:177`, `:187`), so the rebuild is n squared over every water piece on the server, and the turning loop (`:16100`) can repeat it. One connected group is capped at 256 pieces (`MAX_PIECES`, `water_network.gd:39`), but the scans cover every group in the world, so cost grows with all plumbing on the server, not with the channel placed. `unmeasured risk`.
- **Fix (M):** relink only the connected group round the new piece; a small grid for port look-ups (ports join within `PORT_JOIN_M`).
- **If we skip it:** each pipe placed in a big irrigation or plumbing build freezes the server a little longer.
- **How others solved it:**
  - [Factorio Friday Facts #271, fluid systems](https://cf-www.factorio.com/blog/post/fff-271) groups connected pipes into separate "fluid systems", each updated on its own. [Factorio Friday Facts #416, Fluids 2.0 segments](https://cf-www.factorio.com/blog/post/fff-416) goes on to treat each connected run of pipes as one segment.
  - [Factorio electric networks](https://wiki.factorio.com/Electric_system): poles that touch form one network, and a new pole joins only the networks it connects to.
- **Pick for Dynasty: Factorio's connected groups.** Each connected run of channels and pipes is its own network, and placing a piece only joins or rebuilds the groups it touches. Placing a pipe stays instant however much plumbing the server has.

### 6. The cut-plant file is rewritten in full once a second while anything is cut (`src/stream/server_flora.gd:406`)
- **Problem:** `save_removed` (called every 0.5 s, at most once a second, `terrain_server.gd:2705`) writes every tree felled and plant removed since the world began, pretty-printed and key-sorted, on the main thread. A road clears plants all along its length, so it rewrites the file every second.
- **Fix (S):** compact JSON and the 30 s save cadence (keep the forced write at exit); later, append-only.
- **If we skip it:** a growing once-a-second hitch while felling, clearing or road building.
- **How others solved it:**
  - Minecraft keeps what happened to a chunk inside that chunk's own slot in the [Minecraft region file format](https://minecraft.fandom.com/wiki/Region_file_format), written only when that chunk changed ([Paper incremental chunk saving](https://ayakael.net/mirrors/papermc/commit/6f2c8a6449ab611291af948092fa692e88e75c0d)).
  - The [Minecraft Bedrock client blob cache (Mojang)](https://gist.github.com/Tomcc/4be79d3eafcd158c5059abd4ab2e8d35) also keys world data per small area, so a change rewrites only that area.
- **Pick for Dynasty: per-area lists saved with finding 2's area saves.** Plants cut in one area are written with that area, on the normal save schedule, so chopping a forest never rewrites the history of the whole island.

### 7. One dig makes every client re-ask water for a box spanning all dig windows (`src/sullivan_water/live/dig_windows.gd:355`)
- **Problem:** `drawn_rect` merges every live dig window into one rectangle, and the server merges it again with the last one sent (`terrain_server.gd:1488`). Two windows kilometres apart (two players digging, or one player's old and new dig) give a rectangle kilometres wide, and every client re-requests water for every flora chunk it holds inside it, again while the water runs.
- **Fix (S to M):** send a list of rectangles (protocol bump).
- **If we skip it:** in multiplayer, water traffic and server work for everyone each time anyone digs near water.
- **How others solved it:**
  - Minecraft tells each client exactly which chunk sections changed (one batch per section, [Paper multi block change](https://ayakael.net/mirrors/papermc/src/commit/5f0932b6c8ac9a3c900075fc40f77b506c63ed82/patches/server/0647-Multi-Block-Change-API-Implementation.patch)), never a bounding box.
  - The [Minecraft Bedrock client blob cache (Mojang)](https://gist.github.com/Tomcc/4be79d3eafcd158c5059abd4ab2e8d35) lets a client re-fetch only the pieces whose contents actually changed.
- **Pick for Dynasty: a list of changed areas.** The server names each changed area (one small rectangle per dig window), and clients ask again only for those, so two people digging far apart never make everyone reload the water in between.

### 8. Animals look for food by scanning every world item (`src/stream/server_items.gd:12418`, `:12454`)
- **Problem:** `loose_food_near` and `stealable_near` loop over all world items. Foxes call it every `look_s` and every step towards food just to find one id again (`server_thieves.gd:86`, `_food_pos` `:131`); goblins (`server_goblins.gd:269`, `:335`), companions (`server_companions.gd:323`) and snares (`server_traps.gd:135`) the same. Cost is animals times world items.
- **Fix (S):** `_food_pos` reads the item by id; the near searches use the grid.
- **If we skip it:** animal ticks get slower as the world fills.
- **How others solved it:**
  - The [Unreal Engine Replication Graph (Fortnite)](https://docs.unrealengine.com/4.27/InteractiveExperiences/Networking/ReplicationGraph) and its [Unreal grid spatialization node](https://dev.epicgames.com/documentation/unreal-engine/API/Plugins/ReplicationGraph/UReplicationGraphNode_GridSpatia-?lang=en-US) file every actor in a grid of cells and answer "what is near here" from the few cells around a point.
  - Factorio keeps its update lists to the entities with work to do ([Factorio developer Rseding91 on active entities](https://forums.factorio.com/viewtopic.php?p=228959)), the same idea applied to searches.
- **Pick for Dynasty: a grid, plus lookup by id.** A fox already chasing a piece of food reads that item directly, and near-a-point searches read the 100 m grid the server already builds. Animals stay lively in a busy world.

## Nice to have

### 9. Every dig is sent to every player (`scenes/terrain_server/terrain_server.gd:2319`)
`net.dug.rpc` goes to all peers; each client marks cache blocks, edits its loaded ground and its grass even kilometres away. Cheap per edit today; grows with players times edits. **Fix (S):** send to players within view distance; the rest get it through finding 1's join path.
- **How others solved it:** Minecraft sends block changes only to players who have that chunk loaded ([Paper multi block change](https://ayakael.net/mirrors/papermc/src/commit/5f0932b6c8ac9a3c900075fc40f77b506c63ed82/patches/server/0647-Multi-Block-Change-API-Implementation.patch)), and the [Unreal Engine Replication Graph (Fortnite)](https://docs.unrealengine.com/4.27/InteractiveExperiences/Networking/ReplicationGraph) sends each player only what is relevant to their cell.
- **Pick for Dynasty: send digs to players within view distance.** Players farther away get them through finding 1's catch-up when they come near or rejoin.

### 10. Supports are found by scanning the world (`src/stream/server_items.gd:4491`, `:4515`)
Placing or removing any support rescans all items; `support_strength_at` (used by the tunnel watch) checks every support in the world per query. **Fix (S):** grid by position.
- **How others solved it:** the grid approach of the [Unreal grid spatialization node](https://dev.epicgames.com/documentation/unreal-engine/API/Plugins/ReplicationGraph/UReplicationGraphNode_GridSpatia-?lang=en-US) answers "which supports are near this point" from nearby cells only.
- **Pick for Dynasty: a grid of supports by position.** Tunnel checks then cost the same in a mine-riddled world as in a new one.

### 11. Whole-file saves that grow with exploring (`src/stream/server_map.gd:319`, `src/stream/server_trails.gd:173`)
A player's whole explored map is rewritten when any of it changes; the animal trails file every 120 s. Small now. **Fix (S):** write only changed blocks.
- **How others solved it:** Minecraft stores each map as its own small file ([Minecraft maps, one file per map](https://minecraft.fandom.com/wiki/Map)), and chunks each in their own slot ([Minecraft region file format](https://minecraft.fandom.com/wiki/Region_file_format)), so a change rewrites only its piece.
- **Pick for Dynasty: save only the changed map and trail blocks** as their own rows, the same way.

### 12. Each water update drops every chunk's packed water on the server (`scenes/terrain_server/terrain_server.gd:1475`, `server_flora.gd:399`)
Only the live window changed, but `clear_water` empties all, so every later ask repacks. **Fix (S):** clear only chunks in the changed area.
- **How others solved it:** the [Minecraft Bedrock client blob cache (Mojang)](https://gist.github.com/Tomcc/4be79d3eafcd158c5059abd4ab2e8d35) keeps cached pieces whose contents did not change, and Minecraft re-sends only changed chunk sections ([Paper multi block change](https://ayakael.net/mirrors/papermc/src/commit/5f0932b6c8ac9a3c900075fc40f77b506c63ed82/patches/server/0647-Multi-Block-Change-API-Implementation.patch)).
- **Pick for Dynasty: forget only the chunks inside the changed area.**

Left out: about 60 other loops over every world item inside one-off player actions (placing, station checks, seats, beds, crafting). Each is one pass per click; they matter only at the scale in finding 3 and share its fix.

**Verdict:** fix 1 first (it is Dave's bug again, at every join), then 2 and 3, which decide whether a long-running shared server stays smooth.

**Not checked:** client UI (`inventory_view.gd`, 7,000 lines; its loops are over items within 100 m, so bounded), animal AI internals, water simulation internals, worldgen and bake tools, rendering and GPU cost. No test or measurement ran.
