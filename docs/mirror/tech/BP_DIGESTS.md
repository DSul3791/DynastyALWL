# Role digests of BEST_PRACTICES.md (BP-T25 / rv-bp-digest, Dave approved). Read YOUR digest + changelog lines since your last "BP read". Full text and "why" in BEST_PRACTICES.md. Written 2026-10-22 by the Guru; regenerate after BP changes.

## All threads (every digest includes these)
- Policy: BP read daily after the Guru's check; before anything NEW find the entry, none = ask the Technical Director and take another job (RULE 4). Priorities P0-P3 (T23). Cross-talk limits (T22). Ideas via ledger (T24). Token habits (T27).
- Zero new warnings (C01). No other thread's code without a one-line announced hook (rv-shared-files). Reports succinct; "Still waiting on:" only if pending (T10). Questions: ask the Guru with your recommended answer; never write to QUESTIONS.md yourself (T33); keep working or park the job. Anything Dave must do = numbered point form, one action per line (T10, Dave 17:07). Never commit crash reports, logs, .tile (C105). Never wait for Dave (T07).
- Push: own branch `claude/<sal|sonny|steve|kathleen|mike>-<topic>` (any branch containing `held` is never merged); merge line names both numbers ("640, was 627"), pre-push checks (C102), numbers provisional until the Technical Director merges (C101/C107). Server-side build = say "SERVER RESTART".

## Technical Director + Guru (Tyler_Guru_SenDev)
C10-C12, C23, C85, C90, C93, C100-C108, T01-T06, T08, T12, T16-T28. Daily: BP check + log, ledger, mirror, queue audit. Merge branches each cycle, renumber, BUILD_LOG. Docs only; no game code. First: code audit (C11, C90).

## Sonny (World: ground, tunnels, bracing, water)
C20-C24 (collapse OFF until second approval + Dave card + 90 s warning + visual warning), C30-C33, C22/C23 (freeze, no tile commits, hash gates: PC baseline, cloud before/after only), C91-C92, C80 (long gates to MikeW). Held branches (`-held-`) never merge. Order: probes + pond fill test, slab hunt, bracing step 1, chute gate. Reviewer for look: Kathleen; sign-off: Technical Director.

## Sal_Crafts (items, crafting, NPCs, animals, buildings, trade)
C40-C44, C50-C52 (CONTROLS.md), C04, T28(c)(d)(e)(l) (one container model; world-state numbers append-only; append columns to saves). Splits: server_items.gd after terrain_client; back up saves first. PieceLook table + structures.json fields: you write them first, Kathleen swaps look functions. Rest/shelter lookup after the logout RPC.

## Steve_ProblemSolver (Systems: server, network, HUD, movement, performance, saves)
C11-C16, C13 (never block the server main thread), C14 (evidence), C71-C74 (cost at Low, performance routine), C90-C93, C84, T28(f)(g)(k). First jobs (cc-first-job): BUILD const file, build-id handshake (empty id = match; F3 shows server commit; joined-server message "close the game and press Play again"; launcher restarts only its own server; drop the pid-kill), then terrain_client split one feature per build (rescue.gd), crashes/saves.

## Kathleen_ArtisticDirector (art, animation, sound)
C60 (present-day systems sound allowed; others on hold), C61, C70-C74 (cost at Low, 128 px textures, MultiMesh, no per-tree nodes), T28(h)(i)(j) (deterministic asset scripts, CREDITS.md, screenshot + F3 sounds-heard line from MikeW), C24 (collapse warning must not rely on sound). Art reading: ART_DIRECTION.md.

## MikeW_LocalAgent (Dave's PC)
C80-C84, C109 (long runs only when the game is not running; check first), C01 (warning baseline), C23 (hash baseline on the PC), C93 (first store backup before next bake), RULE 3. Run via `--script` or a named scene only. Test branches in the second clone `C:\\GodotProjects\\DynastyALWL_test`, never in Dave's folder. Dave answered: long runs OK except while the game runs; PC stays awake. Report "blocked on permission" in one line. Cloud fallback = parse + Python checks, flagged "unverified locally".
