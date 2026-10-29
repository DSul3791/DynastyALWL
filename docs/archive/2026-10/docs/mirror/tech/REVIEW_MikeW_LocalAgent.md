# Process review: MikeW_LocalAgent (runs on Dave's PC)

Written 2026-10-22 from BIG_PICTURE.md, HANDOFF.md, HOW_WE_WORK.md, BEST_PRACTICES.md (skimmed) and hands-on runs on Dave's PC. The doc set matches my role (warnings, headless tests, long runs, RULE 3); points below are gaps in it, not disagreements.

## What works
- The PC can do all local work: Godot 4.7.2 editor exe, `gh` logged in, Git bash, Python. Measured: addons load 0.3 s, validate_items 2 s, check_warnings.sh 21 s (233 warnings, 321 scripts), a short test 0.35 s. These are tiny next to a cloud checkout, install and build.
- `--script` runs are fast and clean. Pull and push work now that the permission rules are committed.
- BIG_PICTURE.md is a short, good first read. HANDOFF.md now holds the exact local commands.

## What hurts local builds and tests
- **Permission checker.** Auto mode refused fetch, pull, commit, push and writing its own settings, and ignored chat approval. Cost: about 10 round trips and Dave's time. Fixed by the committed rules; confirm they survive a session restart.
- **Bare `godot --headless --path .` starts the game launcher and a terrain server** (left a process running once). Only use `--script` or a named scene.
- **Dirty tree.** 22 uncommitted files (crash reports, `.uid`, the `~libwatercore` temp dll). They confuse GitHub Desktop and make pull/stash risky. HANDOFF.md edits were lost once to a discard.
- **No baseline for warnings.** check_warnings.sh prints 233 but nothing says which are new; `--changed` needs a pushed base.
- **Bash gaps.** `.sh` tools need `godot` on PATH (shim in /tmp, lost on reboot) and `/tmp`; no WSL, no ffmpeg (sound tools).
- **Long tests unknown.** test_worldgen is about 6 min; nobody has timed the full test list locally.
- **Stale reports.** My first branch report was wrong because local HEAD was stale: always fetch before reporting.

## Changes to reach the goals and cut tokens
1. Make local the default for every build, test, warning check and bake; cloud threads only edit and review, and ask me for runs with the exact command.
2. Add one script, `tools/local_check.sh`, that runs addons load, validate_items, check_warnings `--changed` and the tests touching changed files, and prints only pass/fail plus failing lines. Threads read that, not full logs.
3. Commit the warning baseline (BP-C01 quotes 233; today's run also gives 233) as a file, so only new warnings are reported. This is restart step 3; ready to do it on "go".
4. Put the godot shim and PATH setup in the repo (e.g. `tools/godot.cmd`) instead of /tmp.
5. Move crash reports and telemetry logs to `.gitignore`, and keep `.uid` files committed with their scripts, so the tree stays clean.
6. One test runner that lists all tests with timings; run the full set nightly or on request, and the fast subset per change.
7. Reports to Dave stay at 3 lines; details go to a file, not chat.
