# Rules (one file; replaces TEAM_AND_RULES, HOW_WE_WORK and PROCESS, 29 Oct 2026)

Since 1 Nov 2026 Dave runs a team of Claude agents with a moderator coordinating; roles are in `docs/START_HERE.md` and `MODERATOR_QA_LOG.md`. (The October team of the same names, with a Technical Director, was a different arrangement.) Since 11 Nov 2026 work follows the AI Team Operating System (`CLAUDE.md`, `docs/ai-team/`): task branches -> nightly `dev` -> gated `main`; `main` still waits for Dave's go. The old files are in `docs/archive/2026-10/docs/mirror/tech/` for history. `docs/mirror/tech/BEST_PRACTICES.md` stays as the reference library of numbered entries (BP-xxx); look up the entry before anything new.

## Dave
- Dave decides design. He tests at his own pace; Claude never waits on him: park the job and ask the coordinator for the next assignment.
- Reports to Dave are SUCCINCT. Test results: "Test done: X pass, Y fail", one line per failure. Anything Dave must do is numbered steps. Big fix = say so. Times in Atlantic.
- Missing design detail: check settled decisions and scoped delegation in `docs/ai-team/DECISION_AUTHORITY.md`; decide routine details and delegated provisional values, recording meaningful assumptions. Ask one concise question with a recommendation only for a material decision outside authority.
- Questions for Dave: check current designs, decisions and scoped delegation first. Use the coordinator's verified current QA surface for real decisions; if unavailable, keep the question in the current task record and ask Dave concisely rather than blocking unrelated work. The historical `qa` branch and `tools/qa_post.py` workflow are not proof of a live question channel; never merge `qa` and `main` into each other or delete the record branch.
- Safe place: the game never says anything that might divide people. No labels for groups of players; describe the use, never who it is for.
- **Decision 61 (11 Nov 2026; Dave's current explicit clarification, 12 Nov 2026 21:19 UTC, project chat, verbatim):** "When new code replaces old code, the obsolete code should be deleted rather than preserved behind compatibility flags or left as dead code. This does not authorize deleting unrelated assets, user work, historical documents, or anything still required by the game. Documents are archived. Other unused files continue through the existing proposed-removal procedure." (The original 11 Nov wording is not in the repo; the earlier line here was an AI paraphrase.) `tools/merge_check.py` enforces it: deleted code needs a row in the "Replaced code" table of `proposed_removals/REMOVALS.md` naming its replacement, and no live use left (game files, runner scripts, CI); code with no replacement is an ordinary unused file; deleted documents must be archived under `docs/archive/`; other files follow the line below.
- Other unused files are not deleted: they move to `proposed_removals/<original path>` (add `.removed` to .gd, .tscn, .tres, .uid), with one line in `proposed_removals/REMOVALS.md` (who, date, why, replaced by). Dave approves removals. `tools/merge_check.py` fails the merge if such a file vanished and isn't there, or has no `REMOVALS.md` line.
- Never commit crash reports, editor logs, temp DLLs or `.tile` files.
- Usage: pace the weekly tokens evenly (resets Wed 03:00 Atlantic). Do the work directly; use the local Qwen model only for bulk reading. At the bedtime backup, ask Dave for the weekly percent and log it in `C:\GodotProjects\Claude_Usage_Log.md`.

## Git
- `main` is protected and stable: pull requests only. Nothing is committed straight to `main`; no force-push. Nothing reaches `main` until the full merge gate passes (`docs/ai-team/TEST_GATES.md`) and Dave says go; on his go, back up first as before. (This outranks the `WORKFLOW.md` line on routine promotions until Dave changes it.)
- Flow since 11 Nov 2026 (Dave): each task works on its own branch (`claude/<task>`) cut from `dev`; reviewed branches are integrated into `dev`, fully committed every night for Dave's playtest; promotion to `main` is a reviewed PR. Agents never push to `main`. (The 1 Nov per-day integration branch and the 2 Nov rule against any daily branch are superseded; history in `docs/ai-team/KNOWN_CONFLICTS.md` #1-2.)
- `tools/ship.sh` (pushes `ship/build-N`, merges the PR with `tools/pr_merge.sh`) is the October way into `main`; use it only for that last step, with Dave's go.
- Before handing a branch to the coordinator: fetch current `dev`, reconcile relevant intervening changes without rewriting others' work, check conflict markers and `python3 tools/merge_check.py`; run touched-script Godot parsing on the authorized PC and controls checks when applicable. Review the final diff and evidence under `docs/ai-team/TEST_GATES.md`; documentation-only work does not require Godot. Label each change RUNTIME (no restart), RESTART (close the game after Pull) or BAKE (needs a tile bake).
- Build number: the HUD number lives in `src/shared/build.gd` and is raised only by `tools/ship.sh` at the last step into `main` (it also appends `docs/mirror/tech/BUILD_LOG.md`). Agents on branches do not touch it.
- Bakes: never bake or commit tiles in the cloud. A `TERRAIN_VERSION` change ships only with a bake.

## Code
- Typed GDScript; zero new warnings; no `@warning_ignore` without a reason. Baseline checked by `tools/local_check.sh`.
- Server and client talk only through `src/stream/terrain_net.gd`; shared code in `src/shared`.
- Any input change updates `CONTROLS.md` and passes `python3 tools/check_controls.py`.
- Significant architecture/contract changes need Dave's authorization: code organization, network protocol, save formats, block store, `TERRAIN_VERSION`, cross-system shared constants, new dependencies/native code and unbudgeted per-frame cost. Check existing scoped approval first; routine implementation within an approved contract does not need repeated approval (`docs/ai-team/DECISION_AUTHORITY.md`).
- After client, server, streaming, flora or water changes, run the performance routine and say what it costs at the Low tier.
- Item numbers: the task's assigned item-data owner controls `data/items/items.json` (`next_number`); action IDs and protocol bumps have one assigned owner for `src/stream/terrain_net.gd`. Record current ownership/reservations in mission state and coordinate before allocation. Stable numbers are not reused; `tools/merge_check.py` fails duplicates. Historical role names and the October `ID_CLAIMS.md` list are not current ownership locks.

## Testing
- Test first yourself (headless tests, look rig `tools/look_rig.sh`, the spawn showroom); only human-judgment checks go to Dave.
- Run tests with `tools/tests_for_diff.py` and `tools/run_tests.sh` (put `tools/` on PATH so `godot` resolves).
- Per change: `tools/tests_for_diff.py <base> <head> > plan.json`, then `tools/run_tests.sh --plan plan.json` (seconds to a minute). Small fast tests cover drainage, live water, the water hub and the erosion delta. The big tests on the real baked tiles run per change only when baked tiles, water data or plan files change.
- Before a release or after a big world or water change, run `tools/release_check.sh` by hand (every test, about 7 min). There is no nightly schedule.
- Ground tests: look down at the spot, step back about 1 m, say what you expect, then stop.
- No chasing ghosts: fix only with a log, a repro or a screenshot.

## Where things live
`HANDOFF.md` (commands, setup, gotchas), `BIG_PICTURE.md`, `DESIGN_IDEAS.md`, `PROTOCOL.md`, `CONTROLS.md`, `WORLD_FORMAT_SPEC.md`, `ARCHITECTURE_BUDGET.md`, `tech/ACTION_PLANS/` (four plans still cited by code and data or not fully built; the other 41 finished October plans are in `docs/archive/2026-11/tech_ACTION_PLANS/`), `docs/mirror/tech/` (BUILD_LOG, DECISIONS, QA docs, backup and restore plans). QA page: https://dsul3791.github.io/DynastyALWL-QA/

## Heavy Godot jobs share the PC (Tyler, 31 Oct 2026)
At most 3 test or rig jobs run at once on this PC, across all sessions: `tools/run_tests.sh` / `tools/run_one_test.sh` take a slot from `tools/godot_slot.sh` on their own. For anything else that starts Godot for a while (picture rigs, servers and clients, probes), wrap it: `tools/godot_slot.sh godot --path . ...`. `GODOT_SLOTS=0` switches the guard off, `GODOT_SLOTS=N` changes the number. It never kills anything; a slot whose job is gone is taken over.
