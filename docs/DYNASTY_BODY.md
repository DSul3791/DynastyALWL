# Dynasty body: design and integration reference

**Scope:** Dave's `Dynasty_Base_Male.glb`, its integration and retained animation/appearance ideas. Decisions and dated implementation notes are distinguished below; static cleanup is not a new PC visual check. Character records: [Character system](CHARACTER_SYSTEM.md); feel parameters: [Feel tuning](FEEL_TUNING.md).

## Adoption and fallback
Dave adopted the player body on 1 Nov 2026. On 8 Nov he made it the only player body: "lets turn them all on and get rid of that code". The old-body launch flags and Settings switch were removed; generated geometry remains the missing-import fallback, not a player option. On 3 Nov Dave directed the creator to "use our new character mesh and allow us to adjust his proportions"; the earlier wait-for-adoption and generated-creator alternatives are superseded.

This adoption does not settle NPC/crowd or first-person-arm implementation. The original NPC/arm exclusions were dated integration choices; inspect their current builders rather than treating them as a permanent ban. Dave's 1 Nov backlog retains lower-detail characters for low settings and distant NPCs (fewer triangles, 1k/2k textures), deferred rather than canceled.

## The file
Recorded 1 Nov asset: 1.70 m tall, faces +Z (wrapper turns 180 degrees to game -Z); centimetre skeleton under 0.01 scale, with 100x mounts for metres. One skinned mesh: 55,747 triangles, 34,760 vertices, one material, two 4096x4096 colour/metallic-roughness PNGs, 28.6 MB. 24 Mixamo bones (`mixamorig_Hips` through `HeadTop_End`, plus `headfront`), no fingers. The original export had 84 clips; the later export has 98. Clips are in place apart from some transitions. Original game-light pictures are dated evidence, not fresh validation.

## What is wired
`src/client/character/dynasty_body.gd` wraps the GLB and exposes `skeleton`, `body_mesh`, `animation_player`, `play`, `current`, `is_one_shot_playing`, `dress` (no-op), `set_shoulder_log`, `hand_mount_r/l` and `head_mount`. Trace player creation through `my_character.gd` and `terrain_client.gd::_make_avatar`; `game_menu.gd` formerly held the removed switch.

Mount convention: grip 7 cm into the palm along the forearm, -Z along fingers, +Y toward body front. The held axe follows the right wrist; `_build_mounts` is the adjustment point after visual inspection. Hip travel is removed from clips. `CLIP_MAP` owns current slices and rates; all source clips remain playable by name (for example `Formal_Bow`). Original gait measurements were Walking 1.15, Running 3.9 and RunFast 7.3 m/s, retimed then toward 1.4/3.2/6.0 m/s; these are dated measurements, not current movement targets.

| game clip | Dave's clip | note |
|---|---|---|
| idle, carry_idle | Idle | |
| walk, carry_walk | Walking | the arm does not rise to steady a shoulder log |
| jog | Running | |
| run | RunFast | |
| crouch | CrouchLookAroundBow (98-clip export) | hips 0.46 m, loops, feet on the ground |
| crouch_walk, _back, _left, _right | Cautious_Crouch_Walk_Forward, _Backward, _Left, _Right | retimed to the game's 0.9 m/s crouch pace; `avatar_driver.gd clip_for` picks one by velocity for a body that has them (the Dynasty body only) |
| sit | Chair_Sit_Idle_M | hips 0.51 m in source; ground sit is post-processed by `_ground_sit` (BUG-020) |
| sit_chair | Chair_Sit_Idle_M, held on its first frame | sitting ON a seat (E on a chair, stool, log seat or bench, 5 Nov 2026); hips 0.51 m. X beside or inside a seat sits on it too, and the client lifts the body each frame so the hips joint rests 0.07 m over the seat top (terrain_client.gd _seat_lift, 7 Nov 2026) |
| lie | Sleep_Normally | head toward +Z, hips 0.18 m, right |
| swing, swing_fp, chop, pick_overhead | Heavy_Hammer_Swing | two-handed overhead; source impact retimed in `CLIP_MAP`; inspect current slices/rates against held_item's `HIT_AT` |
| jab | Right_Jab_from_Guard | GAP: a punch, not a spear thrust |
| throw | Charged_Spell_Cast | GAP: nearest arm-forward release; nothing throws |
| use | Push_Forward_and_Stop | GAP: closest reach |


**State hooks:** implemented 1 Nov in `avatar_driver.gd::hook_clip`, called by `terrain_client.gd::_update_view`: deep-water `swim`/`swim_idle`, E `drink`, sleep-end `wake_up`. Stamp: `inventory_view.gd::_drink_msec`. Picking up and gathering by hand play no clip, first or third person (Dave 17 Nov 2026; the `pick_up` hook and the first-person `gather` arm clip were deleted). Bodies lacking clips are unaffected. `sit_down`/`stand_up` mappings remain, but their chair transitions stopped being started on 5 Nov for ground sitting (BUG-020). They are not a missing general state-hook task.

## Clothing, hair, beard, faces, the character screen: what must be redone
1. **Worn clothing (gap 1 in code comments):** the original ragdoll axes are limbs down -Y/front -Z on `hips chest head hand_* ...`. Reported implemented 3 Nov: `WORN_BONES` / `_worn_frames()` map those joints to `mixamorig_*`, undo the rest basis and apply the 180-degree flip (`R_rest^-1 * Flip`), preserve the old joint positions, stretch along each limb by new/old length, and expose rig metadata `worn_frames` to `worn_look.gd`. Widths stay 1 (reported within 1–2 cm of the rest mesh). The former skip-all-builders instruction is obsolete. `test_dynasty_worn` covers the mapping; the recorded PC-picture check remains unverified here.
2. **Skin/clothes colour:** one texture contains skin, loincloth and painted face. Skin tinting was reported with the creator work; a whole-albedo tint also colours the loincloth. A separate skin/cloth mask and recolouring shader remain an option for independent colours.
3. **Hair/beard:** meshes mounted on Head; retain the option to bake `body_generator.gd` hairstyles to fit this head. The original bald body does not supply them.
4. **Creator/proportions:** reported started 3 Nov under Dave's direction above. `dynasty_proportions.gd` (`SkeletonModifier3D`) applies Height, Legs, Torso, Arms, Shoulders, Neck, Head, Hands and Feet after animation, lifting hips to keep feet down. `creator_proto` previews the shape; `my_character.make_avatar` applies it in play. `dynasty_shapes.gd` builds Build, Muscle, Belly, Hips and Chest blend shapes from the bind pose once per run; skin colour tints albedo. Recorded remaining work: face sliders, clothes colours, hair, female body (QA card `dynasty-hair-female`). Test: `test_dynasty_proportions`. Completion/appearance of those gaps is not certified by this cleanup.

## Animation gaps and retained ideas
Recorded gaps requiring suitable animation or a design choice: spear thrust (`jab` is a punch), standing throw (`throw` is only the nearest arm-forward release), one-handed use touch, log carry with right arm raised to steady the shoulder log, real swimming stroke matched to water depth, and tool-specific digging/hammering/pickaxe/fishing. The older deep-crouch complaint predates the 98-clip crouch mapping above; verify its appearance rather than reinstating a missing-clip task.

Retained source-clip ideas (not blanket implementation commitments):
- Combat: Attack, Double/Triple_Combo_Attack, Left_Slash, Sword_Parry, Two_Handed_Parry, Dodge_and_Counter, Roll_Dodge, Stand_Dodge, Simple_Kick, jabs, Combat_Stance, Hit_Reaction x2, Knock_Down, Dead — later fighting.
- Conversation/gestures: Agree, Big_Wave_Hello, Formal_Bow, Shrug, Talk_x6, Listening, Stand_and_Chat, Discuss_While_Moving, Victory_Cheer, Sitting_Clap, Stand_Clap.
- Festivals/emotes: All_Night_Dance, Joyful_Dance_with_Hand_Sway, Happy_Sway_Standing, Arm_Circle_Shuffle, Indoor_Swing.
- Gaits: Casual, Confident, Thoughtful, Quick, Injured, Limping, Unsteady, Walk_Turn_Left, Run_Turn_Left, Run_to_Walk, Jump_Run — injury/fatigue, turns and jumping. Check current mappings before calling a clip unwired.
- Gathering: Female_ x4, Collect_Object, Pull_Radish, Push_and_Walk_Forward; drink/sit variants: Sit_and_Drink, Sitting_Answering_Questions, Walk_to_Sit.
- The 14 added clips: Cautious_Crouch_Walk x4 and CrouchLookAroundBow; Crouch_Pull_and_Throw (crouched, not the requested standing throw); Crouch_Walk_with_Torch and left/right variants; Crawl_Backward, Crawl_and_Look_Back; Squat_Stance, Idle_5, Idle_10. Torch/crawl/idle clips retain their possible uses; inspect `CLIP_MAP` before assigning hooks. None supplies the jab/use/log-carry gaps.

## Checks and source evidence
Tests: `src/worldgen/tools/test_dynasty_body.gd`, `test_dynasty_worn`, `test_dynasty_proportions`, `test_avatar_hooks`. Tools: `tools/dynasty_clip_stats.gd`, `dynasty_gait.gd`, `dynasty_body_view.gd` (offline pictures), `dynasty_lie_check.gd`. Dated evidence: `art/CRITIQUES/dynasty_base_male_2026-11-01/`, including `clip_stats.md`, `clip_stats_98.md` and `game/` client pictures (`right_walk0.png`, `right_walk4.png`). No new Godot run or PC-picture review is claimed.

Consolidated from [the 1–8 Nov integration notes](https://github.com/DSul3791/DynastyALWL/blob/5352ecf4426adb164d81e8385ad2aaa9744a5992/docs/DYNASTY_BODY.md). Old personal assignments, elapsed-time estimates and superseded instructions remain in Git history rather than serving as current work orders.
