# Handoff: Jason "Champ" (audio), 5 Nov 2026

Scope: `SCOPE_JASON.md`. Sound map and hook audit: `docs/SOUND_MAP.md`. Findings record: `SOUND_AUDIT.md` (repo root). Live backlog: `/mnt/project-files/backlog/jason.md` and `/mnt/project-files/BACKLOG.md` (Jamie assigns jobs). One branch per task, `claude/jason-YYYYMMDD-*`, cut from main.

## Rules in force
- No cloud testing (Dave, 5 Nov): no Godot runs, renders or `tools/run_tests.sh` in the cloud. Only static checks (`merge_check.py`). Tyler runs tests on Dave's PC while Dave is not playing, and merges.
- Work goes top down by Dave's priority order in BACKLOG.md; when idle, take the next open job at the highest rank. Make up nothing new.

## Merged since 1 Nov
- #300 skill-up sound: a soft wooden tock, at most once every 20 s.
- #314 weather sound bugs (BUG-002, 003, 004): no birds in rain, no far fish plops, one fire loop.
- #327 BUG-005: one weather gate for every bird and insect sound.
- #337 lag: settled water is re-asked less and less (logic in `src/client/water_reask.gd`).
- #343 lag: settled water is published again only when a level moves 1 cm (`levels_moved` in `water_hub2.gd`, test `test_water_notify`).

## Open PRs (wait on Tyler's PC run and Dave's play)
- #358 night wind bed made quieter (`BED_TRIM_DB` bed_night -32 dB) and the stomach growl removed (oggs in `proposed_removals/`).
- #366 settled chunk water stays drawn inside the live window where the live sim has drained it.
- #370 water debug keys moved to Ctrl+Shift+F7 / F8. Ctrl+Shift+W was fly down + faster + forward, so flying hid all water.
- #374 grass build spike (rank 2): grass cell build resumes per row of ground points at the 5 ms deadline. Agreed with MikeW. Not yet run in Godot.

## Waiting on Dave
- BUG-001 storm sound: Dave to name the sound he heard ("storm_growl" is not in the repo).
- Dave's two footstep recordings (step_gravel_left, step_stone_left, variants 1 and 2) clipped at +0.2 dB: trimmed to -1.2 dB peak with declip.py on 6 Nov (Dave: go with the recommendation).

## Parked (new sound, after "no new stuff" lifts)
Nest sound cue with MikeW (hook `net.nests_received`, #335); cave den sounds after animal spawns; a Pixabay clip to replace the stand-in fish_land. Older hooks still without a client event (sleep, hurt, bow, fishing, animals, clothing, craft, level-up) are listed in `JASON_NEXT_TASKS.md`.

## Risks
Licence record has TODOs (Pixabay page URLs; no rows for the voice files). Every sound claim in these docs is read from code; only Dave's play confirms how it sounds.
