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
  - [Minecraft Bedrock client blob cache (Mojang)](https://gist.github.com/Tomcc/4be79d3eafcd158c5059abd4ab2e8d35): the server names each sub-chunk of ground by a hash of its contents; the client checks its own cache, reports hits and misses, and the server sends only the missing pieces. The cache is kept across sessions and even across servers.
  - Dynasty's own PR #1253 (for comparison, not another game): the server keeps a numbered log of digs and fills; a returning client asks for the edits on its tile since its revision and reloads only those spots. A full wipe is left for re-bakes and resets.
- **Pick for Dynasty: PR #1253's catch-up log, now.** It reuses the edit log the server already keeps, and a returning player reloads only the spots dug while they were away. The Bedrock-style hash cache is the stronger long-term design, since it could also spare a full re-download after a re-bake that leaves most ground unchanged. It is a new cache and protocol, so it is worth revisiting only if re-bakes keep making players wait.

### 2. Every save rewrites the whole world on the server's main thread (`src/stream/server_items.gd:1562`)
- **What this is:** every 30 s (`SAVE_EVERY_S`, `:49`) `save()` runs if `_dirty` is set.
- **Problem:** there is one `_dirty` flag for everything (`_dirty = true` appears about 200 times). One pickup, one item ageing out or one moved log makes the next save turn every inventory, world item, chest, tree, character, crop, light, kiln, smelter and smithy into JSON on the tick (`_write_atomic`, `:6197`: "the snapshot is taken now, on the tick"; only the disk write is in the background). A 675 ms save in one tick was already logged on 5 Nov. The cost grows with everything ever built or dropped.
- **Fix (M):** one dirty flag per file, so a pickup saves `inventories.json` only; world items and chests only when they changed. Later, world items as SQLite rows (only changed rows written).
- **If we skip it:** a server freeze every 30 s that every player feels as a hitch, longer each week the world is played.
- **How others solved it:**
  - Factorio: [Factorio non-blocking save](https://forums.factorio.com/viewtopic.php?p=341647) lets the game fork itself so the save is written by a separate background process while play continues. It is experimental, Linux and macOS only, and may crash or corrupt saves. A whole-world snapshot is still taken; it is only moved.
  - Minecraft: the [Minecraft region file format](https://minecraft.fandom.com/wiki/Region_file_format) gives each chunk its own run of sectors and its own modification time. [Paper incremental chunk saving](https://ayakael.net/mirrors/papermc/commit/6f2c8a6449ab611291af948092fa692e88e75c0d) writes only chunks not saved within the autosave interval, up to a set number per tick (default 24), spreading the work over many ticks.
- **Pick for Dynasty: the Minecraft and Paper way.** Keep world items in areas (for example the existing 100 m sync cells) and save only the areas that changed, a few per tick. A save should then cost about the size of what changed, not the size of the world (unmeasured). This changes the save format, which needs Dave's yes. A contained first step was drafted in this thread (moving the JSON work off the server's main loop); it was not pushed or merged and is on hold. It would shorten the freeze but not stop it growing.

### 3. The server's quarter-second tick walks every item in the world many times (`src/stream/server_items.gd:1453`)
- **What this is:** the slow tick runs every 0.25 s (`SLOW_TICK_S`, `:386`).
- **Problem:** each pass loops over every world item to find a few: `_fires` (`:4988`, copies all keys, plus `_refresh_pots` `:8627` two more full passes), `_lights_tick` (`:17176`, copies all keys), `_expire_items` (`:5063`, copies all keys). That is about 6 full passes every 0.25 s. On top: `_sync_world_items` (`:5703`) and the scatter clean-up (`:6325`) every second, and `_on_path` (`:13127`) once a second per player. The item count has no cap and grows with play: a road leaves a `path_patch` item every 0.7 m (`PATH_SPACING_M`, `:3379`), loose stones and sticks are laid out within 96 m of each player and kept to 250 m, dropped items have no limit. 20,000 items means roughly half a million dictionary visits a second before any real work. `unmeasured risk`.
- **Fix (M):** keep small id sets per kind (fires, lights, items that expire, path patches, pots), updated where items are added and erased; near-a-point questions read the `_sync_grid` (`:227`) that already exists.
- **If we skip it:** server lag for everyone that grows with how much the world holds, with no single action to blame.
- **How others solved it:**
  - Factorio: [Factorio developer Rseding91](https://forums.factorio.com/viewtopic.php?p=228959) says the game runs `update()` on "each active entity each tick", so only entities on the active list cost tick time.
  - Factorio: [Factorio Friday Facts #271](https://cf-www.factorio.com/blog/post/fff-271) moved fluid logic into a separate Fluid Manager, grouping connected fluidboxes into fluid systems, so fluid-connected machines no longer had to update every tick for pipe flow. It reports about 6.5 times faster on its test map.
- **Pick for Dynasty: Factorio-style active lists.** Keep a short list per job (burning fires, lit lights, pots) that changes only when one is lit, put out, placed or removed. For things that age, store the moment they expire and look only at the ones due, rather than counting every item down four times a second. Each tick should then cost about what is actually happening, not the size of the world.

## Should fix

### 4. Building a road makes the whole world sync four times as often (`src/stream/server_items.gd:3880`)
- **Problem:** while one player's road builds, `_sync_in = minf(_sync_in, ROAD_SYNC_S)` runs the full world sync (grid of every item, every player's nearby list and signatures) every 0.25 s instead of every 1 s, for everyone. Each station (`_road_station`, `:4071`) also loops over every world item, as does each hoe path stroke (`_hoe_path`, `:3413`).
- **Fix (S):** push the road's new pieces straight to the players near the road and leave the 1 s sync alone; station checks use the grid.
- **If we skip it:** road building gets slower and laggier for everyone as the world fills; it is the action Dave was doing when the ground went missing.
- **How others solved it:**
  - [Unreal Engine Replication Graph (Fortnite)](https://docs.unrealengine.com/4.27/InteractiveExperiences/Networking/ReplicationGraph): Fortnite runs about 100 players and 50,000 replicated actors. Actors are filed into grid cells ([Unreal grid spatialization node](https://dev.epicgames.com/documentation/unreal-engine/API/Plugins/ReplicationGraph/UReplicationGraphNode_GridSpatia-?lang=en-US)), and each client's list is served from the cell it is in, instead of checking each actor against each client.
  - (No second verified example for this one: Minecraft batches block changes per chunk, but the source found was a server-mod patch, not protocol documentation.)
- **Pick for Dynasty: the Replication Graph grid idea.** A new road piece is pushed straight away only to players near the road, and the world sync for everyone else stays at once a second. The road builder should see the road just as quickly, and others stop paying for it.

### 5. Placing one pipe or channel rebuilds the water network of the whole world (`src/stream/server_items.gd:16178`)
- **Problem:** once any piece with ports exists anywhere (`_water_has_ports`, `:16050`), every new water piece calls `_water_relink` (`:16071`), which rebuilds the network from all pieces. Each `WaterNetwork.add` compares the new piece with every piece (`water_network.gd:177`, `:187`), so the rebuild is n squared over every water piece on the server, and the turning loop (`:16100`) can repeat it. One connected group is capped at 256 pieces (`MAX_PIECES`, `water_network.gd:39`), but the scans cover every group in the world, so cost grows with all plumbing on the server, not with the channel placed. `unmeasured risk`.
- **Fix (M):** relink only the connected group round the new piece; a small grid for port look-ups (ports join within `PORT_JOIN_M`).
- **If we skip it:** each pipe placed in a big irrigation or plumbing build freezes the server a little longer.
- **How others solved it:**
  - Factorio: [Factorio Friday Facts #271](https://cf-www.factorio.com/blog/post/fff-271) groups connected fluidboxes into fluid systems held in a Fluid Manager; [Factorio Friday Facts #416](https://cf-www.factorio.com/blog/post/fff-416) groups pipes into fluid segments.
  - (The second source checked, the Factorio wiki on electric networks, does not describe what happens on a join, so it is not used.)
- **Pick for Dynasty: Factorio-style connected groups.** Each connected run of channels and pipes is its own network, and placing a piece joins or rebuilds only the groups it touches, so the cost follows that group, not all plumbing on the server.

### 6. The cut-plant file is rewritten in full once a second while anything is cut (`src/stream/server_flora.gd:406`)
- **Problem:** `save_removed` (called every 0.5 s, at most once a second, `terrain_server.gd:2705`) writes every tree felled and plant removed since the world began, pretty-printed and key-sorted, on the main thread. A road clears plants all along its length, so it rewrites the file every second.
- **Fix (S):** compact JSON and the 30 s save cadence (keep the forced write at exit); later, append-only.
- **If we skip it:** a growing once-a-second hitch while felling, clearing or road building.
- **How others solved it:**
  - Minecraft: the [Minecraft region file format](https://minecraft.fandom.com/wiki/Region_file_format) gives each chunk its own sectors and modification time, and [Paper incremental chunk saving](https://ayakael.net/mirrors/papermc/commit/6f2c8a6449ab611291af948092fa692e88e75c0d) writes only chunks not saved within the interval, a few per tick.
  - (No second verified example; the Bedrock blob cache is a network cache, not a save format.)
- **Pick for Dynasty: cut plants kept per area and saved with finding 2's area saves,** on the normal save schedule, so chopping one forest does not rewrite the island's history. Depends on finding 2's area saves, so it needs the same yes from Dave.

### 7. One dig makes every client re-ask water for a box spanning all dig windows (`src/sullivan_water/live/dig_windows.gd:355`)
- **Problem:** `drawn_rect` merges every live dig window into one rectangle, and the server merges it again with the last one sent (`terrain_server.gd:1488`). Two windows kilometres apart (two players digging, or one player's old and new dig) give a rectangle kilometres wide, and every client re-requests water for every flora chunk it holds inside it, again while the water runs.
- **Fix (S to M):** send a list of rectangles (protocol bump).
- **If we skip it:** in multiplayer, water traffic and server work for everyone each time anyone digs near water.
- **How others solved it:**
  - [Minecraft Bedrock client blob cache (Mojang)](https://gist.github.com/Tomcc/4be79d3eafcd158c5059abd4ab2e8d35): a client is sent only the pieces whose contents it does not already hold.
  - (No second verified example.)
- **Pick for Dynasty: a list of changed areas.** The server names each changed area (one small rectangle per dig window), and clients ask again only for those, so two people digging far apart do not make everyone reload the water in between.

### 8. Animals look for food by scanning every world item (`src/stream/server_items.gd:12418`, `:12454`)
- **Problem:** `loose_food_near` and `stealable_near` loop over all world items. Foxes call it every `look_s` and every step towards food just to find one id again (`server_thieves.gd:86`, `_food_pos` `:131`); goblins (`server_goblins.gd:269`, `:335`), companions (`server_companions.gd:323`) and snares (`server_traps.gd:135`) the same. Cost is animals times world items.
- **Fix (S):** `_food_pos` reads the item by id; the near searches use the grid.
- **If we skip it:** animal ticks get slower as the world fills.
- **How others solved it:**
  - By analogy with the [Unreal Engine Replication Graph (Fortnite)](https://docs.unrealengine.com/4.27/InteractiveExperiences/Networking/ReplicationGraph): actors are filed into grid cells ([Unreal grid spatialization node](https://dev.epicgames.com/documentation/unreal-engine/API/Plugins/ReplicationGraph/UReplicationGraphNode_GridSpatia-?lang=en-US)), and a client is served from its own cell. The same grid idea can answer "what food is near this point".
  - Factorio's active list ([Factorio developer Rseding91](https://forums.factorio.com/viewtopic.php?p=228959)): only what is active costs work.
- **Pick for Dynasty: a grid, plus lookup by id.** A fox already chasing a piece of food reads that item directly, and near-a-point searches read the 100 m grid the server already builds.

## Nice to have

### 9. Every dig is sent to every player (`scenes/terrain_server/terrain_server.gd:2319`)
`net.dug.rpc` goes to all peers; each client marks cache blocks, edits its loaded ground and its grass even kilometres away. Cheap per edit today; grows with players times edits. **Fix (S):** send to players within view distance; the rest get it through finding 1's join path.
- **How others solved it:** the [Unreal Engine Replication Graph (Fortnite)](https://docs.unrealengine.com/4.27/InteractiveExperiences/Networking/ReplicationGraph) serves each client only the actors in the grid cells relevant to it, not every actor in the world.
- **Pick for Dynasty: send digs only to players within view distance.** Players farther away get them through finding 1's catch-up when they come near or rejoin.

### 10. Supports are found by scanning the world (`src/stream/server_items.gd:4491`, `:4515`)
Placing or removing any support rescans all items; `support_strength_at` (used by the tunnel watch) checks every support in the world per query. **Fix (S):** grid by position.
- **How others solved it:** by analogy with the [Unreal grid spatialization node](https://dev.epicgames.com/documentation/unreal-engine/API/Plugins/ReplicationGraph/UReplicationGraphNode_GridSpatia-?lang=en-US), the same grid idea can answer "which supports are near this point" from nearby cells only.
- **Pick for Dynasty: a grid of supports by position,** so a tunnel check costs about the same in a mine-riddled world as in a new one.

### 11. Whole-file saves that grow with exploring (`src/stream/server_map.gd:319`, `src/stream/server_trails.gd:173`)
A player's whole explored map is rewritten when any of it changes; the animal trails file every 120 s. Small now. **Fix (S):** write only changed blocks.
- **How others solved it:** a loose analogy: Minecraft stores each map as its own file, `map_x.dat` ([Minecraft maps](https://minecraft.fandom.com/wiki/Map)), and each chunk in its own sectors ([Minecraft region file format](https://minecraft.fandom.com/wiki/Region_file_format)).
- **Pick for Dynasty: save only the changed map and trail blocks** as their own rows. Depends on finding 2's area saves, so it needs the same yes from Dave.

### 12. Each water update drops every chunk's packed water on the server (`scenes/terrain_server/terrain_server.gd:1475`, `server_flora.gd:399`)
Only the live window changed, but `clear_water` empties all, so every later ask repacks. **Fix (S):** clear only chunks in the changed area.
- **How others solved it:** by analogy with the [Minecraft Bedrock client blob cache (Mojang)](https://gist.github.com/Tomcc/4be79d3eafcd158c5059abd4ab2e8d35), which keeps what has not changed and fetches only what has.
- **Pick for Dynasty: on the server, forget only the chunks inside the changed area.**

### Follow-up for Dave to pick (not built): fine dig water goes to every player (`scenes/terrain_server/terrain_server.gd:1464`)
Found while building 7 and 12 (18 Nov). `deliver_fine_water` sends each dig region's 2 m water to every connected player, wherever they stand, every time it changes. It is the same shape as finding 9 (digs sent to everyone). A likely fix is to send each region only to players within its reach, as the pick for 9 does for digs. Not built: it changes who gets what water, so it waits for Dave's pick.

Left out: about 60 other loops over every world item inside one-off player actions (placing, station checks, seats, beds, crafting). Each is one pass per click; they matter only at the scale in finding 3 and share its fix.

**Verdict:** fix 1 first (it is Dave's bug again, at every join), then 2 and 3, which decide whether a long-running shared server stays smooth.

**Not checked:** client UI (`inventory_view.gd`, 7,000 lines; its loops are over items within 100 m, so bounded), animal AI internals, water simulation internals, worldgen and bake tools, rendering and GPU cost. No test or measurement ran.

## For Dave (provisional choices made while building, 18 Nov 2026)
Assumed on Dave's behalf under his "these should all be built" (11:08Z). Each value can be changed with one constant.
- **Finding 2, crash window.** World items are now saved by area: only the areas that changed are copied and written. Changes are found by a check that walks the world a little every tick. Because of that, a change can take up to two saves (about a minute) to reach the disk, where it used to take one (about 30 s). If the server crashes, up to about a minute of world item changes can be lost: dropped items, placed pieces, fires. The check is kept under 1 ms a tick. Measured on David4 (18 Nov, 50,000 world items) it costs about 0.5 ms a tick and walks the whole world in under one save interval, so the window is about a minute there. It walks about 200 items a tick at most, so the window stays about a minute up to roughly 100,000 world items; past that it grows with the world (about 2 minutes at 200,000, estimated). A clean shutdown loses nothing. Raising the per-tick limit shortens the window and costs tick time. (`SAVE_EVERY_S`, `SWEEP_BUDGET_US` in `server_items.gd`.)
- **Finding 2, timers after a crash.** Running timers, such as how long a dropped item lasts or how long a fire burns, are rounded to 10 minutes when deciding whether an area changed. After a crash, a dropped item can last up to 10 minutes longer, or a fire burn up to 10 minutes longer, than it would have. (`AREA_STEP_S`.)
- **Finding 2, area size.** Each area is 128 m square. (`AREA_M`.)
- **Finding 2, older builds.** A world saved by this build cannot be opened by an older build.
