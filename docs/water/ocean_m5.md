# The sea, one wave set for CPU and GPU (Sullivan water M5, Sonny, 7 Nov 2026)

Design first (Dave's top rule). The guide's sections 6 and 28 cover the ocean, and its test F10 is the precision check. M5 in `src/sullivan_water/README.md` is "ocean baseline, one wave function for CPU and GPU".

## Why
The sea today is a 12 km flat plane that follows the player (`terrain_client.gd`). Its swell is only a slope: four waves in `water_material.gd` `sea_slope`, which bend the light but not the surface. That is fine for the picture near the start, but two things are wrong:
1. **Precision (F10).** A wave's phase is k·(d·p) − ω·t. Our world is about 54 km across, so far from the world's corner the phase of the 6 m wave is tens of thousands of radians. The GPU's 32-bit floats keep only about 0.008 rad of a number that size, at every step of the sum. The swell steps and shimmers far out, and it would never match a CPU copy.
2. **One wave function.** Swimmers and boats (M7) need the sea's height where they are. If the waves live only in the shader, the CPU would need its own copy, and the two drift apart.

## The rule
1. **One wave set.** `src/sullivan_water/ocean/ocean_waves.gd` holds the four waves: direction, length, strength, the 0.6 speed tuning and the 0.21 cross-crest modulation, all as the shader had them. The shader keeps a constant copy, and the test checks that the two are the same.
2. **Phase origin.** The client picks an origin near the player, snapped to 1024 m (`origin_for`), so it moves rarely. The shader draws with q = p − origin, which is small.
3. **Phases from the CPU.** When the origin moves, the client hands the shader each wave's phase at the origin, (k·d·origin) mod 2π, and the crest's phase, in 64-bit floats (`phases_at`, uniform `sea_phase`). Since the swell is a sum of sines, the phase at p is that phase plus k·d·q, so the picture is the same as before, only exact.
4. **CPU copy.** `ocean_waves.gd slope()` is the same sum in 64-bit floats: what the shader draws, without its distance fade.

At the origin (0, 0) with zero phases the shader is exactly the old one, so nothing changes near the start.

## Second step: real heights (7 Nov 2026)
5. **Heights.** The two long waves lift the surface: 0.30 m for the 64 m swell and 0.14 m for the 29 m one (`HEIGHTS_M`), so at most 0.44 m, with steepness about 0.03, a calm sea. The short waves stay slopes for the light. The shader (`sea_height`, in the vertex step) and `ocean_waves.gd height()` are the same sum.
6. **Mesh.** The 12 km plane was two triangles, which cannot lift. `ocean/ocean_mesh.gd` is one 384 x 384 grid whose spacing is 1 m at the centre and grows smoothly to about 90 m at the 6 km edge. The plane still follows the player. The lift fades to flat between 80 and 240 m from the camera, where the spacing reaches about 10 m.
7. **One clock.** Every frame the client folds the sea clock into the phases, (k·d·origin − ω·t) mod 2π in 64-bit floats, and sets `sea_clock`. The shader no longer uses TIME for the swell, so the hourly rollover jump is gone, and the picture and `height()` are the same water at the same moment.
8. **Swimmers and the eye.** `swim.gd water_at` takes the sea's surface (`sea`, default 0 m). The client passes `height()`, so a swimmer in the sea rides the swell. Whether ground is under the sea is still decided at 0 m, so a crest does not flood a beach. The underwater view uses the swell too: a crest over the eye is under water, but only where the ground below is under the sea or none is found.

## Limits, labelled
- The sea clock is each client's own, so two players see the swell at different moments. A shared server clock comes with the boats (M7).
- The heights do not reach the far sea (flat beyond 240 m) and the sea's distance fade is not in `height()`. Swimmers are always near the camera, so this does not matter.
- Only the client's swimming and underwater view use the heights. Server checks still take the sea at 0 m; the difference is at most 0.44 m.
- The world position itself is 32-bit on the GPU (about 4 mm at 54 km). That is a 0.004 rad error on the 6 m wave, which nobody can see. The phase was the big error.

## Check
- **David4 (headless):** `test_sullivan_water_ocean`. It emulates the shader's 32-bit sums on the CPU 54 km out. It passes when the swell drawn with the origin matches the exact 64-bit swell (worst error under 0.002), the old way is at least ten times worse, moving to the next origin draws the same swell, and the shader's waves are `ocean_waves.gd`'s.
- **David4, second step:** the same test also checks heights three days in, 54 km out (32-bit against 64-bit, under 1 mm), the folded clock, the shader's heights against `HEIGHTS_M`, the mesh's 1 m centre, and that swimmers float on the swell while a beach above 0 m stays dry.
- **Dino, second step:** from a beach, a picture looking out to sea from 2 m up, then one swimming in the sea. **Pass:** the near sea visibly rises and falls with the long swell, no mesh lines or steps show, the far sea is unchanged, the swimmer bobs with the waves without the view flickering under and over, and the shader error count is 0. Also note the frame time against the first-step head.
- **Dino (picture, first step):** stand on a beach far from the corner (for example x and z about 50 km), look out to sea, and take one picture. **Pass:** the swell looks the same as near the start, with no stepping or shimmer, and the shader error count is 0.
