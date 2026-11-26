# Dynasty engineering workflow
**Status: IN FORCE. Four-rulebook consolidation approved by Dave, 15 Nov 2026.** Authority and delegation: `CONSTITUTION.md`. Required validation: `TEST_GATES.md`. Engineering method: `../PONYTAIL_RULES.md`.

## Branches and ownership
Start from freshly fetched `origin/dev`, read `../../CLAUDE.md` there, and use a scoped `feature/<task-id>-<scope>` or agreed `claude/<task>` branch/worktree. Own only assigned paths. Use one owner per shared file unless the mission defines a reviewed section split. Reconcile intervening `dev` changes before delivery without overwriting others' work. No direct `main` push, force push, history rewrite, gate disabling or deletion of user work.

Reviewed branches integrate into fully committed `dev` under `TEST_GATES.md`. `main` is a stable milestone: protected PR, complete gate and Dave's explicit approval. No nightly `main` promotion requirement. Verify actual branch protections; prose does not enforce them. Build numbers in `src/shared/build.gd` change only through `tools/ship.sh` at the authorized last step into `main`; branches do not bump them. `tools/ship.sh`/`tools/pr_merge.sh` are not a routine route into `main` without that approval.

## Roles and task lifecycle
The coordinator owns priorities, assignments, shared state, dependencies and escalation; it does not write game code or approve its own PR. Specialists implement within scope; non-author reviewers assess evidence; an authorized PC runner performs machine checks. Roles are responsibilities, not permanent named chats. Use the workers needed for the task. Existing installed model/effort defaults are unchanged; verify actual availability and honor Dave's explicit choices. Claude Code definitions do not prove Cowork loads them.

1. Assign a bounded task: ID, expected behavior, current authority/decision pointers, paths/interfaces owned, prohibited side effects, acceptance tests, priority, owner, reviewer, branch and authorized runner. Use `TASK_BRIEF_TEMPLATE.md`.
2. Read relevant design, mission state/decisions, code/callers and tests. Inspect private handoffs only when relevant and accessible. Do not load the whole archive or Library.
3. Investigate, implement and verify the smallest complete solution. Self-review under Ponytail, answer findings, then obtain independent review under `TEST_GATES.md`. Report unrelated discoveries for prioritization; do not launch side repairs.
4. Save a compact checkpoint at meaningful milestones and before handoff: exact SHA, changed paths, current hypothesis/result, failures, commands, next action, risks and authority. Finish scope and request the next assignment.
5. Refresh at task boundaries or earlier when context quality declines; save state first. No invented context-percentage threshold. Close workers only after outputs are saved/verified and ownership released.
6. Keep coordinator state compact. Replace an overloaded coordinator through a verified user-accessible workflow with explicit ownership transition; do not assume active child sessions transfer or automatic retirement is supported.

Newer explicit priorities govern within scope. Standing fallback priority: terrain/water, Dave's playtest bugs, freezes/lag, testing, first-hour bugs, body/movement, flora/fauna, art, audio, tuning, guides/docs, parked ideas. Use the current task queue rather than historical personal rosters. Dave may speak to a worker directly; log substantive changes in shared state and notify the coordinator.

## Integration, playtesting and blocking findings
Claude Code warns before a `git commit` (a bare print() in client code; a key, token or password) and before a `git push` (the rule checks), from `tools/hooks/` via `.claude/settings.json`; these local warnings never block: fix what they name. GitHub checks every file a change touches for the same problems (`tools/warn_watch.py`): a problem is flagged each time its file is touched and blocks on its 3rd flag until fixed; a key or password blocks at once. Before handoff, fetch `dev`, check conflicts, run `MERGE_CHECK_BASE=origin/dev python3 tools/merge_check.py` and applicable tests/controls/parse checks on permitted runners. Review the final candidate and evidence. Label runtime delivery RUNTIME (no restart), RESTART (close after pulling) or BAKE (needs a tile bake). A `TERRAIN_VERSION` change ships only with its authorized bake.

Stop starting risky changes near nightly integration. Integrate reviewed ready work and publish the exact committed `dev` SHA and relevant evidence. Apply the startup/world-load gate before calling it playable; if unavailable report `DEV COMMITTED — PLAYABILITY UNVERIFIED` and offer a last-known-green SHA. Distinguish implemented, reviewed, tested, integrated and played.

No unresolved finding may be hidden, dropped or archived as if fixed. Record owner, reproduction/evidence, severity and disposition in current task state. Unresolved blockers and missing required checks stop dependent integration/release until resolved and verified. Known noncritical baseline defects require explicit reviewer disposition under `TEST_GATES.md`; no new blanket waiver is created here. Unaffected work can continue.

Dave playtests dev in Godot, or the installed build, at his pace. Every bug, from any source, goes in `BugsList_Current.md` (the one bug list; its header says how). When play-testing shows a suggestion in `docs/RULINGS.md` is not right, make the game correct, change that line by its procedure and tell the coordinator; a rule is never changed this way (CONSTITUTION, "Rules and suggestions"). Log observed/expected behavior, reproduction, scene/screenshot, severity and build SHA. Workers investigate immediately on isolated branches. Do not replace his checkout, change his tested revision, launch heavy jobs during his session or kill Godot blindly. Remote `dev` may advance without changing his running build. Defer PC runs until a guarded slot is available.

Messages to Dave are short and use Atlantic time. Prefer `Dev ready: <SHA>. Changes: <sentence>. Known issues: <sentence>. Pull dev and play.` Or `Dev not ready: <reason>; play <last-known-good SHA>.` Test summary: counts, one line per failure; anything Dave must do uses numbered steps. Detailed evidence stays in the task record, using `HANDOFF_TEMPLATE.md`.

## Commands and machine protection
Verify current paths/builds and access before running. Godot 4.7.2 with Voxel Tools is required for world tests and gameplay; the standard executable is for data/compatible server tests. Typical authorized Windows paths:
- Voxel build: `C:\GodotInstaller\godot.windows.editor.x86_64.exe` (default of `tools/godot`).
- Standard build: `C:\GodotInstaller\Godot_v4.7.2-stable_win64_console.exe`.
- Dave's protected checkout: `C:\GodotProjects\DynastyALWL`.

```bash
python3 tools/tests_for_diff.py <base_sha> <head_sha> > /tmp/plan.json
GODOT_EXE=/c/GodotInstaller/godot.windows.editor.x86_64.exe tools/run_tests.sh --jobs 3 --out /tmp/run --plan /tmp/plan.json
GODOT_EXE=/c/GodotInstaller/Godot_v4.7.2-stable_win64_console.exe tools/run_one_test.sh <test> 300 /tmp/o_<test>
godot --path . -- --role=play
```

Read the plan's `why`; `TEST_GATES.md` owns the change plan, the dev sweep (`--wide`), batches, carry-over and full-suite requirements. A standard-build compile failure in a voxel world test is a wrong-runner result. Tests live under `src/worldgen/tools/` and `src/water2/`. Use `CONTROLS.md` for inputs and the current mission's player checklist. Water implementation is `src/water2/`; no old-water switch. Current body authority is `../DYNASTY_BODY.md`.

At most three heavy Godot jobs share the PC through `tools/godot_slot.sh`; test runners take slots automatically, other long jobs must use the wrapper. Do not disable the guard to evade contention. No heavy cloud Godot/headless tests, bakes or renders; permitted static/lint/CI checks may run in the cloud. `TEST_GATES.md` owns machine/water-record prerequisites and evidence.

## Lessons loop
Weekly, about an hour (Dave 25 Nov 2026; `docs/RULINGS.md` R-TEAM-LESSONS):
- When: each Wednesday after the token reset, the coordinator's scheduled task wakes it and it gives one thread the week's lessons.
- Read: that week's independent-review findings, `tools/check_dave_rules.py` FAILs, and bugs entered again that `BugsList_Fixed.md` already holds.
- Fix: a mistake seen twice in the week becomes one small PR to `dev` that stops it coming back, a new check or a skill fix, with independent review under `TEST_GATES.md`.
- Ask first: anything that would change a ruling, a rulebook or a test gate goes to Dave through the coordinator, never straight into a PR.
- Report: one line to the coordinator (the PR link, or "nothing seen twice"), kept in `/mnt/project-files/lessons/` for the next week.

## Backups and resource arrangements
Reuse an existing approved backup arrangement without asking again. Before enabling unattended backups, obtain one-time approval for exact source paths, destination (prefer another physical drive), retention, verification and schedule. Follow approved retention, record success/failure and verify recovery; a copied folder alone is insufficient. Do not silently expand scope, discard backups/live water records/manual assets/uncommitted tiles, or modify Dave's checkout. Back up before authorized `main` promotion as required by the approved arrangement.

Preserve the established weekly token pacing (reset Wednesday 03:00 Atlantic).

## Documentation and removal lifecycle
Maintain one authority per topic and concise task state; `CONSTITUTION.md` owns decision provenance. Update current instructions in place, repair affected readers and preserve source decisions/unique knowledge before retiring a duplicate. Required licenses/attribution stay with distributed assets for as long as needed. No archive can conceal an unresolved issue.

Dave approved a seven-day document recovery period with Git history retained. On reviewed retirement integration, record source commit/blob, preserved target or justified history-only disposition, reader/issue checks, actual integration event/time and expiry 168 hours later in the existing `../../proposed_removals/REMOVALS.md`. Exclude retired documents from routine reading immediately. Never infer retirement from source age. Remove from the current branch only after expiry, verified history recovery, no remaining reader/license obligation and reviewed passing enforcement. No history rewriting or permanent second archive.

The six consolidated rulebook paths are temporary redirects, not additional authorities. Their source content is preserved at the consolidation base recorded below. Finalize actual merge-derived retirement timestamps after integration; this branch assigns no speculative dates. The existing document-deletion checker still prevents deletion: update and review its expiry validation before deleting redirects or archive files. The wider inventory/expiry automation proposal is not approved by this core-rulebook change.

Code/file removal safeguards remain: delete genuinely replaced code with a valid replacement row and no live use; other unused files follow the existing proposed-removal procedure and Dave's applicable approval. Do not delete the historical `qa` branch. Never commit crash reports, editor logs, temporary DLLs or unauthorized `.tile` outputs. Relevant stable-ID, save and architecture safeguards are in Ponytail and the contracts.

Consolidation base: `dd566834db6496d0d8d2bb2a6bf2b9cb1ec882aa`. Former setup, staffing/lifecycle and RULES text are recoverable with `git show dd566834db6496d0d8d2bb2a6bf2b9cb1ec882aa:<original-path>`; deployment receipts are in the existing removal ledger. Repo template updates do not update live project settings or private copies: report SYNC PENDING accurately.
