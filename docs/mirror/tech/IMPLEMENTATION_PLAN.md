# Implementation plan for the five approved decisions (Guru, 2026-10-22). Docs only until Dave says go.

Gate for every step marked GATED: Dave's go AND a MikeW_LocalAgent run on his PC, because it touches the repo workflow, tiles, or git history. Nothing GATED is done today.

## Step 1: Docs mirror (T18). Not gated (docs only, no history rewrite)
- Technical Director copies md files from tech/, handoff/, items/ into `docs/mirror/<folder>/` and pushes once a day with the BP check. Commit message "docs mirror only". No build number (no code).
- Mirror is read-only: edits happen in project files, then the next mirror overwrites.

## Step 2: Per-thread branches (C107). Needs coordinator set-up
1. Coordinator gives each thread a designated branch `claude/<thread>-<topic>` (thread sessions can only push to their assigned branch).
2. The thread pushes there, does the pre-push checks, and posts "ready: <branch>, job, files" in JOBS.md.
3. Technical Director merges to `claude/generator-v2` in order, takes the build number at merge (max of origin BUILD and BUILD_LOG + 1), writes the BUILD_LOG line, resolves conflicts, deletes the merged branch.
4. Dave's PC still pulls only `claude/generator-v2`; his flow does not change.
5. Fast path: a one-file docs or data fix by its owner may be merged within the same cycle (about 30 minutes).
Risk: Technical Director becomes a merge bottleneck. Mitigation: merge on each moderator cycle, batch small ones, threads keep working on the next job meanwhile.

## Step 3: CI (C85). GATED
- File `.github/workflows/checks.yml`, triggers: push to claude/*, pull request. Jobs: (a) `python3 tools/check_controls.py`, (b) `python3 tools/items_check.py`, (c) conflict-marker grep from PROCESS.md, (d) fail if a push to claude/* adds `*.tile` outside Dave's commits or any crash report/editor log.
- No Godot in CI (custom engine is 66 MB and warnings only show in the editor). MikeW keeps those.
- Before enabling: MikeW runs the three scripts locally to prove they pass on the current tree (so CI starts green).

## Step 4: Save backups (C93). Not gated for the rule; scripted part is code, so Steve_ProblemSolver writes it later
- Rule now: before any protocol, TERRAIN_VERSION or save-format bump the pusher (or Steve_ProblemSolver) copies the server store to `store_YYYYMMDD_HHMM`, keeps the last 3, logs it in BUILD_LOG.md.
- Later (Steve_ProblemSolver, small tool `tools/backup_store.sh`) once dev restarts.
- First backup should be taken by MikeW on Dave's PC before the next bake.

## Step 5: Git LFS for tiles (C108). GATED
1. MikeW checks Dave's PC has git-lfs (GitHub Desktop includes it) and that a clone works.
2. Forward-only: add `.gitattributes` line `*.tile filter=lfs diff=lfs merge=lfs -text`; new tile commits (Dave's next bake) go to LFS. No history rewrite, no force-push.
3. History migration (`git lfs migrate import`) is optional and needs a separate explicit go from Dave; it rewrites commits and breaks every clone.
4. Check GitHub LFS storage/bandwidth quota first (free tier is small; 9 tiles of about 9 MB each plus rebakes may exceed it). If it does, fallback is to keep tiles out of git with a download step. Dave decides then.

## First steps for restart (after Dave's "go")
1. Guru: mirror docs (step 1), post the final BP log line, tell coordinator "BP ready".
2. Coordinator: re-arm moderator at 30 minutes; assign thread branches (step 2); wake only threads with queued jobs.
3. MikeW: run warning baseline, the three CI scripts, git-lfs check, store backup (steps 3 to 5 prerequisites). Report "Test done: X pass, Y fail".
4. Technical Director: after MikeW passes, add CI workflow and `.gitattributes` (GATED, one PR-sized commit), update PROCESS.md.
5. Restart order for workers: Steve_ProblemSolver (crash/persistence), Sonny, Radar, Kathleen_ArtisticDirector. Each reads BEST_PRACTICES entries changed since 2026-10-22.
