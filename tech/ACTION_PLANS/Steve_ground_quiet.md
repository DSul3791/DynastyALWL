# Action plan: the watchdog restarts a healthy slow stream (BUG-001 reopened / BUG-002)

Branch: claude/steve-ground-quiet (from generator-v2). RUNTIME, client only (ground_watchdog.gd, terrain_client.gd, network_voxel_stream.gd counters). Evidence: Mike's log logs/join_ground_fail_2026-10-24.txt on claude/mike-goalpad (3dc47918), build be20764e.

## What the log shows (read line by line)
1. The stream is healthy and slow, not quiet: received 120 at +16 s, 2214 at +31 s, 5269 at +36 s, 9883 at +46 s (the server sends 24,456 blocks, 10.8 MB). `timeouts 0, bad 0, zeroed 0, test drops 0`: NOTHING failed. The client already knows the ground is at 31.2 m; the ray under the player finds no collision yet (the engine is still busy building), so `waiting_for_ground` stays true.
2. At +46 s my BUSY rule (30 s waiting, pending > 0) fires "retry 1". `_restream_ground` throws the stream away: counters fall (received 9883 to 4615, loads 5905 to 2610) and work already done is redone. Retry 2 at +61 s again.
3. Retry 3 (+72 s): the new stream gets `received 2047`, then `received 0, pending 0` for ever. The voxel engine already holds the blocks it loaded, so it asks the NEW stream for nothing. Zero asked, zero received.
4. `silent_server` in `_update_connect_window` reads the CURRENT stream's counters: `blocks_received == 0 and pending() == 0` after 20 s in the world, i.e. exactly the state my restart created. It shows "The server is not sending ground ... none is being asked for" while the picture shows ground and the server sent 24,456 blocks. The shot runner then saves "GROUND NOT READY".
So the error is caused by my restart, in two ways: (a) busy restart of a stream that keeps delivering, (b) the error text reads counters that the restart reset.

## Changes
1. **Restart only on failure, never on slowness.** New `stream.failed_total()` = timeouts + bad_blocks + zeroed_blocks + drops_made (the test drop counts: a dropped block is a failed block). The watchdog gets `failed` as a fourth argument. A retry is due only when failures are NEW since the last retry (`failed > failed_at_last_try`) AND the stream is idle (nothing pending, or no block received for 8 s). The BUSY rule (retry while blocks keep arriving) is removed. A delivering stream with no failures is never restarted.
2. **Totals across restreams.** `_ground_received_total` and `_ground_failed_total` carried over in `_restream_ground`; `silent_server` and the 5 s join line use the total (received since the welcome, not since the last restart); "not sending ground" needs total received == 0 AND no retry yet. After any retry it can never fire.
3. **Slow but healthy: say so, do not fail.** While waiting with no failures the join window shows "The ground is loading (n blocks so far)" instead of an error; give-up is only after MAX_TRIES failed-block retries, as today.
4. **A real missing block still recovers.** `--drop-ground-lods=4` counts drops as failures (item 1), so the existing hang test still retries and opens (test_ground_watchdog.gd keeps its cases; new cases: slow stream with 0 failures is never retried over 120 s; a restart cannot raise "not sending ground"; failure plus idle retries; counters carry over).
5. **Diagnostics (so the next log shows the cause of the slow collision):** the 5 s join line adds `ray_down` (does a ray down from the player hit anything), failed total, received total, and the terrain's `collision` state if the voxel terrain exposes it.

## Not in this plan (honest)
Why the collision under the player takes 46+ s to appear while 10,000 blocks stream in (the client receives 120 blocks in the first 16 s and then thousands a second) is a streaming-order or main-thread question, not the watchdog's. With this plan it no longer breaks the join; the shot runner still sees "ground not ready" until the engine finishes, so it should wait for `waiting_for_ground == false` up to a longer timeout (Mike/David3's shot_runner). If wanted, a follow-up plan looks at the server sending the spawn column first.

## Gate (BP-T57)
Fresh-clone join on the box (David3) and a fresh start on Mike's Windows PC; test_ground_watchdog.gd; `--drop-ground-lods=4` still recovers; picture runs show no error text. Not run in Godot in the cloud.
