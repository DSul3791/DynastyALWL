# M001-T07 results: Leatherworking table, Tailor's table, Loom, Thread (phase 2b part 2)

- Branch `m001/t07-textiles`, clone `E:\Software\godotDev\m001_p2b2`, base `cc5242ad8`. Code commits: `97cc8f3bf` (data, tests), **`3257581db7f9ce87b2e2a05cb19997b287e92c0c`** (test_hammer_list count; code head). This file is committed on top (docs only). Not pushed.
- Brief: `T07_BRIEF.md`. Master `DYNASTY_MASTER_ITEMS.md` s2.8, s3.4, s4 items 10-11.

## What changed
- `data/items/items.json`: Loom 846, Leatherworking table 911, Tailor's table 912 and Thread 913 lose `future`; the three stations' notes name their states.
- `data/items/structures.json`: `leatherworking_table` state 243, `tailors_table` 244, `loom` 245; each its own kit, item and station id, level 1, reach 3 m.
- `data/items/blueprints.json`: 205-207, hammer 1, known; `next_number` 208.
- `data/items/recipes.json`: 278, 392, 356, 361, 213, 214, 358, 359, 360 -> `leatherworking_table`; 216, 237-244 -> `tailors_table`; 245, 334, 342 -> `loom` (old workbench station levels dropped: each new station has one level). Twine -> Thread (same counts) in 23, 39-42, 173, 194-196, 237, 238, 241, 388. New recipe 409 Thread; `next_number` 410. Hide goods 23, 30, 39-42, 173, 194-196, 388 stay by hand; fur 242-244 keep Sinew.
- `data/items/look_placeholders.json`: Thread reason updated; the two borrowed station looks listed.
- `docs/design/catalog_ledger.json`: 846, 911, 912, 913 IMPLEMENTED - UNVERIFIED; 775 Drying rack BLOCKED with the reason. `--check` passes.
- Tests: new `test_textile_route.gd`; `test_server_items` (quiver and hood take Thread), `test_blueprints` (191 live), `test_hammer_list` (141 rows).

## Costs chosen (s5 tuning, for playtest)
| Row | Cost |
|---|---|
| Thread (recipe 409, by hand) | 2 Plant fibre -> 1 Thread, 2 s. Value-neutral: Thread is value 2, two fibre are 2 (Twine is 3 fibre at value 3). The brief's 2 -> 2 would let a trader pay double for fibre. Needle recipes keep their old twine count, so sewing gets cheaper (1 Thread = 2 fibre against 3 per Twine). |
| Leatherworking table (205) | 4 Log, 4 Stick, 4 Twine, 2 Stone |
| Tailor's table (206) | 3 Log, 6 Stick, 4 Twine |
| Loom (207) | 2 Log, 10 Stick, 6 Twine, 4 Clay (the loom weights its look draws) |
All pre-saw: no Planks, no metal (s4 item 10); `test_textile_route` asserts it.

## Looks
- Loom: its own `loom` builder (warp-weighted loom), drawable.
- Leatherworking table: borrows `carpenters_bench` (2.0 x 1.0). Tailor's table: borrows `table` (1.4 x 0.7). Both **NOT visually complete**, listed in `look_placeholders.json`. (`woodworking_table` was tried first; validate_items refuses a look named after a retired item.)
- Thread: grey chunk item icon, listed. **NOT visually complete.**

## Drying rack 775: not done
The live leather chain is hide -> Scraped hide (179, by hand, catalog KEEP "hand") -> Leather (234, Tanning rack, KEEP). A hide-drying step needs either a new intermediate item or moving a KEEP recipe to the rack; both go beyond the catalog. Ledger BLOCKED; needs a mission-lead call. Food drying unchanged.

## Evidence (Dave's PC, voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe`)
- `python3 tools/tests_for_diff.py cc5242ad8 HEAD` at `97cc8f3bf`: 210 tests, **209 PASS, 1 FAIL** (`test_hammer_list`: its count, 138 -> 141, the three new blueprints). Fixed in `3257581db`; rerun alone: PASS. No other failure, so no base comparison was needed for the suite.
- At `3257581db`: `validate_items` PASS, 0 errors, 168 warnings (base `cc5242ad8` 169; the two changed lines are Thread no longer "future but obtainable" and no longer a dead end). `test_item_looks` PASS. `test_hammer_list` PASS.
- `test_textile_route` (in the suite, PASS): a new character gathers fibre, stones and sticks by hand, makes a stone knife, takes hides and bone from two rabbit carcasses, makes a Bone - Needle, twists Thread, sews a Hide - Hood by hand with no Twine and no bench, scrapes and tans a hide at a built Tanning rack, is refused a Leather strap there, builds the Leatherworking table and cuts 2 straps; is refused Fibre cloth by hand, builds the Loom and weaves 3; is refused the gambeson at the Loom, builds the Tailor's table and makes a Fibre - Gambeson; all stations stand. Given, not made: scraper, wooden hammer, tannin bark, water, the stations' logs, sticks, twine, stones and clay.
- `python3 -I tools/catalog_ledger.py --check`: pass. `tools/check_look_names.py`: all 220 structure looks drawable.
- NOT RUN: `tools/items_check.py` (calls Godot directly, outside the slot runner); in-game look check of the three stations; the standard exe.

## Self-review (`/ponytail-review`, diff `cc5242ad8..3257581db`)
No must-fix. Notes, left as they are:
1. `encyclopedia.json` (read by nothing yet) still says "Craft at a workbench" and "1 Twine" for the moved and needle recipes, and Loom `obtainable_now` false; `encyclopedia_reach.py --check` was already out of date at base (T06 rows). One encyclopedia sync pass for all of phase 2b is cleaner than a third hand patch.
2. The ledger tags Hide - Backpack 50 and Hide - Quiver 272 as phase 2b (the generator matched "backpack" in s3.4); their UPDATE is the [D9] carrying work (phase 5). Not touched.
3. Recipe 278 still keeps `stone_knife`; the `knife` group switch is s4 item 4 (phase 2c).
4. s2.8 item 5 (portable Thread repairs) has no data yet: no clothing row has a `repair` list. Not in this brief.
5. s4 item 10 station input and output capacity fields: not added (T06 did not add them to the Smelter either).

## Risks for the reviewer
- The workbench L2/L3 lose all leather and cloth recipes; anything that showed them as level unlocks (hints, guides) is stale text.
- `look_placeholders.json` now holds two structure ids with no item icon row; `test_item_looks` skips them (it only checks ids in `looks.json`).
- Tanning in the route test uses given water and tannin bark.
