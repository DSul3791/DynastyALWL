# M001-T07 brief: Phase 2b part 2, leather and textile stations and Thread

Mission 001, Phase 2b (`docs/design/CATALOG_IMPLEMENTATION_PLAN.md`). Owner: systems-engineer agent. Reviewer: independent gate-reviewer. Branch `m001/t07-textiles` in clone `E:\Software\godotDev\m001_p2b2` (base `cc5242ad8`: Phases 0-3 and the 2b metal route). New game: no old-save migration.

## Behaviour (master `docs/design/DYNASTY_MASTER_ITEMS.md` s2.8, s3.4, s4 items 10-11; [R], [C], [D1])
1. **Leatherworking table** (item 911, inactive row) goes live: structure (state 243), hammer blueprint 205, kit = its own id, its own station id `leatherworking_table`. Recipes 278 (Leather strap), 392 (belt), 356 (quiver), 361 (backpack), 213, 214, 358, 359, 360 (leather garments) move to it from wherever they are today.
2. **Tailor's table** (item 912) goes live the same way (state 244, blueprint 206, station `tailors_table`). Recipes 216 (Fibre - Gambeson) and 237-244 (wool, linen, fur clothing) move to it.
3. **Loom** (item 846, FUTURE) goes live (state 245, blueprint 207, station `loom`). Cloth recipes 245 (Linen), 334 (Fibre cloth), 342 (Wool cloth) move to it.
4. **Thread** (item 913) goes live with a hand recipe from plant fibre (next free recipe numbers from 409; amounts are s5 tuning: keep it cheap, e.g. 2 plant fibre -> 2 Thread), and replaces Twine in the 13 needle recipes 23, 39-42, 173, 194-196, 237, 238, 241, 388. Twine stays the binding cord everywhere else. Fur garments 242-244 keep Sinew.
5. Hide goods stay hand-sewn with the Bone - Needle (recipes 23, 30, 39-42, 173, 194-196, 388 by hand, 2.8 item 3): basic hide clothing needs no building.
6. **No Planks and no metal** in the Leatherworking table and Loom blueprints (s4 item 10: the first Bronze - Axe needs a Leather strap, and the pre-saw Feather - Bed and Fibre - Gambeson need Fibre cloth). Give the Tailor's table the same pre-saw cost class (logs, sticks, twine, stone, hide are fine).
7. Drying rack 775 (UPDATE): adds the hide-drying step (s3.4) only if the existing leather chain has a place for it without inventing an intermediate; otherwise record why it is left and report it (do not invent items).
8. Each station needs a drawable look (an existing builder reused as a marked placeholder in `look_placeholders.json` is acceptable; record it as NOT visually complete).
9. Ledger (`docs/design/catalog_ledger.json`): touched rows to IMPLEMENTED - UNVERIFIED with their tests; `python3 -I tools/catalog_ledger.py --check` passes.

## Rules
Work only in `E:\Software\godotDev\m001_p2b2`. Never touch `C:\GodotProjects\DynastyALWL` or other clones. Do not push. Godot only through `tools/run_one_test.sh` / `tools/run_tests.sh` with timeouts (PC slot lock, max 3 jobs; another suite may hold slots); never kill a Godot process you did not start. JSON edits stay line-local (CRLF, mixed hand formatting: never re-serialise whole files; a helper that replaces one entry's block in place is fine). No catalog changes beyond the above; report problems instead. Retired ids are never reused.

## Acceptance (Dave's PC, voxel build `GODOT_EXE=/c/GodotInstaller/godot.windows.editor.x86_64.exe`)
- `tools/run_one_test.sh validate_items` PASS, and `python3 tools/tests_for_diff.py cc5242ad8 HEAD` with no new failures against base (known: `test_flora_density` can time out under load; `test_npc_view` can crash at quit after printing PASS).
- A new player-path test: from a new character, gather hide/fibre, make Thread by hand, sew a hide piece by hand with the needle and Thread; build the Leatherworking table and make a Leather strap there; build the Loom and make Fibre cloth; build the Tailor's table and make a Fibre - Gambeson. Assert real pack and world state through the server.
- `/ponytail-review` of your own diff with answered findings; commit with `docs/ai-team/missions/M001/T07_RESULTS.md` (exact head SHA, test counts PASS/FAIL/NOT RUN, costs chosen, placeholder looks).
