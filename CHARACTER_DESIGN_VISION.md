# Character design vision (Sonny; research and plan, 30 Oct 2026; for Dave to review)

Status: **research and planning only. Nothing in the game has been changed.** Branch `sonny-character`; this is the only file added.

Goal: the player character should look and move like a natural, readable person: arms swinging properly in walk and run, weight in every start and stop, believable swings, digs, chops and builds, and the same quality in first person, third person, for other players and for NPCs. It must stay cheap enough for the minimum machine (GTX 1050, 8 GB) and fit a stylised look beside a near-photoreal world.

## The target picture
- **Looks:** slightly stylised, heroic proportions, a hint of cartoon (Dave, 2026-10-20, ART_DIRECTION.md section 10), readable as a silhouette at 70 m. Joints that bend. Whether it gets a face, hair and fingers is Dave's decision (D1).
- **Moves:** blended gaits instead of clip switches; jump, fall, land, crouch walk, strafe, turns, ladders, swimming, slopes with planted feet; actions with anticipation, contact and recovery fired from clip events.
- **Both views agree:** one skeleton, one set of clip names, one shared action definition per tool, so first-person arms, third-person body, NPCs and other players never drift apart.
- **Network:** velocity, stance and action ids go over the wire; each client works out the pose.

## Why (the short version)
- Today the body is blobs on rigid weights with 17 bones and hard clip switches; third-person swings do not show; there are no jump, swim or climb clips; other players are not drawn (Part 1).
- Comparable games show the traps: first and third person drifting apart (Rust, Medieval Dynasty), giant state machines (Rust), rigs too crude to bend (Unturned) (Part 3, F1 to F10).
- The research could not confirm many numbers (gait angles, proportions, budgets). So the plan treats numbers as tunable and measures on the minimum machine (Part 3.10).

## Principles
See Part 4.1 (eight principles: readable first; believable weight; one body many views; actions are events; derive, don't send; cheap at distance; every number has a knob; no divisive defaults).

## How the pieces fit
`ragdoll_body.gd` (rig and clips) -> `terrain_client.gd::_update_view` (picks clips) -> `held_item.gd` (first-person arms and tools) -> `worn_look.gd` / `worn_sync.gd` (clothes) -> `npc_view.gd` (NPCs). The plan puts an `AnimationTree` and a shared action library in the middle of that chain (Part 5.1) and changes the body last (Phase 3).

## Plan in one paragraph
Phase 0 measure and prototype; Phase 1 animation architecture on the current body; Phase 2 missing locomotion; Phase 3 new body and rig; Phase 4 tool and activity library; Phase 5 equipment and secondary motion; Phase 6 other players; Phase 7 special states (Part 7.1). Risks in 7.2; open questions 7.3.

## Decisions for Dave
D1 look (ragdoll or simple stylised human), D2 how the body is made, D3 first-person approach, D4 third-person priority, D5 order of work, D6 sprint/roll, D7 when other players appear, D8 distance tiers, D9 customisation, D10 file ownership and approval of the removal list, D11 quality bar, D12 budgets, D13 purchased animation (Part 7.4, each with my recommendation).

## Where things are
Order of this file: this vision; Part 1 present state; Parts 4 to 7 (rules, movement plan, gap analysis, roadmap and decisions); then the reference sections at the end: **Part 2** (copied project passages and the "passages to remove once Dave approves" list in 2.8) and **Part 3** (research log with sources and confidence tags). Part numbers are kept so cross references still work.

**How to read it.** Every statement is labelled:

- **FACT (code)**: read from the repository on this branch; the file path is given. Line numbers (marked "~") are approximate positions on 2026-10-30.
- **FACT (doc)**: stated in one of our own documents; source file and heading are given.
- **FACT (web)**: stated by an outside source; the URL is in the Research log (Part 3) with a confidence note.
- **RECOMMENDATION**: my own opinion; always labelled.
- **UNCONFIRMED**: could not be checked; stated as such.

Older project documents mention an earlier agent called Sonny who worked on terrain and water. That is a different role; only the player-character parts of those documents are used here.

---

# Part 1. Present state of the player character

## 1.1 Summary

- **FACT (code)** The player is drawn by **one script that builds everything in code**: [src/client/ragdoll_body.gd](src/client/ragdoll_body.gd) (643 lines). There is no imported model, no `.glb`, no `.tscn` for the character and no texture. [assets/character/](assets/character/README.md) holds only a README. Despite the name it is **not a physics ragdoll**: it is a skinned, keyframe-animated puppet ("animated, not simulated", ART_DIRECTION.md section 45).
- **FACT (code)** It is a **17-bone `Skeleton3D`** with one skinned mesh made of ellipsoids and capsules. Weights are rigid (every vertex is 100 percent on one bone), so joints are separate overlapping blobs, not a bending skin. About 1.86 m tall.
- **FACT (doc), conflict** Triangle count: assets/character/README.md says about 3.2 thousand; ART_DIRECTION.md section 45 (older) says 1.5 thousand. I did not run the check script, so which is current is UNCONFIRMED.
- **FACT (code)** The game is **first person and third person**. First person is the default. The mouse wheel scrolls out to third person (1.6 m to 7 m behind the shoulders) and back. In first person the full body is hidden and its animation switched off; a separate **arms-only** copy of the same rig (7 bones) hangs from the camera and holds the tool.
- **FACT (code)** Animation is **hand-keyed in code** (angle tables per pose, sampled into `Animation` resources at start-up) and played by an **`AnimationPlayer` with hard clip switches** (0.15 to 0.25 s cross-fade). There is **no `AnimationTree`, no blend space, no state machine, no IK, no look-at, no root motion**.
- **FACT (doc)** The look is deliberately minimal. Owner wording 2026-10-21: "a simple ragdoll type character, no features, just a body, head, arms, legs and hands" (ART_DIRECTION.md section 45). One neutral skin colour; no face, hair or fingers (each hand is one ellipsoid).
- **FACT (code)** Clothing is a set of small primitive meshes (spheres, boxes, cylinders) hung on bones by [src/client/worn_look.gd](src/client/worn_look.gd), plus a four-region colour shader (skin, coat, trousers, shoes) inside `ragdoll_body.gd`.

## 1.2 The rig and mesh (`src/client/ragdoll_body.gd`)

- `extends Node3D`, `_init(arms: bool = false)`. `Ragdoll.new()` is the full body (feet at the node origin, facing -Z, right = +X). `Ragdoll.new(true)` is the first-person arms model.
- Bones (`BONES` table, top of file): `hips` (0.95 m above the floor), `spine`, `chest`, `neck`, `head`, `arm_r/l`, `forearm_r/l`, `hand_r/l`, `thigh_r/l`, `shin_r/l`, `foot_r/l`. 17 in all. **No shoulder (clavicle) bone, no toe bones, no finger bones, no twist bones, no jaw or eye bones, no root or IK-target bones.** The names are the project's own, **not the Godot humanoid names** (`Hips`, `LeftUpperArm`, ... of `SkeletonProfileHumanoid`), so Godot's retargeting needs a bone map to use them.
- Mesh (`PARTS` table): ellipsoids for torso, head, joints, hands and feet; capsules for limbs. Built once and cached in static variables (`_full_mesh`, `_full_skin`), so every body shares one mesh and one draw call. A 2.4 m custom bounding box stops culling while limbs swing.
- The vertex colour red channel marks the clothing region (0 skin, 0.34 coat, 0.67 trousers, 1 shoes). `dress(skin, coat, trousers, shoes)` swaps in a small shader material that recolours the regions.
- Mounts: `hand_mount_r`, `hand_mount_l` (a `Marker3D` under a `BoneAttachment3D` on each hand; grip 7 cm below the wrist, -Z along the fingers) and `head_mount`. Held tools are parented here.
- `set_shoulder_log(...)` hangs a cylinder on the chest bone for the large-log carry.

## 1.3 The animation clips (`ragdoll_body.gd`, `_build_animations`)

Clips key rotation tracks for **every** bone (so a switch never leaves a bone in the old pose) plus a position track on the hips. Each is sampled from a function at 8 to 22 frames and Godot interpolates between the keys.

| Clip | Length | Loop | Notes (FACT, code) |
|---|---|---|---|
| idle | 3 s | loop | breathing, arms slightly out |
| walk / jog / run | 1.0 / 0.75 / 0.62 s | loop | one parametric function `_gait(...)`: thigh swing, knee swing and plant, arm swing, elbow, lean, spine twist, hip bob, run hop. Numbers from Tyler's table (Part 2, B3) |
| crouch | 2 s | loop | one held pose, the same whether still or moving |
| sit / lie | 3 s / 4 s | loop | static poses with breathing |
| swing | 0.7 s | once | third-person axe/pick chop clip, right arm and spine only; left arm held at rest by Dave's rule |
| swing_fp | 0.55 s | once | first-person chop; impact key at 0.35 s; has a wrist track |
| jab | 0.5 s | once | spear thrust |
| throw | 0.8 s | once | spear throw |
| use | 0.6 s | once | reach out and touch or press; used for every other tool and action |
| carry_idle / carry_walk | 3 s / 1.2 s | loop | large log on the right shoulder |

There is **no** clip for: jump, fall, land, swim, climb or ladder, turn, start or stop, strafe, walk backwards, sprint (run is the top gait), draw a bow, drink, eat, hammer or build, dig, fish, hurt, death, faint or collapse, mount, pick-up, or a two-handed hold. (I searched the file and its callers; none found.)

## 1.4 How the third-person body is driven (`scenes/terrain_client/terrain_client.gd`)

- `_update_view(delta)` (~line 2731) runs every drawn frame: it creates the avatar once (`_make_avatar`, ~2841, a child of the player `CharacterBody3D`), places the drawn camera, and picks a clip.
- Clip choice: the stance (`idle`, `crouch`, `sit`, `lie`) from [src/client/stance.gd](src/client/stance.gd). If standing and horizontal speed is over 0.6 m/s then `walk`, `jog` or `run` by speed, with hysteresis (jog from 2.2 m/s, run from 5.0, back down at 1.8 and 4.4). `carry_*` when a log is on the shoulder.
- Playback speed is scaled to ground speed so the stride roughly matches the ground (walk speed/1.4 clamped 0.5 to 1.7; jog /3.2 clamped 0.8 to 1.6; run /6.0 clamped 0.8 to 2.0). This is the only anti-foot-sliding measure. There is no foot IK or foot locking.
- A forward tilt of the whole body (`_avatar.rotation.x`) follows the ground slope (uphill up to 0.44 rad, downhill a little back).
- While hidden (first person) the `AnimationPlayer` is inactive, so it costs nothing.
- Speeds (m/s, ~line 150): `WALK_SPEED 1.4`, `JOG_SPEED 3.2`, `RUN_SPEED 6.0`. Jump: `velocity.y = 7.0` with `GRAVITY 20.0`, a rise of about 1.2 m (7 squared over 2 x 20, computed by me). Swimming 2 m/s, 3 m/s with Shift (CONTROLS.md "Swimming"). Ladder climb 1.1 m/s ([src/client/ladder_climb.gd](src/client/ladder_climb.gd)). Step-up limit 0.5 m ([data/movement.json](data/movement.json), [src/client/step_up.gd](src/client/step_up.gd)).
- Gait controls: double-tap W toggles jogging, Shift runs (CONTROLS.md "Gait rules").
- Stances (stance.gd): STAND, CROUCH (C), SIT (X), LIE (Z), toggles. Collision capsule height 1.8 / 1.2 / 1.0 / 0.7 m; eye height above body centre 0.7 / 0.2 / -0.05 / -0.55 m; speed share 1 / 0.45 / 0 / 0.
- The player body is a `CharacterBody3D` with a capsule of radius 0.35 m, height 1.8 m. The avatar is offset so its feet sit at the capsule bottom.
- Body yaw turns instantly with the mouse (`body.rotate_y(...)`, ~2906); the eye camera pitches separately (`camera.rotation.x = pitch`). **In third person the body does not turn gradually, the head does not look up or down and the torso does not twist toward the aim**; the body is always square to the view. (From code reading; I did not see it running.)
- First-person camera: a small head bob and sway tuned per gait (`BOB_M`, `SWAY_M`, `SWAY_DEG`, `STEP_M`, ~lines 165 to 175). In third person the "eye" node stays where the eyes are and the drawn camera `view_cam` is offset up and back, pulled in by a ray so it stays out of walls (`VIEW_CLEAR_M 0.25`); the distance is remembered in `user://view.txt`.

## 1.5 First-person arms and held items (`src/client/held_item.gd`, 1802 lines)

- `_arms = RagdollScript.new(true)` (~line 158) is added under the camera. At rest the arms hang at the body's side below the screen edge; swinging, jabbing, using or aiming brings them up to a camera pose (`_arm_up`, `ARMS_FOLLOW_K`). `REST_DOWN_M`, `REST_PITCH_DEG`, `ARMS_POS`, `ARMS_PITCH_DEG`, `ARMS_SCALE 0.85` were tuned by eye from rendered stills (comments in the file).
- Actions play on the **arms only**: `_arm_play("swing_fp" | "jab" | "throw" | "use", seconds)` (~lines 224, 400 to 608). Timing constants: `SWING_S 0.55`, `HIT_AT 0.636` (the clip's impact key), hit stop `HIT_STOP_S 0.045`, reach `REACH_M 3.0`, `JAB_S 0.28`.
- Tools are parented to `hand_mount_r` through a per-tool rotation table (`HELD_LOOK_TURN`) and many hand-tuned per-tool pitch and scale constants (`THIRD_ROD_PITCH_DEG`, `THIRD_SPADE_PITCH_DEG` and others). The off-hand items (torch, shield) go to `hand_mount_l`.
- **Third person: I found no call that plays a swing, jab or use clip on the full-body avatar.** `_arm_play` acts only on `_arms` while it is visible (first person). In third person the tool sits in the avatar's hand while the body keeps walking or idling, so a swing does not visibly move the body's arms. (UNCONFIRMED by running the game; from code reading and search only.)

## 1.6 Clothing and equipment on the body

- [src/client/worn_look.gd](src/client/worn_look.gd) (189 lines): builders `cloak, hood, boots, leggings, mittens, skirt, sandals, pack`; per-item rows in [data/items/worn.json](data/items/worn.json) (builder, colour, layer). Parts are primitives on `BoneAttachment3D` nodes. Layers stand 1.5 cm further out to avoid z-fighting. Detail parts are skipped for bodies farther than about 30 m. Everything is rigid: cloaks and skirts do not sway.
- [src/client/worn_sync.gd](src/client/worn_sync.gd) (66 lines) maps server item numbers to ids. `terrain_client.gd::_dress_avatar` (~2809) tints coat, trousers and shoes from the `slot` of worn items using colours from [src/client/basic_look.gd](src/client/basic_look.gd) and hangs the worn pieces. Its comment says head, hands and back items had no basic look on the body in the first (colour) stage; worn_look builders for hood, mittens and pack do exist.
- The character screen ([src/client/character_screen.gd](src/client/character_screen.gd), ~line 96) shows a preview rig in idle.

## 1.7 Who else uses the same rig

- NPCs: [src/client/npc_view.gd](src/client/npc_view.gd) builds an NPC from the same rig with colour variation, chair and bed props and a name label. Clips come from server state and measured speed; update rate falls with distance (every frame to 15 m, every 2nd frame to 40 m, every 4th to 70 m, held pose beyond; at most 20 drawn).
- Animals use their own builders ([src/client/animal_view.gd](src/client/animal_view.gd)), not this rig.
- **I found no code that draws other human players' bodies.** A project plan says the same (tech/ACTION_PLANS `Steve_worn_attach.md`: "other players have none yet (no remote-player bodies ...)"). A 20-player server is the stated target, but the client appears to draw only the local avatar and NPCs. UNCONFIRMED for the current build: I searched `src/` and `scenes/` for remote-player views and found none.

## 1.8 Tools and tests that exist

- [tools/check_ragdoll.gd](tools/check_ragdoll.gd): headless check (about 1.8 m tall, every animation present and keying every bone, mounts exist, arms model has only arms, mesh not heavy).
- [src/worldgen/tools/test_worn_sync.gd](src/worldgen/tools/test_worn_sync.gd).
- `debug_pace` in `terrain_client.gd` ("shot runner only: pretend to move at this speed") and `docs/mirror/tech/STANDARD_SHOTS.md` are how earlier agents looked at the character (software-rendered stills).

## 1.9 What I could not determine

- How the character actually looks and moves in the running game. I did not run the game (this phase allows reading only); everything above is from code and documents.
- The real triangle count and per-frame cost on the minimum machine. Documents give estimates, not measurements (ART_DIRECTION.md section 45: "by estimate, not measured live").
- Whether remote human players are drawn anywhere (1.7).
- Whether the third-person body animates during swings (1.5).
- The frame-time effect of animating many bodies. It was never measured; DECISIONS.md sets a budget of 1 ms at Low for 20 visible bodies.
- Whether character assets exist outside the repository (Dave's disk, `E:\Software\godotDev`). I looked only in the repository.

---

# Part 4. Player character design guides and rules

**Everything in Parts 4 to 7 is RECOMMENDATION unless marked FACT, with the supporting facts cited by ID from Part 1 (current state), Part 2 (project documents) or Part 3 (research). Where the research could not confirm something, the rule says so and makes it a tunable value to be set by eye or by measurement, not a law.**

## 4.1 Principles

1. **Readable first, detailed second.** The player and other people must read as a person at 70 m and from any camera angle: strong silhouette, clear head, torso, arms, legs, held tool. (Basis: the Team Fortress 2 design papers I read, which validated characters as plain silhouettes before any shading; see H13 and 3.9 below. Project basis: Dave 2026-10-20 decision that characters are "slightly stylised, heroic proportions, a hint of cartoon", ART_DIRECTION.md section 10.)
2. **Believable weight over realism.** The world is near-photoreal (ART_DIRECTION.md section 5) but the character is stylised (section 10). Motion should be natural in its timing and weight (A1, A2) while the shapes are simplified.
3. **One body, many views.** The first-person arms, the third-person body, the character screen preview and the NPCs and other players should all be driven by the same skeleton definition, the same clip names and the same action timings, so a fix in one place fixes all (Basis: Rust spent years with first and third person drifting apart, F1, F10; Medieval Dynasty's bug stream, F5; Dave already found the third-person clip was driving the first-person arms, Part 2 B5, FINDINGS Report 26).
4. **Actions are events, not clips.** A swing is: anticipation, contact, recovery, with the damage/sound/particle fired on the contact event, never from a timer that is guessed to match the animation (Part 2 B5, FINDINGS Report 26 item 3; D1, D4, B3).
5. **Derive, don't send.** The network carries velocity, stance, aim and action ids; each client derives the pose (Part 2 B7 decision DECISIONS 18:10; E1, E2, E4).
6. **Cheap at distance, rich up close.** Full detail within about 15 m, reduced beyond, frozen past about 70 m (Dave's existing rule, Part 2 B7); a measured budget of 1 ms at Low for 20 visible bodies (DECISIONS.md, Part 2 B1).
7. **Every number has an owner file and a tuning knob**, in data, not buried in code (the Dave rule that gaits are tuned in one place; Part 2 B3 and B7 item 1).
8. **No gendered, divisive or exclusionary labels or defaults** in names, files, clips or customisation (DECISIONS 2026-10-23 03:35 "safe place" rule; DESIGN_IDEAS section on spouses; Part 2.9 item 10).

## 4.2 Look, proportions, scale and style

- **Style (FACT/doc):** slightly stylised, heroic proportions, a hint of cartoon; lighter budget than the realistic reference (ART_DIRECTION.md section 10). Owner on 2026-10-21 asked for a "simple ragdoll type character, no features". These two are compatible only if "no features" is read as "no detailed face, no fingers"; whether to add a face, hair and fingers is Dave's decision (Part 7, D1).
- **Height and scale (FACT/code):** 1.86 m tall, capsule 1.8 m high and 0.35 m radius, eye 0.7 m above the capsule centre, hips at 0.95 m. RECOMMENDATION: keep 1.8 to 1.86 m, because the world, doors, ladders (2.4 m, rungs 0.35 m), jump height (about 1.2 m) and the step limit (0.5 m) are all tuned to it; scale NPC variation within plus or minus 4 percent height and 6 percent width (project proposal, FINDINGS Report 17, not an outside fact).
- **Proportion rule (RECOMMENDATION, not sourced):** no outside source for head-heights or hand and foot size was found (H14). Propose a 7 to 7.5 head-tall body with hands and feet about 10 to 15 percent oversize, shoulders slightly broad, as a *starting* value to be decided by Dave's eye on a side-by-side with the current figure. Clearly marked UNCONFIRMED by research; validate with the silhouette test below.
- **Silhouette test (basis: TF2 paper, H13):** every new body, tool, hat or garment must still read when drawn as a flat black shape at the size the character appears at 20 m, 50 m and 70 m. Test before any shading work.
- **Colour and contrast:** keep the existing four-region tint (skin, coat, trousers, shoes) for cheap variation (Part 1.2). Prefer value contrast between torso, arms and legs so the swing of an arm reads against the body.
- **Shape language:** rounded shapes for the body are already in place; hands and tools need distinct silhouettes (tool head larger than realism, grip visible).
- **Faces and hair (decision pending):** if added, keep them as a few large shapes on the head mesh or texture, not geometry detail; the small-rig Minecraft and Unturned experience shows a simple face plus strong body motion carries a lot (F3, F6).
- **Joints must bend (basis: H14 community advice and the current "blob" weights):** the current rigid weights give a stick-figure look (Part 1.1). The next body must have a joint loop at each elbow, knee, shoulder, hip, wrist, ankle and neck and soft weights across it. Keep the 7 to 10 degree bend visible at the knee even in walk.
- **Skin tones and body variety:** allowed variation: skin tone, hair, coat colour, body build within a narrow range (disguise rule in DESIGN_IDEAS section 9.2: height and build are hard to change). Detail in Part 7.

## 4.3 Skeleton and rig conventions

- **Bone names (RECOMMENDATION, basis B6 B7):** adopt the Godot humanoid names (`Hips`, `Spine`, `Chest`, `Neck`, `Head`, `LeftShoulder`, `LeftUpperArm`, `LeftLowerArm`, `LeftHand`, `LeftUpperLeg`, `LeftLowerLeg`, `LeftFoot`, `LeftToes`, and Right) so any future imported animation, Mixamo-style or purchased clip set can be retargeted by a BoneMap (B6) and RetargetModifier3D (B8) instead of re-keying. The current names (`arm_r`, `forearm_r`, `thigh_r`...) can stay as an internal alias table.
- **Minimum new bones:** shoulders (clavicles) so the shoulder can shrug and the arm can reach without twisting the chest; toes so the foot can roll; `UpperChest` optional. Add helper/twist bones only if the mesh shows candy-wrapper twisting. Fingers: one pair of grip poses (open, closed around a haft) by blend shape or three simple finger bones per hand; decide in Part 7 (D1). Rust added twist bones and metacarpals in its rebuild (F1) but with a far larger budget.
- **Extra non-deforming bones:** `Root` at the feet (for root motion if used and for IK placement), `Hand_R_Grip` and `Hand_L_Grip` (replace today's `Marker3D` mounts), `Head_Look`, `Eye` (camera) and `Back`, `Hip_R`, `Hip_L` attachment points for pack, quiver, tool on belt.
- **Axis and rest pose:** T-pose or A-pose facing +Z for imported assets (B6); the project's own convention is facing -Z in the rig with right = +X, which is Godot's usual forward. Document the convention once in assets/character/README.md and keep the check script (`tools/check_ragdoll.gd`) updated.
- **Skeleton count:** one shared skeleton definition for player, NPC and other players (FINDINGS Report 17 item 1).

## 4.4 Animation quality bar

These are targets to be tuned and measured, not outside standards. Where an outside source exists it is cited.

- **No visible foot sliding while moving at a steady speed.** Match playback speed to ground speed (already done within limits, Part 1.4); lock planted feet with IK when IK lands (C1, G14). The sliding perception threshold is not known (G14); define it by eye on a standard slow-motion side shot.
- **Weight:** every move that starts or stops has a lean/ease: a body that reaches full speed instantly looks weightless (A1). Add lean into acceleration, turns and stops (G15 says no sources; judged by eye).
- **Response time:** a tool swing should begin to visibly move within about 50 to 70 ms (3 to 4 frames at 60 fps) of the click, with the longer wind-up carried by an already-ready pose (A2 "anticipation moves into the ready pose") and the owner's client playing it at once (E8). The 40 to 80 ms ceiling comes from low-authority sources (G11); treat as a starting point.
- **Hit timing:** damage, sound and particles fire on the contact event of the clip; hit stop 2 to 10 frames scaled with tool weight, capped (D1, D3: lengths unverified, tune by feel). Offer a setting to reduce or turn off camera shake/bob/hit stop (C10, G12 note).
- **Cross-fades and transitions:** no hard cuts; cross-fade 0.1 to 0.25 s depending on the pair (today 0.15 to 0.25 s, Part 1.3); landing and start/stop clips must be short enough not to lock control (A10).
- **Loop cleanliness:** every loop is seamless and the phase of left/right feet is preserved on blends (B1 sync "cyclic").
- **Secondary motion:** breathing, cloak sway, tool inertia, head stabilisation (the head stays level while the body bobs, Part 2 B3 rules).
- **Cost:** a single body < 0.1 ms CPU for animation at full rate; 20 visible bodies < 1 ms at Low (DECISIONS.md; Tyler's 0.1 ms per NPC target, FINDINGS Report 17). Re-measure on the minimum machine before and after each phase (the agent's note B5 says AnimationTree is heavy on weak CPUs and 4.7 changed internals, B4).
- **Visual review:** every clip is reviewed as a flat side/front/back/three-quarter stills set and a slow-motion capture, per the existing STANDARD_SHOTS.md procedure (Part 2 B4), before Dave sees it.

## 4.5 Naming and technical conventions

- **Clip names:** `snake_case`, grouped by prefix: `loco_idle`, `loco_walk`, `loco_jog`, `loco_run`, `loco_crouch_idle`, `loco_crouch_walk`, `air_jump_start`, `air_fall`, `air_land`, `swim_surface`, `climb_ladder`, `act_chop`, `act_mine`, `act_dig`, `act_hammer`, `act_jab`, `act_throw`, `act_use`, `pose_sit`, `pose_lie`. Loop clips carry a `loop` suffix if imported (B14). Existing names (`idle walk jog run crouch sit lie swing swing_fp jab throw use carry_*`) are mapped by an alias table until retired.
- **Frame events:** method-call tracks named `hit`, `step_l`, `step_r`, `release`, `grab`, `footfall` and so on; footstep sounds and grass/dust hooks should be driven by `step_*` events, not a timer (Tyler's note, Part 2 B3). AnimationPlayer method tracks do not fire when seeking or stopping (B3), so cancel paths need explicit tests.
- **Data:** gait, lean and action timing numbers in `data/` JSON (like `movement.json` and `worn.json`), not in constants.
- **Code layout (proposal):** `src/client/character/` with a rig definition, a body builder, a state-machine builder, an action library, an equipment/attachment module and a remote-body view; `ragdoll_body.gd` becomes a thin wrapper until retired. This is a plan for later; no file changes now.
- **Tests:** keep `check_ragdoll.gd` style headless checks: bone set, clip set, every clip keys every driven bone, loops closed, event tracks present, attach points exist, triangle and bone limits.
- **Ownership:** this document assumes Sonny owns the player character look, feel and movement files (`ragdoll_body.gd`, `stance.gd`, the avatar part of `terrain_client.gd::_update_view`, the arm/clip parts of `held_item.gd`, `worn_look.gd`, `worn_sync.gd`, the character screen preview). Several are shared with others (held item logic, camera): Part 7 asks Dave to confirm.

---

# Part 5. Movement and animation plan

Legend. **Now** = what the code does today (Part 1). **Look** = how it should read. **Build** = technique. **Why** = supporting fact IDs or project rule. **Pri** = priority (P1 first). Techniques named here are available in Godot 4.7 per B1 to B15.

## 5.1 Architecture (applies to everything below)

1. **State machine plus blend spaces plus layers, in an `AnimationTree` (B1).**
   - Locomotion layer: a `BlendSpace1D` (speed) for forward gaits, plus a `BlendSpace2D` (direction x speed) for strafe and backward if wanted; stance state machine on top (stand, crouch, sit, lie, swim, climb, air).
   - Upper-body action layer: `OneShot` nodes with a bone filter (B1, D5) so a swing or use plays on spine/arms while the legs keep walking.
   - Additive layer: breathing, look-at, lean, recoil (A1 secondary action).
   - Procedural layer after the mixer: `LookAtModifier3D` for head/spine (B11), `TwoBoneIK3D` for feet and left hand (B10, C1), `SpringBoneSimulator3D` for cloaks and straps (H1), all `SkeletonModifier3D` (B9).
   - **Hard cuts become cross-fades** driven by a transition graph rather than an if-chain in `_update_view`.
2. **Root motion: not used for the player; in-place clips with speed-scaled playback** (the player's speed is decided by input and the server, not the animation). Root-motion data may be used offline to read stride lengths (A5, A11, A6). Basis: our movement is server-validated physics; Unreal's pose warping needs root-motion clips and is Unreal-only (A5).
3. **Motion matching and stride warping: not recommended** (needs large data sets and custom engine work, no Godot implementation found; A6 to A8). Use a small number of authored clips plus IK.
4. **One action model for all views.** A shared "action definition" record per tool/action: clip, duration, anticipation end, contact time, recovery end, cancel window, hit-stop, camera kick, sound event, which hand(s), which layer. First-person arms and third-person body read the same record; each view has its own clip authored to the same timings (F1, F10; Part 2 B5 Report 26).
5. **Update scheduling.** Own avatar: every frame when visible. Others: use `callback_mode_process = MANUAL` and `advance()` at the tier rate (H3; already used for NPCs, Part 1.7), and throttle modifiers too (H3).
6. **Network:** see 5.5.

## 5.2 Locomotion and posture

| State | Now (FACT, code) | Look (RECOMMENDATION) | Build | Why | Pri |
|---|---|---|---|---|---|
| Idle | one 3 s loop, arms slightly out | weight shifts, occasional look-around, breath, hands relaxed; variation every 4 to 12 s | idle set (3 to 4 clips) + random micro-actions in the state machine; head glance via LookAt | FINDINGS Report 17 item 3 (project); A1 | P2 |
| Walk | clip `walk`, speed 1.4 m/s | heel-strike, relaxed arm swing, level head, hip sway | refine clip; stride-match; foot lock IK later | Tyler table, unverified (3.7 G15); G1 | P1 |
| Jog / run | clips `jog` 3.2, `run` 6.0 m/s | lean 5 to 10 degrees, bent elbows, flight phase in run | refine; blend by speed in BlendSpace1D, not hard switches | G3 transition about 2 m/s; A4 | P1 |
| Sprint | none (game has no sprint) | only if the game adds it | decision D6 | CONTROLS gait rules | - |
| Strafe / backward | none: the body is always square to the view | walk or jog at reduced stride while facing the view; backward half stride | BlendSpace2D (direction x speed), or orientation twist of the spine over a forward clip | A5 (orientation warping idea) | P2 |
| Turning | body snaps with mouse | in third person the body follows the view with a short lag; turn-in-place steps when the view turns past a threshold; lean into fast turns | torso/head lookat limit, then body yaw catch-up; turn clips; lean via additive | G15 (no source); handled by eye | P2 |
| Start / stop | none (immediate) | 2 to 4 step accel lean, stop lean back, plant | additive lean from acceleration; optional start/stop clips | A3 (Game Anim chapter); A1 | P2 |
| Crouch | single held pose | knees and hips flex, back inclines, shorter steps, smaller head bob; separate idle and walk; transition in/out | `loco_crouch_idle`, `loco_crouch_walk` + transition clips; stance eye heights from stance.gd | G7 weak; Part 1.4 | P1 |
| Sit / lie / sleep | static poses | settle in/out transitions, breathing, hands in lap; furniture markers hold exact pose (chair, bed) | transitions + marker-driven snap, as for NPCs | FINDINGS Report 17 item 2 | P3 |
| Jump / fall / land | **no clips** (jump 7 m/s, rise about 1.2 m) | crouch-load, push-off, tucked rise, open arms in fall, landing absorb scaled by fall speed, tumble on hard fall | `air_jump_start`, `air_fall` loop, `air_land` short; blend landing by vertical speed; no control lock | A4 (distance matching idea), A10, G12 | P1 |
| Step up (0.5 m) | instant lift of the body | lead knee lifts, foot plants on the step, body rises smoothly | foot IK target at step height; smooth the capsule lift (existing eye ease) | Part 1.4 step_up.gd; C1 | P2 |
| Slopes | whole body tilts | uphill lean, shorter steps; downhill knee bend; feet on the ground | pelvis drop + two-bone foot IK to ray hits, smoothed; keep the tilt for large slopes | C1, B10; Tyler slope rules (unverified) | P2 |
| Stairs / ladders (placed ladders exist) | none (no ladder clip) | one limb at a time, hands on rungs, feet on rungs 0.35 m apart, body close to the rails | `climb_ladder_up/down` loops synced to climb speed 1.1 m/s; hand/foot IK to rung positions | G9; Rust still lacked a ladder animation in 2017 (F2); ladder_climb.gd | P2 |
| Swim | walk/idle clips while swimming | surface: prone body, alternating arm strokes and flutter; dive: glide; tread when still; breath exhale | `swim_surface`, `swim_fast`, `swim_idle`, `swim_dive`; body pitch to move direction | G8 weak; CONTROLS swimming 2 and 3 m/s | P2 |
| Wade (water over knees) | speed reduced only | high steps, arms out | blend knee lift by water depth | CONTROLS swimming | P3 |
| Carry (log on shoulder) | `carry_idle`, `carry_walk` | forward lean, shorter steps, slow roll | keep; tune lean with G6 | G6; Part 1.3 | P3 |
| Heavy pack / load | speed only | lean forward and shorter, faster steps scaled by load | additive lean by load ratio | G6 | P3 |
| Mounts (horses planned) | none | seated pelvis follows horse motion; legs and hands posed | mount point + pose + pelvis follow; later | G10; DESIGN_IDEAS mounts text | P4 |
| Exhaustion / injury | none (heart and breath sound only) | heavy breathing in chest, slowing, stumble, limp; collapse on faint | additive breathing driven by the exertion value; limp clip; ragdoll or collapse clip for faint | Part 2 B3 exertion text; DESIGN_IDEAS 6.16 | P3 |
| Hurt / death / respawn | none | flinch, fall; lie down; get up | additive hit reaction; death: ragdoll via `PhysicalBoneSimulator3D` or scripted fall | DESIGN_IDEAS death text; B9 (PhysicalBoneSimulator3D) | P3 |

## 5.3 Hands, tools, weapons and activities

Common rule: each activity is defined by the action record in 5.1 item 4: **anticipation, contact, recovery** with the contact event firing the effect (D1, D4, Part 2 Report 26). Anticipation lengths are tuned per tool weight; the look in the table is the target.

| Activity | Now | Look | Build | Pri |
|---|---|---|---|---|
| Chop (axe, felling) | first person: `swing_fp` 0.55 s, good; third person: **no swing visible** | two-hand grip, weight back, over-shoulder, impact at chest height, tug out | third-person clip `act_chop` driven by same action record; left hand IK to the haft; hit stop | P1 |
| Mine (pickaxe) | first person `use` | over-head arc, heavier, short pause, recoil | `act_mine`; stronger camera kick | P1 |
| Dig / fill (spade) | `use` | foot on blade, lever, lift, throw; both hands | `act_dig_*` with loop for held button; left-hand IK | P1 |
| Hammer / build | `use` | short repeated strikes at the placed piece; kneel for low pieces | `act_hammer` loop | P2 |
| Saw | `use` | pull-push loop | `act_saw` loop | P3 |
| Knife / cut | `use` | short slash; two-hand carve | `act_cut` | P3 |
| Spear jab / throw | `jab`, `throw` | crouch-lunge jab; throw with whole body | per-view clips; aim line for throw | P2 |
| Bow draw / shoot | bow item exists, no clip | nock, draw with back muscles, hold with breathing, release, bow hand recoil | `act_bow_draw` (held), `act_bow_release`; left hand holds the bow, right hand IK to string | P2 |
| Fishing | rod item | cast over shoulder, hold, strike, reel | `act_fish_cast/idle/reel` | P3 |
| Torch / shield (off hand) | mount only | torch held low and forward; shield on forearm, raise to block | off-hand layer that overrides one arm (Rust's torch method, F1); block pose | P2 |
| Gather / pick up / interact (E) | `use` | bend or reach to the target height (ground, bush, chest, door), pick, stand | height-aware reach: IK or three clips (low, mid, high) | P2 |
| Eat / drink | none | hand to mouth, head tilt; scoop water | `act_eat`, `act_drink` | P3 |
| Place blueprint / set trap | none | hold, point, lower | context-specific upper layers | P4 |
| Talk to NPC | none | face NPC (head look), small gesture | LookAt + gesture one-shots | P4 |
| Carry (hands) / drag | none | two-hand hold for baskets, crates | carry layers | P4 |

**Tool grip.** Replace the per-tool hand-tuned constants in `held_item.gd` with a per-item grip record in data: grip point on the tool, secondary (left-hand) grip point, hold style (one-hand, two-hand, off-hand) and carry pose (third person). The tool mesh stays the same as the ground model (Part 2 B5 Dave 2026-10-24). The left hand reaches the second grip point with `TwoBoneIK3D` when the tool is two-handed (B10; no sourced recipe, C11).

**First person.** Keep the arms-only viewmodel (cheap, proven in survival games, C6, F10) with these rules: (a) own camera-space clip per action authored to the shared action record; (b) the body-twist clip never drives the arms; (c) hands stay in view during wind-up; (d) the left hand shows only when it holds something (Dave's rule, Part 2 B5); (e) viewmodel FOV/depth treatment only if wall clipping becomes a problem (C8, both approaches have reported side-effects); (f) small camera dip and shake on impact under a user setting (C10, G13).

## 5.4 Equipment and clothing

- **Slots (existing items):** head (hood), chest (cloak, jerkin), back (pack), legs (leggings, skirt), feet (boots, sandals), hands (mittens), off-hand (torch, shield). (Part 1.6.)
- **Approach (RECOMMENDATION):** keep the data-driven slot system (worn.json) and its cheap primitives for now (Kathleen's plan in Part 2 B6 is sound: named anchors, layers, fit by proportion, under 150 triangles per piece, no detail beyond 30 m), but: (1) switch anchors to the new named attach bones from 4.3; (2) hide body regions under clothing with a region mask in the existing vertex-colour shader (not confirmed anywhere in research, H9; prototype first); (3) keep all worn pieces on the one shared `Skin` where possible to avoid extra skinning cost (H6, to be profiled); (4) give cloaks, skirts and straps `SpringBoneSimulator3D` chains (H1) with a cheaper vertex-shader sway for far bodies (H2: no source for the sway technique); (5) one master tint per item through instance uniforms (H7).
- **Tools on the body when not held:** belt/back attachment points for axe, spade, bow, quiver, torch; shown to others and in third person. New (not in the code today).
- **First-person own body:** hide head/hood/cloak parts from the owner's camera (Part 2 B6 Steve plan item 4; C7), never shrink the camera into the body.
- **Armour (planned, ARMOUR_LADDER.md):** same layer system, shape plus colour/material per tier, no per-armour clips.

## 5.5 Other players, NPCs and the network

- **Decision already taken (Part 2 B7):** send velocity, stance and one-shot action ids; clients derive clips. Research supports it (E1, E2, E3, E4). RECOMMENDATION adds:
  1. The owning client plays its own action immediately; the server validates and the hit result arrives later (E8, E6). Keep cosmetic and authoritative parts separate.
  2. One-shot action ids go on a reliable channel; positions on unreliable ordered (E9). At the 5 Hz tier a swing could be missed otherwise (E10).
  3. Drive remote walk speed from the interpolated displayed velocity, not the last packet's (E11 memory-level; test).
  4. Add hysteresis at the 15, 40 and 70 m tier edges (E10 report of pop-in).
  5. If melee needs server-side hit checks, use capsules or swept volumes first; server animation like Riot's is a possible later step and they cut cost by animating every fourth frame (E6).
  6. Interpolation buffer about three snapshot intervals (E5): at 4 Hz updates that is 750 ms, which is long for nearby players; consider a higher send rate within 20 m. (My arithmetic from E5; the real current send rate for players is not in this document, see Part 1.7.)
- **Remote humans do not exist client-side today** (Part 1.7). The remote body view should reuse the NPC view's logic (clip choice from speed/state, tiered update) and the same dressing code.

## 5.6 Camera and view

- First person: keep the head bob/sway (Part 1.4) but expose strength sliders and an off switch (C10); add a dip and a recoil on hit (D2, G13).
- Third person: keep the scroll-out view; replace the single ray with a swept-shape check (`SpringArm3D` style, C9) and smooth the return; align the camera target slightly above the shoulder.
- Add (optional) shoulder-swap and an over-the-shoulder aim mode for bow/throw. No source found for shoulder swap (C-gaps); judge by playtest.
- First-person full body ("body awareness"): optional; a lower-body-only mesh visible when looking down is a cheap compromise suggested by one forum poster (C7). Decision D3.

---

# Part 6. Gap analysis (current state against the plan)

"Current" is FACT (Part 1). "Target" is the RECOMMENDATION in Parts 4 and 5. Size: S under a day of work, M a few days, L a week or more (my rough guess, not measured; Dave should treat these as order of magnitude).

| Area | Current (FACT) | Target (RECOMMENDATION) | Gap | Size |
|---|---|---|---|---|
| Body look | Blobs of ellipsoids/capsules, rigid weights, no face, hands one ellipsoid | Soft-skinned stylised body, joint loops, simple head, grip-capable hands, clear silhouette | Mesh, skin weights, proportions, hands, head | L |
| Skeleton | 17 bones, own names, no shoulders/toes/fingers/root/grip bones | Humanoid-compatible names, shoulders, toes, root, grip and attach bones, one shared rig for all views | New rig definition, alias table, check script | M |
| Animation authoring | Angle tables in code sampled to clips | Same approach kept for tuning, plus ability to import authored clips by BoneMap | Pipeline decision (D2); import/retarget path | M |
| Animation runtime | `AnimationPlayer`, hard clip switches by if-chain | `AnimationTree`: locomotion blend space, stance state machine, filtered upper-body one-shots, additive layer | Build the tree (and verify it works on a code-built skeleton, I2) | M |
| Locomotion | idle, walk, jog, run, crouch (one pose), sit, lie, carry | + crouch walk, strafe/back, turn, start/stop, jump/fall/land, swim, climb, wade, slopes, steps | ~12 new clips or procedural systems | L |
| Feet | Playback speed matching only; whole-body tilt on slopes | Foot IK on slopes/steps, foot lock, pelvis drop | `TwoBoneIK3D` setup, rays, tuning (no tutorial exists, B10) | M |
| Head/torso aim | Body square to view; head does not look | LookAt on head/spine with limits; body yaw catch-up; turn-in-place | `LookAtModifier3D`, turn logic (default changed in 4.7, I1) | M |
| First-person arms | Arms-only rig; clips `swing_fp`, `jab`, `throw`, `use`; hand-tuned per-tool constants | Per-action camera-space clips on shared action records; left hand shows only when it holds something; settings for shake/bob | Action records + more clips | M |
| Third-person actions | **No arm clip plays on the body during swings/jabs/uses** (Part 1.5) | Same actions visible in third person, from the same records | Wire up + author clips | M |
| Tools and weapons | Mount + many tuned constants per tool; spear, axe, knife, torch, tools via `use` | Grip records in data; two-hand IK; per-tool clips (chop, mine, dig, hammer, bow, fish) | Data + IK + ~10 clips | L |
| Action events | Hit fired by a timer matched to the clip key (`HIT_AT 0.636`) | Hit/step/release events on the clip's method track | Event tracks + cancel-path tests (B3) | S |
| Equipment | Primitives per slot on bones, colour regions; no secondary motion; no tools on belt/back | Named attach bones, region hiding under clothes, spring bones, belt/back tools | Attach points, mask, `SpringBoneSimulator3D` | M |
| Other players | **Not drawn** (Part 1.7) | Remote bodies using the same rig, derived animation, tiered update | New remote body view + sync decisions | L |
| NPCs | Same old rig, clip by state/speed, tiered update | Share the new rig and tree; idle variation, work loops | Port | M |
| Network | Plan exists (derive from velocity/stance/action id); not implemented for players | Reliable action ids, hysteresis tiers, interpolation of displayed speed | Implementation + test with 20 clients | M |
| Performance | Budget 1 ms/20 bodies; never measured; 1 renderer (Forward+) | Measured per-phase on the minimum machine; LOD bodies | Profile harness | M |
| Camera | FP bob/sway fixed; TP ray, simple zoom | Settings sliders, impact dip, swept shape, smooth return | Small | S |
| Death/faint/hurt | No body response | Ragdoll or clip on faint/death; hurt additive | Clips + `PhysicalBoneSimulator3D` | M |
| Mounts | None | Mount pose later | Later | L |
| Tooling | `check_ragdoll.gd`, standard shots | Per-clip review sheets, event/loop/foot-slide checks, perf harness | New checks | M |
| Documentation | Scattered over ~20 docs, some stale (Part 2.9) | This file as the single source; originals pointed to it | Dave approves removal list | S |

---

# Part 7. Phased roadmap, risks, open questions and decisions

## 7.1 Phased roadmap (RECOMMENDATION)

The order is chosen so each phase is useful on its own, risky assumptions are tested early, and nothing is built twice. Nothing starts until Dave approves.

**Phase 0. Agree and measure (before any build).** Dave answers the decisions in 7.4 (at least D1, D2, D3, D5, D10). Capture a baseline: standard stills and a slow-motion capture of the current walk/run/swing from side, front and back; frame time of the avatar and of 20 NPCs on the minimum machine (the project has never measured this, Part 1.9). Prototype in a scratch scene (not in the game) that an `AnimationTree` can drive the code-built skeleton (I2). Output: a short measured report. Size S to M.

**Phase 1. Animation architecture on the current body.** Replace the if-chain with an `AnimationTree` (locomotion blend space, stance machine, filtered upper-body one-shot), cross-fades instead of cuts, event tracks for hit/step, data-driven gait numbers, shared action records so third person plays the same swings as first person, settings for bob/shake. Keep the present body, so the result is visible as movement quality alone and is cheap to revert. Output: same figure, much better motion; third-person swings visible. Size M. Why first: it fixes the largest "feel" defects (hard clip switches, no third-person actions) and every later phase depends on it.

**Phase 2. Missing locomotion.** Jump/fall/land, crouch walk, strafe/back, turn and start/stop, ladder, swim, wade, slopes with foot IK (`TwoBoneIK3D`, B10), step-up, head look-at. Each as a small separate change reviewed by stills. Size L.

**Phase 3. Body v2 and rig v2.** The new skeleton (humanoid names, shoulders, toes, grips, root), soft-skinned body with joint loops and the agreed proportions and hands (per D1 and D2), LOD body, character screen preview updated, silhouette test passed, alias table so old clips still play. The big visual jump arrives here. Size L. Needs the art pipeline decision (D2) and the proportion look-and-approve step with Dave.

**Phase 4. Tool and activity library.** Per-tool clips and grip records: chop, mine, dig, hammer, saw, knife, spear, bow, fishing, torch, shield, gather/pick-up/interact, eat/drink. Two-hand IK. Hit stop and camera feedback. Replace the per-tool constants in `held_item.gd`. Size L, can run in slices tool by tool in the order players meet them.

**Phase 5. Equipment and secondary motion.** Named attach points, belt/back tools, region hiding, spring-bone cloak and straps, tint via instance uniforms, armour layers. Size M.

**Phase 6. Other people.** Remote player bodies, derived animation, tiers with hysteresis, reliable action ids, NPC port, performance measured with 20 bodies. Size L. May move earlier if a friend session needs to see each other (D7).

**Phase 7. Special states and polish.** Exertion posture, limp, hurt, faint/death ragdoll, sit/sleep transitions on markers, emotes, mounts when horses arrive. Size L, open-ended.

Review gates: after each phase Dave sees stills/video and a short change note; a phase is "done" when the checks in 4.4 pass.

## 7.2 Risks

1. **Wide blast radius.** `terrain_client.gd` (5,196 lines) and `held_item.gd` (1,802 lines) are shared with other work; the avatar and first-person arm code sit inside them. Mitigation: move the avatar logic to its own module in Phase 1 with minimal edits to those files; coordinate with the other agents (the session "kathleen" is active now). Unknown: who else edits these files this week.
2. **AnimationTree on a code-built skeleton is unconfirmed** (I2). Mitigation: Phase 0 prototype. Fallback: keep the `AnimationPlayer` and build the blending in code (blend nodes are plain classes).
3. **CPU cost.** AnimationTree and skinned meshes may cost more than the 1 ms budget at 20 bodies on a GTX 1050-class PC with a weak CPU (B5, H4; both anecdotal). Mitigation: Phase 0 measurement; manual `advance()` tiers; fewer bones for far LOD; do not offer the Compatibility renderer without testing (H4).
4. **IK without a recipe.** The 4.6 nodes are new and no foot-IK tutorial exists (B10). Mitigation: small prototype before relying on it; keep the current tilt as fallback; physics-world ray costs.
5. **Unsourced numbers.** The gait table that drove today's clips is from memory (3.7). Mitigation: treat all values as tunable, tune by eye with Dave.
6. **Two view problem.** Maintaining separate first-person and third-person clips can drift (F1, F5). Mitigation: shared action records, one test that compares event times for both clips.
7. **Art production.** Body v2 needs modelling/rigging skill and time; code-generated bodies are limited (Part 1.1). Unknown: Dave's tools and who authors (D2).
8. **Style mismatch** between "no features" and "heroic stylised" (Part 2.9 item 1). Mitigation: decide D1 first.
9. **Network design unmeasured**: the actual player update rate, bandwidth and 20-client behaviour are not in my knowledge (Part 1.9). Mitigation: Phase 6 starts by reading the real protocol and measuring.
10. **Scope creep.** The wish list (mounts, emotes, customisation) is endless. Mitigation: phases ordered by what players do every minute (walk, jump, swing, climb, swim) first.
11. **Research confidence.** Many sources were summary-level (3.10). Mitigation: re-open the sources behind any expensive decision.
12. **Licensing** if third-party assets or animations are used: for example the GDQuest third-person controller art is non-commercial (B15). Mitigation: check every licence before importing anything.

## 7.3 Open questions for Dave

1. Is third person a first-class mode (every action polished in both), or a secondary view (first person is the real game)? (Medieval Dynasty and Rust show the cost of treating both loosely, F1, F5.)
2. Do you want other players to see each other soon (a friend session)? That raises the priority of Phase 6.
3. What speeds will the game finally use, and will there be a true sprint, a roll or a dodge, or combat? (CONTROLS has walk, jog, run only; PvP zones are in DESIGN_IDEAS.)
4. How much will combat matter? Melee against players needs server-side hit design (E6, E8) that shapes the swing animation timings.
5. Are horses and mounts, boats, and wall/rope climbing planned for the first playable? (They need poses and attach points.)
6. Character customisation: how much (skin tone, hair, build, face)? Any limits under the "safe place" rule?
7. Should the player's own body be visible in first person (looking down to see feet and clothing), as in Sons of the Forest (F8, snippet)?
8. Hardware floor: still GTX 1050 / 8 GB at 30 fps minimum (BIG_PICTURE.md), Forward+ only?
9. Is Blender (or another DCC tool) available and who will model and rig, or should the body stay generated in code?
10. How does the "Kathleen_ArtisticDirector" role (arts) divide with me on character look, worn items and animal/NPC bodies?

## 7.4 Decisions only Dave can make (with my recommendation)

| # | Decision | Options | Recommendation |
|---|---|---|---|
| D1 | Character look | (a) keep "no features" ragdoll look, only improve motion and joints; (b) stylised human with simple face, hair, hands; (c) detailed realistic | (b) kept simple, but only after Phase 1 and 2 prove the motion. If the answer is (a) Phase 3 shrinks to joints, shoulders and hands |
| D2 | How the body is made | (a) keep generating it in code; (b) model/rig in Blender and import glTF; (c) buy/licence a base and adapt | (b) if a modeller is available, else (a) with soft weights generated by script; avoid (c) unless the licence is clear |
| D3 | First-person approach | (a) arms-only viewmodel (today); (b) full body in first person; (c) arms-only plus lower body when looking down | (a) now, (c) later if wanted. Never two unrelated animation sets: shared action records |
| D4 | Third person priority | first-class vs secondary | first-class for actions (they are cheap once records are shared) |
| D5 | Order of work | the roadmap in 7.1 | Phase 0, 1, 2 first |
| D6 | New movement: sprint, roll, dodge | add or not | not until combat design says so |
| D7 | When other players become visible | before or after Body v2 | after Phase 1 and 2 unless a friend session needs it sooner |
| D8 | Update-rate tiers for far bodies | keep 15/40/70 m tiers | keep, with hysteresis; measure |
| D9 | Customisation scope | none / small / large | small: skin tone, hair, coat colour |
| D10 | Ownership and approvals | which files I may change; whether I may edit shared files `terrain_client.gd` and `held_item.gd`; approval of the passage-removal list in 2.8 | Allow me to extract the avatar and arm logic into a new module with minimal edits to the shared files |
| D11 | Quality bar sign-off | accept the targets in 4.4 or change | accept as tunable defaults |
| D12 | Budgets | triangles/bones/body cost per LOD | set after the Phase 0 measurements, not before (no external number found, H11) |
| D13 | Headline: motion-capture or purchased animation packs | use / don't | consider packs only with BoneMap retarget and licence check; no motion matching (A8) |

## 7.5 What I would do first once Dave approves (RECOMMENDATION)

1. Phase 0 baseline and the AnimationTree prototype (one scratch scene).
2. Phase 1 on the existing body.
3. Show Dave a short side-by-side (stills and a clip) after each of Phases 1 and 2 before spending on Body v2.


---

# Reference sections (appendices)

Parts 2 and 3 follow: the copied project passages and the research log.

# Part 2. Our own documents about the player character

These passages are **copied unchanged** (each line prefixed with "> ") from the source files, which are untouched. Each has its source file, line range and nearest heading. Where the documents disagree, see 2.9. Old agent names: Mandy and Art = the arts director (now Kathleen_ArtisticDirector); Tyler = technical research; Steve = former technical director; Radar/Items = items; "Sonny" inside these passages is the earlier terrain/water agent, not me.

## Passages by topic (B1 to B7 below are 2.1 to 2.7)

### B1. Look, style, proportions and budgets

**Source:** `ART_DIRECTION.md` lines 53-55; under heading: ### 2.7 Character and buildings

> ### 2.7 Character and buildings
> - **Character:** realistic proportions, layered clothes (leather tunic, cloth sash, bracers, boots), rich material detail. This is more realistic than "heroic with a hint of cartoon" (see the open question in Section 5).
> - **Buildings:** log and thatch with mossy thatch, real wood grain. Not in scope yet; noted for later.

**Source:** `ART_DIRECTION.md` lines 82-84; under heading: ## 5. Realism over storybook

> ## 5. Realism over storybook
>
> **[Decided] (owner, 2026-10-20: "to me the picture is right")** The picture is near-photoreal, while the earlier direction (DESIGN_IDEAS Section 1) said "the world looks like the best of old fantasy book illustrations" with slightly cartoonish characters. The picture wins. The world aims for natural, realistic materials and light with warm, rich colour, and "storybook" lives in the colour and mood rather than in painted shapes. The character style is decided in section 10.

**Source:** `ART_DIRECTION.md` lines 107-109; under heading: ## 10. Character look (owner decision, 2026-10-20)

> ## 10. Character look (owner decision, 2026-10-20)
>
> **[Decided]** Characters are slightly stylised: heroic proportions and a hint of cartoon, not realistic, and lighter on older machines (a lower triangle and texture budget than the target picture's character, which was realistic). The world around them stays realistic. This unblocks character model work (Art queue item 7); the budget per character (triangles, bones, texture size, per tier) still goes through the asset budget table with Technical direction before any model is made.

**Source:** `ARCHITECTURE_BUDGET.md` lines 68-68; under heading: ## 5. Modeled and procedural assets

> - **Modeled assets for** the look: hand-made tree, plant, building and character models, several per species, each with 3 or 4 detail levels. Procedural code then picks the model, scale, tilt and tint.

**Source:** `docs/mirror/tech/DECISIONS.md` lines 121-121; under heading: ## 2026-10-21 Ground edits must tell the grass

> - Character bodies for OTHER players need a budget of 1 ms at Low for 20 visible (distance cull, animation LOD); Art's 2-6 ms estimate is too high for the 1050-class minimum.

**Source:** `DESIGN_IDEAS.md` lines 1671-1671; under heading: ### 9.2 Crime memory and delayed discovery

> - **[Proposed]** Characters have a few recognizable features (face, build, hair, clothing, distinctive items). A disguise changes some but not all: clothes and hair are easy to change, height and build are not. Quality depends on disguise skill and materials, rolled on the server. Being caught in disguise can count against the wearer.

### B2. The current character body (as documented)

**Source:** `ART_DIRECTION.md` lines 330-332; under heading: ## 45. Ragdoll character (build 349)

> ## 45. Ragdoll character (build 349)
>
> Owner (2026-10-21): a simple ragdoll-type character, no features. src/client/ragdoll_body.gd builds it in code (17-bone Skeleton3D, one skinned mesh of capsules and boxes in a neutral skin colour, about 1.86 m tall, 1.5k triangles, one draw call, AnimationPlayer with idle walk run crouch sit lie swing jab throw use, a Marker3D mount on each hand for held tools); `Ragdoll.new(true)` is the first-person arms model. Docs: assets/character/README.md; check: tools/check_ragdoll.gd. Cost: no physics bodies and no joints (it is animated, not simulated); only the local player's body exists and only draws and animates in third person (the animation is switched off in first person); the skinned mesh and 18 tracks are well under 0.5 ms a frame on a GTX 1050-class PC by estimate, not measured live. Other players would cost one draw call and one animation player each, about 20 players at a few hundred microseconds each when visible.

**Source:** `ART_DIRECTION.md` lines 369-371; under heading: ## 48. Ragdoll sides (build 354)

> ## 48. Ragdoll sides (build 354)
>
> The rig had its sides swapped (the bone named left sat on +X, which is the right of a body facing -Z). Names now match the body: right is +X, the swing, jab and touch clips use the right arm, held tools go to hand_mount_r.

**Source:** `assets/character/README.md` lines 1-57; under heading: # Ragdoll character

> # Ragdoll character
>
> The plain character (no features): body, head, arms, legs, hands. Built in code by `src/client/ragdoll_body.gd`,
> so there is nothing to import. About 1.86 m tall, 0.26 m half width (the player capsule is 0.35 m), about 3.2 thousand (rounded: ellipsoid torso, head, joints, hands and feet; capsule limbs)
> triangles in one skinned mesh (one draw call), 17 bones, one neutral skin colour. Check: `godot --headless --path . --script res://tools/check_ragdoll.gd`.
>
> ## Use
>
> ```gdscript
> const Ragdoll := preload("res://src/client/ragdoll_body.gd")
> var body := Ragdoll.new()        # full body for third person; feet at the node's origin, facing -Z
> var arms := Ragdoll.new(true)    # first person: only arms and hands, rooted at the chest
> body.play("walk")                # idle walk run crouch sit lie  (loops)  swing jab throw use  (one shots)
> ```
>
> The third-person camera in `terrain_client.gd` already uses it (`_make_avatar`, `_update_view`): the clip follows
> the stance (idle, crouch, sit, lie) and the walking speed (walk, run).
>
> ## Animations (all key every bone, so a switch never leaves a bone in the old pose)
> | name | length | kind | what |
> |---|---|---|---|
> | idle | 3 s | loop | breathing, arms slightly out |
> | walk | 1 s | loop | one cycle = two steps (about 1.6 m of ground) |
> | run | 0.6 s | loop | leaning, bent elbows (about 2.8 m a cycle) |
> | crouch | 2 s | loop | held low |
> | sit | 3 s | loop | seated, hips 0.45 m down, thighs horizontal |
> | lie | 4 s | loop | on the back, head toward +Z, hips 0.18 m up |
> | swing | 0.7 s | once | both hands, over the head and down (axe, pick) |
> | jab | 0.5 s | once | thrust straight ahead (spear) |
> | throw | 0.8 s | once | wind up behind, let go forward |
> | use | 0.6 s | once | reach out and touch, a small push in the middle |
>
> `body.is_one_shot_playing()` says whether a one-shot is still running; `body.current()` is the clip name.
> For a swing in step with a hit, play it at the speed you need: `body.play("swing", 1.3)`.
>
> ## Where the held tool goes (Items: hotbar, equip, held tool)
> `body.hand_mount_r` (and `hand_mount_l`; the rig faces -Z, so the right side is +X and the right hand is the one on the viewer's right in first person) is a `Marker3D` on the hand bone. Parent the tool to it:
>
> * the mount's origin is the grip, in the palm, 7 cm below the wrist;
> * its **-Z axis points out along the fingers** (the way the tool points: a spear tip or an axe head is at -Z);
> * its **+Y axis points forward (-Z of the hand bone) when the arm hangs at the side**, so with the arm hanging a
>   tool's -Z points down along the fingers and its +Y points forward;
>   rotate the tool under the mount if it sits wrong (it is a plain Marker3D).
>
> The same mounts exist on the first-person arms model: `arms.hand_mount_r`. `body.head_mount` is the middle of the head
> (a hat, or a head camera).
>
> ## First person
> `Ragdoll.new(true)` has only the chest as a root and the two arms and hands (7 bones, 480 vertices) and plays the same
> ten animations (the arm tracks of each). Put its origin about 0.28 m below and 0.05 m behind the camera so the shoulders
> sit at the screen's lower corners; the arms hang down along -Y and swing forward along -Z.
>
> ## Changing it
> Bones and shapes are the `BONES` and `PARTS` tables at the top of the script; animations are the `_idle`, `_walk` ...
> functions (a pose per phase, bone name to X/Y/Z radians: for an arm or leg hanging down, + X swings it forward, elbows
> bend with +, knees with -). A modelled replacement can later keep the same bone names and animation names.

**Source:** `docs/mirror/tech/BUILD_LOG.md` lines 51-54; under heading: ## One number ahead (Dave 2026-10-20 23:42: threads must not wait on a number)

> - 346 Ground third-person camera (scroll wheel, placeholder body, zoom saved; controls checked). Ground spare 347 (old 299 void). Next 348.
> - 346 Ground third-person camera pushed (bed68da): one ray per frame, small body draw. Ground holds 347 and 348. check_controls fails on Tab (Items b0c856a): Items to fix. Next 349.
> - 349 Art ragdoll character (ragdoll_body.gd, check_ragdoll.gd; replaces Ground's third-person placeholder body). Art spare 350. Next 351.
> - 349 Art character body pushed (790ce06): animated skeleton (not ragdoll physics), 17 bones, 1.5k tris, 1 draw, <0.5 ms for the local player; 20 players est. 2-6 ms CPU. CONDITION for other players' bodies: distance cull plus animation LOD, budget 1 ms at Low for 20 players, re-measure first.

**Source:** `docs/mirror/tech/BUILD_LOG.md` lines 59-60; under heading: ## One number ahead (Dave 2026-10-20 23:42: threads must not wait on a number)

> - 344 Items first-person arms hold the tool (Art's Ragdoll.new(true) on hand_mount_l); HUD stays at upstream 353. Items holds 329, 330, 337, 338, 339, 351, 352.
> - 354 Art ragdoll sides fixed (right is +X, hand_mount_r; held_item.gd and inventory_view.gd changed in same commit). Art holds 355.

**Source:** `docs/mirror/tech/JOBS.md` lines 320-320; under heading: ## Note to Art from Items (2026-10-21T03:50:25Z)

> Arms wired (3b437ce): held_item.gd adds Ragdoll.new(true) as camera child 'Arms' and parents tools to hand_mount_l, because in the rig 'left' is +X which appears on the viewer's right (facing -Z, +X is the character's right), so left and right look swapped: please check the naming. Boulders: Dave's card is open; keep your scenery until he picks.

**Source:** `docs/mirror/tech/JOBS.md` lines 398-398; under heading: ## Moves awaiting Steve (Dave 2026-10-21 20:54: Steve approves every "set aside and move on")

> - Mandy (Arts): src/client look and view files (flora, tree, grass_view, sky, weather look, water_material.gd and fall_mist.gd shaders, character/ragdoll, npc_view and animal_view looks, building/forge looks), assets/, art/, sound code and data, ART_DIRECTION.md.

### B3. Movement, gaits, stance and exertion

**Source:** `CONTROLS.md` lines 17-17; under heading: ## Now (terrain client, build 23)

> | (automatic) | Very slight camera bob and sway when moving on the ground, in step with the feet: down and leaning to the stepping side at each footfall, back up in between. Strides are longer when jogging (4.2 m) and running (6 m) than walking (3 m) |

**Source:** `CONTROLS.md` lines 26-26; under heading: ## Now (terrain client, build 23)

> | C | Crouch (toggle): lower eye, slower; kept while moving |

**Source:** `CONTROLS.md` lines 68-73; under heading: ## Now (terrain client, build 23)

> Gait rules:
> - Minecraft style: double-tap W toggles jogging on, and Shift adds running while held.
> - Letting go of Shift drops back to jogging (if on) or walking. Only letting go of W drops back to walking.
> - Walking shows no label. Jogging shows "Jogging". Running shows "Running".
> - Other status words (underwater, waiting for ground) still show.
> - Flying is an admin look-around tool (noclip). Shift multiplies flying speed.

**Source:** `CONTROLS.md` lines 86-86; under heading: ## Planned / not decided

> - Stances (Dave, 2026-10-20, decided, build 229 Ground thread, not built yet): C = crouch, X = sit, Z = lie down, all toggles; any movement key stands you up. No movement while sitting or lying. Admin dig moves from X to Ctrl+X (the table row for X changes when it lands).

**Source:** `CONTROLS.md` lines 94-94; under heading: ## Planned / not decided

> - Rest (Ground adds the keys: C crouch, X sit, Z lie, all toggles; any movement key stands you up): sitting or lying brings exertion down to 0, lying fastest; standing under a heavy pack only rests it to about half. Over-exerted: about 10 percent slower (tunable over_speed_factor in exertion.json) but you can keep running and keep pushing until you black out. Past the faint threshold you black out smoothly, not in steps: right at the threshold it takes about 14 s and you lie down at the end, and the further over you push the faster it comes on (about 1.5 s a long way over). The heart beats about 175 bpm at the threshold and 200 at the peak of a blackout; there are no breathing noises. Then you wake slowly.

**Source:** `ITEMS_DESIGN.md` lines 66-67; under heading: ### Stance and rest (protocol 21)

> ### Stance and rest (protocol 21)
> ACT_STANCE (20, a = 0 stand, 1 crouch, 2 sit, 3 lie); the server's answer is the new last field of strain(). Fainting forces lying and a fainted or waking player cannot choose; walking off faster than 1.5 m/s stands a sitting or lying player up. Strain rests faster sitting (x2) and lying (x3) with no floor, so it reaches 0; standing or crouching under a heavy pack only rests down to about half (floor 0.5 x load ratio). A pack adds load_effort x ratio^1.5 to the effort of anyone moving, even at the crawl a full pack allows (min speed 25 percent), so a pack at the limit tires you quickly. Client: items.request_stance(s), items.stance_confirmed, items.stance_event (Ground owns keys C crouch, X sit, Z lie and the camera height).

**Source:** `PROTOCOL.md` lines 65-65; under heading: ## Inventory action kinds (inventory_action(kind, a, b, count, at))

> | 20 | ACT_STANCE | a = wanted stance: 0 stand, 1 crouch, 2 sit, 3 lie; the server answers in strain() | 21 |

**Source:** `DESIGN_IDEAS.md` lines 959-961; under heading: ### 6.16 Exertion, fitness and health (brainstorm)

> - **[Idea] (brainstorm)** **Three physical measures: Health, Exertion, Fitness.** Health is injury and damage. **Exertion** is the strain right now, rising and falling all the time (conceptually 0 to 100 percent). **Fitness** is longer-term conditioning. Exertion **replaces** a classic stamina pool; there is no separate stamina bar next to it (matches "no permanent bars" in Section 6.14: the numbers live on the character screen, in play the body tells you).
> - **[Idea] (brainstorm)** **Activities raise exertion at their own rates.** Walking and resting let it recover. Jogging, running, sprinting, fighting, swimming (faster swimming more), heavy physical work and other hard effort raise it. Fitness changes how much each activity raises it, how fast it drops, and **how high an activity can be sustained**: a very fit runner can jog or run a long way at a steady elevated exertion well below collapse (perhaps slowing a little), while sprinting stays above anyone's sustainable level and in the end drives even that runner to severe exhaustion. An unfit character is winded jogging and must sit after a short sprint.
> - **[Idea] (brainstorm)** **Escalating forced slowdown:** slight slowdown, stronger slowdown, severe exhaustion barely faster than walking, then stumbling and collapse. Exertion can force a lower real speed even while the player keeps asking for a jog, run or sprint. Collapse is gradual (staggering, slow fainting), and during unconsciousness the player hears breathing and heartbeat settle until control returns. Collapse from exertion is **not** combat damage and never kills; it meets the rescue layers in Section 6.5.

**Source:** `DESIGN_IDEAS.md` lines 967-969; under heading: ### 6.16 Exertion, fitness and health (brainstorm)

> - **[Idea] (brainstorm)** **Breath and heartbeat follow physical exertion only, not fear (owner, for this proposal).** Low exertion is subtle or silent, severe exertion brings loud fast breathing and a strong heartbeat, and near collapse the ears ring and outside sound muffles. Players can hear exertion climb and recover, and footstep spacing slows in step with forced slowdown.
> - **[Decided] (owner, 2026-10-17)** Breathing and heartbeat follow **exertion only** for now. Later, fear and pain may add adrenaline that affects them, but not yet.
> - **[Decided] (owner, 2026-10-17)** **Stamina is no longer a metric.** When these ideas are built, they **replace** the old stamina system everywhere it is mentioned (altitude Section 4.5, flu Section 8.1, marrowroot `stamina` property, 6.14 endurance text).

**Source:** `DESIGN_IDEAS.md` lines 940-940; under heading: ### 6.14 Senses, thoughts and the minimal HUD

> - **[Idea] (brainstorm)** **Instincts** (trained reflexes): a veteran shifts stance, turns a torch toward a sensed flanker, guards an open side or steadies their breath; a hunter drops low. Reflexes help, never replace, the player: no spending valuable items, big moves or spells on their own.

**Source:** `DESIGN_IDEAS.md` lines 985-985; under heading: ### 6.17 The sound stage (brainstorm)

> - **[Idea] (brainstorm)** **Footsteps follow the feet.** Walking uses short strides, jogging longer, running longer again, with cadence following speed; a forced exertion slowdown changes the spacing to match. Surface-dependent sound triggered by foot contact, not a timer. The camera bob already works this way: stride 3 m walking, 4.2 m jogging, 6 m running (build 23), with a footfall at each step phase. The same step phase can fire the footstep sounds. **[Open]** surface tagging, what is sent over the network (footsteps of other players are played locally from their reported movement), and cost.

**Source:** `docs/archive/2026-10/docs/mirror/tyler/BEST_PRACTICES.md` lines 99-109; under heading: ## Character animation (decision for Dave's question, 2026-10-21)

> ## Character animation (decision for Dave's question, 2026-10-21)
> FINDING FIRST: it is not a mesh problem. src/client/ragdoll_body.gd already has a 17-bone skeleton with separate arm/forearm, thigh/shin/foot bones and keyframed clips (idle, walk, run, crouch, sit, lie, swing, jab, throw, use). Knees (shin -0.7 rad walk, -1.5 run), elbows (forearm +0.3 walk, +1.3 run) and opposite arm/leg swing are already keyed, and terrain_client.gd:2079-2088 plays walk/run by speed and scales the cycle to ground speed. So what Dave saw is probably: (a) flying or admin mode shows idle; (b) first person hides the body (animation off by design); (c) OTHER players and NPCs: src/client/npc_view.gd has no animation calls, so they likely stand stiff. Ask Mandy to check (c) first with a still of a walking NPC and another player.
> RECOMMENDATION (keep it cheap, one approach): keep baked keyframe clips in an AnimationPlayer/AnimationTree, not physics ragdoll, not full IK.
> 1 Blend by speed: AnimationTree with a BlendSpace1D idle-walk-run (and one-shot nodes for swing/jab/throw/use) instead of hard clip switches, so starts and stops are smooth; stride-matched speed scale (already there) to avoid foot sliding; walk cycle ~1.6 m, run ~2.8 m.
> 2 Polish the clips (data only): knee bend peaks 40-60 deg walk and 80-100 deg run on the swing leg, elbow 15-30 deg walk and 70-90 deg run, arm swing opposite to the leg, 5-8 deg torso counter-twist, 2-3 cm hip bob at double frequency, slight forward lean in run, heel-first foot roll.
> 3 Additive procedural layer on top (a few lines per frame, local player and visible others only): lean into acceleration and turns, head look toward interest (+-40 deg, low-pass), arms hold the tool pose when something is held, a tiny breathing motion at idle (scale 1.0-1.01) and heavier chest motion when out of breath or over-exerted (links to the exertion vital).
> 4 Foot placement: skip IK for now; if feet float on slopes later, add a 2-bone IK for legs only within 20 m.
> 5 Network: send only velocity, stance and one-shot action ids; each client derives the animation (no bones on the wire).
> 6 Budget for 20 visible bodies at Low (Steve's 1 ms): update animation full rate within 15 m, 15 Hz from 15-40 m, 5 Hz from 40-70 m, frozen idle pose beyond 70 m and hidden beyond the player draw range; one skinned mesh and one draw per body (already so).
> 7 Sources: Godot AnimationTree/BlendSpace1D is the standard speed-blend tool; stride-matching and additive layers are standard practice in character animation. I did not find a single authoritative source worth citing for the numbers; they are typical human gait ranges and should be tuned by eye.
> Hand to Mandy (owner of the character model).

**Source:** `docs/archive/2026-10/docs/mirror/tyler/BEST_PRACTICES.md` lines 130-152; under heading: ## Natural walk, jog, run: numbers for the ragdoll (for Mandy, Dave's request 2026-10-21)

> ## Natural walk, jog, run: numbers for the ragdoll (for Mandy, Dave's request 2026-10-21)
> Sources: only the walk-run transition at Froude number about 0.5 is sourced ([Kram et al. via PMC, Apollo Number paper](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2719915/), [Kram 1997 gait transition](https://sites.utexas.edu/neptune/wp-content/uploads/sites/6031/2020/07/jeb2085.pdf)); my search found no source for the other values, which are typical adult gait-lab ranges from memory: tune by eye, they are targets not laws.
> Body: 1.8 m, leg length about 0.9 m. Transition speed = sqrt(0.5 x g x leg) = about 2.1 m/s (so 2.0-2.2 m/s is where walk becomes jog; a walk faster than that looks like race-walking).
> | | Walk | Jog | Run | Sprint |
> |---|---|---|---|---|
> | Speed m/s | 1.0-1.8 (typical 1.4) | 2.2-3.5 | 3.5-6.5 | 7+ |
> | Cadence steps/min | 100-120 | 150-165 | 165-180 | 190+ |
> | Step length m | 0.65-0.8 | 0.9-1.2 | 1.2-1.6 | 1.8-2.2 |
> | Forward trunk lean | 1-3 deg | 4-7 | 8-12 | 15-20 |
> | Vertical bob (peak to peak) | 3-5 cm | 6-8 cm | 8-10 cm | 10-12 cm |
> | Hip swing (flexion/extension) | +25/-10 | +35/-15 | +45/-20 | +55/-25 |
> | Knee peak (swing phase) | 60 | 90-100 | 105-120 | 125+ |
> | Knee at foot strike/stance | 15-20 | 35-40 | 40-45 | 45 |
> | Elbow bend | 15-30 (varies a little) | 60-80 | 80-95 | 90-100 |
> | Shoulder arm swing | +-15-20 | +-30 | +-40-50 | +-60 |
> | Pelvis rotation / shoulder counter-rotation | +-4 / +-6 | +-5 / +-9 | +-6 / +-12 | +-8 / +-15 |
> | Stance share of cycle | 60% (double support) | 40% | 35% | 30% (flight phases) |
> Rules of motion: the lean is a rotation of the whole spine/chest forward, increasing with speed and with acceleration (add 3-5 deg while speeding up, lean back 2-3 deg when stopping); bob has two peaks per stride (one per step) and the lowest point is at mid-stance for walk, the highest at mid-flight for run; arms swing opposite to the same-side leg; shoulders counter-rotate against the pelvis; head stays level (counter the bob and lean by rotating the neck/head back to look at the horizon); in run, a flight phase where both feet are off the ground for ~10-15% of the cycle (a tiny hop in the body height curve, not only a leg change); foot placement lands heel-first walking, mid/fore foot running, toe-off pushes the body up.
> Stride and speed: do not just speed up the same clip. Blend clips by speed on a BlendSpace1D (idle 0, walk 1.4, jog 3.0, run 5.0 m/s) and scale playback only within each clip's range (walk 1.0-1.8, jog 2.5-3.5, run 4-6.5) so the step length grows with speed (about step length = 0.415 x height at a walk, growing to about 0.8-0.9 x height at a run) rather than the legs spinning faster. A jog clip is missing today (idle, walk, run only): add it.
> Slopes: on an uphill lean the body forward by about the slope angle (cap 25 deg) and shorten the steps 10-15%; downhill lean back 3-6 deg, shorten the steps, bend the knees 10 deg more; cross-slope no change. Stairs/steps: knee lift to 60+ deg on the lead leg. Sideways strafe and backward: half stride length, no run clip (use the walk clip) and lean toward the move direction by 1-2 deg.
> Where the current clips stand (ragdoll_body.gd, read at head): walk thigh +-0.5 rad (+-29 deg, a bit wide), shin 0.7 rad (40 deg, low; use 1.0), forearm fixed 0.3 rad; run thigh +-0.9 rad, shin 1.5 rad (86 deg, ok), forearm 1.3 rad (74 deg); no forward lean beyond 3 deg, no flight bob in run, no jog, walk-to-run switch at 7 m/s in terrain_client.gd:2082 (should be about 2.1 m/s for the walk-jog change; check what speeds the game uses for walk and sprint before copying my numbers).
> Footsteps: key the sound and any dust/grass hook on the foot-plant frame of the clip (not a timer), so the audio matches the visible step; and add a small camera bob in first person at the same rate (2-3 cm walk, 4-6 cm run), reduced for comfort.
> Cost: all clip data plus a few lines for lean, head counter-rotation and slope; nothing per bone beyond what runs today.

**Source:** `docs/archive/2026-10/docs/mirror/tyler/FINDINGS.md` lines 215-222; under heading: # Report 13 (2026-10-21): build 465 walk/jog/run against my table (ragdoll_body.gd _gait, terrain_client.gd:2179-2193)

> # Report 13 (2026-10-21): build 465 walk/jog/run against my table (ragdoll_body.gd _gait, terrain_client.gd:2179-2193)
> Good: lean (2.0 / 5.7 / 10.3 deg across spine, chest and head, head counter-rotated), knee swing peaks (60 / 95 / 109 deg), knee at plant (17 / 37 / 43 deg), elbows (23 / 69 / 86 deg), bob (4 / 6 / 9 cm peak to peak at two per stride), shoulder/pelvis counter-rotation, hysteresis on the clip switch and a jog clip. All match my targets.
> Mismatches:
> 1 SPEEDS (the big one, a Dave decision): the game's WALK_SPEED is 6.0 m/s, JOG 8.5, RUN 11.0 (terrain_client.gd:121-124), while the clips were built for 1.4 / 3.2 / 6.0 m/s. Clip selection is by real speed (run clip above 5.0 m/s), so plain walking plays the RUN clip at 1.0x, jogging plays it at 1.42x and running at 1.83x (limit 2.0), about 366 steps/min: legs flail, and the walk and jog clips are only seen at low speed (crouch, slope, over-exertion). Real walking is 1.4 m/s; survival games usually set walk about 3-4, run about 6-7, sprint 8-9 m/s. Options: (a) lower the game speeds (e.g. 3.5 / 5.5 / 8) and use my natural speeds; (b) keep the speeds and add a SPRINT clip for over 7 m/s (thigh +-0.8 rad, lean 15-20 deg, flight phase) and cap playback at 1.25x so cadence stays under 190 steps/min, then treat 6 m/s as the "run" clip, 8.5 as sprint; (c) keep as is (it reads as constantly sprinting). I recommend (a) for feel and balance (also keeps footstep sounds and exertion believable); it is a design call, so ask Dave once.
> 2 Amplitudes slightly wide: thigh 0.45/0.75/1.0 rad (26 / 43 / 57 deg) against my +-26 / +-32 / +-38; arm 0.5/0.8/1.0 rad (29 / 46 / 57 deg) against 15-20 / 30 / 40-50. Trim to thigh 0.45 / 0.6 / 0.75 and arm 0.3 / 0.5 / 0.8 unless a longer stride is wanted for the fast speeds.
> 3 Missing: a flight phase in run (body height curve has no airborne hop; add +3 cm for 10-15% of the cycle), slope lean (uphill by slope angle up to 25 deg, back 3-6 deg downhill), lean into acceleration (+3-5 deg) and a stop lean, backwards and strafe clips (use walk at half stride), footstep audio and grass hooks keyed to the foot-plant frame.
> 4 Remote players and NPCs: unchecked whether they run these clips (npc_view.gd has no play calls in my earlier read; recheck).

### B4. Camera, first person and third person

**Source:** `CONTROLS.md` lines 10-10; under heading: ## Now (terrain client, build 23)

> | Wheel (mouse) | Scroll out (wheel down) from first person to third person: the camera moves up and back a little at each step (1.6 m to 7 m behind, 0.4 m a step); in third person scrolling out pulls further, scrolling in comes closer and, past the nearest step, back to first person. The distance is remembered between sessions (`user://view.txt`); you always start in first person. The camera pulls in when a wall, the ground or a trunk is in the way. Works while flying. A plain placeholder body is drawn until there is a real character. Only while the mouse is captured (menus and the inventory keep their own scrolling) |

**Source:** `docs/mirror/tech/BUILD_LOG.md` lines 51-52; under heading: ## One number ahead (Dave 2026-10-20 23:42: threads must not wait on a number)

> - 346 Ground third-person camera (scroll wheel, placeholder body, zoom saved; controls checked). Ground spare 347 (old 299 void). Next 348.
> - 346 Ground third-person camera pushed (bed68da): one ray per frame, small body draw. Ground holds 347 and 348. check_controls fails on Tab (Items b0c856a): Items to fix. Next 349.

**Source:** `docs/mirror/tech/CAMERA_TURN_RECIPE.md` lines 11-11; under heading: ## The recipe (one change, three parts)

> C0. **Third person and subject shots must NOT turn the body** (Dave watching Mike's run, 25 Oct 01:42): `_side_view()` in shot_runner.gd (line 847) places view_cam with the BODY's basis (`left = body.global_transform.basis * (-1,0,0)`), so any body turn turns the camera with the character and every picture is the same. Replace it with a world-space orbit: `angle = start_angle + k * PI/2` (k = 0, 1, 2); `view_cam.global_position = subject + Vector3(sin(angle) * dist, height, cos(angle) * dist)`; `view_cam.look_at(subject + Vector3(0, aim_height, 0), Vector3.UP)`. The character stays put, the camera goes round it, same distance and height. Read back the camera position and heading toward the subject (each view differs by 90 degrees around the subject, distance equal within 5 cm), not the body yaw. Subject = the character (third person), a tree, a shrub, the ground item group, or the placed piece. In shot mode the player camera is hidden/unused for these shots (client.third_person = true already does this).

**Source:** `docs/mirror/tech/STANDARD_SHOTS.md` lines 15-15; under heading: ## STANDARD SET v3 (Dave 25 Oct 01:26: "only take 3 shots and rotate left 90 degrees after each shot")

> - **SUBJECT spot** (the picture is of a thing: a tree, shrub, ground items, a placed piece, or the character in third person): the thing stays put and the CAMERA ORBITS it, 90 degrees around per shot at the same distance and height, always looking at the subject (a, b = 90 degrees, c = 180 degrees around). K03, K04, K05, K06, K11, K12, K13, and any third-person shot of the character. Turning the body is never used for these: it would swing the view away from the subject, or (third person) turn the camera with the character.

### B5. Hands, held items, tool and weapon use

**Source:** `ITEMS_DESIGN.md` lines 131-133; under heading: ## First-person arms (2026-10-21)

> ## First-person arms (2026-10-21)
>
> held_item.gd puts Art's first-person arms (`Ragdoll.new(true)`) on the camera (ARMS_POS, ARMS_PITCH_DEG; hidden in third person via `set_first_person`). The held spear, axe, knife or torch is parented to `hand_mount_r`, the hand on the viewer's right (the rig's right is +X, naming fixed in build 354), with the grip at the mount origin and the tool tipped TOOL_TILT_DEG up. Left click plays swing (axe), jab (spear) and throw on the arms, timed to the existing hit timers; otherwise idle. Without arms the old offsets are used. Placeables and other kits are not drawn in the hand yet. The pose was checked in software-rendered stills (idle, jab, swing), not on a real GPU: ARMS_POS, ARMS_PITCH_DEG, TOOL_TILT_DEG and GRIP_ALONG_Y are the knobs.

**Source:** `DESIGN_IDEAS.md` lines 568-568; under heading: ### 5.3 Crafting

> - **[Decided]** **Spear controls (owner, 2026-10-20):** held and jabbed by default with the normal attack keys. Hold right click to raise it and aim a throw, then left click throws it. Letting go of right click returns to the normal stance.

**Source:** `CONTROLS.md` lines 52-52; under heading: ## Now (terrain client, build 23)

> | Right click (hold) | Spear: aim a throw; then left click throws. Letting go returns to the normal stance |

**Source:** `CONTROLS.md` lines 88-88; under heading: ## Planned / not decided

> - Spear (Dave, 2026-10-20, decided, not built): normal attack keys jab; hold right click to raise and aim a throw, left click throws, release right click returns to normal stance.

**Source:** `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_held_tools_pose_heads.md` lines 1-8; under heading: # Held tools: pose, saw shape, tool heads (Kathleen, 25 Oct)

> # Held tools: pose, saw shape, tool heads (Kathleen, 25 Oct)
> From Mike's hands10 pictures (results/20261025_hands10). One branch claude/kathleen-held-pose, RUNTIME, three small commits:
> 1. Third-person pose in held_item.gd (_mount_model_third): tool out to the side and slightly forward, grip on the handle, head forward of the skull (today it slants back behind the neck, handle hidden behind the leg).
> 2. New "saw" shape in basic_look.gd (long thin toothed blade, pistol grip); looks.json hand_saw switches from "spade" to "saw" (data/items/looks.json one row; Sal owns the file, one-line change).
> 3. Better tool heads in basic_look.gd: axe/hammer chipped tapered stone with lashing; pickaxe swept head with two points.
> Not mine: shore net and torch head (Sal). Tests: check_look_names, headless mesh build, David3 hand pictures again (K-set) and a QA look card.
>
> Update 25 Oct: part 1 = commit 3af62551 (heads, saw, hammer). Part 2 (pose) = its own commit 1c089053 (third-person lean 78 deg, grip choke 0.6), revertable alone.

**Source:** `docs/archive/2026-10/docs/mirror/tyler/FINDINGS.md` lines 495-523; under heading: # Report 26 (2026-10-21): the first-person axe chop looks wrong (Dave): how a real chop moves, how FPS games animate it, a keyframe table, and why ours is off. Read from src/client/held_item.gd (SWING_S 0.55, ARMS_POS (0,-0.1,-0.15), ARMS_PITCH 50 deg, TOOL_TILT 20 deg, strike fired at 0.5 x SWING_S) and ragdoll_body.gd `_swing` (shared by first and third person). I have not seen a render of the chop.

> # Report 26 (2026-10-21): the first-person axe chop looks wrong (Dave): how a real chop moves, how FPS games animate it, a keyframe table, and why ours is off. Read from src/client/held_item.gd (SWING_S 0.55, ARMS_POS (0,-0.1,-0.15), ARMS_PITCH 50 deg, TOOL_TILT 20 deg, strike fired at 0.5 x SWING_S) and ragdoll_body.gd `_swing` (shared by first and third person). I have not seen a render of the chop.
> ## 1 How a real chop looks (felling or splitting with an axe; references: woodcutting form guides, biomechanics of axe swing, game viewmodel practice)
> Phases: (a) anticipation / backswing: the axe is lifted up and back, elbows bend, wrist cocks so the head tilts behind the hands, weight goes back slightly, eyes stay on the cut; (b) a brief pause at the top (20-40 ms); (c) downswing: shoulders and hips rotate forward and the arms accelerate in an arc, the wrist uncocks late (the flick) so the head is fastest at the end; (d) impact at roughly chest height or below, hands in front of the body, arms nearly straight, blade at about 45 degrees to the trunk (for felling, alternating upper and lower cuts), the head stops dead; (e) follow-through is short, then recovery by pulling the axe out of the wood (a tug back) to the next backswing.
> The path is mostly VERTICAL in the plane facing the tree: over the shoulder and down in front, with a 15-25 degree diagonal (right-handed: top right to centre-left). It is not a horizontal sweep (that is a bat or scythe).
> Two-hand grip (felling axe): off-hand (left for a right-hander) at the butt end, dominant hand (right) higher; on the downswing the right hand slides down the shaft towards the left, ending close to it at impact. One-handed hatchet: grip stays put, more wrist, much less shoulder.
> Timing for a 0.55 s chop (normal pace): backswing 40% (0.22 s) eased out, pause 5% (0.03 s), downswing 18% (0.10 s) eased in (fast), impact + hit stop 8% (0.04 s), recovery 29% (0.16 s). Hit damage, sound, particles on the impact frame (0.35 s), not before.
> ## 2 How good first-person games do it (Skyrim, Valheim, Rust, Minecraft-like viewmodels)
> A dedicated viewmodel animation, authored in camera space (positions relative to the camera, hands and tool only, usually the lower right of the screen), separate from the third-person body animation; the camera never turns with the body twist; hands stay mostly in view during the wind-up (they rise into the top-right corner, the tool head visible, they do not go behind the camera); small camera motion supports it: a 1-2 degree pitch up in the backswing and a 2-3 degree dip with a short shake on impact; hit stop (freeze 40-60 ms) and a 2-3 cm recoil of the tool sell the weight; left hand only appears when it holds something (Dave's rule): either grips the shaft (two-hand tools) or is out of view.
> ## 3 Keyframe table (right hand, camera space, metres; camera x right, y up, -z forward; shoulder at about (0.22, -0.20, -0.10); arm length about 0.65 m; times at SWING_S = 0.55 s)
> | t (s) | phase | hand position | elbow | wrist | axe head direction | body and camera |
> |---|---|---|---|---|---|---|
> | 0.00 | rest | (0.30, -0.42, -0.50) | 40 deg | 0 | up-forward 20 deg | 0 |
> | 0.22 | backswing top, ease-out | (0.28, -0.05, -0.20) hand at the upper right of the view, about eye level or slightly above, not behind the camera | 110 deg | cocked back 60 deg | up and back (about 120 deg from forward) | lean back 4 deg, twist right 6 deg, camera pitch +1.5 deg |
> | 0.25 | pause at the top | same | same | same | same | same |
> | 0.31 | mid downswing | (0.15, -0.20, -0.45) | 60 deg | 40 deg cocked, uncocking | about vertical down-forward | twist 0, pitch 0 |
> | 0.35 | IMPACT | (0.05, -0.38, -0.65) hand centre-right of the screen, near chest height, arm almost straight | 25 deg | uncocked, 0 to +10 deg | forward-down 45 deg into the target | lean forward 6-8 deg, twist left 6 deg, camera pitch -2.5 deg plus 0.5 deg shake |
> | 0.39 | hit stop ends; recoil 2-3 cm back | (0.06, -0.38, -0.62) | 30 deg | 0 | same | same |
> | 0.47 | recovery | (0.22, -0.34, -0.50) | 45 deg | 0 | up-forward | easing to 0 |
> | 0.55 | rest (or the next backswing if the button is held, start the next backswing from t=0.47 pose so chains do not return to rest) | rest | | | | |
> Left hand: out of view, or if the tool is two-handed it shadows the shaft: rest (0.05, -0.50, -0.40) at the butt end, and at impact (0.02, -0.45, -0.55); otherwise hidden below the screen edge.
> Axe in hand: handle runs from the palm forward; head leads at impact; tool tilt TOOL_TILT 20 deg is the REST pose only: during the swing the wrist rotation should add up to about 60 degrees back and then +70 forward (the table). Interpolate positions with a Bezier or an overshoot-free spline (arc, not a straight line between keys), and rotation with spherical interpolation.
> Rig translation (tune on the stills): in your rig use arm x about 0.9 at rest, about 2.2 at the backswing top (not 2.6: that points behind the camera), about 1.1 at impact; lateral arm z about +0.2 at the top and -0.15 at impact (not +0.55 to -0.45); forearm 0.8 / 1.9 / 0.45; plus a keyed hand_r wrist of -1.0 / -0.2 / 0.1 (a wrist key does not exist today).
> ## 4 The three most likely reasons it looks wrong with our rig
> 1 NO WRIST AND A WRONG SWING PLANE: `_swing` keys the shoulder, elbow, spine twist and lean, but nothing on hand_r, so the axe stays rigidly in line with the forearm like a stick; and the lateral arm value runs from +0.55 to -0.45 rad (a 57 degree sideways sweep), which makes a horizontal wave across the screen instead of an over-the-shoulder vertical chop. Fix: add a wrist track (cock to uncock) and cut the lateral component to about +-0.2.
> 2 THE THIRD-PERSON CLIP IS DRIVING THE FIRST-PERSON ARMS: the same `_swing` clip (body twist -0.5 to +0.45 rad = +-28 degrees, lean 0.4 rad, hips move) rotates the chest that the first-person arms hang from, while the camera does not rotate. The viewmodel therefore sweeps sideways and rolls, and the 2.6 rad backswing (149 degrees) with the arm root 0.15 m BEHIND the camera and pitched 50 degrees sends the hand up and behind the lens so it vanishes and pops back in. Fix: a separate first-person clip (camera-space table above, twist and lean at most 6-8 degrees, no hips) and keep the hand in view through the backswing; the third-person clip can stay.
> 3 TIMING AND EVENTS: the hit event is fired at 0.5 x SWING_S (0.275 s) while the clip's peak impact key is at phase 0.55 (0.30 s), so sound and damage lead the visual, and the downswing/recovery eases are linear keys (`_keys`), so it moves at constant speed and has no snap; the impact has no hit stop, no recoil, no camera dip, and the left arm waves forward ('steady' 1.3 rad) while the axe is held in one hand only, which breaks Dave's rule that the left hand moves only if it holds something. Fix: fire the event at the impact key (0.35 s of 0.55), ease the downswing in (accelerate) and the backswing out, add 40-60 ms hit stop, a 2-3 cm recoil and a small camera dip, and park the left arm out of view.
> Also the old non-mounted fallback in `_process_body` (model position and rotation.x lerps) is a different motion; make sure it is off when the model is mounted, or it will fight the arm clip.
> Owner: Mandy (first-person clip and wrist track), Radar (held_item.gd event timing if he owns it: confirm with Steve's file map: held_item.gd is client look, so Mandy).

**Source:** `docs/mirror/tech/BUILD_LOG.md` lines 306-306; under heading: ## One number ahead (Dave 2026-10-20 23:42: threads must not wait on a number)

> - 05:00 Radar: 612 (torch and other held items now show in the body's right hand in third person (light and model no longer vanish); a drop is refused only when 64 loose dropped items lie within 12 m (trunks, stumps, fires, structures no longer count); server restart needed)

**Source:** `docs/mirror/tech/BUILD_LOG.md` lines 333-333; under heading: ## One number ahead (Dave 2026-10-20 23:42: threads must not wait on a number)

> - 06:45 Radar: 638 (third person: torch, axe and knife are held by the handle end, not the head; the grip offset had the wrong sign; client only)

**Source:** `docs/mirror/tech/BUILD_LOG.md` lines 254-254; under heading: ## One number ahead (Dave 2026-10-20 23:42: threads must not wait on a number)

> - 23:55 Mandy: 559 (shoulder log carry: carry_idle and carry_walk clips (right arm over the log, empty left hand at rest, forward lean, slow roll), log on the shoulder in third person and at the edge of the view in first person; runtime only, client)

**Source:** `docs/mirror/tech/SCALE_PLAN.md` lines 138-138; under heading: ## 11b Who handles what: server or client, per feature (the centre of the plan; "cost at 1000" is per second across the whole world, est.)

> | Chopping, gathering | S | drops and tree HP are economy | swing animation, hit sound/particles, predicted impact only | hit-spam (limit by tool rate), reach/line-of-sight cheat; server must own loot rolls (luck.gd) | per hit < 0.2 ms after limit; felling broadcasts via AoI |

### B6. Clothing and equipment visuals

**Source:** `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_worn_clothing.md` lines 1-17; under heading: # Kathleen: worn clothing meshes (goal 1f, all clothing items in one plan)

> # Kathleen: worn clothing meshes (goal 1f, all clothing items in one plan)
> Goal: every wearable item (hide_cloak, hide_boots, hide_hood, hide_mittens, hide_leggings, grass_skirt, grass_cloak, fibre_sandals, backpack) has a worn mesh per body slot for NPC/remote-player bodies (npc_view._make_body) so worn clothing shows.
> Files: new src/client/worn_look.gd (builders per slot: cloak, hood, boots, mittens, leggings, skirt, sandals, pack), data/items/worn.json (item -> slot, builder, colour), small hook in npc_view._make_body (Steve owns the worn-clothing sync/protocol; I only supply meshes + the attach function).
> How: parametric box/cylinder builders attached to body parts by slot; cached meshes; shared material; under 150 triangles per piece.
> Test: headless build + counts; Mike picture of one dressed body per item. Label RUNTIME. Needs Dave: none.
>
> ## Tyler reply (02:45 UTC 24 Oct, once; BP-T52). GO, branch claude/kathleen-worn-clothing, label RUNTIME. All clothing in this one plan is right.
> Best-practice suggestions:
> 1. **Slot anchors, not body hacks.** Attach each piece to a named anchor (head, torso, upper arm, hand, thigh, shin, foot, back) on the body, and have the body publish those anchors (Node3D markers or bone names) in ONE place. Your attach function reads the anchor by slot name from worn.json. If the body has no such anchor yet, add the markers in the body builder in a tiny change and tell Steve. Never position by magic numbers in each builder.
> 2. **Data-driven, one row per item.** worn.json: item id, slot, builder, colour, scale, optional second anchor (boots use both feet, mittens both hands). A new wearable = one JSON row. Validator (Python, called from merge_check): every item with a worn slot in items data has a worn.json row, every row names a real item and a known builder.
> 3. **Fit by proportion, not fixed size.** Builders take body dimensions (shoulder width, leg length, head size) from the body so different characters (the character screen) and heights fit; clamp the scale range. Check at the extremes of the character screen sliders.
> 4. **Layers and conflicts.** Define slot layers (underwear/base, clothing, outer, pack) so a cloak over leggings does not z-fight or clip; give each layer a small outward offset (1-2 cm) and let the cloak hang off the shoulders with a slight flare. Hood up or down is a parameter if the design asks; default down.
> 5. **Cached and cheap.** One ArrayMesh per (builder, params) cached; shared materials per colour key; under 150 triangles per piece and a total cap of about 600 for a fully dressed body. Remote players are many: pieces beyond about 30 m use no detail pieces (no mittens or straps), same switch as the body LOD.
> 6. **Sync is Steve's.** You supply meshes + the attach function; the protocol for other players' worn clothing (a bump in the protocol number, claimed in ID_CLAIMS.md) is Steve's. Make the attach call take a list of item ids so his sync code calls it once with whatever the server sends. Until his sync lands, show the local player's worn items in the character screen preview so you can test without the network.
> 7. **Look.** Hide-based items: stitched seams, uneven edges; grass items: layered fringe; fibre sandals: strap lines. Use the real references per item in art/MODEL_INVENTORY.md (3-5 lines each). Keep it plain and non-divisive (safe-place rule): no gendered labels in names or files.
> 8. **Test (groupable).** ONE labelled row of dressed bodies in the showroom (one body per item plus one wearing everything), via REQUEST; PASS IF each shows its own mesh on the right slot, no clipping at the character screen extremes. Headless: triangle count per piece in a table.
> 9. **Order and commits.** Cloak, hood, boots, leggings, mittens, skirt, sandals, pack; one commit per slot; merge in the hourly batch.

**Source:** `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_worn_attach.md` lines 1-20; under heading: # Steve: wear Kathleen's worn clothing on bodies (RUNTIME, client only; one item)

> # Steve: wear Kathleen's worn clothing on bodies (RUNTIME, client only; one item)
> Branch claude/steve-worn-attach from generator-v2 after claude/kathleen-worn-clothing merges (needs src/client/worn_look.gd and data/items/worn.json). Queued behind the river settle work.
> Today: the server sends the worn item numbers to the player (protocol 40 net.worn, inventory_view._on_worn). Only the player's own third-person avatar (terrain_client._make_avatar, held_item._avatar_rig) and NPCs (npc_view._make_body) have bodies; other players have none yet (no remote-player bodies, so "sync" means the local player and NPCs).
> Plan, three small hooks, one call each, no protocol change:
> 1. Own avatar: on every _on_worn change, WornLook.attach(avatar_rig, ids_from_numbers(worn), far=false) and on the first-person arms rig (held_item._arms) the mittens only if the builder allows; ids come from table.id_of(number).
> 2. NPCs: npc_view._make_body calls WornLook.attach(ragdoll, ids, far) with ids from an optional "worn": [item ids] list in the NPC roster rows (data/npcs); far = true beyond 30 m (re-attach when the NPC crosses the distance, one check per second, not per frame).
> 3. Character screen body preview: character_screen.gd gets a small SubViewport with a RagdollBody in idle, turning slowly, WornLook.attach with the same ids, refreshed in character.refresh(). Shown beside the slots; no new input.
> Best-practice questions for Tyler: one shared helper (src/client/worn_sync.gd: numbers -> ids -> attach) so the three places do not each convert; far/near switch by distance in one place; SubViewport cost when the screen is closed (no render while hidden).
> Tests: parse_scan, local_check 233, test_worldgen/validate_items (Kathleen's rows), Mike one rig picture with a full outfit (give the 9 items via --give, then look from the side) and one character-screen picture.
>
> ## Tyler reply (03:05 UTC 24 Oct, once; BP-T52). GO, branch claude/steve-worn-attach after claude/kathleen-worn-clothing is merged. Yes to one helper.
> Best-practice suggestions:
> 1. **One helper, one conversion.** src/client/worn_sync.gd with a single entry: apply(rig, worn_numbers_or_ids, far). It converts numbers to ids once (table.id_of), diffs against what is already attached (remember the applied ids on the rig as metadata) and adds or removes only the pieces that changed, so a worn change does not rebuild the whole outfit.
> 2. **Distance switch in one place.** Keep a single `far` decision (30 m, one check per second, hysteresis of a few metres so a body at 30 m does not flicker) inside the helper or its caller, not in each of the three places. Re-attach only when the far flag flips.
> 3. **Closed screens cost nothing.** The character-screen SubViewport uses render_target_update_mode DISABLED (or UPDATE_ONCE per refresh) while the screen is hidden, and its body is freed or paused; the idle turn runs only while visible. Report the frame cost with the screen open and closed (Ctrl+Shift+G).
> 4. **First-person arms.** Show mittens on the arms only if Kathleen's builder is flagged for it in worn.json (arm_ok); the first-person camera must not see clipping through the cloak or hood (hide hood/cloak parts on the own head layer, visible to others and the third-person view only).
> 5. **NPC rosters.** The optional "worn" list in data/npcs rows is validated in Python (every id exists and has a worn.json row); an unknown id logs once and is skipped, never an error.
> 6. **Protocol note.** No protocol change today is right. When remote-player bodies arrive, the same apply() takes the list the server sends; document that in worn_sync.gd's header and claim a protocol number then.
> 7. **Tests.** parse_scan, local_check at 233, validate_items, plus one headless test that attaches an outfit twice (second call changes nothing) and swaps one item (only that piece changes). Mike's picture is one REQUEST: full outfit side view, and the character-screen body (two pictures).
> Label RUNTIME. Merge: next hourly batch after Kathleen's branch.

**Source:** `docs/mirror/items/CLOTHING_AND_WARMTH_DESIGN.md` lines 19-19; under heading: ## Clothes (items, mostly future)

> Wrapped hide cloak, hide boots, leather jerkin, wool cloak, fur hat, mittens. Early game: plant fibre skirt and grass cloak (small warmth, rot quickly). They need hides, wool, a sewing needle (job 90) and the Tailoring skill. Items get `kind: clothing`, `slot`, `warmth`, `wet_resist`, `durability` (wear from use), a body slot panel in the Tab screen, and appear on the character model (Art builds the layer rig after the ragdoll). Equipment is a new inventory section (9 slots); a protocol and save bump when built.

**Source:** `docs/mirror/items/NPC_DESIGN.md` lines 69-69; under heading: ## 10. Questions for Steve (not Dave)

> - NPC body: reuse the player ragdoll with a clothes set for the first wave. I recommend yes.

### B7. Other people's bodies: NPCs, other players, animation level of detail, network

**Source:** `docs/archive/2026-10/docs/mirror/tyler/FINDINGS.md` lines 299-307; under heading: # Report 17 (2026-10-21): NPC bodies, pre-generated NPC voice lines, river surface problems. Practice notes from industry norms (Skyrim, GTA, WoW, Witcher 3, Wwise and FMOD guidance) and hydrology; not tested in the game.

> # Report 17 (2026-10-21): NPC bodies, pre-generated NPC voice lines, river surface problems. Practice notes from industry norms (Skyrim, GTA, WoW, Witcher 3, Wwise and FMOD guidance) and hydrology; not tested in the game.
> ## A. NPC bodies in an MMO (for Mandy)
> 1 One shared skeleton and one animation set for every humanoid (players, NPCs), with per-NPC variation from mesh parts, colours and scale (+-4% height, +-6% width). Retargeting is then free and the clip memory is paid once. The 17-bone ragdoll rig is the shared rig: build NPC clips as data tables like the player gaits so Dave can tune one place.
> 2 Pose library, not many clips: idle A/B/C (weight shift, arms crossed, hands behind), sit (chair, bench, ground), sleep (on side, on back, in bed with blanket cover), lean (wall), work loops per job (hammer, sweep, stir). Pose = a table of joint angles blended over 0.4-0.8 s. Sit and sleep need a "seat marker" on the furniture holding position, facing and pose id, so the NPC snaps to it exactly (avoids sinking into chairs). Markers already exist in data/npcs/markers.json; reuse.
> 3 Idle variation: do not loop one idle. Pick a random micro-action every 4-12 s (look around, scratch, shift weight, stretch) with a cooldown and never the same twice in a row; add a slow breathing offset on the chest (1 cm at 12-16 cycles/min) and eye/head glance at a nearby player (gaze within 5 m, head turn limit 60 deg, 0.3 s delay). Different NPCs start at random phase so a crowd is never in sync.
> 4 Animation LOD (matches Dave's existing 15 / 70 m rule): full skeleton to 15 m; to 40 m: update every 2nd frame, no fingers or face; to 70 m: every 4th frame, body only, frozen leg cycle when still; past 70 m: single static pose, or hidden if indoors. Offscreen NPCs: no animation tick at all. Server only sends position, heading, state (walk/sit/sleep/talk/work) and the client plays the pose, so bandwidth stays tiny.
> 5 Cost targets: under 0.1 ms per animated NPC at full LOD, under 0.01 ms at far LOD; cap full-LOD NPCs per frame to 20-30 and demote the farthest. Batch similar NPCs; share materials; merge static clothing meshes.
> 6 Pitfalls: foot sliding (scale walk speed to path speed, as 486 did), popping when LOD changes (blend over 0.3 s), NPCs standing in each other's space (steering with 0.5 m personal space), sleeping NPCs ending up in the wall (bake sleep marker as the only legal pose position), time-of-day schedules all firing at the same minute (random +-10 min).
> 7 Dave's rule: unwell NPCs sit or lie down and keep conversation short; add an unwell posture variant (hand to head, slower walk 0.6x) so it is visible from distance.

**Source:** `docs/mirror/tech/DECISIONS.md` lines 201-202; under heading: ## 2026-10-21 18:10 Animation and river mouth (Tyler, from Dave; Steve)

> ## 2026-10-21 18:10 Animation and river mouth (Tyler, from Dave; Steve)
> (1) Animation for other players and NPCs: APPROVED, Mandy. Clients derive clips from velocity and stance (no protocol change). Animation LOD: full at <= 15 m, 15 Hz to 40 m, 5 Hz to 70 m, frozen beyond; stays inside the 1 ms at Low budget for 20 visible bodies (measure). npc_view.gd must play clips.

**Source:** `docs/mirror/items/NPC_DESIGN.md` lines 53-53; under heading: ## 7. Server cost at 20 players

> - Network: NPC position/heading/state for NPCs within 120 m at 4 Hz, about 12 bytes each, delta sent: under 2 KB/s per player in a busy square. A dialogue message is one small RPC per line. New RPCs `npcs(numbers)`, `npc_say(npc, text, voice, choices)`, `npc_talk(npc, choice)`: protocol bump when built, cost at Low stated then (draw the same ragdoll body as the player, max 20 NPCs drawn).

**Source:** `docs/mirror/tech/BUILD_LOG.md` lines 185-185; under heading: ## One number ahead (Dave 2026-10-20 23:42: threads must not wait on a number)

> - 19:33 Mandy: 491 (NPC bodies are the rounded ragdoll with clothes colours, idle/walk/jog/run/sit/lie, animation by distance)

**Source:** `DESIGN_IDEAS.md` lines 1765-1765; under heading: ### 11.3 Life in the world

> - **[Proposed]** Close up: fully animated NPCs, carts and machinery. Medium and far: simple shapes and basic motion (a wagon train crawling along a distant road, smoke from a mine). Beyond sight: schedule only. Distances and counts are graphics settings, so older machines can reduce them.


## 2.8 Passages to remove from the original documents once Dave approves

Nothing has been removed. This list is for Dave's approval. For each entry: file, line range at the time of copying (2026-10-30), and the heading it sits under. After approval I would replace each removed passage with a one-line pointer "see CHARACTER_DESIGN_VISION.md, section B<n>". Several passages are also in the mirror copies under `docs/mirror/`; those mirrors (copies of root files) should be treated the same way as their originals. Passages from `docs/archive/` are history; I recommend leaving the archive untouched and removing only from live documents (Dave's call).

- `ART_DIRECTION.md` lines 53-55, heading: ### 2.7 Character and buildings
- `ART_DIRECTION.md` lines 82-84, heading: ## 5. Realism over storybook
- `ART_DIRECTION.md` lines 107-109, heading: ## 10. Character look (owner decision, 2026-10-20)
- `ARCHITECTURE_BUDGET.md` lines 68-68, heading: ## 5. Modeled and procedural assets
- `docs/mirror/tech/DECISIONS.md` lines 121-121, heading: ## 2026-10-21 Ground edits must tell the grass
- `DESIGN_IDEAS.md` lines 1671-1671, heading: ### 9.2 Crime memory and delayed discovery
- `ART_DIRECTION.md` lines 330-332, heading: ## 45. Ragdoll character (build 349)
- `ART_DIRECTION.md` lines 369-371, heading: ## 48. Ragdoll sides (build 354)
- `assets/character/README.md` (whole file): KEEP IN PLACE; it is the technical reference that ships with the code. Copied above for reading only.
- `docs/mirror/tech/BUILD_LOG.md` lines 51-54, heading: ## One number ahead (Dave 2026-10-20 23:42: threads must not wait on a number)
- `docs/mirror/tech/BUILD_LOG.md` lines 59-60, heading: ## One number ahead (Dave 2026-10-20 23:42: threads must not wait on a number)
- `docs/mirror/tech/JOBS.md` lines 320-320, heading: ## Note to Art from Items (2026-10-21T03:50:25Z)
- `docs/mirror/tech/JOBS.md` lines 398-398, heading: ## Moves awaiting Steve (Dave 2026-10-21 20:54: Steve approves every "set aside and move on")
- `CONTROLS.md` lines 17-17, heading: ## Now (terrain client, build 23)
- `CONTROLS.md` lines 26-26, heading: ## Now (terrain client, build 23)
- `CONTROLS.md` lines 68-73, heading: ## Now (terrain client, build 23)
- `CONTROLS.md` lines 86-86, heading: ## Planned / not decided
- `CONTROLS.md` lines 94-94, heading: ## Planned / not decided
- `ITEMS_DESIGN.md` lines 66-67, heading: ### Stance and rest (protocol 21)
- `PROTOCOL.md` lines 65-65, heading: ## Inventory action kinds (inventory_action(kind, a, b, count, at))
- `DESIGN_IDEAS.md` lines 959-961, heading: ### 6.16 Exertion, fitness and health (brainstorm)
- `DESIGN_IDEAS.md` lines 967-969, heading: ### 6.16 Exertion, fitness and health (brainstorm)
- `DESIGN_IDEAS.md` lines 940-940, heading: ### 6.14 Senses, thoughts and the minimal HUD
- `DESIGN_IDEAS.md` lines 985-985, heading: ### 6.17 The sound stage (brainstorm)
- `docs/archive/2026-10/docs/mirror/tyler/BEST_PRACTICES.md` lines 99-109, heading: ## Character animation (decision for Dave's question, 2026-10-21)
- `docs/archive/2026-10/docs/mirror/tyler/BEST_PRACTICES.md` lines 130-152, heading: ## Natural walk, jog, run: numbers for the ragdoll (for Mandy, Dave's request 2026-10-21)
- `docs/archive/2026-10/docs/mirror/tyler/FINDINGS.md` lines 215-222, heading: # Report 13 (2026-10-21): build 465 walk/jog/run against my table (ragdoll_body.gd _gait, terrain_client.gd:2179-2193)
- `CONTROLS.md` lines 10-10, heading: ## Now (terrain client, build 23)
- `docs/mirror/tech/BUILD_LOG.md` lines 51-52, heading: ## One number ahead (Dave 2026-10-20 23:42: threads must not wait on a number)
- `docs/mirror/tech/CAMERA_TURN_RECIPE.md` lines 11-11, heading: ## The recipe (one change, three parts)
- `docs/mirror/tech/STANDARD_SHOTS.md` lines 15-15, heading: ## STANDARD SET v3 (Dave 25 Oct 01:26: "only take 3 shots and rotate left 90 degrees after each shot")
- `ITEMS_DESIGN.md` lines 131-133, heading: ## First-person arms (2026-10-21)
- `DESIGN_IDEAS.md` lines 568-568, heading: ### 5.3 Crafting
- `CONTROLS.md` lines 52-52, heading: ## Now (terrain client, build 23)
- `CONTROLS.md` lines 88-88, heading: ## Planned / not decided
- `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_held_tools_pose_heads.md` lines 1-8, heading: # Held tools: pose, saw shape, tool heads (Kathleen, 25 Oct)
- `docs/archive/2026-10/docs/mirror/tyler/FINDINGS.md` lines 495-523, heading: # Report 26 (2026-10-21): the first-person axe chop looks wrong (Dave): how a real chop moves, how FPS games animate it, a keyframe table, and why ours is off. Read from src/client/held_item.gd (SWING_S 0.55, ARMS_POS (0,-0.1,-0.15), ARMS_PITCH 50 deg, TOOL_TILT 20 deg, strike fired at 0.5 x SWING_S) and ragdoll_body.gd `_swing` (shared by first and third person). I have not seen a render of the chop.
- `docs/mirror/tech/BUILD_LOG.md` lines 306-306, heading: ## One number ahead (Dave 2026-10-20 23:42: threads must not wait on a number)
- `docs/mirror/tech/BUILD_LOG.md` lines 333-333, heading: ## One number ahead (Dave 2026-10-20 23:42: threads must not wait on a number)
- `docs/mirror/tech/BUILD_LOG.md` lines 254-254, heading: ## One number ahead (Dave 2026-10-20 23:42: threads must not wait on a number)
- `docs/mirror/tech/SCALE_PLAN.md` lines 138-138, heading: ## 11b Who handles what: server or client, per feature (the centre of the plan; "cost at 1000" is per second across the whole world, est.)
- `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_worn_clothing.md` lines 1-17, heading: # Kathleen: worn clothing meshes (goal 1f, all clothing items in one plan)
- `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_worn_attach.md` lines 1-20, heading: # Steve: wear Kathleen's worn clothing on bodies (RUNTIME, client only; one item)
- `docs/mirror/items/CLOTHING_AND_WARMTH_DESIGN.md` lines 19-19, heading: ## Clothes (items, mostly future)
- `docs/mirror/items/NPC_DESIGN.md` lines 69-69, heading: ## 10. Questions for Steve (not Dave)
- `docs/archive/2026-10/docs/mirror/tyler/FINDINGS.md` lines 299-307, heading: # Report 17 (2026-10-21): NPC bodies, pre-generated NPC voice lines, river surface problems. Practice notes from industry norms (Skyrim, GTA, WoW, Witcher 3, Wwise and FMOD guidance) and hydrology; not tested in the game.
- `docs/mirror/tech/DECISIONS.md` lines 201-202, heading: ## 2026-10-21 18:10 Animation and river mouth (Tyler, from Dave; Steve)
- `docs/mirror/items/NPC_DESIGN.md` lines 53-53, heading: ## 7. Server cost at 20 players
- `docs/mirror/tech/BUILD_LOG.md` lines 185-185, heading: ## One number ahead (Dave 2026-10-20 23:42: threads must not wait on a number)
- `DESIGN_IDEAS.md` lines 1765-1765, heading: ### 11.3 Life in the world

## 2.9 Conflicts and out-of-date statements found in our documents (FACT unless stated)

1. **Style: realistic or stylised.** ART_DIRECTION.md section 2.7 describes the character as "realistic proportions, layered clothes ... rich material detail" and says this is more realistic than "heroic with a hint of cartoon", pointing at section 5. Section 5 says the near-photoreal picture wins for the world and the character style is decided in section 10. Section 10 (owner decision 2026-10-20) says slightly stylised, heroic proportions, a hint of cartoon, lighter than the picture's character. Section 10 is the later, decided one. Section 2.7 is a description of the reference picture, not a decision.
2. **Triangle count:** ART_DIRECTION.md section 45 says about 1.5k triangles; assets/character/README.md says about 3.2k after the rounded rebuild. The README is later.
3. **Walk speeds:** Tyler's FINDINGS Report 13 recorded game speeds of 6.0 / 8.5 / 11.0 m/s against clips built for 1.4 / 3.2 / 6.0. The code now has WALK 1.4, JOG 3.2, RUN 6.0, so that mismatch is resolved. The same report's other points (flight phase, slope lean, strafe, backwards clips) were partly done (run hop and slope tilt exist; strafe and backwards do not).
4. **Camera bob stride:** CONTROLS.md says strides of 3 m walking, 4.2 m jogging, 6 m running; the code has `STEP_M` 0.75 / 1.2 / 2.0 m per step (that is about 1.5 / 2.4 / 4.0 m per two steps). The doc is out of date or counts differently.
5. **Stances:** CONTROLS.md "Planned / not decided" still says stances are "not built yet"; the code has them (stance.gd).
6. **Spear controls:** the same section says spear controls are "decided, not built"; held_item.gd implements jab and throw.
7. **Arms side naming:** older notes (JOBS.md, BUILD_LOG.md) say the arms use `hand_mount_l`; since build 354 the right hand is `hand_mount_r` (ART_DIRECTION.md section 48).
8. **NPC animation:** Tyler's BEST_PRACTICES says npc_view.gd had no animation calls; later BUILD_LOG entries (491) say NPC bodies animate. The code today has clip selection and distance throttling.
9. **Unsourced numbers:** Tyler's gait table (BEST_PRACTICES "Natural walk, jog, run") says plainly that only the walk-run transition is sourced and the rest are from memory; the clips were built from it. See Part 3.7 for my check.
10. **Dave's rules found in the passages (carry forward):** the left hand does not move in an attack unless it holds something; the first-person view should not be driven by the body-twist clip; hit events fire at the impact key; held items point only slightly down; names must be non-divisive ("safe place" rule, no gendered labels); characters are not to be shown as realistic.

---

# Part 3. Research log

**Method.** Research was done by six sub-agents (Sonnet 5.5, medium effort) in round 1, one per topic, then two more in round 2, and I reviewed and merged the reports. Round count is stated at the end of this Part. The agents could open some pages and only saw search summaries for others; I keep their confidence tags:

- **OPENED**: the page was fetched and read (the fetch tool summarises long pages, so this is a summary read, not necessarily verbatim).
- **SNIPPET**: seen only in a search result summary. Treat as a lead, not a fact.
- **MEMORY**: not sourced; the agent's recollection. Never used as a fact in the plan.

Every note is in my own words. Each entry has an ID (for example A3) that Parts 4 to 7 cite. Items I could not confirm are marked **NOT CONFIRMED**. I did not re-open every page myself; the confidence tags are the agents' reports, and I treat SNIPPET items as unverified.

## 3.1 Round 1, topic A: animation principles, locomotion, root motion

- **A1** Game versions of the 12 principles: designers want short anticipation, animators long; too short feels weightless, too long feels sluggish; a frame where the player regains control keeps follow-through without hurting responsiveness; exaggerate and hold poses so they read at distance; secondary motion goes in additive or partial layers. https://gamedeveloper.com/production/the-12-principles-of-animation-in-video-games (OPENED)
- **A2** In games anticipation moves into idle and ready poses because wind-up frames delay input response; heavy easing can read as lag; because players can cancel anything, follow-through needs designed blend-outs; silhouettes must read from any camera angle. https://anim.works/?p=23056 (OPENED)
- **A3** Jonathan Cooper's book *Game Anim* is the standard reference for locomotion starts, stops and turns (not read; no free text found). https://www.routledge.com/Game-Anim-Video-Game-Animation-Explained/Cooper/p/book/9780367707651 (SNIPPET)
- **A4** Distance matching drives a clip by distance, not time: height above ground for landings, XY distance for starts, stops and pivots. https://dev.epicgames.com/documentation/en-us/unreal-engine/distance-matching-in-unreal-engine (OPENED)
- **A5** Unreal's pose warping: stride warping adjusts foot spacing to capsule speed (fewer speed-specific clips); orientation warping turns leg IK toward travel direction and twists the spine (one clip covers a wide strafe range). Needs root-motion clips and an IK rig. https://dev.epicgames.com/documentation/en-us/unreal-engine/pose-warping-in-unreal-engine (OPENED)
- **A6** Motion matching (For Honor): each frame the system scores candidate animation frames on key-bone positions and a predicted trajectory; foot IK and toe locking hide residual sliding; a state machine still runs the game logic. https://www.gameanim.com/?p=13538 (OPENED); Clavet GDC 2016: about 5 to 10 minutes of captured motion can replace hand-made starts, stops and turns. https://gdcvault.com/play/1022985/Motion-Matching-and-The-Road (OPENED)
- **A7** Unreal Motion Matching needs a schema, a database of root-motion clips and a pose history; cost grows with samples; it replaces state machines. https://dev.epicgames.com/documentation/en-us/unreal-engine/motion-matching-in-unreal-engine (OPENED). The Last of Us Part II used it and the 2021 talk overview calls it high-risk and then experimental. https://gdcvault.com/play/1027118/Motion-Matching-in-The-Last (OPENED, overview only). Learned motion matching cuts memory with neural nets and is research-grade. https://montreal.ubisoft.com/?p=23009 (OPENED)
- **A8** Indie feasibility of motion matching: the cost is mocap data (studio capture is thousands per day; cheap packs exist); no Godot implementation found. https://mocaponline.com/blogs/mocap-news/motion-capture-indie-game-dev (SNIPPET, vendor). My conclusion (RECOMMENDATION): not realistic for this project.
- **A9** The human walk-to-run transition is about 2.0 m/s (Hreljac 1993 average 2.06 m/s, energetic optimum 2.24); the mechanism is still debated. https://www.wikipedia.org/wiki/Transition_from_walking_to_running (SNIPPET); the earlier internal Tyler note cites Kram et al. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2719915/ and https://sites.utexas.edu/neptune/wp-content/uploads/sites/6031/2020/07/jeb2085.pdf (as quoted in our own docs; not opened by me). **NOT CONFIRMED by any source found in round 1: cadence, stride length, lean angles, knee peaks.** Round 2 tried to fill this (3.7).
- **A10** Jump design: take-off, looping in-air pose and a very short landing clip because the player may keep running (student blog, weak). https://mattlawsonhall.blogspot.com/2025/12/graduate-portfolio-character-animation.html (SNIPPET). Forum opinion: locking movement during a landing recovery feels bad. https://answers.unrealengine.com/questions/28414/view.html (SNIPPET).
- **A11** Godot AnimationTree gives BlendSpace1D/2D, Transition, OneShot, TimeScale and root motion; Godot has no built-in motion matching or stride warping (absence in the docs, not proof). https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html (OPENED)
- **A12** **NOT CONFIRMED / no authoritative source found** for crouch, swimming, climbing, ladder and mounted-riding animation (round 1). Round 2 asked again (3.7).

## 3.2 Round 1, topic B: Godot engine specifics (stable docs identify as 4.7)

- **B1** AnimationTree: state machine with Immediate, Sync or At End transitions and `travel()`; BlendSpace2D (Delaunay triangles; modes Interpolated, Discrete, Carry; sync modes include Cyclic); Blend2/Blend3 and OneShot take track filters, which is how bone-mask layering is done; TimeScale; Transition; root motion via a root-motion track and `get_root_motion_position()` etc. https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html (OPENED)
- **B2** AnimationNodeAdd2 adds one input on top of another by an amount (filter properties not seen: NOT CONFIRMED). https://docs.godotengine.org/en/stable/classes/class_animationnodeadd2.html (OPENED). AnimationNodeBlendTree can be built in code. https://docs.godotengine.org/en/stable/classes/class_animationnodeblendtree.html (OPENED)
- **B3** AnimationMixer: `callback_mode_process` physics, idle or manual (manual means you call `advance(delta)` yourself, usable for distance-based update rates); `capture()` cross-fades from a cached pose; `deterministic`; root-motion getters. https://docs.godotengine.org/en/stable/classes/class_animationmixer.html (OPENED). AnimationPlayer: Call Method tracks can fire events but do not fire on seek-with-update-only or on `stop()`; `play()` applies on the next process unless `advance(0)` is called. https://docs.godotengine.org/en/stable/classes/class_animationplayer.html (OPENED)
- **B4** Godot 4.7 beta 1 notes list optimisations to AnimationTree, Player, Mixer and Library, and a breaking change to BlendSpace point naming; final 4.7 release notes not opened. https://godotengine.org/article/dev-snapshot-godot-4-7-beta-1/ (OPENED)
- **B5** Crowd cost: one forum thread (4.5 post, 4.2 numbers) saw about 300 animated rigged units at 36 fps on a weak integrated-graphics PC; replies say AnimationTree is heavy, there is no skeleton culling, and the workaround is to disable distant players; may have changed in 4.7, so profile on a GTX 1050. https://forum.godotengine.org/t/performance-of-crowds-of-animated-rigged-characters-in-3d/130409 (OPENED, anecdotal)
- **B6** Retargeting: set the Skeleton3D `bone_map` to a BoneMap using SkeletonProfileHumanoid; reference is a T-pose facing +Z; options Rest Fixer, Bone Renamer, Remove Tracks; Overwrite Axis and Fix Silhouette can distort models. https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html (OPENED)
- **B7** SkeletonProfileHumanoid has 56 bones (Body, Face, LeftHand, RightHand groups) including Root, Hips, Spine, Chest, UpperChest, Neck, Head, Jaw, eyes, shoulders, upper/lower arm, hand, upper/lower leg, foot, toes and finger bones. https://docs.godotengine.org/en/stable/classes/class_skeletonprofilehumanoid.html (OPENED). That a reduced rig can map a subset is the agent's inference: NOT CONFIRMED.
- **B8** RetargetModifier3D retargets a pose at runtime from one skeleton to another with a different rest, so shared animations could drive a differently shaped body without baking. https://docs.godotengine.org/en/stable/classes/class_retargetmodifier3d.html (OPENED, not tested)
- **B9** SkeletonModifier3D runs after the AnimationMixer; subclasses listed include IKModifier3D, LookAtModifier3D, SpringBoneSimulator3D, RetargetModifier3D, BoneConstraint3D, BoneTwistDisperser3D, LimitAngularVelocityModifier3D, ModifierBoneTarget3D, PhysicalBoneSimulator3D, SkeletonIK3D. https://docs.godotengine.org/en/stable/classes/class_skeletonmodifier3d.html (OPENED)
- **B10** IK returned in Godot 4.6: TwoBoneIK3D (deterministic), ChainIK3D family (SplineIK3D, IterateIK3D with FABRIK3D, CCDIK3D, JacobianIK3D), LimitAngularVelocityModifier3D to smooth; no foot-IK tutorial. https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/ (OPENED). TwoBoneIK3D settings: root, middle, end bone, target node, pole node, pole direction; end must be a child of middle, middle of root. https://docs.godotengine.org/en/stable/classes/class_twoboneik3d.html (OPENED). SkeletonIK3D still exists but is marked deprecated. https://docs.godotengine.org/en/stable/classes/class_skeletonik3d.html (OPENED). The 4.6 blog's wording that it was removed in 4.0 contradicts the class page: unresolved.
- **B11** LookAtModifier3D turns a chosen forward axis toward a target with angle limits, damping and time smoothing; parent-bone modifiers must be listed before child-bone ones. https://docs.godotengine.org/en/stable/classes/class_lookatmodifier3d.html (OPENED)
- **B12** SpringBoneSimulator3D (secondary motion for hair, tails, cloth): chains from root to end bone, no branched chains, do not scale the skeleton, collisions by SpringBoneCollision3D nodes; introduced in Godot 4.4 per the 4.4 release page (see H1; the 4.6 blog wording is looser). https://docs.godotengine.org/en/stable/classes/class_springbonesimulator3d.html (OPENED)
- **B13** BoneAttachment3D copies a bone transform to a node (right for tools, shield, torch, pack); avoid `override_pose` together with modifiers. https://docs.godotengine.org/en/stable/classes/class_boneattachment3d.html (OPENED)
- **B14** Import: animation names containing `loop` or `cycle` import looped; `-noimp` drops a node. https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html (OPENED)
- **B15** Licences: godot-demo-projects is MIT. https://github.com/godotengine/godot-demo-projects (OPENED). GDQuest's Godot 4 third-person controller: code MIT, **art CC-BY-NC-SA (not usable commercially)**. https://github.com/gdquest-demos/godot-4-3d-third-person-controller (OPENED). No well-known Godot 4 locomotion, foot-IK or ragdoll addon with a confirmed licence was found. No official foot-IK or hand-IK tutorial for the new nodes; hand IK on a tool is the agent's inference only.

## 3.3 Round 1, topic C: IK, procedural animation, viewmodels, camera

- **C1** Foot IK recipe: two-bone solve per foot to a ray-cast hit plus foot offset; lower the pelvis to the lowest foot (never raise it); run IK continuously; smooth hit position and normal; fade IK weight out during the foot's swing phase using contact events; rotate the foot to the smoothed normal. https://sites.google.com/view/realtime-animation-tips/tutorials/animation-stepping-stones (OPENED) and https://docs.vulkan.org/tutorial/latest/Advanced_glTF/Procedural_Animation_IK/04_foot_placement.html (OPENED)
- **C2** Stairs need more than IK: predict the next plant point, build a virtual ground from shape casts (Ubisoft "Fitting the World", GDC 2016, https://gdcvault.com/play/1023009/Fitting-the-World-A-Biomechanical, SNIPPET; the talk itself was not seen).
- **C3** Aim offsets are blend spaces of additive poses over an aim pose (Unreal). https://dev.epicgames.com/documentation/unreal-engine/aim-offset-in-unreal-engine (SNIPPET). Godot has no confirmed direct equivalent; LookAtModifier3D (B11) on head and spine is the analogue (agent inference).
- **C4** Procedural animation from very few keyframes (Rosen, GDC 2014 Animation Bootcamp). https://gdcvault.com/play/1020049/Animation-Bootcamp-An-Indie-Approach (OPENED title and description only).
- **C5** Viewmodel sway as damped springs per input (look delta, strafe, bob): forum and mod sources only. https://forums.unrealengine.com/t/adding-weapon-sway-fps/299979 (SNIPPET).
- **C6** Separate arms versus shared full body (forum opinion, "it depends"): separate arms allow better arm detail and no clipping and fewer bones on the third-person mesh, at the cost of two asset sets; a shared body keeps the two views in sync but makes aim blending and iron sights harder. https://forums.unrealengine.com/t/arms-vs-bodies-which-is-better-for-multiplayer-shooters/72956 (OPENED)
- **C7** Camera on a head bone: hide the owner's head from the owner only, limit look-down pitch to avoid the torso, damp bob inherited from the bone. https://forums.unrealengine.com/t/should-a-first-person-character-necessarily-use-multiple-meshes/370368 (SNIPPET), https://discussions.unity.com/t/proper-cinemachine-camera-placement-on-full-body-first-person-model/1590365 (SNIPPET)
- **C8** Godot viewmodel clipping: a shader that overrides FOV and scales depth (needs 4.3+, works per material, forum reports it can change size/position) https://godotshaders.com/?p=8957 (OPENED); a SubViewport second camera, reported to lose world shadows and sometimes the WorldEnvironment (old threads, unconfirmed for 4.7) https://godotforums.org/d/28766-better-way-to-handle-first-person-weapon-clipping (SNIPPET); cheap fixes: shrink the weapon into the capsule or lower it via a wall ray.
- **C9** SpringArm3D sweeps a shape each physics frame for third-person camera collision; the agent's snippet says it pops back out abruptly (Unreal thread), so smooth the return. https://docs.godotengine.org/en/4.6/tutorials/3d/spring_arm.html (OPENED)
- **C10** Head bob and shake should be adjustable (sliders/toggles); players disagree on bob; forum and press only, no peer-reviewed source. https://forum.godotengine.org/t/motion-sickness-check-is-the-movement-head-bob-in-my-boomer-shooter-too-aggressive-seeking-feedback/128936 (SNIPPET)
- **C11** **NOT CONFIRMED / nothing found:** procedural arm swing, lean into acceleration, two-handed grips and left-hand IK, tool inertia, which rig approach Tarkov/Arma/Ready or Not use.

## 3.4 Round 1, topic D: tool actions, layering, equipment, budgets

- **D1** Smash hit-stop (Sakurai): both sides freeze for the same time, stronger hits freeze longer, capped, the victim shakes, kept short. https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/ (OPENED)
- **D2** Screen shake and stacking many small tweaks ("Art of Screenshake", Nijman): article only mentions the shake. https://gamedeveloper.com/design/vlambeer-co-founder-shares-advice-on-building-better-action-games (OPENED)
- **D3** Hit-stop lengths of 2 to 3 frames light, 4 to 6 medium, 6 to 10 heavy come from an unverified blog: starting values to tune, not a standard. https://freegamesprites.com/ar/news/game-feel-2d-combat-juice-tricks (SNIPPET)
- **D4** Attack structure of anticipation, active and recovery frames with a cancel window late in recovery (generic fighting-game sheet). https://docs.google.com/document/d/1i2zTU-0btjdDaTJMucGcmAPAEwuJm_siPdPVMY1zgGY/export?format=pdf (SNIPPET). Mariel Cartwright's Animation Bootcamp talk on fluid, powerful, responsive animation: https://gdcvault.com/play/1020575/Animation-Bootcamp-Fluid-and-Powerful (OPENED, description only).
- **D5** Layering in Godot: Blend2 with filters, or two AnimationPlayers (upper/lower); OneShot with filters over locomotion gives attack-while-walking. https://forum.godotengine.org/t/is-possible-to-use-two-animation-in-parallel/50798 (OPENED); one forum report says a track-stripping script worked in 4.1.4 and broke in 4.6, so prefer node filters. https://forum.godotengine.org/t/can-t-remove-tracks-from-imported-animation/135572 (SNIPPET)
- **D6** Modular characters: share one skeleton and swap skinned meshes; meshes made for other bone lengths warp. https://forum.godotengine.org/t/swapping-a-skeletons-3d-models-while-having-them-look-normal/140811 (SNIPPET). Attach tools to bones instead of keeping hidden children; material swaps are cheaper than duplicate meshes. https://godotforums.org/d/40518-accessories-for-3d-characters (SNIPPET)
- **D7** Budgets are vendor marketing only (mobile hero 1.5k to 5k triangles, PC 15k to 50k; LOD example 3.7k down to 1.0k): low confidence. https://blog.neural4d.com/user-guide/polygon-count-for-3d-game-assets-printing-and-webar/ (SNIPPET), https://simplygon.com/posts/0179d2c5-a440-49d7-850a-0a9a94152d1b (SNIPPET). **NOT CONFIRMED: anything GTX 1050-specific, bone limits, hiding body regions under clothing, atlasing, stylised proportion guidance.** Round 2 retried (3.8).
- **D8** **NOT CONFIRMED / nothing found:** For Honor or Dark Souls frame data, Swink's *Game Feel* text, input buffering sources (the 100 to 200 ms buffer, late-recovery cancel window are agent MEMORY), looping gather animations, foot sliding while attacking.

## 3.5 Round 1, topic E: networking and prediction

- **E1** Godot community advice: sync the trigger state (an int state), let each remote AnimationTree pick the clip; do not sync particles or bones. https://forum.godotengine.org/t/how-does-the-multiplayersynchronizer-node-actually-work/115113 (OPENED, forum answer). Whether exact animation phase must sync is unsettled; a capsule is enough for damage. https://forum.godotengine.org/t/best-practice-for-syncing-animationtree-in-godot-4-multiplayer/140295 (OPENED)
- **E2** Unity Netcode's NetworkAnimator warns that a parameter changing every frame costs a message per frame and should be derived locally from data clients already have; triggers need the networked call; late joiners get state but not triggers. https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@2.8/manual/components/helper/networkanimator.html (OPENED)
- **E3** Photon Fusion lists six animation-sync methods; simplest is driving the animator from interpolated networked state, with drift fixed by a periodic state-time sync. https://doc.photonengine.com/fusion/current/technical-samples/animations (OPENED)
- **E4** Unreal's character movement replicates location, rotation and velocity to other clients and they derive animation from it (no bones sent). https://dev.epicgames.com/documentation/en-us/unreal-engine/understanding-networked-movement-in-the-character-movement-component-for-unreal-engine (OPENED)
- **E5** Remote entities are drawn a little in the past, blended between two server states (about 100 ms behind at 10 updates/s); the local player is predicted. https://gabrielgambetta.com/entity-interpolation.html (OPENED). A buffer of about three snapshot intervals absorbs jitter and loss (so about 600 ms at 5 Hz). http://gafferongames.com/post/snapshot_interpolation/ (OPENED). Source engine defaults about 20 snapshots/s and 0.1 s interpolation (via a gist copy). https://gist.github.com/CoolOppo/fe0586836de3fb2f90f9 (OPENED, copy)
- **E6** Riot (Valorant): the server runs the animations, saves poses with positions and rewinds both to judge a shot; it animates the server every fourth frame and interpolates saved poses on rewind, saving about 75 percent animation cost. https://www.riotgames.com/en/news/valorants-128-tick-servers (OPENED). Rewind is capped so high-ping players cannot hit someone who already took cover. https://www.riotgames.com/en/news/peeking-valorants-netcode (OPENED)
- **E7** Overwatch: mostly predicted with rollback; server rewinds to the shooter's view. https://edgegap.com/blog/game-backend-deep-dive-overwatch-2016-netcode-architecture-rollback (OPENED, third-party summary). The GDC talk itself was not seen. https://gdcvault.com/play/1024001/-Overwatch-Gameplay-Architecture-and (OPENED, description only)
- **E8** Pattern "play the swing at once on the owning client, server validates and rewinds the target" (forum proposal). https://devforum.roblox.com/t/combat-system-with-rollback/3685525 (SNIPPET). The cost is a window where animation and outcome disagree. https://forums.playdeadlock.com/threads/punched-mid-parry.66043 (SNIPPET)
- **E9** Godot: MultiplayerSynchronizer has `replication_interval`, `delta_interval` and per-peer visibility filters (one interval applies to everyone, so distance tiers likely need several synchronizers or manual visibility). https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html (OPENED). Transfer modes `unreliable`, `unreliable_ordered`, `reliable`; keep gameplay decisions on the server. https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html (OPENED)
- **E10** Our tiers (full to 15 m, 15 Hz to 40 m, 5 Hz to 70 m, frozen beyond) have **no external precedent found**; Unreal's update-rate optimisation is a rendering-side equivalent (forum sources only). Add hysteresis at the cull edge (forum report of pop-in at cull boundaries). https://forums.unrealengine.com/t/variable-net-update-frequency/382890 (SNIPPET). With a 5 Hz tier, one-shot action ids must go reliably or swings are missed (agent inference).
- **E11** **NOT CONFIRMED:** how Valheim, Rust, Ark, 7 Days to Die sync animation (Rust's changelog mentions server-side melee and line-of-sight checks only, https://rust.facepunch.com/changelist/2681 SNIPPET); foot sliding on remote players (MEMORY: drive the walk speed from the displayed interpolated velocity).

## 3.6 Round 1, topic F: comparable games (verified items only)

- **F1 Rust.** June 2026 devblog "Built Different": new player model with more realistic proportions after almost 10 years, new skeleton with a more natural bind pose and twist bones, old Maya rig replaced by one with IK/FK switching, pose libraries and mocap; old single animation state machine had over 250 animations plus per-weapon overrides and was fragile; new approach uses separate self-contained behaviours, for example a torch state machine driving only the right arm so the left arm keeps its locomotion; first-person and third-person animations had drifted apart in action and timing and are now being matched. https://rust.facepunch.com/news/Built-Different (OPENED)
- **F2 Rust 2017.** Rig simplified so the upper body always aims where the player looks and others can see ironsight versus hipfire; known issues listed included odd one-handed holds while running and no ladder animation. https://rust.facepunch.com/news/devblog-144 (OPENED)
- **F3 Minecraft.** The player is a few boxes (head, body, two arms, two legs plus an outer layer); hitbox 1.8 by 0.6 blocks, eye height 1.62; arm swing when attacking or mining was added in Alpha 1.0.15. https://minecraft.wiki/w/Player (OPENED, first part). Community animation mods work by animating those few parts. https://www.curseforge.com/minecraft/mc-mods/player-animation-core/files/8413312 (SNIPPET). A resource pack overhauls player animation on the same tiny rig. https://modrinth.com/resourcepack/better-animations (OPENED)
- **F4 Conan Exiles.** Combat animation is motion-captured combos, then cleaned and exaggerated by animators, then approved and given sound and effects. https://www.conanexiles.com/?p=6009 (OPENED). A developer said you are largely locked into an animation once committed, and that the game once was first-person combat and now plays more like a Souls-style game, with a clash. https://forums.funcom.com/t/developer-stream-recap-december-12th-2019/98110 (OPENED). Player complaints about stiff large-weapon runs and clunky backward/sideways movement exist (individual opinions). https://forums.funcom.com/t/animation-quality-and-combat-needs-to-be-improved/73514 (SNIPPET)
- **F5 Medieval Dynasty.** First-person at launch, third person added Dec 2021, reportedly for players with motion sickness; later patch notes show perspective-specific animation bugs. https://techraptor.net/gaming/news/medieval-dynasty-update-1102-adds-third-person-perspective (SNIPPET), https://steamdb.info/patchnotes/9296741 (SNIPPET)
- **F6 Unturned.** Developer-side and community comments say its character rig is poor; a forum post says chunky arms cover the held gun in first person. https://blog.smartlydressedgames.com/2024/02/27/community-blog-029/ (SNIPPET), https://forum.smartlydressedgames.com/t/devlog-019/8520?page=3 (SNIPPET)
- **F7 Valheim.** Third-person (first-person only via mods; mod notes say head and helmet must be hidden or shrunk to avoid clipping and headless shadows). https://thunderstore.io/c/valheim/p/Azumatt/FirstPersonMode/ (SNIPPET). The low-poly look began as a constraint the creator could produce quickly (reported). https://www.pcgamesn.com/valheim/ps1-graphics (SNIPPET). **NOT CONFIRMED: Iron Gate's rig, armour method or animation tech.**
- **F8 Others, low confidence.** 7 Days to Die 1.0 reportedly brought new base models and new first- and third-person animations (secondary sources only). https://charlieintel.com/games/7-days-to-die-1-0-version-333099 (SNIPPET). Project Zomboid Build 41 described as its animation overhaul with visible clothing and backpacks (search summary only). https://projectzomboid.com/blog/news/2017/02/buildstatus/ (SNIPPET). RuneScape: Dragonwilds is Unreal Engine 5, third person (job postings mention IK and mocap). https://www.heftig.com/?p=1184 (SNIPPET). Sons of the Forest: first person, you can look down to see equipped armour on your own body (Q&A report). https://dreadxp.com/?p=30887 (SNIPPET). ARK: Survival Ascended players complained the first-person camera sits too low (Steam thread). https://steamcommunity.com/app/2399830/discussions/0/3954784199559638352 (SNIPPET).
- **F9 NOT CONFIRMED / not researched:** Palworld, Kenshi, Mount & Blade, Green Hell, original ARK, Vintage Story (no developer source), V Rising specifics, any GDC postmortem on survival-game character animation, 7 Days to Die first-person arms details.
- **F10 Pattern across F1, F3, F5, F6 (my synthesis, labelled).** Where there is a separate first-person arms rig plus a full body, the two drift apart unless deliberately kept in step (Rust took years, Medieval Dynasty has a stream of bugs). Small rigs stay workable if the geometry does not hide the held item. Context-specific animation layers beat one giant state machine.

## 3.7 Round 2, gait numbers, special movement, action feel, camera shake

Bottom line from this round (agent report, which I accept): **the numeric gait table written earlier by Tyler (walk 1.4 m/s, cadence 100 to 120, step 0.65 to 0.8 m; jog, run, sprint speeds; trunk lean 1-3 / 4-7 / 8-12 degrees; knee peaks 60 / 95 / 110 degrees) could not be confirmed or refuted by any source found.** They stay "from memory, tunable by eye". The only well-supported numbers are below.

- **G1** Cadence of at least about 100 steps/min is a consistent heuristic for moderate-intensity walking in adults. https://pubmed.ncbi.nlm.nih.gov/29858465/ (SNIPPET). Older able-bodied adults: stride about 1.35 to 1.53 m (step about 0.68 to 0.77 m) at 103 to 112 steps/min. https://pubmed.ncbi.nlm.nih.gov/26210370/ (SNIPPET). So 100 to 120 steps/min and a 0.65 to 0.8 m step are plausible for a walk, not confirmed for young adults.
- **G2** In one study cadence did not depend on age, height or weight at preferred speed, while stride length did. https://pubmed.ncbi.nlm.nih.gov/11292147/ (SNIPPET). Use for design (RECOMMENDATION): keep cadence similar across body sizes and scale stride with leg length.
- **G3** The walk-run transition happens at a Froude number of about 0.5 (v squared over g times leg length). https://pmc.ncbi.nlm.nih.gov/articles/PMC1617162 (SNIPPET; page blocked). With a 0.9 m leg this is about 2.1 m/s (my arithmetic). Matches A9 and the game's jog start at 2.2 m/s.
- **G4** Running style is described by step frequency and duty factor; faster running raises step frequency and lowers duty factor, flight time rises. https://pmc.ncbi.nlm.nih.gov/articles/PMC9760857 (SNIPPET; which of two URLs carries it is unconfirmed). No degrees found.
- **G5** Arm swing: arms act as passive dampers of upper-body rotation, shoulders counter-rotate against the pelvis; shoulder and elbow motion grows with speed; restricting the arms shortened stride and speed. https://pubmed.ncbi.nlm.nih.gov/19181900/ (SNIPPET), https://www.mdpi.com/2076-3417/15/12/6593 (SNIPPET). No degrees found.
- **G6** Carrying a load: forward trunk lean and higher cadence are consistently reported; stride change is not consistent. Systematic review of 54 studies: https://espace.curtin.edu.au/handle/20.500.11937/20483 (SNIPPET). Soldiers with 10.7 to 17.5 kg leaned forward about 10 degrees or more and took longer, faster strides. https://pubmed.ncbi.nlm.nih.gov/20496244/ (OPENED, abstract). A 40 percent body-mass pack is reported to give shorter, faster strides (LaFiandra 2003, no URL: MEMORY level, not used as fact).
- **G7** Crouch walking: only clinical crouch-gait data was found (deeper stance knee flexion, smaller swing flexion); weak evidence for a game crouch walk. https://pmc.ncbi.nlm.nih.gov/articles/PMC3233366 (SNIPPET).
- **G8** Swimming: freestyle phases are catch, pull, push, recovery; body roll guidance conflicts (about 30 to 45 degrees). https://royallifesavingwa.com.au/programs/swim-teacher/swim-teacher-tips/freestyle-stroke-technique (SNIPPET, low authority). **NOT CONFIRMED: breaststroke, treading water.**
- **G9** Ladders: standard portable ladder rung spacing is 305 mm; rung spacing sets stride length. https://cdc.gov/niosh/bulletin/2023/research-rung-spacing.html (SNIPPET). Climbing is described with three points of control. https://www.mdpi.com/1660-4601/17/8/2897/htm (SNIPPET). Game rule of thumb (agent's, not a source): one limb moves at a time, alternate hand and foot. Our ladder rungs are 0.35 m apart (terrain_client.gd `LADDER_RUNG_M`), close to that spacing.
- **G10** Riding: the rider's pelvis is the main connection and must follow the horse's motion; rider pelvic motion differs by gait (trot mainly vertical, canter rocking). https://www.usdf.org/EduDocs/The-Rider/In_Search_of_Balance1.pdf (SNIPPET), https://uwe-repository.worktribe.com/OutputFile/7521252 (SNIPPET). **NOT CONFIRMED: rider pose angles; the 4/2/3 beat counts are MEMORY.**
- **G11** Responsiveness: about 40 ms end to end for competitive shooters, 50 to 70 ms for action games, with animation start-up frames counting as latency (blog, low authority). https://bugnet.io/blog/debugging-input-lag-in-action-games (SNIPPET). A patent filing says latency beyond about 70 to 80 ms hurts fast-action play. https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11071908 (SNIPPET). A study found players did not rate the most natural but least responsive controller as better, though observers did. https://repository.upenn.edu/hms/141 (SNIPPET).
- **G12** Coyote time and jump buffering are described by Celeste's author as small cheats for feel, with no frame counts. https://gigazine.net/gsc_news/en/20200317-celeste-action-feel-things (OPENED). (The "6 frames each" claim is from one tutorial site only and is not used.)
- **G13** Camera shake: Eiserloh's GDC 2016 talk "Juicing Your Cameras With Math" exists (page confirms framing, smoothing, shake). https://gdcvault.com/play/1023146/Math-for-Game-Programmers-Juicing (OPENED). The trauma model (trauma 0 to 1 added by events, decays, shake = trauma squared or cubed, noise-driven) comes from secondary sources and memory. https://www.strayspark.studio/docs/godot-camera-system/noise-and-shake (SNIPPET).
- **G14** Foot slide: perception thresholds studied (camera motion raises the threshold); values not obtained. https://diglib.eg.org/handle/10.2312/SCA.SCA11.287-294 (SNIPPET). Foot-locking practice: detect the planted foot and hold its world position with IK until lift-off; sliding mostly comes from play rate not matching travel speed, so match playback to speed first. https://theorangeduck.com/ (SNIPPET), https://deepmotion.com/article/foot-locking (SNIPPET).
- **G15** **NOT CONFIRMED / nothing credible found:** turn-in-place and lean-into-turn technique; running cadence; flight-phase fraction; trunk lean degrees; knee flexion degrees; counter-rotation degrees; Dean 1965 step-length equation.

## 3.8 Round 2, stylised design, budgets, modular characters, animation cost, secondary motion

Project fact (code): `project.godot` features line says Godot 4.7 with the **Forward Plus** renderer (line 22). That matters for H3 and H6.

- **H1** SpringBoneSimulator3D shipped in **Godot 4.4** (this corrects B12, which said 4.5): the 4.4 release page lists it as a new node for hair, cloth and tails built on SkeletonModifier3D. https://godotengine.org/releases/4.4/ (OPENED). It returns bones to the original pose (unlike PhysicalBoneSimulator3D) and has `external_force` for wind. https://docs.godotengine.org/en/stable/classes/class_springbonesimulator3d.html (OPENED). A contributor blog snippet saying 4.5 conflicts; I trust the release page.
- **H2** Valheim cape physics: only a third-party collider mod mentions hip and lower-back cloth colliders; not an Iron Gate statement. https://valheim.thunderstore.io/c/valheim/p/HugotheDwarf/More_and_Modified_Player_Cloth_Colliders/v/3.0.1/ (SNIPPET). **NOT CONFIRMED: vertex-shader sway for capes in low-poly games (no source found).**
- **H3** Animation cost in Godot: `callback_mode_process` MANUAL means the mixer only steps when you call `advance(delta)`, so distance-based update rates are possible; there is no built-in throttle property. https://docs.godotengine.org/en/stable/classes/class_animationmixer.html (OPENED). `Skeleton3D.modifier_callback_mode_process` also has a MANUAL mode; if animation is throttled, modifiers (spring bones, look-at, IK) should be throttled too. https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html (OPENED).
- **H4** A known open engine issue: about 100 animated skeletons on the **Compatibility (OpenGL)** renderer ran under 20 fps against over 100 fps on Vulkan; a maintainer said skin deformation, not animation playback, is the bottleneck; workarounds are spreading updates across frames, pausing distant animation, impostors. https://github.com/godotengine/godot/issues/88954 (OPENED). Relevant: this project uses Forward Plus; the issue would bite if a Compatibility renderer option were ever added for weak machines (RECOMMENDATION: check before promising one).
- **H5** Unity's animator culling modes (always animate, cull update transforms, cull completely) show the standard idea of not animating what is not seen. https://docs.unity.com/en-us/engine/current/manual/animation-section/animation-mecanim/class-animator (OPENED). Unreal has update-rate optimisation flags; mechanics not documented in what was reachable. https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/Engine/USkinnedMeshComponent (OPENED, flag names only). **NOT CONFIRMED: the official Unreal URO guide.**
- **H6** Modular characters in Godot: a `MeshInstance3D` has `skeleton` and `skin`; the default of `skeleton` changed in Godot 4.6 (a project setting restores the old behaviour), so check this when swapping armour meshes; baking meshes from the current pose stalls the renderer and is not for runtime use on many characters. https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html (OPENED). Several meshes on one skeleton using different `Skin` objects get several skeleton RIDs, so each differently skinned armour piece may add skinning work; sharing one `Skin` resource or merging meshes avoids that (the agent's inference from the docs, to be profiled). https://docs.godotengine.org/en/stable/classes/class_skinreference.html (OPENED).
- **H7** Per-instance shader parameters (`instance uniform` plus `set_instance_shader_parameter`) allow per-player colours or region toggles on one shared material. https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html (OPENED)
- **H8** MultiMesh and skinned meshes: no documentation found saying a MultiMesh can be skinned; Godot's own tutorial does crowds with vertex-shader animation because CPU bone animation does not scale. https://docs.godotengine.org/en/stable/tutorials/3d/vertex_animation/animating_thousands_of_fish.html (SNIPPET; page flagged as not updated for 4.7). So "skinned bodies cannot be batched" is very likely but **not confirmed by an explicit doc**. Baked vertex-animation textures are the documented alternative (a plugin exists; SNIPPET).
- **H9** **NOT CONFIRMED:** whether Forward+ skins on GPU or CPU in Godot 4; any authoritative way to hide body regions under clothing (shader masks, vertex colour regions, blend shapes). MultiMesh ignores blend shapes (SNIPPET).
- **H10** Godot automatic mesh LOD (meshoptimizer at import, 1 pixel threshold by default) warns it can cause rendering issues in skinned meshes; at 1.5 to 3k triangles the gain is small, so hand-made low LODs with visibility ranges are safer. https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html (OPENED). Visibility ranges: begin and end measured to the AABB centre; fade mode DISABLED acts as hysteresis and is cheapest; alpha-fade modes need Forward+ (fine here). https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html (OPENED)
- **H11** Triangle budgets: **no developer-stated figures found for Valheim, Minecraft, Fortnite or Overwatch.** Overwatch heroes at about 30 to 34 thousand triangles with four LODs is a community claim only. https://polycount.com/discussion/235824/anyone-know-overwatch-2-tri-count-for-hero-characters (SNIPPET). A CryEngine character budgets page exists (not opened). Generic mobile 3k to 10k is vendor material (see D7). **Therefore the project's own budget cannot be justified from outside sources; it must be set by measurement on the minimum machine (RECOMMENDATION).**
- **H12** Valheim's player: no verified Iron Gate source for how the character, armour, cape and weapons are built. Soft facts only: equipment has head, chest, legs, cape and held-item slots (preview, SNIPPET); the art director says the low-poly look is deliberate. https://widgets.sportskeeda.com/esports/news-the-story-deathsquitoes-rule-cool-valheim-s-journey-robin-eyre-art-director-creative-lead-sportskeeda-exclusive (SNIPPET). Nothing found on customisation.
- **H13** Stylised design: Team Fortress 2's wiki summarises the design aim that a character is recognised by silhouette without lighting, class differences come from body proportion, weapon and silhouette, rim highlights replace dark outlines, and shading varies hue and luminance. https://wiki.teamfortress.com/wiki/Artstyle (OPENED; wiki summary, not the paper). The Valve paper and slides exist (Mitchell, "Illustrative Rendering in Team Fortress 2", SIGGRAPH 2007 notes https://www.advances.realtimerendering.com/s2007/Mitchell-IllustrativeRenderingInTF2(Siggraph07%20Course%20Notes).pdf and GDC 2008 https://cdn.steamstatic.com/apps/valve/2008/GDC2008_StylizationWithAPurpose_TF2.pdf) but the fetch tool could not read them: **I have not read them (SNIPPET: URLs only).**
- **H14** Joint topology: forum advice says place a loop at the pivot of a joint with supporting edges either side and more density where it bends (community opinion, no wiki text). https://www.tech-artists.org/t/edgeflow-for-good-deformation/895 (SNIPPET), https://polycount.com/discussion/comment/1823338 (SNIPPET). **NOT CONFIRMED: heads-tall ratios, big hands and feet, simplified faces, Overwatch or Fortnite design talks, Zelda BotW analyses.**

## 3.9 Round 2 (Godot gaps) and my own round-3 spot checks

**Godot 4.7 and animation nodes (agent, round 2):**

- **I1** The 4.7 "stable" docs are the current docs; the 4.7 release page lists no skeleton or IK changes (animation items: collapsible editor nodes, `Tween.tween_await()`). https://godotengine.org/releases/4.7/ (OPENED). The 4.7 upgrade page notes: `add_blend_point` on BlendSpace1D/2D gets an optional name, **`LookAtModifier3D.relative` default changed from true to false**, no skeleton/IK deprecations listed. https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html (OPENED). The 4.6 release page confirms the new IK framework (IKModifier3D, TwoBoneIK3D, SplineIK3D, FABRIK3D, CCDIK3D, JacobianIK3D, with constraints). https://godotengine.org/releases/4.6/ (OPENED). SkeletonIK3D: deprecated, class still present in 4.7 docs (settles the question left open in B10). https://docs.godotengine.org/en/stable/classes/class_skeletonik3d.html (OPENED)
- **I2** Filter API sits on the base `AnimationNode`, so Blend2, Blend3, Add2 and OneShot all have `filter_enabled`, `set_filter_path(path, enable)`, `is_path_filtered(path)`. https://docs.godotengine.org/en/stable/classes/class_animationnode.html (OPENED). Path form is `<skeleton path relative to the tree's root_node>:<bone name>`, from a forum example that builds a tree in code. https://forum.godotengine.org/t/journal-samples-how-to-setup-animationtree-by-code/110728 (OPENED). That example used an imported skeleton, so **a tree on a code-built skeleton and player is plausible (tracks are only paths) but is not confirmed by any source: prototype it first.**
- **I3** OneShot has `fadein_time`, `fadeout_time`, `mix_mode` (blend or add), `autorestart`, `break_loop_at_end`; fire it with `parameters/OneShot/request`. https://docs.godotengine.org/en/stable/classes/class_animationnodeoneshot.html (OPENED). Blend2 amount range 0 to 1, Blend3 -1 to 1, Add2 for out-of-range. https://docs.godotengine.org/en/stable/classes/class_animationnodeblend2.html (OPENED)
- **I4** BlendSpace sync modes: none, independent, cyclic mutable (cycle length from the active weights) and cyclic constant (fixed `cyclic_length`); `AnimationNodeAnimation` has `stretch_time_scale`, `start_offset`, `use_custom_timeline` for matching walk and run cycle periods. https://docs.godotengine.org/en/stable/classes/class_animationnodeblendspace2d.html (OPENED), https://docs.godotengine.org/en/stable/classes/class_animationnodeanimation.html (OPENED). Introduction version of sync modes: NOT CONFIRMED.
- **I5** State machine class: transitions added in code with `add_transition(from, to, transition)`; playback through `parameters/playback`. https://docs.godotengine.org/en/stable/classes/class_animationnodestatemachine.html (OPENED). Transition properties (switch mode, advance condition, cross-fade time) were not verified.
- **I6** Root motion lives on `AnimationMixer` (`root_motion_track`, getters for position, rotation, scale and accumulators). https://docs.godotengine.org/en/stable/classes/class_animationmixer.html (OPENED)
- **I7** Skeleton3D: `add_bone` names must be unique with no `:` or `/`, parent index must be lower than child index; no maximum bone count is stated on the page. https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html (OPENED). GeometryInstance3D docs mention a custom AABB avoids costly AABB recalculation when a skeleton is used (the current mesh already sets one, Part 1.2). https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html (OPENED). **No official statement of GPU or CPU skinning, bone limits per skin, batching or per-character cost was found.** Profile.
- **I8** GeometryInstance3D visibility ranges: begin/end plus margins (hysteresis with fade disabled); fade modes SELF and DEPENDENCIES only in Forward+. https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html (OPENED). `VisibleOnScreenNotifier3D` is approximate with no occlusion. https://docs.godotengine.org/en/stable/classes/class_visibleonscreennotifier3d.html (OPENED)
- **I9** `PhysicalBoneSimulator3D` offers `physical_bones_start_simulation()` and `stop` (ragdoll for faint/death); PhysicalBone3D details not read. https://docs.godotengine.org/en/stable/classes/class_physicalbonesimulator3d.html (OPENED). `CharacterBody3D` has floor snap and slope settings but **no built-in stair support**; the project already has its own `step_up.gd` (Part 1.4). https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html (OPENED)

**My own spot checks (round 3):**

- **J1** I re-opened the Rust "Built Different" devblog myself. It is dated 4 June 2026 and says what F1 reports: new player model with more realistic proportions after almost 10 years, new rig with more natural bind pose and twist bones, Maya rig replaced (IK/FK spine, pose libraries, mocap), the single 250-plus-animation state machine replaced by small context-specific behaviours (torch: right arm only), and third-person animation matched to the first-person viewmodel where possible. https://rust.facepunch.com/news/Built-Different (OPENED by me). Confirms F1.
- **J2** I read the two Valve texts myself (local copies of the PDFs the agent downloaded, text extracted with `pdftotext`). SIGGRAPH 2007 course notes, Mitchell, Francke and Eng, "Illustrative Rendering in Team Fortress 2": the nine class silhouettes were designed to be distinct; body proportions, weapons and silhouette lines from footwear, hats and clothing folds were designed to give each a unique silhouette; interior clothing folds echo the silhouette; characters were validated as readable in plain silhouette during concept; rim highlights replace dark outlines. https://www.advances.realtimerendering.com/s2007/Mitchell-IllustrativeRenderingInTF2(Siggraph07%20Course%20Notes).pdf (READ). GDC 2008 slides "Stylization with a Purpose": read hierarchy of team colour, class by silhouette and proportion, weapons; character creation order silhouette, interior shapes, model sheet, 3D model, skin; "keep it iconic". https://cdn.steamstatic.com/apps/valve/2008/GDC2008_StylizationWithAPurpose_TF2.pdf (READ). This upgrades H13 from "not read" to read for these two documents. They contain no numeric proportions.
- **J3** A new web search for stylised head-height ratios and hand/foot sizing returned generic articles (silhouette test as black shape, grayscale check, shape language) and no usable numeric guidance: https://80.lv/articles/character-design-shape-language-and-readability/ and https://rocketbrush.com/blog/shape-language-in-game-character-design-how-to-make-characters-readable-and-consistent (SNIPPET, search summary only). **Proportion numbers remain NOT CONFIRMED by any source**; the plan's numbers are my starting values.

## 3.10 How many rounds, and what is still unknown

- **Round 1:** six sub-agents, one per topic (A to F). **Round 2:** three sub-agents on the gaps round 1 left (gait and feel numbers; design, budgets, modular, animation cost, Valheim; Godot-specific gaps). **Round 3:** my own spot checks (J1 to J3) plus reading the Valve documents. That is **three rounds**. Round 3 found nothing that changes the plan, so I stopped there. Round 2 did add important items (the Compatibility-renderer skinning issue H4, SpringBoneSimulator3D version H1, the unverified gait table 3.7, the lack of stairs support I9, the 4.7 `LookAtModifier3D.relative` change I1), so I would not call the research exhaustive, only sufficient for planning.
- **Limits.** Most sources were summarised by a small model on fetch and many pages were not fully readable (several returned 403 or were blocked). Dozens of items are SNIPPET-level. I did not re-check every claim. Treat SNIPPET items as leads. A second pair of eyes should re-open the sources behind any decision that costs a lot (the Compatibility-renderer issue, the multiplayer approach, the choice of IK nodes).
- **Still NOT CONFIRMED (the honest list):** numeric human gait values (3.7 G15); proportion numbers for stylised bodies (J3); developer-stated triangle budgets for comparable games (H11); how Valheim, Ark, Rust, 7 Days to Die sync animation and build armour (E11, F7, H12); turn-in-place and lean-into-turn technique (G15); procedural arm swing and left-hand IK recipes (C11); a Godot recipe for foot and hand IK with the new 4.6 nodes (B10, I2); whether skinned meshes can be batched and how Forward+ skins (H8, H9, I7); an official input-latency standard (G11); remote-player foot-sliding fix (E11); mounted riding pose angles (G10); breaststroke and treading (G8); Unreal's official URO guide (H5); the Overwatch GDC talk content (E7).

---
