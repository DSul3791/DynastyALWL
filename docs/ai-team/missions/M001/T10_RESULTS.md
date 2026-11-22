# M001-T10 results: Phase 2c durability, repair, sharpening, craftsmanship and Tempered steel (code)

Branch `m001/p2c_code`, base `84186f06a`. Code under test: **`f3164d2c3`** (`7b3d64f26` the change, `f3164d2c3` two test fixes; the commit after it adds only this file). Machine: Dave's PC, clone `E:\Software\godotDev\m001_p2c_code`, voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe`, headless, through `tools/run_tests.sh` / `tools/run_one_test.sh` (slot lock). Engineer: systems-engineer agent, 12 Nov 2026. Not pushed.

## Design (all numbers in `data/items/smithing.json`; s5 tuning for playtest)
Rules live in `src/shared/smithing_rules.gd` (static, server and client).
- **Maximum durability** = `inst.max_d`, else the row's `durability`: `_is_broken(inv, slot)` (every server break check), hotbar `key_slot`, `_wear_slot`, durability bars and Condition (pack, chest, hotbar), tooltips, Hob's sale price and mending price. `Inventory.MAX_D_CAP` 1 000 000 (was 65535: a Tempered +2 steel spade passes it).
- **Breaking:** a row with durability and no `repair` is disposable: cleared at zero ("Your stone axe broke and is gone."); a thrown one whose throw breaks it is not dropped. Any other stays broken in its slot and is not used; the message names its repair station and materials.
- **Repair (R):** at `repair_station` with the row's `repair` materials, wear to 0, `max_d` unchanged. Disposable rows are never mended (also refused by Hob: `repair_cost` 0). `tool_wear.repair_restores` and `tool_wear.hone` and `_hone` are deleted.
- **Sharpness (edge rows):** each use adds its wear to `inst.sharp`; fully dull at `dull_share` 0.1 x row durability x (1 + 0.5 Tempered + 0.25 per craft level). **Dull effect:** fully dull wears `dull_wear_mult` 2x.
- **Sharpening (R on a dull, unbroken edge tool):** a grindstone station within reach, else a sound whetstone in the pack with water at hand (a filled water container in the pack, a tank, `water_near`, or a record spring/brook within the thirst reach). Timed job: whetstone `full_s` 300 s for a fully dull tool, in proportion to the dullness, x1.5 faster sitting (stance 2) on a seat; grindstone 90 s, no water. Then the next dull edge tool in the pack, automatically. Stops (partial credit in proportion) when the player walks 1.5 m from the start, leaves the grindstone's reach, or loses the water or whetstone. Restores sharpness and lowers `max_d` by `sharpen_cost` 0.02 x row durability x the share restored (rounded up). The whetstone wears 1 per tool. Not saved; cleared on disconnect.
- **Variants (`ACT_CRAFT_QUEUE` b; bit 0 Tempered, bits 1-2 +1/+2):** eligible = one unstackable `tool`/`weapon`/`clothing`/`gear` per craft. +1/+2 only at a Master smithy that serves the recipe's station; Tempered only for steel rows (`material` steel or id `steel_*`, not `steel_striker`) with a `quenching_trough` within `addon_reach_m` of a Smithy or Master smithy that serves the recipe. Server checks at queue time and every craft tick (the craft waits away from the stations); bad codes are refused. Cost: materials x1.5 (+1) / x2 (+2), rounded up; time x2 / x3, x1.5 Tempered (multiplied). `max_d` set once at craft = durability x (1 + 0.25 Tempered + 0.15 per craft level): bonuses add. +1/+2 also: dulls slower (above), sale value x1.5 / x2, melee damage +1 / +2. Queue entries `[recipe, count, needs, parts, chain, variant]`, saved. Repair and sharpening never set `temper` or `craft`.
- **Client:** recipe card "Make as" (variants the stations beside you allow, with the cost factors); Craft time shows the variant; name "Tempered Steel - Pickaxe +2" (`inst_label`); tooltip and info strip show Sharpness %; R also sharpens. No new message; `PROTOCOL.md` (13, 21) and `terrain_net.gd` comments updated; no PROTOCOL_VERSION bump (an old client sends b = 0, plain).

## Tests
| Run | Result |
|---|---|
| New `test_tool_care` (34 checks: disposable gone, Javelin, metal break/stay/refuse/repair at station to remaining max, +1/+2 at Master smithy only with cost/time/max, fixed through repair, Tempered only steel with trough, plain without, iron refused, Tempered +2 additive, repair keeps flag, forged codes 5/7/-1 refused, variant through save/load) | PASS |
| `test_whetstone` rewritten (21 checks: dulling, dull effect, no-edge spade, water needed, 300 s, max_d cost, proportional, next tool, walk away, water gone, seat faster, grindstone 90 s no water, leaving it, broken not sharpened) | PASS |
| `tests_for_diff.py 84186f06a HEAD` plan (337 fast + 8 timing), `run_tests.sh --jobs 3` at `7b3d64f26` | 342 pass, 3 fail |
| `test_chest_column` (its fake store lacked `max_durability`): fixed in `f3164d2c3`, rerun | PASS |
| `test_flora_density` 300 s timeout under load; rerun alone, 600 s | PASS (403 s) |
| `test_item_instances`: 3 FAIL (nuts cancel ages, pack after restart, remains) | same 3 FAIL at base `84186f06a` (run here): pre-existing; the nuts section writes slots 0 and 1 directly over the sorted iron axe |
| `test_whetstone`, `test_server_items`, `test_trade` rerun at `f3164d2c3` | PASS |
| `validate_items` | PASS (0 errors, 168 warnings) |
| `check_look_names.py`, `merge_check.py` | clear |
| warnings: none on changed lines (two new integer divisions in tests fixed) | PASS |
| Full suite at `f3164d2c3` | NOT RUN (the second commit touches three tests only; they were rerun) |

No new failures against base.

## Self-review (`/ponytail-review`), answered
- Stale sharpening job after a reconnect: `_sharpening` now cleared on disconnect.
- `made_inst` reuses `Inventory.make_inst`.
- Unmeasured risk: an active whetstone job calls `water_near` 4 times a second per sharpening player; a variant craft head scans world items for the stations each slow tick.

## Not done, risks for the reviewer
- Interpretation: sharpening starts with R (then runs automatically through the dull tools); master s2.2 rule 7 says "automatically". Grindstone needs no water. R on a dull worn tool sharpens first unless you are at its repair station without sharpening means.
- `validate_items.gd` still fails a row with durability and no repair: T09's disposable rows need that rule changed (T09's or the merge's job).
- Stand-ins: stone axe/Javelin `repair` removed in tests, steel recipes made known, pickaxe edge, Grindstone structure row (state 246 is T09's).
- Wear travels as u16: rows above 65535 (steel spades, and Tempered/+2 maxima) show wrong bars on the client (pre-existing for the 81000 rows).
- Craft queue on the client shows no variant; the Craft button is enabled from the plain needs (the server refuses a short variant). Clothing/armour variants: only durability, value (and damage for weapons); no warmth or weight effect. NPC grindstone use not built. Recipe card UI not checked in game.
- `test_item_instances` pre-existing failure (above) should be fixed by its owner.

## Integration onto T09 and review fixes (branch `m001/int3`, clone `E:\Software\godotDev\m001_int`)
Base: dev `b62db1e7c` + T09 `0539f99b3` + T10 `eb3d50d89`, merged by the mission lead at `99155ebae`. Code under test: **`471c5d001`** (`bbd4e0a3d` integration, `471c5d001` review fixes; the commit after it adds only this section). Same PC, voxel build, slot scripts.

| Change | Where |
|---|---|
| Test stand-ins removed; tests read T09's live rows (disposable Stone - Axe and Javelin, edged pickaxes, known steel recipes, the Grindstone structure 246). `test_tool_care` section 7 breaks and repairs every Phase 2c tool or weapon row of the ledger (32 rows). `test_server_items`' wear section follows the disposable Stone - Axe; `test_trade` asserts the live row. | tests |
| `validate_items` agrees with the code: disposable rows need no repair (T09); a `repair_station` must be a live structure's station and needs repair materials; an `edge` needs a repairable row; `smithing.json`'s whetstone, stations, temper add-on and three cost factors must exist; every "Steel - " weapon or clothing row must be in `temper.include`. | `validate_items.gd` |
| Tier ranks (Wooden 1 .. Steel 5): T10 code reads no tier (`_hammers_for` is T09's). | none |
| Ledger: the 30 phase 2c rows waiting on T10 (all but the Kiln) are IMPLEMENTED - UNVERIFIED with `test_tool_care` / `test_whetstone`. | `catalog_ledger.json` |
| Review MUST: Tempered now reads `smithing.json temper.include` (the s3.6/s3.7 steel weapon and armour rows, which carry no material: Steel - Cuirass `plate_cuirass` and 19 others) besides `material: steel` for tools; the `steel_` prefix rule is gone (it took the s3.10 Steel - Plate barding, outside s4 item 15). Ammunition (stacks), the Striker and the barding are never eligible. | `smithing.json`, `smithing_rules.gd` |
| Sharpening that lowers `max_d` to the wear breaks the tool as a use does (`_tool_broke`: disposable gone, metal stays broken). | `server_items.gd` |
| A running variant craft re-checks its stations at most once a real second per player (`_variant_here`), not every 0.25 s tick. | `server_items.gd` |
| Client: the recipe card's wells, Short line and Craft button use the chosen variant's scaled needs (no parts plan for variants, as the server); Lasts shows the variant's maximum; `craft_variants` is memoised per frame and uses the nearest Smithy / Master smithy, as the server does; the craft queue carries the variant (`[recipe, count, variant]`, PROTOCOL.md) and shows it with its longer time; a disposable tool that vanishes at its end plays the break sound (a `shortcut:` heuristic: within 10 wear of its end). | client |

| Run at `471c5d001` | Result |
|---|---|
| `tests_for_diff.py origin/dev HEAD` plan (338 fast + 8 timing), `run_tests.sh --jobs 3` | 344 pass, 2 fail |
| `test_flora_density` (300 s timeout under load), rerun alone 600 s | PASS (392 s) |
| `test_npc_view`: prints `test_npc_view: PASS`, then exit 139 at quit (known flake, T04 record; loads no T10 file), rerun alone | same: PASS printed, segfault at quit |
| `test_tool_care` (130 checks), `test_whetstone` (24 checks) | PASS |
| `validate_items` | PASS (0 errors, 163 warnings) |
| `merge_check.py`, `check_look_names.py` | clear |
| `catalog_ledger.py --check` | exit 0 (IMPLEMENTED - UNVERIFIED 100, IN DEVELOPMENT 1: the Kiln) |
| warnings in the new or changed T10 scripts | none new (server_items and test_server_items warnings are older lines) |

Decision recorded: R starts sharpening, then the sequence runs on by itself (mission lead, review). Still open: wear on the wire is u16 (maxima above 65535 show wrong bars; older for the 81000 spades); the craftsmanship damage bonus is melee only (thrown and bow damage unchanged); the recipe card and queue are not checked visually in game.
