# Daily engineering and playtest workflow
**Status: IN FORCE (activated by Dave, 12 Nov 2026; `INSTALL_RECORD.md`). Drafted as PROPOSED.**

## Branches
- `feature/<task-id>-<short-scope>` (or agreed `claude/<task-id>`): single job, isolated worktree; owns only assigned paths. No unreviewed worker edits to someone else's branch.
- `dev`: shared integration, **fully committed** nightly playable candidate for Dave. It is allowed to contain known noncritical defects. Does not require full stable-release gate, but must pass the **dev playtest gate**.
- `main`: last fully verified stable milestone. Protected PR merges only on the exact reviewed SHA with the complete main gate and Dave's explicit approval. Nightly promotion is not required. Source: Dave's 12 Nov project-instruction ruling in `DECISION_AUTHORITY.md`; `RULES.md`.

## Daily rhythm
**Morning:** Dave approved the *daily backup concept*. Before enabling unattended backups, obtain one-time approval for exact source paths, destination (prefer a different physical drive), retention, verification method, and allowed schedule. Then run that authorized backup automatically each day without asking Dave again, logging a restore manifest. Do not silently expand scope, delete older backups outside approved retention, or modify his PC checkout. Update task queue from overnight playtest and highest-priority backlog. Resume from clean task sessions.

**Workday:** Coordinator assigns bounded tasks with explicit acceptance tests, document pointers, branch/worktree, model/effort and reviewer. Agent diagnoses with evidence, implements the smallest complete change under `docs/PONYTAIL_RULES.md`, runs `/ponytail-review` on its own diff and answers each finding, runs only allowed tests on permitted machines, records lessons/risks and requests review. Coordinator monitors interdependencies and prevents simultaneous file ownership conflict.

**Nightly integration:** Stop starting risky new changes; gather ready branches into `dev` only if reviewed and integration checks pass. Commit everything; publish exact dev SHA, tag optionally (`playtest-YYYY-MM-DD`) if authorized, run smoke tests on the designated PC while Dave is not playing, clearly label skipped and blocked tests. Do not claim 'playable' if game-launch smoke test could not run. If dev fails, offer the last green dev SHA or last stable main. Keep defects in the backlog.

**Dave playtests:** On his PC in Godot 4.7.2 editor via **F6 (Run Current Scene)**; coordinator logs concise observed behavior, reproduction, screenshot/scene, expected result, severity and build SHA. Workers **immediately investigate** on their own branch. Do not automatically interrupt his play session, launch Godot heavy jobs on his PC, or replace his working copy; wait for available slots. Only commit verified fixes to dev; never alter the SHA Dave is currently testing.

**Periodically:** Full main gate, promote approved verified commit from dev (or reviewed subset) via protected PR. Record exact tag and evidence. Do not discard live water data, manual assets, or uncommitted tiles as cleanup.

## Compact messages to Dave
`Dev ready: <SHA>. Changes: <1 sentence>. Known issues: <1 sentence>. Pull dev and play.` Or `Dev not ready: <reason>; play <last-known-good SHA>.` More detail goes in files.
