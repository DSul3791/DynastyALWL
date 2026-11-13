# BUGLIST-001 backpack: DESIGN-001 (backpacks improve carry weight, not inventory slots)

Baseline SHA f5d6b54 (origin/dev). Branch `claude/buglist001-backpack`. No Godot ran in the cloud: every test below is NOT RUN until the PC run.

Requirement (BUGLIST-001 section C): equipping a backpack must not change the count of inventory slots; it improves comfortable carry-weight capacity and encumbrance through weight distribution; different quality may change the effect; verify before/equipped/after-unequip, no item loss or duplication near capacity or in saves.

## Verification by reading the code (baseline f5d6b54)

| Point | Result | Evidence |
|---|---|---|
| Wearing changes the pack's slot count | PASS | `_wear` (server_items.gd, just above `_unwear` at 11994) only moves the piece to a worn position and returns displaced pieces to the pack; nothing touches `inv.slot_count`/`usable`. The pack grows or shrinks only with its contents (inventory.gd:63 `trim`, protocol 116). |
| A backpack adds slots of its own | FAIL on the strict reading, see Q1 | items.json rows 50 and 767 carry `bag_slots` 10 and 15 (catalog Phase 5, M001-T15, `src/shared/bag_rules.gd` `slots_of`): a separate per-bag container opened from the Tab screen, held in the worn piece's instance data. The pack itself stays 30 slots. |
| Wearing raises comfortable carry weight or the limit | FAIL (the defect) | `carry_bonus_kg` was deleted in fc67431 (M001-T15): `_carry_body` (server_items.gd:11936) returned the body weight alone and client `carry_body_kg` (inventory_view.gd:4653) likewise; docs/CARRY_WEIGHTS.md:17, master s3.9 rule 2 and validate_items.gd:1186 forbade it; test_carrying.gd asserted "the worn pack does not raise the carry limit". The reverse of DESIGN-001. |
| Quality matters | FAIL (baseline) | No weight effect existed on either row, so hide and leather encumbered identically; only bag_slots differed (10 vs 15). |
| Unequip near capacity: loss or duplication | PASS | `_unwear` (server_items.gd:11994) does `inv.add(...)`; if that fails the piece stays worn ("Your pack is full") so nothing is lost or doubled; the pack grows for it. Over the limit afterwards: slowed, never stripped, told once (`_carry_notice`, server_items.gd:10143; CATALOG_SAVE_MIGRATION.md rule 10). |
| Saves | PASS | Worn pieces and their instance data are saved in characters.json `worn`; the effect is derived from the worn numbers on every read, so nothing extra is persisted. |

## Change (second part of the commit, easy to drop if the ruling differs)

Restore the weight effect for the two backpacks only, from the values the catalog already carried before M001-T15 retired them (items.json at fc67431^: Hide - Backpack 12, Leather - Backpack 18; master DYNASTY_MASTER_ITEMS.md s3.9 table row "Backpack carry bonus"). No new numbers, items, mechanics, protocol or save-format change.

- data/items/items.json: `carry_bonus_kg` 12 on row 50, 18 on row 767 (field restored; bag_slots untouched).
- src/shared/carry_rules.gd: `carry_bonus_kg(numbers, table)`, the shared sum over worn numbers.
- src/stream/server_items.gd `_carry_body`: body weight plus bonus / carry_kg_per_body_kg (the original formula), so the limit and the comfortable load (free_ratio of it) both rise (limit +12 or +18 kg, comfortable +9.6 or +14.4 kg). Everything keyed on it follows: pick-up refusal `_fit`, `_carry_notice`, loaded-bag effort, cart cargo check.
- src/client/inventory_view.gd: `carry_body_kg` the same (bar, walk slowdown, pick-up gate); the item tooltip says "you can carry N kg more".
- src/worldgen/tools/validate_items.gd: `carry_bonus_kg` allowed only as above 0 up to 60 kg on a `back` piece (was forbidden everywhere).
- docs/CARRY_WEIGHTS.md note updated. Item descriptions left as they are ("its load still weighs on you" stays true).

## Tests (NOT RUN)

- NEW src/worldgen/tools/test_backpack_carry.gd (+ .uid): measures slots, limit and comfortable load before equipping, with Hide then Leather worn, after unequipping; leather above hide; a load that slows a bare body but not a wearer; near capacity (40 axes + 28 stones, 69 stacks, 68 kg) worn then taken off: nothing lost or doubled, slowed and told once, no further pick-up; an emptied pack back to 30 slots; save and reload worn, then unequipped. Prints `INFO` lines with the raw numbers for the evidence run.
- ADJUSTED test_carrying.gd (rows 50/767 now have the bonus and no other row does; the worn-pack check expects +12 kg) and test_warmth.gd:149 (same). Both asserted the retired behaviour.
- Run: `godot --headless --path . --script res://src/worldgen/tools/test_backpack_carry.gd`, then test_carrying, test_warmth, test_pack_growth, validate_items.

Regression risks: both adjusted tests encoded the old rule; a player over the plain limit after taking a pack off is only slowed (rule 10); bag slots on the backpacks still exist (Q1); master s3.9 rule 2 text and the T15 docs now disagree with the code (history, left as written).

Status: NEEDS PLAYER VERIFICATION (weight effect). Slot point: see Q1.

## Open questions (decisions recorded, nothing waited on)

- Q1: Does "must not change the count of inventory slots" also forbid the backpack's own `bag_slots` container (10 and 15 slots, T15)? Recorded decision: the pack's slot count is unchanged (PASS) and the bag containers are left, because removing `bag_slots` from rows 50/767 would orphan contents already saved inside worn or carried backpacks (a migration, a Class C save question), and about a dozen tests (test_carrying, test_hotbar_keys, test_mission001_walkthrough, ...) use the backpack as their bag. The rucksack, pack basket and satchel are also unchanged. If Dave means no bag slots on backpacks, that is a separate ruled change with a contents migration.
- Q2: The restored 12 and 18 kg are the earlier catalog values, not newly tuned ones; confirm or retune (data/items/items.json only).
- Q3: master s3.9 rule 2 ("a pack never adds muscle power", marked APPROVED [D9]) conflicts with DESIGN-001. I followed DESIGN-001 (Dave's later, explicit requirement); the master text needs a note from the document owner.

## F6 player check

Wear the Hide - Backpack with the pack nearly full of stone (carry bar yellow or red around 42 kg): the bar's comfortable mark and limit move out (about 51.6 and 64.5 kg at 75 kg body), the walk returns to normal speed, and the inventory shows the same slots; take it off and the bar and slowdown return. The Leather - Backpack moves them further (about 56.4 and 70.5 kg).
