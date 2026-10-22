# MASTER RESTART CHECKLIST (Guru, 2026-10-22 16:00). Dev is paused until Dave says "go". Sources: all approved decisions (DECISIONS.md), CONCERNS_RESOLUTIONS.md, JOBS.md, questions/LATER.md, handoff/*_002 files. Priority P0..P3 per BP-T23. Items marked GAP were NOT on any list before today.

## Phase 0: before "go" (docs/safety; mostly done)
- [x] Team, names, BP, digests, ledger, mirror, design reading (BP-T20..T28). Owner: Guru.
- [x] Questions page cleared; old 11 checks parked in questions/LATER.md.
- [ ] P0 Backup: MikeW first supervised run (Dave closes Godot, says "run backup"); then 14 dry-run nights; monthly restore drill. Owner: MikeW, Dave. (BACKUP_PLAN.md)
- [ ] P0 Dave: download art/engine backup zips (attached to thread message). Owner: Dave.
- [ ] GAP Dave's `digs.dat` and saves exist only on his PC: covered by backup `server_store`, verify at first run.

## Phase 1: restart mechanics (coordinator + Guru + MikeW; first hour)
1. Dave: GitHub Desktop Fetch + Pull, then CLOSE the game fully (server restarts, builds 614/621/632/629/636/641/645 are server-side). Owner: Dave.
2. Coordinator: re-arm moderator (30 min, list_threads since last check); assign per-thread branches `claude/<sal|sonny|steve|kathleen|mike>-<topic>` (cc-branches); wake only threads with queued jobs; keep `-held-` branch ignored. Owner: coordinator.
3. MikeW: warning baseline file (233); permission rules check; `.gitattributes` LF (done); tools/godot.cmd; second clone `DynastyALWL_test`; time the 882 tests and python checks; keep-awake; CI prerequisites (check_controls.py, items_check.py). Owner: MikeW.
4. Guru: daily BP check + log; mirror docs; role digests refresh; first code audit (C11 server authority, C90 save versions). Owner: Guru.
5. Guru: add CI workflow (C85) after MikeW's scripts pass. GATED.

## Phase 2: first work group (Dave's order: crashes, saves, version check)
Steve_ProblemSolver (P1 chain):
1. BUILD const to src/shared/build.gd; tools/next_build.sh (advice only); merge-time numbering by Guru.
2. Build-id handshake in welcome (empty id = match; joined-server message; launcher restarts only its own server; drop pid-kill; F3 shows server commit). Protocol bump.
3. terrain_client.gd split, one feature per build: rescue.gd (merge Willy's rock rescue + void rescue), link bars, join window. MikeW headless check each.
4. Crash hunt from Dave's next telemetry; keep RESCUE line; compaction kill switch stays.
5. Quick-key flake and plantpick failure: fix or list as known-failing baseline.
6. GAP Saved player positions (players always spawn at world spawn today) + clean-logout flag (needed before collapse). 
7. Server stalls list (server_items.tick, _bury_plants, welcome building); per-peer action rate limits (parked by focus rule, keep parked).
Guru reviews each protocol/save/shared-file push before merge.

## Phase 3: water and ground (Sonny, World)
1. tools/probes folder + test_head_pond_fill.gd (would have caught the 623 bug).
2. Slab / brown squares: needs Dave's Ctrl+Shift+W answer (LATER.md check-628) or park (RULE 2).
3. Bracing step 1 (tunnel watch stays OFF; collapse OFF). Read EXCAVATION_BRACING_GROUND_DESIGN.md + Willy_002_NOTES.md first (Willy retired). GAP: add saved wall clock for timers (C92) and admin overlay of working cells.
4. Chute gate for the NEXT BAKE bundle (south spill chute B, pond-outlet carve limit, TERRAIN_VERSION 26): 882 tests + edge match + scratch before/after hashes (MikeW runs on PC), Kathleen hillshade look review, flow-split probe (fallback option A), Guru names the commit. Bake itself = Dave only. GAP: no bake date/steps for Dave yet: Guru writes the "Dave's bake steps" doc when the gate passes.
5. Settle-time numbers warm/cold, flood plan steps A to D (parked by focus rule).

## Phase 4: items and building (Sal_Crafts)
1. Wait for/coordinate with the terrain_client split; then server_items.gd split (back up saves first, old-save load test, world-state numbers append-only), then container model + chests.json migration.
2. structures.json carries look, clears_grass, sound; PieceLook table (written by Sal, Kathleen swaps looks); inventory_view.gd split with Kathleen.
3. Fire store panel refresh; F opens workbench/forges; doorway door; roof/wall corner joins; bracing items (props, sets) once Sonny's ground timer exists.
4. Rest/shelter lookup after Steve_PS's logout RPC; shelters without owner count once slept in.

## Phase 5: art and sound (Kathleen)
1. Deterministic asset scripts (one build with waveform byte-compare; approved sounds as regression set); CREDITS.md rule.
2. look_sheet scene for MikeW; one screenshot per new piece + F3 sounds-heard line.
3. Tunnel warning sounds heard once by Dave (admin test call) and a visual/text warning that does not depend on sound, BEFORE collapse can be enabled; dust particles at roof.
4. Parked: animal quads patch (handoff/Mandy_002_animal_quads.patch), beach sound question (footsteps vs waves).

## Phase 6: Dave-facing
- GAP One regrouped test card from LATER.md's 11 checks plus TEST_QUEUE (builds changed since; many may be moot). Question cl-tests on the page.
- Collapse enable gate (all four: second approval, Dave test card, 90 s warning + visual warning, logout flag, rest lookup). Not before Phase 2 item 6 and Phase 5 item 3.
- Reports: succinct; "Finished:" alerts; phone alert when all threads done.

## Docs and process upkeep (Guru, daily)
- BP check + log; mirror; ledger review; queue audit; LESSONS tags; digests; DESIGN_CHANGELOG lines.
- GAP Fold Dave's answers into DESIGN_IDEAS.md (no music, wolves, footsteps 15 m, NPC mutter, 1000-player target, bracing/collapse rules, shovel/pickaxe ladder, logout vs disconnect): no owner after Steve retired. Owner: Guru (docs only). Also add the bracing design to DESIGN_IDEAS 11.2 as [Decided] (Willy_002 note).
- GAP Update `items/` docs and README pointers for renamed threads (Radar to Sal_Crafts, etc.) in handoff files; old _002 handoffs keep old names, noted in JOBS.md.
- GAP HANDOFF.md "Current state" must be refreshed at restart (latest build, what is paused).

## Unverified bugs carried over (do not lose)
Launcher replace-old-server path never run end to end; "under the world after rock dig" cause unknown (rescues hide it); spade "does nothing" and stuck-on-hole-rim unconfirmed; new lake by head pond (only Dave's digs.dat can settle it); connection window look never seen on screen; pit-wall panels and F2 Low check; quickkeys/plantpick tests; cold-join items step 1.4 s and 4.8 s.

## Decisions needed from Dave (question page)
cl-bake (when the next bake happens), cl-tests (what to do with the 11 old checks).
