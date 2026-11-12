# M001-T11 results: Phase 4a clothing and armour layering model

Branch `m001/p4a-layers`, base `dev` `b62db1e7c`. Code under test: **`0e237d0d5`**, the merge of `dev` `5285e2e20` (Phase 2c) and M001 state `f3d0d2ac0` into this branch (the commit after it changes only this file). Earlier rounds: `169ee26ff` (3), `31421c218` (2), `65ff75603` (1). Machine: Dave's PC `ManlandRyzen5`, clone `E:\Software\godotDev\m001_p4a`, voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe`, headless, through `tools/run_tests.sh` / `tools/run_one_test.sh` (slot lock, 3 jobs). Engineer: systems-engineer agent, 12 Nov 2026.

## Layer data model
- `items.json`: every clothing and armour row (33 live or retired, 32 inactive Phase 1 rows) has `wear_layer` beside `slot`, from the merged layer model (master s3.8), and a `fabric`. The three cloaks move from `slot: outer` to `slot: body, wear_layer: outer` (the model: `outer` is the body's outer layer). The inactive rows 951-981 and 1188 gain their `slot` too (they had none); Linen and Wool - Dress carry `spans: ["legs"]`. Gear rows (packs, quivers, belt) need no `wear_layer`: a row without one takes its slot's first layer. No row switched on, no row added.
- `clothing.json`: `slots` = the body slots an item may name (head, body, legs, feet, hands, back, waist, **neck** new); `layers` per slot inside to outside (head base/mail/rigid; neck base; body base/padding/mail/rigid/over/outer; legs base/mail/rigid; hands base/rigid; feet socks/footwear/over; back, waist base); `worn` = the 20 worn positions `"slot:layer"`, **append-only**, the first eight being the old eight slots (head:base, body:base, legs:base, feet:footwear, hands:base, back:base, body:outer, waist:base). `worn_labels` for the Tab screen. `body:mail` is the 20th position, appended after the first build (mission lead decision below).
- Hats (Straw, Fur, Broad-brim) are head `rigid`, so no hat goes over a helm (master table).
- **Mission lead decision (12 Nov):** the table's body "padding or mail" is two layers, padding inside mail, because s3.7 rule 1 puts a gambeson beneath other armour. Body `padding`: Gambeson, Leather - Jerkin; body `mail`: Mail shirt, Bronze - Scale shirt, Iron - Mail hauberk. So mail goes over a gambeson; a jerkin and a gambeson share one layer.
- **Strap and quiver slots not added (brief item 2):** no Mission 001 item uses them before Phase 5, which designs the belt attachment points (s3.9 recommended carry model). They will be appended to `worn` then; nothing here blocks them. Only `neck` (Wool - Scarf 981) was added.

## Behaviour (server `src/stream/server_items.gd`)
- ACT_WEAR: the piece goes to its own position. Every worn piece sharing a position with it comes off into the pack (`_covers`: its own position plus `spans`, so a Dress takes off the tunic and trousers, and trousers take off a Dress). Each needs a free pack slot (worn pieces never stack; the slot the new piece leaves counts): without room nothing moves and the player is told. ACT_UNWEAR a = a worn position; each layer comes off on its own (an inner layer may come off under an outer one).
- A coat and a cloak are both body outer: one position, never both.
- Old saves: `_clean_worn` reads any worn list by position; an old 8-column list lands each piece in its slot's base layer and the outer column in body outer. A piece whose own layer is another (a helm saved in the head column) moves to its own position when free; one that fits nowhere is left off with a warning (as before; no old-save migration needed, new game). **Accepted by the mission lead (12 Nov):** this differs from the master s3.8 line "old saves map each worn item to its slot's base layer", which would have put a helm in the hood's position; the outer column still maps to body outer as written.

## Warmth formula and numbers (`warmth.json layers`; s5 tuning, recorded in master s5)
- Per body slot, the worn pieces' warmth sorted largest first: `slot = w1 + k w2 + k^2 w3 ...`, `layer_keep` k = **0.6**. Slots add up, capped at `max_insulation` 0.85. Example: Hide tunic 0.24 + Gambeson 0.3 + Hide cloak 0.3 = 0.566 (sum 0.84). A full hide outfit (hood, tunic, cloak, trousers, boots, gloves) is 0.974, still capped at 0.85 as before; the camp goal `worn_warmth` uses the same dry layered sum.
- Fabric fields (`layers.fabrics`): `wet_keep` (share of warmth kept soaked through, linear in soak, before the body_703 wind strip), `breath`, `rain_shed`. plant 0.3/0.9/0.2, hide 0.4/0.3/0.2, leather 0.6/0.3/0.3, wool 0.75/0.5/0.1, linen 0.4/1.0/0, fur 0.5/0.1/0.3, oilcloth 0.9/0.1/0.7, padded 0.4/0.2/0, metal 1.0/0.6/0. Snowshoes have none (neutral).
- Heat: in air that feels warmer than `comfort_c`, heat load = layered `warmth x (1 - breath)` (capped 0.85); exertion += `heat_effort` **0.5** x load x min((feels - comfort_c) / `heat_span_c` **10**, 1). Fur cloak at 30 C: load 0.38, +0.19 exertion; linen shirt 0.
- Rain: the best body piece's `rain_shed` slows soaking and lowers the soak ceiling: an hour of rain soaks a bare body to 1.0, under an Oilcloth - Cloak to 0.3.
- **Before and after (FLAG FOR PLAYTEST TUNING).** Insulation from the data (before = the old sum capped at 0.85, no fabric effect; after = layered and fabric), and the warmth target at 5 C with no wind and no fire (`100 - (20 - 5) x (1 + 0.5 x soak) x 3 x (1 - insulation)`; the body_703 wind strip comes on top in wind):

| Outfit | Dry before | Dry after | Soaked before | Soaked after | Target dry, before / after | Target in heavy rain (soak 1), before / after |
|---|---|---|---|---|---|---|
| Fibre set (skirt, cloak, sandals) | 0.21 | 0.21 | 0.21 | 0.06 | 64 / 64 | 47 / 37 |
| Full hide set (hood, tunic, cloak, trousers, boots, gloves) | 0.85 | 0.85 | 0.85 | 0.39 | 93 / 93 | 90 / 59 |
| Wool and fur set (wool cap, tunic, trousers, mittens; fur cloak, boots) | 0.85 | 0.85 | 0.85 | 0.80 | 93 / 93 | 90 / 86 |

  Dry outfits are unchanged (they reach the cap either way). In rain, hide and fibre now lose most of their warmth while wool and fur keep it: the hide set in heavy rain at 5 C drops from 90 to 59 (still above `cold_at` 40). That is the intended s3.8 design 1 effect, but the size of the drop is a tuning number for Dave's playtest.
- The heat load reads the air less wind chill only; a fire's heat never makes clothing a heat load (review fix, round 3).
- A Dress counts its warmth once, in the body slot, though it also covers the legs: Phase 4b sets its warmth value with that in mind.
- Protection hook (Phase 4b): `_layered(values)` is the per-slot diminishing sum to reuse; no protection values exist yet.

## Wire and save (protocol 107)
- `worn(numbers, insts)`: one number per worn position (20), the instance block keyed by position index; shape unchanged from 106. `PROTOCOL_VERSION` 107, `PROTOCOL.md` table row and note, `terrain_net.gd` history and ACT_WEAR / ACT_UNWEAR comments.
- `characters.json worn`: one slot array `[number, 1, wear, inst]` per position. Older lists (8 columns, bare numbers or slot arrays) load as above.

## Client
- Tab screen (`character_screen.gd`): every worn layer on its own line with its own Take off, grouped by slot, "nothing" for a bare slot, and "Legs: covered by Linen - Dress" for a slot a spanning piece fills.
- You column (`you_column.gd`): each well shows its slot's outermost worn layer; the Outer well is body:outer and the Body well what is under it. Neck has no well: not added, because a sixth well on a side makes the column taller than the five-well layout was sized for (`you_column.gd` FIGURE 470 px against 5 x 96 px wells) and that needs a visual check; the neck layer shows on the Tab screen with its Take off. No live neck item exists until 4b.
- Tooltip: "Worn on the body, outer layer." Avatar colours: only body and legs base and feet footwear tint the body's own garment (a cloak now in the body slot does not recolour the tunic).
- Visual: `worn_look` draws every worn piece it has a row for, as before. **Placeholders, NOT visually complete:** 32 `worn.json` rows for the inactive Phase 1 rows (`"placeholder": true`, an existing builder and a colour): iron_brigandine, iron_breastplate, iron_mail_hauberk, steel_half_plate, steel_plate_harness, iron_mail_coif, iron_gauntlets, steel_gauntlets, bronze_greaves, iron_mail_chausses, iron_greaves, steel_greaves, iron_sabatons, steel_sabatons, linen_trousers, linen_skirt, linen_dress, wool_dress, wool_cloak, wool_coat, wool_robe, oilcloth_cloak, linen_apron, leather_apron, tabard, linen_headwrap, leather_broad_brim_hat, fur_mittens, leather_shoes, wool_socks, wool_scarf (drawn as a belt), riding_boots. Pieces of the same visual `layer` worn together in one slot (Hide tunic and Gambeson are both layer 2) may overlap: the art pass sets offsets.

## Tests
| Run | Result |
|---|---|
| New `test_clothing_layers` (36 checks: model and positions, layered equip and per-layer take-off with conservation, same-layer swap, coat vs cloak, Dress span both ways, full-pack refusal of wear and take-off and the one-for-one swap, layered warmth numbers, camp goal, wet hide vs wool, fur heat load and exertion, linen none, cool air none, oilcloth rain, wire numbers and position-keyed instance data, save and reload of 5 layers with wear and data, old 8-column list incl. a helm in the head column, an old characters.json) at `65ff75603` | PASS |
| `tests_for_diff.py b62db1e7c HEAD` plan (337 fast + 8 timing), `run_tests.sh --jobs 3` at `c1109bb1e` | 342 pass, 3 fail |
| `test_item_instances`: pinned `PROTOCOL_VERSION == 106`; now `>= 106` (as test_bulk_ops / test_hotbar_keys), rerun at `65ff75603` | PASS (77 checks) |
| `test_npc_view`: exit 139 after printing PASS (the exit-race segfault T04 recorded at base `159b566`, 2 of 4 runs); rerun at `65ff75603` | 1 crash, 1 PASS. It loads worn.json (only placeholder rows added, no NPC outfit uses them) |
| `test_flora_density`: 300 s timeout under 3-job load (timing lane, as in T04); rerun alone, 600 s limit | PASS (417 s) |
| `test_clothing_slots`, `test_you_column`, `test_warmth`, `test_save_compat`, `test_persistence_drills` (updated to the position contract) | PASS in the plan run |
| `validate_items` (run explicitly; plus a positive control: a bogus wear_layer is caught) | PASS at `65ff75603` |
| `check_look_names.py`, `catalog_ledger.py --check`, `merge_check.py` (base `b62db1e7c`) | PASS, PASS, all clear (its carry_audit warning is the same at base) |
| `check_warnings.sh` full: server_items.gd 9 (none in the changed lines; baseline file stale at 8), other changed files 0 new | PASS for this diff |
| **Round 2 at `31421c218`** (padding under mail, Tab screen Dress line): `test_clothing_layers` (38 checks, adds mail over gambeson and a scale shirt swap) | PASS |
| Round 2: `validate_items` | PASS |
| Round 2: `tests_for_diff.py 65f370dd2 HEAD` plan (337 fast + 8 timing), `run_tests.sh --jobs 3` | 343 pass, 2 fail: `test_npc_view` exit 139 after PASS and `test_flora_density` 300 s timeout, the same two known failures as round 1 (both passed on rerun there) |
| **Round 3 at `169ee26ff`** (fire heat excluded from the heat load; review notes): `test_clothing_layers` (40 checks, adds "hide outfit at a lit fire on a cold night: no heat load" and its hot-day positive control) | PASS |
| Round 3: `validate_items`, `test_item_instances`, `test_clothing_slots`, `test_you_column`, and every test reading the warmth target or exertion: `test_warmth`, `test_body_weather`, `test_bedroll`, `test_cave_climate`, `test_cave_shelter`, `test_comfort`, `test_fire_coals`, `test_sickness`, `test_water_pieces`, `test_goals`, `test_server_items` | 16 PASS |
| Round 3: full plan | NOT RUN (the change is in `warmth_target` and test/doc text; round 2's full plan at `31421c218` is the latest) |
| **Merged head `0e237d0d5`** (dev `5285e2e20` merged; one conflict, `terrain_net.gd` action comments: T11's ACT_WEAR / ACT_UNWEAR and 2c's ACT_REPAIR kept; PROTOCOL_VERSION 107, 2c kept 106): `tests_for_diff.py 5285e2e20 HEAD` plan (339 fast + 8 timing), `run_tests.sh --jobs 3` | 345 pass, 2 fail: `test_npc_view` exit 139 after printing `test_npc_view: PASS` (3 of 3 runs here; the exit-race crash T04 recorded, 8 of 8 at its head) and `test_flora_density` 300 s timeout under load (timing lane; passed alone in 417 s at round 1, not rerun alone here) |
| Merged head: `validate_items` | PASS |
| Merged head: `merge_check.py` (base `5285e2e20`), `catalog_ledger.py --check`, `check_look_names.py` | all clear (carry_audit warning as at base), PASS, PASS |
| In-game visual and multiplayer check | NOT RUN |

No new failures against base.

## Not done, risks for the reviewer
- No in-game visual check of the Tab screen, You column or layered looks (PC playtest).
- The heat load has no message: a player overdressed in heat tires faster without being told why.
- Taking off an inner layer under an outer one is allowed (no dressing order).
- `PROTOCOL_VERSION` 107 may collide with another branch bumping in parallel (2c): renumber at merge.
- `items.json` edits are inside clothing rows only; `server_items.gd` edits are the clothing/warmth section, `effort_of`, `_update_soak`, `warmth_target` and `_worn_warmth` (2c edits tool wear code).
