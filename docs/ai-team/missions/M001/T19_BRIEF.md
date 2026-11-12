# M001-T19 brief: integrated Mission 001 walkthrough and the full-suite regression

Mission 001 final integration check (mission brief section 9 "Required in-game outcomes" and section 12 "Mission complete" items 4-8). Owner: systems-engineer agent (test author, no feature work). Reviewer: independent gate-reviewer. Branch `m001/final` in clone `E:\Software\godotDev\m001_final` (base `e4c11ae91` = dev `0b19357cf` tree, every Mission 001 phase integrated).

## What to build
One new automated player-path test, `src/worldgen/tools/test_mission001_walkthrough.gd`, that drives ONE world through the real server (`server_items.gd` and its helpers, real data, the same harness patterns as `test_iron_saw_route.gd`, `test_cooking_route.gd`, `test_storage_locks.gd`, `test_handcart.gd`), checking resulting game state at each step, never just issuing inputs. Materials that the world would provide by gathering may be given only where an existing route test already proves that gathering step; say so in a comment at each give. Steps (each a numbered check group):
1. **Early survival:** a new character arrives with nothing; gathers stones, sticks, plant fibre and twine; makes a Stone - Axe and Stone - Knife by hand; builds a lean-to or other shelter from its blueprint; hunts or forages food and cooks it at a campfire; builds an early storage (Wicker - Chest) and stores items.
2. **Wood and metal:** digs bog iron with a Wooden spade; makes charcoal; builds the Smelter and the Smithy; fires the Smithy; makes an Iron - Saw; saws Planks from a softwood log and Hardwood boards from a hardwood log — no purchase anywhere.
3. **Construction and equipment:** builds a Leatherworking table and Loom and Tailor's table; makes Thread, a Leather strap, Fibre cloth, a Fibre - Gambeson; builds a Rustic - Chest and a Crude - Chair from boards; crafts an iron weapon and an iron armour piece at the Smithy; wears gambeson + mail in layers; fills a backpack and wears it; checks capacity, durability wear from use, repair at the station, and a Master smithy +1 or a Tempered steel item where the chain allows (Blast furnace steel).
4. **Cooking and preservation:** Food Preparation Table, prepare and cook a flatbread, seal a Sauerkraut batch at the Preserving jar and mature it, make Smoked meat and Dried mushrooms, assemble a board and set it on a Serving platter on the table, eat a portion; portions conserved.
5. **Food effects:** eat three foods of different groups; three effects active; XP bonus applied only when earned; expiry; no Fitness loss from an energy aid.
6. **Storage and warehousing:** lock a chest with code 0042; a second player is refused, enters the code, gets in; Warehouse desk lists only permitted contents; build a Handcart; move a loaded Warehouse crate to a second desk area; contents identical, ageing continued.
7. **Regression spot checks:** after all the above, the world saves and reloads with every placed piece, container and worn item intact (counts by item before and after).
Each step reports PASS/FAIL lines; the test exits non-zero on any failure.

## Then
- Run the full test suite: `python3 tools/tests_for_diff.py 7f8aabf4f HEAD --full` (the whole suite against the pre-mission dev), `run_tests.sh --jobs 3`, no edits during the run; plus `validate_items`, `merge_check.py`, `catalog_ledger.py --check`, `check_look_names.py`. Save head before/after and logs.
- If the walkthrough exposes a real defect in integrated code, do NOT paper over it in the test: write it up in `T19_RESULTS.md` with the failing step and a minimal reproduction, fix it only if the fix is small and clearly within the approved design (and say so), otherwise leave the test failing on that step and report.

## Rules
Work only in `E:\Software\godotDev\m001_final`. Never touch `C:\GodotProjects\DynastyALWL` or other clones. Do not push. Godot only through the slot scripts with timeouts; never stop a process you did not start. Commit with `docs/ai-team/missions/M001/T19_RESULTS.md` (head SHA, per-step results, full-suite counts with log paths, defects found).
