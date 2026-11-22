# Local server and client competing at the first load: plan (BugsList 108, 93)

Status: plan (22 Nov 2026); option A, measurement only, is in #1518. It was written for the lag list, piece 1, "server pauses while the PC loads tiles". The trigger was the second main gate's Z step A5, which went red. The cold first-join FREEZE had medians of 25.23 s at Z and 23.96 s at Y''', against a pass rule of 24.85 s (record: /mnt/project-files/server-client-split/NEXT_MAIN_GATE.md, A5 ruling and its follow-up). Evidence cited here under /mnt/project-files/ is the project's shared folder, not in this repo.

Dave's recorded stance (BugsList_Current.md, BugsList 93, and TODO.md, 21 Nov) is that a long first load is "not a problem. its expected on the first load", and #1405 shows a note saying so. This plan is lag-list work picked by the coordinator, not a request from Dave. Whether the second main merge waits for any of it is his choice.

## What the logs already show

- **Client, cold first join (Z, Y''').** There is one FREEZE gap of about 25 s after the "held item" piece, with a HUNG report. During it, voxel streaming shows 1000 blocks outstanding and the link rtt reads 12.6 s (NEXT_MAIN_GATE.md, A5 follow-up); the coordinator also relays that nothing is received.
  - Those last three are symptoms of the frozen client main thread, not causes. ENet is polled from the main thread, so a frozen client acknowledges nothing; the rtt grows and the outstanding count stays full.
  - The FREEZE comes before any first-shown model. BugsList 93 puts the cause in the cold d3d12 pipeline and shader build of the world materials. On 20 Nov a warm APPDATA cut the longest FREEZE to 2754 and 2988 ms (/mnt/project-files/server-client-split/MAIN_GATE_TONIGHT.md, evening of 20 Nov).
- **Launcher server, the same runs.** Two server STALL lines were first relayed as about 5.7 s and about 25 s. The Z ft1 telemetry has them as 5850 ms and 18269 ms, back to back: about 24 s together, the length of the client's freeze (next section).
- **Older full report** (/mnt/project-files/diag93_X1_hung_report_2026-11-20_17-56-22.txt, build of 20 Nov):
  - Server STALLs of 1791 and 11306 ms during the first join. The client's own main thread also stalled 6475 ms at 17:56:07.
  - The state line after the 11.3 s one names the slowest steps since the last state line: "between frames (rpc handlers, engine) 1791, items 3524, checks 7740". `event_log.mark` keeps each step's maximum since the last state line, so these are not one frame. items + checks = 11264 ms fits the 11306 ms frame. The 1791 most likely belongs to the earlier 1791 ms STALL, whose own line closed before its step mark (inferred; the two lines' timestamps overlap by about 1 s).
  - The same log has "terrain: tile (3, 4) loaded in 2874 ms (file 2845 ms)", which is a 2.8 s file read of the spawn tile.
  - On that build, "items" was `items.tick` plus `_tunnel_tick` and `_send_buried` (option A splits these out as "tunnels+buried"). "checks" is everything after the block delivery in `terrain_server._process`: `_send_held_edits`, `_send_fine`, `store.save_revisions`, `flora.save_removed`, the flag files, and direct `print()` calls. Option A names them "checks" (the tile_changed calls only), "checks: held edits", "checks: fine water", "checks: revisions file", "checks: flora removed file" and "checks: flags, report".
- **Z against Y'''.** Z was about 1.3 s slower on all three runs, and Z adds more start-up work on the server: the resource landscape (#1469, #1500, about 9 tiles on a worker), the animal range jobs (#1484, #1504, main-thread lumps of 34-67 ms per block), and the cave and ore layout. **Settled 22 Nov as the machine, not code** (next section): main itself, re-run in the same session as Z, reads the same as Z. Which part of the machine is not shown.

### Z ft1 telemetry (read 22 Nov, /mnt/project-files/first_load_df896777_ft1_*)

Measured (telemetry and play log line times):
- **Server.** Its main thread stopped twice, back to back:
  - stall A: 5850 ms in "between frames (rpc handlers, engine)", about 02:21:20.0 to 02:21:25.85
  - stall B: 18269 ms in "checks", 02:21:25.85 to 02:21:44.12
  No "SLOW RPC" line names a handler for stall A.
- **Client.** The JOIN lines count from the connect: the server saw the peer at 02:21:13.2. They place the client's 5.3 s freeze at about 02:21:13.5 to 18.8 and its 25.23 s freeze at about 02:21:18.8 to 44.0. This is inferred from the gap lengths and the JOIN stamps.
- **So the server's main thread was stopped from about 1 s after the client's long freeze began until it ended.** Stall B ends within about 0.1 s of the client's freeze. Stall A does not line up with either client freeze on its own.
- **The watchdog.** During stall B the watchdog thread wrote a line every second, so the server process ran and only its main thread was held. During stall A there is a single WATCHDOG line, at its end (02:21:25.853, "silent for 5 s"). The lines due at about 23 s and 24 s are missing, so either the whole server process was held, or its log writing was.
- **The block line, a hypothesis.** The client logs "the block line closed; blocks come over the game connection" just before its long freeze. Block-line workers send with `StreamPeerTCP.put_data`, which blocks while a client reads nothing, and they hold the line's mutex while they do. But the state lines just before and after (02:21:19.286, 02:21:44.123) show "queued urgent 0 prefetch 0, in work 0", so nothing shows that workers had blocks to send. Option A's counter tests this.

Open questions:
- What held stall B? Option A splits "checks" into its calls.
- What held stall A, and was it the whole process? Both are open.
- Does the client wait on the server in turn? If not, the server's stalls are a symptom of the client's freeze rather than a cause of it.

The CPU reading (cause 1 below) fits these times less well than a wait. The pool's non-high queue, which all these jobs use, also gets only part of the pool's threads (`threading/worker_pool/low_priority_thread_ratio`; the server_items comment says 30 %).

## How the two processes share the PC today

- The Play launcher (`scenes/launcher.gd`) starts the server with `--threads=` set to half of the usable cores. That caps only the server's own block-builder threads, which run at `Thread.PRIORITY_LOW`, plus 2 idle builders, also low.
- The server's **WorkerThreadPool tasks are not capped and run at normal priority.** These include tile prefetch (`terrain_generator.prefetch_tile`), the resource landscape (`server_items._resource_task`), coarse ground, and the flora brush and cover-index chunks (`server_flora._brush_tasks`, `terrain_server._cover_tasks`). "Normal" here means the pool's non-high queue (`add_task(..., false)`); NEXT_MAIN_GATE.md calls the same queue low. The log-line prints in server_items and server_flora go to the high queue. The item save writer and `_bury_thread` are their own Threads at the default priority. Godot's pool size is one thread per core by default, as far as I know the engine (an assumption, not checked here); the project sets no `threading/worker_pool` setting. On a 12-core PC the server alone can have 6 low builders, 2 low idle builders and up to 12 normal pool threads runnable during the client's cold shader build. The driver's shader compile threads are assumed to run at normal priority too (not checked).
- `terrain_generator.get_tile` reads a tile once. Any other caller, the main thread included, spins on `OS.delay_msec(5)` until that read is done. A main-thread call on a tile that a starved worker is still reading therefore waits as long as the worker does. #1503 removed the periodic main-thread tile reads on the position-report path, but player actions (fishing, drinking, digging) and `ground_height` still read.
- Both processes read and write the same disk at the first load. The client copies the starter ground and writes its shader caches; the server reads tile files and writes saves.

## Candidate causes, most likely first

The Z ft1 telemetry above adds a cause that now fits best: 0. **the server's main thread is held by something tied to the frozen client** (the timing is measured; what holds it is not named yet). The four below were written before that telemetry was read.

1. **CPU oversubscription.** The client's shader build plus the server's uncapped, normal-priority pool tasks, with more of them since #1469 and #1484. It was written to fit the extra 1.3 s at Z, which is withdrawn (that was the machine, see below), and the server STALL matching the client FREEZE (the ft1 timing above puts the stall about 1 s after the freeze starts). It is inferred, not measured.
2. **The server main thread waiting on a starved worker.** This happens through `get_tile`'s wait, or through a lock a pool task holds (the flora lock, the store). This fits a STALL length close to the freeze. It is inferred.
3. **Synchronous main-thread work in the server's "items" and "checks" steps at the first join** (3.5 s and 7.7 s on 20 Nov). Which sub-step is slow is not yet measured. Candidates are the save writes (`save_revisions`, `save_removed`), `_send_held_edits` and `_send_fine` on a new player, and direct `print()` on a debug build. The client fix #1491 shows that a main-thread print can take 0.4-1.6 s there.
4. **Disk contention.** The 2.9 s spawn-tile read against the client's cache writes on a cold run. This adds to 1-3 but is unlikely on its own to make 25 s.

## Options, lowest risk first

| # | Option | Risk | Expected effect | What it needs to test |
|---|---|---|---|---|
| A | **Measure first.** Sub-marks inside the server's "items" and "checks" steps, a server-side "pool tasks running/queued" count on the state line, and the server's 10 s report prints moved onto a worker (`items._log_off_main`). The other direct prints stay: the rare ones, and "Client %d connected" on the join path. | Very low: logging, and print order only | Names the slow step, so B to E aim at it (measure before fixing: docs/PONYTAIL_RULES.md) | Change plan on Lane B (smokes dedicated_stop, play_stop, join_remote); one cold windowed Play on Lane A to read the new STALL breakdown |
| B | **Hold the server's start-up jobs while a player is joining.** The local Play server starts the resource landscape, range jobs and similar after the first player reports ground ready, or after a fixed time, whichever comes first. A dedicated server starts them at once, as now. | Low to medium: a job order change, and nothing in the world differs once done | Less pool load during the shader build, if A shows that matters (Z's +1.3 s, its first reason, was the machine) | Change plan; Lane A 3 cold windowed Plays, median FREEZE against Y''' and Z; a check that the resource landscape and ranges still finish (their existing tests, plus a Lane B log line) |
| C | **Cap the server's pool on Play.** The Play server's own pool tasks go through one small queue with its own cap (for example half the cores, the same as `--threads`), instead of straight to `WorkerThreadPool.add_task`. Godot has no per-process command-line override for `threading/worker_pool/max_threads` that I could find in this repo, so the cap is ours. | Medium: touches every server pool user; a too-small cap slows block and tile service | Bounds the server's share of the PC while the client builds shaders | Change plan plus the timing tests (flora walk cost, stock poll cost); Lane A 3 cold Plays; Lane B dedicated smokes to confirm dedicated servers are unchanged |
| D | **Take the measured main-thread steps off the server's main thread.** Whatever A names, for example the save writes into the existing writer pattern, or a new player's held edits sent over several frames. | Medium: depends on the step; saves need the crash-safety checks of #1473 | Removes the STALL's own share | The owning tests for that step, plus Lane B save and resume tests (test_area_saves, test_resume_spot) |
| E | **Lower the whole Play server process's priority** (below normal on Windows). | Medium to high: needs a platform-specific launch (`OS.create_process` has no priority); the Linux and dedicated paths must stay as they are | Gives the client first claim on every core | A Windows-only lane check (Lane A); Lane B confirms Linux is unchanged |

The client's own cold shader build (BugsList 93) is the larger part of the 25 s and is a separate track. It is the targeted warm-up, once Dave's play log names the first-shown stalls. That work and these options add up; they do not replace each other.

## fd5eed2c ft1 telemetry (22 Nov) and the block-line send fix

- The server's main thread stopped from 0.1 s after the client's long freeze began (04:58:42.94 against 42.83) until about 0.9 s before the client was free (04:59:07.03 against 07.96): 4845 ms "between frames" (again no WATCHDOG line inside it), then 17782 ms in "items", which its own slow line puts in `_vitals_tick` (17779 ms). Nothing on that path reads a file, sends or prints, and the flora lock printed no wait. In Z the same stretch sat in "checks". So the main thread is held wherever it happens to be (inferred), not by one step's work. Block-line sends in progress were 0 throughout, so a frozen client was not holding it. Tile file reads took 3.0 to 9.9 s in that window.
- The read found a real hole elsewhere. Block-line workers sent with `StreamPeerTCP.put_data`, which waits until the socket takes everything (Godot's `write(..., p_block = true)` polls with no time limit), with that player's line lock held. A game that stops reading could hold every worker that took one of its blocks, and every player's blocks waited. The fix sends with `put_partial_data` into an outbox per player that the line's thread writes on. While that outbox is full (`block_line_outbox_kb`, 8 MB), further blocks go over the game connection and the line stays, so nothing the line took is thrown away for a slow player. A line that takes nothing for `block_line_stall_ms` (60 s, the ENet timeout's minimum) while blocks wait is dropped; what its outbox held is lost, and that game asks again (the ground watchdog during a join, otherwise when it next needs the blocks). Both limits are in data/network.json. Test: test_block_line_stall.

## The 1.3 s was the machine, not code (22 Nov)

Lane A ran these cold windowed Plays in one session in the night and morning of 22 Nov (coordinator's relay; record in NEXT_MAIN_GATE.md, A5 follow-up):

| Build | Longest FREEZE (ms) |
|---|---|
| main d6801991 (3 runs) | 25797, 25161, 25065; median 25.16 s |
| Z df896777 (median of 3) | 25230 |
| dev b91852d3 (median of 3) | 25167 |
| 9c252970, before the landscape and #1484 (1 run) | 25497 |

The same main tree gave a median of 23.96 s on the evening of 21 Nov. So the gap between Z and Y''' came from the PC, not from Z's commits. The boot and the driver (610.88) were the same, with no updates. New since the Y''' runs: Firefox (about 16 processes) and a video player were open, and the GPU sat at 21 % load with the lane stopped. These happened at the same time; they are not shown to be the cause. The NVIDIA driver cache (DXCache, 22.4 GB, 293 files) and D3DSCache (33 MB) were warm in every run.

"Cold" in the lane jobs means a fresh APPDATA, TEMP and TMP in a new clone (LANE_JOBS_Z.md). That clears whatever Godot keeps under user:// (terrain_cache in this repo, and the engine's own shader caches, by general knowledge, not checked here). It does not clear the machine-wide driver caches that the lane saw warm (DXCache, D3DSCache), which as far as I know live under %LOCALAPPDATA% (not checked). The project renders with d3d12 (project.godot), so the driver's compiled pipelines most likely persist between runs (inferred).

### Proposal for the gate's frame-time step (for Dave; not in force)

What to log before each cold run, as a lane-job change and docs only:
- other processes that use the GPU or much CPU (from Task Manager's GPU column or `nvidia-smi`), and the GPU load while idle
- the driver version and the size and file count of the driver caches (DXCache or DxcCache, D3DSCache)
- the wait between the clone's import and the Play (the import writes about 5,570 files to `.godot/imported`; a virus-scanner or indexer effect on those is possible but not measured)

How the FREEZE limit could hold up when the machine state changes. Today the limit is a fixed number (24.85 s) set from the 20 Nov X runs. Options, recommended first:
1. **Same-session comparison against main.** In the same session, run 3 cold Plays of the candidate and 3 of current main, interleaved (main, candidate, main, and so on). It passes if the candidate's median is no more than a set margin above main's median. The margin is Dave's pick: about 4 % (1 s) is one choice, roughly where 24.85 s sits above the 23.96 s main later measured; runs of one build spread about 0.7 s, so a smaller margin would fail on noise. Whether 1 s is enough is not measured. Drift then affects both sides equally. It adds 3 Plays, about 10 minutes by estimate.
2. **A clean-machine rule.** The fixed limit stays, but the run only counts when no other GPU program is open and idle GPU load is under 5 %. Otherwise the run is repeated. This is simpler, but it depends on the lane cleaning up a PC that Dave is using. The lane must not close his programs.
3. **Record only, no limit.** The FREEZE goes on record, and only a jump far beyond noise (for example more than 3 s over main) holds the gate. This matches Dave's stance that a long first load is expected (BugsList 93).

The long-term item stays BugsList 93 itself: the client's cold shader build of about 25 s.

## Recommendation

1. Do **A** now. It is safe before or after a main gate and turns causes 1-3 from inference into numbers.
2. Then do **B** only if A's logs show the pool busy with start-up jobs during the freeze. Z's extra 1.3 s turned out to be drift (above), so B no longer has that reason. Its trigger is ruled: the first player's ground ready, or 120 s after server start.
3. Do **C** or **D** only if A's numbers point there.
4. Keep **E** as the last resort.
5. B to E should land after a main gate, not just before one. Each changes timing on the first join, which is what the gate's A5 step measures.

## Open questions (for the coordinator)

- Answered 22 Nov: the Z ft1 server telemetry has them as 5850 ms ('between frames') and 18269 ms ('checks'); see above.
- Answered 22 Nov (coordinator): B's trigger is the first player's ground ready, with 120 s after server start as the fallback.

## 22 Nov: Vulkan on Windows

The client now uses Vulkan on Windows (#1544). Lane A cold plays on e0c1ef58: longest FREEZE median 7959 ms on Vulkan against 23910 ms on d3d12, ground ready +22.6 s against +48.7 s. On Vulkan the server STALLs during the join were 600-700 ms (d3d12 runs up to 13 s), which fits the CPU-starvation reading above: the shorter client build leaves the server its CPU. The driver cache folders named above are the d3d12 ones; on Vulkan the NVIDIA driver keeps its pipeline cache under %LOCALAPPDATA%\NVIDIA\GLCache (general knowledge, not checked on the lane PC). Options B to E are not needed for now.
