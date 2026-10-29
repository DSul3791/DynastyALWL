# Nightly project backup: plan and failure-mode review (P0). Guru, 2026-10-22 15:40. Spec summary: BEST_PRACTICES BP-C110. Restore steps: RESTORE_PROCEDURE.md.
STATUS: awaiting Dave's approval (question bk-plan). MikeW writes NOTHING until approved. Then the Guru reviews the code read-only before the first real run.

## What it is
One Python script `tools/nightly_backup.py` (+ tests `tools/test_nightly_backup.py`) run by MikeW on Dave's PC when Dave says "goodnight". Python, not PowerShell Compress-Archive (that tool has file-size limits and locks files); `zipfile` with ZIP64 and a CRC test. Output: `E:\Software\godotDev\DynastyALWL_ProjectBackups\DynastyALWL_ProjectBackup_YYYY-MM-DD_HHMM.zip`.
Inside the zip: the whole `C:\GodotProjects\DynastyALWL` incl. `.git` (folder `DynastyALWL/`); the `server_store` save folder (top-level folder `server_store/`) (source path recorded in `BACKUP_MANIFEST.json`); the manifest itself (file count, total bytes, SHA-256 of project.godot and .git\HEAD, script version, date). Excluded (listed in the log every night): crash_reports, editor logs, `.godot` cache, `~libwatercore*` temp dll, `*.tmp`, `__pycache__`.

## Order of a run (any failed step = stop, report FAILED, never half-continue)
1. Preflight: E: exists (never fall back to C:), free space >= 1.3 x last zip + 5 GB, game process NOT running (C109), no `.git\index.lock`, clock sanity (new timestamp later than the newest zip's), target name does not exist. Keep the PC awake for the whole run (SetThreadExecutionState).
2. Remove stale `.partial` files older than 1 day (log them).
3. Scan source, count files and bytes, then write `NAME.zip.partial` (same folder), flush to disk.
4. Verify: full CRC test (`testzip`), file count and byte total equal the scan, required paths present (project.godot, .git\HEAD, tile_3_4.tile, server_data), size within 50 percent of the previous zip (outside = WARN, not fail).
5. Rename `.partial` to `.zip` (atomic on NTFS), write `LAST_BACKUP_OK.txt` and `backup_status.json`.
6. Restore test: unzip into `E:\...\_restore_test\` (scratch), run `git fsck --connectivity-only`, `git status`, and the Godot `--script` addons load (0.3 s, proven); delete scratch; log result. Done nightly (disk time only, runs while Dave sleeps). FAIL here = alert even though the zip exists.
7. Cull (only after steps 4 to 6 pass): see rules below. Dry-run mode first.
8. Report one line to the coordinator: "Backup done: <name>, <size>, restore test OK, culled N" or "Backup FAILED: <step>, <reason>".

## Retention and cull rules (Dave 2026-10-22 15:32)
Keep every nightly 30 days. Older: oldest-first; the LAST backup of each ISO week (Mon to Sun, by the date in the NAME; normally Sunday night) moves to `weekly\` (rename, same drive) and is kept forever, the other days of that week go to `_trash\` (Guru changed this from 'oldest' after code review, 2026-10-22 15:50: the code keeps the last of the week, which holds the whole week's work), not deleted. `_trash\` is emptied after 7 days. Nothing in `weekly\` is ever touched by the cull.
Cull safety:
- Acts only on files in the backup folder root whose names match `^DynastyALWL_ProjectBackup_\d{4}-\d{2}-\d{2}_\d{4}\.zip$` exactly. Any other file is ignored and listed.
- Cross-checks the date in the name against the file's modified time; more than 2 days apart = skip and alert.
- At most 3 zips moved per run. With 4 to 7 candidates (e.g. after a few missed nights) it moves 3, alerts, and continues next night until the backlog is gone. With MORE than 7 candidates (a week-plus outage or a clock error) nothing moves and it alerts; Dave present can override with `--max-moves`.
- Never touches the newest 30 days, never the newest zip, never leaves fewer than 30 zips if they exist.
- Every move is written to `backup_log.txt` (name, reason, week, time). DRY-RUN: first 14 real nights the cull only logs what it WOULD do.

## Failure modes and answers
| Failure | Answer |
|---|---|
| Crash/power loss mid-write | `.partial` name, atomic rename, stale partials cleaned; old zips untouched |
| Locked / changing files (game or Desktop running) | refuse while game runs; refuse if `.git\index.lock`; an unreadable non-excluded file = retry 3 times then FAIL loudly (never skip silently) |
| Disk full | preflight space check; write errors = FAIL, partial deleted; cull never runs on a failed backup |
| Bad zip (corrupt, truncated) | CRC test + manifest counts + nightly real restore test |
| Cull deletes the wrong file | strict name regex, date cross-check, max 3 per run, trash with 7 day undo, weekly\ untouchable, dry-run 14 nights, full log, unit tests |
| Clock/date wrong or time zone/DST change | new timestamp must be later than the newest zip; week from the date in the name; cull stops if dates disagree with mtimes |
| E: drive missing/unplugged | FAIL, no fallback to C: |
| Name collision | never overwrite; FAIL |
| Backup silently stops | coordinator expects a report within 30 minutes of "goodnight"; none = alert Dave's phone; two nights without success = P0 alert |
| Backup contains the wrong things / misses saves | required-path check, manifest, restore test |
| Sleep/shutdown mid-run | keep-awake during run; if still interrupted, `.partial` is cleaned next run, FAIL reported |
| Contains private data | stays on E:; no upload anywhere; `.git` has no tokens (MikeW checks `.git\config` first run) |
| Script bug | unit tests on fake folder trees (a year of dates, missing nights, year-boundary ISO weeks 52/53/1, DST days, duplicates, junk files); Guru code review; first real run with Dave watching |

## Rollout (nothing runs unattended until step 6)
1. Dave approves. 2. MikeW writes script + tests; Guru reads code. 3. MikeW unit-tests the cull on fake data (cloud-style scratch folder). 4. First manual run with Dave present: backup + restore test + a manual full restore using RESTORE_PROCEDURE.md. 5. "Goodnight" runs for 14 nights with cull in DRY-RUN; Guru reviews the log. 6. Cull goes live; weekly check of `backup_log.txt` by MikeW report; monthly manual restore drill by Dave (5 minutes).
Estimated size: about 1.5 GB per zip (MikeW measures first); 30 nightlies about 45 GB; plus about 1.5 GB per kept week, about 80 GB a year. Run time estimate: 3 to 8 minutes (MikeW times it).

## Code review additions (Guru, 2026-10-22 15:50, tools/nightly_backup.py e1d4506)
- Restore test needs `godot --import` because `.godot` is excluded. Decision: keep `.godot` OUT (derived cache, can be stale) and keep the import in the restore test (it proves the project really opens). MikeW times it on the first run; if it takes over 10 minutes, the import test runs weekly and the nightly test is git fsck + addon load only.
- Failure must leave a trace: write FAILED lines to `backup_log.txt` and a `LAST_BACKUP_FAILED.txt`; write `LAST_BACKUP_OK.txt` only after the restore test passes.
- If Godot (editor or game) is open the run refuses; the message must say "close Godot completely" (Dave says goodnight, closes Godot, then the run starts).
