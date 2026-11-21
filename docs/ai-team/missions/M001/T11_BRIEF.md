# M001-T11 brief: Phase 4a clothing and armour layering model

Mission 001, Phase 4a (`docs/design/CATALOG_IMPLEMENTATION_PLAN.md`). Owner: systems-engineer agent. Reviewer: independent gate-reviewer. Branch `m001/p4a-layers` in clone `E:\Software\godotDev\m001_p4a` (base `dev` `b62db1e7c`, which has the Phase 1b instance data with worn slot arrays `[number, 1, wear, inst]`). New game: no old-save migration needed, but an old `characters.json` must still load safely.

Parallel work: Phase 2c (tools: T09 data, T10 code) edits `server_items.gd` tool wear/repair code and tool rows in `items.json`. Keep your server edits to the worn/clothing/warmth code and your data edits to clothing and armour rows, `clothing.json`, `worn.json`, `warmth.json`, so the branches merge.

## Behaviour (master `docs/design/DYNASTY_MASTER_ITEMS.md` s3.7 rules 1-2, s3.8 design 1-2 and the "Merged layer model" table, s3.9 for the strap and quiver slots, s4 and s8 notes)
1. Every clothing and armour row gets a `wear_layer` beside its existing `slot`, per the merged layer model: head base/mail/rigid; neck (new slot) single; body base/padding-or-mail/rigid/over/outer; legs base/mail/rigid; hands base/rigid; feet socks/footwear/over; back and waist single. Each slot-and-layer pair holds one item. A Dress (rows from s3.8, inactive until 4b) fills body base and legs base together (support the rule now with a `spans` field). `outer` is the body's outer layer, so a coat and a cloak cannot both be worn.
2. New worn slots appended at the end of `clothing.json slots` (s4/s8 and `CATALOG_SAVE_MIGRATION.md` rule 7): `neck`, and for Phase 5 the `shoulder`/strap and `quiver` slots if the carrying design needs them now (s3.9 rule: quiver at hip/waist coexisting with a backpack) — add only what has an item that uses it in Mission 001 and record the choice.
3. Equipping: putting on an item goes to its slot-and-layer; a different item already there is swapped back to the pack (never lost; a full pack refuses the swap). Taking off works per layer. The character screen / You column shows every worn layer and lets the player take each off.
4. **Warmth and protection combine with diminishing returns, never full stacking** (s3.7 rule 1, s3.8 design 2): replace the per-slot single insulation with a per-slot layered sum with diminishing returns (record the formula as s5 tuning). Protection values and damage modes are Phase 4b; leave a hook.
5. Per-material weather fields (s3.8 design 1; s7 item 14): add the fields the warmth code reads (e.g. wetness penalty for hide, wool warm when damp, linen cool, oilcloth rain resistance, fur too hot in heat) using the existing `warmth.json` soak / wind / wet machinery; numbers are tuning.
6. Wire and save: worn now carries several items per slot. Update the worn sync, `characters.json` save/load (an old one-item-per-slot array still loads into the base layer), PROTOCOL.md and `PROTOCOL_VERSION` (107).
7. Visual: the worn look (`worn.json` / `worn_look`) draws every worn layer it already knows; a missing look is a recorded placeholder, NOT visually complete.

## Rules
Work only in `E:\Software\godotDev\m001_p4a`. Never touch `C:\GodotProjects\DynastyALWL` or other clones. Do not push. Godot only through the slot scripts with timeouts (shared PC slot lock); never kill a Godot process you did not start. JSON edits line-local (helper `C:\Users\david\AppData\Local\Temp\claude\01b3e68161e49208\35a61d07-6ae9-47de-b88c-fe7400bb03ef\scratchpad\jsonedit.py`). Do not switch on new catalog rows (that is 4b) and do not invent items.

## Acceptance (voxel build `GODOT_EXE=/c/GodotInstaller/godot.windows.editor.x86_64.exe`)
- New tests asserting real server state: layered equip and unequip with conservation (nothing lost or duplicated, full-pack refusal); a coat and a cloak cannot both be worn; layering warmth with diminishing returns; per-material wet/heat effects; save/reload of several layers per slot; an old one-per-slot worn array loads; wire round trip.
- Existing worn/warmth/clothing tests updated to the new contract, not weakened; `python3 tools/tests_for_diff.py b62db1e7c HEAD` with no new failures; `validate_items` PASS; `merge_check.py` clear.
- `/ponytail-review` of your diff; commit with `docs/ai-team/missions/M001/T11_RESULTS.md` (head SHA, counts, formula and numbers, placeholders).
