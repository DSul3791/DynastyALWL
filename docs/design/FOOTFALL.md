# Footfall and ground contact (MikeW, 8 Nov 2026)

## Built on the animal life layer (behind flags, off until the PC check)
1. **`footfall(kind, at, ground, speed)` signal**: fired at every landing the step sounds already use (`stepped`), with what the foot lands on (`water` where the water is above the feet, `snow` in winter, `mud` while the animal is wet, else `dust`) and the speed. One hook for puffs, tracks and ground-aware hoof sounds: Kathleen's sound stage can pick a hoof-on-mud or hoof-in-snow slot from `ground` instead of one step slot per species.
2. **Puffs** (`footfall_fx`): at a running landing (over 2 m/s), a small one-shot puff of 6 to 10 particles: brown dust, dark mud flecks or white snow; nothing in water (the swim role and wet look cover that). Gone in under a second.
3. **Slope pitch** (`slope_tilt`): the body pitches with the slope it walks on, learnt from its own movement (the server keeps it on the ground, so rise over run is the slope), held while it stands, at most 20 degrees. A long body (horse, elk, elephant) then has its front and back feet on the ground on a hillside instead of one end floating.

## Next steps (design only)
4. **Foot IK**: per leg, a two-bone IK (Godot `SkeletonIK3D` or a small solver in the bone layer) that puts each foot on the terrain height under it during stance. Needs the terrain height under each foot: a voxel raycast is too dear per foot per frame, so sample the four foot points once per landing (the footfall event) and hold them while the foot is planted. Only within 25 m of the camera.
5. **Tracks in snow and mud**: a decal per landing in snow or mud (a hoof, paw or claw print chosen by the sign group in animal_sign.json: hoofed, pawed, clawed), oriented by the heading, fading over 10 game minutes in mud and until fresh snow in snow; a cap of 200 decals near the player. These are the same prints the tracking skill reads, so the hunting trail can later point at real ones.
6. **Splashes**: wading or swimming landings (`ground == "water"`) get a ring and a few droplets (with the wet line shader).

## Check
`creature_motion --speed=8` with `footfall_fx` and `slope_tilt` set on (the run sheet's step 4 gains two lines), a horse on a 20-degree slope, and Kathleen's listening for the ground-aware hoof slots.
