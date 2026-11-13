# BUGLIST-002 — Door / Doorway Design Correction

**Status:** ACTIVE — DIRECTOR-APPROVED design requirements; implementation and audit assignment  
**Date:** 2026-11-13  
**Scope:** Exactly one issue, DOOR-001. BUGLIST-001 is retired.  
**Authoritative catalog:** `docs/design/DYNASTY_MASTER_ITEMS.md`, section 3.0 (BUGLIST-002 director-approved amendment).  
**Design provenance:** Dave's direct conversation decisions, 13 Nov 2026. Earlier automatic integral-door walls were an AI-generated interpretation, not Dave's approved design.

## DOOR-001 — Every door is a separate item installed in a matching empty doorway

### Four door/doorway pairs — ALL required now

| Door item | Separate matching structural wall item | Opening |
|---|---|---|
| Single Door | Single Doorway | Rectangular, straight lintel, one hinged leaf |
| Double Door | Double Doorway | Rectangular, straight lintel, two leaves |
| Single Arched Door | Single Arched Doorway | Rounded top, one leaf shaped to fit |
| Double Arched Door | Double Arched Doorway | Rounded top, two leaves shaped to fit |

**The first two are NOT arched.** Arches are general building features for timber, stone, brick and other suitable walls; not reserved for ships. Ships themselves are outside this ticket. "Shingle door" was an apparent typo for "single door"; do not add a shingle door.

### Established quality progression
Crude → Rustic → Refined → Superior → Engineered → Fortified. Those are quality tiers. Iron and steel are **materials**, not extra tiers. Door shape/leaf count is separate from material and tier. The catalog section specifies the four pairs as item families across the six tiers. Reconcile existing doorway item rows rather than duplicating or renumbering them. Do not promise a particular recipe or material progression that Dave has not approved.

### Required behavior / acceptance
1. Building a doorway creates only the wall segment, jamb/frame and an open passage. It has no door leaf, door toggle or door-specific interaction.
2. Each door is independently crafted/acquired, held and installed into an existing compatible doorway using normal item/build placement. Do not construct the door automatically with the wall.
3. The installed door owns open/closed state and interaction (existing E-key convention). Closed obstructs passage, open clears it; doorway stays in place on removal/replacement.
4. Match single vs double widths and rectangular vs arched top shapes. Incorrect combinations show an invalid preview and a truthful reason. A matching door fits the matching frame; no unsupported placement into arbitrary walls or free space.
5. Preserve current 2 m grid and approved 4 m double-door opening where applicable. Investigate geometry, hinge, snapping, occlusion, collision, placement preview/final parity, multiplayer/state replication, persistence, animal collision / structure grid, and replacement / dismantle.
6. Every one of the six quality levels must be represented in the catalog family specification. Exact existing IDs, new IDs and per-tier material recipes must be inventoried against current `dev`; allocate through the official catalog rules, never reuse/guess numbers. Flag only true design gaps; do not quietly invent names or extra classes.
7. Legacy doorway-with-built-in-door implementations are incorrect. Audit **all** tiers, 4 m double doorways, any iron/steel-named material variants, engineered and fortified; separate their integral door leaves/states. Preserve ids and saved-world semantics via tested explicit migration/compatibility; don't delete existing player structures or reuse retired IDs.
8. Update all authoritative item/catalog entries, ledger/implementation contract, blueprint/recipe/structure data, graphics/icons/tooltips, tests and relevant design documentation. This task is a narrow **owner-authorized exception** to the discretionary item-catalog freeze for these explicitly approved door/doorway families only. Keep the frozen unrelated catalog intact. Follow existing independent review and PR gates.
9. Do not add locks, keys, permission controls, automatic closing, ship systems, new construction tiers, or a larger redesign without separate approval. Existing functionality must not be unintentionally removed.

### Required engineering plan and evidence
- Establish fresh `origin/dev` baseline and current master/ledger; document the exact existing doorways, IDs, state twins, recipe/blueprint data, door item gaps and item-reservation/ledger requirements.
- Build a reconciliation matrix by **tier × configuration**: existing doorway reused/updated, missing doorway added, separate door added, match anchor, craft path, state/persistence, tests. One semantic entity per stable ID, no duplicates.
- Implement on scoped task branches, with review/test gates and PRs targeting **dev**, NOT main. Do not commit gameplay changes to this documentation branch. Reconcile catalogue section 3.0 into the approved master in the work itself; don't leave runtime/catalog inconsistent.
- Automated checks: each pairing accepts only matching frame, both leaves on double types, correct rectangular/arched geometry, empty doorway passability, mounted closed/open passability, removal/replacement, server/client placement agreement, save/reload, catalog ledger checker, old existing structures and unrelated walls/roofs/gates.
- Run applicable tests on actual test PC and produce F6 checklist. Never claim game acceptance without running it and Dave verifying visually.

### Coordinator handoff
Coordinate DOOR-001 as the **only** BUGLIST-002 issue. Read this report and the master catalog amendment, current approved repository instructions and records, and reconcile the legacy design contradiction with explicit director provenance. Carry the work through validated `dev` integration, with evidence and concise status for Dave. Escalate only material uncovered conflicts or design questions; preserve independent progress.
