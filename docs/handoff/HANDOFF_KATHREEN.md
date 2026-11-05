# Handoff / backlog: Kathreen (art assistant), 1 Nov 2026, Phase 1 (no Godot)

> **CURRENT FLOW (fact check, 5 Nov 2026; supersedes the branch and merge lines below):** there is no daily branch: `DailyDev_20261029` was merged into `main` (PR #11, `a8c4d545`) and deleted on 1 Nov, so "the daily" below means `main`. Each agent cuts a new branch from `origin/main` each day and opens one pull request per job into `main`; agents never merge themselves. Tyler merges when CI is green and `tools/run_tests.sh` passes on the merged result. "Never merge to main" below means "never merge it yourself", not "never open a PR". Commit heads, test counts and "in the daily" claims below are as of the date in the title; `git log origin/main` and CI are the truth now. Priorities and job owners: `/mnt/project-files/BACKLOG.md`.

Branch `claude/kathree-art-20c939`. Scope: `SCOPE_KATHREEN.md`. Nothing here has been run: all Godot work waits for the moderator's PHASE 2.

## Done in Phase 1 (code by reading only, NOT run, NOT seen)
1. **Face details ported** (from `claude/kathleen-body-details` 73fcc818, `ragdoll_body.gd`): nose, brow, chin, ears, thumbs. Decision: PORT. Thumb offsets changed from x 0.036 to 0.052 (y -0.05, radii 0.014/0.038/0.014) because Kathleen's enlarged hand (radii 0.05/0.09/0.036) would hide the original thumb inside the hand. `shortcut:` comment in the file. Old branch can be deleted once this is merged.
2. **Yarrow and chamomile look** (`tree_builder.gd` `WILDFLOWER_LOOKS`): heads warm cream (1.0,0.96,0.84 and 1.0,0.98,0.9) instead of pure white (flora session: grey-blue in shade), per-flower `stem` colour (0.3,0.42,0.18) darker than `WILD_STEM` for these two only; other flowers unchanged (Kathleen's rating 4/5 stands). Tell Kathleen: she was informed; flowers are mine.

## Backlog (owner Kathreen unless stated; all need Phase 2 Godot)
| # | Item | Exact next step | Why not done |
|---|------|-----------------|--------------|
| 1 | Verify items 1 and 2 above | Phase 2: `tools/shot_node.gd` face/hand close-up (kathleen-body view script) and `flora_model_view` yarrow, then real game yarrow at 53302,68423 facing N and chamomile at 53326.7,68442.2 from S (default camera); one QA card each, rate honestly | needs Godot |
| 2 | Yarrow still glossy or faceted? | If after 1 heads still read grey/metallic: smoother upward normals for umbel clusters (`_cluster` last arg) and a matte stem (bark shader `lift`/rough in `flora_view.gd`, tell Kathleen) | cannot judge without picture |
| 3 | Creator preview | Phase 2: run `tools/proto_creator_view.gd`, confirm it faces front (Sonny `c41e2d21`), fix plain colours (`character_screen.gd` preview rig, `_preview_turn` line ~563), card `pic-fh-creator` retake | Godot |
| 4 | Water look | Read done (status doc). Phase 2: real-game pictures of river, lake, sea at 10/30 m, rate, fix colour/transparency/foam/shore in `water_material.gd`; ask Sonny for the flow channel and who applies the six-line patch; lava/swamp need an emission uniform | Godot; Sonny's protocol change |
| 5 | Ground PBR | DECISION: do not port now. Phase 2: picture the ground at 10/30 m with Kathleen; port `claude/kathleen-photoreal-batch1` / `claude/mike-pbr-ground` only if flat; check `CREDITS_PBR.csv` licences and draw cost with MikeW | needs a real picture to judge |
| 6 | Blueberry F-13 | Shoot at 53331.5,68359 N, agl 1.0, pitch -15, timeout over 280 s, with MikeW; card | Godot |
| 7 | Animal looks review | Rate every row in `data/animals/animals.json` at 10/30 m, fix weakest three; MikeW for shot placement | Godot |
| 8 | Character stance, grass/shrub pass | See SCOPE_KATHREEN.md steps 5 to 7 | Godot |

## Skipped or not verified
No code run, no parse check (GDScript edits are small, but a typo would only show in Godot: run `godot --headless --check-only` or the look tests first in Phase 2). No pictures seen. Thumb geometry is arithmetic. Water, creator, animals, ground untouched.

## Waiting on Kathreen (2026-11-01 evening)
All of it is on branch `claude/kathree-art-20c939` (head 20d82b8e, pushed, NOT merged, UNTESTED in Godot):
- `src/client/water_material.gd` `sea_slope`: crest modulation line (a5c239ae). Keep only if a sea picture at 54728,75530 (12 m up, yaw 180, pitch -18) is better; else revert that one line.
- `src/water2/water_traits.gd` `emission` look trait plus `"emission": 1.0` on lava in `water_kinds.json`. Run `src/water2/test_water_field.gd` (voxel build) before merging.
- Not written yet: the water look itself. Add the uniforms from `SHADER_INCLUDE` in `src/water2/water_flow_texture.gd` on branch `water-flow-channel` (`water2_tex`, `water2_origin`, `water2_size`, `water2_on` default 0, and `water2_at(world_xz)`) to `water_material.gd`, read depth/flow/foam (R/G,B/A) only when `water2_on` is 1; then an emission uniform and per-kind colours so lava glows and swamp is not grey. Needs Sonny's protocol flow channel (his backlog item 6) before it shows anything.
- Pictures still to retake: sea (above), river from the bank near 53302,68436 facing N, lower.
- Also open: `tools/proto_creator_view.gd` forces 20 degrees (should start at 180); ground PBR picture at 10/30 m; animals review; grass/shrub pass.

## Update after Phase 2 (1 Nov, pictures taken, QA cards pushed on qa 738e8ccf)
- Parse/look tests pass (test_flora_budget 0 over, test_look_table 0 failures); ragdoll_body.gd compiles and runs in the real game (body_right.png). NOTE: a fresh worktree needs `godot --headless --path . --import` once, else rigs fail with "AppConfig not declared".
- Yarrow 3.5, chamomile 3 (grey-blue speckle on white petals: fix = flat/smooth material for daisy and umbel heads in flora_view.gd, tell Kathleen; only if Dave says No), blueberry 3 (small bush behind grass), creator 3 (scene faces front; the "back" pictures came from tools/proto_creator_view.gd forcing 20 degrees: change to 180, one line, not done), body details 3. Cards: pic-yarrow-real, pic-chamomile-real, pic-blueberry-real, pic-creator-front, pic-body-details.
- Water look: sea baseline 3.5 (regular lattice), river shot missed (retake from the bank, e.g. 53302,68436 facing N lower, after the test pass). Prepared and UNTESTED: sea_slope crest modulation in water_material.gd (a5c239ae); retake sea.png at 54728,75530 and keep only if better. Sonny asked for flow channel and kind data (owner Sonny, next step his reply). Lava/swamp emission: Kathreen after Sonny.
- Not done: ground PBR picture with Kathleen (needs Godot, wait for test pass); animal looks review (read-only part not started); character stance pass; grass/shrub pass. Owner Kathreen, next step: one ground shot at 10/30 m, then animals from data/animals/animals.json.
- Not verified: thumbs (too small to see at 1.6 m), face at 1.6 m is crude.

## Water look: Sonny's answer (1 Nov), plan for after the test pass
- Flow channel does not exist yet (Sonny backlog item 6, docs/TERRAIN_WATER_BACKLOG.md); `src/water2/water_flow_texture.gd` exists (RGBAF: R depth m, G flow x, B flow z, A foam hint; SHADER_INCLUDE uniforms water2_tex, water2_origin, water2_size, water2_on, function water2_at(world_xz); names final). Until the channel lands the patch changes nothing on screen (only his demo).
- DONE untested: `emission` added to water_traits.gd and lava in water_kinds.json (run src/water2/test_water_field.gd after the go). Kathreen next steps (Godot needed to verify; shader errors would break all water, so write and check in one go): (1) apply the six-line patch to `water_material.gd` with water2_on = 0 default, check the sea/river pictures are unchanged; (2) add "emission" to `src/water2/water_kinds.json` (lava 1.0, others 0) and read it in `water_traits.gd`; add an emission uniform and per-kind colour uniforms to the shader so lava glows and swamp is not grey; check by picture with Sonny's demo; (3) sea retake for the lattice change (a5c239ae). Sonny will message the commit of his channel.

## 4-5 Nov 2026 (Kathreen)
PRs from this round. Offline renders are in art/CRITIQUES/kathreen_2026-11-04/. Dave's rule from 5 Nov 00:06 is no more cloud testing, so the in-game checks are Dave's on the PC.
- **#348 BUG-007, merged.** The cave passage closed at a distance because LOD 1-2 carving was under one voxel wide. `terrain_generator.gd` `cave_radius` gives at least 0.9 voxels at the coarse levels. `cave_room` caps the widening by the ground above, sampled every 8 m or less along the passage, so it never breaks through. TERRAIN_VERSION 52. Test: `src/worldgen/tools/test_cave_lods.gd` (voxel engine only). Steve's note: if block generation ever shows as slow, cache cave_room per capsule and level at tile load.
- **#363 floating pebbles over cave mouths, merged.** `grass_view.gd` re-casts 5 probes per cell at 1.5, 3, 6, 12, 24 and 48 s after the build, and rebuilds the cell when the ground moved more than 0.35 m. Counter `ground_rebuilds`. Test: `test_grass_ground_check.gd`.
- **#357 item looks (seed sack, bark, bandage), open, with Tyler.** `basic_look.gd` builders "sack", "bark" and "bandage" (the #352 picture check). See ITEM_ART_STATUS rows 9, 13 and 17.
- **#368 cave dressing, open, with Tyler.** `src/client/cave_dressing.gd` draws bone piles and formations per tile. The server sends them with the cave dens (`terrain_net.cave_dressing`, protocol 92; it moves to 93 if #359 merges first). Data: `cave_bones` has 5 floats per entry (x, y, z, kind 0 animal / 1 human, yaw), and `cave_formations` has 6 (x, y, z, kind 0 stalagmite / 1 stalactite, height_m, radius_m). Sonny's bake fills them in `tile_terrain_data._load_caves`. Stalagmites with a radius of 0.25 m or more are solid. Test: `test_cave_dressing.gd`.
- **Parked: NPC clothes** (branch `claude/kathreen-clothes-1104`, pushed, no PR). There is an outfit "dressed" table in data/npcs/outfits.json and `_worn_of` in npc_view.gd. The render looked blocky, and it waits on Dave's decision card.
- **Still open, needs the PC:** the look checks of NPC bodies (#298), the net in first person (#334), the wolf, the coats and the wildflower stems, and the meadow grass brightness shot (gain 0.6 if the tufts look pale).
