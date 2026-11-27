# Dynasty engineering workflow
**Status: IN FORCE. Four-rulebook consolidation approved by Dave, 15 Nov 2026.** Authority and delegation: `CONSTITUTION.md`. Required validation: `TEST_GATES.md`. Engineering method: `../PONYTAIL_RULES.md`.

## Branches and ownership
Start from freshly fetched `origin/dev`, read `../../CLAUDE.md` there, and use a scoped `feature/<task-id>-<scope>` or agreed `claude/<task>` branch/worktree. Own only assigned paths. Use one owner per shared file unless the mission defines a reviewed section split. Reconcile intervening `dev` changes before delivery without overwriting others' work. No direct `main` push, force push, history rewrite, gate disabling or deletion of user work.

Reviewed branches merge into `dev` under `TEST_GATES.md`. `main` is a stable milestone: protected PR, complete gate (`MAIN_GATE.md`) and Dave's explicit approval. Never commit crash reports, editor logs, temporary DLLs or unauthorized `.tile` outputs. Verify actual branch protections; prose does not enforce them. Build numbers in `src/shared/build.gd` change only through `tools/ship.sh` at the authorized last step into `main`; branches do not bump them. `tools/ship.sh`/`tools/pr_merge.sh` are not a routine route into `main` without that approval.

## Roles and task lifecycle
The coordinator owns priorities, assignments, shared state, dependencies and escalation; it does not write game code or approve its own PR. Specialists implement within scope; non-author reviewers assess evidence; an authorized PC runner performs machine checks. Roles are responsibilities, not permanent named chats. Honor Dave's explicit model choices; Claude Code definitions do not prove Cowork loads them.

1. Brief (`TASK_BRIEF_TEMPLATE.md`): the goal, the paths owned, and how to know it is done.
2. Read only the design, mission state, code, callers and tests the task touches; not the whole archive or Library.
3. Make the smallest complete fix, self-review under Ponytail, then get independent review under `TEST_GATES.md`. Report unrelated finds to the coordinator; do not start side repairs.
4. Checkpoint before handoff and at milestones: head SHA, what is left, risks. Then ask for the next assignment.
5. Refresh at task boundaries or when context quality drops, saving state first. Close a worker only after its outputs are saved and its ownership released.

Newer explicit priorities govern within scope. Standing fallback priority: bug fixes first (Dave: "bug fixes always first"), and among them anything broken with the ground or water (R-CORE-GROUND-WATER-FIRST); then freezes/lag, testing, first-hour bugs, body/movement, flora/fauna, art, audio, tuning, guides/docs, parked ideas. Weekly token pacing resets Wednesday 03:00 Atlantic. Dave may speak to a worker directly; log substantive changes in shared state and notify the coordinator.

## Integration, playtesting and blocking findings
Claude Code warns before a `git commit` (a bare print() in client code; a key, token or password) and before a `git push` (the rule checks), from `tools/hooks/` via `.claude/settings.json`; these local warnings never block: fix what they name. GitHub checks every file a change touches for the same problems (`tools/warn_watch.py`): a problem is flagged each time its file is touched and blocks on its 3rd flag until fixed; a key or password blocks at once. Before handoff, fetch `dev`, check conflicts, run `MERGE_CHECK_BASE=origin/dev python3 tools/merge_check.py` and the change plan on a permitted runner. Label runtime delivery RUNTIME (no restart), RESTART (close after pulling) or BAKE (needs a tile bake). A `TERRAIN_VERSION` change ships only with its authorized bake. Distinguish implemented, reviewed, tested, merged and played.

No unresolved finding may be hidden, dropped or archived as if fixed: record owner, evidence, severity and disposition in task state. Unresolved blockers and missing required checks stop dependent merges until resolved. Known noncritical baseline defects need reviewer disposition under `TEST_GATES.md`. Unaffected work continues.

Dave playtests dev in Godot, or the installed build, at his pace. Every bug, from any source, goes in `BugsList_Current.md` (the one bug list; its header says how). A bug whose fix is merged in dev with its gate passed is closed then: nothing waits on Dave's play check, and it reopens only if Dave or a tester reports it again (R-TEAM-CLOSE-FIXED). When play-testing shows a suggestion in `docs/RULINGS.md` is not right, make the game correct, change that line by its procedure and tell the coordinator; a rule is never changed this way (CONSTITUTION, "Rules and suggestions"). Log observed/expected behavior, reproduction, scene/screenshot, severity and build SHA. Do not replace his checkout, change his tested revision, launch heavy jobs during his session or kill Godot blindly.

No automatic updates to Dave (Dave, 26 Nov 2026: "stop any automatic updates. i will ask when I need them"): post to him only when something needs him or he asks. Messages to him are short, in Atlantic time; anything he must do uses numbered steps. Detailed evidence stays in the task record (`HANDOFF_TEMPLATE.md`).

## Commands and machine protection
Verify current paths/builds and access before running. Godot 4.7.2 with Voxel Tools is required for world tests and gameplay; on Dave's PC the lane's voxel build runs every test, data and server tests included. Typical authorized Windows paths:
- Tests run only from the lane folder (R-TEAM-LANE-C-DRIVE, `TEST_GATES.md` "Environment constraints"): the lane's voxel build `C:\DynastyLane\godot\godot_lane_a.exe` is the default of `tools/godot`, `tools/godot.cmd` and the test tools.
- `C:\GodotInstaller` holds Dave's editor and the standard build; the lane copies its Godot from there and never tests with them.
- Dave's protected checkout: `C:\GodotProjects\DynastyALWL`.

```bash
python3 tools/tests_for_diff.py <base_sha> <head_sha> > /tmp/plan.json
GODOT_EXE=/c/DynastyLane/godot/godot_lane_a.exe tools/run_tests.sh --jobs 3 --out /tmp/run --plan /tmp/plan.json
GODOT_EXE=/c/DynastyLane/godot/godot_lane_a.exe tools/run_one_test.sh <test> 300 /tmp/o_<test>
godot --path . -- --role=play
```

Read the plan's `why`; `TEST_GATES.md` owns the change plan, the dev sweep (`--wide`), batches, carry-over and full-suite requirements. A standard-build compile failure in a voxel world test is a wrong-runner result. Tests live under `src/worldgen/tools/` and `src/water2/`. Use `CONTROLS.md` for inputs and the current mission's player checklist. Water implementation is `src/water2/`; no old-water switch. Current body authority is `../DYNASTY_BODY.md`.

At most three heavy Godot jobs share the PC through `tools/godot_slot.sh`; test runners take slots automatically, other long jobs must use the wrapper. Do not disable the guard to evade contention. `TEST_GATES.md` "Environment constraints" owns the machine limits (no Godot in the cloud) and the water record.

## Lessons loop
Weekly, about an hour (Dave 25 Nov 2026; `docs/RULINGS.md` R-TEAM-LESSONS):
- When: each Wednesday after the token reset, the coordinator's scheduled task wakes it and it gives one thread the week's lessons.
- Read: that week's independent-review findings, `tools/check_dave_rules.py` FAILs, and bugs entered again that `BugsList_Fixed.md` already holds.
- Fix: a mistake seen twice in the week becomes one small PR to `dev` that stops it coming back, a new check or a skill fix, with independent review under `TEST_GATES.md`.
- Ask first: anything that would change a ruling, a rulebook or a test gate goes to Dave through the coordinator, never straight into a PR.
- Report: one line to the coordinator (the PR link, or "nothing seen twice"), kept in `/mnt/project-files/lessons/` for the next week.

## Backups and document retirement
Read `DOC_LIFECYCLE.md` only when setting up backups or retiring documents or code files.
