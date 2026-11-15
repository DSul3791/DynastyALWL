# Start here — current engineering entry point
**Updated 15 Nov 2026 on Dave's operating-rules instruction.** Historical rosters and superseded rhythms remain in Git history and dated handoffs, not this active checklist.

## The game
*Dynasty: a life well lived*: rough-medieval multiplayer survival and town building, with families/heirs and a dynasty beyond one character. Godot 4.7.2, GDScript, Voxel Tools; low-tier target 1050-class GPU, 8 GB RAM, 30 fps. Dave owns creative direction and wants concise reports. His checkout `C:\GodotProjects\DynastyALWL` is protected from worker experiments.

## Read only what the task needs
1. Fetch current `origin/dev`, cut a scoped task branch from it and read `CLAUDE.md` there. PRs target `dev`; `main` requires the full gate and Dave's explicit approval.
2. Policy: `docs/ai-team/CONSTITUTION.md`. Authority/delegation: `DECISION_AUTHORITY.md`; procedures: `WORKFLOW.md`, `TEST_GATES.md`, `DOCUMENT_AUTHORITY.md` in the same directory. The general handoff freeze is lifted; specific holds and catalog controls still apply within their recorded scope.
3. Current topic authority: `docs/DOC_MAP.md`, relevant approved design, current mission `STATE.md` and decision record. Distinguish intended design, implemented code/data and actual test/player evidence. Do not use an old index or handoff as the latest status.
4. Engineering: `docs/PONYTAIL_RULES.md`, relevant `docs/knowledge/` entry, callers/contracts and tests. Reuse existing systems and build the smallest complete change. Preserve approved Foundation/Ceiling names, realism, looks and sound.

## Assignment, autonomy and continuity
The coordinator prioritizes and assigns bounded tasks; permanent responsibilities and temporary workers are described in `docs/ai-team/ROLE_CATALOG.md`. Do not infer active ownership or machine access from a historical personal name. Record branch, current file/section owner, reviewer and runner in the task state. One owner per shared file unless the mission explicitly defines reviewed section boundaries.

Standing priority default (Dave, 4 Nov 2026): terrain/water; freezes/lag; testing; first-hour bugs; body/movement; flora/fauna; art direction; audio; tuning; guides/docs; parked new ideas. Dave's playtest bugs go immediately after terrain. Staff top-down rather than keeping workers in fixed lanes; newer explicit priorities and assigned missions govern within their scope.

Complete assigned work autonomously. Recover settled decisions before asking questions; make and record meaningful provisional choices only within applicable delegation. A specific settled instruction beats an assumption. Report unrelated findings for prioritization, finish scope and request the next assignment. Hold only actions genuinely beyond authority or missing required evidence; continue unaffected work. Checkpoint at meaningful milestones and before handoff, not every command.

## Testing and work protection
- Follow the risk-based dev gate in `docs/ai-team/TEST_GATES.md`; relevant checks and non-author review precede integration. Full regression is deferred only with recorded rationale, owner and checkpoint; it is required before `main`.
- No cloud Godot/headless runs, bakes, renders or heavy jobs. Permitted static Python/lint/CI checks may run in the cloud. Godot testing uses the designated authorized PC lane with the correct build, timeouts and available resources; do not disturb Dave's active F6 session.
- At most 3 heavy Godot jobs on the shared PC, through `tools/godot_slot.sh` (test runners do this). Never kill Godot blindly. Verify current runner paths and water-record prerequisites before testing/baking; David4 must not bake without the required record.
- For docs-only changes use static/link/package checks and proportionate non-author review; do not claim new gameplay verification. Mark missing checks NOT RUN. A runtime build without the required smoke is `DEV COMMITTED — PLAYABILITY UNVERIFIED`.
- Protect stable IDs, supported saves, user work and active checkout. Decision 61 and removal details are in `RULES.md`: delete genuinely replaced code, archive retired documents, move other proposed removals aside. Do not delete the historical `qa` branch or run unauthorized backups.
- Use the established approved backup arrangement without repeated permission; scope/retention changes require applicable approval and backup verification remains necessary (`WORKFLOW.md`).

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
Tests live in `src/worldgen/tools/` and `src/water2/`. Use the current mission verification report and exact tested SHA for results; old role handoffs and Phase 2 runbooks describe historical checkpoints.

## Run the game
From the project folder with the voxel build: `godot --path . -- --role=play` (play is the default role in `scenes/launcher.gd`; starts a server and joins it; pressing Play in the editor does the same). Water: the Dynasty water (`src/water2`) is the only water; the old hub and its `--water-old` switch were deleted on 9 Nov. The body is Dave's `Dynasty_Base_Male.glb`, the only one since 8 Nov (the old-body switches are gone; `docs/DYNASTY_BODY.md`). In game: K = photo camera, `/` = inspection mode (`CONTROLS.md`). Dave's play-test page: `MORNING_PLAYTEST_CHECKLIST.md`.


## Find current sources
| Need | Source |
|---|---|
| Topic design and approved item/building mechanics | `docs/DOC_MAP.md` -> current topic spec |
| Actual implementation | Current `src/`, `data/`, `PROTOCOL.md`, `CONTROLS.md`, `WORLD_FORMAT_SPEC.md` |
| Task progress, delegated assumptions, next steps and evidence | Current task/mission checkpoint under `docs/ai-team/missions/` or its brief's recorded location |
| Role responsibilities and staffing defaults | `docs/ai-team/ROLE_CATALOG.md`; actual ownership in task state |
| Principles, rejected ideas, performance | `DESIGN_PRINCIPLES.md`, `DESIGN_REJECTED.md`, `ARCHITECTURE_BUDGET.md` (resolve topic decisions through DOC_MAP) |
| Historical context | Dated handoffs, `docs/archive/`, Git history; not new approval or current test evidence |
