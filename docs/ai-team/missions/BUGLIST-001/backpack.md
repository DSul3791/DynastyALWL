# BUGLIST-001 backpack: DESIGN-001 (backpacks improve carry weight, not inventory slots)

Baseline SHA f5d6b54 (origin/dev). Branch `claude/buglist001-backpack`. No Godot ran in the cloud: every test below is NOT RUN until the PC run.

Requirement (BUGLIST-001 section C): equipping a backpack must not change the count of inventory slots; it improves comfortable carry-weight capacity and encumbrance through weight distribution; different quality may change the effect; verify before/equipped/after-unequip, no item loss or duplication near capacity or in saves.

## Verification by reading the code (baseline f5d6b54)

| Point | Result | Evidence |
|---|---|---|
| Wearing changes the pack's slot count | PASS | `_wear` (server_items.gd, just above `_unwear` at 11994) only moves the piece to a worn position and returns displaced pieces to the pack; nothing touches `inv.slot_count`/`usable`. The pack grows or shrinks only with its contents (inventory.gd:63 `trim`, protocol 116). |
| A backpack adds slots of its own | FAIL on the strict reading, see Q1 | items.json rows 50 and 767 carry `bag_slots` 10 and 15 (catalog Phase 5, M001-T15, `src/shared/bag_rules.gd` `slots_of`): a separate per-bag container opened from the Tab screen, held in the worn piece's instance data. The pack itself stays 30 slots. |
| Wearing raises comfortable carry weight or the limit | FAIL (the defect) | `carry_bonus_kg` was deleted in fc67431 (M001-T15): `_carry_body` (server_items.gd:11936) returned the body weight alone and client `carry_body_kg` (inventory_view.gd:4653) likewise; docs/CARRY_WEIGHTS.md:17, master s3.9 rule 2 and validate_items.gd:1186 forbade it; test_carrying.gd asserted "the worn pack does not raise the carry limit". The reverse of DESIGN-001. |
| Quality matters | FAIL (baseline) | No weight effect existed on either row, so hide and leather encumbered identically; only bag_slots differed (10 vs 15). |
| Unequip near capacity: loss or duplication | PASS | `_unwear` (server_items.gd:11994) does `inv.add(...)`; if that fails the piece stays worn ("Your pack is full") so nothing is lost or doubled; the pack grows for it. Over the limit afterwards: slowed, never stripped, told once (`_carry_notice`, server_items.gd:10143; CATALOG_SAVE_MIGRATION.md rule 10). |
| Saves | PASS | Worn pieces and their instance data are saved in characters.json `worn`; the effect is derived from the worn numbers on every read, so nothing extra is persisted. |

## Change (second part of the commit, easy to drop if the ruling differs)

Restore the weight effect for the two backpacks only, from the values the catalog already carried before M001-T15 retired them (items.json at fc67431^: Hide - Backpack 12, Leather - Backpack 18; master DYNASTY_MASTER_ITEMS.md s3.9 table row "Backpack carry bonus"). No new numbers, items, mechanics, protocol or save-format change.

- data/items/items.json: `carry_bonus_kg` 12 on row 50, 18 on row 767 (field restored; bag_slots untouched).
- src/shared/carry_rules.gd: `carry_bonus_kg(numbers, table)` (sum over worn numbers) and `carry_body_kg(weight, worn, table, cfg)`, the one formula both sides call.
- src/stream/server_items.gd `_carry_body`: calls `CarryRules.carry_body_kg` (body weight plus bonus / carry_kg_per_body_kg, the original formula); `_loaded_bag_effort` works the comfortable load out only when a worn bag has loaded_effort, so the limit and the comfortable load (free_ratio of it) both rise (limit +12 or +18 kg, comfortable +9.6 or +14.4 kg). Everything keyed on it follows: pick-up refusal `_fit`, `_carry_notice`, loaded-bag effort, cart cargo check.
- src/client/inventory_view.gd: `carry_body_kg` calls the same helper (bar, walk slowdown, pick-up gate); the item tooltip says "you can carry N kg more".
- src/worldgen/tools/validate_items.gd: `carry_bonus_kg` allowed only as above 0 up to 60 kg on a `back` piece (was forbidden everywhere).
- docs/CARRY_WEIGHTS.md note updated. Item descriptions left as they are ("its load still weighs on you" stays true).

## Tests (NOT RUN)

- NEW src/worldgen/tools/test_backpack_carry.gd (+ .uid): measures slots, limit and comfortable load before equipping, with Hide then Leather worn, after unequipping; leather above hide; a load that slows a bare body but not a wearer; near capacity (40 axes + 28 stones = one stack, 42 stacks with the backpack, 68 kg) worn then taken off: nothing lost or doubled, slowed and told once, no further pick-up; an emptied pack back to 30 slots; save and reload worn, then unequipped. Prints `INFO` lines with the raw numbers for the evidence run.
- ADJUSTED test_carrying.gd (rows 50/767 now have the bonus and no other row does; the worn-pack check expects +12 kg) and test_warmth.gd:149 (same). Both asserted the retired behaviour.
- Run: `godot --headless --path . --script res://src/worldgen/tools/test_backpack_carry.gd`, then test_carrying, test_warmth, test_pack_growth, validate_items.

Regression risks: both adjusted tests encoded the old rule; a player over the plain limit after taking a pack off is only slowed (rule 10); bag slots on the backpacks still exist (Q1); master s3.9 rule 2 text and the T15 docs now disagree with the code (history, left as written).

Status: NEEDS PLAYER VERIFICATION (weight effect). Slot point: see Q1.

## Coordinator rulings (05:27Z, 13 Nov 2026; the coordinator's words, not Dave's; for Dave's confirmation)

- Restoring `carry_bonus_kg` 12 and 18 on rows 50 and 767 is a value correction to meet DESIGN-001 and is allowed; 12 and 18 are starting values for Dave to tune.
- DESIGN-001 (later, explicit requirement) wins over master s3.9 rule 2 [D9]. The D9 text is not rewritten: dated notes (13 Nov 2026) beside the "Backpack carry bonus" check, the carry-limit recommendation and the row 50 and 767 text in docs/design/DYNASTY_MASTER_ITEMS.md point to BUGLIST-001 DESIGN-001 and this ruling.
- The `bag_slots` containers stay (Q1 remains open for Dave). PROTOCOL.md entry 109 updated to match (documentation only, no version bump).
- Gate review of deb9815 fixes (this follow-up): stack count in the near-capacity check (28 stones are one stack, so 42 stacks), shared `CarryRules.carry_body_kg`, lazy `_loaded_bag_effort`, a client/server helper-agreement check, stale validator comment.

## Open questions (decisions recorded, nothing waited on)

- Q1: Does "must not change the count of inventory slots" also forbid the backpack's own `bag_slots` container (10 and 15 slots, T15)? Recorded decision: the pack's slot count is unchanged (PASS) and the bag containers are left, because removing `bag_slots` from rows 50/767 would orphan contents already saved inside worn or carried backpacks (a migration, a Class C save question), and about a dozen tests (test_carrying, test_hotbar_keys, test_mission001_walkthrough, ...) use the backpack as their bag. The rucksack, pack basket and satchel are also unchanged. If Dave means no bag slots on backpacks, that is a separate ruled change with a contents migration.
- Q2: The restored 12 and 18 kg are the earlier catalog values, not newly tuned ones; confirm or retune (data/items/items.json only).
- Q3: master s3.9 rule 2 ("a pack never adds muscle power", marked APPROVED [D9]) conflicts with DESIGN-001. I followed DESIGN-001 (Dave's later, explicit requirement); the master text needs a note from the document owner.

## F6 player check

Wear the Hide - Backpack with the pack nearly full of stone (carry bar yellow or red around 42 kg): the bar's comfortable mark and limit move out (about 51.6 and 64.5 kg at 75 kg body), the walk returns to normal speed, and the inventory shows the same slots; take it off and the bar and slowdown return. The Leather - Backpack moves them further (about 56.4 and 70.5 kg).

## Test evidence (PC run, 13 Nov 2026)

Every GDScript test marked "NOT RUN" above has now run (below); picture lanes and visual or sound checks have still not run. Ran on the David4 test PC (Linux, Godot 4.7.2 voxel build, headless, 2 jobs, fresh import) on `claude/buglist001-integration` at 8e46c4b254ed8061938cecee06a2cbb8665393c9 (dev f5d6b54 + all seven BUGLIST-001 heads). Result: 370 pass, 0 fail, no retries (fast 361/361, timing 8/8, slow 1/1 test_worldgen). validate_items PASS (0 errors), check_look_names PASS, warnings: none new over tools/warning_baseline.txt. Startup smoke: welcome 15.7 s, ground ready 133 s, 0 script errors, exit 134 (known headless exit). Picture lanes (5): NOT RUN; visuals and sound not checked. Logs: David4 /work/lanerun/bl001b_plan, /work/lanerun/bl001b_extra. An earlier run on a0b5365 failed 2 tests (test_hammer_list counts, test_server_items road restart height) plus 3 warnings; those were test-only fixes, reviewed, and are in 8e46c4b. Merged to dev by PRs #1068-#1074; dev add271196 has the identical tree (c6ec74eb). Status stays NEEDS PLAYER VERIFICATION until Dave's F6 check.

## Follow-up 13 Nov 2026: no backpack slots (Dave)

Baseline e08a680 (origin/dev). Dave, 13 Nov 2026 11:35Z: "Backpacks do not have slots. The only thing they do is give you more carry weight." This answers Q1 above: the `bag_slots` containers on rows 50 and 767 go. Scope: those two items only (`backpack` #50 Hide - Backpack, `leather_backpack` #767 Leather - Backpack). Every other bag (quivers, shoulder bag, wicker pack basket, rucksack, pack frame, pouch, satchel, tool roll, scabbard, bandolier) keeps its slots and the shared bag code (bag_rules.gd, the server's worn-bag container -1 - position, the container panel, character_screen) still serves them. No protocol or save-shape change.

Change:
- data/items/items.json: `bag_slots` and `bag_takes` removed from rows 50 and 767; `carry_bonus_kg` 12 and 18 and everything else kept. Descriptions say what they do now: #50 "A hide pack worn on the back. It lets you carry more weight."; #767 "A leather pack worn on the back. Lets you carry more weight than a hide pack, and sheds a little rain." Same text in data/items/descriptions_voice.json (#50) and data/items/encyclopedia.json (both).
- src/shared/inventory.gd: new `Inventory.clean_inst_of(table, number, raw)` = `clean_inst` and then drops a `bag` key when the item's items.json row has no `bag_slots` (no table: nothing dropped). `from_json_array` uses it. Comment says it is how an older save's backpack contents are dropped (Dave 13 Nov 2026).
- src/stream/server_items.gd: the same helper in `_clean_worn` (worn list in characters.json) and in the loose world-item row load (ground items). One comment tweak at `_carry_body`.
- Leftover backpack-slot code: none found to delete. The server (`_worn_bag`, `_chest_of`), the client (`character_screen`, `inventory_view`, `container_panel`) and `BagRules.slots_of` all key on `bag_slots > 0`, so a backpack drops out of them by data alone. The client tooltip (`inventory_view.gd` ~5134) adds the "Holds N slots" sentence only for `slots_of > 0`, so a backpack now reads "Worn on the back ... you can carry N kg more." with nothing about slots. validate_items.gd only checks rows that have `bag_slots`; it needs no change.
- docs: dated notes (13 Nov 2026, Dave) beside the backpack rows and rules in docs/design/DYNASTY_MASTER_ITEMS.md (s3.9 rows 50 and 767, "Backpack carry bonus" check, carry-limit bullet, back container line, Appendix rows 50 and 767); docs/design/catalog_ledger.json notes for 50 and 767 (`python3 -I tools/catalog_ledger.py --check` passes); PROTOCOL.md entry 109 note (no version bump). data/items/clothing.json notes say "one pack on the back" and bags generally, nothing about backpack slots: unchanged.

Old saves ("this is a new game so there are no existing things in the world", Dave): no migration. A saved backpack instance that still carries `bag` rows loads plain and adds no weight (`CarryRules.bag_kg` reads the instance, so a dropped key means no invisible weight). Covered load paths: every `Inventory.from_json_array` (player packs inventories.json, chests, crates and a body's remains in chests.json, a handcart's cargo store, craft undo backups, bag contents opened by BagRules.open) through `clean_inst_of`; the worn list (`_clean_worn`, characters.json); loose ground items (world_items.json rows). Not covered, and needing no cover: the craft-queue unit instances (`_load_craft_queues`, what a craft took; no recipe consumes a backpack) and the client (`inst_from_bytes`, server-clean data). A real bag keeps its contents through the same load.

## Tests (NOT RUN, no Godot in the cloud)

- test_backpack_carry.gd: both backpacks `slots_of == 0` with no `bag_takes` and `carry_bonus_kg` 12/18 unchanged; a worn Hide and Leather backpack is not opened (no container window sent) and takes nothing; old-save section: a pack row, the worn Leather and a ground Hide backpack whose instances carry `bag` rows load with no `bag` key, carried weight drops by exactly those 9 stones, and a Wicker - Pack basket with contents keeps them.
- test_carrying.gd: the container system (fill, drop, chest, hand-over, despawn, save) now uses the Wicker - Pack basket (back, 10 slots, any); asserts the backpacks have 0 slots, the worn backpack refuses ACT_CHEST_OPEN and a put, and the +12 kg carry limit check stays.
- test_mission001_walkthrough.gd 3p/3q: the backpack is still crafted and worn; 3q now asserts it has no slots, is not opened and takes nothing (the old capacity check is gone); the gathered kinds are still put down afterwards so later steps see the same pack.
- test_warmth.gd, test_clothing_layers.gd, test_server_items.gd (recipe live check): use the backpack only as a worn piece or a recipe: unchanged.
- Run: `godot --headless --path . --script res://src/worldgen/tools/test_backpack_carry.gd`, then test_carrying, test_mission001_walkthrough, test_warmth, test_clothing_layers, validate_items.

Regression risks: a test or save that put things into a backpack no longer can (intended); the walkthrough's 3q no longer exercises bag capacity (test_carrying's basket does).

Status: NEEDS PLAYER VERIFICATION.

F6 check: wear the Hide - Backpack (or Leather): the Tab screen and the pack show no bag window for it and the item tooltip mentions only "carry N kg more"; the carry bar's limit still rises (12 / 18 kg). Wear a Wicker - Pack basket: its 10-slot window still opens.


## Follow-up 2, 13 Nov 2026: all back packs (Dave)

Baseline 36a3250 (origin/dev, after PR #1076). Dave, 13 Nov 2026 16:19Z: "correct no backpacks have slots they only improve the weight you can carry due to ergonomics" (confirming that the other back-slot packs lose their slots as #50 and #767 did). Dave, 16:21Z: "I think we need to do away with wooden." The lead reads this as retiring the Wooden - Pack frame (#988); that reading is the lead's, not Dave's wording.

Change:
- data/items/items.json: Wicker - Pack basket (#983) and Traveller's rucksack (#987): `bag_slots`, `bag_takes` removed (rucksack also `loaded_effort`), `carry_bonus_kg` added. Descriptions now talk about carrying more weight; the basket stays cheap and poor in the wet, the rucksack is for long journeys. These two names were not in descriptions_voice.json or encyclopedia.json, so nothing to update there.
- Starting values for Dave to tune (lead-chosen, items.json only): Hide 12 and Leather 18 (unchanged), basket 8, rucksack 24. Reasoning: they keep the order of the old slot counts and of cost and craft effort (basket 10 slots, value 20, made by hand from sticks and twine; Leather 18 kg; rucksack 20 slots, value 130, Tailor's table). The basket is below the hide pack, the rucksack the best of the four (a 75 kg body carries about 52.5 kg, so +24 kg is about +46 percent).
- Wooden - Pack frame (#988): retired. Retirement path used: the M001 convention "numbers kept, new game: no old-save migration" (the same as Stone - Wedge 353 and Saw blade 238; docs/design/CATALOG_SAVE_MIGRATION.md rule 3). Row 988 stays in items.json with `"retired": true` and loses `slot`, `bag_slots`, `bag_takes`, `worn_speed_mult` and `loaded_effort`; recipe 608 stays with `"retired": true` (the recipe table skips it at load, so it leaves the Carpenter's bench list); its `worn.json` row is removed (no slot, no worn look); its `looks.json` row stays, with its `look_placeholders.json` reason updated, because validate_items wants a looks row for every gear item. The number 988 is never reused. No `renames.json` pair (there is no successor) and no `refund` list: CATALOG_SAVE_MIGRATION.md rule 5 describes refund lists and a `migrate_catalog` pass, but neither exists in data or code (no row has `refund`, no `migrate_catalog`), so I did not invent one. An old save holding a frame: pack, chest and ground rows keep the number and load as an inert item with no slot (its `bag` contents dropped by `Inventory.clean_inst_of`); a worn frame is blanked by `_clean_worn` (existing loss path in CATALOG_SAVE_MIGRATION.md section 1). Dave has said this is a new game with no existing items, as for #1076.
- Deleted code (Decision 61): `ServerItems._loaded_bag_effort` and its use in `effort_of`; `CarryRules.worn_speed_mult` (the frame was its only data user) with its callers, the server's strike recovery and bow pace (src/stream/server_items.gd `_strike`, `_shoot`) and the client's `worn_speed()` in `speed_factor()` (src/client/inventory_view.gd); the bag_takes `awkward` rule in `BagRules.refusal`, the validator's `awkward` entry and the clothing.json `bags` note (the frame was its only user); the `weighed` parameter of `_give_shoulder` (it only served a large log taken out of a worn pack frame; `_box_take` keeps its own `weighed` for other worn bags). Stale comments about the frame and `loaded_effort` fixed (clothing.json note, server_carts.gd, carry_rules.gd, server `_carry_body`).
- Carry-bonus path: unchanged and already generic. `CarryRules.carry_bonus_kg` sums `carry_bonus_kg` over every worn number, so any worn back piece counts; `carry_body_kg` is shared by the server (`_carry_body`) and the client (`inventory_view.gd carry_body_kg`); only one `back:base` piece is worn at a time. validate_items.gd (line 1186) only requires a number above 0 up to 60 on a `back` slot, not a list of two backpacks, so it needed no change; the client tooltip adds "Spreads the weight: you can carry N kg more." for any worn piece with the bonus. Other bags (quivers, shoulder bag, satchel, pouch, tool roll, scabbard, bandolier) keep their slots and the shared bag code.
- docs: dated notes (13 Nov 2026 16:19Z and 16:21Z) at DYNASTY_MASTER_ITEMS.md s3.9 rows 564, 568 and 569, rule 2, the "Backpack carry bonus" check, the carry-limit bullet and the `back` line (the Appendix A rows only list the older rows 50 and 767, no rows for 983, 987 and 988); catalog_ledger.json notes for 983, 987 and 988 (`catalog_ledger.py --check` passes; 988 keeps its "TESTED - ACCEPTED" state for the original add); PROTOCOL.md entry 109 note (no bump). No Python tool read `loaded_effort` or `bag_slots` for these items.

## Tests (NOT RUN, no Godot in the cloud)

- test_carrying.gd: the container system (fill, drop, chest hand-over, despawn, save and reload, swap, wolves) now uses the Fibre - Shoulder bag (shoulder, any, 4 slots); a leather satchel is the bag refused inside it and the one swapped in; the despawn check counts two full shoulder bags on the ground and a gone empty pouch. Row check: the four live back packs (and only they) have `carry_bonus_kg`, none has slots, `bag_takes` or `loaded_effort`. New: a worn bag refuses a large log; no item row has `worn_speed_mult`, `loaded_effort` or bag_takes `awkward`. The frame's old log, speed and effort checks are gone with the frame.
- test_backpack_carry.gd: section 1b wears each of the four back packs in turn and checks `slots_of == 0`, no `bag_slots`/`bag_takes`/`loaded_effort`, the bonus 12/18/8/24, the server limit rise of bonus / 0.7, and that the worn pack refuses a container open and a put; the plain limit returns with none worn; the frame row is retired with no slot and no speed penalty. Old-save section: the basket with a `bag` row now loads plain too (11 stones of invisible weight dropped, not 9) and the Fibre - Shoulder bag is the real bag that keeps its contents.
- Each new check fails on the old data (slots 10 and 20, no bonus on the basket and rucksack, frame wearable with `worn_speed_mult`).
- Run: `godot --headless --path . --script res://src/worldgen/tools/test_backpack_carry.gd`, then test_carrying, test_item_looks, validate_items, test_mission001_walkthrough, test_item_renames, test_save_compat.
- test_mission001_walkthrough and the other tests do not mention these three items or `loaded_effort` (grep over src/worldgen/tools).

Regression risks: recipe 608 leaves the Carpenter's bench list (a recipe-list count assertion anywhere would show it; none found by grep); a player holding a frame in an old save loses its use (new game, no migration written); the rucksack and basket values are a first guess.

Status: NEEDS PLAYER VERIFICATION.

F6 check: wear the Wicker - Pack basket, then the Traveller's rucksack: neither shows a bag window, the carry bar's limit rises by about 8 kg and 24 kg, and the tooltip says "Spreads the weight: you can carry N kg more." The Carpenter's bench no longer lists a Wooden - Pack frame; swinging a sword or walking with a pack is at normal speed.
