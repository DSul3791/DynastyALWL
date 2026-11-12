# M001-T17 results: Phase 10, the Handcart and loaded crates as cargo

Branch `m001/p10` (clone `E:\Software\godotDev\m001_p10`), base `b6ccb3c53`. Code under test: **`5c692c013`** (`529f1aeeb` plus two warning fixes: the cart yaw keeps its fraction with `fposmod`, an unused parameter dropped; the commit after it changes only this file). Brief: `T17_BRIEF.md`. Owner: systems-engineer agent, 12 Nov 2026. Machine: Dave's PC, voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe`, headless, through `tools/run_one_test.sh` / `tools/run_tests.sh` (slot lock). Review: pending (independent gate-reviewer).

## Entity design (`src/stream/server_carts.gd`, a helper the items module owns, as `server_traps.gd`)
- **The cart is a placed structure** (structure state 290, kind `handcart`) with slots: its own cargo store is a `chests.json` entry by uid like any container, so open, put, take, Take all, Store all, sort and saving are the chest code, unchanged. structures.json `vehicle` holds its numbers. No kit item (s3.11 RECOMMEND).
- **One controller, the player as puller** (s3.11 RECOMMEND): `ACT_CART b=0` takes the handle; one handle per cart and one cart per player. Each position report of the puller (about 5 a second) moves the cart on the server toward the point `hitch_m` from them on the line back to the cart: it swings in behind like a towed trailer (wide turns) and is pushed when walked into. Nothing runs for a cart nobody pulls (one dictionary look-up per position report; no tick work).
- **Authority:** the cart moves at most its pace x `pace_slack` x elapsed time, so a client cannot drag it faster; the client caps its own walk at the pace (`cart_pull`). Refused moves: no ground, a grade over `slope_max` (unless it is no steeper than where it stands), water deeper than `water_max_m`, a wall or heavy station (`structure_blocks`) or a tree trunk (`trunks_near`). When the cart cannot follow and the puller is more than `slack_m` past the handle, the handle slips and the cart parks, with the reason. Letting go, disconnecting (`peer_left`) and dying (the next report is far away) park it the same way.
- **Speed penalty from data:** pace = `speed_mps` x (1 - `load_slow` x load share) x (1 - `slope_slow` x grade/slope_max) x `rough[ground material]`; sent when it changes by 0.1 m/s. Pulling adds `pull_effort` x load share to the puller's exertion while moving.
- **Loaded crates** (structures.json `cargo`: Crate 850 and Warehouse crate): `b=2` lifts a crate onto the nearest standing cart within `load_reach_m` with a free crate spot; `b=3` sets it down beside the cart (sides, then behind, then in front; ground, shallow water, nothing standing there). The crate keeps its world record, uid, owner, lock and contents; it carries `struct.on` (the cart's uid) and `struct.spot` and rides at the spot. Nothing is converted or copied.
- **Locked-crate rule (s3.13 DELEGATED default):** `_may_access` before every lift and set-down; a cart carrying a locked crate is not pulled, and not taken apart, by a player without access. A player who entered the code keeps that access after the move (the lock rides in the struct).
- **Views:** a riding crate and the cart belong to no storage view (in transit); set down, the crate joins whatever view covers its new spot (views are location-derived, unchanged). So desk A drops it on lifting, desk B lists it after setting down.
- **Ageing in transit:** a riding crate ages at the cart's `place_mult` (`spoilage.json handcart 1.0`, open to the weather); the cart's own store too.
- **Payload:** the cart's `max_kg` (300) counts its store and every crate on it with the crate's own wood (its blueprint materials' weight) and contents; a crate that would pass it stays down; puts into the cart or a riding crate stop at the payload.
- **Taking a cart down (dismantle):** all or nothing on a copy of the pack first: its cargo and every blueprint part into the pack (slots and the carry limit), every crate on it set down whole; if anything does not fit, nothing happens ("Empty the handcart first" / "Make room in your pack first"). Nothing is ever dropped to despawn.
- **Conservation:** lifting, carting, setting down, saving mid-trip, disconnecting, two players grabbing (server order: the second is refused), two players lifting the same crate (the second sees it riding) and dismantling move references, never items.

## Wire and save (protocol 111; 110 is Phases 7-8's)
- `ACT_CART := 78` (b: 0 grab cart a, 1 let go, 2 lift crate a, 3 set crate a down). 75-77 left free for Phases 7-8: **check for a number clash at merge.**
- `cart_pull(id, pace_dms)` reliable; `items_moved(ids, positions, yaws)` unreliable_ordered to each player who knows the cart (the world sync also re-sends a structure row whose x/z moved, and its extra gains `on: true` for a riding crate). `PROTOCOL.md` rows and the 111 note.
- `world_items.json` **version 3**: structure rows gain index 18 (the uid of the cart a crate rides on, 0 none) and 19 (its spot). Versions 1 and 2 load (no crate on a cart); an older build sets a version 3 file aside (`_read_json_version`). A crate whose cart is missing at load is put on the ground. Pulling is never saved: after a restart every cart is parked.

## Numbers (s5 tuning for playtest)
| Row | Value |
|---|---|
| Handcart (state 290, blueprint 250, hammer 1, "Storage and shelter") | 6 Planks, 2 Wooden - Cart wheel, 1 Axle, 12 Wooden pins; 12 slots, payload 300 kg; footprint 1.2 x 2.0 m; 1 crate spot |
| Vehicle | hitch 1.7 m, slack 1.5 m, 3.2 m/s (walk speed), pace slack 1.3, load_slow 0.4, slope_max 0.36 (about 20 deg), slope_slow 0.5, water_max 0.5 m, fit 0.6 m, pull_effort 0.35, load reach 3 m; rough: rock/bare rock 0.65, stony soil 0.8, gravel 0.85, sand/beach sand 0.7, mud 0.55, peat 0.7, snow 0.6, volcanic ash 0.8 |
| Wooden - Cart wheel (recipe 700, Carpenter's bench = workbench 2, 30 s) | 2 Planks, 8 Wooden pins, 1 Iron band (7.5 kg in, the wheel weighs 6) |
| Axle (recipe 701, Carpenter's bench, 24 s) | 4 Planks, 1 Iron band (12.7 kg in, weighs 10) |
`recipes.json next_number` 702, `blueprints.json next_number` 251. Planks only (no Hardwood boards): the cart can be built in hardwood-free biomes (s3.11 RECOMMEND). Reinforced wagon wheel and every animal vehicle stay FUTURE-GATED.

## Looks: NOT visually complete
Handcart borrows the wooden trough builder (`look_table.gd`, `shortcut:` comment): no wheels, handles or visible crate fill. Wheel and axle are grey chunks (`look_placeholders.json`). Clients glide moved carts to each new place (`inventory_view._glide_tick`); no client-side prediction for the puller (the cart lags its puller by about one report).

## Client and controls
E at a cart takes the handle (F opens its store, hold E takes it apart); while pulling, E only lets go and the walk is capped at the pace. Hold E on a crate beside a cart lifts it on; on a riding crate, sets it down. `CONTROLS.md` rows.

## Evidence (voxel build, Dave's PC)
| Run | Result | Log |
|---|---|---|
| New `test_handcart` (62 checks, real server state; see its header) at `5c692c013` | PASS | `scratchpad\t17\after_fix\` |
| Negative control: `_may_access` removed from the lift (working tree, restored) | FAIL "a stranger cannot lift the locked crate onto the cart" (as wanted) | `scratchpad\t17\neg1\` |
| Full plan `tests_for_diff.py b6ccb3c53 HEAD` at `529f1aeeb` (344 fast + 8 timing; protocol bump selects every fast test), `run_tests.sh --jobs 3`, head the same before and after, no tracked edits during it | **350 PASS, 2 FAIL**: `test_npc_view` exit 139 after printing PASS (known exit crash), `test_flora_density` 300 s timeout under load (known) | `scratchpad\t17\full_529f1ae\` (`full_run.log`, `full\`, `plan.json`, `head_*.txt`) |
| `test_flora_density` alone at `5c692c013`, 700 s limit | PASS (379 s) | `scratchpad\t17\flora_alone\` |
| At `5c692c013` (only server_carts.gd and one call line changed): `test_handcart`, `test_server_items`, `test_storage_locks` | PASS | `scratchpad\t17\after_fix\` |
| `validate_items` (checks lane, run explicitly; new vehicle and cargo rules) | PASS, 0 errors, 122 warnings (none new about errors; wheel and axle appear in the existing "no recipe uses them" list, as blueprint-only parts) | `scratchpad\t17\full_529f1ae\checks\` |
| `merge_check.py b6ccb3c53`, `catalog_ledger.py --check`, `check_look_names.py`, `check_controls.py` | all clear (carry_audit warning predates T17), exit 0, 237 looks drawable, ok | `full_529f1ae\merge_check.log`, `ledger_check.log` |
| `check_warnings.gd` (debug) | at `529f1aeeb`: 2 warnings in server_carts.gd (unused parameter, `posmod` narrowing; both fixed in `5c692c013`), none on changed lines elsewhere; rerun at `5c692c013`: none in server_carts.gd or test_handcart.gd (output not kept) | `full_529f1ae\warnings_raw.log` (the first run) |
| In-game look, feel of pulling, two real network clients, `items_moved` on a real client | NOT RUN | - |
Logs root: `C:\Users\david\AppData\Local\Temp\claude\01b3e68161e49208\35a61d07-6ae9-47de-b88c-fe7400bb03ef\scratchpad\t17\` (scratch, not kept by the repo). Updated tests: `test_blueprints` (211 live), `test_hammer_list` (160).

## Performance
`test_handcart`: 186 puller reports, **about 50-57 us each** on the server (test stand-ins for ground and water); about 0.3 ms a second per pulling player at 5 reports a second, plus one `items_moved` per report to each player who sees the cart. A parked cart costs nothing per tick; the per-report cost for everyone else is one dictionary look-up. Unmeasured: the real `ground_material` / `surface_height` / `water_depth_at` / `trunks_near` calls in a running world (5 to 7 per report).

## Self-review (`/ponytail-review` method), answered
- Fixed: a locked crate could be set down by a stranger by taking the cart apart (now refused; tested); a pulled cart rescanned every world record per report for its crates (now cached at grab); `posmod` truncated the cart's yaw to whole degrees (now `fposmod`).
- Accepted limits: the cart passes through chests, crates and other non-blocking pieces (only walls, heavy stations and trunks stop it); lifting picks the nearest cart even when it is full; no stacking of crates on the ground or a second crate spot.

## Not done
- Cart damage and repair (wheel, axle, frame), passengers, visible cargo, crate stacking on the cart or ground, narrow-path width beyond the 0.6 m fit, side-slope (roll), rain on open cargo.
- Client prediction of the puller's own cart; the look.
- Crate 850 ledger row stays NO CHANGE although its structures row gains `cargo` (ledger tracks item rows).

## Risks
- ACT number 78 and recipe numbers vs Phases 7-8 at merge; `gen_dishes.py` would hand out recipe numbers from `next_number` 702 (inside the 700-719 range).
- Character keys come from the client (T13 risk) apply to the cart's lock checks too.
- A crate on a cart ages faster than in a warehouse (1.0 against 0.6): by design (cart's place_mult), tuning.
