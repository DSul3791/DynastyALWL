# M001-T04 results: Phase 1b item-instance data

Branch `m001/p1b-instances`, base `159b566`. Code under test: **`7864137b5`** (the commit after it adds only this file). Machine: Dave's PC `ManlandRyzen5`, clone `E:\Software\godotDev\m001_p1b`, voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe`, headless, through `tools/run_tests.sh` / `tools/run_one_test.sh` (slot lock, 3 jobs). Engineer: systems-engineer agent, 12 Nov 2026.

## What changed
- `src/shared/inventory.gd`: per-slot `inst` (Dictionary, `{}` plain; keys `sharp`, `max_d`, `temper`, `craft`, `magic` written only when not default, `clean_inst` drops anything else). Instance slots never merge (add, move, ground). `remove` takes plain stacks before instances and can report the instance units it took. `take_from_slot` returns `inst`. `FORMAT` 3. Phase 2c API: `max_durability`, `sharpness_used`, `make_inst(craft, tempered)`, `fill_magic(slot, index, effect)` (refuses an occupied slot, an empty effect, a stack of more than one; nothing clears a filled slot).
- Wire (protocol 106, `PROTOCOL.md` and `terrain_net.gd` history): instance block = `u16 length + UTF-8 JSON {"slot": inst}` (`Inventory.inst_bytes`, length 0 for none). `to_bytes` = format byte, 30 x 8 slot bytes, block (243 bytes with no instances). `inventory_slots` = count byte, 9-byte records, block for the changed slots. `worn(numbers, insts)`.
- Saves: slot row `[n, c, wear]`, `[n, c, wear, 1]` favourite, `[n, c, wear, 0|1, inst]` with an instance. `characters.json` worn = slot arrays `[n, 1, wear, inst]` (`[0, 0, 0, {}]` empty; a bare old number reads `[n, 1, 0, {}]`; worn pieces now keep their wear). Loose `world_items.json` rows end with the inst Dictionary. `craft_queues.json` ingredient rows may carry a third value, the instance units taken, given back first on a cancel. No old-save migration (new game): a playtest world from before may be started fresh.
- Paths that keep `inst` (`server_items.gd`): drop and pick-up (piles never merge with an instance), throw and landing, chest put and take (and Take all / Store all, which use them), worn on and off, sort, split, dialogue hand-over (`take_from`, plain first), craft queue take and cancel refund (`_stock_take`, `_start_deferred`, `_refund_entry`), death (remains copy the pack through JSON), `recipe_table.craft` undo, `_strip_dead_kits` / torch burn-out / shop sale clear the whole slot. Stack to nearby skips instance slots (they never stack). Goblins never steal an item with instance data.
- Client: tooltip and pack info strip show `+1`/`+2` after the name, "Tempered" and each filled magical slot; worn wells and the Tab screen's Wearing list show the craftsmanship.

## Tests (code `7864137b5`, unless noted)
| Run | Result |
|---|---|
| New `test_item_instances` (53 checks: JSON and bytes round trip of every field, no merge, fill_magic permanence, slot message format, hotbar pointer, ground, throw, chest, take-down refusal, Take all, worn, hand-over, craft cancel, save and reload of pack, chest, ground and worn, death, PROTOCOL_VERSION 106) | PASS |
| `tests_for_diff.py origin/dev HEAD` plan (333 fast + 8 timing), `run_tests.sh --jobs 3` at `62395ee91` | 338 pass, 3 fail |
| `test_chest_column` (its fake store lacked `inst_of`) and `test_save_compat` (asserted the old bare-number worn shape): updated to the new contract in `7864137b5`, rerun | PASS, PASS |
| Same two at base `159b566` | PASS, PASS (so they failed only on the old contract, now updated) |
| `test_flora_density`: timed out at 300 s under 3-job load; rerun alone at head with a 600 s limit | PASS (396 s); a known timing-lane test (`tools/test_lanes.json` timing_note), flora code untouched |
| `test_you_column` (fake view gained `worn_inst` and `inst_label`), rerun | PASS |
| Plan checks `validate_items`, `check_look_names.py`, `warnings` | NOT RUN (no data or look change in this diff) |
| Full suite at `7864137b5` after the two test updates | NOT RUN (only the changed tests were rerun) |

No new failures against base. One deviation: a two-line GDScript default-argument probe (fresh Array per call) ran once on the standard exe outside the slot scripts, about 1 s.

## Self-review (`/ponytail-review`), answered
- `worn_of` runs on every carry and warmth check: the in-memory worn record is taken as is (cleaned once at load), so no per-call cleaning. Fixed before commit.
- `_snapshot` copies 30 small dictionaries per action: unmeasured, expected negligible (per player input, not per frame).

## Not done, risks for the reviewer
- Selling an instance item to a shop ends it like any sale (the shelf is a count); placing a placeable with instance data as a structure keeps only its wear. No player-to-player trade exists in the code. If either should refuse instance items, that is a design call.
- Goblin stealing now skips instance items (behaviour change, low impact until Phase 2c makes instances).
- The plan's new worn slots (neck, strap, quiver in `clothing.json`) are data under `data/items/`, outside this brief; not done.
- World-item rows sent to clients carry no instance data (ground tooltips show plain); no in-game visual check of the tooltip was made.
- `_split` still does not copy wear to the new half (pre-existing).
