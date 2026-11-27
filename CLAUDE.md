# Dynasty — agent entry point
Fetch current `origin/dev` and read this file there before starting a scoped task branch. PRs target `dev`; `main` promotion follows the approved release gate.

Read the four rulebooks for the assigned work:
- `docs/ai-team/CONSTITUTION.md`: authority, autonomy, approvals and provenance.
- `docs/ai-team/WORKFLOW.md`: assignments, branches, commands, checkpoints and retirement.
- `docs/ai-team/TEST_GATES.md`: risk-based tests, independent review and evidence.
- `docs/PONYTAIL_RULES.md`: engineering method, technical safeguards and token use (section 7).

**Testing:** On Dave's PC all testing runs only from `C:\DynastyLane`: test Godot `C:\DynastyLane\godot\godot_lane_a.exe`, clone `C:\DynastyLane\clone` (R-TEAM-LANE-C-DRIVE in `docs/RULINGS.md`, Dave 26 Nov 2026: "make it a permanent rule make a folder for the godot on c: an only test from there"; the paths and "never from E:" are the coordinator's reading, details in `docs/ai-team/TEST_GATES.md`). Never test from E:. Every agent follows it.

**Good enough is the standard** (R-CORE-GOOD-ENOUGH; Dave, 26 Nov 2026: "good enough is the new standard that stops us from being too picky"). Stop when the thing works and looks like a simple version of what was asked. Do not re-test, re-review or re-shoot pictures to chase the ideal. Reviewers raise only must-fix faults (broken, wrong, unsafe, laggy), never polish. Looks are improved only when Dave complains, and then only a little; the graphics will be reworked in later years. Every agent follows it.

Read `docs/RULINGS.md`: Dave's rulings, one live line per subject, beating older text anywhere; record a new ruling by its procedure. Use `docs/DOC_MAP.md` for topic designs and the current mission's state/decisions for scope. Load specialist references only when needed. Installed agent/skill definitions route to these authorities. Report actual SHA and observed results; short updates to Dave, durable evidence in task state. Historical installation records, handoffs and redirects are not additional rulebooks. `AGENTS.md` is intentionally omitted from this repo to avoid competing instructions.
