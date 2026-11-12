# M001-T13 brief: Phase 9 storage, locks and the Warehouse Desk

Mission 001, Phase 9 (`docs/design/CATALOG_IMPLEMENTATION_PLAN.md`). Owner: systems-engineer agent (data and code). Reviewer: independent gate-reviewer. Branch `m001/p9` in clone `E:\Software\godotDev\m001_p9` (base `f3d0d2ac0` = dev `5285e2e20` + state; Phase 3 furniture grades and chest families are in). New game: every container starts unlocked; a saved `owner` is kept.

Parallel work: Phase 6 cooking (m001_p6) edits food and cooking data/code; Phase 4a (m001_p4a) edits worn/warmth code. Keep to storage. JSON edits line-local (helper `C:\Users\david\AppData\Local\Temp\claude\01b3e68161e49208\35a61d07-6ae9-47de-b88c-fe7400bb03ef\scratchpad\jsonedit.py`). Your number ranges: structure states 260-279, blueprints 220-239, recipes from 450.

## Behaviour (master `docs/design/DYNASTY_MASTER_ITEMS.md` s3.13 and its reconciliation table, s7 item 19; companion `docs/design/STORAGE_WAREHOUSING_DESIGN.md` s2-s6, all DELEGATED defaults)
1. **Sixteen storage rows go live** (inactive rows: Large wooden chest, Wardrobe, Dresser, Bookcase, Apothecary cabinet, Bottle and jar rack, Tool cabinet, Open storage bin, Firewood rack, Log rack, Board rack, Mason's pallet, Ore and metal rack, Storage sign, Warehouse crate, Warehouse desk): structure rows with `slots`, `max_kg`, footprint and look, hammer blueprints from real materials (finished furniture in Hardwood boards per [D4]/[D5]; yard racks of logs/stone as fits), `place_mult` rows in `spoilage.json` for each container. Large Wooden Chest: more weight and a larger footprint within 30 slots ([D17]). Content restrictions per row where the design names them (a log rack takes logs) — keep them simple and data-driven.
2. **Ownership and access (s5 of the companion):** the existing saved `owner`; containers default open to anyone unless locked; **four-digit codes including leading zeros**; the owner opens without a code; authorized users; **progressive failed-attempt delays** (10/20/30/40 s) that survive reconnect and server restart; nobody but the owner sets or clears a lock. Access checks on open, on every transfer (take, put, take all, store all, bulk, craft sourcing from containers, NPC/station sourcing) and on take-down; a locked crate cannot be lifted or emptied by others ("locked-crate movement and sourcing rule").
3. **Storage sign and Warehouse Desk** are views over nearby containers (desk over sign): a combined inventory listing, search, deposit and withdraw that obey each container's lock and permissions; the desk's area is the delegated default radius; the desk shows only what this player may access.
4. Wire and save: lock state, codes (store safely; never send a code to other clients), authorized lists and attempt deadlines persist; `PROTOCOL.md` and a `PROTOCOL_VERSION` bump (coordinate: 4a takes 107, so take 108).
5. Movable loaded crates are Phase 10, not this task; leave a clean hook.
6. Looks: placeholders allowed if marked (NOT visually complete). Ledger rows updated; `catalog_ledger.py --check` passes.

## Rules
Work only in `E:\Software\godotDev\m001_p9`. Never touch `C:\GodotProjects\DynastyALWL` or other clones. Do not push. Godot only through the slot scripts with timeouts; never kill a Godot process you did not start. No catalog changes beyond the catalog text; report problems.

## Acceptance (voxel build)
- New tests asserting real server state, two players: direct access to an open container; owner sets a code `0042` (leading zeros) and opens without it; a stranger is refused, enters the code and gets in; wrong codes give 10/20/30/40 s waits that survive a reconnect and a restart; the owner authorizes a user; the desk lists only permitted contents and deposit/withdraw obey locks; no duplication or loss in any transfer; save/load keeps everything.
- `validate_items` PASS, `merge_check.py` clear, `python3 tools/tests_for_diff.py f3d0d2ac0 HEAD` with no new failures vs base.
- `/ponytail-review`; commit with `docs/ai-team/missions/M001/T13_RESULTS.md` (head SHA, counts, numbers, placeholders, risks).
