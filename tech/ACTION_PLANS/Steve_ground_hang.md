# Action plan: "Loading the ground under you" can hang forever (Dave, build 787, first start after Pull)

Branch: claude/steve-ground-hang (plan only, no code yet; devstop). CHANGE_LABEL: RUNTIME (client only).
Symptom: join window stuck at step 3, "0 blocks still arriving, 83 s so far". Second start worked. Server and protocol matched (77).

## Cause (read from code, NOT reproduced; confidence about 70 percent)
- The gate: `_ground_ready()` (terrain_client.gd:4758) needs a physics ray 300 m down from the player to hit collision. Until then `waiting_for_ground` is true and the player glides level, not moving.
- "N blocks still arriving" is `stream.pending()` = blocks asked for and not yet answered (`_waiting`). It is 0 when the stream has nothing outstanding.
- In `network_voxel_stream._load`, a block that comes back damaged, zeroed or "not ready" is asked again at most 3 times (300 ms apart); a block unanswered for TIMEOUT_MSEC (30 s) returns RESULT_ERROR. After that the stream owes nothing (pending 0) and the voxel engine does not ask for that block again until the player moves it out of and back into view. A player gliding on the spot never does.
- First start after a Pull is the slow case: the server reads the new tiles from disk for the first time (over a second per tile, nine tiles), and answers for the block under the spawn can be late, refused or zeroed. All three tries or the 30 s timeout are spent, the block under the player stays a hole, nothing retries. Second start: tiles are warm, the blocks are cached, it works.
- Why the existing guard missed it: the "server is not sending ground" failure (terrain_client.gd:744) only fires when `blocks_received == 0`. Here other blocks had arrived, so the window just kept counting. The window also closes only after 120 s, and by then the player is still stuck.

## Fix (small, client only)
1. Watchdog in `_update_connect_window` / physics: while `waiting_for_ground` and `pending() == 0` for 8 s (or `pending() > 0` with no `blocks_received` change for 40 s), restart the stream the way `_reload_ground()` already does, but WITHOUT `cache.clear_all()` and without dropping the starter cache: new stream, same cache and link, `terrain.stream = stream`. Repeat every 10 s, up to 6 tries.
2. Window text says what happens: "Ground is slow: asking the server again (try 2 of 6)". After the 6th try show a clear failure with the numbers and the two log files to send, instead of counting forever.
3. Telemetry on every retry: loads, blocks_received, timeouts, bad_blocks, zeroed_blocks, last block key, player position, and the server's tile state (placeholder or not). One line "JOIN: ground retry n".
4. (Server, optional) while a tile is still loading for the first time, answer "not ready, retry in 1 s" at once instead of blocking up to the 30 s timeout.

## Repro idea for Mike
- Delete the client cache and the second clone's server tile cache, start the server and the client within a second of each other (the "play" launcher path) right after a Pull with changed tiles. Repeat 5 times.
- Or force it: a rig flag `--drop-ground-blocks N` that makes the stream return RESULT_ERROR for the first N answers of the block under the spawn; without the fix the window must hang, with the fix it must open within about 15 s.
- Please keep Dave's files from that run: user://ground_mismatch.log, telemetry_client.log (look for "ZEROED BLOCK", "bad block", "JOIN:" lines) and the server log around the first block requests.

## Tests
- Headless: stream stub that fails the first N loads of one block; assert the watchdog restarts and `_ground_ready()` turns true. Parse scan, local_check (233, no new).
Not run in Godot in the cloud.

## Tyler reply (once, 24 Oct 13:52 UTC)
Approved to build as a bug fix despite the devstop. One branch, claude/steve-ground-hang only, no other work. RUNTIME, client side.
1. Build items 1-3 as written. Item 4 (server "not ready, retry"): SKIP for now. It changes the protocol and needs a number; the client watchdog alone covers it.
2. Watchdog must never clear the cache or the starter cache. Retry caps are fixed: 8 s idle, every 10 s, 6 tries. After the 6th try the failure text names the log files.
3. Add the rig flag `--drop-ground-blocks N` (test only, off by default, not in the normal launcher) so Mike can force the hang. Prove BOTH ways in the test: without the fix it hangs, with the fix it opens within about 15 s.
4. Tests: headless stub test, parse_scan, local_check (baseline 233, no new warnings), check_controls. Print any changed defaults (BP-T55). No pictures in the branch.
5. Push, post the id. I merge the tested id only after Mike's PASS on a fresh clone after Pull (5 starts, all open). Goes into the next build with the final bake checklist.

## Built (Steve, 24 Oct, after Tyler's GO)
- src/client/ground_watchdog.gd: the retry rules as one small class (idle 8 s, every 10 s, 6 tries; a busy stream with no ground after 60 s is retried every 30 s). Never clears the cache.
- terrain_client.gd: `_run_ground_watchdog` (every frame while connected), `_restream_ground` (new stream, same cache and link), window line "Ground is slow: asking the server again (try n of 6)", failure screen after the 6th try naming telemetry_client.log and ground_mismatch.log, telemetry line "JOIN: ground retry ..." with loads, received, timeouts, bad, zeroed, pending, player position.
- Test flag `--drop-ground-blocks=N` (client command line, off by default, not in the launcher): the first N blocks the engine asks for fail for good (nearest first, so the one under the player). Without the fix the join window hangs; with it the ground opens at about 8 s. Mike: `godot --path . res://scenes/terrain_client/terrain_client.tscn -- --server=... --drop-ground-blocks=40` with the watchdog, then compare by checking out the commit before.
- src/worldgen/tools/test_ground_watchdog.gd (headless, prints "Test done: N pass, N fail"): hangs without the fix (120 s), opens within 15 s with it, normal join never triggers, a stubborn ground gives up after 6 tries within 80 s.
- No defaults changed. Not run in Godot here; parse_scan 0 problems, check_controls run.
