# Animal legs keep up with the ground (21 Nov 2026)

Dave, 21 Nov 2026: "they shouldn't be teleporting around or running without moving their feet or legs."

Code: `src/client/animal_gait.gd` (rules), `src/client/animal_view.gd` (`_process_body`, `_animate_model`, `_measure_stride`).
Test: `src/worldgen/tools/test_animal_gait.gd`. Client only: nothing sent changes, no protocol change.

## What was wrong

Evidence: Dave's own game log (21 Nov 2026), which prints each model's clips and the clip speeds the game measured.

1. **Some clips were measured at a fifth of their speed.** An in-place walk or run is played at `ground speed / clip speed`
   (`docs/design/FOOT_SLIDING.md`). The clip speed is measured from planted feet. Bones that never move (the root at the rig's
   feet, IK targets) also sit on the ground at zero speed and pulled the middle value down. The log showed the lynx walk at
   0.26 m/s (row 1.3), guineafowl run 0.20 (row 6), kangaroo walk 0.27 (row 1.0), rabbit hop 0.31 (row 1.5). The rate was then
   capped at 2, so these animals moved at 2.5 to 15 times the speed their legs showed: gliding with the legs barely moving.
2. **The speed was read fresh every frame.** It jumps at each sent point and drops to nothing on a late send, so the clip flicked
   between stand, walk and run and restarted its blend each time.
3. **A model with a walk but no run (or the other way) stood in its idle pose while it moved.**

The drawing of positions (teleporting between sent points) was fixed on 21 Nov by #1433 and #1454 (`src/client/motion_buffer.gd`).
Dave has not played those fixes yet.

## What changed

- A clip-speed measurement counts only bones that move over the clip. A measurement more than 3 times off the model row's own
  `walk_mps` / `run_mps` is not trusted: the row's speed is used, and the log says so.
- The ground speed is eased over 0.15 s. A standing animal starts walking above 0.45 m/s and a walking one stands below 0.25 m/s.
  The walk to run switch sits 10% either side of half way between the two clip speeds.
- The playing rate goes from 0.4 to 2.5 times (was 0.5 to 2).
- A moving animal with only one moving clip plays that one. Its feet still slide at the far end: a walk-only model running at 9 m/s
  plays its walk at the 2.5 cap. Only a real run clip fixes that. A model with no moving clip at all plays its idle clip at rate 1.
- Trade-off of the easing: after a hard stop from 10 m/s the legs run on for about half a second (0.15 s x ln(10 / 0.25)).
- A flock's footstep count goes up once a frame, not once for each bird.

## How to confirm (Lane A)

- The creature check or the game log lists `feet move X m/s` or `feet measured X m/s, too far from the row's Y` for each walk and run.
  The lynx, guineafowl, kangaroo and rabbit lines should now be near their row speeds or rejected.
- Watch a fleeing deer, rabbit, lynx and elephant: the legs keep pace with the ground and the clip does not flick to idle.
