# Character design vision (Sonny; research and plan, 30 Oct 2026; for Dave to review)

Status: **research and planning only. Nothing in the game has been changed.** Branch `sonny-character`; this is the only file added.

Goal: the player character should look and move like a natural, readable person: arms swinging properly in walk and run, weight in every start and stop, believable swings, digs, chops and builds, and the same quality in first person, third person, for other players and for NPCs. It must stay cheap enough for the minimum machine (GTX 1050, 8 GB) and fit a stylised look beside a near-photoreal world.

## The target picture
- **Looks:** slightly stylised, heroic proportions, a hint of cartoon (Dave, 2026-10-20, ART_DIRECTION.md section 10), readable as a silhouette at 70 m. Joints that bend. **Decided (Dave, 2026-10-30): a simple stylised human** (simple face, hair, hands), not the featureless ragdoll. The motion work still comes first (Phases 1 and 2).
- **Moves:** blended gaits instead of clip switches; jump, fall, land, crouch walk, strafe, turns, ladders, swimming, slopes with planted feet; actions with anticipation, contact and recovery fired from clip events.
- **Both views agree:** one skeleton, one set of clip names, one shared action definition per tool, so first-person arms, third-person body, NPCs and other players never drift apart.
- **Network:** velocity, stance and action ids go over the wire; each client works out the pose.

## Why (the short version)
- Today the body is blobs on rigid weights with 17 bones and hard clip switches; third-person swings do not show; there are no jump, swim or climb clips; other players are not drawn (Part 1).
- Comparable games show the traps: first and third person drifting apart (Rust, Medieval Dynasty), giant state machines (Rust), rigs too crude to bend (Unturned) (Part 3, F1 to F10).
- The research could not confirm many numbers (gait angles, proportions, budgets). So the plan treats numbers as tunable and measures on the minimum machine (Part 3.10).

## Art direction (Dave, 2026-10-30)
Dave's words, paraphrased: realistic, but "fantasy fun realistic": older cartoons combined with a hyper-real surrounding; classic fantasy adventure picture books, or Final Fantasy without looking like Final Fantasy. Characters may look like Gaston, like Link, or like Dragon Ball characters. Broad audience, a fusion of cartoon and realism. The model does not have to be perfect: leave out detail where it is easiest and exaggerate, and let that become the style.

What this means for the plan (RECOMMENDATION, my reading; the named characters are Dave's references and I have not researched them):
- **Stronger stylisation than ART_DIRECTION.md section 10.** That section says "slightly stylised, a hint of cartoon". This direction is a deliberate cartoon-realism fusion. ART_DIRECTION.md sections 5 and 10 should be updated by Dave's approval (section 5 says "storybook" lives in colour and mood, not shapes; the new direction puts it in the shapes too).
- **Exaggeration is a design tool, not a flaw.** Pick what to exaggerate per archetype (chest and shoulders for a brawler, lean limbs for a scout, big hands, feet and head), and drop what is hard in code (fine faces, individual fingers, hair strands). This matches how the Team Fortress 2 papers I read design characters from silhouette and body proportion first (Part 3, J2).
- **Body archetypes as parameters.** The code-generated body (D2) suits this: a few archetype presets (broad and heavy, lean and tall, stocky, muscular) are just different numbers for limb length, radius, shoulder width, head size and hand size. My earlier single set of proportions (7 to 7.5 heads tall, Part 4.2) is replaced by a range per archetype, to be set by eye with Dave.
- **Acting comes from the body and hands, not the face (Dave, 2026-10-30).** The character does not need face acting if pose, actions and hand acting carry the emotion; think claymation comedy. So: **no lip-sync and no detailed facial animation**; the face is a readable, exaggerated shape. **Correction after research (3.11.1):** the claymation characters Dave's style points to still use a minimal eye, lid and brow channel (Gromit has no mouth but acts with brow and eyes; Shaun relies on eyes and ears), so I keep a *minimal* eye and brow channel as a cheap support (see 4.6). Fear, surprise, pride and effort are shown with held poses, big anticipation, squash and stretch style timing, head and neck moves, shoulders, and above all **hands** (clutching the head, flapping, pointing, wringing, shielding the eyes). I have not researched claymation or stop-motion technique; the named style is Dave's reference.
- **Animation must suit the exaggeration.** Cartoon-leaning bodies read best with strong poses, clear anticipation and follow-through and held key poses (Part 3, A1, A2), while staying grounded (weight, planted feet). One shared skeleton still serves every archetype; clips are scaled or adjusted per archetype rather than re-authored.
- **Open question (D9):** how much of this variety is player-chosen, and how much is for NPCs only. Also check it against the "safe place" rule (no divisive labels, Part 4.1 item 8) and the disguise idea that height and build are hard to change (DESIGN_IDEAS.md section 9.2).
- **Risk:** broad variety multiplies the animation checking (a long reach looks different on a stocky body). Mitigation: test every clip on the two most extreme archetypes.

## Character creation (Dave, 2026-10-30)
Players also pick a D&D-like background and traits (roll or point buy) and a greatest fear that can make the character panic, run away screaming and flail comically (Part 5.8). Players build their characters: an **ancestry** (human, orc, elf and others), which brings cultural boons and unfortunate traits; **sliders** for the skeleton and body (size, build, proportions, gait); the **face** (bone structure and features); **skin colour**; **hair** (style, length, colour); more (age, markings, handedness and others, see Part 5.7); and a **dice button** for everything and one **per section**. A character is a small list of numbers (a genome) saved on the server and turned into a body on each client. Details, suggestions and one rule flag (keep boons and drawbacks to fantasy peoples, keep skin tone and features cosmetic) are in Part 5.7.

## Decision sheet (one page; Sonny, 2026-10-30)

Dave asked me to decide without him wherever I can and to ask only if I really need him. So the decisions below are **provisional decisions by Sonny**: I will work to them unless Dave says otherwise. Each is reversible before the phase that uses it. Full table with options: Part 7.4.

**Decided by Dave:** D1 the character is a simple stylised human. Art direction: cartoon-realism fusion with body archetypes; character creation with ancestry, sliders, face, hair, dice buttons; each character has its own account and a new player must make one; a D&D-like background and traits (roll or points); a greatest fear that can trigger a comic panic.

**Decided by Sonny (provisional):**
| # | Decision | Why |
|---|---|---|
| D2 | Generate the body in code (smooth distance-field body, scripted soft weights, baked and cached by genome); a modeller can replace head and hands later | Dave leans that way; no modeller needed; sliders stay numbers (3.11.3) |
| D3 | Keep the arms-only first-person viewmodel; own camera-space clips driven by the same action records as third person | cheap, proven; Rust's years of drift show why records are shared (F1) |
| D4 | Third person is a first-class view for actions | cheap once records are shared |
| D5 | Order of work: Phase 0 to 2, then body, face, creator | clips survive the body change because the skeleton comes first |
| D6 | No sprint, roll or dodge until combat design needs them | scope |
| D8 | Keep the 15, 40 and 70 m animation tiers, with hysteresis; measure | already Dave's rule |
| D9 | Players: skin tone, hair, coat colour, face presets and a few archetypes; NPCs: full range | variety without a slider explosion (N2, N3) |
| D11 | Accept the animation quality targets in 4.4 as tunable defaults | no outside standard exists (3.10) |
| D12 | Triangle, bone and cost budgets are set after the Phase 0 measurement | no developer-stated figures found (H11) |
| D13 | Purchased animation only with a clear licence and a bone-map retarget; no motion matching | A8, B15 |
| D14 | First ancestries: human (neutral baseline), orc, elf | Dave's examples |
| D15 | Ancestry boons: small, mostly physical or lifestyle, fantasy peoples only; larger bonuses in backgrounds and traits | research (N12) and Dave's safe-place rule |
| D16 | Body size is cosmetic only (same capsule, reach, camera height) | fairness, keeps the 1.8 m tuning |
| D17 | After creation: hair, colour and tattoos can change; height and build cannot | matches DESIGN_IDEAS 9.2 |
| D18 | Creation happens at character selection when the player has no character (Dave's flow) | Dave |
| D19 | Creator version 1: ancestry, background, traits, height, build, skin, hair, face presets plus about eight face sliders, dice and locks | N2, N3 |
| D22 | Traits: point buy by default, plus a bounded-variance roll option | N9 |
| D24 | A greatest fear is hidden from other players | PvP exploit risk |
| D25 | Panic: hazard-aware run, short, with a cooldown and a setting to reduce or disable it | fairness; sources thin (N13 to N15) |
| D27 | The reaction replay is a future idea, owner-only and skippable | scope |
| D28 | Smooth motion by default; held, stepped poses only in comic beats; simplified hands with a thumb and two or three finger groups; minimal eye and brow channel by swap | 3.11.1, 3.11.2 |

**Really needs Dave or another owner (I cannot decide these):**
- **A. D10: ownership and the removal list. ANSWERED by the moderator on Dave's behalf (Part 8.1):** yes to the new module with minimal edits to the shared files; do not remove passages outright, archive them instead (not yet done, 8.4). Dave may still overrule.
- **B. D15 wording:** do you want ancestry-linked boons to stay as small fantasy-people traits, or kept entirely in backgrounds? The research and your rule push toward the second; you asked for the first. I chose the middle path above.
- **C. D20 and D21: accounts.** How many characters per player, how they link to the dynasty and heirs, and how one account per character fits the identity plan. This belongs to the technical lead and the dynasty design.
- **D. D23 and the trait and background content:** the final fear list, the background list and the trait rules are your design; I supplied a draft fear list (5.8.8) only.
- **E. Look sign-off.** The first body must be approved by your eye (proportions and archetype shapes). I cannot judge that for you.

## Principles
See Part 4.1 (eight principles: readable first; believable weight; one body many views; actions are events; derive, don't send; cheap at distance; every number has a knob; no divisive defaults).

## How the pieces fit
`ragdoll_body.gd` (rig and clips) -> `terrain_client.gd::_update_view` (picks clips) -> `held_item.gd` (first-person arms and tools) -> `worn_look.gd` / `worn_sync.gd` (clothes) -> `npc_view.gd` (NPCs). The plan puts an `AnimationTree` and a shared action library in the middle of that chain (Part 5.1) and changes the body last (Phase 3).

## Plan in one paragraph
Phase 0 define the new skeleton and the character genome, research character creators, measure and prototype; Phase 1 animation architecture; Phase 2 missing locomotion; Phase 3 body generator and archetypes; Phase 4 face, hair, skin and marks; Phase 5 character creation (ancestry, sliders, dice buttons); Phase 6 tool and activity library; Phase 7 equipment and secondary motion; Phase 8 other players; Phase 9 special states (Part 7.1, revised 2026-10-30). Risks in 7.2; open questions 7.3.

## Decisions for Dave
D1 look (DECIDED 2026-10-30: simple stylised human), D2 how the body is made, D3 first-person approach, D4 third-person priority, D5 order of work, D6 sprint/roll, D7 when other players appear, D8 distance tiers, D9 customisation, D10 file ownership and approval of the removal list, D11 quality bar, D12 budgets, D13 purchased animation, D14 to D28 ancestries, boons and drawbacks owner, whether size matters in play, later appearance changes, where creation happens, creator scope, character account, trait system, fear list and secrecy, panic mechanics, who designs backgrounds, the future reaction replay, acting style and finger bones (Part 7.4, each with my recommendation).

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
- **Proportion rule (RECOMMENDATION, not sourced; superseded in part by the 2026-10-30 art direction at the top: use a range per archetype, not one set):** no outside source for head-heights or hand and foot size was found (H14). Propose a 7 to 7.5 head-tall body with hands and feet about 10 to 15 percent oversize, shoulders slightly broad, as a *starting* value to be decided by Dave's eye on a side-by-side with the current figure. Clearly marked UNCONFIRMED by research; validate with the silhouette test below.
- **Silhouette test (basis: TF2 paper, H13):** every new body, tool, hat or garment must still read when drawn as a flat black shape at the size the character appears at 20 m, 50 m and 70 m. Test before any shading work.
- **Colour and contrast:** keep the existing four-region tint (skin, coat, trousers, shoes) for cheap variation (Part 1.2). Prefer value contrast between torso, arms and legs so the swing of an arm reads against the body.
- **Shape language:** rounded shapes for the body are already in place; hands and tools need distinct silhouettes (tool head larger than realism, grip visible).
- **Faces and hair (decision pending):** if added, keep them as a few large shapes on the head mesh or texture, not geometry detail; the small-rig Minecraft and Unturned experience shows a simple face plus strong body motion carries a lot (F3, F6).
- **Joints must bend (basis: H14 community advice and the current "blob" weights):** the current rigid weights give a stick-figure look (Part 1.1). The next body must have a joint loop at each elbow, knee, shoulder, hip, wrist, ankle and neck and soft weights across it. Keep the 7 to 10 degree bend visible at the knee even in walk.
- **Skin tones and body variety:** allowed variation: skin tone, hair, coat colour, body build within a narrow range (disguise rule in DESIGN_IDEAS section 9.2: height and build are hard to change). Detail in Part 7.

## 4.3 Skeleton and rig conventions

- **Bone names (RECOMMENDATION, basis B6 B7):** adopt the Godot humanoid names (`Hips`, `Spine`, `Chest`, `Neck`, `Head`, `LeftShoulder`, `LeftUpperArm`, `LeftLowerArm`, `LeftHand`, `LeftUpperLeg`, `LeftLowerLeg`, `LeftFoot`, `LeftToes`, and Right) so any future imported animation, Mixamo-style or purchased clip set can be retargeted by a BoneMap (B6) and RetargetModifier3D (B8) instead of re-keying. The current names (`arm_r`, `forearm_r`, `thigh_r`...) can stay as an internal alias table.
- **Minimum new bones:** shoulders (clavicles) so the shoulder can shrug and the arm can reach without twisting the chest; toes so the foot can roll; `UpperChest` optional. Add helper/twist bones only if the mesh shows candy-wrapper twisting. Fingers: **since acting is carried by the hands (Dave 2026-10-30), do not stop at a single grip pose.** RECOMMENDATION: a simplified hand with a thumb and two or three finger groups (for example index, middle-and-ring together, little), each with two or three bones, so the hands can point, wave, flap, clutch, wring, shield the eyes and grip a haft, in the exaggerated big-hand style; a full 15-bone-per-hand rig (the Godot humanoid profile has finger bones, B7) is more than needed. Exact count decided in Phase 0 (D28). Rust added twist bones and metacarpals in its rebuild (F1) but with a far larger budget.
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
- **Emotion reads from the pose alone (Dave 2026-10-30):** test each acting clip (panic, surprise, effort, pride, tired) as silhouette stills with the face hidden; it must still be clear what the character feels. Use held key poses, overshoot and settle, and hand shapes that tell the story. Optional style choice for Dave: hold some poses "on twos" or a little choppy for a stop-motion feel; I have not tested how this looks in the game (D28).
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

## 4.6 Acting without a face: pose, hands and timing (from the claymation research, 3.11; Dave 2026-10-30)

Facts first (research), then my provisional decisions.
- **FACT (web):** Gromit has no mouth but acts with brow, eyes, ears, neck, hands and body; Shaun relies on eyes, lids, ears and head and shoulder position; Pingu on the beak (3.11.1, L1 to L3). So "pose and hands" works, with a minimal eye or brow channel.
- **FACT (web):** the stop-motion look is poses held for two frames (12 poses a second at 24 fps) in ordinary action, with faster, detailed action on ones, and broadcasters mix them (L4). Spider-Verse and Puss in Boots mixed ones and twos by emotion and beat (K8, K9). Harold Halibut lowered the face frame rate and held key poses to keep a puppet feel (K5). No authoritative Aardman statement on their own frame practice was found (L5).
- **FACT (web):** a CG tutorial's starting recipe for a take at 24 fps: anticipation about 4 frames (6 for a punchier take), accent about 7, settle about 7; a double-take has two head-turn poses about 3 frames apart (L10). Tunable, not Aardman practice.

**Provisional decisions (Sonny; reversible):**
1. **Smooth movement by default; held, stepped poses only in comic beats.** Run normal gaits on smooth interpolation. For panic, surprise and other comic reactions, switch the upper body to held poses on twos (a new pose about every 1/12 s) with fast pops into the accent, as Spider-Verse switched rate by emotion (K8). Reason: stepped movement all the time would look like a bug at 60 fps and make controls feel laggy (response targets in 4.4), but it sells comedy for short moments.
2. **How to do it in Godot (verified API, K1 to K3):** set the pose tracks of the comic clips to `INTERPOLATION_NEAREST`; or step the mixer in `MANUAL` mode with `advance()` at about 12 Hz for those layers; step any spring bones and IK with the skeleton's own manual mode. A cheaper alternative, if clips are authored in Blender, is exporting with step sampling (K3, one user's report).
3. **Acting recipe for every emotion clip:** still neutral hold, short anticipation (4 to 6 frames at 24 fps as a starting value), a fast accent, an overshoot and settle, then a moving hold so the character never freezes (L10, L11, L13 Keaton stillness). One idea per pose; test each pose as a flat silhouette with the face covered (L12).
4. **Emotion pose vocabulary** (starting point, from L14): fear = lean away, shrink, shield the torso; surprise = brief jolt timed against the trigger; relief = shoulders drop, breath out; pride = chest out, head up, hands on hips; exhaustion = slump, limp arms, lagging head. The panic clips (5.8.5) build on these.
5. **Squash and stretch without breaking the rig (K10, K11):** do not scale the whole skeleton or the bones that spring bones use; spring bones warn against scaling. Use (a) extra helper bones above a chain that carry the squash, (b) translation of bones instead of scale where it reads, and (c) a vertex-shader or blend-shape squash for the whole body, with volume kept. Untested; prototype in Phase 0.
6. **Minimal face channel:** eyes with lids that can go wide, squint and blink, and an optional brow raise, by texture or mesh swap (3.11.1, L1, L2, L8: replacement parts are how stop-motion does expressions). No lip-sync.
7. **Hands carry a lot** (Part 4.3): simplified hands with a thumb and two or three finger groups, stored as poses (open, fist, point, flat, claw, clutch, wave) so a clip picks a pose per hand.
8. **Handmade charm:** a slightly uneven, thumbprint look is intentional in claymation (L9); a little irregularity in timing and a hand-made texture suit the style, but not at the cost of readability.

## 4.7 Ancestry, fairness and rules (from the creator research, 3.11.4; Dave 2026-10-30)

- **FACT (web):** the industry has moved ability bonuses away from the choice of people: Tasha's Cauldron let them be moved, Monsters of the Multiverse made them floating and dropped cultural traits for physical or magical ones, the 2024 rules moved bonuses to backgrounds, and WotC said the old word "race" is tied to prejudice against real peoples (N12). Dave's rule, from our own documents, is the same in spirit: the game never says anything that might divide people.
- **Provisional decision (Sonny):** keep Dave's direction (ancestries with cultural boons and drawbacks) **for fantasy peoples only (orc, elf and similar), made of small, mostly physical or lifestyle traits** (for example night sight, a heavier build, a harder time in cold), **and put the larger bonuses and drawbacks in backgrounds and traits chosen by the player.** Human is the neutral baseline with no fixed numbers. Skin tone, hair, face and body shape are cosmetic and gameplay-neutral for every ancestry. I flag this for Dave as the one place his instruction and the research pull in different directions (decision sheet, item B).
- **Rules and licence (N8, N11):** reuse only generic mechanics (point buy, a standard array, rolled dice) in our own words; if we ever copy D&D text, use only the SRD 5.2.1 under CC-BY-4.0 with attribution; avoid D&D names not in the SRD.
- **Roll or points (N9):** standard array and point buy average exactly 12 per stat; four dice drop the lowest averages about 12.24 but with a wide spread, so rolling is higher variance. In an online game players compare, so I provisionally set: point buy as the default; a roll option with bounded variance (a floor and a ceiling on the total, and a limited number of re-rolls) so neither is clearly better.

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

## 5.7 Character creation (Dave, 2026-10-30)

Dave's direction: players build their characters. They choose an **ancestry** (human, orc, elf and whatever else we find in other games), which brings cultural boons and unfortunate traits that vary by group. They adjust the **skeleton in a simple but effective way with sliders** for everything that changes look, gait and size. They adjust **facial bone structure and features**, **skin colour**, **hair style, length and colour**, and more. There is an overall **random (dice) button** and a **dice button in each section** for individual settings. Dave expects things are missing; my additions are marked.

**What I have and have not done.** This section is design only. I have **not researched** other games' character creators (sliders, face systems, dice buttons, ancestry systems); that is a proposed Phase 0 research round. Everything below is RECOMMENDATION built from the code facts in Part 1 and the research in Part 3, with the unresearched parts labelled.

### 5.7.1 The core idea: a character is a small list of numbers (the "genome")
- **RECOMMENDATION:** a character's appearance is a compact record: ancestry id, an archetype or body preset, and about 40 to 60 slider values, each quantised to one byte, plus colour and hairstyle ids. That is on the order of 60 to 80 bytes (my estimate). The body, face and hair meshes are **generated from the genome on each client**, by the same code, so only the genome crosses the network and is saved on the server with the character. This fits the existing plan to derive instead of send (Part 4.1 item 5) and the code-generated body (D2).
- **Cache by genome.** Generate each distinct body once and share the mesh between identical genomes (the current code already caches one shared mesh, Part 1.2). How long generation takes for 20 players entering view is unknown; measure in Phase 0.
- **The server owns the record**, validates ranges (clamps) and never trusts a client's numbers. Appearance is cosmetic; anything that changes gameplay (reach, speed, carrying, ancestry boons) is separate server data.

### 5.7.2 Ancestry (the people)
- **Ancestry** = a preset that sets slider ranges, default values, extra features (for example pointed ears, tusks, a heavier brow) and the gameplay boons and drawbacks. Examples Dave named: human, orc, elf. Which others, and how many, is Dave's call (D14). I have not looked at other games' lists.
- **Boons and drawbacks are server game design, not animation.** They belong with the items, skills and attributes design (the existing luck and fitness attributes; DESIGN_IDEAS.md and SKILLS_AND_ATTRIBUTES.md). This document only provides the visual side. Who designs and balances them is open (D15).
- **FLAG for Dave's rule check (my concern, not a refusal):** "ethnicity" with built-in cultural boons and unfortunate traits is sensitive. Dave's standing rule (2026-10-23) is that the game never says anything that might divide people and describes use, never who it is for (Part 2.9 item 10). Attaching drawbacks to groups is fine for **fantasy peoples** (orcs, elves) but would conflict with that rule if applied to real-world ethnic groups or to skin tone. **Recommendation: keep skin tone, hair and facial features a free, purely cosmetic choice for every ancestry with no gameplay effect; tie boons and drawbacks only to fantasy ancestries.** Also avoid a link where a body slider gives a gameplay penalty in a way that reads as ranking appearances.
- **Sliders stay inside each ancestry's range**, with generous overlap, so a very tall human and a short orc both look right, and the archetypes in Dave's references (Gaston, Link, Dragon Ball; I have not researched them) can be reached inside any ancestry that suits them.

### 5.7.3 Body sliders (the "skeleton" sliders)
Sliders change the bone rest positions and the generated shape from the same numbers, so the mesh and the skeleton always agree.
- **Size and build:** overall height; build (slim to heavy); muscle; belly/waist; chest depth; shoulder width; hip width.
- **Proportions:** torso length; leg length (relative to torso); upper-arm and forearm length; neck length and thickness; hand size; foot size; head size.
- **Posture and gait (these change how the animation looks, see 5.7.6):** posture (upright to stooped), stride length, arm swing, hip sway, bounce, walk weight (light to heavy), shoulder roll.
- **Additions I suggest Dave may be missing:** apparent age (young to elderly: posture, skin, hair greying); handedness (left or right; our tool mounts and swing clips currently assume the right hand, Part 1.5); voice pitch or type if voices are added; body hair; scars, markings, tattoos, war paint (cosmetic layers); eye colour and eye shape; teeth, tusks, fangs; ear shape; optional extras by ancestry (tail, horns); starting clothing colours; a name; a saved-presets list; sharing a character as a short code; a neutral preview with a turntable and a walk preview.

### 5.7.4 Face
- **Bone structure:** a small set of face bones or blend shapes: brow ridge, cheekbones, jaw width, chin length and width, nose (bridge, width, length, tip), eye size, spacing and tilt, mouth width, lip fullness, ear size and point. Godot supports blend shapes on a mesh (Part 3, H6) and the humanoid profile has jaw and eye bones (B7). How many and which is open.
- **Art direction fit:** a few big readable shapes, not fine detail (Dave 2026-10-30: leave out detail and exaggerate). **No full expression rig is needed** (Dave 2026-10-30: pose, actions and hand acting carry the emotion). No lip-sync and no jaw animation. **Decision (Sonny, provisional):** keep a minimal supporting channel anyway, because every Aardman example researched uses one (3.11.1, L1, L2): eyes with lids that can open wide, squint or blink, and optionally a brow raise, done by a texture or mesh swap, not a bone rig. A mouth-open swap for screams is the same kind of cheap swap. This is far cheaper than facial animation and does the work of the Gromit-style brow.
- **Cost warning:** a unique face per player means unique mesh data. I found that **MultiMesh ignores blend shapes** and that skinned meshes cannot be assumed to batch (H8, H9), so each distinct face is its own draw; the 20-body budget must be measured with 20 distinct genomes.

### 5.7.5 Skin, hair and marks
- **Skin:** tone (a continuous slider over a wide range, no gameplay effect), undertone, freckles, flush, age marks, scars, tattoos and markings. Extends the existing region-colour shader (Part 1.2) with a small texture mask; per-instance values through shader instance uniforms (H7).
- **Hair:** style (a list of a few dozen simple stylised shapes), length (a slider that scales the shape), colour (picker, gradient, greying), facial hair, eyebrows. Hair is the hardest thing to do well in code, so use big solid shapes with a simple shader and optional spring-bone sway (H1). The method is unresearched.
- **Optional:** eye colour, lip colour, nail colour.

### 5.7.6 What sliders do to animation (important)
- **FACT (code):** the gait function already takes its swing, lean and bob amplitudes as parameters (`_gait(...)`, Part 1.3), so per-character gait style is natural to support.
- **RECOMMENDATION:** do **not** bake a different clip set per character. Keep one shared clip set and apply per-character modifiers at run time: stride scales with leg length, arm swing and bounce scale with the posture and gait sliders, lean and sway go through the additive layer (Part 5.1). The research found cadence did not depend on body size at preferred speed while stride length did (G2), so playback rate should follow speed divided by the stride set by leg length; that also stops foot sliding when legs differ in length.
- **Changing bone lengths:** clips mostly store rotations, so they work on different bone lengths; the hips position key must be scaled by hips height (Godot's retarget has the same idea, B6 "Normalize Position Tracks"). Do not scale the whole skeleton node (the spring-bone docs warn that scaling breaks them, B12/H1); change bone rests and the generated mesh instead.
- **IK:** foot IK and hand IK to tools (Part 5.1) must read the character's real bone lengths.
- **Extremes:** test every clip on the smallest, largest, stockiest and leanest genome (risk in 7.2); clamp sliders where a clip breaks (for example arms too long to swing without hitting the legs).

### 5.7.7 Random (dice) buttons
- **Global dice** randomises everything; **per-section dice** (Ancestry features, Body, Face, Skin, Hair, Marks, Gait) randomise only that section; **per-slider lock** (suggested) so a locked value survives the dice.
- **Random is gentle by default:** values are drawn from a bell-shaped spread around the ancestry's defaults, not uniformly over the full range, so results look like people; a "wild" toggle draws from the full range (suggested).
- **Seeded, repeatable and undoable:** each press records its seed so Undo steps back; the whole genome can be shown as a short code to share. Sections stay independent so the face dice never changes the body.
- Creator dice are client-side and cosmetic; the server validates the final record. Server rolls that affect gameplay keep going through the existing luck path (`src/shared/luck.gd`). Whether a random ancestry is allowed is Dave's call.

### 5.7.8 Rules and limits
- **Gameplay-neutral by default:** height, build and face sliders change look only; the collision capsule, reach, step height and camera height stay the same unless Dave decides body size should matter (D16). If it does, the capsule and eye height must scale with it and the 1.8 m tuning (ladders, doors, step-up) must be revisited.
- **Ranges and fairness:** clamp every slider on the server. Keep extremes inside what the animation, clothing and tools support (worn pieces are fitted by proportion, Part 2 B6, Kathleen plan item 3).
- **Changing appearance later:** barber, disguise (DESIGN_IDEAS.md section 9.2: clothes and hair are easy to change, height and build are not) and ageing are design questions (D17).
- **Clothing and worn items must adapt to every genome**, which affects the worn-item builders.
- **Start of the game (Dave, 2026-10-30):** when a player starts the game they **pick their character, and each character has its own account**. If they have no character they must **make one** (the creator above). So the flow is: sign in or start, character list (with a small body preview per character), choose one to play or make a new one. Consequences, all RECOMMENDATION or open: (1) the genome belongs to the character account and is stored with it on the server; (2) the list screen needs a cheap preview for each character (the character screen preview rig already exists, Part 1.6); (3) how many characters per player and how they relate to the dynasty and heir idea (BIG_PICTURE.md, DESIGN_IDEAS.md) are design questions (D20); (4) an identity layer exists as a plan: DECISIONS.md 2026-10-21 18:00 describes player identity behind one server-side `IdentityProvider` with an allow-list of account ids; I have not read it in full or checked how "one account per character" fits it, so that needs the technical lead (D21); (5) a character that already exists must never be re-rolled by the creator (luck and fitness are rolled once, PROTOCOL.md).
- **Where creation happens:** I found no character creator in the code; the character screen shows a preview of the existing character, and luck and fitness are rolled once at first hello (PROTOCOL.md, characters.json entry). Whether creation is at first hello, in a hall, or in a menu is open (D18).

### 5.7.9 Changes made after the creator research (3.11.4, 3.11.3)
- **Faces: presets plus a small set of sliders, not dozens (N2, N3).** Baldur's Gate 3 shipped no face sliders (curated presets plus attachments) and a workshop paper warns that many face sliders make the space of faces hard to grasp. **Provisional decision:** a gallery of curated face presets per ancestry plus about eight sliders (jaw, chin, cheeks, brow ridge, nose size, nose bridge, eye size and spacing, ear size), and attachments (hair, scars, tattoos, horns, tusks). The Sims 4 approach of dragging points on the face is a later option (N1).
- **Dice (N1):** adopt the Sims 4 idea: randomise only what is not locked; section dice never touch other sections; per-slider locks.
- **Share code (N7):** version byte, one byte per slider, enum indices and colours, CRC, then Base64 using `PackedByteArray` and `Marshalls` helpers on raw bytes only (never decode objects from a pasted code). Store slider values, not mesh results, so the generator can improve without breaking saved characters.
- **Preview with the real thing (N5):** the creator preview uses the same generator, shader, lighting and idle and walk animations as the game.
- **Later changes (N2):** appearance after creation: allow hair, colours and tattoos at a barber or by item; height and build stay fixed (matches DESIGN_IDEAS.md section 9.2); a Magic-Mirror style full change could be a rare late-game item.
- **Accessibility (N6):** remember all settings, no flicker, and readable text in the creator.
- **Body generation (3.11.3, provisional decision):** build the body from capsule and ellipsoid signed distance fields with a smooth union, mesh it with naive surface nets, compute skin weights by distance falloff with a few smoothing passes (M15), 4 influences per vertex, bake once per genome and cache the mesh on disk by a hash of the genome (M7). Use rotation-only animation clips with the hips position scaled by `motion_scale` so one clip set fits every body (M8); consider a shared reference skeleton with `RetargetModifier3D` only if that fails. Hair as solid shapes from the same distance field (M17). The meshing time in GDScript is unknown (M12); the Phase 0 prototype benchmarks it and, if too slow, moves the mesher to C# or a GDExtension. The project already uses the Godot Voxel module for terrain (`VoxelLodTerrain`); I will check whether its SDF tools can mesh a body before writing my own mesher.

## 5.8 Backgrounds, traits and the greatest fear (Dave, 2026-10-30)

Dave's direction: a Dungeons and Dragons style system, but different. Players pick a **background** that gives different bonuses or boons. Every character picks their **traits** through **a rolling system or a point system, the player's choice**. **Base traits affect all related skills.** Every character also picks a **greatest fear** from a list we make up; when they meet their greatest fear the character has a **rolled chance to freak out and run away screaming and flailing, comedically**.

**Whose job is which.** Backgrounds, trait values, skill links and the fear list are **game and server design**, which belongs with the items, skills and attributes designers (the existing design is SKILLS_AND_ATTRIBUTES.md and DESIGN_IDEAS.md section 5.4). My part is: (1) the creator screens and how a background or fear shows on the character; (2) the panic animation and movement state; (3) the dice and point-buy controls in the creator. Everything below is RECOMMENDATION unless marked FACT, and I have **not researched D&D character creation or other games' background and fear systems** (a Phase 0 research item).

### 5.8.1 What already exists (FACT, doc)
- Attributes are whole numbers from -10 to +10, fixed at creation: **Luck and Fitness are built**; Strength, Dexterity, Memory and Wisdom are listed but not built (docs/mirror/items/SKILLS_AND_ATTRIBUTES.md, "Attributes").
- A skill has an innate part, a trained part and practice; **attributes feed skills through a web of weights** (same file, intro). That is already "base traits affect all related skills", so Dave's rule fits the existing design.
- NPCs are created with a randomly rolled **background**, and the language model fills in details (DESIGN_IDEAS.md, NPC section, line 1232 area). A player background can share the same data format.
- Luck and Fitness are rolled once at first hello and never changed (PROTOCOL.md, characters.json entry). A creator would have to roll or spend points **before** that first hello and then fix the result on the server.

### 5.8.2 Backgrounds (suggestion)
- A background is a data record: name, short story, a few starting skills or knowledge, a small boon and optionally a small drawback, a starting item or two, maybe a look hint (clothing, a mark, posture). Examples are for Dave to invent; none are decided.
- Visual side (mine): a background can suggest default clothing colours, a tattoo or scar, or a posture and gait style, all optional and changeable in the creator.
- Same rule as ancestry (5.7.2): boons and drawbacks come from **what the character did**, not from skin tone or facial features.

### 5.8.3 Trait values: roll or point buy (the player's choice)
- **Point buy:** a pool of points spent on the attributes (-10 to +10 today); a cap per attribute, a visible total and a reset.
- **Roll:** a button that rolls the attributes (the dice idea of 5.7.7), with a limited number of re-rolls or a keep-the-best choice so it stays fair. Rolled and bought values should have the same expected total, otherwise one method is better than the other (design check; no numbers proposed).
- **The server rolls and validates**, because luck-affecting rolls go through the existing server random path (`src/shared/luck.gd`, PROTOCOL.md); the client only shows the preview. Anything the player buys is checked against the pool on the server.
- **Fairness (N9):** standard array and point buy average exactly 12; four dice drop the lowest averages about 12.24 with a wide spread (forum analysis and the agent's own arithmetic). **Provisional decision (D22):** point buy is the default; the roll option gets bounded variance (a floor and a ceiling on the total) and a limited number of re-rolls, so neither is clearly better in an online game where players compare. Baldur's Gate 3 uses 27-point buy only with scores starting at 8 and capped at 15 (N9). Costs per point in the SRD are public (8=0 up to 15=9); we use our own numbers, scaled to the -10 to +10 range already in the game, to be set by the skills designers.
- "Like D&D but different": the different part (what the pool is, what extra choices exist) is Dave's design to decide (D22).

### 5.8.4 Greatest fear
- **Chosen from a list we write.** Suggested categories only, not a list: creatures (wolves, snakes, spiders, bears), places (deep water, heights, dark enclosed spaces, caves), phenomena (fire, storms, thunder, blood), and odd or social fears (crowds, a certain animal such as geese). Dave writes or approves the real list (D23). Keep them harmless and comic; avoid fears that mock real conditions.
- **Trigger and roll are server decisions.** The server knows what is near the player and rolls the chance (through the existing random path) when the greatest fear comes into range or view. The client must not decide this. Suggested shape: trigger when the feared thing is within a distance or in sight, roll once per encounter, then a cooldown so it cannot loop; modified by traits such as Wisdom or a courage-like trait if Dave adds one.
- **Hidden information.** A player's greatest fear should be hidden from other players by default, otherwise others could exploit it in PvP. Whether a character may reveal it, and whether NPCs can know it, is open (D24).
- **Existing design to reconcile.** DESIGN_IDEAS.md section 6.16 decided that breathing and heartbeat follow exertion only and that "later, fear and pain may add adrenaline" (2026-10-17). This panic feature is that later step, so those sounds would need a fear input.

### 5.8.5 The panic state (my animation and movement part)
- **What it looks like (suggestion):** the character screams (needs a sound clip from the sound owner), eyes wide, mouth open, arms flailing overhead, an exaggerated high-knee run away from the feared thing, a stumble or two, a wobbling head. Comedic and in line with the cartoon style (art direction at the top), not scary. It ends on a timer or when far enough away, then a breathless slump or a short embarrassed recovery.
- **Mechanics (FACT, code, then RECOMMENDATION):** player movement is client-side with the server validating (Part 1.4, PROTOCOL.md), so the server would send a "panic" state with a direction hint and a duration, and the client would steer the character itself; the player briefly loses control. This touches the movement code (`terrain_client.gd`) and the server together, so it needs the technical lead (D25).
- **Safety rules (important):** panic must never run a player into near-certain death (off a cliff, into deep water, fire or a cave-in) in a way that feels unfair. Options: the run avoids hazards using the same ground checks as the creature AI; or it is a fixed-length stumbling run at reduced speed with no auto-jump; or hazard cases give a freeze and cower instead. An accessibility setting (reduce or disable loss of control, or turn it into a flinch and cower) is wise, since losing control can be unpleasant. None of this is researched.
- **Others see it too:** it is an action the server states to nearby clients (Part 5.5), so remote players and NPCs play the same panic clips from the same record. NPCs could have fears too (NPC backgrounds already exist), a cheap source of comedy.
- **Animation work:** panic run, flail loop, cower or freeze, scream pose, recovery; all on the shared skeleton and tested on the extreme genomes (5.7.6). Acting follows Part 4.6: held, stepped poses on twos in the comic beats, with hand shapes (clutch the head, flap, shield the eyes) and a quick eye widening by texture swap.
- **Lessons from other games (3.11.4, N13 and N14):** Darkest Dungeon makes afflicted heroes ignore commands and lets stress spread, with a cost to cure; Amnesia hid its numbers and later became ambient mood with few consequences; Don't Starve never takes control from the player. No source on opt-outs or complaints about forced loss of control was found, so these rules are my inference: keep panic rare (cooldown), short (a few seconds), funny rather than punishing, never lethal on purpose, with no stat penalty beyond the lost seconds, and hide the number from the player the way Amnesia did.

### 5.8.6 Where this sits in the roadmap
Backgrounds, trait entry and fear selection are part of **Phase 5, character creation**, but their server side (trait storage, skill weights, fear rolls) comes from the skills and attributes designers and must be agreed before then. The panic animation and movement state go into **Phase 9** (special states) unless Dave wants them earlier because they are a signature feature; they need a few clips and one server message. Like 5.7, this is untested design.

### 5.8.7 Future idea: the reaction replay (Dave, 2026-10-30; not to build now)

Dave's picture: some day, after you flip out and run away, an **instant-replay slow-motion camera** swings around and shows you from the front, in third person, like a movie, as you open the door or the chest, realise what you are looking at, and react in slow motion: you turn into an anxiety-riddled, running buffoon screaming "Nope. Nope. Nope. Not today. Oh no! Not today."

Status: **idea only, not planned for any phase, not researched.** Notes so the idea is not lost, all RECOMMENDATION or open:
- **It should be a replay, not slow motion of the live game.** The world, the server and other players cannot slow down for one player. A replay shown to the owner only, after or just as the panic starts, avoids that. Two ways to do it: (a) keep a short rolling history (the last few seconds) of the player's position, facing, speed, stance and actions, then re-play it on the avatar from a cinematic camera; (b) at the trigger, briefly cut to a staged cinematic of the same few seconds. Option (a) fits the plan to derive animation from velocity, stance and action ids (Part 4.1 item 5), because the replay can re-derive the pose from that short history instead of storing bones.
- **Camera:** a swing from first person round to a front view of the avatar's face, with a push-in or dolly-zoom on the reaction, a slow-motion section and a return to normal play. Needs the third-person camera work in Part 5.6 and a camera mode that can be driven by script. The 3rd-person body must already be good, so this comes after the body and face work (Phases 3 and 4).
- **Body and hand acting (not face acting):** the replay works through the body: a freeze, a head snap back, shoulders up to the ears, hands flying to the head, a double-take, then the flailing run. Per Dave's claymation-comedy direction the face does not act, so the panic clips (5.8.5) must carry everything with strong, held poses and expressive hands. Hands therefore matter more than the face (see the hands note in Part 4.3).
- **Voice:** spoken lines such as "Nope. Nope. Nope. Not today. Oh no! Not today." need recorded or generated voice lines (the sound owner, plus the project rule about voices in DESIGN_IDEAS.md and the earlier TTS decisions) and subtitles; a few variants per character voice so it is not the same line every time.
- **Fairness and comfort:** the replay must not leave a player helpless while others can attack, so it should play only after control is back or while the character is already safe, be skippable, and be switchable off. A swinging camera and slow motion can be uncomfortable; the research found that comfort options for camera motion are common practice (Part 3, C10).
- **Owner only:** the cinematic is seen by the player; other players just see the normal panic animation.
- **Sharing:** a replay clip could be saved or shared as a short code or clip; whether that is wanted is Dave's call (privacy and cost not examined).

### 5.8.8 Draft list of fears (Sonny, 2026-10-30, at Dave's request: simple first, then strange, things people will meet sometimes)

**Status: a first draft for Dave to edit. Nothing is decided.** Rules I followed: harmless and comic, things a player will run into now and then just to experience the moment; no medical words (not "phobia"); nothing aimed at a real group of people. "Trigger" is what the server would have to detect (distance, sight or a condition); distances are placeholders to tune. "In game today?" is only what I know from our documents (animals built so far: rabbit, deer, wolf, moose, horse, fox, duck, from BUILD_LOG.md and ANIMAL_ART_NEEDS.md); I did not check the full content list, so "no" means "not that I know of". Each fear that needs something that does not exist yet waits for that content.

**Tier 1. The classics (simple, easy to read)**
| # | Fear | Trigger | Panic flavour (my suggestion) | In game today? |
|---|---|---|---|---|
| 1 | Spiders | a spider, or a web, within 3 m | slap-dance, brushing yourself off, then bolting | no |
| 2 | Snakes | a snake within 4 m, or a long stick that looks like one in the grass | high-kicking leap backward, then run | no |
| 3 | Bears | a bear in sight within 25 m | straight sprint, arms overhead | not that I know of |
| 4 | Wolves | a wolf within 25 m, or hearing a howl close | looks over the shoulder while running | yes |
| 5 | Rats and mice | a rat nearby | hops on the nearest thing, squeals | no |
| 6 | Bats | a bat flying within 4 m | ducks, covers head, zigzags | no |
| 7 | Bees and wasps | a swarm within 5 m | spinning, swatting, running in circles | no |
| 8 | The dark | standing in full darkness in the open at night or in a cave without light | feels along the air, bolts to the nearest light | partly (day cycle, caves exist) |
| 9 | Fire | a big fire or a burning building within 6 m | hands up, backing away, then running | yes (campfires) |
| 10 | Thunder | a close lightning strike | drops flat, then bolts | yes (storms, lightning in docs) |

**Tier 2. Places and situations (you meet them by exploring)**
| # | Fear | Trigger | Panic flavour | In game today? |
|---|---|---|---|---|
| 11 | Deep water | standing at the edge of or in deep water | flailing backward, refuses to turn around | yes |
| 12 | Heights | standing near a drop of more than about 5 m | drops to hands and knees, clings, crawls away | yes (terrain) |
| 13 | Caves and tunnels | entering a cave or deep tunnel | bolts toward daylight | yes |
| 14 | Cave-ins and creaking timber | a bracing beam creaks, or a roof drips dust | covers head, runs out | yes (digging and supports) |
| 15 | Tight spaces | a narrow dug passage | squirms and backs out | partly |
| 16 | Open ocean | being on a boat far from land | clutches the rail, cries | boats are planned |
| 17 | Fog | thick fog | walks into things, spins, runs blind | partly (weather) |
| 18 | Mud and swamp | wading in a bog | high stepping, panics at every squelch | partly |
| 19 | Crowds and markets | many people close | squeezes through, escapes | NPC towns planned |
| 20 | Blood | seeing a big wound or a butchered animal | faints or bolts | yes (hunting, carcasses) |

**Tier 3. Odd and strange (comedy first)**
| # | Fear | Trigger | Panic flavour | In game today? |
|---|---|---|---|---|
| 21 | Geese and ducks | an angry bird within 6 m | runs in an exaggerated waddle, flapping elbows | yes (duck) |
| 22 | Moose | a moose in sight | frozen stare, then tiptoes, then bolts | yes |
| 23 | Owls at night | an owl hoot very near, or eyes in a tree | looks around slowly, then bolts | no |
| 24 | Crows | a flock of crows landing near | covers head | partly (crow calls exist in the sound pack) |
| 25 | Scarecrows | a scarecrow seen at dusk | slow backing away, then run | no (a possible prop) |
| 26 | Your own shadow | long shadow at dawn or dusk | jumps, then fights the shadow | the lighting exists |
| 27 | Mushrooms | a large cluster of mushrooms | tiptoes round them, flails | partly (flora) |
| 28 | Mirrors and still water reflections | seeing yourself in still water | stares, pulls a face, bolts | partly |
| 29 | Chests and doors that creak | opening a chest or door, the very moment (matches Dave's replay idea, 5.8.7) | double-take, then the "Nope" run | yes (chests, doors) |
| 30 | Being watched | feeling eyes behind you for a long time in the forest | keeps turning, walks backward, bolts | no |
| 31 | Silence | no sound at all for a while | pokes ears, shouts "hello?" | the sound stage exists |
| 32 | Pots and cooking smoke | burning food | frantic flapping at the smoke | yes (cooking) |
| 33 | Toads and frogs | a frog landing on you | shakes limbs, high-pitched squeal | partly (ambience has frogs) |
| 34 | Fish that jump | a fish leaping out of the water at your feet | flinches, falls over | yes (fishing) |
| 35 | Very large trees falling | a tree falling nearby | sprints sideways, looks up | yes (felling) |

**How I would build the list in practice (RECOMMENDATION):**
- Start with the ten in tier 1, because most are easy to trigger with things that exist or are cheap to add. Take 3 or 4 from tiers 2 and 3 that need nothing new (deep water, heights, caves, a chest or door, geese and ducks, moose, a falling tree).
- **Panic flavour makes each fear its own small animation set**: running away, backing away, falling to the ground and crawling, flapping or swatting. These are variants of one panic state (5.8.5) to avoid 35 separate systems; the server only sends a fear id and a direction hint.
- A fear is a data row: id, name, trigger kind, trigger distance, roll chance, cooldown, panic variant, and the voice lines (D27 idea). New fears then cost content only.
- Fear 29 (a creaking chest or door) is the best first one: it needs nothing new and matches the reaction replay (5.8.7).
- The same list could give NPCs a fear too.

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
| Character creation | **None found** (luck and fitness rolled once at first hello; a preview rig exists) | Ancestry, body/face/skin/hair sliders, dice buttons, compact genome saved on the server and generated on every client | Genome format, generator, UI, server validation, sharing | L |
| Body sliders on animation | Gait amplitudes are function arguments but there is one set of clips for everyone | Shared clips plus per-character modifiers (stride from leg length, swing, bounce, posture) | Modifier layer, scaled hips key, IK reading real bone lengths | M |
| Tooling | `check_ragdoll.gd`, standard shots | Per-clip review sheets, event/loop/foot-slide checks, perf harness | New checks | M |
| Documentation | Scattered over ~20 docs, some stale (Part 2.9) | This file as the single source; originals pointed to it | Dave approves removal list | S |

---

# Part 7. Phased roadmap, risks, open questions and decisions

## 7.1 Phased roadmap (RECOMMENDATION; revised 2026-10-30)

Revised after Dave's approval. Two changes: (1) the **skeleton and the character genome are defined first**, so clips authored later survive the move to the new body (the earlier order would have made clips twice); (2) **character creation** (ancestry, sliders, face, hair, dice) is added. Nothing starts until Dave says go.

**Phase 0. Define, research, measure, prototype.**
- Define the **new skeleton** (humanoid-compatible names, shoulders, toes, hand and grip bones, root, face bones or blend shapes, attach points; Part 4.3) and the **genome**: the list of sliders, ranges and archetype presets (Part 5.7). Keep the old body mesh running on the new skeleton temporarily.
- Research round on character creators in other games (sliders, face systems, dice, ancestry systems) and on code-generated smooth bodies and soft weights, with sources, as for Part 3.
- Baseline stills and frame times (avatar and 20 NPCs) on the minimum machine.
- Prototypes in a scratch scene, not in the game: (a) `AnimationTree` on a code-built skeleton (I2); (b) a generated smooth mesh with scripted soft weights, saved as an asset, on two extreme genomes; (c) the cost of 20 different generated bodies.
- Check whether the Godot Voxel module the game already uses can mesh a body from distance fields (3.11.3, M13) before writing a separate mesher; benchmark GDScript surface nets at a coarse grid.
- Prototype stepped (held) poses on one comic clip with `INTERPOLATION_NEAREST` and with manual stepping, and a squash helper bone, to see what looks right (4.6).
Output: a short measured report and a frozen skeleton and genome spec for Dave. Size M.

**Phase 1. Animation architecture.** `AnimationTree` (or the fallback), cross-fades, upper-body masks, events, data-driven gait numbers, shared action records so third person plays the same swings. Built on the new skeleton. Size M.

**Phase 2. Missing locomotion.** Jump, fall, land, crouch walk, strafe and back, turn and start/stop, ladder, swim, wade, slopes and foot IK, step-up, head look-at, stride from leg length. Tested on the extreme genomes. Size L.

**Phase 3. Body generator and archetypes.** The smooth generated body with soft weights, joint-friendly shapes, hands, a simple stylised head, LOD, saved as an asset; archetype presets (broad, lean, stocky, muscular); silhouette test; character screen preview updated. This is the big visual jump. Size L.

**Phase 4. Face, hair, skin and marks.** Face sliders (bones or blend shapes), hair styles and colour, skin tone and marks, eyes. Size L.

**Phase 5. Character creation.** Ancestry presets and ranges, slider screens, section and global dice with locks and undo, save and load presets, share code, server validation and storage of the genome, first-hello flow. Boons and drawbacks per ancestry are separate server design (D15). Size L.

**Phase 6. Tool and activity library.** Per-tool clips and grip records, two-hand IK, hit stop and feedback, replacing the per-tool constants. Slice by tool. Size L.

**Phase 7. Equipment and secondary motion.** Attach points, belt and back tools, fit-by-proportion on every genome, region hiding, spring-bone cloaks, armour layers. Size M.

**Phase 8. Other people.** Remote player bodies from the genome, derived animation, tiers with hysteresis, reliable action ids, NPC port using the same generator (NPC variety is just random genomes), 20-body measurement. May move earlier if a friend session needs it (D7). Size L.

**Phase 9. Special states and polish.** Exertion posture, limp, hurt, faint and death, sit and sleep transitions, emotes, mounts. Open-ended.

Review gates: after each phase Dave sees stills or video and a short note; done means the checks in Part 4.4 pass.

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
13. **Character creation is a large new system** (UI, genome, server validation, storage, sync, content for ancestries). Mitigation: Phase 0 research and spec, a small first version (few ancestries, a limited slider set), expand later.
14. **Unique bodies cost.** Every distinct generated body and face is its own mesh and draw; the 1 ms budget for 20 bodies may not hold with 20 different genomes (H8, H9). Mitigation: Phase 0 measurement, LOD, share meshes for identical genomes, cap face detail.
15. **Sensitivity of ancestry design.** Boons and drawbacks by "ethnicity" can collide with the safe-place rule (5.7.2). Mitigation: fantasy peoples only, cosmetic traits free of gameplay effect, Dave approves the ancestry list and traits.
16. **Fairness and exploits.** Size or body sliders could confer advantages (hiding in grass, small hitboxes). Mitigation: gameplay-neutral appearance by default (5.7.8).
17. **Unresearched.** Creator UX, face systems and generated hair in code are new territory for this team and not yet researched.
18. **Panic can feel unfair or be exploited.** Loss of control near hazards, or other players learning a fear, could ruin play. Mitigation: hazard-aware or non-lethal panic, hidden fear, opt-out setting (5.8.5).
19. **Trait and background design is outside my files** and has to be agreed with the skills, items and server owners before creator work starts (5.8).

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
| D1 | Character look. **DECIDED by Dave 2026-10-30: (b) simple stylised human.** | (a) keep "no features" ragdoll look, only improve motion and joints; (b) stylised human with simple face, hair, hands; (c) detailed realistic | (b) kept simple, but only after Phase 1 and 2 prove the motion. If the answer is (a) Phase 3 shrinks to joints, shoulders and hands |
| D2 | How the body is made. Dave leans to code generation (2026-10-30: the model need not be perfect; leave out detail and exaggerate). | (a) keep generating it in code (smooth blended mesh, scripted soft weights, saved as an asset); (b) model/rig in Blender and import glTF; (c) buy/licence a base and adapt | (b) if a modeller is available, else (a) with soft weights generated by script; avoid (c) unless the licence is clear |
| D3 | First-person approach | (a) arms-only viewmodel (today); (b) full body in first person; (c) arms-only plus lower body when looking down | (a) now, (c) later if wanted. Never two unrelated animation sets: shared action records |
| D4 | Third person priority | first-class vs secondary | first-class for actions (they are cheap once records are shared) |
| D5 | Order of work | the roadmap in 7.1 | Phase 0, 1, 2 first |
| D6 | New movement: sprint, roll, dodge | add or not | not until combat design says so |
| D7 | When other players become visible | before or after Body v2 | after Phase 1 and 2 unless a friend session needs it sooner |
| D8 | Update-rate tiers for far bodies | keep 15/40/70 m tiers | keep, with hysteresis; measure |
| D9 | Customisation and archetypes | none / small / large; archetypes for NPCs only or for players too | small for players (skin tone, hair, coat colour, one of a few archetypes); full archetype range for NPCs. Check against the safe-place rule |
| D10 | Ownership and approvals | which files I may change; whether I may edit shared files `terrain_client.gd` and `held_item.gd`; approval of the passage-removal list in 2.8 | Allow me to extract the avatar and arm logic into a new module with minimal edits to the shared files |
| D11 | Quality bar sign-off | accept the targets in 4.4 or change | accept as tunable defaults |
| D12 | Budgets | triangles/bones/body cost per LOD | set after the Phase 0 measurements, not before (no external number found, H11) |
| D13 | Headline: motion-capture or purchased animation packs | use / don't | consider packs only with BoneMap retarget and licence check; no motion matching (A8) |
| D14 | Which ancestries ship first | human only / human, orc, elf / more | human, orc, elf, then add; each defined by slider ranges and extra features |
| D15 | Who designs ancestry boons and drawbacks | Sonny / items and skills designers / Dave | the items and skills designers with Dave; Sonny supplies the visual side only. Fantasy peoples only; skin tone and facial features gameplay-neutral |
| D16 | Does body size matter in play (reach, hitbox, speed, carrying, camera height)? | cosmetic only / some effect | cosmetic only at first |
| D17 | Changing appearance after creation | never / barber and hair only / full | hair and colours by barber or item; height and build fixed (matches DESIGN_IDEAS 9.2) |
| D18 | Where character creation happens. **Dave 2026-10-30: at game start, pick a character (each has its own account); if none, make one.** | at first hello / a world place / menu | as Dave said: character list at start, creator when none; a later edit place for hair and colours |
| D19 | Creator scope for version 1 | minimal (ancestry, height, build, skin, hair, face preset) / full slider set | minimal first, then grow; dice and locks from the start |
| D20 | Characters per player and their link to the dynasty/heir idea | one / several / unlimited | several, with the dynasty design deciding how heirs inherit appearance |
| D21 | One account per character and the identity layer | per Dave's decision; how it maps onto the IdentityProvider plan | technical lead to confirm before Phase 5; Sonny supplies only the appearance record |
| D22 | Trait system: point buy and roll, and what is "different from D&D" | Dave's design | player's choice of roll or point buy, equal expected value, server-validated; Dave defines the rest |
| D23 | The list of fears | Dave writes it; **Dave asked Sonny to draft it: see 5.8.8 (35 fears, three tiers)** | edit the draft; start with tier 1 and a few from tiers 2 and 3 that need no new content |
| D24 | Is a greatest fear hidden from other players and NPCs | hidden / revealable / public | hidden by default |
| D25 | Panic mechanics: loss of control, hazards, duration, opt-out setting | full run-away / flinch and cower / player setting | run-away with hazard avoidance and an accessibility setting; technical lead designs the server message |
| D26 | Who designs backgrounds and their boons | Sonny / skills and items designers / Dave | skills and items designers with Dave; Sonny supplies creator UI, look hints and animation |
| D27 | The reaction replay (slow-motion cinematic of the panic) | never / someday / early signature feature | someday, after the body, face and panic clips; design as a short replay for the owner only, skippable, with a setting to turn it off |
| D28 | Acting style and hands: how stop-motion-like should the motion be (smooth with strong poses, or deliberately choppy), and how many finger bones | smooth / partly choppy / fully choppy; 5, 10 or 15 finger bones per hand | smooth motion with strong held poses, optionally choppy only in comic moments; simplified hands with thumb and two or three finger groups |

## 7.5 What I would do first once Dave approves (RECOMMENDATION)

1. Phase 0 baseline and the AnimationTree prototype (one scratch scene).
2. Phase 1 on the existing body.
3. Show Dave a short side-by-side (stills and a clip) after each of Phases 1 and 2 before spending on Body v2.


---

# Part 8. Action plans and the first prototype (Sonny, 2026-10-30)

## 8.1 Answers from the moderator while Dave is away (relayed by the session that started me)
1. **Yes:** move the avatar and first-person arm code into a new module on my branch, with minimal edits to `terrain_client.gd` and `held_item.gd`.
2. **Do not remove passages outright:** move them into an archive file so nothing is lost. (Status in 8.4.)
3. **Ancestry boons:** take my middle path (small mostly physical traits for fantasy peoples, bigger bonuses in backgrounds and traits, skin tone and face cosmetic). Done in 4.7 and the decision sheet.
4. **Characters per player:** Dave's call; design for **one active character per account with a data shape that allows more** (D20).
5. **Draft the fear, background and trait lists as proposals** for Dave to edit (Plan 3).
6. **Build the first body prototype**, save pictures for Dave, keep proportions adjustable, benchmark the GDScript body generation (Plan 1, results in 8.3).
7. Search the web for facts and record source and confidence; delete nothing; write three new plans of action, approve them myself (pre-approved), and start the first.

This widens my earlier rules (document only) to: the new files below, on my branch only. I still do not touch `main` or `DailyDev_20261029`, make no bakes, and have not changed any existing game file.

## 8.2 Three action plans (approved by me under the moderator's pre-approval)

**Plan 1. Body generator prototype and benchmark (started, first result below).** Goal: prove the genome-to-body idea. Steps: generator from sliders to skeleton, smooth body, skin weights and mesh; pictures of four archetypes at rest and in a bend test; GDScript timing; then iterate on the defects (seams, hair, hands, face, clothes, triangle budget); then add the face presets and skin and hair options. Files: `src/client/character/body_generator.gd`, `tools/proto_body.gd`, pictures in `art/character_proto/`. Done when: bodies bend cleanly, four archetypes read clearly at 20 m, cost per body is known, and Dave has seen pictures. Risk: GDScript too slow (measured below: no); visual quality of a code-made body (open).

**Plan 2. Motion prototype on the generated skeleton. DONE for the checks (8.3b): 10 of 10 pass.** Goal: prove the animation plan before building it. Steps: an `AnimationTree` with a speed blend space and a filtered upper-body one-shot on the new skeleton (settles risk 2 in 7.2); a held-pose comic clip using `INTERPOLATION_NEAREST` and manual stepping (4.6); a squash helper bone; rotation-only clips with the hips scaled by `motion_scale` on two different bodies (5.7.6); capture stills and timing. Files: `tools/proto_motion.gd` and a few new clip definitions. Done when: the same clip set plays correctly on the four archetypes with no foot sliding at a fixed speed, and the stepped clip reads as comedy rather than lag.

**Plan 3. Proposals for Dave: fears, backgrounds, traits (documents only). DRAFTED: see Part 9 and 5.8.8.** Goal: give Dave lists to edit. Steps: keep the draft fear list (5.8.8); draft about 12 backgrounds (story, small boon, small drawback, look hint) written as plain data rows; draft the trait list on the existing -10 to +10 attributes (Luck and Fitness exist; Strength, Dexterity, Memory, Wisdom are listed) with the skill links; write all as proposals, label them clearly, and check wording against the safe-place rule. Files: this document (Part 9). Done when: Dave has lists he can cut and change. Done as a draft.

Plan 4 (**done, 8.3c**): **extract the avatar and first-person arm code** into a new module (the moderator's answer 1). It waits for Plans 1 and 2 because the new skeleton decides the shape of that module, and extracting before that would be done twice.

## 8.3 Plan 1 first result: it works, with known defects

**What was built (new files, nothing existing changed):** `src/client/character/body_generator.gd` (about 620 lines) and `tools/proto_body.gd`. A genome of 18 sliders from -1 to +1 (height, build, muscle, belly, shoulders, hips, torso, legs, arms, neck, head, hands, feet, jaw, nose, brow, ears, hair length) plus skin and hair colours. Four archetype presets (average, broad, lean, stocky) are just different slider values. The skeleton has 21 bones with Godot humanoid names (hips, spine, chest, neck, head, shoulders, upper and lower arms, hands, upper and lower legs, feet, toes). Each body part is a rounded cone or ellipsoid on one bone; each group (trunk and head, each arm, each leg) is blended smoothly inside the group and meshed separately; skin weights come from distance to the parts of the same group, smoothed twice, best four bones kept. Eyes are two small spheres on the head bone. Hair is a cut ellipsoid cap and a back piece.

**Pictures (for Dave; four bodies, front and side):** `art/character_proto/proto_rest.png` (standing), `art/character_proto/proto_bent.png` (a bend test: arms raised, elbows and knees bent, head turned) at 3 cm detail, and `art/character_proto/voxel45/` at 4.5 cm detail. Copies are in the shared notes folder.

**Benchmark (GDScript, one run on Dave's PC, wall-clock in milliseconds, whole body from genome to mesh; one run, not averaged):**
| Detail | Archetype | Triangles | Total ms | of which field | surface | skin weights |
|---|---|---|---|---|---|---|
| 3.0 cm | average | 6,852 | 335 | 83 | 117 | 134 |
| 3.0 cm | broad | 9,188 | 446 | 110 | 162 | 173 |
| 3.0 cm | lean | 6,700 | 354 | 86 | 120 | 148 |
| 3.0 cm | stocky | 8,272 | 436 | 113 | 157 | 165 |
| 4.5 cm | average | 3,024 | 156 | 43 | 53 | 60 |
| 4.5 cm | broad | 4,060 | 220 | 58 | 73 | 88 |
| 4.5 cm | lean | 2,932 | 160 | 46 | 53 | 60 |
| 4.5 cm | stocky | 3,736 | 203 | 51 | 73 | 78 |

Reading: **one body takes about 0.15 to 0.45 s to generate in plain GDScript on this PC, with no optimisation.** That is acceptable for creating a character or loading one into view once (and baking the result to a file, plan in 5.7.9) but not for building 20 bodies in one frame; they must be generated one at a time in the background, cached by genome, and ideally shared between players with the same genome. The earlier estimate in 3.11.3 (M12: "hundreds of milliseconds to seconds") held, at the low end. The agent estimate was not measured by me on the minimum machine: this PC is likely faster than a GTX 1050-class machine, so the real cost there is higher; this must be re-measured on the minimum machine. Triangle counts (3,000 to 9,000) are above the old documented budget of 1.5 to 3.2 thousand for the ragdoll; 4.5 cm detail is near it.

**Findings (what worked and what failed):**
- **Worked:** the genome idea (four clearly different bodies from numbers alone); soft bends at elbows, knees and shoulders in the bend test; one shared skeleton with different bone lengths per body; the bake path is cheap.
- **Failed first, then fixed:** blending all parts smoothly made the arms fuse to the torso and legs to each other, and a raised arm tore a sheet of skin off the side (first pictures). Fix: blend only inside a group; weights only from the same group; then separate meshes per group so a hanging arm no longer forms a thin membrane against the torso. This is a real design rule for the final generator: **limbs must not be unioned with the trunk.**
- **Known defects left in the first picture sheet:** thin seam lines where limbs meet the trunk; the hair cap shows a grey patch (a cut-plane artefact); face is only two eyes, a nose, brow and ears; hands and feet are crude blobs; no clothes; lighting in the sheet is flat. These are prototype defects, not findings about the method.
- **Not yet checked:** how the body looks in the game lighting; animation clips on it (Plan 2); memory per body; whether the Voxel module could mesh faster; saving the mesh to a file and loading it back (5.7.9); the cost of 20 different bodies in view on the minimum machine.

## 8.3b Plan 1 second pass and Plan 2 result (same day)

**Plan 1, second pass (pictures `art/character_proto/proto_rest.png` and `proto_bent.png` replaced; 3.5 cm detail).** Added: a tunic, trousers and boots drawn as slightly larger cloth parts in the same group so the surface shows cloth where it covers and skin elsewhere; brows in hair colour; a lip patch; shoulder cones dressed; vertex colours from the nearest part with a bias so hair, lips and cloth beat the skin under them. Result: the four bodies now read as dressed characters, bend cleanly in the test pose, and cost 400 to 630 ms each at 3.5 cm detail (6,000 to 8,000 triangles) in GDScript on this PC. **Save and reload test:** the baked body mesh saved in 5.5 ms to a 98 KB compressed file and loaded back in 8.1 ms with the same vertex count (a skin bind check after reload was not done). So generating once and loading from the cache costs about fifty times less than generating. Still open: seam lines at the limb joints, a light patch on the side of the head, crude hands and feet, no fingers, no face beyond eyes, brows, nose, lips and ears.

**Plan 2, motion prototype: all 10 checks pass** (`tools/proto_motion.gd`, run headless; `src/client/character/motion_proto.gd`; exit code 0). What was proved, on the generated skeleton and an AnimationPlayer both built in code (this settles risk 2 in 7.2 and the unconfirmed point I2 in the research log):
1. **An `AnimationTree` built in code drives a code-built `Skeleton3D`.** A blend space over speed (idle at 0, walk at 1.4, run at 3.5 m/s) moves the legs; at rest the thigh stays at rest, walking swings it about 0.45 rad. **Two catches found by the check:** (a) a tree built in code does nothing until at least one frame has been processed in the scene tree (calling `advance()` immediately changes nothing), and (b) a `BlendSpace1D` ignores points outside its range, whose default is -1 to 1, so `min_space` and `max_space` must be set for m/s values.
2. **A filtered one-shot works.** A panic clip fired through an `AnimationNodeOneShot` with the upper-body bones filtered moved the arms by up to 1.4 rad against an identical body without the shot, while the legs stayed identical (difference 0.000 rad): attack-while-walking layering is confirmed in this setup.
3. **Held poses work.** The panic clip's rotation tracks use `INTERPOLATION_NEAREST`; sampled 10 ms apart inside one step the pose is identical, and it changes between steps (twelve poses a second). This is the stop-motion beat of Part 4.6, working. Whether it looks right on screen is not yet judged.
4. **One clip set fits bodies with different bone lengths.** Rotation-only clips with the hips position stored in units of hips height and `Skeleton3D.motion_scale` set per body put the hips at each body's own height (1.08 m for the lean body, 0.83 m for the stocky one, within 3 mm). This confirms the design rule in 5.7.6 and M8.

Not yet done in Plan 2: viewing the clips on screen (a walk strip and the panic poses), squash and stretch, foot placement, and measuring the cost of an `AnimationTree` for 20 bodies. Those are the next steps for the motion plan.

## 8.3c Plan 4 result: the avatar rules moved out of `terrain_client.gd` (behaviour unchanged, checked)

**What changed (the only edit to an existing game file so far):** `scenes/terrain_client/terrain_client.gd` lost about 45 lines (51 deleted, 6 added). The rules that choose the avatar's clip (idle, crouch, sit, lie, walk, jog, run, carry), its playback speed, its slope tilt and its clothes colours now live in the new `src/client/character/avatar_driver.gd` as plain functions (`choose_clip`, `speed_scale`, `slope_tilt`, `outfit_colors`, `dress`). `terrain_client.gd` keeps the camera, the avatar node and the held-item wiring and calls the driver. `held_item.gd` was not edited. The first-person arm code is **not** moved yet (see the plans below).

**Check (`tools/check_avatar_driver.gd`, headless):** the old inline formulas are repeated in the check as the reference and compared with the new functions over **11,731 cases** (every stance, every current clip including the hysteresis margins, carrying or not, speeds 0 to 9 m/s in 0.05 steps; every clip's speed scale to 12 m/s; 500 random floor normals for the slope tilt): **0 differences.** The same run also loads `terrain_client.gd` and `held_item.gd` and confirms both compile. Other existing checks still pass: `tools/check_ragdoll.gd` (ok) and `test_worn_sync.gd` (0 failures). I did **not** run the game itself, so on-screen behaviour is checked only through these equivalence tests.

**Two things learned while doing it:**
- A fresh worktree has no `.godot` class cache, so scripts that use a `class_name` (for example `AppConfig`) fail to compile in headless runs until `godot --headless --path . --import` has been run once; that run also rewrites many tracked `.import` files, which I reverted so they do not enter my commits (the cache itself is git-ignored).
- `terrain_client.gd` cannot be compiled in a bare `--script` run for the same reason; the check now works because the cache exists.

## 8.6 Three new plans (approved by me under the moderator's pre-approval; Plan 5 starts now)

**Plan 5. Motion on screen.** Render a walk strip and the panic poses for two or three bodies, so Dave can judge them; test squash and stretch with a helper bone; test foot placement on a slope with `TwoBoneIK3D`; measure the cost of 20 animation trees in one scene. Files: `tools/proto_motion_view.gd` and pictures in `art/character_proto/motion/`. Done when: pictures exist, the IK test says whether feet stay planted, and the 20-tree cost is a number.

**Plan 6. Body version 2. DONE (8.6c).** Fingers (thumb and two or three finger groups) and a nicer hand, a better face (eye lids that can open wide, a brow raise by swap), seam fixes, a lower-detail variant for distance, a genome that can be saved and shared as a code (5.7.9), and a check script for the generator (bone set, limits, no holes). Files: `body_generator.gd` and new check tools.

**Plan 7. First-person arm extraction. DONE for the arm placement and fist (8.6d); the rest is not moved.** Move the arm-model code out of `held_item.gd` (about 1,800 lines, tangled with tool handling) into a module with the same equivalence-check approach as Plan 4. Only after Plans 5 and 6 settle the skeleton, because the arms must use it. If the equivalence check cannot cover enough of it, I will stop and report instead of editing blind.

## 8.6b Plan 5 results: motion on screen, foot IK, cost of 20 animation trees

- **Pictures:** `art/character_proto/motion/strips.png` (eight frames per row; rows: lean walk, lean panic, stocky walk, stocky panic; made by `tools/proto_motion_view.gd`). **Walk:** both bodies walk with a readable stride, arm swing and bend at the knees; the stocky body's stride is shorter because the same clip is applied to shorter legs (stride from leg length was already predicted in 5.7.6). **Panic:** the stepped clip gives clear held poses: hands clutch the head, then flail overhead; three-quarter view reads as comic panic even without a face. Walk and panic are crude prototype clips, not tuned animation.
- **Foot IK works (`tools/proto_ik.gd`, headless, 3 of 3 checks pass).** Godot's `TwoBoneIK3D` (new in 4.6, present in 4.7) moved the left foot of a generated body onto a target 15 cm higher to within 0.000 m, bent the knee toward the pole target (z -0.26 m, forward) and left the right foot where it was. The setup is `setting_count` plus indexed setters (`set_root_bone_name`, `set_middle_bone_name`, `set_end_bone_name`, `set_target_node`, `set_pole_node`), verified through the class API. **Catch found:** the modified pose can be read only inside the skeleton's `skeleton_updated` signal; reading `get_bone_global_pose()` at other times returns the unmodified pose, which at first looked like "IK does nothing". This is the kind of thing the 4.6 blog and docs did not say (research gap B10 now has a working recipe on our rig). The check starts the legs slightly bent; a perfectly straight chain was not tested separately.
- **Cost of 20 animation trees (`tools/proto_motion_bench.gd`, headless, one run):** 20 generated bodies with an `AnimationTree` each: **0.150 ms per frame for all 20** (0.0075 ms each); with a plain `AnimationPlayer` each: 0.100 ms for all 20. This is animation evaluation only; it excludes drawing and GPU skinning (headless), and this PC is probably faster than the minimum machine, so treat it as a lower bound. It is far inside the earlier 1 ms budget for 20 bodies, so the `AnimationTree` is not a cost worry on the evidence so far (the forum worries in 3.2 B5 were about much larger crowds on weaker CPUs).
- **Not done in Plan 5:** squash and stretch with a helper bone (left for Plan 6 with the new hands), full-scene cost with drawing on the minimum machine, IK on a real slope with ground rays.

## 8.6c Plan 6 result: body version 2

- **Hands:** a simplified hand with a thumb and three finger groups (index, middle and ring together, little), two bones each, 16 more bones (37 in all, Godot humanoid names such as `RightIndexProximal`). Each hand is meshed on its own finer grid (about 9 mm) so fingers exist at all (at the body's 3 to 4 cm grid they would vanish). Poses tried in `art/character_proto/hands/hands_and_faces.png` (top row): open, fist, point (index out, the rest curled), claw. They read as hand shapes; they are crude.
- **Face:** eyes and brows are now small movable parts on the head bone (no mesh rebuild): `Generator.set_expression(face, open, brow_raise)` blinks (open near 0), widens (1.35) and raises or lowers the brows. Bottom row of the same picture: normal, blink, wide eyes with raised brows, narrowed eyes with lowered brows. No lip-sync, no jaw (Part 4.6).
- **Share code:** `Generator.encode(genome)` gives a short text (version byte, one byte per slider, three bytes per colour, a check byte, Base64; 64 characters or fewer); `decode` refuses cut, damaged, empty or foreign text and never executes anything from it.
- **Detail levels:** `Generator.lod_voxel(level)`: 3.0, 4.5 and 7.0 cm grids (near, middle, far); the hand grid scales with it.
- **Speed after adding hands:** 0.63 to 0.83 s per body at 3.5 cm detail (7,600 to 10,800 triangles) in GDScript on this PC, after speeding up the skin weights (they now only look at the parts of the vertex's own group). Hands cost about 1,000 triangles per body at near detail, so a far level should drop the fingers (not built yet).
- **Check (`tools/check_body_generator.gd`, headless): 244 checks, 0 failures:** bone names unique, parents before children, required bones present; for each archetype no NaN vertices, unit normals, weights in range and summing to 1, valid indices, plausible height (1.5 to 2.3 m), feet at the floor, left and right balanced, bones that matter carry weight; **every one of the 18 sliders at both extremes gives a valid body**; share code round trip, refusal of damaged codes; same genome gives the same mesh and weights.
- **Not done in Plan 6:** squash and stretch, seam lines at limb joints, a far detail level without fingers, a skin bind check after reload, real texture or lighting work.

## 8.6d Plan 7 result: first-person arm rules moved out of `held_item.gd`

The rules for how the arms follow the body at rest and the camera while working (`next_arm_up`, `arms_transform`) and the fist at each hand mount (`make_fist`) moved to `src/client/character/arms_view.gd`; `held_item.gd` shrank by 22 lines (4 added, 26 deleted) and calls it, passing its own tuning constants. **Check (`tools/check_arms_view.gd`, headless): 4,013 cases, 0 differences** against the old formulas repeated as the reference (2,000 random arm-up blends, 2,000 random camera poses, fist size, place and colour), plus a test that reads `held_item.gd` as text and fails if any of the seven tuning constants was changed, plus a compile check of `held_item.gd` and `terrain_client.gd`. **Not moved:** the swing, jab and throw timers, the tool mounting and the per-tool constants (about 1,700 lines), because they are entangled with the item and network code and I could not build an honest equivalence check for them without running the game.

## 8.6e Three more plans (approved by me under the moderator's pre-approval; Plan 8 starts now)

**Plan 8. Existing clips on the new skeleton, and a drop-in adapter. DONE (8.6f), not run in the game.** Convert every clip of the old rig automatically (rename the bone tracks to the new names, scale the hips position by hips height) so no clip is authored twice; build an adapter node with the same methods the game uses on the old body (`play`, `current`, `is_one_shot_playing`, `animation_player`, `hand_mount_r`, `hand_mount_l`, `head_mount`, `dress`, `set_shoulder_log`, `skeleton`, `body_mesh`) so the generated body can replace the old one behind a command-line switch that is **off by default**. Done when: the converted clips match the old ones numerically on mapped bones and the adapter passes a method-by-method check. Needs a look in the running game before anyone turns it on.

**Plan 9. Creator prototype.** A standalone scene (new files only) with sliders for the 18 genome values, a dice button for everything and one per section, per-slider locks, undo, preset archetypes, a share-code box and a turntable preview using the same generator. Logic (dice, locks, undo, codes) checked headless; looks checked by pictures.

**Plan 10. Motion polish.** Strafe and backward walking, jump, fall and land, crouch walk, swim and ladder clips, squash and stretch with a helper bone, foot placement on a real slope with ground rays, and a far detail level without fingers; each with a headless check where one is possible and pictures where not.

## 8.7 What was tested how (for Dave's review)

Nothing below was run inside the real game. **"Headless" means a command-line run with no window; "pictures" means my own render script showing the generated bodies in a bare test scene, not the game's scene, lighting or camera.**

| Item | How it was tested | Still needs a look in the running game |
|---|---|---|
| Body generator (shape, bones, weights, 18 sliders at extremes, share code) | 244 headless checks, all pass | Yes: how the body looks in the game's lighting, textures and at game distances; per-frame cost with real drawing on the minimum machine |
| Body appearance and bending | Pictures only (my judgement of stills; flat lighting, no game camera) | Yes: everything about looks |
| Generation time | One run per body on this PC, wall clock | Yes: the minimum machine will be slower; many bodies at once |
| Save and reload of the baked mesh | One headless-capable run: same vertex count after reload | Yes: skin binds after reload, and loading many |
| Animation tree, filtered one-shot, stepped poses, motion scale | 10 headless checks, all pass | Yes: how the motion feels at 60 frames a second, with real input |
| Walk and panic strips | Pictures only | Yes: the clips are crude prototypes; judging comic timing needs motion, not stills |
| Foot IK (`TwoBoneIK3D`) | 3 headless checks, all pass, on a flat test with a raised target | Yes: on real slopes with ground rays; a straight chain was not tested alone |
| Cost of 20 animation trees | Headless, evaluation only | Yes: includes no drawing or skinning |
| Avatar rules moved out of `terrain_client.gd` | 11,731 headless comparisons against the old formulas, 0 differences; both files compile | Yes: the game was **not run**; this is the only edit of the player's visible behaviour code, and it should be looked at once in play (walk, jog, run, crouch, carry a log, slopes) |
| First-person arm rules moved out of `held_item.gd` | 4,013 headless comparisons, 0 differences; constants checked; files compile | Yes: swing, jab, aim and rest pose in first person should be looked at once in play |
| Old clips converted to the generated skeleton; drop-in body | 5,124 headless comparisons, 0 failures; pictures of the old clips on two bodies | Yes, essential: start the client with `--generated-body` and look in third person (walk, run, crouch, carry a log, tool in hand). **Never run in the game.** |
| Fear list, backgrounds, traits, all plans | Documents only | They are proposals; nothing is built |

## 8.6f Plan 8 result: the old clips play on the generated body; a switch to try it in the game

- **Clip converter (`src/client/character/clip_converter.gd`):** renames the tracks of every old clip (idle, walk, jog, run, crouch, sit, lie, swing, swing_fp, jab, throw, use, carry_idle, carry_walk) to the humanoid bone names and puts the hips position in units of hips height, so **no clip is authored twice**. (A function of that name clashed with a built-in; renamed `convert_clip`.)
- **Drop-in body (`src/client/character/generated_body.gd`):** offers the methods and properties the game uses on the old body (`skeleton`, `body_mesh`, `animation_player`, `hand_mount_r/l`, `head_mount`, `play`, `current`, `is_one_shot_playing`, `dress`, `set_shoulder_log`), with a shader so the clothes colours can still be set (the material id rides in the vertex colour alpha).
- **Check (`tools/check_generated_body.gd`, headless): 5,124 cases, 0 failures.** Every converted track equals the old one (rotations equal, hips positions divided by 0.95, key times and counts, loop modes, lengths); the new body has every method and property listed above and they behave as the old ones in the calls the game makes. The other checks still pass after the change (`check_avatar_driver` 11,731 cases, `check_arms_view` 4,013 cases, `check_body_generator` 244 checks, `check_ragdoll` ok), and `terrain_client.gd` and `held_item.gd` compile.
- **Picture:** `art/character_proto/converted/old_clips_on_generated.png`: the **old** clips (idle, walk, jog, run, crouch, swing, jab, throw, in that order) on the lean and stocky generated bodies. They read correctly on both; the stocky body bends into the crouch with a rounder shape. Colours look darker than before because the test lighting differs from the earlier pictures; the game's lighting was not used.
- **A way to look at it in the running game (off by default):** start the client with the argument `--generated-body` and the player's third-person avatar becomes the generated body instead of the old ragdoll (one added line in `terrain_client.gd::_make_avatar`, plus a guard in `avatar_driver.gd` so worn pieces, which are built on the old bone names, are skipped on the new body). **It has not been run.** Known gaps when it is on: worn clothing pieces are not shown; the first-person arms are still the old model; generation takes about 0.6 s when the avatar is first made; no head look or turning (as before).

## 8.4 What I did not do, and why
- **Moving passages into an archive file (answer 2):** not done yet. Every passage is already copied in Part 2 of this file, so nothing can be lost. Editing the original documents now (many live files, edited by other agents on other branches) risks merge conflicts and gains nothing yet; I will create the archive file and replace the passages in the originals with one-line pointers in one pass when Dave or the moderator says the plan is final, or sooner if asked. This is a decision of mine, stated here so it can be overruled.
- **Avatar module extraction (answer 1):** done for the avatar rules in Plan 4 (8.3c); the first-person arm code is Plan 7 (8.6).
- **Playing the generated body in the game:** not done; no existing game file was changed.

## 8.5 Next steps (in order)
1. Plan 1: seams, hands with fingers, a nicer face, a lower-detail variant for distance, and a skin bind check after reload.
2. Plan 2: look at the clips on screen (a walk strip and the panic poses), squash and stretch, foot placement, and the cost of 20 trees.
3. Plan 3: Dave's review of Part 9 and 5.8.8.
4. Plan 4: avatar and arm module extraction once the skeleton is frozen.

---

# Part 9. Proposals for Dave: backgrounds and traits (Plan 3, draft; nothing here is decided)

Written for Dave to cut and change. Moderator answer: "draft the fear, background and trait lists as proposals". The fears are in 5.8.8. Everything below uses only skills and attributes that already exist in `data/items/skills.json` and SKILLS_AND_ATTRIBUTES.md, so a background is just a few small number changes and one story line. All wording follows the safe-place rule: a background describes **what the character did and learned**, never who they are; no background mentions skin, face, body or any real group. Boons and drawbacks are small, so no background is clearly best.

## 9.1 Traits (attributes) on the existing scale
Existing, -10 to +10, whole numbers: **Luck** and **Fitness** (built); **Strength**, **Dexterity**, **Memory**, **Wisdom** (listed, not built). **Proposal: add one new attribute, Courage** (-10 to +10), because it is the natural dial for the greatest-fear panic roll (5.8.4): higher Courage lowers the chance to freak out, lower Courage raises it. It also gives a comic knob, such as a bold fool and a timid hero. Attributes feed skills through the existing web of weights (so "base traits affect all related skills" holds). Point buy and roll rules are in 5.8.3. Suggested point-buy pool and caps are a number for the skills designers; I give none.

## 9.2 Twelve draft backgrounds
Each row: **story**, **skills it nudges** (existing skill names), **attribute nudge** (small), **boon**, **drawback**, **look hint**. A "nudge" is a starting bump of a few levels, not a cap.

| # | Background | Story (one line) | Skills nudged | Attributes | Boon | Drawback | Look hint |
|---|---|---|---|---|---|---|---|
| 1 | Woodcutter's Helper | grew up carrying logs and sharpening axes | woodcutting, crafting | Strength +1 | a little extra yield from felled trees | clumsy with delicate work (crafting time slightly higher at first) | calloused hands, leather apron colours |
| 2 | River Fisher | learned the shallows and the weather from a boat | fishing, tracking | Wisdom +1 | bites come a little sooner | easily bored by long waits away from water (small exertion rise on dry land when idle is not used; flavour only) | a woollen cap, waders colours |
| 3 | Hedge Herbalist | knew which leaves heal and which ones do not | foraging, gathering | Memory +1 | extra plant yield and a better chance to recognise a plant on first inspection | weak at hauling (lower carry in the first levels) | pouch, bundle of herbs on the belt |
| 4 | Quarry Apprentice | spent years swinging a pick in the dark | mining, digging | Strength +1, Fitness +1 | a little faster at breaking rock | a little uneasy under open sky: a tiny extra chance of the greatest-fear roll outdoors in storms | dusty clothes, a pick strapped to the back |
| 5 | Hunter's Kin | followed a relative through the woods | hunting, tracking | Dexterity +1 | quieter steps | bad at crowds and market talk (worse prices in trade, once trade exists) | fur trim, a bow or spear colours |
| 6 | Travelling Peddler | walked from town to town selling small goods | crafting, trades | Memory +1 | better prices once trade exists, remembers faces and places | thin pack at the start | patched cloak, many small pouches |
| 7 | Hermit's Student | learned quiet living and odd lore in a cave | foraging, tool care | Wisdom +2 | spots the Might-be and Unknown inspection clues better | slow with tools (small craft time penalty) | plain robe, a staff |
| 8 | Shepherd | spent days on hillsides with a flock and a dog | gathering, tracking | Fitness +1 | steadier on slopes and in weather | a little slow to learn fighting skills | wool coat, a crook |
| 9 | Ferry Hand | poled people across rivers and learned the water | athletics, fishing | Fitness +1 | steadier swimming (slower exertion rise in water) | uneasy on tall places (small bump on the greatest-fear roll near heights) | rope belt, a striped shirt |
| 10 | Cook's Helper | chopped, stirred and carried at an inn | crafting, gathering | Dexterity +1 | slightly better food results once cooking depends on skill | soft hands (small exertion rise on heavy work at first) | apron, a ladle |
| 11 | Tower Watch | kept a lookout light and watched the sky | tracking, athletics | Wisdom +1 | notices weather and distant movement a little earlier | night-time dread: a small bump on the dark fear roll | a lantern, a long coat |
| 12 | Wandering Tinkerer | mended pots and tools for coin | crafting, tool care | Dexterity +1, Luck +1 | tools wear a little slower | spends coin carelessly (starts with fewer items) | tool roll, goggles or a magnifier |

Notes for Dave: (1) Every drawback is something that can be coded as a small change in an existing number or a flavour line; I did not invent new systems. (2) Items "once trade exists" refer to features that are not built yet. (3) The rows deliberately overlap in skills so that no skill belongs to one background. (4) Any row can be renamed, merged or dropped; the count of twelve is arbitrary. (5) Backgrounds could also be offered to NPCs at birth (DESIGN_IDEAS.md already rolls an NPC background).

## 9.3 How a background, a trait and a fear fit together (an example)
A "Quarry Apprentice" with Strength +1, Fitness +1 and a greatest fear of "cave-ins and creaking timber" is good at mining and bad at being calm in a mine: strong and capable, but with a comic panic chance when the roof creaks, which is the funny contrast Dave described. A "Tower Watch" with a fear of "the dark" has a small extra bump, so the story and the fear can reinforce each other, or the player can choose a fear that contradicts the background for different comedy.

## 9.4 What I need from Dave on these
Not a blocker. When Dave reviews: keep, rename or cut each background; say whether Courage should be added as an attribute; and give the point-buy pool and caps to the skills designers (or tell me to propose numbers).

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

- **Round 1:** six sub-agents, one per topic (A to F). **Round 2:** three sub-agents on the gaps round 1 left (gait and feel numbers; design, budgets, modular, animation cost, Valheim; Godot-specific gaps). **Round 3:** my own spot checks (J1 to J3) plus reading the Valve documents. That is **three rounds** for the original plan; **round 4** (3.11) followed Dave's later requests for claymation, character-creation and body-generation research, with four more agents, so the document now rests on **four rounds**. Round 3 found nothing that changes the plan, so I stopped there. Round 2 did add important items (the Compatibility-renderer skinning issue H4, SpringBoneSimulator3D version H1, the unverified gait table 3.7, the lack of stairs support I9, the 4.7 `LookAtModifier3D.relative` change I1), so I would not call the research exhaustive, only sufficient for planning.
- **Limits.** Most sources were summarised by a small model on fetch and many pages were not fully readable (several returned 403 or were blocked). Dozens of items are SNIPPET-level. I did not re-check every claim. Treat SNIPPET items as leads. A second pair of eyes should re-open the sources behind any decision that costs a lot (the Compatibility-renderer issue, the multiplayer approach, the choice of IK nodes).
- **Still NOT CONFIRMED (the honest list):** numeric human gait values (3.7 G15); proportion numbers for stylised bodies (J3); developer-stated triangle budgets for comparable games (H11); how Valheim, Ark, Rust, 7 Days to Die sync animation and build armour (E11, F7, H12); turn-in-place and lean-into-turn technique (G15); procedural arm swing and left-hand IK recipes (C11); a Godot recipe for foot and hand IK with the new 4.6 nodes (B10, I2); whether skinned meshes can be batched and how Forward+ skins (H8, H9, I7); an official input-latency standard (G11); remote-player foot-sliding fix (E11); mounted riding pose angles (G10); breaststroke and treading (G8); Unreal's official URO guide (H5); the Overwatch GDC talk content (E7).

---

## 3.11 Round 4 (Dave asked for the claymation research, then the character-creation research; four agents)

Round 4 added four topic reports: 3.11.1 claymation technique, 3.11.2 games and films that imitate stop-motion, 3.11.3 generating the body in code, 3.11.4 character creators, D&D mechanics, ancestry design and fear mechanics. Conclusions drawn from them are in Part 4.6, 4.7, 5.7 and 5.8. Tags as in 3.0.

### 3.11.1 Round 4a: claymation and stop-motion comedy technique (agent report; I reviewed it)

Many search results were low-quality mirrors, so fewer sources were opened than hoped. Tags as in 3.0.

**Faces: what the famous "limited face" characters still use (this corrects my own earlier wording)**
- **L1** Gromit has no mouth but **does** act with a movable brow, eyes, ears and neck, plus hands, feet and body; Feathers McGraw (tiny bead eyes, almost no movement) is the opposite extreme and is described as hard to animate. https://gizmodo.com/wallace-and-gromit-vengeance-most-fowl-feathers-animation-netflix-2000549707 (OPENED). Park dropped Gromit's planned mouth because brow movement plus body language communicated more than speech (a post reporting Merlin Crossingham; attribution slightly unclear). https://kottke.org/16/05/how-gromit-from-wallace-and-gromit-is-built (OPENED). A dog was chosen because a dog can show emotion without speaking; Wallace's vest is hollow so animators can grip him. https://blog.scienceandmediamuseum.org.uk/surprising-stories-about-aardman-animations/ (OPENED)
- **L2** Shaun the Sheep: expression relies mainly on the **eyes** (plus lids and ears), the only facial features animators change, and on head and shoulder positioning for mood; about three seconds of finished animation per animator per day. https://www.annecyfestival.com/about/archives/2015/2015-meetings/2015-conference-summaries/summary:100000393398 (OPENED). He communicates with wordless sounds and gestures such as pointing, with slapstick and silent-film style comedy. https://en.wikipedia.org/wiki/Shaun_the_Sheep (OPENED)
- **L3** Pingu: the beak is the main expressive feature; speech is invented babble. https://en.wikipedia.org/wiki/Pingu (OPENED). Claims about clay versus replacement parts come from fan wikis only (unverified).
- **Consequence (RECOMMENDATION, my decision):** the claim "no face acting" was too strong. The accurate version is: **no lip-sync and no detailed facial animation; a minimal eye and brow channel is allowed as a cheap supporting channel**, with body and hands doing most of the work. Details in Part 4.6.

**Frame rates and pace**
- **L4** Definitions: on ones = a new pose every frame (24 per second at 24 fps), on twos = each pose held two frames (12 per second), on threes = 8 per second; mixing inside a shot is normal, with ones for fast or detailed action. https://www.idtech.com/blog/what-does-animating-on-ones-twos-and-threes-mean (OPENED; about drawn animation, arithmetic applies). 12 poses per second is described as a common stop-motion target with a staccato feel (blog, SNIPPET). https://huehd.com/stop-motion-animation-frame-rates-explained/ (SNIPPET)
- **L5** **Not found:** any authoritative statement of Aardman's own practice (ones versus twos) or their frame counts for takes, reaction holds and recovery. The agent's recollection that feature stop-motion is mostly on twos with ones for fast action is MEMORY.
- **L6** Laika holds an expression two or three frames at 24 fps but changed the face 12 to 24 times a second on Missing Link so brows could rise slowly; printed face counts differ by source. https://www.tctmagazine.com/famous-faces-3d-printing-laika/ (OPENED)
- **L7** Output is very slow (about 3 to 4 seconds of finished animation per animator per day on Shaun and Chicken Run; one older interview says about 5 seconds a week); sources conflict, so only the order of magnitude is usable. https://www.slashfilm.com/1447180/chicken-run-dawn-of-the-nugget-cgi-stop-motion-animation (OPENED), https://www.irishtimes.com/culture/film/2023/12/09/chicken-impossible-behind-the-scenes-at-dawn-of-the-nugget (OPENED)

**Clay deformation versus replacement parts**
- **L8** Chicken Run's sequel used more than 5,000 clay mouths and beaks sorted by sound; bodies now silicone with clay heads; the art director called the eyes the "soul" of the puppet (Slashfilm and Irish Times above, OPENED). Plasticine can stretch without an armature but gives less control; puppets normally use metal armatures. Aardman's course outline lists clay over wire, replaceable hands and face parts. https://academy.aardman.com/puppetmaking-professional (OPENED). **No direct Aardman statement about squash and stretch technique was found.**
- **L9** The handmade look is intentional: Park told animators not to worry about visible thumbprints. (Science Museum blog and an Aardman animator interview, OPENED, above and https://alternativemagazineonline.co.uk/2009/11/27/interview-in-converstion-with-merlin-crossingham-lead-animator-at-aardman-animation/)

**Timing of takes, anticipation and holds**
- **L10** A CG tutorial's starting recipe at 24 fps (not Aardman practice): a basic take is about 4 frames anticipation, about 7 to the accent, about 7 to settle; a punchier take holds the anticipation about 6 frames then pops to the accent in one frame; a double-take has two head-turn poses about 3 frames apart then an accent of about 9 frames. https://www.schoolofmotion.com/blog/how-to-animate-character-takes (OPENED). Treat as tunable starting values.
- **L11** Anticipation makes the following action clearer and affects perceived speed and weight; "moving holds" stop a held character looking frozen. https://learn.toonboom.com/modules/animation-principles/topic/anticipation-principle (SNIPPET). Standard books (MEMORY, not opened): The Animator's Survival Kit, Cartoon Animation, The Illusion of Life.
- **L12** Staging: present one idea at a time; action reads better in side-on silhouette than frontal; Disney tested poses as black shapes. https://education.siggraph.org/static/HyperGraph/animation/character_animation/principles/staging.htm (OPENED)

**Pantomime and silent comedy**
- **L13** Chaplin's pantomime is catalogued across 83 films; the Tramp's identity was kept by dominant visual expression; the moustache was kept tiny so it would not hide his expression (moderate-quality sources). https://docta.ucm.es/entities/publication/4dc4c4a5-3c03-480b-9879-465cfef90869 (SNIPPET). Keaton's stillness was a deliberate tool that made reactions pop (a held neutral pose, then the reaction). https://archives.boulderweekly.com/entertainment/eternal-appeal-great-stone-face/ (SNIPPET). **Mr Bean: no reliable technique source found.**
- **L14** Emotion pose vocabulary (tutorial conventions, not science): fear = lean away, shrink, protect the torso; surprise = brief, timed against the trigger; relief = tension collapse, shoulders drop, breath release; pride = chest out, head up, hands on hips; exhaustion = slump, limp arms, lagging head, extra apparent weight. https://mocaponline.com/blogs/mocap-news/emotion-animation-games-guide (SNIPPET)
- **L15** Aardman animators act through the puppet (holding it with both hands to feel its weight) and say consistency of performance across a film is hardest. Sources did not open (SNIPPET). Park acted out scenes himself as live reference for animators. https://screenrant.com/early-man-director-acted-entire-movie-live-action/ (SNIPPET)
- **L16 Gaps:** Aardman primary statements on frame rate and takes; hand-posing technique for Wallace and Gromit; Pingu's construction; Chaplin, Keaton and Mr Bean technique from authoritative sources. Pages that failed to open: theasc.com, stopmotionanimation.com, metro.us, animationmentor.com, some Animation World links.

### 3.11.2 Round 4b: games and 3D films that imitate stop-motion or limited frame rate (agent report; I reviewed it)

Confidence tags as in 3.0: OPENED, SNIPPET, MEMORY. "Inference" means the agent's own reasoning from an API, not a documented practice.

**Godot API for held, stepped poses (verified against stable = 4.7 docs)**
- **K1** `Animation.InterpolationType` has NEAREST (no interpolation, holds the nearest key), LINEAR, CUBIC, LINEAR_ANGLE, CUBIC_ANGLE; set per track with `track_set_interpolation_type`. NEAREST gives true held poses. https://docs.godotengine.org/en/stable/classes/class_animation.html (OPENED). Value tracks also have an update mode DISCRETE, which updates only at keys (useful for property or blend-shape pops). Same page.
- **K2** `AnimationMixer.callback_mode_process` MANUAL plus `advance(delta)`: the engine way to update animation at a lower rate (accumulate time, call `advance` at your chosen step such as 1/12 s). The "12 Hz idiom" is the agent's inference; the docs only describe the API. https://docs.godotengine.org/en/stable/classes/class_animationmixer.html (OPENED). `Skeleton3D` has its own modifier manual mode, so spring bones and IK must be stepped with it. https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html (OPENED)
- **K3** A forum user got a stop-motion look from Blender by exporting glTF with the "Sampling Interpolation Fallback" option set to Step (lowering Godot's import FPS did nothing). One user's report, 4.4.1. https://forum.godotengine.org/t/how-to-get-low-frame-rate-3d-animations-stop-motion-style/125609 (OPENED). A community Godot 4 plugin, FlipDot, caps an AnimationPlayer's frame rate without changing the player (MIT, v1.0.0, 2026-03-10; repo not opened, implementation unseen). https://www.godotengine.org/asset-library/asset/4882 (OPENED listing)
- **K4** `MeshInstance3D` has a blend shape API (`set_blend_shape_value`, `find_blend_shape_by_name`); the animation track path for blend shapes was not confirmed. https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html (OPENED)

**Games and films**
- **K5 Harold Halibut:** early true stop-motion tests were dropped because gameplay did not work with them; faces were hand-sculpted, scanned and animated digitally with a lowered face frame rate that jumps between keyframes to keep a puppet feel (stepped keys); bodies from mocap performed by the director in a more stop-motion style, then keyframed on top; mocap cleanup was the hardest part. https://www.cartoonbrew.com/tech/behind-the-scenes-of-harold-halibut-a-handcrafted-stop-motion-inspired-video-game-241868.html (OPENED)
- **K6 Wallace and Gromit's Grand Adventures (Telltale):** per a WIRED video summary (secondary), the game ran at 30 fps but was pushed toward a 24 fps stop-motion feel, transitions were altered to feel more physical, and mouths changed in distinct steps instead of blending. https://rosetta.to/u/wired/wallace-gromit-turning-clay-into-play (OPENED, secondary; verify before relying)
- **K7 The Neverhood** was made with real clay stop-motion; **no source found on its technical pipeline**. https://en.wikipedia.org/wiki/The_Neverhood (SNIPPET). Yoshi's Woolly World and Kirby's Epic Yarn are about material looks, with no evidence found that they copy stop-motion timing. https://nintendo.co.uk/Iwata-Asks/Iwata-Asks-Kirby-s-Epic-Yarn/Iwata-Asks-Kirby-s-Epic-Yarn/1-Using-Real-Yarn-and-Cloth/1-Using-Real-Yarn-and-Cloth-206925.html (SNIPPET)
- **K8 Into the Spider-Verse:** animating on twos (a new pose every second frame) was chosen because it looks crisper and more comic-like; hair, cloth and camera on twos took cross-department effort; once the pipeline could switch between ones and twos inside a shot it became a creative choice. https://gizmodo.com/how-spider-man-into-the-spider-verses-technical-wizard-1831179866 (OPENED). Reports say characters were mostly on twos with the camera often on ones and Miles switching rate with the emotion of the scene (not opened). https://www.creativebloq.com/features/how-into-the-spider-verse-got-its-mind-blowing-look (SNIPPET). **Design lesson (RECOMMENDATION): switch frame rate by beat or emotion, not globally.**
- **K9 Other films:** Puss in Boots: The Last Wish reportedly experimented with frame rates and held key poses in action. https://www.cartoonbrew.com/feature-film/puss-in-boots-joel-crawford-inbtwn-224324.html (SNIPPET). In Arcane the hand-drawn effects were on twos while the 3D characters were not (secondary sources). https://redsharknews.com/why-netflixs-arcane-looks-so-good-how-fortiche-ramped-up-the-animation-pipeline (SNIPPET). **Hi-Fi Rush: no evidence of limited frame rate found**; it retimes animation so strikes land on the beat. https://www.unrealengine.com/developer-interviews/hi-fi-rush-was-inspired-by-shaun-of-the-dead-and-futurama (SNIPPET)

**Squash and stretch in skeletal 3D**
- **K10** The main problem: non-uniform bone scale passed down a rotated hierarchy shears, and engines often cannot represent it. Artist workarounds: drive deform bones from non-deforming control bones, scale a helper bone above the chain, or use translation instead of scale. https://forums.unrealengine.com/t/solved-blender-to-ue4-squash-and-stretch-bone-heirarchy-scaling/72193 (SNIPPET), https://polycount.com/discussion/comment/1204981 (SNIPPET). A Blender Nation post says two ways exist that work in most engines but does not name them. https://www.blendernation.com/2021/03/12/avoiding-squash-and-stretch-issues-in-game-rigs/ (OPENED)
- **K11** **Conflict to plan for:** the SpringBoneSimulator3D docs warn that scaling the simulator or skeleton will likely misbehave, so bone-scale squash and stretch and spring-bone cloaks on the same skeleton clash. https://docs.godotengine.org/en/stable/classes/class_springbonesimulator3d.html (OPENED). Alternatives (blend shapes for squash, a vertex-shader squash along a body axis with volume kept) are the agent's MEMORY, not source-verified.

**Pose-based, comic acting in games**
- **K12** Rain World's creatures are described as procedurally animated, squishy and stretchy (GDC 2016, description only). https://gamedeveloper.com/art/video-animating-i-rain-world-i-and-its-many-squishy-stretchy-creatures (OPENED). Gang Beasts and Fall Guys are described as built on procedural animation and ragdoll physics for comedy (press pages, not developer breakdowns). https://gangbeasts.game/press-pack (SNIPPET), https://en.wikipedia.org/wiki/Fall_Guys (SNIPPET)
- **K13 Not found:** maker documentation for Overcooked, Human Fall Flat, Untitled Goose Game, Goat Simulator, Lethal Company, Content Warning, Phasmophobia scared reactions; technical breakdowns of The Neverhood, ClayFighter or the Lego games; how Spider-Verse handled hair and cloth on twos; Godot-specific squash and stretch guidance; the Godot blend-shape track path format.

### 3.11.3 Round 4d: generating the body in code (agent report; I reviewed it)

Tags as in 3.0. "My inference" means reasoning the agent or I added, not a documented fact. The project fact (code): the client uses the Godot Voxel module (`VoxelLodTerrain` in `scenes/terrain_client/terrain_client.gd`), which the agent did not know.

**Godot mesh and skeleton facts (stable = 4.7 docs)**
- **M1** Per-vertex bones and weights hold 4 influences by default; the flag `ARRAY_FLAG_USE_8_BONE_WEIGHTS` raises it to 8 per surface (not a project setting). `SurfaceTool` has `set_bones`, `set_weights` (4 values each) and `set_skin_weight_count`; for 8 influences building raw arrays and calling `ArrayMesh.add_surface_from_arrays` is the safer path (agent's advice, not tested). https://docs.godotengine.org/en/stable/classes/class_arraymesh.html (OPENED), https://docs.godotengine.org/en/stable/classes/class_surfacetool.html (OPENED)
- **M2** Blend shapes: `add_blend_shape(name)` must come before the surface is added; shapes carry only vertex, normal and tangent data; signature `add_surface_from_arrays(primitive, arrays, blend_shapes, lods, flags)`. https://docs.godotengine.org/en/stable/classes/class_arraymesh.html (OPENED). `MeshInstance3D.bake_mesh_from_current_skeleton_pose` ignores blend shapes; the default skeleton path changed in 4.6 (project setting restores the old behaviour). https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html (OPENED)
- **M3** `Skeleton3D.add_bone` names must be unique, non-empty, without `:` or `/`; the parent index must be lower than the child's; `set_bone_rest` exists; `motion_scale` multiplies position-track values on playback. https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html (OPENED)
- **M4** Instance uniforms: practical maximum 16 per shader, scalar and vector types only (no textures or arrays); good for per-character skin and hair colour on one shared material. https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html (OPENED)
- **M5** `MultiMesh` ignores blend shapes (4.1 docs) and the multimesh tutorial does not mention skinned meshes, so about 20 bodies means about 20 `MeshInstance3D` plus `Skeleton3D`, not a MultiMesh. https://docs.godotengine.org/en/4.1/classes/class_multimesh.html (SNIPPET), https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html (OPENED)

**Saving and exporting**
- **M6** `GLTFDocument.append_from_scene(node, state, flags)` then `write_to_filesystem(state, path)` (.glb binary or .gltf text); runtime save and load work in exported projects, .glb recommended; FBX is load-only. https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html (OPENED), https://docs.godotengine.org/en/stable/tutorials/io/runtime_file_loading_and_saving.html (OPENED). No blend-shape export toggle was found on `GLTFState`. https://docs.godotengine.org/en/stable/classes/class_gltfstate.html (OPENED)
- **M7** `ResourceSaver.save(resource, path, flags)` writes .res (binary) or .tres (text); whether `ArrayMesh` and `Skin` save fine is agent MEMORY: test it. https://docs.godotengine.org/en/stable/classes/class_resourcesaver.html (OPENED). Caching idea (agent's): hash the rounded genome and use it as the file name; skip regeneration if the file exists.

**Sharing animation across different bodies**
- **M8** Animations address bones by path with position, rotation and scale tracks; the same bone names do not guarantee compatibility if rests differ. The import "Normalize Position Tracks" divides position tracks by hips height and stores `motion_scale`; "Unimportant Positions" strips position tracks except root and hips. **My inference (agent agrees): rotation-only clips plus a hips position scaled by `motion_scale` is the cleanest design for per-genome bodies.** https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html (OPENED)
- **M9** `RetargetModifier3D` copies pose from a parent skeleton to child skeletons even when rests differ (model space; with `use_global_pose` off, differing proportions are tolerated). Use: one shared reference skeleton drives every genome skeleton; cost for 20 characters untested. https://docs.godotengine.org/en/stable/classes/class_retargetmodifier3d.html (OPENED). Changing rests per character with `set_bone_rest` is allowed; behaviour of position tracks after changing rests is untested.

**Making a smooth body from primitives**
- **M10** Smooth minimum (Inigo Quilez): polynomial smin blends two distances over a band; order matters for some versions; used in Media Molecule's Dreams. https://iquilezles.org/articles/smin (SNIPPET only; direct fetch failed; formulas not verified). Capsule SDFs for limbs are on the same site (MEMORY).
- **M11** Surface nets (Lysenko, "Smooth voxel terrain"): averages edge crossings per cell, giving quad-based, well-shaped meshes; simpler than dual contouring; fits a rounded body with no sharp features (agent's summary). https://github.com/mikolalysenko/isosurface (SNIPPET, MIT). A Rust surface-nets crate claims about 20 million triangles per second on one core (native speed reference only). https://docs.rs/fast-surface-nets (SNIPPET)
- **M12** GDScript speed: a developer called smooth-terrain marching cubes in GDScript "lackluster" and planned a GDExtension port; no voxel-count benchmarks found. https://redlib.hbubli.cc/r/VoxelGameDev/comments/1jjue4f/working_on_a_sandbox_game_in_godot_using_smooth (SNIPPET). **Estimate (inference, not sourced): a 40 x 40 x 100 cell grid is about 160,000 cells, probably hundreds of milliseconds to seconds in GDScript: fine when baked once and cached, not per frame. Benchmark in the project.**
- **M13** The Godot Voxel Tools module (Zylann) has an SDF channel and smooth meshers, designed for terrain streaming. https://voxel-tools.readthedocs.io/en/latest/smooth_terrain/ (SNIPPET). It is probably heavier than a single-body bake needs; whether to reuse it is open.

**Automatic skin weights**
- **M14** Pinocchio (Baran and Popovic 2007): weights from bone proximity smoothed by a diffusion equilibrium over the surface; assumes the character is roughly proportioned like the template skeleton, which fits a genome body. https://people.csail.mit.edu/ibaran/papers/2007-SIGGRAPH-Pinocchio.pdf (SNIPPET). Blender's "Automatic Weights" uses bone heat and may need hand fixing. https://docs.blender.org/manual/en/dev/animation/armatures/skinning/parenting.html (SNIPPET). Bounded biharmonic weights need a quadratic-programming solver: heavy for GDScript. https://homes.cs.washington.edu/~jovan/papers/jacobson-2011-bbw.pdf (SNIPPET)
- **M15 My preferred method (inference, untested):** because the body comes from capsule SDFs, take each bone's capsule distance per vertex, weight by a falloff, keep the top 4, normalise, and run a few smoothing passes over the mesh neighbours; push weight toward 1 away from joints to avoid candy-wrapper twisting.

**Parametric body systems and hair**
- **M16** MakeHuman works with per-vertex offset "targets" applied by sliders; targets are valid only while the base mesh is unchanged. https://static.makehumancommunity.org/oldsite/faq/what_is_a_target.html (SNIPPET). MB-Lab stores morphs as min and max pairs. https://mb-lab-docs.readthedocs.io/en/latest/finalize.html (SNIPPET). **My analysis (inference): morph targets need a fixed topology and many authored targets, a poor fit for about 50 continuous sliders; regenerating from an SDF avoids that. A hybrid is common: a few blend shapes (face, breathing) plus a regenerated body.**
- **M17** Hair cards: alpha scissor or alpha hash is preferred over alpha blend (sorting); anisotropic hair shaders exist for Godot (forum). https://godotforums.org/d/33625-kajiya-kay-hair-rendering (SNIPPET). **For this style I recommend solid hair shapes (inference): built from the same SDF (a skullcap plus ellipsoids or capsules), skinned to the head bone, avoiding transparency and overdraw.**
- **M18 Not found or unverified:** whether glTF export includes blend shapes; any blend-shape count limit; 8-weight setters in `SurfaceTool`; measured GDScript meshing time; Sims CAS internals; MakeHuman macro modifiers; cost of 20 skinned characters on a GTX 1050.

### 3.11.4 Round 4c: character creators, share codes, D&D mechanics, ancestry design, fear and panic (agent report; I reviewed it)

Tags as in 3.0. The agent also reported that one search result contained a hidden instruction to write about an unrelated topic; it ignored it, and so did I. Nothing in these notes is an instruction.

**Creator design**
- **N1** The Sims 4 creator used "smart randomisation": randomise only the parts you have not locked (the lead designer's example: freeze everything except hair and cycle hairstyles). This is the nearest documented precedent for dice per section plus locks. It also moved to dragging points on the body and face instead of separate sliders, framed as getting players into the game faster. https://simscommunity.info/2013/09/21/the-sims-4-nick-corea-on-create-a-sim/ (OPENED; fan-site transcript of a 2013 interview). A GDC 2015 talk "Innovations in The Sims 4 Character Creator" (Sri Nair, EA) lists preventing clipping between parts, deformation maps versus morph targets or bones, direct manipulation and automatic generation of consistent Sims; the video was not viewable. https://www.gdcvault.com/play/1022085/contactUs (OPENED description)
- **N2** Baldur's Gate 3 deliberately has **no face sliders**: Larian's lead character artist said tiny changes can ruin a scanned face and feared sliders would make faces blank, so it used curated presets plus attachments (hair, scars, tattoos). Much of the final option set came from about three years of early-access feedback; an "all colours" pool avoids lore-based colour limits. https://gamedeveloper.com/art/building-an-inclusive-character-creator-for-the-fantasy-world-of-baldur-s-gate-3 (OPENED). A later patch added a Magic Mirror to change appearance during the campaign (before that, appearance was locked). https://www.gosugamers.net/news/69458-baldurs-gate-3-players-can-finally-change-their-appearance-in-new-update (SNIPPET)
- **N3** Slider overload is a recognised problem: a Casual Creators workshop paper argues that as facial sliders multiply the space of faces gets hard to grasp and sliders interact unpredictably. https://mkremins.github.io/casual-creators-workshop/papers/ICCC20_paper_197.pdf (SNIPPET; text not recoverable). Fallout 4 replaced numeric face sliders with dragging and "putty"; some players preferred numbers, others said extreme slider values make faces look alike. https://middleofnowheregaming.com/2015/11/12/fallout-4-review-part-1 (SNIPPET)
- **N4** Sharing: Black Desert has save and load files (format not documented); Nioh 2 and Saints Row use share codes; Dragon's Dogma 2 has no codes but a standalone creator and storage tool; Mount and Blade II: Bannerlord stores a face as text with a long hex key shared by copy and paste. https://www.naeu.playblackdesert.com/en-US/Wiki?wikiNo=5 (SNIPPET), https://primagames.com/tips/nioh-2-character-codes (SNIPPET), https://www.gamesradar.com/saints-row-character-customization (SNIPPET), https://primagames.com/tips/are-there-character-creation-codes-in-dragons-dogma-2-answered (SNIPPET), https://docs.bannerlordmodding.com/_xmldocs/npccharacters/npccharacter/face (SNIPPET)
- **N5** Lesson from Mass Effect: Andromeda (players reported creator faces looked worse in game and in animation): preview with the real in-game rig, lighting and animations. https://www.pcgamer.com/mass-effect-andromeda-wont-get-any-animation-improvements-on-day-one (SNIPPET)
- **N6** The Game Accessibility Guidelines basic tier includes saving and remembering all settings, simple controls or a simpler alternative, readable text and avoiding flicker; the motor section lists avoiding sudden unexpected events. https://gameaccessibilityguidelines.com/basic/ (OPENED)

**Compact storage**
- **N7** Wii Mii data: a fixed 74-byte block of packed bit fields with a CRC, the best documented fixed-width example. https://wiibrew.org/wiki/Mii_data (SNIPPET). Godot: `PackedByteArray` has `encode_u8`, `encode_u16`, `encode_half`, `encode_float`, `compress` and `decompress`. https://docs.godotengine.org/en/stable/classes/class_packedbytearray.html (OPENED). `Marshalls` has `raw_to_base64` and `base64_to_raw`, and warns that decoding objects from untrusted data can run code, so a share code should use raw bytes only. https://docs.godotengine.org/en/4.3/classes/class_marshalls.html (SNIPPET). **My inference, not sourced:** version byte, one byte per slider, enum indices and colours, CRC, Base64; store slider values, not mesh results.

**D&D mechanics and licence**
- **N8** The D&D SRD 5.2.1 is under CC-BY-4.0 (commercial use allowed with attribution; the page does not give exact attribution wording). https://www.dndbeyond.com/srd (OPENED). SRD backgrounds give three listed ability scores raised +2/+1 or +1/+1/+1 (cap 20), an origin feat, two skills, a tool proficiency and equipment or 50 gp; SRD species include Dragonborn, Dwarf, Elf, Gnome, Goliath, Halfling, Human, Orc and Tiefling. https://www.fantasygrounds.com/library/5e/dd-srd-5-2-1/character-origins (OPENED; third-party mirror)
- **N9** Ability generation in the 2024 SRD: standard array 15, 14, 13, 12, 10, 8; roll 4d6 drop the lowest six times; 27-point buy with costs 8=0, 9=1, 10=2, 11=3, 12=4, 13=5, 14=7, 15=9. https://api-beta.open5e.com/v2/rules/srd-2024_create-your-character_ability-scores/?format=api (OPENED; mirror). Forum analysis: 4d6-drop-lowest averages about 12.24 per stat versus exactly 12 for the array, so the difference is mainly variance (the agent's own arithmetic agrees). https://www.enworld.org/threads/why-i-am-starting-to-prefer-4d6-drop-the-lowest-over-the-default-array.555040/ (SNIPPET). Baldur's Gate 3 uses 27-point buy only, scores start at 8 and cap at 15. https://bg3.wiki/wiki/Point_Buy (OPENED)
- **N10** Other systems: Pathfinder 2e lets players assign attributes freely and ancestry plus background define identity (secondary sources; licence terms not checked). https://paizo.com/community/blog/v5748dyo6sieu (OPENED). Fallout 4 SPECIAL: seven stats, 21 points to allocate (snippet). Cyberpunk 2077 lifepaths change the opening and dialogue, not stats (snippet). Daggerheart pairs ancestry and community and has its own licence (not read). https://www.daggerheart.com/srd (SNIPPET)
- **N11 Licence note (not legal advice; the general point is agent MEMORY):** game rules and mechanics are generally not copyrightable while specific text is. Safest: reuse only SRD text under CC-BY-4.0 with attribution, or write our own wording for generic mechanics such as point buy and a standard array; avoid D&D names not in the SRD.

**Ancestry design and the "do not divide people" rule**
- **N12** WotC moved away from fixed ability bonuses by ancestry: Tasha's Cauldron let them be moved; Monsters of the Multiverse (2022) made them floating so the choice of people does not steer class, and dropped cultural traits for physical or magical ones; the 2024 rules moved ability bonuses to backgrounds. In December 2022 WotC said "race" is problematic because of links to prejudice against real peoples and replaced it with "species". https://www.wargamer.com/dnd/race-removed (OPENED), https://gizmodo.com/dungeons-and-dragons-player-race-changes-monsters-of-mu-1848373576 (OPENED, secondary), https://www.dndbeyond.com/sources/dnd/sae/tashas-cauldron-of-everything (OPENED; no reasoning given). **Implication (my reading): the industry direction is to attach numbers and culture to chosen options (background, class, free points) and keep ancestry cosmetic or physical. This supports the recommendation in 5.7.2 and means "cultural boons and unfortunate traits by group" goes against that direction; see Part 4.7.**

**Fear, panic and sanity mechanics**
- **N13** Darkest Dungeon: stress mostly from combat and events; at 100 stress heroes usually gain an affliction (rarely a virtue); afflicted heroes often ignore commands and add stress to the party; at 200 a heart attack; afflictions are cured in town for gold and a week. https://darkestdungeon.wiki.gg/wiki/Stress (OPENED). No source found on forced loss of control being a complaint.
- **N14** Amnesia: sanity effects on visuals and audio, exact numbers hidden, and the game deliberately lowered the challenge, so it became ambient mood with few consequences. https://www.gamedeveloper.com/design/game-design-deep-dive-i-amnesia-i-s-sanity-meter- (OPENED). Don't Starve: visible meter, effects are distortion, hallucinations and shadow creatures, no loss of control. https://dontstarve.wiki.gg/wiki/Sanity (OPENED). Phasmophobia, Lethal Company and Call of Cthulhu use hidden or semi-hidden sanity (snippet-level). Dwarf Fortress tantrums are a comic disaster where the player cannot intervene (snippet). https://dwarffortresswiki.org/Tantrum (SNIPPET)
- **N15** Skyrim ships no phobia setting; players use mods to replace spiders. https://www.nexusmods.com/skyrim/mods/26468 (SNIPPET). **Not found:** any source on opt-outs or accessibility treatment of comic panic, or on criticism of forced loss of control; my fairness and opt-out guidance in 5.8.5 is my own inference.
- **N16 Gaps:** Valheim, Palworld, Starfield, Conan Exiles, Skyrim and Elden Ring creators; undo, redo and preview-camera conventions beyond Sims 4; a talk on randomise buttons beyond Sims 4; exact SRD attribution wording; Daggerheart and Pathfinder licence terms.
