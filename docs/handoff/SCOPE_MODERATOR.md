> **Update 2 Nov 2026 (Dave): there is no daily branch any more.** Where this document says "the daily" or `DailyDev_20261029`, read `origin/main`. Work on your own new branch each day (`claude/<name>-YYYYMMDD`) and open a PR. Bugs in `docs/BUGS_FOUND_IN_PLAY.md` come first. Rules: `docs/START_HERE.md`.

# Scope: moderator (1 Nov 2026)

## 1. The job
I speak for Dave to ten Claude sessions (Sonny, Kathleen, Kathreen, Sal, MikeW, Steve, Tyler, Dino, Jason, Jamie; roles in `docs/START_HERE.md`) building *Dynasty: a life well lived*. I start and steer them, decide reversible choices, log decisions in `MODERATOR_QA_LOG.md`, merge their pushes into the integration branch `DailyDev_20261029`, run the full test pass, and keep Dave's questions on the QA page (branch `qa`). I start where an agent hands me a pushed commit and stop at main: I never merge to main until Dave has play-tested and says go.

## 2. Done so far
- Ran ten agents across world look, items, systems, sound, water, documentation and the first-hour guide; merged every verified push into the daily (pushed).
- Test passes: full pass on the final code (164 tests, 163 pass, the one fail superseded), delta pass after the stone and economy changes, rig joins clean.
- Logged every decision in `MODERATOR_QA_LOG.md` (roles, stump rule, stones 5 for 1 copper, cheap goods stay cheap, sound hooks, fire and water looks) and wrote `docs/PONYTAIL_RULES.md`, `docs/CLOSING_PLAN.md`, `docs/OLD_BRANCH_REVIEW.md`.
- Started Kathreen, Steve, Jason and Jamie; collected a handoff and scope pair from every agent.
- Cleaned git: about 350 old and merged remote branches deleted (398 to about 50), 6 leftover worktrees removed, old unfinished work assigned, reviewed and ported or dropped.

## 3. Planned, in order
1. Dave fetches the daily, plays, answers the QA cards, runs the delete command, says go.
2. After the go: backup, merge the daily into main, final tests, new daily branch (e.g. `DailyDev_20261102`).
3. Then the backlogs: terrain bake set (one bake with Dave's go), water look, remaining pictures, bridges and plank tier, real death build, sound hooks, fauna tuning, the market idea in `DESIGN_IDEAS.md`.

## 4. Priorities
1. Dave can play the daily with the new water as the default.
2. Never merge to main without Dave's go.
3. Every agent has pushed handoff and scope documents.
4. Full tests green on the right Godot build.
5. No agent idle without a job (after the handoff: start the successor sessions with these documents).

## 5. Dependencies
I depend on each agent's pushes and on free Godot slots (max 3 heavy jobs via `tools/godot_slot.sh`; never leave detached test lanes). Agents depend on me for merges, decisions and Dave's answers. Dave depends on me for one plain status.

## 6. Finished when
Dave has played the daily, said go, main contains it, tests pass on main, and a fresh daily branch is open with the handoff documents as the first thing the next team reads.
