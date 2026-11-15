> Instance of `docs/ai-team/TASK_BRIEF_TEMPLATE.md` for the first controlled development trial (11 Nov 2026).

# DEVTEST-01 — spend the lowest group member first
- Priority / purpose: Dave's ONE authorized development task (project thread "Dynasty — First Controlled Development Trial", 11 Nov 2026 19:04 UTC). All other development stays frozen. Also a test of the AI team OS lifecycle, model assignment, Ponytail and gates.
- Owner role and model/effort: `systems-engineer` (agent file: sonnet / high; ROLE_CATALOG: "Sonnet high for bounded changes"), spawned fresh. Actual serving model is not observable from the harness.
- Reviewer / integration authority: `gate-reviewer` (independent, read-only, fresh). The coordinator thread commits, runs the PC tests and merges into `dev` after the gates pass. Nothing goes to `main`.
- Base SHA / feature branch / worktree: `origin/dev` = `origin/main` = `be491ba638610f23761d43be78787179c48e58fe` (fetched 11 Nov 2026 19:10 UTC). Branch `claude/project-thread-918v74` in Dave's checkout `C:\GodotProjects\DynastyALWL` (the coordinator's assigned place for this trial; Dave's pre-existing uncommitted `.import` / `project.godot` changes are his and must not be touched, staged or reverted).
- Files/interfaces owned: `src/shared/inventory.gd`, `src/stream/server_items.gd` (spend paths only), tests in `src/worldgen/tools/` (`test_build_stock.gd`, `test_ingredient_groups.gd` or a new focused test), and `docs/ai-team/trials/DEVTEST-01/HANDOFF.md`. No other file without recording why.
- Authoritative design and approved decisions:
  - FINAL_HANDOFF_REPORT_11Nov.md §9.1 (repo copy `docs/FINAL_HANDOFF_REPORT_11Nov.md`): "spend the lowest group member first" PR is approved.
  - Coordinator decision 10 Nov 2026 (commit `1343ec4c4`, comment at `src/stream/server_items.gd` `_refund_number`): a group cost gives back its LOWEST member; "lowest" = lowest items.json `tier`, then lowest material on `REFUND_MATERIALS`, then lowest `value`; missing field ranks last; full tie keeps the group's own order (own id first).
  - Building on the spot (Dave 2 Nov 2026, `test_build_stock.gd` header): ground stock within `BUILD_STOCK_M` is used before the pack. That priority between inventory, nearby ground stock and containers must NOT change.
  - `docs/design/item_system.md` (tiers), `docs/PONYTAIL_RULES.md`.
  - The Library `design/decisions_pending.md` and `handoffs/Steve_handoff_11Nov.md` are NOT reachable from this machine or project (searched): SOURCE UNVERIFIED for any detail beyond the above.
- Evidence / reproduction: `Inventory.remove_fill` (`src/shared/inventory.gd` ~line 152) takes "the id itself first, then the group members in the order of the group". For the nails group that spends iron Nails (the scarce kind) before Bronze nails, while the refund gives back the lowest member, so build + take-down converts iron into bronze.
- Expected outcome: wherever a group ingredient is paid (crafting and building; pack, ground stock, containers), within each existing source the lowest member by the same ranking as `_refund_number` is spent first. Source priority unchanged. Exact-id costs unchanged. Insufficient totals still refuse with no change.
- Definition of done: smallest complete fix (one shared ordering, reused, not duplicated); regression tests for mixed tiers, sufficient and insufficient quantities, and existing crafting/building behaviour; `/ponytail-review` run on own diff with each finding answered; `HANDOFF.md` per `HANDOFF_TEMPLATE.md`.
- Required local runner and forbidden work: tests only on this PC with a timeout, via `tools/run_one_test.sh` / `tools/run_tests.sh` (they take a Godot slot). Max 3 Godot jobs. Never kill Godot processes. No cloud runs, no bakes, no git commit/push/branch operations (coordinator does those), no edits outside owned files.
- Significant decisions permitted: routine implementation choices. Escalation triggers: any change to source priority, to the ranking rule, to `PROTOCOL.md`, or a new gameplay rule.
- Handoff path and Library sync target: `docs/ai-team/trials/DEVTEST-01/HANDOFF.md`; project-folder copy by the coordinator or SYNC PENDING.

Stop conditions: unverified blocking rule, data loss risk, unapproved cross-system contract, unavailable test runner.
