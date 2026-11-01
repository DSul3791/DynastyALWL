# Scope: moderator (1 Nov 2026)

## 1. The job
I speak for Dave to six Claude sessions (Sonny, Kathleen, Sal, Tyler, Flora, Guide) building *Dynasty: a life well lived*. I start and steer them, decide reversible choices, log decisions in `MODERATOR_QA_LOG.md`, merge their pushes into the integration branch `DailyDev_20261029`, run the full test pass, and keep Dave's questions on the QA page (branch `qa`). I start where an agent hands me a pushed commit and stop at main: I never merge to main until Dave has play-tested and says go.

## 2. Done so far
- Ran the six agents across the world look, items, comfort and shelter, the first-hour guide, and the new water (all merged on the daily except the water default push still due from Sonny).
- Merged every agent's work into the daily; last pushed head `f50d17f0`, local head ahead with the handoff documents and the dynasty-water merge `26a51f65`.
- Full test run on `27dfe828`: 159 of 159 pass (132 standard exe, 27 on the voxel build `godot.windows.editor.x86_64.exe`).
- Wrote `docs/PONYTAIL_RULES.md`, the QA cards (lean-to, fixtures, grass, `death-novice`), the picture rule in `questions/README.md`, the stump rule and the standing instruction in `MODERATOR_QA_LOG.md`.
- Collected handoffs and scope documents from the agents (see `docs/handoff/`).

## 3. Planned, in order
1. Merge Sonny's water-default push; run the full test pass (voxel build for world tests); push the daily.
2. Merge Tyler's, Flora's, Kathleen's and Sonny's final handoff and scope documents; confirm all twelve files exist in `docs/handoff/`.
3. Confirm the stump rule is wired (Tyler) and drops (Sal).
4. Hand Dave a clean daily for his play-test; relay feedback via QA cards.
5. After Dave says go: backup, merge into main, final tests, new daily branch.

## 4. Priorities
1. Dave can play the daily with the new water as the default.
2. Never merge to main without Dave's go.
3. Every agent has pushed handoff and scope documents.
4. Full tests green on the right Godot build.
5. No agent idle without a job (after the handoff: start the successor sessions with these documents).

## 5. Dependencies
I depend on each agent's pushes and on free Godot slots (stale Godot processes from 31 Oct were still holding them). Agents depend on me for merges, decisions and Dave's answers. Dave depends on me for one plain status.

## 6. Finished when
Dave has played the daily, said go, main contains it, tests pass on main, and a fresh daily branch is open with the handoff documents as the first thing the next team reads.
