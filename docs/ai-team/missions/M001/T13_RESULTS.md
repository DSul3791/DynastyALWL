# M001-T13 results: Phase 9 storage rows, code locks, Storage sign and Warehouse desk

Branch `m001/p9` (clone `E:\Software\godotDev\m001_p9`), base `f3d0d2ac0`. Code under test: **`60f9b4027`** (round-1 review fixes `0bfec1b95` merged with dev via `m001/p4a-layers` `dd903d971`, whose tree equals dev `fefee0aa2`; the commit after it changes only this file). The first evidence block below is round 0 at `be3d8c9df`. Brief: `T13_BRIEF.md`. Owner: systems-engineer agent. Review: pending (independent gate-reviewer).

## What went live
- **Sixteen s3.13 rows** (items 1225-1240): `future` removed, `slots` on the item rows, structure rows (states 260-275), hammer blueprints 220-235 (`next_number` 236), `spoilage.json place_mult` for the 14 containers. Category "Storage and shelter".
- **Content rules (data):** structures.json `takes` (item ids or ingredient groups, any member) and `takes_kinds` (items.json kinds). A container with neither takes anything. Enforced on put, Store all and view deposits (`_box_takes`).
- **Code locks:** structures.json `lockable` on every chest grade (Wicker, Crude, Rustic, Fine, Ornate), the Large wooden chest, the Crate and the Warehouse crate. Racks, shelves, cupboards and the new household furniture are not lockable (s3.13: "not a mandatory universal lock on baskets, shelves, racks and other furniture").
- **Storage sign** (8 m, rank 1) and **Warehouse desk** (16 m, rank 2): views over nearby physical containers; list (search), withdraw (one, a stack, all) and deposit (a pack stack, or every stack already stored there).

## Lock and permission design (server_items.gd "Code locks and storage views")
- Default open to anyone ("who": "anyone" stays the default access). New game: every container starts unlocked; the saved `owner` (set at placement) is kept.
- `struct["lock"] = {salt, hash, ok, allow, tries}`: `hash` = sha256(salt + ":" + four-digit code); the code itself is never saved or sent. `ok` = character keys that entered the current code; `allow` = keys the owner let in; `tries` = key -> [consecutive failures, unix deadline].
- Owner: opens without a code; sets/changes (new salt, `ok` cleared, `allow` and waits kept), removes (everything dropped), lets in the nearest other player within 4 m, withdraws all access. Nobody else can change the lock.
- Others: a code try during a wait is refused and not counted; a wrong code waits 10 s x consecutive failures (no cap); the right code adds the player to `ok` (their access only) and resets their count. Waits use the server's unix clock (`_unix`), keyed by character and persistent container (the lock lives in the container's struct, so Phase 10 movement carries it).
- One check, `_may_access`, on: `_chest_of` (open, put, take, Take all, Store all, Sort), live pushes to viewers (`_push_box`), take-down, hammer repair sourcing (`_boxes_near`, which used any container in reach), both views. Crafting, blueprint sites and Stack to nearby already use only the player's own containers (CraftStock.owner_ok), so they never pass a lock. No NPC job sources from containers today (none found in `src/stream`).
- A lock change shuts out a viewer who lost access.
- Phase 10 hook: `_may_access` before lifting or loading a crate (comment in the section header).

## Wire and save
- `PROTOCOL_VERSION` 108 (107 is Phase 4a's). Actions `ACT_CHEST_LOCK` 71 (b = op, count = code 0-9999 read as four digits), `ACT_VIEW_OPEN` 72, `ACT_VIEW_TAKE` 73, `ACT_VIEW_PUT` 74. RPCs `chest_lock(id, locked, mine, may_open, wait_s, allowed)` and `storage_view(id, numbers, counts, containers)`. `PROTOCOL.md` rows and the 108 note.
- `world_items.json` version 2: structure rows gain index 17, the lock as a JSON string ("" unlocked). Version 1 files load with no locks; an older build sets a version 2 file aside (`_read_json_version(..., 2, 1)`). `_read_json` (only world_items used it) is deleted.
- `test_item_instances.gd` checked `PROTOCOL_VERSION == 106`; now `>= 106` (4a will meet the same line).

## Numbers chosen (s5 tuning, playtest)
| Row | Slots / kg | Footprint m | Cost (hammer tier) | Takes |
|---|---|---|---|---|
| Large wooden chest | 30 / 350 (Ornate 250) | 1.4 x 0.8 | 14 Hardwood board, 20 nails, 2 hinges (1) | anything; lockable |
| Wardrobe | 16 / 80 | 1.2 x 0.6 | 8 boards, 12 nails, 2 hinges (1) | clothing, gear |
| Dresser | 12 / 50 | 1.0 x 0.5 | 6 boards, 12 nails (1) | anything |
| Bookcase | 12 / 40 | 1.0 x 0.35 | 6 boards, 10 nails (1) | anything (no book rows exist) |
| Apothecary cabinet | 16 / 30 | 0.8 x 0.4 | 4 boards, 8 nails, 2 hinges (1) | medicine, four teas |
| Bottle and jar rack | 12 / 60 | 1.2 x 0.35 | 4 boards, 8 nails (1) | containers, plum jam, preserved damsons |
| Tool cabinet | 16 / 80 | 1.0 x 0.4 | 6 boards, 12 nails, 2 hinges (1) | tools, nails, hinges |
| Open storage bin | 8 / 300 | 1.0 x 1.0 | 6 Planks, 8 wooden pins (1) | stone, flint, clay, sand, gravel, soil, charcoal, coal, ores, cobblestone |
| Firewood rack | 10 / 300 | 2.0 x 0.8 | 2 logs, 10 sticks, 2 twine (1) | firewood (both) |
| Log rack | 6 / 900 | 3.0 x 1.2 | 4 logs, 4 twine (1) | any log |
| Board rack | 10 / 500 | 2.4 x 0.8 | 2 logs, 4 Planks, 8 pins (1) | Planks, Hardwood boards (kept apart: separate ids) |
| Mason's pallet | 8 / 800 | 1.2 x 1.2 | 6 Planks, 12 pins (1) | stone, cut and carved blocks, brick, cobblestone, shingles, roof tile |
| Ore and metal rack | 10 / 400 | 1.6 x 0.8 | 6 boards, 12 nails, 2 iron bands (1) | ores, ingots, iron band, nails, hinges |
| Storage sign | view 8 m | 0.6 x 0.1 | 2 Planks, 1 stick, 1 charcoal (1) | - |
| Warehouse crate | 20 / 500 (Crate 10 / 80) | 1.0 x 1.0 | 8 boards, 16 nails, 4 iron bands (3) | anything; lockable |
| Warehouse desk | view 16 m | 1.4 x 0.8 | 8 boards, 12 nails (1) | - |
place_mult: 0.6 closed furniture and crates, 0.8 open shelves and tool cabinet, 1.0 yard racks and bins (as the existing rows).

## Placeholders (NOT visually complete)
- Looks: each row borrows an existing builder (`look_table.gd`, `shortcut:` comment); no fill states.
- The lock window and the storage window (`src/client/ui/inventory/storage_dialogs.gd`) are plain panels in the inventory colours (`shortcut:`), not the INVENTORY_CRAFTING_LOOK.md style. The chest window gains a Lock button for the owner.

## Evidence (Dave's PC, voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe`, guarded runner, 3 jobs)
- Full plan `python3 tools/tests_for_diff.py f3d0d2ac0 HEAD` (339 fast + 8 timing; the protocol bump selects every fast test), run at `49de69535`: **341 PASS, 6 FAIL** of 347.
  - 4 caused by this change, fixed in `be3d8c9df` and rerun there alone: `test_blueprints` (live blueprint count 192 -> 208), `test_hammer_list` (wooden-hammer rows 142 -> 157), `test_look_table` (the bin's borrowed barrel look was over the 300-triangle cap; now the crate look), `test_chest_column` (its stand-in view has no `_storage_ui`). All 4 PASS at `be3d8c9df`.
  - 2 known flakes, not attributed: `test_npc_view` prints PASS then segfaults at quit (exit 139; T04 and T10 records, loads no changed file; also crashed when rerun alone here); `test_flora_density` timed out at 300 s under the full-run load (known, T07 brief). Base `f3d0d2ac0` was NOT rerun here; the dev record for `5285e2e20` is 344/346 with 2 flakes.
  - Note: the 4 fixes were edited into the working tree while the full run was still going, so tests that started late in that run read some of them; every test that loads a fixed file was rerun at `be3d8c9df`.
- At `be3d8c9df`: `test_storage_locks` PASS (69 checks), `validate_items` PASS (0 errors), `test_blueprints`, `test_hammer_list`, `test_look_table`, `test_chest_column` PASS.
- Static at `be3d8c9df`: `merge_check.py` all clear (its one warning, recipe 153 water wheel over the carry cap, is from before this task), `catalog_ledger.py --check` exit 0, `check_look_names.py` all 236 looks drawable.
- `/ponytail-review` self-check on `f3d0d2ac0..be3d8c9df`: no must-fix; one unmeasured scale risk recorded as a `shortcut:` (view scan); findings fixed in `be3d8c9df` were the test counts above.
- NOT RUN: the client windows in a running game (no client UI test exists for them), startup smoke, two real network clients.

## Not done
- Movable loaded crates, cargo ageing in transit (Phase 10).
- The owner cannot name players to let in (the server knows only character keys, not names): "let in the player beside it" and a count of others with access.
- No client UI test; the windows were not opened in a running game.

## Evidence at `60f9b4027` (clean run: no edits during it; `git rev-parse HEAD` the same before and after, no tracked changes; voxel build, guarded runner, 3 jobs)
- Plan `python3 tools/tests_for_diff.py dd903d971 HEAD` (dev's tree; `fefee0aa2` itself is not in this clone): 340 fast + 8 timing. `run_tests.sh --jobs 3`: **347 PASS, 1 FAIL** of 348. The one: `test_flora_density` timed out at 300 s under full-run load (known flake; loads no T13 file). `test_npc_view` passed this time.
- `validate_items` PASS, `test_storage_locks` PASS (76 checks, including the round-1 tests; its Stack-to-nearby check fails with the `_box_takes` line removed: negative control run at `0bfec1b95`'s working tree, then restored), `merge_check.py` all clear (its carry_audit warning, recipe 153 water wheel, predates T13), `catalog_ledger.py --check` exit 0.
- Logs: `C:\Users\david\AppData\Local\Temp\claude\01b3e68161e49208\35a61d07-6ae9-47de-b88c-fe7400bb03ef\scratchpad\p9\run_60f9b4027ull_run.log` (summary), `...ull\*.out` and `*.result` per test, `...\checks\` (validate_items, test_storage_locks), `...\merge_check.log`, `...\ledger_check.log`, `...\head.txt` (head before and after), `...\plan.json`.
- Merge: conflicts only in `PROTOCOL.md` and `terrain_net.gd`'s PROTOCOL_VERSION line (both notes kept, 108 then 107). `test_blueprints` and `test_hammer_list` counts were unchanged by dev (4a adds no blueprints); `test_item_instances` keeps `>= 106`.

## Review round 1 (FAIL on evidence; code PASS WITH NOTES) and the fixes
- A damaged or unusable lock row on a container with an owner now loads **fail-closed**: an empty-code lock only the owner passes (no code can match); the owner sets a new code or takes the lock off. An ownerless container with a damaged row loads unlocked (nobody could ever open it otherwise). Test: `test_storage_locks` section 13.
- New tests (section 12): hammer-repair sourcing (`_boxes_near`) skips a locked chest for a stranger and uses it for its owner; `_push_box` reaches the owner and not a stranger who had the chest open; Store all keeps what the container does not take; Stack to nearby.
- Stack to nearby now also applies `_box_takes`. Negative control: with that check removed, the new test fails ("rack 3").
- world_items.json stays version 2: an older build sets a version 2 file aside as `.bad` and does not misread it (so it does not load those locks unlocked); this build reads version 1 files.

## Residual risks
- **Character keys come from the client** (`hello(player_key)`): a scripted client can present a fresh key per try and get a fresh wait each time. This is a wider authentication question for Dave, not a lock bug. No per-container cap was added, because one would let strangers lock an owner's friends out by failing on purpose.
- The `tries` list grows by one entry per failing key per container (a right code removes that key's entry; failures are never pruned, since a count must survive its deadline). Small per key, unbounded under the scripted-key abuse above.
- A player with the code (or let in) can empty a locked chest and then take it down: s4.8 / the s3.13 reconciliation default lets "the owner or a player with access" lift or take down a locked container.
- The first player to open a container with no owner becomes its owner (8 Nov 2026 rule) and can then lock it. New game: every container is owned from placement, so only containers from older saves have no owner.
## Other risks
- Unmeasured: each view action scans all world records once (`shortcut:` comment).
- Playtest worlds from before load (version 1 world_items reads), but a 108 server refuses older clients.
- A four-digit code is a game lock, not security: the save holds a salted hash of a 10 000-value space.
