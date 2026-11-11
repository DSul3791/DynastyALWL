# Ponytail rules: Dynasty engineering method

**Status: DIRECTOR-APPROVED direction (Dave, project thread "Integrate Ponytail into AI team", 11 Nov 2026): apply Ponytail across the whole coding team, never overriding his approved designs, realism requirements, architecture decisions or engineering standards.** The wording below is the AI team's reviewed adaptation, not a Dave quote. This file is the single authoritative Ponytail text for Dynasty. Install record, environments and rollback: `docs/ai-team/PONYTAIL_INSTALL.md`.

Source: Ponytail v5.3.3 by Dietrich Gebert, MIT, `github.com/DietrichGebert/ponytail` tag `v5.3.3` = commit `7801d061243d7b753bad0e0b3c057cd250b11755`. Adapted from its `skills/ponytail/SKILL.md`; the first version of this file (moderator, 31 Oct 2026) was written from the Ponytail README for the water build and handoffs then applied it team-wide.

## Where it sits
Ponytail is **how** we build, never **what** we build. It works inside `docs/ai-team/CONSTITUTION.md` precedence and never overrides Dave's approved designs, realism requirements, architecture decisions, interface contracts (`PROTOCOL.md`, save and record formats) or the gates in `docs/ai-team/TEST_GATES.md`. Simplicity is a way to reach quality, not a reason to lower it.
- "The task" means the requirement **including** the approved design and realism it serves. The smallest complete change is the smallest one that fully meets that, even when that is a hard algorithm (the water sim chose local inertial shallow water over a simpler cellular automaton because the simple one could not give real flow: `docs/DYNASTY_WATER_DESIGN.md`).
- Approved architecture and planned stages (`ARCHITECTURE_BUDGET.md`, the next stage of an approved design) count as asked for. YAGNI targets speculative code that no design or task asks for.
- If a requirement looks unneeded or oversized, say so with a reason and keep building it, or escalate under `docs/ai-team/DECISION_AUTHORITY.md`. Never drop or shrink an approved feature, item or realism mechanic on Ponytail grounds.
- A Ponytail heuristic is not a ban. It never makes a plausible approach forbidden; if it seems to, apply `CONSTITUTION.md` (cite, check provenance, propose).
- Where a Dynasty rule asks for more (more tests, a performance budget, a decision record), the Dynasty rule wins.

## 1. Understand before you build
Read the task, the approved design and its decision history, `docs/knowledge/` for the topic, and the code the change touches. Trace the real flow: input, server authority, state, save/record, client, network messages, frame cost. List every place the change must reach: callers, signals, scenes, data files, tests, tools, docs. List what it could break: saves, the water record, other players, frame time, other roles' interfaces. That list is the scope; extra features are not. Be lazy about the solution, never about the reading.

## 2. The smallest complete change (take the first rung that fully works)
1. Does it need to exist? Skip options and flexibility nobody asked for, and name them in one line. A vague request: check the approved design first, then build the smallest version that does its core job and say what was left out.
2. Already in this codebase (helper, autoload, scene, data table, tool, test helper)? Use it the way the surrounding code does.
3. Does Godot do it (nodes, servers such as `NavigationServer3D` and `PhysicsServer3D`, `AnimationTree`, shaders, `JSON`, `ResourceLoader`, threads, MultiplayerAPI) or GDScript's built-ins? Use it.
4. An installed addon or dependency (`addons/`, Voxel Tools)? Use it. Never add a dependency for a few lines.
5. Can it be one clear line? One line.
6. Otherwise write the minimum that works.

- Finish every part the change needs: callers, tests, fixtures, data, docs it breaks.
- No abstraction, wrapper, option, config or "for later" code nobody asked for. Keep the structure the codebase has. Deletion beats addition; replaced code is deleted, documents are archived (`RULES.md`, decision 61).
- Bug fix: find every caller of what you touch and fix the root cause once, in the shared code.
- Code you move or merge keeps its validation and error handling.
- Between options of equal size, take the one correct on edge cases. Between options of equal correctness, take the one that holds the frame and network budget (`ARCHITECTURE_BUDGET.md`).
- Performance work: measure first (on the PC, or label the cost unmeasured), then make the smallest change that meets the budget, keeping behaviour and the approved look.
- Comment only the why the code cannot show, in one line.
- A shortcut with a known limit gets a comment: `# shortcut: <the limit>, <when to revisit>`. `/ponytail-debt` lists them.

## 3. Never cut
Server-side validation of anything a client sends; error handling that prevents data loss (saves, SQLite, the water record, baked tiles); security; accessibility; performance on the target hardware; the calibration real terrain/water needs; anything Dave or the approved design asked for.

## 4. Tests and reports
- New non-trivial logic (a branch, loop, parser, sim step, economy or security rule, a bug fix) leaves at least one small test that fails when it breaks. `TEST_GATES.md` may require more.
- Tests are written anywhere but run only where allowed: never heavy Godot tests, bakes or renders in the cloud. A test not run is reported `NOT RUN`, never passed.
- Every report or handoff ends with what was skipped or not checked, and any risk (one short line in messages to Dave).

## 5. Review commands (Claude Code skills in `.claude/skills/`)
- `/ponytail-review`: the author runs it on their own diff before asking for review, and fixes or answers each finding. The `gate-reviewer` has it preloaded as its review method. Its findings are advice; the gate verdict stays PASS / FAIL / NOT RUN under `TEST_GATES.md`, and "Ship" never means merge approval.
- `/ponytail-audit`: a report-only audit of a folder or system, run when the coordinator or Dave asks. Findings become backlog proposals, not edits.
- `/ponytail-debt`: the `shortcut:` ledger, for handoffs and planning.
- A "delete" or "yagni" finding about something an approved design names (an item, realism mechanic, hook for a planned stage) is not dead code: run the `decision-provenance` skill before removing it.

## 6. Topic notes
- Water (Sonny, 31 Oct 2026): reuse baked tiles, `TileFile`/`TerrainTile`, the water shader, `ShoreRules` and the existing test helpers; new water code lives under `src/water2/`; no copy-paste of the old live sim.
