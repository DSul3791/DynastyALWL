# Player Character Design (Sonny)

Owner of this document: Sonny, the agent who owns the look, feel and movement of the main player character.
Status: **research and planning only (first pass, written 2026-10-30). Nothing in the game has been changed.** Dave reviews this before any work starts.
Branch: `sonny-character`. This file is the only file added or changed.

**How to read it.** Every statement is labelled:

- **FACT (code)**: read from the repository on this branch; the file path is given. Line numbers (marked "~") are approximate positions on 2026-10-30.
- **FACT (doc)**: stated in one of our own documents; source file and heading are given.
- **FACT (web)**: stated by an outside source; the URL is in the Research log (Part 3) with a confidence note.
- **RECOMMENDATION**: my own opinion; always labelled.
- **UNCONFIRMED**: could not be checked; stated as such.

Older project documents mention an earlier agent called Sonny who worked on terrain and water. That is a different role; only the player-character parts of those documents are used here.

## Contents

1. Present state of the player character (Step 1)
2. Our own documents about the player character, copied by topic (Step 2), with the list of passages to remove from the originals once Dave approves
3. Research log (Step 3)
4. Player character design guides and rules (Step 4)
5. Movement and animation plan
6. Gap analysis
7. Phased roadmap, risks, open questions, decisions only Dave can make

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

# Part 2. Our own documents about the player character

These passages are **copied unchanged** (each line prefixed with "> ") from the source files, which are untouched. Each has its source file, line range and nearest heading. Where the documents disagree, see 2.9. Old agent names in these passages: Mandy and Art = the arts director (now Kathleen_ArtisticDirector); Tyler = technical research; Steve = former technical director; Radar/Items = items; Sonny in those passages is the earlier terrain/water agent, not me.

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

