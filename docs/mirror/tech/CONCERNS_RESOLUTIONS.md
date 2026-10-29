# Concerns resolved by the Technical Director (Guru), 2026-10-22 15:30. Source files: CONCERNS_Guru, _Tyler, _Sonny, _Sal_Crafts, _Kathleen, and docs/mirror/tech/CONCERNS_MikeW_LocalAgent.md. Items needing Dave are on the question page (cc-*).

## Decided by the Technical Director (small, technical; no Dave needed)
**Builds and branches**
- Build numbers are PROVISIONAL on a thread branch; the Technical Director renumbers at merge and appends BUILD_LOG (Tyler 2, Sonny 6). next_build.sh is advice only, so the race does not matter.
- Branch names `claude/<thread>-<topic>`; any branch with `-held-` in its name is never merged or pushed to generator-v2 (Sonny 4). Held spill chute stays held until the bake is named.
**Splits (Tyler 1, 5; Sal 1, 2, 4; Kathleen 2)**
- One split at a time, in this order: (1) BUILD const to src/shared/build.gd, (2) terrain_client.gd by feature, one feature per build (rescue merged into src/client/rescue.gd, link bars, join window), each checked by MikeW's headless run; (3) server_items.gd; (4) inventory_view.gd, starting with the PieceLook table (state -> look function), owned jointly by Kathleen and Sal.
- Other threads freeze the file being split (announce in JOBS.md) or use one-line hooks (Dave rv-shared-files).
- Before splitting server_items: copy the save folder (BP-C93) and run one load test with an old save; world-state numbers append-only, never renumbered (Sal 3); container-model refactor only after the split and with a chests.json migration (Sal 4).
**Handshake build (Tyler 3, 4, 10; Sal 7)**
- Welcome carries build id; empty id (exports, no .git) counts as a match; mismatch shows a plain "server is out of date, restarting" message, never a silent drop; replaces the pid-kill launcher only if the pid's start time matches; F3 line shows the server commit.
- Keep the RESCUE telemetry line and the settled_ground kill switch (Tyler 6, 7).
**Tests and gates**
- Gate decisions come from MikeW's run on Dave's PC, not a single cloud pass (Tyler 8; BP-C84). Hash/edge gates: baseline stored once from the PC; cloud scratch bakes compare cloud-before vs cloud-after only, never with Dave's file (Sonny 3, MikeW 1); written into BP-C23.
- quickkeys flake and plantpick failure are listed as known-failing in a baseline file until fixed (Sal 9).
- Probes folder under src/worldgen/tools is allowed during the freeze (no generator change) (Sonny 7). Chute gate reviewer: Kathleen for look, Technical Director signs off (Sonny 2). Flow-share probe: if not cheap, fall back to option A (seal) (Sonny 5).
- .gitattributes gets `*.sh text eol=lf` now (MikeW 3).
- MikeW: first run times the 882 tests and the Python checks, confirms permission rules after each session restart, and reports "blocked on permission" in one line (MikeW 2, 7, 8). tools/godot.cmd goes in the repo (MikeW 5). Cloud fallback if the PC is off: parse + Python checks only, flagged "unverified locally" (Guru 4).
**Safety and design**
- Collapse stays OFF until: second approval, a Dave test card, a 90 s warning, AND a visual/text warning that does not depend on sound; Dave hears the quake stages once via the admin test call (Kathleen 1; BP-C24 updated).
- Deterministic asset scripts as one build with a waveform byte-compare; Dave's approved sounds are the regression set (Kathleen 4). Role digests include C60 and C70-C74 for art (Kathleen 6). look_sheet needs a headed run: MikeW confirms at the first run (Kathleen 3).
- Rest/shelter lookup waits for Steve_ProblemSolver's logout RPC; Radar redoes the draft from DECISIONS.md; shelters without an owner count only once slept in (Sal 5).
- Free-text bug answers: use a `[text]` question or the "Found a problem (I will describe it)" option on the grouped card (Tyler 9; README already allows `[text]`).
- Sonny's slab/squares job parks under RULE 2 if Dave does not answer (Sonny 8). World order inside Sonny's thread: probes folder + pond fill test, slab hunt, bracing step 1, chute gate, then the rest (Sonny 1) (Dave picks the team-wide order: cc-first-job).
**Guru's own**
- Code audit (BP-C11, C90) is the first Guru job after restart; role digests (6) written before the first worker starts; first store backup by MikeW before the next bake; CI after MikeW proves the scripts; ledger checked against chat daily; token savings measured once and recorded in LESSONS.md (Guru 1, 4, 5, 7, 8, 11, 12).

## Sent to Dave (question page)
cc-first-job (restart order), cc-radar-name, cc-long-runs (when MikeW may run long gates), cc-keep-awake (PC stays awake), cc-branches (when per-thread branches start).

## Round 2 (15:55)
- Held rule: any branch whose name contains `held` (Sonny). Pushed copy `claude/sonny-held-spill-chute`; the patch in handoff/ stays the real backup.
- Handshake (Tyler): drop the pid-kill entirely once the handshake exists; message for a joined server "the server is out of date; close the game and press Play again"; the launcher restarts only a server it started itself.
- Merge lines in BUILD_LOG name both numbers ("640, was 627") (Tyler).
- Branch names `claude/<sal|sonny|steve|kathleen|mike>-<topic>` (Sal); the coordinator creates/assigns them at the first job after restart (Dave: cc-branches).
- PieceLook table and structures.json fields: Sal_Crafts writes first, Kathleen swaps look functions (Sal).
- MikeW tests in a second clone `C:\GodotProjects\DynastyALWL_test` (MikeW); Dave answered cc-long-runs (any time except while the game runs) and cc-keep-awake (yes): MikeW may run long gates now.
