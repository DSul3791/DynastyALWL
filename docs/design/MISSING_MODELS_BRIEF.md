# Missing models: a checklist for Dave's Meshy sessions (MikeW, 8 Nov 2026)

One block per animal. The code maps bone and clip names through the model row, so **any naming works**; what matters is that the bones and clips exist. Every block follows the same 8-point list (MODEL_QUIRKS.md): standing rest pose, in-place clips, a looping clip for every role, clear unique clip names, separate eye surfaces, clean texture alpha, named tail/ear/neck/head/jaw/chest bones, no .blend beside the .fbx.

Common to all: export **FBX with textures alongside** (base colour at 2048, normal optional); real-world size does not matter (the row's `length_m` scales it) but give the length below so it can be checked; the animal **faces one axis** (any, the row turns it).

---
## Golden eagle
- **Pose to generate in:** standing perched, **wings folded** against the body, tail closed. Not wings spread (a spread rest pose is sized wrongly).
- **Length:** 0.85 m bill to tail (wingspan 2.0 m).
- **Bones needed:** spine/chest, neck (2+), head, jaw/beak (optional), each wing: shoulder, elbow, wrist (hand), and primaries if possible; tail (1 to 3); each leg: thigh, shank, foot, toes (talons).
- **Clips (in place, loop where marked):** perch idle (loop), alert head-up (loop), hop (loop), takeoff (once), flap (loop), glide/soar (loop, wings held), land (once), talons-forward strike (once).
- **Textures:** dark brown body, golden nape, pale feet; feather cards with real alpha only if used; eyes a separate surface (amber).
- **Note:** soars in big circles (FLIGHT_RIGS.md); no eye shine (birds).

## Raven
- **Pose:** standing, wings folded. **Length:** 0.62 m (wingspan 1.2 m).
- **Bones:** as the eagle (spine, neck 2+, head, beak, wing shoulder/elbow/wrist, tail, legs to toes).
- **Clips:** stand idle (loop), look about (loop), walk (loop; ravens walk, not only hop), hop (loop), peck (loop), takeoff, flap (loop), glide (loop), land, a croak with the beak open (once).
- **Textures:** glossy black with a blue-purple sheen (roughness about 0.35 on the feathers, not matte); separate dark eye.
- **Note:** replaces nothing; the crow stays. Follows players and lands at carcasses (FLIGHT_RIGS.md).

## Owl (tawny or barn)
- **Pose:** perched upright, wings folded, face to the front. **Length:** 0.4 m (wingspan 1.0 m).
- **Bones:** spine, neck (2+, it turns its head far), head, each wing shoulder/elbow/wrist, tail, legs to toes; eyelids if possible (blink).
- **Clips:** perch idle (loop), head turn left and right (loop or two once-clips), blink (once), takeoff, flap (loop, slow), glide (loop), land, pounce (once).
- **Textures:** mottled brown or white face disc; big dark eyes as a separate surface (glossy; no shine).
- **Note:** active at night only; silent in flight.

## Bat
- **Pose:** neutral standing on all fours with **wings folded**, or hanging upside down by the feet with wings wrapped; either works (the roost is a clip). **Body:** 0.08 m long, **wingspan:** 0.28 m.
- **Bones:** body/spine, head, ears (2), each wing: upper arm, forearm, and at least 3 finger bones (the wing membrane stretches between them); legs and feet; a short tail if any.
- **Clips:** roost hanging upside down, wings wrapped, breathing (loop); alert hanging, head turning (loop); drop and open wings (once); fast flap (loop, about 0.12 s per beat); short glide (loop); swing up to hang (once).
- **Textures:** dark brown fur, membrane thin and dark (alpha only at the membrane edge if needed); tiny dark eyes.
- **Note:** drawn as a colony of 8 to 40 (BAT_RIG.md).

## Whale (humpback or a northern whale)
- **Pose:** neutral swimming straight, flippers out to the sides, flukes level. **Length:** 14 m.
- **Bones:** spine chain (6 to 10, the body bends when it swims), head, jaw, each flipper (2 bones), tail stock (2 to 3), flukes (left and right if possible); blowhole not needed.
- **Clips:** swim slow (loop, the tail beating up and down), swim fast (loop), surface and blow (once), dive (once, flukes up), breach (once), idle at the surface (loop).
- **Textures:** dark grey back, pale belly and flippers; barnacle patches in the texture, not geometry; separate small eye.
- **Note:** ocean only, far from shore (`sea_depth_m`); seen from the coast. The swim system (#589) handles the surface; dives and breaches need a sea version of it later.

## Dolphin
- **Pose:** neutral swimming straight, flippers out. **Length:** 2.5 m.
- **Bones:** spine chain (5 to 8), head, jaw (optional), each flipper, tail stock (2), flukes; dorsal fin not needed (rigid).
- **Clips:** swim (loop), swim fast (loop), leap (once), surface and breathe (once), idle at the surface (loop).
- **Textures:** grey back, paler belly; glossy (roughness about 0.25), no fur.
- **Note:** pods of 3 to 10 along the coast, leaping in the bow wave of a boat later; a flock row like the ducks (one record is a pod).

---
## Then, for each model
1. Drop the export folder in the pack location or tell MikeW where it is.
2. `python tools/install_animal_models.py --kinds=<kind> --import=<godot exe>`.
3. `godot --path . --script res://tools/creature_check.gd -- --kinds=<kind> --clips` (and `--head`): every clip standing and right, length right.
4. A species spec through `tools/add_species.py`.
