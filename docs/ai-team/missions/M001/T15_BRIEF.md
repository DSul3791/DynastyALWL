# M001-T15 brief: Phase 5 carrying equipment

Mission 001, Phase 5 (`docs/design/CATALOG_IMPLEMENTATION_PLAN.md`). Owner: systems-engineer agent (data and code). Reviewer: independent gate-reviewer. Branch `m001/p5` in clone `E:\Software\godotDev\m001_p5` (base `dd903d971` = dev `fefee0aa2` tree: 4a worn layers with append-only positions, 1b instance data, protocol 107). New game: no old-save migration.

Parallel work: Phase 4b (m001_p4b) edits weapon/armour/clothing rows and combat code; Phase 6 and 9 edit food and containers. Keep JSON edits line-local (helper `C:\Users\david\AppData\Local\Temp\claude\01b3e68161e49208\35a61d07-6ae9-47de-b88c-fe7400bb03ef\scratchpad\jsonedit.py`). Your recipe numbers: 600-649; protocol: take 109 (4a 107, Phase 9 108).

## Behaviour (master `docs/design/DYNASTY_MASTER_ITEMS.md` s3.9 rules and reconciliation table, s4, s7 item 15, s8; `CATALOG_SAVE_MIGRATION.md` rules 10-11 for intent)
1. **Nine carrying rows go live** (Fibre - Shoulder bag, Wicker - Pack basket, Leather - Satchel, Belt pouch, Tool roll, Traveller's rucksack, Wooden - Pack frame, Weapon scabbard, Utility bandolier) with `worn.json` rows and recipes at the stations s3.9 names; the 6 kept gear rows (Hide/Leather - Backpack, Hide/Leather - Quiver, Leather - Belt, Bedroll) updated as the table says (quiver descriptions; Bedroll attachable to the pack exterior, not a backpack slot).
2. **Per-bag contents** (s3.9 rule 3, s8): a bag is an individually tracked instance holding its own nested inventory, saved with the bag instance (in the 1b `inst` data or a keyed store referenced from it), sent to its owner, carried with the bag when dropped, picked up, traded or put in a chest. **No nesting** (a bag cannot go inside a bag). Drop and pick-up conserve every item. A bag on the ground or in a chest keeps its contents and spoilage continues.
3. **Volume instead of `carry_bonus_kg`**: bags add organized volume (extra slots of their own), not carrying strength; total burden still counts toward the carry limit (s3.9 rule: "increases organized volume but total burden still counts"); remove `carry_bonus_kg` once volume works; an over-cap player is slowed, not stripped, with a one-time notice (migration rule 10 intent).
4. **Attachment points**: worn positions for back (one pack), waist (belt), belt attachments (pouch, quiver, scabbard) and a shoulder/strap position (satchel, shoulder bag), appended to `clothing.json worn` (append-only, as 4a set it); quiver at hip/waist coexists with a backpack. Content limits per bag type where the catalog names them (pouch: small items; tool roll: small tools; quiver: arrows of its capacity 40/60; scabbard: one suitable blade; bandolier: small consumables, no strength bonus; pack frame: awkward loads such as logs and ore sacks).
5. Bag UI: open a worn bag's contents beside the pack (existing container panel pattern), move items in and out, see weight.
6. Looks: placeholders marked (NOT visually complete). Ledger rows updated; `catalog_ledger.py --check` passes.

## Rules
Work only in `E:\Software\godotDev\m001_p5`. Never touch `C:\GodotProjects\DynastyALWL` or other clones. Do not push. Godot only through the slot scripts with timeouts; never kill a Godot process you did not start. No catalog changes beyond the catalog text; report problems.

## Acceptance (voxel build)
- New tests asserting real server state: fill a backpack, drop it, pick it up, contents identical; save and reload a worn and a dropped full bag; a bag refuses another bag; a quiver holds its capacity of arrows and a backpack and quiver are worn together; a pouch refuses a log; hand a full bag to another player (or put it in a chest and take it out) with nothing lost or duplicated; spoilage continues inside a bag; carrying weight counts bag contents.
- `validate_items` PASS, `merge_check.py` clear, a clean full plan `python3 tools/tests_for_diff.py dd903d971 HEAD` at the exact head with no new failures (known flakes as in STATE.md).
- `/ponytail-review`; commit with `docs/ai-team/missions/M001/T15_RESULTS.md` (head SHA, counts with log paths, design of the nested store, wire/save format, risks).
