# Task handoff — DEVTEST-01 (spend the lowest group member first)
- Task, role, session: `systems-engineer` (temporary agent, 11 Nov 2026, retired after this file was saved). Status: **COMPLETE** (coordinator: committed as `1726dc29d`, independent review PASS in `REVIEW_1.md`, results and smoke in `RESULTS.md`). The text below is the engineer's, written before the commit.
- Code: base SHA `be491ba638610f23761d43be78787179c48e58fe` (= `origin/dev` = `origin/main` per the brief); branch `claude/project-thread-918v74`, no commit made (coordinator commits); no PR. Changed files below. Dave's pre-existing `.import` / `project.godot` changes untouched.
- Design authority: FINAL_HANDOFF_REPORT_11Nov.md §9.1 (approved "spend the lowest group member first"); coordinator decision 10 Nov 2026 (`_refund_number` ranking: tier, then `REFUND_MATERIALS`, then value, missing ranks last, full tie keeps group order); building on the spot (Dave 2 Nov 2026, source priority unchanged). Library files `design/decisions_pending.md` and `handoffs/Steve_handoff_11Nov.md`: not reachable, SOURCE UNVERIFIED for anything beyond the brief. No design decision was needed: ranking rule, source priority and `PROTOCOL.md` are untouched.

## Root cause
`Inventory.remove_fill` spent "the id itself first, then the group members in group order" (nails group `[nails, bronze_nails]`: iron first) while the refund gives back the lowest member, so build then take-down turned iron into bronze. The ground-stock, craft-stock and site-gather takes had the same flaw by taking any member stack in nearest-first or world order.

## What changed (one ordering, reused)
- `src/shared/item_table.gd:95-117`: new `SPEND_MATERIALS` (the old `REFUND_MATERIALS` list, moved) and `spend_order(number)`: the group's members lowest first (tier, material, value, then group index so a full tie keeps the group's own order). `[]` for a non-group. Placed in the shared `ItemTable` because it already owns `group_members`, `entry`, `id_of`; the Inventory (client and server, `table` is always the `ItemTable`, which has tier/material/value) and the server both reach it. This file is outside the brief's list; reason recorded here.
- `src/shared/inventory.gd:152-172` `remove_fill`: iterates `spend_order` (falls back to `fills_of` for a non-group or a table without it). Covers pack, chests (`box.remove_fill`), crafting (`recipe_table.craft`, `_stock_take`, `_start_deferred`), building (`_pay_blueprint`), site deposit/gather, repair, dead kit. `fills_of`/`count_fill` unchanged (membership only).
- `src/stream/server_items.gd`: `_refund_number` (~8002) is now `spend_order(number)[0]` (old key code and static `_rank_below` deleted, nothing else used them). New `_spend_sorted(rows, number, member_of)` (~8009): stable positional sort of loose stacks by `spend_order` index, nearest-first kept inside a member; a row with `member_of` 0 (a chest in `_gather_site`) keeps its place so the source order is unchanged. Used in `_ground_stock` (~7610, building on the spot), `_ground_take` (~7964, repair and site deposit), `_gather_site` (~8200) and `_stock_take` (ground part of crafting and blueprint stock). It is applied in `_stock_take`, not `_craft_ground`, so the counting path (`_stock_have`, hammer list) does not sort.
- Tests: `src/worldgen/tools/test_build_stock.gd` new `_check_spend_lowest` (call at line 114, placed before `_check_group_refund`, which erases the real nails group); `src/worldgen/tools/test_ingredient_groups.gd` new mixed-tier, nails, exact-id, no-group, tie and craft-queue checks. One existing check changed on purpose: "taking 4 logs takes the oak first, then one spruce" now expects spruce first (value 32 < oak 48), the intended new order.
- Observable in game: build a nails piece with iron Nails and Bronze nails in the pack: Bronze nails go first, the pack keeps iron; take-down returns Bronze nails.

## Evidence (this PC, Godot 4.7.2 console build for single tests; voxel editor build for the plan)
All outputs under `C:\Users\david\AppData\Local\Temp\claude\01b3e68161e49208\4e34633a-7989-4835-8cc3-c3c5cfecc59f\scratchpad\devtest01\` (below `scratchpad`: `<dir>`).
- `tools/run_one_test.sh test_build_stock 300` and `test_ingredient_groups 300` (`GODOT_EXE=/c/GodotInstaller/Godot_v4.7.2-stable_win64_console.exe`): both PASS (0 failures), `<dir>\run3\`.
- Tests fail without the fix: with `remove_fill` back on group order and `_spend_sorted` turned into a no-op, 8 new/changed checks in test_build_stock and 7 in test_ingredient_groups FAIL (`<dir>\run_prefix\`); with only the `_stock_take` ground sort removed, the new craft-stock-ground check fails (`<dir>\run_prefix2\`). Source restored byte-identical afterwards.
- Affected set: `python tools/tests_for_diff.py --paths src/shared/inventory.gd src/shared/item_table.gd src/stream/server_items.gd src/worldgen/tools/test_build_stock.gd src/worldgen/tools/test_ingredient_groups.gd` -> `<dir>\affected_final.json` (class code, 178 fast + 4 timing, 0 slow, check `validate_items`). Run: `GODOT_EXE=/c/GodotInstaller/godot.windows.editor.x86_64.exe tools/run_tests.sh --jobs 3 --plan <dir>\affected_final.json --out <dir>\full2` -> **182 pass, 0 fail**, 0 skipped, 0 retries/flakes (`<dir>\full2_summary.txt`, `<dir>\full2\retries.log` empty), wall 220 s. Includes `test_server_items` and the other crafting and building tests.
- `validate_items` (console build): PASS, 0 errors, 135 warnings (`<dir>\validate\validate_items.out`).
- An earlier full run on a slightly earlier revision of the same change (sorting inside `_craft_ground`) was stopped by me after about 19 tests (I stopped the `run_tests.sh`/`xargs` shell, not Godot); its partial results in `<dir>\full\` are not evidence and were superseded by `full2`.

## What did NOT run / unverified
- No in-game or multiplayer manual check (cloud-forbidden, no visuals involved); no timing measurement of the new sort (cost judged small, unmeasured: `spend_order` is a sort of at most 26 members, run per group ingredient per take, not per count).
- Gate-reviewer verdict and merge: not mine.

## Known risks and open points for the coordinator
1. Log group behaviour changes visibly beyond nails: a `log` cost now spends plain log (value 4) first, then cheaper species (value 24, 32) before oak/beech/maple (48). That is the approved ranking applied to every group ("every group spend"), but Dave may notice it. Also applies to wooden blocks, knives, fuel, fish, fruit and the other 15 groups.
2. `_pull_nearby_logs` (shoulder/ground logs pulled into the pack for a `log` cost) is a separate "move" rule, not a pay path; unchanged. It pulls the nearest ground logs first, then the pack spends its lowest. Not touched (level B/C if Dave wants ground logs ranked too).
3. Between sources only each source is ordered; across `_gather_site` ground stacks and chests the old nearest-first interleave is kept (ground stacks swap places among the positions ground stacks already held). Containers: each chest spends its own lowest first, chests stay nearest-first (source priority as today).
4. Refund still gives back only the single lowest member (unchanged); a cost paid partly with a higher member still refunds the lowest (existing, recorded design: "we do not record which member was used").

## Ponytail review (`.claude/skills/ponytail-review/SKILL.md` applied to this diff, head SHA base `be491ba6`, uncommitted)
What this change does: one shared ranking (`ItemTable.spend_order`) now decides both the refund and every spend of a group ingredient.
- Should fix, `server_items.gd:8200` (`_gather_site` lambda is a dense one-liner). Answer: kept; splitting it adds a helper for one use; behaviour covered by the site-gather test.
- Should fix (scale), first version sorted inside `_craft_ground`, which `_stock_have` calls for every blueprint row on each stock send. Answer: fixed; the sort now lives in `_stock_take` only.
- Missing test, ground stacks 4 to 12 m (craft stock) not covered at first. Answer: added; verified to fail without the sort.
- Bug check, shared-code caller list: `recipe_table.craft` (client-possible), `_start_deferred`, `place_item` dead kit, repair, deposit, gather, `_stock_take` all go through `Inventory.remove_fill` or `_spend_sorted`; `inventory_view` and `recipe_list` only count (`count_fill`). No finding.
- Lean: old `REFUND_MATERIALS` and `_rank_below` deleted (replaced code); net +62 lines in sources, one list not duplicated.
- Nice to have: memoize `spend_order` per group. Skipped: unmeasured, no need.
- Findings: none open. Not checked: PC play test, timing, gate.

## Attempts that failed
My first new test ran after `_check_group_refund`, which replaces the real nails group with a stand-in and erases it, so the real group was gone (fixed by calling mine before it).

## Next action for a fresh agent / coordinator
Review the diff (`git diff -- src/shared src/stream src/worldgen/tools`), commit only those five files, run the gate-reviewer, re-run `tools/tests_for_diff.py` against the committed diff, merge to `dev` only after the gates pass.

## Docs updated
This file only. Library sync: SYNC PENDING (coordinator). Independent reviewer / integration status: not reviewed.
