# Ears and breathing: animals that listen and breathe (MikeW, 8 Nov 2026)

## 1. Ears (built, on the eye-placement branch)
Ears are how an animal shows what it pays attention to. Horses, deer, dogs and cats turn them toward a sound and pin them back when they mean harm.
- **Turn toward the player** when the player is within 20 m (the camera stands in for "the nearest sound" the client knows): both ears swivel toward the player's side, harder when the animal is alert (state 3).
- **Lie back flat** when the animal warns, charges or jaw-pops (10, 11, 16).
- Eased in and out, so they move like ears, not switches.
- **Data:** `"ear_motion": {"left": bone, "right": bone, "swivel_axis": "y", "flatten_axis": "x", "swivel_deg": 40, "flatten_deg": 50}`, done in the same bone layer as the crow's posture and the tail motion (`bone_offsets.gd`). Rows set: deer (first look), moose, elk, wolf, fox, horse, donkey, dog (soft, its ears hang), cat. Bone names from the files; axes a first guess until a check.
- **Later:** real sound sources (a twig snap, a call, the player's footsteps sound events) instead of the camera; one ear turning alone.

## 2. Breathing (design only)
A resting animal that does not breathe looks stuffed. Many WildMesh idles already breathe (`Idle_Breathing`), but grazing, sitting and lying clips, the gait-built loops and every pose held by `clip_loop` do not.
- **What:** the chest and flank rise and fall a few millimetres to a centimetre: a slow scale on the chest or spine bone, about 2 to 4% of its girth, at the species' resting breath rate.
- **Rates (breaths a minute at rest):** horse 10 to 14, cow 20 to 30, deer 20 to 30, dog 15 to 30, cat 20 to 30, bear 6 to 10, elephant 4 to 6, rabbit 30 to 60, birds 20 to 40 (birds' bodies barely move: half the swing). Faster after running: for 20 s after a flee or charge, twice the rate and twice the swing, settling back.
- **How:** the same bone layer: `"breath": {"bone": "Spine2", "per_min": 12, "swell": 0.03}`, applied as a scale on the bone's two short axes (not along the spine) so the body breathes instead of stretching. Off while running (the gait hides it).
- **Where it shows most:** sleeping and lying animals (bears, dogs, deer bedded down), and Kathleen's close shots.
- **Check:** moving frames, like the tail.
