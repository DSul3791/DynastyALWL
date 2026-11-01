# Handoff: Kathleen (art and looks), written 2026-11-01

## Role
I own the ART side of DynastyALWL (Godot 4.7, GDScript): the looks of items, tools, weapons, armour, food, kits, furniture, structures, fauna, flora model fixes. Not mine: item data, recipes and balance (Sal); server, structures and lit-fixture light code (Tyler); flora placement, densities and foliage shader (the flora session); water, body and camera including stance (Sonny). Branch: `kathleen-art` (pushed to origin). Never merge into the daily branch (DailyDev_20261029) myself; the moderator does that. After a batch, send the moderator an "approved to merge" note (branch, commit, tests, risks).

## Method
Research, block out, render several angles, give an honest 1 to 5 rating (5 = clearly real at 10 and 30 m), revise, check in the real game when possible, keep models cheap. Pictures and a README go in `art/CRITIQUES/<item>_<date>/`. Never hand Dave pictures in chat: every picture he should review is ONE card on the QA page (qa branch, worktree `C:/GodotProjects/DynastyALWL_qa`, pull first): copy the picture to `questions/img/<name>.png`, append to `questions/QUESTIONS.md` a block `## pic-<id> | Question?` / `Image: ...` / `Note: ...` / `- Yes` / `- No`, commit and `git push origin qa`.

## Done and pushed (kathleen-art, latest 38a51028; the daily 27dfe828 contains it up to 27833d45)
- Lean-to: long roof (ridge 1.5 m at z 0.4, back at ground z -1.7, about 35 degrees), sloped roof collider, test `test_leanto_collider`.
- Lit fixtures (fireplace, torch, chandelier) client look; fireplace front rated 4.5.
- Tall-grass panicle tips and far cue (flora rated 4.5 at 10 m).
- Meadow flowers round 3 (flora rated 4/5 at 10 m, 3.5 at 15 m); round apples (`_round_fruit`); crown variety (`_crown_variety`: colour spread, elliptical and leaning crowns, 1 in 8 dying, 1 in 20 mostly dead).
- Fibre cloth look, chopping block, ten distinct kit looks (BasicLook ART_OVERRIDES), larger hands (ragdoll_body.gd).
- Felled trunk, stump and log bark in the real game (27833d45): shader `lift` (vec3) in flora_view.gd BARK_SHADER, set to (3.0, 2.0, 1.3) in inventory_view.gd `_felled_bark`; softwood tint fallback. Cause was missing warm baked shading, not a missing material. QA card pic-felled-bark-after posted (stump and log block brown, rated 3.5).
- QA cards posted: pic-orchard, pic-fibre-cloth, pic-kits, pic-hands, pic-meadow-flowers, pic-apples, pic-crown-variety, pic-fireplace-light, pic-orchard-real, pic-felled-bark-after, pic-hold-stone-axe.

## In flight / unfinished (exact next steps)
1. Lying trunk after the final bark fix: NOT shot. `art/playthrough/rig.sh --item stone_axe --client-arg --shot-fell=flat --wait 120 --settle 20 --out <dir> --name fell` (wrap with `bash tools/godot_slot.sh ...`). The last run (art/CRITIQUES/nov1_checks/fell/) failed: every picture is the "Joining the game" screen (ground took 71 s). Rerun on a quiet machine, then card.
2. Cut logs (`src/client/log_look.gd`) are still plain blocks; give them the bark shader on the sides and a pale cut face with ring (same lift). Stump side still reads smooth.
3. Held stone axe card posted (rated 3): head is pale grey-white and blocky; consider a darker, chipped stone head. Held pose is stance (Sonny).
4. Orchard and crown close-ups in game (eye height inside a crown gives a leaf wall; shoot from about 15 m north of the orchard at 53376,68506 yaw 180).

## Open bugs and risks
- Orchard fruit is sparse from eye height; crown variety rated 3 to 3.5, render only in some views.
- Flame tips still pale cream (Tyler's code). Thatch seen from behind reads as paper triangles (idea: second offset layer).
- Rig quirks: ground south of z about 68430 may be unloaded; rig shots take 4 to 10 minutes and need a quiet PC; `crash_reports/` is tracked after merges, do not commit changes to it (`git checkout -- crash_reports`). If a merge refuses because untracked `crash_reports/telemetry_client.log` would be overwritten, move the folder away first.

## Tests (run from the repo root, headless, the voxel build `C:/GodotInstaller/godot.windows.editor.x86_64.exe` (the standard exe is `Godot_v4.7.2-stable_win64_console.exe`))
`godot --headless --path . --script res://src/worldgen/tools/<name>.gd` for: test_leanto_collider, test_item_looks, test_look_table, test_structure_looks, test_tool_looks, test_flora_budget (0 over budget; 27 at ceiling), test_fruit_share, test_season_fruit, test_trunk_cutting. All passed on 2026-10-31 after the daily merge. Heavy Godot jobs (rig, renders) through `tools/godot_slot.sh`, at most 3 at once. Offline photography: `tools/shot_node.gd` with view scripts (piece_view, leanto_scene, flora_model_view --variants=N, item_sheet, lit_view, fruit_close, trunk_view).

## Read first
`art/ITEM_ART_STATUS.md` (queued checks), `art/ART_TASKS.md`, `art/CRITIQUES/*/README.md` (ratings and reasoning per item), `art/playthrough/RIG_PLACE.md`, `src/client/basic_look.gd` (ART_OVERRIDES), `src/client/building_look.gd`, `src/flora/tree_builder.gd`, `src/flora/flora_view.gd` (shaders), `art/CRITIQUES/kits_2026-10-31/README.md` (stance notes for Sonny).

## Decisions from Dave not to re-litigate
Pictures only via QA cards, one item per card. Crab apples are green, orchard apples round and red. Trees must not all look the same (variety). The lean-to has a long sloped roof. Never merge to main; I do not merge to the daily.

## Skipped or not verified
Not seen in the real game: long-roof lean-to with bed, the ten kits, larger hands, fibre cloth, white (yarrow, chamomile) and pink (valerian) meadow drifts, the lying trunk after the final fix. Not modelled: log cabin set piece, woven texture on fibre cloth, furniture rows in structures.json (Tyler/Sal).

## Next tasks I would have done
Cut-log bark look; stump bark ridges; darker stone axe head; real-game pass for lean-to, kits, hands, fibre cloth (one card each); then fix the worst three pictures in `art/playthrough` rated 1 to 3.

## Update 2026-11-01: stump rule from Dave
Chopping a stump still in the ground just chops it up: it disappears and gives firewood and kindling, no fallen log. Models therefore now UNNEEDED: felled-stump and chopped-pieces models (the stump_chop / stump_gone pictures of `--shot-fell`, any "chopped stump" look). `_make_felled(false, ...)` (the standing stump) is still used. The felled-trunk look only matters for trees that really fall. Do not spend more shots on stump chopping.
Firewood and kindling looks exist but are plain: `data/items/looks.json` firewood (bundle #8a5e36), firewood_soft (bundle #9a7a4a), kindling (bundle #a8845a, size 0.6); the world drop of firewood is a split stick in inventory_view.gd (~line 2533). They have not been checked in game or improved; this is item 6 of SCOPE_KATHLEEN.md.
Stopped on Dave's order: the lying-trunk shot (`--shot-fell=flat`) was killed mid-run; no tests were running. To re-run after RESTART: the fell shot, then the tests listed above.
