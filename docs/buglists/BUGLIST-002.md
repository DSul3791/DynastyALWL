# BUGLIST-002 — Separate Doors and Doorways

**Status:** Implemented in `dev` (PRs #1077 and #1078); automated/headless checks passed; **player F6 verification remains outstanding**  
**Date:** 2026-11-13  
**Scope:** DOOR-001 only  
**Catalog authority:** [Master Items Catalog, section 3.0](../design/DYNASTY_MASTER_ITEMS.md)

## DOOR-001 — Doors must be separate from doorway walls

### Approved design
- Construct a **doorway wall** with an empty, usable opening and frame. Building the wall does not create a door.
- A **door** is a distinct craftable/installable item. Place it into a compatible built doorway, open and close it, and remove or replace it without demolishing the doorway.
- Follow the separate doorway-and-door construction model used in ARK and Atlas. This is a design reference, not permission to copy unrelated systems.
- **All four configurations are implemented in the current `dev` data; the table uses descriptive configuration names**:

| Door | Matching empty doorway | Shape |
|---|---|---|
| Single Door | Single Doorway | Rectangular, one leaf |
| Double Door | Double Doorway | Rectangular, two leaves |
| Single Arched Door | Single Arched Doorway | Rounded top, one leaf |
| Double Arched Door | Double Arched Doorway | Rounded top, two leaves |

- The first two have **straight rectangular tops**, not arches. Arched openings are available for suitable ordinary buildings, including wood and stone construction; they are not exclusive to future ships.
- The established quality progression is **Crude → Rustic → Refined → Sturdy → Superior → Engineered → Fortified**. **Iron and Steel are materials**, not quality tiers. Sturdy is an existing normal construction tier and must not be omitted. Material, quality and configuration are separate attributes.
- **Approved wood-stock definitions:** Plank (`lumber`) = **6 inches wide × 4 inches thick**, rough surface. Hardwood board = **6 inches wide × 2 inches thick**, smooth, shiny surface. Same width; Plank is twice as thick. These are cross-sectional dimensions, not door size or board length.
- **Approved door materials:** Rustic = **Plank with wooden hinges**; Refined = **Hardwood boards + Nails + metal Hinges**; Sturdy = **Plank + Nails + metal Hinges**; Superior = **two layers of smooth, shiny Hardwood boards, attractive nails, ornate metal hinges and a handsome handle**; Fortified = **all-metal iron + steel + rivets**, no wooden core. Superior must look thick and elegant, appropriate for a castle or fine house. Ornate hardware does not automatically require new item types. Engineered remains wood with iron reinforcement. Exact door ingredient quantities are now approved in Master Items Catalog section 3.0; implement them without adding separate hinges, nails, rivets or handles as ingredient costs.
- Compatible doors and frames must match their **geometry and dimensions**. Do **not** require identical materials or quality tiers unless an independently approved rule requires it. A matching door must not be rejected merely because its tier or material differs from the frame.
- Preserve the approved building grid and the existing 4 m double-door frame (two wall cells) where applicable. Use the implementation's corresponding clear opening geometry, not an invented 4 m clear passage.

### Current item naming and frame construction

The shipped display names omit the word **Single** for one-leaf variants. For example, `Rustic - Door`, `Rustic - Arched door`, `Rustic - Double door`, `Rustic - Double arched door`; matching one-leaf frames are `Rustic - Doorway` and `Rustic - Arched doorway`. The names in the configuration table above are descriptive, not exact display-name strings.

**Director-approved frame costs (13 Nov):** A single rectangular or arched frame costs the **same as that tier's wall**. A double rectangular or double arched frame costs **twice the tier's wall**. Frames are placed by hammer blueprint; doors are also placed by hammer blueprint and snap into compatible frames. The door recipes below are separate costs. `Iron - Doorway` and `Steel - Doorway` are retired catalog entries, **not construction tiers**; their old saved instances map to Refined and Fortified empty frames respectively.

### Implementation evidence and outstanding acceptance

- **Merged:** BUGLIST-002 implementation PR #1077 and retirement follow-up PR #1078 on `dev`.
- **Implemented:** eight previously existing empty doorway frames, twenty new frames, twenty-eight standalone doors; matching door attachment, open/close, take-down safeguards, persistence compatibility and approved recipes.
- **Automated/headless evidence:** project ledger records an independent review PASS and a 214-pass/0-fail follow-up run at `94596ec`, with item validation showing zero errors. See [BUGLIST-002 ledger](../ai-team/missions/BUGLIST-002/LEDGER.md).
- **Still unverified by player:** F6 placement, visual material accuracy, sound, icons, frame-rate and multiplayer behavior in a real session. The ledger records new door/frame icon baking as blocked at last review. Do not treat code/test completion as player acceptance.

### Approved door crafting costs

These ingredients and counts are **director-approved** for the door items; doorway-wall costs are separate. Hinges, nails, rivets and handles are incorporated into the listed materials, not additional ingredient requirements. Keep the visual hardware on the model.

| Tier | Single Door / Single Arched Door | Double Door / Double Arched Door |
|---|---|---|
| Crude | 50 Stick, 100 Twine | 100 Stick, 200 Twine |
| Rustic | 5 Plank | 10 Plank |
| Refined | 6 Hardwood board, 1 Iron ingot | 12 Hardwood board, 2 Iron ingot |
| Sturdy | 6 Plank, 2 Iron ingot | 12 Plank, 4 Iron ingot |
| Superior | 12 Hardwood board, 2 Iron ingot, 1 Steel ingot | 24 Hardwood board, 4 Iron ingot, 2 Steel ingot |
| Engineered | 12 Plank, 4 Iron ingot | 24 Plank, 8 Iron ingot |
| Fortified | 10 Iron ingot, 10 Steel ingot | 20 Iron ingot, 20 Steel ingot |

**Simple invariant:** Double doors use exactly twice the same-tier single-door ingredients. Arched doors cost exactly the same as their corresponding rectangular doors. Do not introduce arch premiums or extra material classes. See the master catalog for art/geometry design.

### Implemented contract and remaining acceptance requirements
1. **Reconciled in `dev`:** Existing doorways were converted to empty frames, 20 additional frames and 28 separate doors were added. Preserve this completed reconciliation; review changes only if new evidence reveals a defect.
2. **Allocated in `dev`:** The seven tiers × four configurations give 28 door variants and 28 corresponding frame variants, using existing frame IDs where available. The implementation allocated 20 new frame items and 28 new door items, not 56 new item IDs. Keep the assigned IDs and reservations stable.
3. Correct all legacy doorway variants that automatically include a door. Keep the structural opening, remove integral door operation, and provide a separate compatible door item.
4. Door placement must validate the built frame and correctly match single/double width and rectangular/arched profile. Preview and actual placement decisions must agree, with a meaningful refusal when invalid.
5. Opening, closing, collision, movement through the opening, ownership of interaction state, multiplayer synchronization, and save/reload must work correctly. For double doors, ensure both leaves function as a double-door assembly.
6. Removal or replacement of a door leaves the doorway wall intact. Do not create duplicate doors or lose existing structures during save/load. Follow the **current approved save policy** rather than inventing a new migration requirement.
7. Item, blueprint, structure and catalog-ledger changes were integrated in `dev` using the exact approved door costs above. **Frame costs are now approved: a frame costs the same as its tier's wall; arched costs the same; double costs 2×.** Icons and real-game visual acceptance remain separate art/playtest work. Rustic wooden hinges should use the existing wood material chain if possible, not automatically a new item.
8. This is **specific owner authorization** for the door/doorway corrections and additions stated here. It does not lift the catalog freeze for other items or authorize changing unrelated tiers, construction pieces, or game systems.

### Verification and delivery
- Test all four configurations, covering all seven approved construction tiers (7 × 4 = 28 logical pairings); report any unsupported combination as incomplete rather than excluding it.
- Verify correct shape, snapping, empty opening, opening/closing, passability, door removal/replacement, persistence, and mismatched-door rejection.
- Verify Rustic uses rough 4-inch Planks and wooden hinges; Refined uses polished 2-inch Hardwood boards with nails and metal hinges; Sturdy returns to rough 4-inch Planks with nails and metal hinges; Superior uses **two layers of smooth 2-inch Hardwood boards with ornate metal hinges, visible finished nails and an attractive handle**. Check in-game appearance and thickness; document any rendering-scale conflict rather than quietly changing global building geometry.
- Test an appropriately sized compatible door in a frame made from a different material/quality; do not introduce a same-tier-only rule.
- Check existing Sturdy/stone and other placed doorways and save/reload under the current save policy. Run catalog consistency checks and relevant building regression tests.
- Use the existing reviewed integration and headless test evidence; carry out the remaining real-game F6 checks and art/icon verification before claiming player acceptance.

**Workflow:** Any follow-up fixes still follow the active `CLAUDE.md`, project review and test gates, with PRs to `dev` and no direct `main` changes. Do not claim player verification from automated checks.

### Out of scope
Locks, permissions, keys, automatic closing, ships, unrelated catalog items, and new quality tiers. Report genuinely unresolved design choices rather than inventing restrictions.

### Design provenance
Dave's direct decisions on 13 November 2026 supersede earlier AI-authored descriptions of doors permanently integrated into doorway walls. The earlier records remain historical evidence, not instructions to retain integral doors.
