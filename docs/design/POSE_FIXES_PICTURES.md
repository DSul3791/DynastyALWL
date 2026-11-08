# Lynx idle and eye highlights: the pictures that let the bones be set in one pass (MikeW, 8 Nov 2026)

Two fixes need eyes on the model before code: the lynx's idle is a low, stalking crouch (it reads as hunting while it rests), and many models have no separate eye material, so they get no eye highlight (Kathleen's check 10.5) and no eye shine (#596). Both are set from pictures of the model itself, offline, with the creature check on Dave's PC: no live game, no world, about 10 minutes.

## 1. Lynx standing idle
**Pictures (creature check, side view, 1 m grid):**
1. `--kinds=lynx --clips`: the full clip list (95 clips), to pick candidates.
2. One strip per candidate standing pose, each paused 40% into the clip: `Idle`, `idle_alerted_pose_01_to_idle_pose_01` (its end pose), `idle_call_01`, `idle_shake_01`, `idle_stretching_01`, `drinking_set_01`. A small `--roles=` option on the check lets one strip show any list of clip names instead of the row's roles.
3. The same strip with the current `Idle` and a trial `bone_offsets` of the spine and neck raised 10, 20 and 30 degrees, in case no clip stands tall.

**Then, in one pass:** pick the tallest calm clip for graze (0) and recover (12); if none, set the spine and neck `bone_offsets` from strip 3. Done means the lynx stands with its back level and head up in rest, and still crouches when it alerts or stalks.

## 2. Eye highlights where there is no eye material
39 of the 45 model rows have no `Eye` surface (deer, wolf, fox, bear and others; the list comes from the rows). Their eyes are painted into the body texture, so there is no glossy cornea and nothing for eye shine to light.

**Pictures (a new head close-up mode of the creature check, `--head`):** for each of those species, a front and a three-quarter view of the head at 0.5 m, the mesh drawn with its bones' names at the head and eye bones, and a marker at the bone positions. One sheet per ten species.

**Then, in one pass:** for each species a row key `eye_bones: [left, right]` (most rigs have eye bones: the mink's LeftEye/RightEye, the bear's eyelid bones) or, without eye bones, `eye_offset: [x, y, z]` from the head bone. The client puts two small glossy spheres (radius from the head size, roughness 0.1, the coat's eye colour) on those points, half sunk into the head; they carry the highlight and the eye shine. Done means every species shows a highlight in the strip and the eye shine strip (#596 test) lights them.

## 3. Order on the PC
1. `--head` mode and `--roles=` option (cloud, small code in tools/creature_check.gd).
2. One PC session: lynx strips 1 to 3, the head sheets (four sheets).
3. One cloud pass setting the lynx clips or offsets and every `eye_bones`/`eye_offset`.
4. A second PC session to check, then gate.
