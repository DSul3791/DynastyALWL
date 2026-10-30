# Rules (one file; replaces TEAM_AND_RULES, HOW_WE_WORK and PROCESS, 29 Oct 2026)

The old multi-thread team (Tyler, Steve, Sonny, Sal, Kathleen, MikeW) is retired. Today it is Dave plus one Claude session on Dave's PC. The old files are in `docs/archive/2026-10/docs/mirror/tech/` for history. `docs/mirror/tech/BEST_PRACTICES.md` stays as the reference library of numbered entries (BP-xxx); look up the entry before anything new.

## Dave
- Dave decides design. He tests at his own pace; Claude never waits on him: park the job and take the next one.
- Reports to Dave are SUCCINCT. Test results: "Test done: X pass, Y fail", one line per failure. Anything Dave must do is numbered steps. Big fix = say so. Times in Atlantic.
- Thinly discussed design = ask one short question with your recommendation. Technical details: decide yourself.
- Questions for Dave: pickable answers on the `qa` branch, `questions/QUESTIONS.md`, posted with `tools/qa_post.py`; answers come back in `questions/ANSWERS.md` on `qa`. Check HANDOFF, the design docs and DECISIONS first. Never merge `qa` and `main` into each other.
- Safe place: the game never says anything that might divide people. No labels for groups of players; describe the use, never who it is for.
- NOTHING IS DELETED. Unused files move to `proposed_removals/<original path>` (add `.removed` to .gd, .tscn, .tres, .uid), with one line in `proposed_removals/REMOVALS.md` (who, date, why, replaced by). Dave approves removals. `tools/merge_check.py` fails the merge if a file vanished and isn't there.
- Never commit crash reports, editor logs, temp DLLs or `.tile` files.
- Usage: pace the weekly tokens evenly (resets Wed 03:00 Atlantic). Do the work directly; use the local Qwen model only for bulk reading. At the bedtime backup, ask Dave for the weekly percent and log it in `C:\GodotProjects\Claude_Usage_Log.md`.

## Git
- `main` is the base for all code. It is protected: pull requests only. Nothing is committed straight to `main`; no force-push.
- Work on a branch (`claude/<topic>`), ship with `tools/ship.sh` (pushes `ship/build-N` and merges the PR with `tools/pr_merge.sh`). The branch is never deleted by the tools.
- Commit, push and merge only with Dave's go-ahead.
- Build number = max(origin BUILD, last BUILD_LOG line) + 1; the BUILD_LOG line goes in the same commit. Each change is labelled RUNTIME (no restart), RESTART (close the game after Pull) or BAKE (needs a tile bake).
- Before shipping: `git pull --rebase origin main`, conflict-marker grep empty, `python3 tools/merge_check.py`, headless parse of touched files, controls check.
- Bakes: never bake or commit tiles in the cloud. A `TERRAIN_VERSION` change ships only with a bake.

## Code
- Typed GDScript; zero new warnings; no `@warning_ignore` without a reason. Baseline checked by `tools/local_check.sh`.
- Server and client talk only through `src/stream/terrain_net.gd`; shared code in `src/shared`.
- Any input change updates `CONTROLS.md` and passes `python3 tools/check_controls.py`.
- Big changes need Dave's approval first: how the code is split, the network protocol, save formats, the block store, `TERRAIN_VERSION`, shared constants two areas touch, new dependencies or native code, per-frame cost not behind the quality setting.
- After client, server, streaming, flora or water changes, run the performance routine and say what it costs at the Low tier.
- Claim item numbers and action ids in `docs/mirror/tech/ID_CLAIMS.md` before using them.

## Testing
- Test first yourself (headless tests, look rig `tools/look_rig.sh`, the spawn showroom); only human-judgment checks go to Dave.
- Run tests with `tools/tests_for_diff.py` and `tools/run_tests.sh` (put `tools/` on PATH so `godot` resolves).
- Per change: `tools/tests_for_diff.py <base> <head> > plan.json`, then `tools/run_tests.sh --plan plan.json` (seconds to a minute). Small fast tests cover drainage, live water, the water hub and the erosion delta. The big tests on the real baked tiles run per change only when baked tiles, water data or plan files change.
- Before a release or after a big world or water change, run `tools/release_check.sh` by hand (every test, about 7 min). There is no nightly schedule.
- Ground tests: look down at the spot, step back about 1 m, say what you expect, then stop.
- No chasing ghosts: fix only with a log, a repro or a screenshot.

## Where things live
`HANDOFF.md` (state and gotchas), `BIG_PICTURE.md`, `DESIGN_IDEAS.md`, `PROTOCOL.md`, `CONTROLS.md`, `WORLD_FORMAT_SPEC.md`, `ARCHITECTURE_BUDGET.md`, `tech/ACTION_PLANS/` (open plans), `docs/mirror/tech/` (BUILD_LOG, DECISIONS, QA docs, backup and restore plans). QA page: https://dsul3791.github.io/DynastyALWL-QA/
