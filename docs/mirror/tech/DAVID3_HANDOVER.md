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
| Terrain tile bakes (big or small), river settles, island table, backups | MikeW by default. David3 as OVERFLOW when MikeW is busy and I assign it (Dave 24 Oct 19:13) | Dave's rule |
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

## Bakes on David3 (overflow only; limits 8 CPUs, 10 GB RAM, lowest priority; ~300 GB under /data/godot)
- Command in the box: `run_jobs.sh bake <code-commit-id> [--tiles "x,z;x,z"]` (default: the tiles already in that commit). It uses a SECOND clone (/work/bake = /data/godot/box/bake), checks drainage_mode is true, runs bake_tiles.gd --threads 6, settle_water.gd per tile (7200 ticks), island_checks.gd, writes docs/bake_<8hex>/island_table.txt with the code commit id (BP-T54), and pushes `claude/david3-bake-<8hex>` (tiles via git, BP-T53). I merge code and tiles together on a PASS. Never in the cloud.
- NOT yet copied from MikeW's recipe: stitch.txt, breach_pits.txt, river_settle_report. David3 and MikeW compare the first David3 bake against a MikeW bake of the same commit (tiles byte-identical) before I merge any David3 bake.
- Space: a bake commit adds about 55 MB tiles + 1 MB water; the second clone about 2 GB; each run folder is small. `run_jobs.sh cleanup` runs after every bake: keeps the newest 40 run folders and at most 40 GB in /out, touches nothing outside /data/godot/box.
- Same guards: PAUSE file, load 6 or more waits, claude/* branches only.

## Pictures
PICTURES (Dave 24 Oct): ask for any game picture through the coordinator (it goes to David3 on the server box); the pictures live on branch claude/box-results: results/PICTURES_INDEX.md (what exists), results/PICTURE_REQUESTS.md (what is asked), a README in each folder. Read there first; do not ask Mike for pictures while Dave's PC is busy.
