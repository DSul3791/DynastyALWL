# Local server and client competing at the first load: plan (BugsList 108, 93)

Status: plan only, no code yet (22 Nov 2026). It was written for the lag list, piece 1, "server pauses while the PC loads tiles". The trigger was the second main gate's Z step A5, which went red. The cold first-join FREEZE had medians of 25.23 s at Z and 23.96 s at Y''', against a pass rule of 24.85 s (record: /mnt/project-files/server-client-split/NEXT_MAIN_GATE.md, A5 ruling and its follow-up). Evidence cited here under /mnt/project-files/ is the project's shared folder, not in this repo.

Dave's recorded stance (BugsList_Current.md, BugsList 93, and TODO.md, 21 Nov) is that a long first load is "not a problem. its expected on the first load", and #1405 shows a note saying so. This plan is lag-list work picked by the coordinator, not a request from Dave. Whether the second main merge waits for any of it is his choice.

## What the logs already show

- **Client, cold first join (Z, Y''').** There is one FREEZE gap of about 25 s after the "held item" piece, with a HUNG report. During it, voxel streaming shows 1000 blocks outstanding and the link rtt reads 12.6 s (NEXT_MAIN_GATE.md, A5 follow-up); the coordinator also relays that nothing is received.
  - Those last three are symptoms of the frozen client main thread, not causes. ENet is polled from the main thread, so a frozen client acknowledges nothing; the rtt grows and the outstanding count stays full.
  - The FREEZE comes before any first-shown model. BugsList 93 puts the cause in the cold d3d12 pipeline and shader build of the world materials. On 20 Nov a warm APPDATA cut the longest FREEZE to 2754 and 2988 ms (/mnt/project-files/server-client-split/MAIN_GATE_TONIGHT.md, evening of 20 Nov).
- **Launcher server, the same runs.** Two server STALL lines, about 5.7 s and about 25 s, are known here only as relayed by the coordinator from the gate lanes; their full lines are not in a record yet. The second has about the same length as the client's freeze.
- **Older full report** (/mnt/project-files/diag93_X1_hung_report_2026-11-20_17-56-22.txt, build of 20 Nov):
  - Server STALLs of 1791 and 11306 ms during the first join. The client's own main thread also stalled 6475 ms at 17:56:07.
  - The state line after the 11.3 s one names the slowest steps since the last state line: "between frames (rpc handlers, engine) 1791, items 3524, checks 7740". `event_log.mark` keeps each step's maximum since the last state line, so these are not one frame. items + checks = 11264 ms fits the 11306 ms frame. The 1791 most likely belongs to the earlier 1791 ms STALL, whose own line closed before its step mark (inferred; the two lines' timestamps overlap by about 1 s).
  - The same log has "terrain: tile (3, 4) loaded in 2874 ms (file 2845 ms)", which is a 2.8 s file read of the spawn tile.
  - "items" is `items.tick` plus `_tunnel_tick` and `_send_buried`. "checks" is everything after the block delivery in `terrain_server._process`: `_send_held_edits`, `_send_fine`, `store.save_revisions`, `flora.save_removed`, the flag files, and direct `print()` calls.
- **Z against Y'''.** Z is about 1.3 s slower on all three runs. Z adds more start-up work on the server: the resource landscape (#1469, #1500, about 9 tiles on a worker), the animal range jobs (#1484, #1504, main-thread lumps of 34-67 ms per block), and the cave and ore layout.

## How the two processes share the PC today

- The Play launcher (`scenes/launcher.gd`) starts the server with `--threads=` set to half of the usable cores. That caps only the server's own block-builder threads, which run at `Thread.PRIORITY_LOW`, plus 2 idle builders, also low.
- The server's **WorkerThreadPool tasks are not capped and run at normal priority.** These include tile prefetch (`terrain_generator.prefetch_tile`), the resource landscape (`server_items._resource_task`), coarse ground, and the flora brush and cover-index chunks (`server_flora._brush_tasks`, `terrain_server._cover_tasks`). "Normal" here means the pool's non-high queue (`add_task(..., false)`); NEXT_MAIN_GATE.md calls the same queue low. The log-line prints in server_items and server_flora go to the high queue. The item save writer and `_bury_thread` are their own Threads at the default priority. Godot's pool size is one thread per core by default, as far as I know the engine (an assumption, not checked here); the project sets no `threading/worker_pool` setting. On a 12-core PC the server alone can have 6 low builders, 2 low idle builders and up to 12 normal pool threads runnable during the client's cold shader build. The driver's shader compile threads are assumed to run at normal priority too (not checked).
- `terrain_generator.get_tile` reads a tile once. Any other caller, the main thread included, spins on `OS.delay_msec(5)` until that read is done. A main-thread call on a tile that a starved worker is still reading therefore waits as long as the worker does. #1503 removed the periodic main-thread tile reads on the position-report path, but player actions (fishing, drinking, digging) and `ground_height` still read.
- Both processes read and write the same disk at the first load. The client copies the starter ground and writes its shader caches; the server reads tile files and writes saves.

## Candidate causes, most likely first

1. **CPU oversubscription.** The client's shader build plus the server's uncapped, normal-priority pool tasks, with more of them since #1469 and #1484. This fits the extra 1.3 s at Z and the server STALL matching the client FREEZE. It is inferred, not measured.
2. **The server main thread waiting on a starved worker.** This happens through `get_tile`'s wait, or through a lock a pool task holds (the flora lock, the store). This fits a STALL length close to the freeze. It is inferred.
3. **Synchronous main-thread work in the server's "items" and "checks" steps at the first join** (3.5 s and 7.7 s on 20 Nov). Which sub-step is slow is not yet measured. Candidates are the save writes (`save_revisions`, `save_removed`), `_send_held_edits` and `_send_fine` on a new player, and direct `print()` on a debug build. The client fix #1491 shows that a main-thread print can take 0.4-1.6 s there.
4. **Disk contention.** The 2.9 s spawn-tile read against the client's cache writes on a cold run. This adds to 1-3 but is unlikely on its own to make 25 s.

## Options, lowest risk first

| # | Option | Risk | Expected effect | What it needs to test |
|---|---|---|---|---|
| A | **Measure first.** Sub-marks inside the server's "items" and "checks" steps, a server-side "pool tasks running/queued" count on the state line, and the server's direct `print()` calls in `_process` moved to the existing print queue (`src/shared/print_queue.gd`, as the client does since #1491). | Very low: logging, and print order only | Names the slow step, so B to E aim at it (measure before fixing: docs/PONYTAIL_RULES.md) | Change plan on Lane B (smokes dedicated_stop, play_stop, join_remote); one cold windowed Play on Lane A to read the new STALL breakdown |
| B | **Hold the server's start-up jobs while a player is joining.** The local Play server starts the resource landscape, range jobs and similar after the first player reports ground ready, or after a fixed time, whichever comes first. A dedicated server starts them at once, as now. | Low to medium: a job order change, and nothing in the world differs once done | Takes Z's +1.3 s out of the first-join window; less pool load during the shader build | Change plan; Lane A 3 cold windowed Plays, median FREEZE against Y''' and Z; a check that the resource landscape and ranges still finish (their existing tests, plus a Lane B log line) |
| C | **Cap the server's pool on Play.** The Play server's own pool tasks go through one small queue with its own cap (for example half the cores, the same as `--threads`), instead of straight to `WorkerThreadPool.add_task`. Godot has no per-process command-line override for `threading/worker_pool/max_threads` that I could find in this repo, so the cap is ours. | Medium: touches every server pool user; a too-small cap slows block and tile service | Bounds the server's share of the PC while the client builds shaders | Change plan plus the timing tests (flora walk cost, stock poll cost); Lane A 3 cold Plays; Lane B dedicated smokes to confirm dedicated servers are unchanged |
| D | **Take the measured main-thread steps off the server's main thread.** Whatever A names, for example the save writes into the existing writer pattern, or a new player's held edits sent over several frames. | Medium: depends on the step; saves need the crash-safety checks of #1473 | Removes the STALL's own share | The owning tests for that step, plus Lane B save and resume tests (test_area_saves, test_resume_spot) |
| E | **Lower the whole Play server process's priority** (below normal on Windows). | Medium to high: needs a platform-specific launch (`OS.create_process` has no priority); the Linux and dedicated paths must stay as they are | Gives the client first claim on every core | A Windows-only lane check (Lane A); Lane B confirms Linux is unchanged |

The client's own cold shader build (BugsList 93) is the larger part of the 25 s and is a separate track. It is the targeted warm-up, once Dave's play log names the first-shown stalls. That work and these options add up; they do not replace each other.

## Recommendation

1. Do **A** now. It is safe before or after a main gate and turns causes 1-3 from inference into numbers.
2. Then do **B** if A shows the pool busy with start-up jobs during the freeze. It is the smallest change aimed at Z's extra 1.3 s.
3. Do **C** or **D** only if A's numbers point there.
4. Keep **E** as the last resort.
5. B to E should land after a main gate, not just before one. Each changes timing on the first join, which is what the gate's A5 step measures.

## Open questions (for the coordinator)

- The 5.7 s and 25 s server STALL lines from Z are known here only as relayed. Their full lines, with the steps named, would confirm whether the 25 s server STALL is in "items", "checks" or "between frames". Ask the lane for `telemetry_server_*.log` from one Z run.
- For B: is "the first player's ground ready" the right trigger on a Play server, or simply a fixed 60 s after start? The second is simpler and does not depend on a client message.
