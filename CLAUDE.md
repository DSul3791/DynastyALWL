# Dynasty — agent entry point
Fetch current `origin/dev` and read this file there before starting a scoped task branch. PRs target `dev`; `main` promotion follows the approved release gate.

**Every agent reads** `docs/PONYTAIL_RULES.md` (engineering method, good enough, token use), plus the `docs/RULINGS.md` lines for its topic (`grep` its section or keys). RULINGS lines are Dave's rulings and beat older text anywhere; a new ruling is recorded by the procedure at the top of that file.

**Open the other rulebooks only for the part the task needs:**
- Coordinator: `docs/ai-team/CONSTITUTION.md` (approvals, provenance, rulings) and `docs/ai-team/WORKFLOW.md`.
- Code or docs thread: `WORKFLOW.md` "Branches and ownership" and "Commands and machine protection"; `docs/ai-team/TEST_GATES.md` "dev playtest gate" and "Test plans for dev" before a merge.
- Reviewer: `TEST_GATES.md` "Review and evidence by risk" and "Evidence format".
- Test lane: `TEST_GATES.md` "Test plans for dev" and "Environment constraints"; `WORKFLOW.md` "Commands and machine protection".
- `main` promotion: `TEST_GATES.md` "main promotion gate".

**Testing on Dave's PC** runs only from `C:\DynastyLane` (R-TEAM-LANE-C-DRIVE); never from E:.

Use `docs/DOC_MAP.md` for topic designs and the current mission's state for scope. Report actual SHAs and observed results; short updates to Dave, durable evidence in task state. Historical records, handoffs and redirects are not rulebooks. `AGENTS.md` is intentionally omitted.
