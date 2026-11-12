# Master catalog implementation plan

**Status: PROPOSED PLAN. Nothing in it is authorized.**
- Each phase starts only after two things: Dave has approved the complete catalog (`DYNASTY_MASTER_ITEMS.md`, Draft 18), and Dave has given that phase its own go.
- Work follows `docs/ai-team/WORKFLOW.md`, `TEST_GATES.md` and `docs/PONYTAIL_RULES.md`. Each phase is its own branch and PR into `dev`, never `main`. Each gets an independent gate review of the exact head commit.
- Godot tests and in-game checks run only on Dave's PC. Cloud agents run static checks only.

## Ground rules for every phase

1. **Source of truth.** The master catalog s3 (design), s4 (engineering) and s7 (JSON change list) define the work. Rows marked DELEGATED give the default to follow. Any departure is written in the PR and needs ChatGPT's or Dave's nod. Any change to an item, a count or an owner rule needs Dave.
2. **Numbering.** New rows take numbers from `items.json` `next_number` (896 at `7f8aabf4`), in catalog order. Numbers are never reused.
3. **Inactive rows.** A row whose system is not built yet lands with `future: true` and is switched on in the phase that builds its system. So the data PR can be complete without exposing half-built items.
4. **Save safety.** Every phase that changes a saved shape adds its step to the one migration pass in `CATALOG_SAVE_MIGRATION.md`, with tests.
5. **Contracts.** Any change to the wire or the save format updates `PROTOCOL.md` and bumps `PROTOCOL_VERSION` in the same PR.
6. **Evidence.** Each PR reports which tests actually ran, where, and on which commit.

## Phases

The agent names below are the repo's agent roles.

| Phase | Scope (master section) | Agents | Depends on | Automated tests | In-game check (Dave's PC) |
|---|---|---|---|---|---|
| **0. Gate** | Dave approves the catalog. Recheck it against the latest `dev`. Settle PR #1036. | coordinator, doc-steward | — | Catalog cross-check script (Appendix A against `items.json`) | — |
| **1. Data and save foundation** | Every s7 retirement, rename and status change. Every ADD row, with `future: true` where its system is missing. `renames.json` pairs. The `migrate_catalog` pass skeleton, file version bumps and `.v1.bak` backups. | item-data, systems-engineer, gate-reviewer | 0 | `validate_items.gd`, `items_check.py`, `test_item_renames.gd`, `test_save_compat.gd` (rules 1–5, 12) | Load the latest playtest world. Nothing is lost, and the retired stations still work. |
| **2. Wood, tools and stations** | s2, s3.1–s3.4: Planks and Hardwood boards, saws, axe and firewood chain, Chopping block, kiln batches, Smelter, Smithy and add-ons, Grindstone, Leatherworking, Tailor's Table, Loom, tool tiers, durability, repair and sharpening. | item-data, systems-engineer, gameplay-designer | 1 | Recipe and blueprint validation; first-hour and route-to-saw economy tests; the per-instance slot column test (rule 9) | First hour from a new character to the first iron saw. |
| **3. Furniture** | s3.5: four grades, comfort best-one-per-class rule. | item-data, systems-engineer, art-reviewer | 2 | Comfort rule unit test; furniture recipe validation | Build each grade and check comfort. |
| **4. Weapons, armour, clothing** | s3.6–s3.8: new rows, `wear_layer`, neck slot appended last, quiver slot, per-material weather. | item-data, systems-engineer, art-reviewer | 1 (2 for metal rows) | Worn pre-pass test (rule 6), layering unit tests | Dress in layers, check warmth and protection, load an old character. |
| **5. Carrying** | s3.9: per-bag contents, volume instead of `carry_bonus_kg`, strap and belt points. | systems-engineer, item-data | 1, 4 | Bag contents save and load, no nesting, drop and pick-up conservation | Fill a backpack, drop it, reload, trade it. |
| **6. Cooking and preservation** | s3.12, s3.14: Food Preparation Table (logs and twine), 7 equipment rows, 16 intermediates, recipe moves through `dishes.json`; Smoked Meat, Dried Mushrooms; `ready_age`, batch size, no merge across `ready_age`; preserves moved to the pot; crafted age inherits the oldest input. | item-data, systems-engineer, gameplay-designer | 2 | `gen_dishes.py` regeneration check; recipe validation; spoilage tests (maturing, merge rule, batch conservation, rule 10) | Bake bread pre-iron, seal ×50 Sauerkraut, wait for Ready, smoke meat. |
| **7. Food effects** | s3.16: `food_group` and tier data, three slots with timers and HUD, [D17] initial values, energy aids without the Fitness cost, teas and juice as Beverages, Nut cake tooltip. | systems-engineer, item-data, gameplay-designer | 6 | XP applied at the tick, not midnight; no multiplying; replace and fourth-group prompts; death clears; save and protocol round trip; rule 11 | A day of training with each group; check the HUD and the XP totals. |
| **8. Boards and serving** | s3.15: 8 boards, Serving Platter, portions as stack count, shelf life from the shortest-lived ingredient, table surface point, placed platter. | systems-engineer, item-data, art-reviewer | 6, 7, 3 | Portion conservation, no board merge, place and pick-up round trip | Set a Roast Platter on a table, eat half, pick it up. |
| **9. Storage and locks** | s3.13: 16 rows, `place_mult` rows, Storage sign and Warehouse Desk views (desk over sign), owner, codes, attempt deadlines, locked-crate lift and sourcing rule. | systems-engineer, item-data, art-reviewer | 1, 5 | Lock matrix (owner, code, stranger), 10/20/30/40 s waits surviving reconnect and restart, desk shows only permitted contents, capacity overflow (rule 7) | Two players: share a code, fail three times, use the desk. |
| **10. Movable containers and the Handcart** | s3.11, s3.13: a persistent movable entity, loaded crates as cargo, cargo in the ageing loop, desk context by location. Handcart only (no animal). | systems-engineer | 5, 9 | Move a loaded crate A → cart → B with no duplication or loss, ageing continues, old desk loses access, save mid-trip | Wheel a full crate between two warehouses. |
| **11. Animal keeping** ([D17]: separate later phase) | Design, then build capture or purchase, ownership, leading, riding, hitching, a domestic ox and the paired-draft controller [D10]. Then switch on the 20 tack rows and 9 animal vehicles. | gameplay-designer (design first, for Dave's approval), systems-engineer, item-data | 10 | Ownership save, one-controller pairing, per-animal stamina and health | Ride, pack and hitch a wagon. |
| **12. Later content** | Nutrition guides in NPC dialogue and books, with book rows added then and shelved in the Bookcase [D17]; dairy (Milk, Butter, Cheese, Press) and Ploughman's Board; ship and Captain's Table; coffee and other drinks. | per its own catalog decision | 7, NPC dialogue system | Per feature | Per feature |

**Order and parallel work:**
- Phases 2 and 4 can run in parallel after phase 1. Phase 3 follows 2 (boards need the saw).
- Phases 6 → 7 → 8 run in order.
- Phase 9 can start after 5, in parallel with 6–8. Phase 10 needs 9.
- Phase 11 waits for Dave's design approval.

**Nightly playtest:** each merged phase goes to `dev` for Dave's evening playtest (`nightly-dev-checkpoint`). Promotion to `main` happens only through `merge-validation`, with Dave's go.

## What can be delegated, and what cannot

- **Delegated to the implementing agents:**
  - Every DELEGATED default.
  - Tuning numbers in master s5, which are playtest values.
  - Names in house style (decision 71).
  - Look details within the approved art direction.
  - Test design.
- **Not delegated (needs Dave):**
  - Adding, removing, renaming or re-purposing a catalog row.
  - Changing an owner rule [D#].
  - Merging to `main`.
  - Starting each phase.
  - The animal-keeping design (phase 11).
