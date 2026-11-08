# Foot sliding: walk and run clips played at the speed their feet were made for (MikeW, 8 Nov 2026)

**Problem.** The server moves an animal at its row's speed (walk_mps, flee_mps). The client plays the walk or run clip and scales its rate by `speed / ref`. If `ref` is not the speed the clip's feet actually move at, the feet slide over the ground (too slow a clip: the body glides; too fast: it moonwalks). Until now `ref` was the model row's `walk_mps` and `run_mps`, typed by hand, except for clips with root motion.

## How the clip's own speed is found
1. **Clips that travel (root motion).** Already done (#538): the travel on the root or `RigRoot` is taken out and kept as the clip's `travel_mps` (bear walk 0.8, run 6.1, sprint 10.4 m/s).
2. **In-place clips (new).** In an in-place walk the body stays still and a planted foot slides backward at exactly the ground speed. `_measure_stride` samples every bone 40 times over the clip in the rig's space (metres: the model's size scale is in it), takes the lowest point the clip reaches as the ground, treats a bone within 3% of the standing height of that as planted, and keeps the middle horizontal speed of planted bones between neighbouring samples. That is the clip's `travel_mps`.
3. Neither works (a hop with no planted frames, a broken clip): the row's `walk_mps` / `run_mps` stay as before.

## How it is used
`_animate_model` already plays a walk or run at `speed_scale = clamp(speed / travel_mps, 0.5, 2.0)`. With a measured `travel_mps` the feet keep pace with the ground at every speed inside that band. Outside it (an animal fleeing far faster than its run clip was made for) the clip runs at twice its rate and the feet slide a little; the fix there is a faster clip in the row, not a bigger clamp.

The measurement runs once per clip when the model is built (40 samples of the skeleton, in GDScript), and a log line says what it found, so `tools/creature_check.gd` shows every species' numbers.

## How we confirm it
- **Numbers:** the creature check report lists `feet move X m/s` for every in-place walk and run. Check them against the species (a fox walk about 1 to 1.5 m/s, a deer run 8 to 12 m/s); a number far off means the planted-foot test failed for that rig.
- **Dino's bear frame pair:** two frames of a walking bear in the live game, a known time apart (for example 0.25 s), from the side. A planted paw must be at the same ground spot in both frames (within a few centimetres) while the body has moved on by `speed × time`. The bear's clips have root motion, so it checks path 1; one in-place animal (fox or deer) checks path 2 the same way.
- **Regression:** the animal tests are server-only and do not change.

## Not in scope
Turning on the spot (no clip), and blending walk to run across the speed range: the clip switches at the halfway speed as before.
