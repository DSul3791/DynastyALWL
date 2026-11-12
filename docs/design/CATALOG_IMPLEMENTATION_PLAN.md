# Master catalog implementation plan

**Status: AUTHORIZED (Mission 001).** Dave approved the complete catalog (`DYNASTY_MASTER_ITEMS.md`, Draft 18, commit `0707384`, PR #1035) and authorized Phases 0–10 and 1b in his Mission 001 brief (project thread "Mission 001", 12 Nov 2026 05:33Z). No phase in that range needs a separate owner go. Phase 11 (animal keeping) and Phase 12 (later content) are **not** authorized.
- The live ledger of every catalog entry is `docs/design/catalog_ledger.json`, checked by `python3 -I tools/catalog_ledger.py --check`. Mission state and the task queue: `docs/ai-team/missions/M001/STATE.md`.
- Work follows `docs/ai-team/WORKFLOW.md`, `TEST_GATES.md` and `docs/PONYTAIL_RULES.md`. Feature branches merge into `dev` by PR after an independent review of the exact head commit, never into `main` (Dave's explicit go only).
- Godot tests and in-game checks run only on Dave's PC, in separate worktrees or clones, never in his checkout, and never while they would disturb his play.

*Corrections from the PR #1035 version (Mission 001 Phase 0): the per-phase owner go is removed; the Phase 2/4 dependency contradiction is fixed by splitting Phase 4; craftsmanship and Tempered steel move out of Phase 12 into Phase 2 (functional) on the Phase 1b instance data; in-scope work and future-gated rows are separated; gates and parallel work are listed per phase; Dave's new-game ruling below replaces old-save migration.*

## Dave's new-game ruling (12 Nov 2026 05:41Z)

Dave: "this is a new game so there are no existing things in the world don't worry about stuff that exists." So:
- **No old-save migration.** The `migrate_catalog` pass, `.catalog.bak` backups, per-file stamps, `worn_moved`, refund lists for retired items and capacity-overflow moves in `CATALOG_SAVE_MIGRATION.md` are **not built**. That document stays as the record of what was considered; its rules 1, 2, 4 (rename half), 5, 6 (refund half), 7, 9, 12–14 are superseded by this ruling.
- **Still required:** every new or changed saved shape round-trips (save, quit, load) with nothing lost or duplicated; a file from a newer format is set aside, not misread, and an older-format file is either read with defaults or refused cleanly, never misread; the wire format changes with `PROTOCOL.md` and a `PROTOCOL_VERSION` bump; retired rows keep their numbers (never reused) and stay in the files.
- **Retirements land directly**, in the phase that delivers the replacement, so `dev` stays playable every night. A retired blueprint simply stops being buildable.
- **Playtest worlds:** a world made on an older `dev` may not load after a format bump. Each nightly report says when Dave should start a new world.

## Ground rules for every phase

1. **Source of truth.** Master s3 (design), s4 (engineering) and s7 (JSON change list). DELEGATED, RECOMMEND and ENGINEERING rows are the defaults. A justified technical refinement that keeps the design is a coordinator call, written in the PR and reviewed. Adding, removing, renaming beyond house style, or re-purposing a row, or changing a [D#] rule, needs Dave.
2. **Numbering.** New rows take numbers from `items.json` `next_number` (896 at `bd0628a`), in catalog order. Numbers are never reused.
3. **Inactive rows.** A row whose system is not built lands with `future: true` and is switched on in the phase that builds its system. Animal tack, animal vehicles and the Reinforced wagon wheel stay `future` throughout Mission 001.
4. **Generated data** changes through its generator (`tools/gen_dishes.py` for dishes, the Appendix A generator for the catalog appendix).
5. **Contracts.** Any change to the wire or the save format updates `PROTOCOL.md` and bumps `PROTOCOL_VERSION` in the same PR.
6. **Small PRs.** A phase is several feature branches; each is one reviewable, testable increment that leaves `dev` playable.
7. **Evidence.** Each PR records which tests ran, on which machine and exact commit, as PASS, FAIL, BLOCKED or NOT RUN, and updates the ledger rows it touches.

## Phases

| Phase | Scope (master section) | Depends on | Acceptance gate (all on Dave's PC unless static) |
|---|---|---|---|
| **0. Baseline** | Verify Draft 18 against `dev`; integrate PR #1035; settle PR #1036; this plan; the ledger. | — | Static: `catalog_ledger.py --check` PASS; independent doc review PASS. |
| **1. Data foundation** | Every ADD and new FUTURE row created with `future: true` (numbers, names in house style, weights, looks placeholders marked); house-style renames of existing rows (same numbers); the `hidden` blueprint flag is not needed (new game). | 0 | `validate_items.gd`, `items_check.py`, `test_blueprints.gd`, `test_item_renames.gd`; startup smoke; ledger numbers filled. |
| **1b. Item-instance format** | One slot format and protocol bump (master s4 items 2, 15, 16): per-instance column for sharpness, current maximum durability, Tempered, craftsmanship (0, +1, +2) and two magical slots; `worn` as slot arrays; new worn slots (neck, strap, quiver) appended to `clothing.json`; instance data shown in the tooltip; instance items never merge with plain stacks; a magical slot write refuses an occupied slot and nothing can clear one. | 1 | Save/load round trip of every field in pack, chest, ground and worn; wire round trip; merge refusal; magical-slot permanence test; startup smoke. |
| **2a. Wood and saw route** | s3.2, s2.7 item 1: Planks 6 per log, Hardwood board (sawmill and hand-saw recipes), sawmill yields, the log groups split so Planks and Hardwood boards never substitute, Chopping block, firewood renames, species lumber and beams retired. | 1 | `test_lumber_route.gd`, `test_logs_carry.gd`, first-hour economy tests; no Plank meets a board cost or the reverse. Uses today's stations; the saw recipe moves in 2b. |
| **2b. Metal and stations** | s3.3, s3.4: Smelter, Smithy, Blast Furnace, Bellows, Quenching Trough, kiln charcoal batches, Leatherworking Table, Tailor's Table, Loom, Thread; the Iron - Saw (recipe 157) at the burning Smithy with no Saw blade; Clay bloomery, Anvil, Stone - Wedge and Saw blade retired with their replacements. | 1, 2a | Bog iron → charcoal → Smelter → Smithy → Iron - Saw walkthrough as an automated player test; recipe and blueprint validation. |
| **2c. Tools, durability, craftsmanship** | s3.1, s2.2, s2.9, s4 items 1, 2, 13, 15: tool ladders and groups, tier renumbering, Stone - Sickle and Stone - Spade retired beside the Bronze - Sickle, break and repair rules, sharpening (Whetstone, Grindstone), **Master Smithy +1/+2 physical craftsmanship and Tempered steel (functional)**. | 1b, 2b | Durability, sharpness and repair unit tests; craftsmanship applied once at craft and saved; Tempered only for eligible steel with the Trough, never stacked or added by repair; durability and sharpness read the instance data. |
| **3. Furniture** | s3.5: four grades, comfort best-one-per-class rule. | 2a | Comfort rule test; furniture blueprint validation; build each grade. |
| **4a. Layering model** | s3.7, s3.8 rules: `wear_layer` on every clothing and armour row, the merged layer model (neck, sock liner, Dress span), per-material weather fields. No new rows switched on. | 1b | Layering unit tests; equip and unequip conservation; warmth regression. |
| **4b. Weapons, armour, clothing rows** | s3.6–s3.8 rows and recipes at their stations; protection values and damage modes. | 4a, 2b (stations, Thread, steel), 2c (instance data for steel) | Recipe validation; dress in layers; protection and warmth checks. |
| **5. Carrying** | s3.9: per-bag contents, volume instead of `carry_bonus_kg`, strap and belt points, quiver slot. | 1b, 2b, 4a | Bag contents save/load, no nesting, drop and pick-up conservation, two-player hand-over. |
| **6. Cooking and preservation** | s3.12, s3.14: Food Preparation Table, 7 equipment rows, 16 intermediates (prepare → cook), Smoked Meat, Dried Mushrooms, `ready_age` batches at Preserving Jar #830. | 2b (Iron equipment needs the Smithy; basic bread stays pre-iron) | Prepare→cook tests; batch conservation; no merge across `ready_age`; no use of unready stacks. |
| **7. Food effects** | s3.16: three group slots with timers and HUD, [D17] values, energy aids without the Fitness cost. | 6 | XP applied at the tick when earned, never retroactive; replace and expire; no stacking; death clears; save and wire round trip. |
| **8. Boards and serving** | s3.15: 8 boards, Serving Platter, portions as stack count, placed platter on a table. | 6, 7, 3 | Portion conservation; place and pick-up round trip; no duplication. |
| **9. Storage and locks** | s3.13: 16 rows, `place_mult`, owner and four-digit codes (leading zeros), failed-attempt waits, Storage sign and Warehouse Desk views. | 1b, 3 | Lock matrix (owner, code, stranger), waits surviving reconnect and restart, desk shows only permitted contents, no duplication. |
| **10. Movable containers and the Handcart** | s3.11, s3.13: persistent movable entity, loaded crates as cargo, ageing in transit, Handcart, Wooden cart wheel, Axle assembly. | 2a, 5, 9 | Move a loaded crate A → cart → B with no loss or duplication; ageing continues; save mid-trip. |
| **11. Animal keeping** — NOT AUTHORIZED | Design first, for Dave; then tack, animal vehicles, Riding - Boots. | 10 | Per its own approval. |
| **12. Later content** — NOT AUTHORIZED | Nutrition guides and books, poison arrows, **magical enchantment application and effects** (the slots exist from 1b and stay empty), dairy, ships, more drinks. | 7, 9 | Per feature. |

**Earliest functional craftsmanship:** Phase 2c. Phase 1b stores and shows the data; Phase 2c makes the Master Smithy and the Quenching Trough produce +1/+2 and Tempered instances whose effects durability and sharpness actually read.

**Order and parallel work:**
- 0 → 1 → 1b in order.
- After 1: 2a and 2b may run in parallel (they share `recipes.json`: one owner at a time per data file, rebased in order).
- After 1b: 4a runs in parallel with 2. 2c needs 1b and 2b.
- 3 after 2a. 4b after 4a, 2b and 2c. 5 after 4a and 2b.
- 6 → 7 → 8 in order (8 also needs 3). 9 after 3 and 1b, parallel with 6–8. 10 after 5 and 9.
- File ownership: `data/items/*.json` and `src/stream/server_items.gd` have one writer at a time, assigned in `STATE.md`.

**Nightly playtest:** accepted increments go to `dev` (`nightly-dev-checkpoint`), reported with the exact SHA, what is newly playable, tests actually run, known problems and whether a new world is needed. `main` only through `merge-validation` with Dave's go.

## Existing FUTURE rows switched on (Q1, decided 12 Nov 2026)

The status column of Appendix A leaves the existing FUTURE rows FUTURE; the catalog switches some on in its text: Steel ingot 32 (s3.3: the Blast Furnace "goes live: steel") and the rows below. Under Dave's direction to decide from the documents (12 Nov 05:42Z), the mission lead decided: each such row is switched on in the phase that delivers its station and materials, as rule 3 does for new rows. Steel ingot 32 in 2b; the five steel tools (34, 47, 224, 561, 800) in 2c; the nine metal swords, maces and shields (315–323) and six metal armour pieces (326, 328–331, 838) in 4b, with the catalog's fixes (Bronze - Shield without Planks, the Steel - Sword and Steel - Cuirass descriptions); Meatballs 837 in 6 (s3.12 DELEGATED). Sources: s3.6 says the metal weapons "stay FUTURE until their metal is live"; s4 item 15 says the steel rows go live with the Blast Furnace's steel; s3.7 names the six metal pieces "core armour". Copper pot 835 and Fish soup 836 stay FUTURE (the master keeps them FUTURE in s3.12 and Appendix A, and no phase needs them), as do the other FUTURE rows (coins, dairy, traps, coop, obsidian, magic tonic and the like). Record: `docs/ai-team/missions/M001/STATE.md`.
