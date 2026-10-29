# Handoff: "Ground loading and performance" thread (written 2026-10-21)

A fresh Claude can continue from this file alone. Read HANDOFF.md, CONTROLS.md and PROTOCOL.md in the repo too.

## Who and where
- Game DynastyALWL: Godot 4.7.2 custom build with Voxel Tools, GDScript. Repo `DSul3791/DynastyALWL`, in the cloud `/home/claude/dynastyalwl`. Dave plays from `C:\GodotProjects\DynastyALWL` (RTX 2060 Super, 4K, game runs embedded in the editor Game tab). Cloud has NO graphics (headless only). Minimum target machine: GTX/RTX 1050 class, 30 fps, 8 GB RAM.
- Work ONLY on branch `claude/generator-v2`. Never push to main (protected; Dave merges PRs). Push with `git push -q origin HEAD:claude/generator-v2` and mirror with `git push -q -f origin HEAD:claude/project-thread-6sd912` (the stop hook complains about unpushed commits on that branch otherwise). Before every push: `git pull --rebase`, `git grep -nE '^(<<<<<<<|>>>>>>>)' -- '*.gd' '*.md'` must be empty, `python3 tools/check_controls.py` must pass, headless parse check. Commit messages end with the Co-Authored-By and Claude-Session lines from the attribution reminder.
- Technical direction (TD) = session `cse_0111SmjyMaTAj3PtyQqHboYJ` (send with `mcp__claude-code-remote__send_message`; arrives to you via ReadNotifications). Coordinator = `session_01Q56PMTBrWt1QNcAeKECxYY`. Art direction = `session_01Lp4BdAEwUFHKjaufRuJ5M3`. Art owns `grass_view.gd` and `flora_view.gd`: message them before big edits there.
- Dave uses voice; keep replies to him short and plain via `mcp__hearthbot__reply`. Progress in `update_status`. "Finished:" opens a reply for a big job. No em-dashes, no ids in text. Use `no_reply_needed` when nothing is owed.

## What I own
Ground loading and streaming (client side), display and quality tiers, HUD and debug details, the GPU/probe tables, frame probe, stances (client), the third-person camera, the client block cache, spade digging and the dig log (server store), performance audits. Not mine: generator speed (Water/terrain), sounds (Sounds), flora/grass looks (Art), items/protocol rules (Items).

## Rules Dave/TD set (keep)
- Every key or input change goes into CONTROLS.md in the same push ("every input is recorded"). Never say F8 for the GPU table: it is Ctrl+Shift+G or Esc > Advanced.
- Big changes (protocol, save formats, engine settings, shared files) need TD approval; standing approval (DECISIONS.md): for chosen features, protocol or save changes are pre-approved if PROTOCOL.md is updated, saves are versioned and cost at Low is stated. State the cost at Low in commit notes.
- Build numbers: TD hands them out in blocks. Never take upstream+1 while holding spares: use the held numbers (the HUD takes the max). Tell TD the commit id after each push. I currently hold: **348, 369, 370, 389, 390** (347 used for the grass merge, 364 digging, 379 probe rows; 346 camera; 299 void).
- Dave's wording that matters: fonts readable on a 55" 4K TV at 1080p; "oh I see. but in our game we should just set it to 1080"; the HUD default is build number, last sound played and location only ("up the scale so I can read it"); effect symbols (brain, ghost house) sit side by side in one row, recentred; keys: C crouch, X sit, Z lie, E interact; mouse wheel scroll out = third person, scroll in = back to first, zoom remembered; spade digging in front of him; "create a simple ragdoll type character" (Art built it, build 349).
- Dave often screenshots an older build: check the HUD build number before treating something as a regression.
- Never use `pkill -f` (it kills your own shell); kill by PID. Godot at `~/bin/godot` (`export PATH=$HOME/bin:$PATH`). Exit-time RID/ArrayMesh/"RenderingServer null" errors in headless runs are old noise.

## What is built (builds / commits, newest first)
- 379 (deeb36f): GPU table has engine rows: idle step split into timed pieces and untimed engine time, voxel main-thread us (detect, io, mesh, update, avg/worst), voxel task queues. At Low the slow sound pieces (ambience, insects, weather, ice, windhole, cave, town, creatures, interior, tree wind, workshop, trees, occlusion) update every second frame with both frames' delta; water, splashes, swim, breath, spear, dig, fire, flame, steps stay per frame (water halved broke the sound_check "merge" scenario).
- 347 (c6ab4d6): grass drawn in merged MultiMeshes (`GrassView.set_merge`: 4x4 cells per draw at Low, 2x2 above; per-cell "bufs", `_flush_groups`, `_make_group_node`). Low grass nodes 388 to 64-68. Low total visible draw nodes at spawn about 334 (from about 970; Art's flora merge 387 did the rest).
- 364 (45ee3af): spade digging. `ACT_DIG = 25` (protocol 28 then; protocol is 31+ now), server `_dig` in server_items.gd (spade, reach 4.5 m, 0.7 s pace, wears spade "dig", 0.9 m sphere 0.25 m below the point), `ServerBlockStore` dig log `digs.dat` ("DIGS1" + x,y,z,r float32; TD says River start extends it to DIGS2; keep the DIGS1 reader forever), `load_block` replays the log over freshly made blocks so holes survive restart and re-bake. Design: DIGGING_DESIGN.md. Client: `held_item._dig_here` (left click with spade). Open item: the admin `dig` RPC (any peer, radius up to 8) is ungated; fix before any public server.
- 346 (bed68da): third-person camera on the wheel (`_scroll_view`, `_update_view`; `camera` stays the eye node, `view_cam` child draws; ray pulls in when blocked; zoom saved in user://view.txt). Art replaced my placeholder body with the ragdoll (build 349, `ragdoll_body.gd`).
- 231/229/222/213/211/204/176/163/162/161/136 and earlier: Measure this machine probe, stances (client + `items.request_stance`), cache flush on a worker thread, status symbol row (`status_icons.add_icon`), tier on the HUD, spawn flora chunks before threads (startup crash mitigation, not reproduced), frame probe, debug HUD registry (`debug_hud.add_line`), 16:9 fixed render size, GPU table layout, display settings.

## Findings (for TD/Dave, all logged in tech/RENDER_AUDIT.md)
- Idle script step headless: about 1.7 ms/frame at Low and Ultra alike (sound.update 0.57, player 0.3...). Dave's PC showed 33 ms idle step (build 354 table at Ultra): not our scripts. Waiting for his table on 379+ with the new "untimed" and "voxel us" rows; report the top three costs to TD when it arrives.
- Collision: trunk colliders (2933 at collision_m 160, 1613 at 60, 0) and terrain collision_lod_count (4 vs 1) did not change the physics step (about 2 ms headless regardless; cloud noise about 1 ms). No change made.
- 24 small static-body meshes near spawn are loose stones/sticks (world items, one MeshInstance each, Items' code); left alone.

## In flight (exact state)
- Client memory audit at Low (TD's last job to me): NOT finished, nothing pushed, working tree clean. I had a throwaway script `/tmp/claude-0/mem.sh` (will be gone) that patched `_process` in terrain_client.gd to print every 1800 frames: `Performance.MEMORY_STATIC`, OBJECT_COUNT, OBJECT_NODE_COUNT, resource count, `VoxelEngine.get_stats()["memory_pools"]` voxel_total/block_count, `flora._chunks.size()`, `flora.instances`, `flora.colliders`, `grass.tufts`, `grass._cells.size()`, RSS from /proc/self/status (my parse failed: split fields with `.split(" ", false)`). Partial result, standing at the spawn at Low: static memory 272 MB at 1 min then 304 MB at 2 min, objects 7626 to 8053, voxel pool 91 to 95 MB, 16k to 16.7k voxel blocks, flora chunks 4 fixed, grass cells 183 fixed. **Static memory and object count were still growing while standing still: find what grows (suspects: sound streams loading (see memory_cap_bytes in sound_stage.gd), voxel pool, cache, textures) and cap it.** Wanted by TD: resident memory after 10 minutes in a forest and a meadow, and while flying, biggest holders (flora, grass buffers, voxel blocks, audio, textures), caps if anything grows without bound. Headless has no textures/GPU, so say so.

## Queue in order
1. Finish the memory audit above; report to TD; push caps if anything is unbounded (ask TD for a number, or use a held one).
2. Report the top three costs when Dave's table with the new rows arrives (TD wants the "untimed" figure and voxel us rows).
3. tech/JOBS.md "Ground loading and performance" section: job 6 (tree LOD) is done by Art; job 7 (collision) answered with no change; check the rest of the section for items left.
4. Possible follow-ups: gate the admin dig RPC; sit/lie status symbol (skipped earlier); compare frame pacing at High with vsync vs Medium; vsync/pacing work; if the startup crash (signal 11 in `patch_at`, propagate_notification) ever recurs, put a mutex around `placer.chunk_items`.

## Waiting on Dave (real machine checks, none confirmed)
- Third-person feel, stance feel (C, X, Z), HUD size/readability, letterbox/mouse/compass at 16:9, Measure this machine run (Esc > Advanced; needs the 1050-class PC), spade digging in the real game, grass popping at the 4x4 group edges at Low (watch the edges while walking), and his build-379 GPU table with the new engine rows.

## Gotchas
- Test harness (recreate if lost): server `godot --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --port=P --store=DIR --quit-after=N` and client `godot --headless --max-fps 30 --path . res://scenes/terrain_client/terrain_client.tscn -- --port=P --cache=DIR --wait=60 --frames=F --quality=Q [--walk|--fly --move=15|--dig|--dig-check]` in parallel, fresh dirs each time. `FrameProbe.report()` prints at the end of a client run. Env `SPIKES=1` prints slow pieces, `BLOCKTIME=1` server timings, `CACHE_SLOW_MS` slow disk.
- `tools/sound_check.py` ("floor" scenario fails also without my changes), `tools/items_check.py`, `tools/check_grass_density.py`, `tools/check_grass_bands.py`, `tools/check_controls.py` are the guards.
- Headless measurement noise on the cloud box is about 1 ms; compare only big differences or run twice.
- Content scale: base 2880x1620; 3D size per tier via `DisplaySettings.render_size`. Tiers Low..Ultra; Low ground view 768 m, grass 14 m ahead radius per tier table in terrain_client.gd (`QUALITY_*` consts).
- Stale ground after a bake: Esc > Advanced > "Clear saved ground". Dave bakes tiles himself; no baking in the cloud.
- The repo-moved notice on push is only a notice. If a push is rejected: pull --rebase and push again. Resolve BUILD-line conflicts by keeping the higher number.
