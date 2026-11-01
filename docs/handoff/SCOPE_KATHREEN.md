# Scope: Kathreen (art assistant: character, animal and plant looks), 1 Nov 2026

> **RULE (Dave): anything about LOOKS is artistic.** Kathleen is overloaded, so Dave named a second art agent, Kathreen. The split below is PROPOSED by me and sent to Kathleen to confirm; where she answers differently, her answer wins and this file is updated.

Read with `SCOPE_KATHLEEN.md` and `HANDOFF_KATHLEEN.md` (method, rating scale, QA card recipe, tests, rig quirks). I use the same method: research, block out, render several angles, honest 1 to 5 rating (5 = clearly real at 10 and 30 m), check in the real game, keep it cheap, one QA card per picture.

## 1. The job, in plain words
Make everything the player sees of **people, animals and plants** look like the real thing at 10 and 30 m, cheaply. It starts where a design says "this exists" (character record, `data/animals`, `flora.json` rows) and ends when the look is built, rated honestly, seen in the real game, and accepted (Yes) on its QA card by Dave.

**Mine (look only):**
- Character: body, face, hair, worn clothes and armour as seen, hands, side-on stance and animations as they look, the creator preview (it opens on the back; Sonny's `c41e2d21` made it open facing front, to be confirmed in the real client), select and loading pictures. Code: `src/client/character/`, `ragdoll_body.gd`, `character_screen.gd`, `arms_view.gd`.
- Animals: models, fur and textures (`src/client/animal_view.gd`).
- Water look (added by Dave, 1 Nov, I take it first): colour, transparency, shader appearance (`src/client/water_material.gd`), foam, flow-texture look, reflections, shore look; lava and swamp looks. Sonny keeps water mechanics (sim, tiles, protocol) and supplies depth and flow data (render texture `src/water2/water_flow_texture.gd`).
- Plants: flower and stem colours (the pale glassy yarrow stems, blue-grey faceted yarrow heads), grass appearance and shader look, shrub and berry looks. Tree models stay with Kathleen (see below).

**Kathleen keeps:** items, tools, structures and furniture, fire and flame looks (incl. campfire flames hidden by grass), tree and fruit models (`tree_builder.gd`), the open pictures: lying trunk, orchard and crown close-ups, held axe head, cut logs, firewood and kindling looks. (Boundary: tree shapes and bark are hers; I touch `tree_builder.gd` only for flowers and shrubs, and tell her first.)

**Not mine:** MikeW: plant/animal density, placement, behaviour, draw cost. Tyler: rules and the character system (store, records, select code). Sal: item data, drops and text. Sonny: terrain and water mechanics, and the depth and flow data the shader reads. Dino: the first-hour playthrough. Water mechanics stay Sonny's; the water look is mine (Dave, 1 Nov).

## 2. Done so far
Nothing built yet. Read the scope, handoff, art queue, moderator documents, QA log, ponytail rules and QA rules. Facts I took from them: flora session left the yarrow rated 3/5 (heads read grey-blue, faceted and metallic in shade, stems pale) and asked for warmer head colour, upward normals and a non-glossy stem; chamomile and blueberry (F-13) pictures were never taken; Kathleen's `hands_larger` and worn-clothes work exists (`art/CRITIQUES/armour_worn`, `kits`).

## 3. Plan, in order (nothing runs until the moderator sends RESTART)
1. **Water look first (Dave's order).** Read what the shader can read today: in the real game only levels cross to the client and flow is guessed from level differences (`WaterGrid._velocities`); the sim's depth, flow and traits reach the shader only in the demo; the flow-texture patch for `water_material.gd` is planned by Sonny (six lines, status doc) and not applied; the shader has no emission uniform, so lava and swamp look wrong (grey, brown, no glow). Steps: (a) real-game pictures of river, lake and sea at 10 and 30 m, rate honestly, list the worst looks (colour, clarity, foam, shore, reflections); (b) fix what the shader can already do (colour, transparency, foam, ripple, shore); (c) agree with Sonny which data I need (flow channel) and who applies the `water_material.gd` patch; (d) emission for lava and swamp look once he confirms; one card per picture. Draw cost checked with MikeW's budget method.
2. **Yarrow and chamomile fix and pictures.** Warmer white head colour, smoother upward normals, matte stem; real-game shot at 53302,68423 facing north (yarrow) and 53326.7,68442.2 from the south (chamomile, default camera); 2 cards, rating each.
3. **Blueberry look (F-13).** Shoot at 53331.5,68359 facing north, camera about 1.0 m, pitch -15 (needs timeout over 280 s); check the 0.25 to 0.5 m bush reads as blueberry; 1 card.
4. **Character creator and select pictures.** Confirm in the real client that the creator opens facing front; shoot creator sections, select and loading screens; fix what looks wrong (face, hair); one card per picture.
5. **Character in play.** Side-on stance and walk/run/carry/crouch/sit/lie as seen, worn clothes and armour fitting the generated body, hands; judge the weakest, fix the worst.
6. **Animals' look.** Review every animal in `data/animals/animals.json` at 10 and 30 m (fur, proportions, colour variety), list ratings, fix the weakest three.
7. **Grass and shrub appearance pass** (with MikeW for draw cost, Kathleen for tree bark overlap): panicle, colour variety, how grass meets feet.
8. Weekly: rerun the look tests (see section 5) and keep `art/CRITIQUES/` READMEs and `art/ITEM_ART_STATUS.md` up to date for my rows.

## 4. Top five priorities
1. Water look (Dave's order), then what Dave sees first: the character (select, creator, in play), then the nearest plants and animals.
2. Real-game verification: a look that passes only the offline sheet is not done.
3. Known weak pictures: yarrow 3/5, character stance, creator preview.
4. Never hurt draw cost: no new materials or meshes without checking `test_flora_budget` and MikeW.
5. Keep boundaries clean with Kathleen, MikeW and Tyler; message the owner before touching their files.

## 5. Dependencies
I depend on: Tyler (character system code, `--dev-place` rig, review of code edits), MikeW (placement, density, where animals and flowers actually are for shots; draw budget), Sal (new items and drops needing worn looks), Kathleen (shared rig quirks, shaders, QA page recipe), Sonny (terrain loaded at shot spots, flow channel and the `water_material.gd` patch), the moderator (RESTART, merging, QA page, Dave's rules). Depending on me: Dino and Dave for character and plant/animal pictures; MikeW for flower and animal looks.

## 6. Rules I work under
Never merge to main (Dave must play-test and say go); I do not merge to the daily either, the moderator does after an "approved to merge" note. Max 3 heavy Godot jobs, always via `bash tools/godot_slot.sh`. World tests need the voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe`; standard tests use `Godot_v4.7.2-stable_win64_console.exe`. Do not kill Godot processes (one may be Dave's editor). Do not commit `crash_reports/`. Pictures: one item per QA card (qa worktree `C:/GodotProjects/DynastyALWL_qa`, pull first, copy to `questions/img/`, `Image:` line, `Note:` with my rating and render-or-real-game, `- Yes` / `- No`). Ponytail rules: read first, minimum code, `shortcut:` comments, one small test for logic, every report ends with what was skipped. Standing instruction: when done, invent three more tasks for my job in `art/ART_TASKS.md` (Kathreen section), do them, repeat.

## 7. The job is finished when
Every character state, animal in `animals.json`, water kind (fresh, sea, swamp, lava) and flower, shrub and grass row has a look rated 4 or more by me at 10 m in the real game and accepted (Yes) on its QA card; the creator opens facing front and its section pictures are accepted; look tests (`test_look_table`, `test_flora_budget`, character smoke test) pass; and no row of mine in `ITEM_ART_STATUS.md` or `PLAYTHROUGH_STEP_STATUS.md` is "rough" for what a player meets before the first winter.

## 8. Not verified
Everything above is from documents; no code run, no picture seen, no Godot started (hold in force). The split with Kathleen is unconfirmed until she replies. Whether `c41e2d21` really fixed the creator view is unknown.
