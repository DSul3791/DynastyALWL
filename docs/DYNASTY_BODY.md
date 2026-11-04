# Dynasty body (Dave's Dynasty_Base_Male.glb): what it is, how it is wired, what is left (Kathleen, 1 Nov 2026)

## Try it
The player's body by default since 1 Nov 2026 (Dave). To go back to the body worn before it (the generated body): client argument `--oldbody`, or Esc > Settings > Gameplay > "Old body (next Play)" (saved in `user://input_settings.cfg`, section `character`, key `old_body`); `--old-body` still gives the ragdoll. NPCs, the first-person arms, the character screen's preview and the creator keep the bodies they had (the creator's sliders do not change the Dynasty body). Code: `src/client/character/dynasty_body.gd` (a drop-in for the player body), `my_character.gd` (`dynasty_body_on`, `old_body`), `terrain_client.gd` (`_make_avatar`), `game_menu.gd` (the switch). Tests: `src/worldgen/tools/test_dynasty_body.gd`. Tools: `tools/dynasty_clip_stats.gd`, `tools/dynasty_gait.gd`, `tools/dynasty_body_view.gd` (offline pictures), `tools/dynasty_lie_check.gd`. Pictures: `art/CRITIQUES/dynasty_base_male_2026-11-01/` (`game/` is the real client).

## The file
1.70 m tall, faces +Z (the wrapper turns it 180 degrees to the game's -Z), skeleton in centimetres under a 0.01 scale (so mounts carry a 100x scale to give metres). One skinned mesh: 55,747 triangles, 34,760 vertices, one material, two 4096x4096 PNGs (colour, metallic-roughness), 28.6 MB. 24 Mixamo bones (`mixamorig_Hips` ... `HeadTop_End`, plus `headfront`), no fingers. 84 clips, in place (no root motion except a few transitions). Looks right in the game light (see `game/right_walk0.png`, `right_walk4.png`).

## What is wired
- The body: a `Node3D` holding the glb; `skeleton`, `body_mesh`, `animation_player`, `play`, `current`, `is_one_shot_playing`, `dress` (no-op), `set_shoulder_log`, `hand_mount_r/l`, `head_mount`, as the other bodies.
- Mounts: the grip is 7 cm into the palm along the forearm, -Z along the fingers, +Y to the front of the body (the old README rule). The held axe sits in the right hand; its angle follows the wrist, so one tilt number in `_build_mounts` may be wanted after Dave looks.
- Clips: the game's names map to Dave's (table in `dynasty_body.gd` CLIP_MAP); hips travel is removed from every clip; walk, jog and run are retimed so the planted foot moves at the game's 1.4, 3.2 and 6.0 m/s (measured with `dynasty_gait.gd`: Walking 1.15, Running 3.9, RunFast 7.3 m/s in place). All 84 clips are also kept under their own names (`animation_player.play("Formal_Bow")`).

| game clip | Dave's clip | note |
|---|---|---|
| idle, carry_idle | Idle | |
| walk, carry_walk | Walking | the arm does not rise to steady a shoulder log |
| jog | Running | |
| run | RunFast | |
| crouch | CrouchLookAroundBow (98-clip export) | hips 0.46 m, loops, feet on the ground |
| crouch_walk, _back, _left, _right | Cautious_Crouch_Walk_Forward, _Backward, _Left, _Right | retimed to the game's 0.9 m/s crouch pace; `avatar_driver.gd clip_for` picks one by velocity for a body that has them (the Dynasty body only) |
| sit | Chair_Sit_Idle_M | hips 0.51 m, right |
| lie | Sleep_Normally | head toward +Z, hips 0.18 m, right |
| swing, swing_fp, chop, pick_overhead | Heavy_Hammer_Swing | two-handed overhead; impact frame not tuned to held_item's HIT_AT (0.5 s of 0.95 s) |
| jab | Right_Jab_from_Guard | GAP: a punch, not a spear thrust |
| throw | Charged_Spell_Cast | GAP: nearest arm-forward release; nothing throws |
| use | Push_Forward_and_Stop | GAP: closest reach |

Not played by the game yet, ready by name (needs a state hook, Steve): `swim` (Swim_Forward), `swim_idle`, `drink` (Stand_and_Drink), `pick_up` (Male_Bend_Over_Pick_Up), `sit_down`, `stand_up`, `wake_up`.

## Gaps Dave would have to animate or decide
Still deep crouch; spear thrust; throw; a one-handed "use" touch; a carry pose with the right arm up over a log; a real swim stroke tuned to the game's water depth; tool-specific work clips (digging, hammering, pick axe, fishing).

## The rest of the 84 clips (not wired; all in `clip_stats.md`)
Combat (Attack, Double/Triple_Combo_Attack, Left_Slash, Sword_Parry, Two_Handed_Parry, Dodge_and_Counter, Roll_Dodge, Stand_Dodge, Simple_Kick, jabs, Combat_Stance, Hit_Reaction x2, Knock_Down, Dead): for a later fight system. Talk and gestures (Agree, Big_Wave_Hello, Formal_Bow, Shrug, Talk_x6, Listening, Stand_and_Chat, Discuss_While_Moving, Victory_Cheer, Sitting_Clap, Stand_Clap): NPC conversation. Dances (All_Night_Dance, Joyful_Dance_with_Hand_Sway, Happy_Sway_Standing, Arm_Circle_Shuffle, Indoor_Swing): a festival or emote. Gaits (Casual, Confident, Thoughtful, Quick, Injured, Limping, Unsteady, Walk_Turn_Left, Run_Turn_Left, Run_to_Walk, Jump_Run): injured or tired walking, turns, and a jump. Pick-ups (Female_ x4, Collect_Object, Pull_Radish, Push_and_Walk_Forward): foraging and harvesting. Drink and sit variants (Sit_and_Drink, Sitting_Answering_Questions, Walk_to_Sit).

## Clothing, hair, beard, faces, the character screen: what must be redone
Dave's body has its loincloth, bald head and face painted into one texture, so:
1. **Worn clothing** (`worn_look.gd`): the pieces are written in the ragdoll's bone frames (limbs down -Y, front -Z) on bones `hips chest head hand_* ...`. For this body they are skipped (`worn_skip_builders` lists every builder) so nothing mis-hangs. Fix: map the names to `mixamorig_*` and parent each part under a compensation node `R_rest^-1 * Flip` (the bone's rest basis undone, then the 180 degree turn), then fit the sizes to a 1.7 m body. About half a day; the maths is in the mount code already. **Done 3 Nov 2026 (Kathreen):** `dynasty_body.gd` `WORN_BONES` / `_worn_frames()` give each old bone one of Dave's bones and a frame in the old axes at the old joint's place, stretched along each limb by his length over the old one; `worn_look.gd` hangs the pieces on those frames (rig meta `worn_frames`). Widths stay 1 (measured from the rest mesh, within 1 to 2 cm). Test: `test_dynasty_worn`. Needs a picture on the PC.
2. **Skin and clothes colour**: baked into the texture. Options: tint the whole albedo by a skin factor (quick, a few hours, loincloth tints too), or ask Dave for an extra mask texture (skin, cloth) so a shader can recolour (a day with his export).
3. **Hair and beard**: new meshes on the Head bone (the head is bald). Reuse `body_generator.gd` hair styles by baking them to a mesh on this head; a day, plus Kathreen's eye on the look.
4. **Face/heads and the character creator** (`character_select`, `creator_proto`): they build the generated body; this body has no genome sliders (height, build, face). Either keep the creator on the generated body and use Dave's body for a fixed hero, or make the creator choose skin tint and hair only. Two days; a design call for Dave.
5. **NPCs and first-person arms**: unchanged on purpose. The 55 thousand triangle and 4k texture cost is too high for crowds; see the backlog line below. First-person arms stay the ragdoll arms.
Estimate: wearing clothes and tinting skin: about one day. Hair, beard and creator integration: about three more days with Kathreen. All of it waits on Dave saying he wants this body.

## Backlog line (Dave 1 Nov)
Lower-detail variants of the character for low settings and distant NPCs (fewer triangles, 1k or 2k textures): to be made later, not now. Owner: Kathleen/Kathreen.

## Code owner for hooks (Steve)
Done 1 Nov 2026 (Steve): `avatar_driver.gd hook_clip` asks for swim / swim_idle (in deep water), drink (the player's E drink), pick_up (a pick-up or gather the player asked for; skipped when running), sit_down and stand_up (stance changes between standing and sitting) and wake_up (the sleep ends). It does nothing for a body without those clips (the generated body, the old ragdoll). The call is in `terrain_client.gd _update_view`; the stamps are `inventory_view.gd _drink_msec` and `pick_stamp`. Test: `test_avatar_hooks`.

## New clips of the 98-clip export (1 Nov, later)
14 added: Cautious_Crouch_Walk x4 and CrouchLookAroundBow (wired); Crouch_Pull_and_Throw (a crouched throw, NOT wired: the game's throw is standing; Dave to say), Crouch_Walk_with_Torch and _Left/_Right_with_Torch (candidates for a held torch while crouched), Crawl_Backward, Crawl_and_Look_Back (a prone crawl), Squat_Stance, Idle_5, Idle_10 (idle variants). None fits jab, use or the log carry; those gaps stand. Stats: `art/CRITIQUES/dynasty_base_male_2026-11-01/clip_stats_98.md`.
