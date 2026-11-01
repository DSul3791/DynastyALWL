# Scope: moderator (1 Nov 2026)

## 1. The job
I speak for Dave to ten Claude sessions (Sonny, Kathleen, Kathreen, Sal, MikeW, Steve, Tyler, Dino, Jason, Jamie; roles in `docs/START_HERE.md`) building *Dynasty: a life well lived*. I start and steer them, decide reversible choices, log decisions in `MODERATOR_QA_LOG.md`, merge their pushes into the integration branch `DailyDev_20261029`, run the full test pass, and keep Dave's questions on the QA page (branch `qa`). I start where an agent hands me a pushed commit and stop at main: I never merge to main until Dave has play-tested and says go.

## 2. Done so far
- Ran the agents across world look, items, comfort and shelter, the first-hour guide and the new water; merged every push into the daily (all current, pushed).
- Full test run on `27dfe828`: 159 of 159 (standard exe plus voxel build for world tests). Not re-run since.
- Wrote `docs/PONYTAIL_RULES.md`, QA cards and picture rules, and logged every decision in `MODERATOR_QA_LOG.md` (stump rule, role changes: Sonny terrain and water only; looks to Kathleen and Kathreen; animals and plant/animal behaviour to MikeW; sub-systems to Steve; sound and sound hooks to Jason; Tyler Q&A testing; Dino guides; Jamie documentation).
- Started Kathreen (second art agent), Steve (systems), Jason/Champ (audio), Jamie (documentation); collected 11 handoff and scope document pairs.
- Cleaned git: 354 old and merged remote branches deleted (398 to 43), 6 leftover worktrees removed, old-branch work assigned and reviewed (`docs/OLD_BRANCH_REVIEW.md`).

## 3. Planned, in order
1. RESTART all agents (after Dave's computer is back); Sonny's water default flip and tests first.
2. Tyler's full test pass on the merged daily; fix what fails; push.
3. Hand Dino's findings to owners (done once; repeat per Dino report); collect pictures and QA cards.
4. Merge the ports from the old-branch review as owners finish; delete their branches; one bake proposal for Dave.
5. Hand Dave a clean daily for his play-test; relay feedback via QA cards.
6. After Dave's go: backup, merge into main, final tests, new daily branch.

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
