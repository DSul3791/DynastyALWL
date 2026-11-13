# BUGLIST-002 — Separate Doors and Doorways

**Status:** Active — approved design correction; implementation pending  
**Date:** 2026-11-13  
**Scope:** DOOR-001 only  
**Catalog authority:** [Master Items Catalog, section 3.0](../design/DYNASTY_MASTER_ITEMS.md)

## DOOR-001 — Doors must be separate from doorway walls

### Approved design
- Construct a **doorway wall** with an empty, usable opening and frame. Building the wall does not create a door.
- A **door** is a distinct craftable/installable item. Place it into a compatible built doorway, open and close it, and remove or replace it without demolishing the doorway.
- Follow the separate doorway-and-door construction model used in ARK and Atlas. This is a design reference, not permission to copy unrelated systems.
- **All four configurations are in scope now**:

| Door | Matching empty doorway | Shape |
|---|---|---|
| Single Door | Single Doorway | Rectangular, one leaf |
| Double Door | Double Doorway | Rectangular, two leaves |
| Single Arched Door | Single Arched Doorway | Rounded top, one leaf |
| Double Arched Door | Double Arched Doorway | Rounded top, two leaves |

- The first two have **straight rectangular tops**, not arches. Arched openings are available for suitable ordinary buildings, including wood and stone construction; they are not exclusive to future ships.
- The established quality progression is **Crude → Rustic → Refined → Sturdy → Superior → Engineered → Fortified**. **Iron and Steel are materials**, not quality tiers. Sturdy is an existing normal construction tier and must not be omitted. Material, quality and configuration are separate attributes.
- **Approved wood-stock definitions:** Plank (`lumber`) = **6 inches wide × 4 inches thick**, rough surface. Hardwood board = **6 inches wide × 2 inches thick**, smooth, shiny surface. Same width; Plank is twice as thick. These are cross-sectional dimensions, not door size or board length.
- **Approved door materials:** Rustic = **Plank with wooden hinges**; Refined = **Hardwood boards + Nails + metal Hinges**; Sturdy = **Plank + Nails + metal Hinges**; Superior = **two layers of smooth, shiny Hardwood boards, attractive nails, ornate metal hinges and a handsome handle**; Fortified = **all-metal iron + steel + rivets**, no wooden core. Superior must look thick and elegant, appropriate for a castle or fine house. Ornate hardware does not automatically require new item types. Engineered remains wood with iron reinforcement. Exact ingredient quantities remain to be approved by Dave, not delegated to Claude.
- Compatible doors and frames must match their **geometry and dimensions**. Do **not** require identical materials or quality tiers unless an independently approved rule requires it. A matching door must not be rejected merely because its tier or material differs from the frame.
- Preserve the approved building grid and the existing 4 m double-door opening wherever applicable. Keep door dimensions aligned with the actual frame geometry; do not invent new universal sizes.

### Implementation requirements
1. Audit the live `dev` catalog, master list, ledger, recipes, blueprints, structures, existing doorway variants and opening/closing states **before editing**.
2. Create a reconciliation table showing which existing item IDs and records can be reused, which require corrected descriptions or behavior, and which separate door/doorway entries must actually be added. **Seven tiers × four configurations require 28 logical door/doorway pairings, not automatically 56 new item IDs.** Follow official number allocation; never reuse an ID.
3. Correct all legacy doorway variants that automatically include a door. Keep the structural opening, remove integral door operation, and provide a separate compatible door item.
4. Door placement must validate the built frame and correctly match single/double width and rectangular/arched profile. Preview and actual placement decisions must agree, with a meaningful refusal when invalid.
5. Opening, closing, collision, movement through the opening, ownership of interaction state, multiplayer synchronization, and save/reload must work correctly. For double doors, ensure both leaves function as a double-door assembly.
6. Removal or replacement of a door leaves the doorway wall intact. Do not create duplicate doors or lose existing structures during save/load. Follow the **current approved save policy** rather than inventing a new migration requirement.
7. Update the master catalog, live catalog ledger, applicable item/blueprint/recipe/structure definitions, descriptions, icons and implementation documentation consistently. Reconcile actual craft costs and construction methods with existing approved item progression; **do not invent a new material or recipe design**. Rustic wooden hinges should be implemented using the existing wood material chain if possible, not automatically as a new item.
8. This is **specific owner authorization** for the door/doorway corrections and additions stated here. It does not lift the catalog freeze for other items or authorize changing unrelated tiers, construction pieces, or game systems.

### Verification and delivery
- Test all four configurations, covering all seven approved construction tiers (7 × 4 = 28 logical pairings); report any unsupported combination as incomplete rather than excluding it.
- Verify correct shape, snapping, empty opening, opening/closing, passability, door removal/replacement, persistence, and mismatched-door rejection.
- Verify Rustic uses rough 4-inch Planks and wooden hinges; Refined uses polished 2-inch Hardwood boards with nails and metal hinges; Sturdy returns to rough 4-inch Planks with nails and metal hinges; Superior uses **two layers of smooth 2-inch Hardwood boards with ornate metal hinges, visible finished nails and an attractive handle**. Check in-game appearance and thickness; document any rendering-scale conflict rather than quietly changing global building geometry.
- Test an appropriately sized compatible door in a frame made from a different material/quality; do not introduce a same-tier-only rule.
- Check existing Sturdy/stone and other placed doorways and save/reload under the current save policy. Run catalog consistency checks and relevant building regression tests.
- Record automated test evidence, independent review, integration commit/PR and an F6 checklist for player acceptance.

**Workflow:** Read the active `CLAUDE.md`, team authorities and test gates; develop on focused branches, submit reviewed PRs to `dev`, and leave `main` unchanged. Do not claim player verification from automated checks.

### Out of scope
Locks, permissions, keys, automatic closing, ships, unrelated catalog items, and new quality tiers. Report genuinely unresolved design choices rather than inventing restrictions.

### Design provenance
Dave's direct decisions on 13 November 2026 supersede earlier AI-authored descriptions of doors permanently integrated into doorway walls. The earlier records remain historical evidence, not instructions to retain integral doors.
