# Dynasty — Current Documentation Map

**Current as of 13 November 2026.** This replaces the outdated early-November file inventory and its misleading source-of-truth pointers. The original contents remain available in Git history if provenance is needed. Use this document to find current design authority; do not treat older report filenames as a second set of gameplay instructions.

## Start here: current approved target designs

| Topic | Authoritative active document | Scope |
|---|---|---|
| Master item identity, item family, crafting tools, doors, station tiers, storage, food | [`design/DYNASTY_MASTER_ITEMS.md`](design/DYNASTY_MASTER_ITEMS.md) | Current §§2.1–2.7, 3.0, 3.3, 3.13 contain updated decisions; generated Appendix A is old actual-data snapshot until updated via implementation |
| Workstation and item system concise reference | [`design/item_system.md`](design/item_system.md) | Current mechanics without historical contradictory forge levels |
| Real early-to-endgame production journey | [`design/progression.md`](design/progression.md) | Stone → Copper/Bronze → Improved Iron → Advanced Steel → Master; no artificial goal locks |
| Full seven construction tiers, empty frames, separate doors, roof slopes and water infrastructure | [`design/buildables_plan.md`](design/buildables_plan.md) | Approved frame/roof mechanics; actual item/blueprint code may still be older |
| Specialized bins, storage, warehouse movement and locked-crate permissions | [`design/STORAGE_WAREHOUSING_DESIGN.md`](design/STORAGE_WAREHOUSING_DESIGN.md) | Includes dedicated resource bin sizes, no-permission periodic fuel HOPPER exception; normal crate permissions unchanged |
| Missing gameplay mechanics and stage-by-stage repair | [`design/PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md`](design/PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md) | Authoritative repair backlog; not gameplay code authorization |
| All 80 goal audit findings and 11 earlier creator questions | [`design/PLAYER_GOALS_DECISION_RECOVERY_2026-11-13.md`](design/PLAYER_GOALS_DECISION_RECOVERY_2026-11-13.md) | Current dispositions and remaining data mismatches |
| Proposed 651 goals and unchanged rewards | [`design/PLAYER_GOALS_REWARDS_DRAFT.md`](design/PLAYER_GOALS_REWARDS_DRAFT.md) | **DRAFT**; updated names, smelting and progression; no release authorization until verified |
| Journal, J/G/M controls, automatic goals and simple HUD | [`design/PLAYER_JOURNAL_GOALS_UI.md`](design/PLAYER_JOURNAL_GOALS_UI.md) | One Inventory/Crafting-styled Journal; first two unfinished Goals at upper right |
| Charcoal player-discovered map and Mapping skill | [`design/PLAYER_CARTOGRAPHY_MAP_DESIGN.md`](design/PLAYER_CARTOGRAPHY_MAP_DESIGN.md) | New design not yet implemented; revisit to refine accuracy, Map Scrolls eventually share/sell |
| Admin/debug keyboard policy | [`design/ADMIN_KEYBINDINGS_POLICY.md`](design/ADMIN_KEYBINDINGS_POLICY.md) | Ctrl+Shift required for every admin/debug action; no J/G/M collision |
| Item/goal/current mechanics integration order | [`design/CATALOG_IMPLEMENTATION_PLAN.md`](design/CATALOG_IMPLEMENTATION_PLAN.md) | Current R0–R9 repair sequence; original Mission 001 details live in its history/mission records |
| Save/version compatibility | [`design/CATALOG_SAVE_MIGRATION.md`](design/CATALOG_SAVE_MIGRATION.md) | Current no-loss/version rules, not the old mandatory blanket pre-release migration |
| Water and spring dynamics | [`design/drinking_water_design.md`](design/drinking_water_design.md), [`design/drinking_water_step2b_design.md`](design/drinking_water_step2b_design.md), `DYNASTY_WATER_DESIGN.md` | Use their **dated supported subfeatures and actual code**; current goal repair must not invent missing water actions |
| Food preparation and preserving | [`design/FOOD_PREPARATION_PRESERVATION_SERVING.md`](design/FOOD_PREPARATION_PRESERVATION_SERVING.md) | Approved relevant food categories, station use and preserving workflows |
| Active workflow, testing and branch rules | `docs/ai-team/WORKFLOW.md`, `docs/ai-team/TEST_GATES.md`, `CLAUDE.md`, `PROTOCOL.md` | Follow actual current files; feature branches through review into `dev`, `main` protected |

## Baseline evidence, NOT active instructions

- `design/PLAYER_GOALS_REWARDS_AUDIT.md` and `design/PLAYER_GOALS_AUDIT_LEDGER.csv` are the preserved historical 651-goal audit snapshot: **230 PASS, 247 NEEDS_CORRECTION, 30 NEEDS_TEST, 144 BLOCKED**, no F6 validation of those goals. All dispositions and new decisions are in the recovery doc above. The original audit was deliberately left unchanged to make before/after verification possible.
- The old 12 Nov catalog/static audit and early 10 Nov ingredient audit were retired from active files because their station and ingredient conclusions no longer describe approved production. They remain accessible in Git history, not through current-design links.
- `design/FOOD_STORAGE_AUDIT_2026-11-12.md`, earlier mission result files and date-stamped handoffs are provenance for their own stages. Do not copy an old forge recipe, item number reservation or phase acceptance test into active design merely because it was once called FINAL.
- The former long `DOC_MAP.md` inventory is available in Git history; it covered an earlier commit and does not describe current authority.

## Workflow for future agents

1. Read **current approved target** in master, the relevant feature spec and the repaired progression guide.
2. Inspect **current runtime code and item JSON** to see what is actually implemented, keeping that separate from approved future behavior.
3. Check the goal audit recovery for conflicts, missing actions and required evidence. Use the historical audit only as a baseline, not as a rule source.
4. Change one coherent subsystem at a time with ID-safe mapping, validated prerequisites and actual in-game tests. Do not claim a doc update is a fixed playable feature.
5. Update the **single current authoritative rule** in place and remove invalid previous rules, not layers of “new note overrides old note.” Preserve essential historical evidence in dated audit reports/Git history, not active source documents.
