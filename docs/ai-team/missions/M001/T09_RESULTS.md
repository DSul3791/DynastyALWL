# M001-T09 results: Phase 2c tool ladder data

- Branch `m001/p2c_data`, clone `E:\Software\godotDev\m001_p2c_data`, base `84186f06a`. Commits: `b20d54ff4` (data, tests), **`7c54ad9aa538fabf45f674cbc61371dbe3a395fa`** (review notes; tested head). This file is committed on top (docs only). Not pushed.
- Brief: `T09_BRIEF.md`. Master `DYNASTY_MASTER_ITEMS.md` s2.1, s2.2, s3.1, s3.6, s4 items 1, 2, 4, 6, 13, s7 items 2 and 6.

## What changed
- **Ten ladder tools live** (896-905): `tool_class`, `material`, `tier`, `durability`, `repair`, `repair_station`, `edge: true`; `future` removed. Recipes 410-419 (`next_number` 420), all known: bronze at `forge` (Stone - Forge or Smithy), iron at `brick_forge` level 2 (as the other iron tools), steel at `brick_forge` with no level.
- **Steel tools 34, 47, 224, 561, 800 live**; recipes 19 and 373 unlocked (known, no `locked`); all keep the Smithy, no level.
- **Groups** (`wood_species.json`): `axe` (stone, bronze, iron, steel), `saw` (Iron - Saw, Steel - Saw), `knife` + iron and steel knives. Labels "Any knife", "Any axe", "Any saw" (item_system.md rule 5). Recipes 20, 278, 344 keep `knife`; 339, 340 keep `axe`; 159, 408 keep `saw` (`wears_tool: saw` kept). `boulders.json tools.axe` + iron 1, steel 1 (as the picks).
- **Group key rows** `axe` 1253 and `saw` 1254 (kind material, "Never given itself", as `knife` 821): the group code (`item_table.gd load_groups`) needs a key item id. Looks rows (grey axe and saw shapes) and a `saw` weight added; `next_number` 1255 in items.json and gathered.json (shared space). Not catalog items; flagged for review.
- **Disposable** (s2.2 rules 1-3): 6, 11, 222, 244, 297, 19, 221, 247, 293, 7, 313, 295, 49 lose `repair`; Stone - Axe, Stone - Knife and Stone - Spear lose `edge` (edge only on metal tools, s2.2 rule 8). Stone - Knife gains `material: stone` (it had none; the tier check and the group spend order read it).
- **Metal tools**: `repair_station` = crafting station type (bronze `forge`, iron and steel `brick_forge`; 13 rows said `forge`, chisels and the Iron - Saw had none). `edge` added to the bronze, iron and steel pickaxes; never on hammers, hoes, spades. Iron - Saw repair 1 Twine + 1 Stick -> 1 Iron ingot + 1 Stick (master s6 #26).
- **Tiers** by material rank in every ladder family (Wooden 1, Stone 2, Bronze 3, Iron 4, Steel 5); Wooden - Spade and Wooden - Hoe now carry `tier: 1`. `digging.json tier_extra` {"2":1,"3":2,"4":3} -> {"4":2,"5":3} (wooden 0, iron 2, steel 3, as before). Blueprint `hammer` values unchanged: 1 (any hammer) and 3 (bronze 3, iron 4, steel 5 all pass `>= 3`), so any metal hammer builds every tier and wooden/stone hammers build what they built.
- **Grindstone** 906 live: structure state 246 (kit and item `grindstone`, station `grindstone` level 1, reach 3 m, borrows the `chopping_block` look: NOT visually complete), blueprint 208 (12 Stone, 2 Log; hammer 1; `next_number` 209).
- **Javelin** `stack` 1. **Recipe 3** Stone - Spear needs its Stone (no `keeps`).
- **Retired**: Stone - Spade 45 with recipe 26, Stone - Sickle 298 with recipe 187. Nothing live needs them (recipes, blueprints, goals, hints, shops, drops); showroom, encyclopedia, descriptions_voice and design_names keep their rows as for earlier retirements.
- `validate_items.gd`: "durability but no repair" became "a metal tool needs repair and a repair_station" (disposable gear has none by design); the `wears_tool` check counts a kept group's members.
- Ledger: 43 rows updated (`--check` passes): the 10 tools and both retirements IMPLEMENTED - UNVERIFIED; the rows whose behaviour also needs T10 code (disposable, repair, sharpening, Grindstone use) IN DEVELOPMENT with the reason.
- Tests: new `test_tool_ladder.gd`; `test_blueprints` (hammer message), `test_stations` (stone hoe for the bench recipe), `test_server_items` (no retired spade), `test_farming` (Bronze - Sickle).

## Numbers chosen (s5 tuning, for playtest)
Durability: iron = bronze x 1.5, steel = iron x 2.5 (the hammer family); bronze sickle = stone sickle x 2500/900 (the axe and knife stone-to-bronze step).
| Tool | Durability | Recipe (station) | craft s |
|---|---|---|---|
| Iron - Axe | 3750 | 2 Iron ingot, 1 Stick, 1 Leather strap (brick_forge L2) | 20 |
| Steel - Axe | 9375 | 2 Steel ingot, 1 Stick, 1 Leather strap (brick_forge) | 20 |
| Iron - Knife | 2250 | 1 Iron ingot, 1 Stick (brick_forge L2) | 12 |
| Steel - Knife | 5625 | 1 Steel ingot, 1 Stick (brick_forge) | 12 |
| Steel - Saw | 6250 | 2 Steel ingot, 2 Stick (brick_forge) | 12 |
| Bronze - Sickle | 1667 | 1 Bronze ingot, 1 Stick (forge) | 12 |
| Iron - Sickle | 2500 | 1 Iron ingot, 1 Stick (brick_forge L2) | 12 |
| Steel - Sickle | 6250 | 1 Steel ingot, 1 Stick (brick_forge) | 14 |
| Bronze - Scythe | 6000 | 2 Bronze ingot, 2 Stick (forge) | 12 |
| Steel - Scythe | 22500 | 2 Steel ingot, 2 Stick (brick_forge) | 14 |
Repair: one ingot of the tool's metal and one Stick, at its station type. Values and weights: the Phase 1 rows' own (unchanged). Grindstone: 12 Stone, 2 Log.

## Tier readers in code (none changed; for T10)
- `server_items.gd:7550` blueprint gate `tier < row.hammer` and `held_item.gd:420` / `hammer_blueprints.gd:119` client list: numeric; unchanged results (rows are 1 or 3).
- `server_items.gd:7592` best hammer by highest tier: steel now beats iron beats bronze (they tied at 3).
- `server_items.gd:7600 _hammers_for`: lists the lightest qualifying tier, so tier 3 now reads "a bronze hammer or better" instead of "a bronze, iron or steel hammer". `test_blueprints` follows; T10 may prefer to restore the full list.
- `server_items.gd:3118` spade tier -> `digging.json tier_extra` (string keys): remapped in data.
- `item_table.gd:131 spend_order` (lowest tier first): order unchanged.
- `server_items.gd:1275` spyglass tier (1, unchanged); `tools/tool_tiers.py` still maps 1-4 (wooden..steel) and `design/TOOL_TIERS.md` was already out of date at base: not regenerated.

## Evidence (Dave's PC, voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe`, working tree before commit)
- `tests_for_diff.py --paths <changed files>`: 221 tests (216 parallel, 5 serial). First run **214 PASS, 7 FAIL**: `test_blueprints` (live count 191 -> 192), `test_hammer_list` (141 -> 142), `test_inventory` (recipe 3 now takes its stone), `test_learn` (steel pickaxe recipe now known), `test_server_items` and `test_whetstone` (they exercised repair on stone tools, now disposable: the rows get their old repair in memory, so the mechanism stays covered until T10 rewrites it), `test_item_instances`.
- `test_item_instances` fails the same 3 checks at base `84186f06a` (run there: nut-cancel ages, restart instance, remains instance): pre-existing, not from this change. `test_server_items` PASS at base.
- After the fixes, rerun alone: `test_blueprints`, `test_hammer_list`, `test_inventory`, `test_learn`, `test_server_items`, `test_whetstone`, `test_tool_ladder` (179 checks), `validate_items` all PASS. So 220/221 with the one base failure; the full suite was not rerun after the six test edits.
- `validate_items`: 0 errors, 163 warnings (base 168: the five steel tools are no longer "future but obtainable"). `catalog_ledger.py --check` pass. `check_look_names.py` all 220 structure looks drawable. `check_dupe_names.py` ok.
- NOT RUN: `tools/items_check.py` (calls Godot outside the slot runner; failed to start here), the `warnings` check lane, in-game looks, the standard exe, startup smoke.

## Review notes (PASS WITH NOTES), fixed in `7c54ad9aa`
- Looks: `looks.json` rows for the ten tools (axe, knife, saw, sickle, scythe shapes; iron `#6c6f75`, steel `#9aa3ad`, bronze `#b5803a`, as their families). `basic_look.gd`: bit `metal` keeps an axe head's and a knife blade's row colour (they were drawn as stone). Sickle and scythe blades are drawn steel-grey whatever the metal, so the bronze ones are NOT visually complete. The `axe`/`saw` group-key looks rows stay: `validate_items` requires a look for every material-kind item (as `knife`).
- Future iron and steel Sword, Mace, Shield (318-323): `repair_station` forge -> brick_forge (bronze ones keep forge). Steel - Striker 294 tier 4 -> 5. Ledger notes added.
- Obsidian - Knife 296: left as it is (FUTURE, parked; still has `edge` and stone-style `repair`); revisit if it ever goes live.
- `stress_items_players.gd` queues recipe 140 (Stone - Hoe, camp bench) instead of retired 26; `showroom.json` drops both Stone - Spade entries.

## Evidence at `7c54ad9aa` (voxel build)
- `python3 tools/tests_for_diff.py 84186f06a HEAD` -> `tools/run_tests.sh --jobs 3`: 221 tests, **220 PASS, 1 FAIL** (`test_item_instances`: the same 3 checks fail at base `84186f06a`; fixed on dev per the mission lead). No flakes.
- `validate_items` PASS, 0 errors, 163 warnings; `test_item_looks`, `test_tool_looks`, `test_showroom` PASS (also in the suite). `merge_check.py` all clear. `catalog_ledger.py --check` pass. `check_look_names.py` all 220 drawable.
- NOT RUN: `items_check.py`, the `warnings` lane, startup smoke, in-game look check.

## Not done, risks
- No inventory icons for the ten tools, the Grindstone or the `axe`/`saw` group rows (`tools/compose_group_icons.py` not run: art step). `test_tool_ladder.gd` has no `.uid` (as `test_textile_route.gd`; Godot writes it on import).
- Recipe numbers 410-419 and item numbers 1253-1254 may collide with a parallel phase branch taking `next_number` from the same base.
