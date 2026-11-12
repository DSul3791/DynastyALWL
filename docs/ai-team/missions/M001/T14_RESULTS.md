# M001-T14 results: Phase 4b weapons, armour and clothing rows; protection by damage mode

Branch `m001/p4b`, base `dd903d971`. Code under test: **`9915c54c5`** (`d6ccf01db` the change, `9915c54c5` the client arrow-list mirror; the commit after it adds only this file). Machine: Dave's PC, clone `E:\Software\godotDev\m001_p4b`, voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe`, headless, through `tools/run_tests.sh` / `tools/run_one_test.sh` (slot lock, 3 jobs). Engineer: systems-engineer agent, 12 Nov 2026. Not pushed.

## What went live
- **77 Phase 4b ledger rows** (all IMPLEMENTED - UNVERIFIED, tests `test_armour`, `validate_items`): 24 weapon + 5 ammunition ADD rows (920-948), 14 armour ADD (951-964), 17 clothing ADD (965-981), the Q1 FUTURE rows 315-323, 326, 328-331, 838, and the renames 269 Shortbow, 763 Longbow (ids kept). Steel bolt 949, Iron - Lance 950 and Riding - Boots stay FUTURE.
- **Recipes 500-560** (next_number 561), all known: bronze at `forge`, iron and steel at `brick_forge` (Smithy), leather at `leatherworking_table`, linen/wool/fur/oilcloth at `tailors_table` (needle kept), Quarterstaff and Wooden bolt by hand, Light crossbow at the workbench (wood and sinew), Heavy crossbow at the Smithy (iron). The 14 locked FUTURE recipes are unlocked and known. Fixes: Bronze - Shield 206 = Wicker - Shield + Bronze ingot + Hide (no Planks); Mail shirt 218 and Steel - Cuirass 220 costs raised so a piece weighs no more than its materials (6 kg mail: 4 iron, 20 rivets, leather; 9 kg cuirass: 5 steel, heavy leather, 10 rivets); Steel - Sword 321 and Steel - Cuirass 331 descriptions (also in encyclopedia.json).
- **Tabard:** two recipes of the one Tabard row (`tabard` from Linen, `tabard_wool` from Wool cloth). **Deviation from the brief/s3.8 RECOMMEND:** ingredient groups are global by key item (`item_table.gd load_groups`), so a group keyed by Linen would let every Linen cost take Wool cloth (Linen - Shirt, trousers, dress from wool). Two recipes give the same player result with no side effect. Mission lead may overrule.
- **Oilcloth - Cloak:** Tailor's table, 10 Linen + 2 Lamp oil + Thread (the catalog's existing-oil route).
- Values: new cloth and some armour values raised so output is worth at least its inputs (family pattern; s5). Weights: T03's estimates kept (every recipe checked: inputs >= output kg).

## Protection and damage (`data/items/protection.json`; every number is s5 tuning)
- Per worn piece: `protect` {slashing, piercing, blunt, projectile} = share stopped on what it covers, `cover` = share of its slot. Per slot and mode: protect x cover x (1 - pen), largest first, each further layer x `layer_keep` 0.5 (`_layered`, now taking a keep), capped `slot_cap` 0.85; slots weighted by where blows land (head 0.12, neck 0.03, body 0.5, legs 0.2, hands 0.07, feet 0.08); total capped `cap` 0.75 (no immunity).
- Roles (s3.7 rule 3): leather light; gambeson blunt 0.35; mail slash 0.55 / blunt 0.12; breastplate cover 0.55 vs hauberk 0.95; steel plate highest. The 8 cross-listed hide/leather clothing rows get modest protect only (no durability).
- Examples (test): gambeson+mail+breastplate+cloak stops slash 0.318, pierce 0.218, blunt 0.225, projectile 0.255; full steel kit slash 0.745 (cap 0.75). Steel sword 22 / mace 20 bare; through mail 17.16 / 19.04. Wolf bite 8 through gambeson+mail: 6.72.
- Applied in `server_items.hurt_player` (wolves, big game, goblins); mode from `attack_modes` by species (bites/tusks pierce, claws slash, default blunt), or a passed weapon mode and pen. Falls, cold, hunger, sickness untouched.
- Weapons carry `damage_mode`, `pen`, `reach_m`, `recover_ms` (read by `_strike`); `weapon_blow()` gives damage+mode+pen. Ammunition is projectile.
- Wear: each hit adds round(damage x cover) to every protecting piece with durability; broken stays worn, stops nothing; mended off the body at its making station (leather 400, gambeson 300, bronze 800, iron 1500, steel 2500). Tempered steel armour: max_d x1.25 only, no edge or sharpness.
- Trade-offs: worn kg x 0.01 effort while moving (16 kg plate +0.16); heat from warmth/fabric (gambeson 0.24 heat load, plate 0.04). Crossbows shoot bolts only, reload 2.5 s / 5 s (`bow.json` pace_ms per row).

## Tests
| Run at | Result | Log |
|---|---|---|
| `test_armour` (new, 488 checks) at `d6ccf01db` | PASS | `scratchpad/t14/r1` |
| Positive control: layers summed without diminishing/cap | 9 FAIL (as intended), code restored | `scratchpad/t14/mut1` |
| `tests_for_diff.py dd903d971 HEAD` (191 fast + 4 timing), `run_tests.sh --jobs 3` at `d6ccf01db` | 194 pass, 1 fail: `test_slot_sounds` (client `BOW_AMMO` mirror) | `scratchpad/t14/full` |
| Same plan (192 + 4) at **`9915c54c5`** | **196 pass, 0 fail** | `scratchpad/t14/full2` |
| `validate_items` at `9915c54c5` | PASS (0 errors, 143 warnings; base 162, none new) | `scratchpad/t14/v3` |
| `merge_check.py` (base `dd903d971`), `catalog_ledger.py --check`, `check_look_names.py` | all clear (carry_audit warning as at base), PASS, PASS | |
| GDScript warnings (check_warnings.gd) | server_items.gd 9, all older lines; bow_aim, validate_items, test_armour 0 | `scratchpad/t14/warn_head.txt` |
| In-game visual, multiplayer, Tab screen | NOT RUN | |

(`scratchpad` = `C:\Users\david\AppData\Local\Temp\claude\01b3e68161e49208\35a61d07-6ae9-47de-b88c-fe7400bb03ef\scratchpad`.)

## Placeholders (NOT visually complete)
60 rows in `look_placeholders.json` now read "phase 4b, live: grey placeholder chunk"; armour and clothing worn looks are the T11 `worn.json` placeholder rows.

## Not done, risks
- No PvP or armed NPC exists: weapon modes and pen only matter on player hits through `hurt_player`; in play today only animal/goblin attack modes act.
- Two-handedness, dexterity (fur mittens, gauntlets) and noise: no existing system reads them; not added.
- Worn weight is not counted in the pack carry limit (Phase 5 owns carrying); only as effort.
- Worn wear is not sent to the client (seen only when taken off); break message says so.
- Encyclopedia has no entries for new rows and `obtainable_now` not recomputed (as in earlier phases).
- All numbers need playtest; armour changes wolf maiming odds.
