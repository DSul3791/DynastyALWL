# Handover: David3 (server box) takes over running all tests. Tyler, 24 Oct 2026
Starts when David3 has finished its first test (selftest + gitcheck pass, one test shot made). MikeW keeps every terrain tile bake.

## Who runs what
| Job | Runner | Why |
|---|---|---|
| parse_scan, local_check, validate_items, check_addons, item_master, check_controls, sound_check | David3 (cloud Python ones also run in the cloud) | headless |
| All 78 `test_*.gd` in src/worldgen/tools (worldgen, water, server items, first hour, persistence, tunnels, weather ...) | David3 | headless, no graphics |
| island_checks, island table check on a pushed bake | David3 | reads the baked tiles |
| One-picture shots (spawn, a spot, a held item) | David3 | GPU under Xvfb (software fallback), labelled "server GPU" |
| look_rig rows (--showroom, --flora, --pieces, --views, --frametime) | MikeW until ported; then David3 | look_rig.sh is Windows-only (cygpath, python, E:\ paths). First task for David3 after the handover: a branch claude/david3-rig that makes it run on Linux, Windows kept working |
| Terrain tile bakes (big or small), river settles, island table, backups | MikeW ONLY | Dave's rule |
| QA look/sound/feel cards, first start after Pull on Windows, F6 play, anything needing a play session | Dave's PC (Mike drives it) | needs a person and the Windows client |
| BUG-001 join hang | David3 for the fresh-clone repro in the box (watchdog test); Dave's PC for the real Windows start | |

## Rules for David3 (the brief)
1. Work only in the box. Branches `claude/*` only; never main, never generator-v2 (Tyler merges). Results go to branch `claude/box-results` (summary + small jpgs) with `run_jobs.sh publish`.
2. Report every run as ONE block: `Test done: N pass, M fail`, then the failing lines, then the results path. Pictures: say "server GPU" or "software" and the time taken.
3. Before every run: `/out/PAUSE` exists -> do nothing and say so. Server load 6 or more -> wait. Check `nvidia-smi` before pictures; skip them if the GPU is busy.
4. Tested ids only: a branch passes only for the exact commit id you ran. Give the id with the result.
5. Queue file: tools/docker/queue.txt format (runner per line type). A `bake` line is MikeW's; a `play` line is Dave's.
6. Never touch the game containers, /data/godot outside box and projects/dynasty, or any key file. Never paste keys or tokens.
7. First job after handover: run the 5 lines in queue.txt on generator-v2, report, then the rig port branch.
