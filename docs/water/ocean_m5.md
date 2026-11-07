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

## Limits, labelled
- The sea is still flat. Real wave heights (moving the plane's vertices, and `height()` for swimmers) are the next step of M5. They will use these same waves.
- TIME in the shader rolls over (Godot's default is an hour), so the swell jumps once an hour. It is unchanged by this step; the height step will pass the time as a uniform too.
- The world position itself is 32-bit on the GPU (about 4 mm at 54 km). That is a 0.004 rad error on the 6 m wave, which nobody can see. The phase was the big error.

## Check
- **David4 (headless):** `test_sullivan_water_ocean`. It emulates the shader's 32-bit sums on the CPU 54 km out. It passes when the swell drawn with the origin matches the exact 64-bit swell (worst error under 0.002), the old way is at least ten times worse, moving to the next origin draws the same swell, and the shader's waves are `ocean_waves.gd`'s.
- **Dino (picture):** stand on a beach far from the corner (for example x and z about 50 km), look out to sea, and take one picture. **Pass:** the swell looks the same as near the start, with no stepping or shimmer, and the shader error count is 0.
