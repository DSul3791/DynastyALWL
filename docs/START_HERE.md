# Start here — current engineering entry point (13 Nov 2026)

One page for a new agent or a new thread of Dave's. Everything else is found through `docs/DOC_MAP.md`.

## The game
*Dynasty: a life well lived*: a rough-medieval, multiplayer survival and town-building world with a "Sims vibe" (heirs, a dynasty that outlives one character). Godot 4.7.2, GDScript, Voxel Tools, built for weak hardware (1050-class GPU, 8 GB, 30 fps). Repo `C:\GodotProjects\DynastyALWL`, owner Dave (wants SHORT reports). Design: `DESIGN_IDEAS.md`, `DESIGN_PRINCIPLES.md`; short picture: `BIG_PICTURE.md`.

## Current responsibilities and assignments

Use `docs/ai-team/ROLE_CATALOG.md` for responsibilities and `docs/ai-team/WORKFLOW.md` for coordination. Sessions are temporary and task-focused; historical agent names are not proof that a worker is active or owns a file today. The coordinator assigns scope, branch, file ownership and reviewer. Read the assigned task checkpoint for current progress.

Current design navigation is `docs/DOC_MAP.md`. Earlier rosters, handoffs and QA records are historical evidence, not a replacement for current assignments. Missing project-file mounts must be reported as unavailable; do not make them a prerequisite for reading the repository.

## Rules
- **Branches (Dave, 11 Nov 2026; supersedes the 2 Nov no-daily-branch rule, kept as history in `docs/ai-team/KNOWN_CONFLICTS.md` #1):** task branches (`claude/<task>`) cut from `dev` -> reviewed, fully committed `dev` for Dave's nightly playtest (Godot F6) -> protected, gated `main` by PR only. Never push or merge to `main` yourself; never merge your own PR. Never delete the `qa` branch (the old QA page, kept as a record). Process: `docs/ai-team/WORKFLOW.md`, gates: `docs/ai-team/TEST_GATES.md`.
- **AI Team Operating System v1.0 (installed 11 Nov 2026):** Claude Code entry `CLAUDE.md`; policy `docs/ai-team/CONSTITUTION.md`; install record and what is still unverified: `docs/ai-team/INSTALL_RECORD.md`. The general handoff freeze was **lifted by Dave on 12 Nov 2026**: normal development on `dev` is authorized under the established workflow; Dave still approves significant design, architectural, destructive, security-sensitive and other protected decisions (`docs/ai-team/DECISION_AUTHORITY.md`).
- **Item catalog FROZEN (Dave, 11 Nov 2026):** no discretionary additions, removals, renames or recipe redesigns in `data/items/`; implement, validate and report problems only. Ruling: `docs/ai-team/DECISION_AUTHORITY.md`.
- **Assignments (Dave, 12 Nov 2026; replaces the 2 Nov self-generated task rhythm):** the coordinator controls prioritization and assignment. Workers complete their assigned work, document results, and request their next assignment. They do not independently create unrelated work.
- Blocked or stuck: record evidence and the blocker in the task checkpoint; route genuine creator decisions through the coordinator under `docs/ai-team/DECISION_AUTHORITY.md`. Continue unaffected assigned work; request the next assignment when finished.
- Prioritization: the coordinator applies Dave's current priorities and playtest findings to the active task queue. Historical backlog files do not independently authorize new work.
- Staffing: work is assigned by priority with explicit file ownership; completed workers request their next task.
- NO cloud testing (Dave, 5 Nov 2026): no cloud renders, headless runs or test runs; they use up his tokens. The only testing allowed is on Dave's PC, and only while he is not play testing.
- Knowledge library (Dave, 6 Nov 2026): before you code a system or fix a bug, read its topic doc in `docs/knowledge/` (index: `docs/knowledge/README.md`), then have the coordinator assign fresh research if it is missing or old. Add your lesson to the doc when you finish.
- LAW (Dave, 5 Nov 2026 18:48): absolutely no tests and no bakes in the cloud. All heavy work (tests, bakes, settles, builds) goes to Dave's PC through the coordinator.
- Questions for Dave: the coordinator presents genuine unresolved decisions concisely under `docs/ai-team/DECISION_AUTHORITY.md`; read current decisions before asking again. Old QA-page paths are historical, not a mandatory live destination.
- Max 3 heavy Godot jobs at once on this PC: run them through `tools/godot_slot.sh` (`run_tests.sh`/`run_one_test.sh` do it themselves). Never start a Godot run without a timeout (hung headless scripts have held all slots); never kill Godot processes blindly (one may be Dave's editor).
- Replaced code and unrelated unused files follow Decision 61 in `RULES.md`. For this creator-authorized documentation cleanup (13 Nov), update active rules in place and remove obsolete prescriptions once replacements are recorded; retain necessary historical audit/migration evidence. See `docs/design/DOCUMENT_CONTRADICTIONS_RECONCILED_2026-11-13.md`. This is not blanket permission to remove historical records.
- Dave decides design; routine reversible decisions follow `docs/ai-team/DECISION_AUTHORITY.md`. Record their provenance separately from direct creator instructions.
- Rules in full: `RULES.md`, `docs/PONYTAIL_RULES.md` (engineering method for all code, Ponytail v5.3.3), `CONTROLS.md` (update on any input change). Wire format: `PROTOCOL.md`.

## Two Godot builds (do not mix up)
| Build | Path | Use |
|---|---|---|
| Voxel build (custom, Voxel Tools inside) | `C:\GodotInstaller\godot.windows.editor.x86_64.exe` (the default of `tools/godot`) | world tests, client scenes, running the game |
| Standard exe | `C:\GodotInstaller\Godot_v4.7.2-stable_win64_console.exe` | data and most server tests |

Never judge a full test run on the standard exe: the world tests fail to compile there (wrong build, not a bug).

## Run tests
```
GODOT_EXE=/c/GodotInstaller/Godot_v4.7.2-stable_win64_console.exe tools/run_one_test.sh <test> 300 /tmp/o_<test>    # one test, result in <out>/<test>.result
python3 tools/tests_for_diff.py origin/dev HEAD > /tmp/plan.json          # the change's tests; read its "why" first (docs/ai-team/TEST_GATES.md, risk-based selection). --full (or tools/release_check.sh) only for the deferred broad run and before main
GODOT_EXE=/c/GodotInstaller/godot.windows.editor.x86_64.exe tools/run_tests.sh --jobs 3 --out /tmp/run --plan /tmp/plan.json   # runs the plan
```
Tests live in `src/worldgen/tools/` and `src/water2/`. Use the assigned task's exact-SHA evidence for current test results; dated full-run reports do not establish a pass for today's head.

## Run the game
From the project folder with the voxel build: `godot --path . -- --role=play` (play is the default role in `scenes/launcher.gd`; starts a server and joins it; pressing Play in the editor does the same). Water: the Dynasty water (`src/water2`) is the only water; the old hub and its `--water-old` switch were deleted on 9 Nov. The body is Dave's `Dynasty_Base_Male.glb`, the only one since 8 Nov (the old-body switches are gone; `docs/DYNASTY_BODY.md`). In game: K = photo camera, `/` = inspection mode (`CONTROLS.md`). Dave's play-test page: `MORNING_PLAYTEST_CHECKLIST.md`.

## Where everything is (for a new thread of Dave's)
| I want | Go to |
|---|---|
| current topic authority | `docs/DOC_MAP.md` |
| current responsibilities and task ownership | `docs/ai-team/ROLE_CATALOG.md`, coordinator-assigned task checkpoint |
| current decision authority and provenance | `docs/ai-team/DECISION_AUTHORITY.md`, current topic specs; `MODERATOR_QA_LOG.md` for historical rulings |
| historical handoff and Phase 2 records | `docs/CLOSING_PLAN.md`, `docs/handoff/PHASE2_RUNBOOK.md` |
| unmerged old branches and what to do with each | `docs/OLD_BRANCH_REVIEW.md` |
| the findings from playing it | `docs/handoff/FINDINGS_REPORT.md`, `PLAYTHROUGH_STEP_STATUS.md` |
| design, principles, rejected ideas | `DESIGN_IDEAS.md`, `DESIGN_PRINCIPLES.md`, `DESIGN_REJECTED.md` |
| current items, recipes and progression | `docs/design/DYNASTY_MASTER_ITEMS.md`, `docs/design/progression.md`; `data/items/` is actual implementation evidence |
| death rule | `data/items/death.json` (respawn at the bed until character level 10, then real death) |
| water, terrain | `docs/TERRAIN_WATER_BACKLOG.md`, `docs/DYNASTY_WATER_HISTORY.md` |
| sound | `docs/SOUND_MAP.md`, `docs/handoff/JASON_NEXT_TASKS.md` |
| looks, the player body | `docs/DYNASTY_BODY.md`, `docs/KATHLEEN_NEXT_TASKS.md`, `docs/handoff/HANDOFF_KATHREEN.md`, `art/CRITIQUES/` |
| controls, wire format, world files | `CONTROLS.md`, `PROTOCOL.md`, `WORLD_FORMAT_SPEC.md` |
| code and data | `src/`, `data/` (JSON tables), `tools/` (scripts); current questions through coordinator |
| historical material | `docs/archive/YYYY-MM/`, dated handoffs and Git history; `docs/mirror/` is a frozen copy cited by some tools, not current design authority |
