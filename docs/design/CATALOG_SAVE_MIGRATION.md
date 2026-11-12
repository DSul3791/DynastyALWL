# Catalog save migration rules

**Status: DESIGN ONLY. Not implemented.** Written by Claude for PR #1035 at Dave's 12 Nov request.

- This design comes from a read-only audit of dev `7f8aabf4`. An independent review checked it, and its findings are fixed below. `si` means `src/stream/server_items.gd`.
- No save was opened and no test was run. The repository contains no live save files.
- The master catalog [D1] says Dynasty has never been publicly released. These rules protect local and playtest saves anyway.
- **The rule above all others: a migration never deletes or hides a player's item.**
- Every rule here is DELEGATED engineering. None needs an owner decision.

## 1. How saves work today

| File (in `user://server_store/<world>`) | Holds | Version |
|---|---|---|
| `inventories.json` | Packs. A slot is `[number, count, wear(, 1 if favourite)]` (`inventory.gd:314-341`). | `INVENTORY_VERSION` 2 |
| `chests.json` | Placed-container contents by uid, in the same slot arrays (si:8923-8956). | literal 1 |
| `world_items.json` | Placed structures, ground items and fires as positional rows: number, count, position, left, state, yaw, wear, kind, uid, owner, born, cave, coins, site, keep_out (si:1427). | `VERSION` 1 |
| `characters.json` | Worn slots as bare item numbers, indexed by the `clothing.json` slot order (head, body, legs, feet, hands, back, outer, waist). Also the hotbar (item-number keys), learned recipes and Fitness `train` (si:10386, 14038-14081, 14368, 15466-15650). | literal 1 |
| `craft_queues.json` | Station craft queues. | 1 |

**Load order:** `_load_characters` (si:472, which runs `_clean_worn`), then craft queues, `_load_inventories` (si:474), chests, and `_load_world_items` (si:476).

**Load behaviour:**
- **Version check.** `_read_json_version(name, version, oldest = -1)` (si:4804-4833) accepts only versions from `oldest` (or the current version) up to the current version. Any other file is renamed `.bad` and loads empty. Only the inventories loader passes an `oldest`.
- **Renames.** `renames.json` maps a retired id to its successor. It is applied on load to packs, chests, ground items, worn slots and the hotbar (`item_table.gd:34-60`). `wood_species.json retired_to` is data that no code reads.
- **Retired rows.** Retired rows stay in `items.json`, and their numbers load as they are.
  - Retired recipes are skipped at load (`recipe_table.gd:28`), so their ingredient lists cannot be read then.
  - Retired blueprints are skipped entirely (si:7425). Taking down a structure whose blueprint is gone gives back its kit item instead of materials (si:8365-8368).
- **Existing loss paths.**
  - Dead kits are silently emptied (`_strip_dead_kits`, si:8933-8944).
  - `_clean_worn` blanks any worn item whose slot no longer matches.
  - A worn item loses its wear, because worn slots hold bare numbers.
- **Refunds.** Refund code needs a connected peer (`_refund_entry`, si:14843). Nothing runs offline at load.

## 2. Rules

1. **One gated pass, `migrate_catalog`.**
   - **Versions.** Raise `INVENTORY_VERSION`, `VERSION` and the chest and character literals by one. Each loader passes `oldest` = its old version, so v1 files still load. Without that, every existing save loads empty.
   - **Stamp.** Each file carries its own `catalog_v` stamp, so a crash mid-save cannot leave files half-migrated.
   - **Backup.** Write a create-once backup named `*.catalog.bak`, not `*.v1.bak`. The skills migration already owns `characters.json.v1.bak`.
   - **Repeat runs.** The pass is idempotent.
2. **Order inside the pass** (after all files have loaded, before the first player joins):
   1. Cancel queued crafts of retired or moved recipes. Return their inputs, after renaming them.
   2. Apply renames.
   3. Make refunds.
   4. Move worn items whose slot changed.
   5. Fix container capacity.
   6. Mark old food stacks.
   7. Save.

   Offline refunds and moves use a key-based `Inventory.add` path with no peer.
3. **Never delete rows.** Retired items, recipes, blueprints and structures keep their rows. Numbers are never reused.
4. **Retired item with a successor → rename** in `renames.json`. This is the live mechanism; update `retired_to` to match.
   - Softwood `lumber_*` and all `beam_*` become Plank.
   - Hardwood `lumber_*` becomes Hardwood board.
   - These rows were FUTURE, so few saves hold them.
5. **Retired item with no successor → refund from a stored list.** The pass cannot read retired recipes, so each retired item row gets a `refund` list in data. Each refund item lands in the same container; overflow follows rule 9.
   - **Stone - Spade 45:** Wooden spade, 2 Stone, Twine. The Wooden spade comes back with the old spade's wear fraction.
   - **Stone - Sickle 298:** Flint, Stick, Twine.
   - **Stone - Wedge 353:** 2 Stone, Stick.
   - **Saw blade 238:** 2 Iron ingot.
   - **Carried Clay bloomery 795 and Anvil 827:** the cost of blueprint 162 or 164.
6. **Retired placed structures stay and still refund.** This covers the Clay bloomery (state 200), the Anvil (state 204) and the Woodworking table 243 (PR #1036).
   - They keep loading and working.
   - Their blueprints 162, 164 and 12 are marked **`hidden: true`** (not buildable) instead of `retired`, so `_blueprint_of_kit` still refunds materials on take-down.
   - This needs a small loader and menu change. Master s7 item 1 is updated to match.
   - Structure rows are never deleted. If one ever must be, the loader first gets a `_structures.has(kind)` guard (hard lookups at si:3397, 10551 and 11921).
7. **Worn slots.**
   - Append any new slot (neck, strap, quiver) at the **end** of `clothing.json slots`.
   - Before `_load_characters` calls `_clean_worn`, the pass reads the raw worn array and moves every item whose slot changed (for example a quiver leaving the waist) into a `worn_moved` list on the character row.
   - After `_load_inventories`, the items in `worn_moved` go into the pack. If the pack is full, they are handed over at the next join and dropped at the player's feet. They are never blanked.
8. **Worn instance data.** `worn` changes from bare numbers to slot arrays `[number, 1, wear(, instance data)]`. An old bare number reads as `[n, 1, 0]`. This lands in the slot-format phase, before Tempered armour or enhancements exist.
9. **Capacity changes.** If a container's `slots` drop, or its `max_kg` falls below its contents:
   - move the excess to the owner's pack;
   - if that is full, drop it as ground items beside the container.

   Never clamp contents or leave them beyond `usable`, where they would be invisible and weightless.
10. **Backpack `carry_bonus_kg` removal.** No migration is needed. An over-cap player is slowed, not stripped, and gets a one-time notice.
11. **New per-instance fields** (sharpness, current maximum durability, Tempered, enhancement slots).
    - They need a new slot column, a format bump, a `PROTOCOL.md` change and a `PROTOCOL_VERSION` bump.
    - Defaults: full sharpness, current maximum = durability, not Tempered, no enhancements.
    - Bag contents are not a column. They are a nested inventory saved with the bag instance, designed in the carrying phase.
12. **Food.**
    - Existing stacks keep their age.
    - Existing passive-maturing stacks (Sauerkraut) are set to `wear = max(wear, ready_age)` once, so they stay eatable. This shortens their remaining shelf life by at most `ready_age`, which is accepted.
    - No food changes ID.
    - The moved preserve recipes affect only new crafts.
13. **Energy aids [D17].** The permanent Fitness cost is removed from the data. Saved `train` values are left unchanged; players who lost points regain them by training.
14. **Learned recipes and the hotbar.** Retired recipe numbers in `learned`, and hotbar keys for retired numbers with no successor, are kept and ignored. They are dead keys that cannot hold or lose an item.
15. **Locks and ownership.** Every container loads unlocked. A saved `owner` is kept. A container saved with no owner keeps today's rule (its first opener becomes the owner), and the existing "keep out" tick is kept.

## 3. Automated tests (headless, on Dave's PC)

These extend `test_save_compat.gd`, `test_item_renames.gd` and `test_server_items.gd`.

| Test | Pass condition |
|---|---|
| A v1 file of each kind with the bumped loaders | Loads in full and is not set aside as `.bad`. |
| A save holding every retired item, in a pack, a chest, worn and on the ground | Item count by successor and refund is conserved, nothing is deleted, and the load has no errors. |
| A queued craft of a retired recipe | Cancelled, with renamed inputs returned. |
| A placed Clay bloomery, Anvil and Woodworking table | They still load. Take-down refunds their materials, not a dead kit. |
| A chest shrunk from 30 slots to 10 | Every item is in the chest, the pack or on the ground. |
| A worn quiver on the waist in an 8-slot bare-number worn array, with the character offline | After join, the quiver is in the pack or at the player's feet. The other worn items keep their slots. |
| An old Sauerkraut stack | Loads Ready and eatable. |
| A character with negative `train` | Value unchanged; no energy aid lowers it again. |
| A skills-migrated world | Its `characters.json.v1.bak` is untouched, and a `.catalog.bak` is written. |
| Run the pass twice, or crash between file writes | The second run changes nothing, and no file is half-migrated. |
| A future-version file | Set aside as `.bad`, with the backup intact. |

**In-game check:** Dave loads his latest playtest world after the migration build. Every chest, his pack and his worn items match a list printed before the build.
