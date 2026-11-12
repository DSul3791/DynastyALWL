# M001-T15 results: Phase 5 carrying equipment

Branch `m001/p5`, base `dd903d971` (dev `fefee0aa2` tree: 4a layers, 1b instances, protocol 107). Code under test: **`9d47c66cc`** (the commit after it changes only this file). Machine: Dave's PC `ManlandRyzen5`, clone `E:\Software\godotDev\m001_p5`, voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe`, headless, through `tools/run_tests.sh` / `tools/run_one_test.sh` (slot lock, 3 jobs). Engineer: systems-engineer agent, 12 Nov 2026. Brief: `T15_BRIEF.md`.

## Nested store (design)
- **A bag's contents are its instance data.** A bag is an item whose `items.json` row has `bag_slots` (its organized volume: slots of its own, 1-30) and `bag_takes` (what goes in). What it holds is the 1b instance key `bag`: rows in the pack's save shape, `[number, count, wear]`, or `[number, count, wear, 0, inst]` for an item with its own instance data (trailing empty rows left out; an empty bag has no `bag` key and is plain again). `src/shared/bag_rules.gd` opens a bag as an `Inventory` of its own slots (`usable` = bag_slots, or more if saved rows run past them, so nothing is hidden) and writes it back (`store`).
- **Why there:** every path that already keeps an instance (T04's list: worn on and off, drop and pick-up, ground piles that never merge, chest put and take, Take all / Store all, sort, death and remains, throw, save and load of pack, chest, ground and worn) now carries the contents with the bag, with no keyed side store to keep in step. One source of truth, so drop, pick-up, chest and hand-on cannot duplicate or lose contents.
- **No nesting:** `Inventory.clean_inst(raw, in_bag)` drops a `bag` key from any row inside a bag (saves and the wire), and the server refuses putting any bag (an item with `bag_slots`) into a bag. A chest or the pack may hold a full bag (s3.9 rule 3: "stored", brief item 2).
- **Worn bags open beside the pack:** the container id of a worn bag is `-1 - worn position`. `_chest_of` returns the bag as an inventory; one action works on one copy (`_bag_edit`), written back to the worn record when the action ends (`_end_bag_edit`, then `_sync_worn`). So the container screen, Take all, Store all and the shoulder-log path are the chest code, unchanged. Only worn bags open; a bag in the pack, a chest or on the ground is closed and carried whole.
- **Content limits** (`clothing.json bags`, tuning): any (not too big for a pack), small (each at most 0.5 kg: pouch, satchel), small_tool (a tool of at most 1.5 kg: tool roll), consumable (food or medicine of at most 0.5 kg: bandolier), arrow (`ammo_class` arrow, at most `ammo_capacity`: quivers), blade (`weapon_class` sword: scabbard), awkward (anything, a large log too: pack frame).
- **Spoilage:** food in a bag ages where the bag is: pack rate in the pack and worn, the chest's rate in a chest, the ground rate on the ground (`_spoil_bag`, `_spoil_inventory`, `_spoil_tick`).

## Volume, weight, attachment points
- `carry_bonus_kg` retired (rows 50 and 767, server `carry_bonus_kg()` deleted, client `carry_body_kg`): the carry limit is the body's alone. Bag contents count in full, in the pack (`CarryRules.carried_kg` adds `bag_kg`) and worn (`_worn_bags_kg`, client `carried_kg`). A worn piece itself still weighs nothing, as before. Picking up or taking out a full bag checks the cap with its contents (`_fit(..., item_inst)`); moving between your pack and your worn bag never asks the cap (the load does not change). Over the cap a player is slowed by the client's walk as before, never stripped, and told once until back under (`_carry_notice`, migration rule 10).
- The 30-slot pack stays (s3.9 rule 3, "reconciled rather than contradicted"); bags add their own slots on top. The recommended shrink of the base pack is not done (see Not done).
- `clothing.json worn` (append-only) gains 7 positions after `body:mail`, 27 in all: `back:roll` (Bedroll strapped outside a worn pack), `waist:pouch`, `waist:quiver`, `waist:scabbard`, `waist:tools` (belt points: at most `belt_points` 3 used), `shoulder:base` (Shoulder bag, Satchel), `strap:base` (Bandolier). `attach` says what each hangs on (pouch, scabbard, tool roll: the belt; bedroll: a worn pack) and the line said without it; a piece something hangs on cannot come off first. A quiver needs no belt (an early archer, s3.9) and on a belt takes a point. Quiver and backpack coexist.
- Bow: a worn quiver is drawn from first, then the pack (server `_shoot`, client `held_item.arrow_to_shoot`).

| Item | Position | Slots | Takes | Recipe (station) |
|---|---|---|---|---|
| Hide - Backpack 50 | back:base | 10 | any | 30 (hand, unchanged) |
| Leather - Backpack 767 | back:base | 15 | any | 361 (Leatherworking table) |
| Hide - Quiver 272 / Leather - Quiver 762 | waist:quiver | 2 / 3 | 40 / 60 arrows | 173 / 356 |
| Bedroll 819 | back:roll | - | - | 388 |
| Fibre - Shoulder bag 982 | shoulder:base | 4 | any | 600 hand: 8 plant fibre, 3 twine |
| Wicker - Pack basket 983 | back:base | 10 | any | 601 hand: 12 sticks, 4 twine |
| Leather - Satchel 984 | shoulder:base | 6 | small | 602 Leatherworking: 2 leather, 1 strap, 1 thread |
| Belt pouch 985 | waist:pouch | 4 | small | 603 hand: 1 hide, 1 thread; 604 Leatherworking: 1 leather, 1 thread |
| Tool roll 986 | waist:tools | 6 | small tools | 605 Tailor's: 2 linen, 1 thread, 1 strap; 606 Leatherworking: 2 leather, 1 strap |
| Traveller's rucksack 987 | back:base | 20 | any | 607 Tailor's: 4 wool cloth, 4 straps, 2 thread |
| Wooden - Pack frame 988 | back:base | 4 | awkward (logs) | 608 Carpenter's bench (workbench 2): 4 planks, 2 straps |
| Weapon scabbard 989 | waist:scabbard | 1 | a sword | 609 Leatherworking: 2 leather, 1 strap |
| Utility bandolier 990 | strap:base | 6 | small food, medicine | 610 Leatherworking: 2 leather, 2 straps |

All slot counts, kg limits and recipe amounts are s5 tuning numbers for playtest. Needle (`sewing_needle`) is kept by the sewn recipes.

## Wire and save (protocol 109; 108 is Phase 9's)
- No new message. The contents travel in the existing instance block (`u16 length + JSON {"slot": inst}`) of inventory bytes (inventory_full, chest_contents), inventory_slots and worn. `ACT_CHEST_OPEN a`, `ACT_CHEST_PUT b`, `ACT_CHEST_TAKE b` = `-1 - worn position` names a worn bag; chest_contents answers with that id and the bag's slots; chest_info with keep out off. `PROTOCOL.md` row 109, `terrain_net.gd` history and action comments.
- Saves: unchanged shapes; the bag rows are inside the inst already saved in inventories.json, chests.json, world_items.json and characters.json `worn`. New game: no migration.

## Data
`items.json`: the 9 rows lose `future` and gain `slot`, `wear_layer` (belt points), `bag_slots`, `bag_takes`; backpacks lose `carry_bonus_kg`, gain volume and new descriptions; quivers move to `wear_layer quiver` with "worn at the hip" descriptions; Bedroll gains `slot back, wear_layer roll` and a description line. `recipes.json` 600-610, `next_number` 611. `worn.json`: 10 rows `"placeholder": true` (pack or belt builder) — **NOT visually complete**; `look_placeholders.json` notes for the 9 grey item looks. `clothing.json` as above. Ledger: 14 rows IMPLEMENTED - UNVERIFIED (Leather - Belt stays NO CHANGE: its row did not change).

## Client
Tab screen: Open beside each worn bag. You column: the Back and Waist wells show the pack and the belt (not the bedroll or a pouch) and a click opens a worn bag. The container screen shows a bag's slots and its load in kg in the title, and closes when the bag is taken off. Tooltip: "Holds N slots of its own"; the "Lets you carry more" line is gone. `CONTROLS.md` row.

## Tests
Logs: `C:\Users\david\AppData\Local\Temp\claude\01b3e68161e49208\35a61d07-6ae9-47de-b88c-fe7400bb03ef\scratchpad\t15\` (`full1`, `full2`, `r2`, `r5`, `r6`; scratch, not kept by the repo).

| Run | Result |
|---|---|
| New `test_carrying` (42 checks, real server state: 27 positions, every row live with its own position and no carry_bonus_kg; backpack and quiver worn together, no strength gain; fill the worn backpack through its window, an instance inside keeps its data, chest_contents bytes; carry weight counts worn contents; bag refuses a bag, clean_inst strips a nested bag; quiver takes 40 of 60 arrows, refuses a stone, the bow draws from it; pouch needs a belt, refuses a log, takes berries; three belt points; belt will not come off under its pouch; scabbard refuses an axe; take out; full pack off, drop, pick up identical; into a chest, second player takes it out, nothing lost or doubled, weight moves with it; spoilage in a worn pouch, a carried pack and a pack on the ground; save and reload of a worn full pouch, a dropped full pack and the quiver; over-cap notice once, nothing stripped; pack frame takes the shoulder log and gives it back) at `fc6743196` (`r2`) | PASS |
| `tests_for_diff.py dd903d971 HEAD` plan at `fc6743196` (340 fast + 8 timing), `run_tests.sh --jobs 3` (`full1`) | 345 pass, 3 fail: `test_chest_column` (its fake view had no `container_number`: moved onto the container panel in `9d47c66cc`, rerun PASS `r5`), `test_npc_view` exit 139 after printing PASS, `test_flora_density` 300 s timeout; `test_slot_sounds` flaked once, passed on retry |
| **Same plan at the code head `9d47c66cc`** (`full2`) | **346 pass, 2 fail**: `test_npc_view` exit 139 after `test_npc_view: PASS` (the known exit-race crash, STATE.md/T04) and `test_flora_density` 300 s timeout under load (known timing-lane flake) |
| `test_flora_density` alone at `9d47c66cc`, 700 s limit (`r6`) | PASS (426 s) |
| `validate_items` at `9d47c66cc` (run explicitly; new checks for bag_slots/bag_takes, carry_bonus_kg, attach and belt_hangs) | PASS (0 errors, 163 warnings, none about the changed rows) |
| `catalog_ledger.py --check`, `merge_check.py` (base default), `check_look_names.py`, `check_controls.py` | PASS, all clear (carry_audit warning as at base), PASS, ok |
| `check_warnings.gd` (debug, all scripts, through the slot lock) | no warnings in changed lines: server_items.gd 9 and character_screen.gd 3, all pre-existing lines |
| In-game visual, UI click-through and multiplayer check | NOT RUN |

No new failures against base. Deviation: one short standard-exe run (about 1 s, through `godot_slot.sh`) of a scratch script to make the two `.uid` files.

## Self-review (`/ponytail-review` method), answered
- Fixed before review: chest TAKE out of a worn bag and a log off a pack frame counted the load twice against the cap (now no cap check: the load does not change); Store all into a bag repeated a refusal per stack (now skipped silently); a shop sale of a bag with contents would have ended them (now refused, "Empty the bag first.").
- Unmeasured: the client's carried weight now also walks worn bag rows each time it is read (per frame for the walk speed); expected small (at most a few dozen rows).

## Not done, risks
- The base pack stays 30 slots (s3.9 rule 3); the s3.9 recommendation to shrink it to hands, belt and pockets is not done, so bags add room on top. A design call for later if bags feel too generous.
- Crafting, building sites and hotbar keys do not draw from worn bags: materials must be taken out first. Likely the first playtest complaint.
- Not modelled (s3.9 rule 2, 6): the pack frame's climbing/sprint/fight penalty, the rucksack's loaded movement cost beyond weight, wet contents in a basket, bag condition and repair, drawing a sword from the scabbard, quick-use from pouch or bandolier.
- No player-to-player trade exists, so the hand-over test goes through a chest (brief allows it). The shop refusal for a full bag is untested.
- A full bag or quiver gives no message when nothing more fits (as chests).
- Bag contents are hidden in a closed bag (pack, chest, ground); the tooltip shows only slots in use.
- Looks: 10 `worn.json` placeholders (pack and belt builders; a shoulder bag draws as a backpack, belt pieces as a second belt) and 9 grey item chunks: NOT visually complete.
- Merge: `PROTOCOL_VERSION` 109 (Phase 9 108); `worn.json` and `recipes.json` appends at the end of their sections and `recipes.json next_number` 611 may conflict with parallel phases (take the larger); `clothing.json` positions are append-only, so any branch appending there must go after `strap:base`.
- All numbers (slots, 0.5 / 1.5 kg limits, belt points 3, recipe amounts) are s5 tuning for playtest.
