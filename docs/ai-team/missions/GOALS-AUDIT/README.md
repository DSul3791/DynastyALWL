# GOALS-AUDIT — work in progress (resume file)

Mission: Dave's brief 13 Nov 2026 18:16Z (project thread "Audit tutorial goals and rewards"). AUDIT ONLY: no gameplay, data, UI or reward changes.
Outputs (the only deliverables): `docs/design/PLAYER_GOALS_REWARDS_AUDIT.md`, `docs/design/PLAYER_GOALS_AUDIT_LEDGER.csv`.
Branch: `claude/project-thread-d8jals`. Baseline: `origin/dev` dc2fa52374d49ce05ef1f31a300999d1da872d9d.

## Layout
- `tools/goals_audit.py <repo> <out>`: parses the draft (651 rows), cross-checks recipes/blueprints/structures/items, producer graph, obtainability fixed point. Output in `work/`.
- `work/`: generated JSON (re-run the tool to regenerate) and workstream results (`ws_*.json|md`).
- `STATE.md`: pass status and next step.

## Goal ID rule (audit)
The draft has no IDs. Audit IDs: legacy runtime id for `existing:` rows (drink, fibre, ...); otherwise `<marker kind>:<key>` from the row's HTML comment (craft:stone_knife, build:wall_section, gather:stick, activity:chop_log_blocks). Unique across all 651 rows.
