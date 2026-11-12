# Catalog save migration rules

**Status: DESIGN ONLY. Not implemented.** Written by Claude for PR #1035 at Dave's 12 Nov request.

- The source was a read-only audit of dev `7f8aabf4`. `si` means `src/stream/server_items.gd`.
- No save was opened and no test was run. No live save files are in the repository.
- The master catalog [D1] says Dynasty has never been publicly released. These rules protect local and playtest saves anyway.
- **The one rule above all others: a migration never deletes or hides a player's item.**

## 1. How saves work today

| File (in `user://server_store/<world>`) | Holds | Version |
|---|---|---|
| `inventories.json` | Packs. One slot is `[number, count, wear(, 1 if favourite)]` (`inventory.gd:314-341`). | 2 |
| `chests.json` | Placed-container contents by uid, using the same slot arrays (si:8923-8956). | 1 |
| `world_items.json` | Placed structures, ground items and fires. Each is a positional row: number, position, state, yaw, wear, kind, uid, owner, born, coins, site, keep_out (si:1427). | — |
| `characters.json` | Worn slots, indexed by the `clothing.json` slot order (head, body, legs, feet, hands, back, outer, waist). Also hotbar, learned recipes and Fitness `train` (si:10386, 14038-14081, 15466-15650). | 1 |
| `craft_queues.json` | Station craft queues. | 1 |

How loading behaves:
- **Versioning.** `_read_json_version` (si:4804-4833) rejects a file outside the supported range. The file is renamed `.bad` and loads empty. Writes are atomic, with a `.prev` copy.
- **Wear.** A slot's `wear` holds tool uses, container millilitres, food age and wet-wood drying. On the wire a slot is a fixed 8 bytes (`inventory.gd:301-312`).
- **Renames.** `renames.json` maps a retired id to its successor. It is applied on load to packs, chests, ground items, worn slots and the hotbar (`item_table.gd:34-60`).
- **Retired rows** stay in `items.json`, and their item numbers keep loading as they are. Retired recipes and blueprints are skipped. Retired structures still load and work; only their blueprint is hidden.
- **The existing loss path.** Dead kit items are silently emptied, with no refund (`_strip_dead_kits`, si:8933-8944). This catalog adds no kit, and this pattern must not be repeated.

## 2. Rules for this catalog

1. **One gated pass.**
   - Bump the versions of `inventories.json`, `chests.json`, `characters.json` and `world_items.json`.
   - Run one `migrate_catalog` pass at load, gated on a `catalog_v` stamp (the same pattern as `no_kits` and `skills_v`).
   - Back up every file as `*.v1.bak` first.
   - The pass is idempotent: running it twice changes nothing.
2. **Never delete rows.** Retired items, recipes, blueprints and structures keep their rows with `retired: true`. Numbers are never reused.
3. **Retired item with a successor → rename.** Add the pair to `renames.json`:
   - softwood `lumber_*` and all `beam_*` → Plank;
   - hardwood `lumber_*` → Hardwood board (the master s4 item 3 mapping).
   - These rows were FUTURE, so few saves should hold them.
4. **Retired item with no successor → ingredient refund.**
   - Affected items: Stone - Spade 45, Stone - Sickle 298, Stone - Wedge 353 and Saw blade 238.
   - They are replaced by the recipe's ingredients in the same container. The refund is scaled by remaining durability for tools, and rounded up.
   - If the container has no room, the overflow follows rule 7.
5. **Retired placed structures stay.** These are the Woodworking table 243 (PR #1036), Clay bloomery 795/state 200 and Anvil 827/state 204.
   - They keep loading and working until taken down. Taking one down refunds its materials, as today.
   - They are not offered in the build menu.
   - A carried Clay bloomery or Anvil item (not placed) gets the rule 4 refund.
   - Structure rows are never deleted. If one ever must be, the loader first gets a `_structures.has(kind)` guard, because unknown kinds would crash the hard lookups at si:3397, 10551 and 11921.
6. **Worn slots.**
   - Append the new neck slot (and any strap or quiver slot) at the **end** of `clothing.json slots`. Inserting it mid-list shifts every saved index.
   - Before `_clean_worn` runs, move any worn item whose slot changed (for example a quiver leaving the waist) to the pack, or to the ground at the player's feet if the pack is full.
   - `_clean_worn` blanks mismatches today, so this pre-pass is mandatory.
7. **Capacity changes.** These cover a container's `slots` dropping, or `max_kg` dropping below its contents.
   - Move the excess to the owner's pack.
   - If the pack is full, drop it as ground items beside the container.
   - Never clamp contents or hide them beyond `usable`. Items past `usable` are kept but become invisible and weightless today.
8. **Backpack `carry_bonus_kg` removal.**
   - No migration. An over-cap player is slowed, not stripped.
   - Show a one-time notice.
9. **New per-instance fields** (sharpness, current maximum durability, Tempered, enhancement slots, code lock, owner grants).
   - They need a new slot column. That means a format bump, a `PROTOCOL.md` change and a `PROTOCOL_VERSION` bump.
   - Defaults: sharpness full, current maximum = the item's durability, Tempered off, no enhancements, unlocked, no grants.
   - Old clients are refused at the welcome, as today.
10. **Food.**
    - Existing stacks keep their age.
    - Stacks of passive-maturing foods (Sauerkraut, and Pickled vegetables once live) that exist before the pass are marked Ready. They were made under the old rules.
    - No food changes ID.
    - Moved recipes (compote, apple sauce, plum jam, damsons) affect only new crafts.
11. **Energy aids [D17].** The permanent Fitness cost is removed from the data. Saved `train` values are left as they are: a player who already lost training points regains them by training. Dave can choose a one-time clamp to 0 instead.
12. **Learned recipes and craft queues.**
    - Retired recipe numbers in `learned` are kept and ignored.
    - A queued craft of a retired or moved recipe is cancelled, with its reserved inputs returned.
13. **Locks and ownership.** Every existing container loads unlocked, owned by its saved `owner`. The existing "keep out" tick is kept.

## 3. Automated tests (headless, on Dave's PC)

Extend `test_save_compat.gd`, `test_item_renames.gd` and `test_server_items.gd`:

| Test | Pass condition |
|---|---|
| Era save with every retired item in a pack, a chest, worn, hotbar and on the ground | The total item count by successor and refund is conserved. Nothing is deleted, and the load has no errors. |
| Placed Clay bloomery, Anvil and Woodworking table | Each still loads. Take-down refunds its materials. |
| Chest shrunk from 30 slots to 10 | Every item is still in the chest, the pack or on the ground. |
| Worn quiver on the waist, with an 8-slot worn array | The quiver ends up in the pack, and the other worn items are unchanged. |
| Old Sauerkraut stack | Loads as Ready, with the same age. |
| Character with negative `train` | The value is unchanged, and no energy aid lowers it again. |
| Run the migration twice | The second run changes nothing. |
| Future-version file | Set aside as `.bad`, and the `.v1.bak` copy is intact. |
| Unknown structure kind (if a row is ever deleted) | Loads without a crash. |

**In-game check:** Dave loads his latest playtest world after the migration build. Every chest, his pack and his worn items match a list printed before the build.
