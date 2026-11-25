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

## Trot and the clip for every state (23 Nov 2026)

Dave 23 Nov 2026: the animals looked "like really bad animatronics". Two causes on the client:

- **Gait.** Between the walk and the run there was nothing. A wolf backing off at 5 m/s played its walk clip at the 2.5 cap (3.75 m/s
  of legs) and slid. A row with a `trot` clip and a `trot_mps` now trots. With walk W, trot T and run R, the walk to trot switch sits
  10% either side of (W + T) / 2, and the trot to run switch sits 10% either side of (T + R) / 2. The trot clip's speed is measured from
  its feet like the walk and run (`feet move X m/s`). A row with no trot, or a trot speed not between its walk and run, walks or runs as
  before. 31 species and their looks have a trot.
- **Missing state clips.** A state with no clip fell back to role 0, the grazing clip. So a deer giving its warning (10) stood
  grazing, and a cow lying down (19) played Idle_to_Lying over and over. models.json now names a clip for the warning (10), lying (19)
  and drinking (21) where the file has one, plus the wolf's wind-up tell (6, AlarmBark). The fixes go into every look of a species,
  because a look's own `clips` replace the species' clips.
- **The clip list.** `data/animals/model_clips.json` lists every clip in every model file, with its length, read from the FBX without
  Godot (`python3 tools/model_clips.py --scan`). `python3 tools/model_clips.py`, which merge_check also runs, fails when models.json
  names a clip that is not in its file. It found the donkey's G0_Walk and G3_Gallop, which were not in the file, so the donkey played
  whatever clip the name search found.

**One-shot clips.** A model row may name a `bite`, `hit` and `die` clip. Each plays once, from a non-looping copy, so a looping role
that names the same clip keeps looping. While one plays (capped: hit 0.9 s, bite 1.2 s, death 2 s), the state's clip does not take
over; then the state's clip blends back.
- The hit plays when a blow lands (`flinch`), on a body slower than 1 m/s, or at any speed when the clip is a hit taken on the run
  (its name has "run": HitInRunHead_F, HitLegFL2RunFast).
- The bite plays when an attack state ends (a wolf's lunge 7, big game's charge 11). The plain wolf file has no bite clip, so only
  the second wolf look bites.
- A killed animal with a death clip falls where it is drawn and goes 0.3 s after the clip ends (2 s at most, as the carcass is
  already on the ground there); one without goes at once, as before. A lying animal (19) shows no standing hit.

**Idle life.** A model row may list `idle_variants`, keyed by role (for now only `"0"`, graze or stand): the model's own other idle
clips (look about, sniff, scratch, shake, sit). A grazing animal plays its own clip for 2 to 12 s first (so a herd does not move as one),
then one variant once through its own length (at least 1 s), then its own clip for 6 to 16 s, and so on. Moving, or any other state,
starts the next stop on its own clip again. Names are checked against `data/animals/model_clips.json` by `tools/model_clips.py`.
Test: `src/worldgen/tools/test_animal_idle.gd`.

## Head tracking (23 Nov 2026)

An animal turns its head to watch a player (`src/client/head_look.gd`, a SkeletonModifier3D on the model's skeleton, laid over
whatever clip plays). Client drawing only: the server still owns where the body is and which way it faces.
- Who: the nearest player's head (this player and every other player drawn). On watch (alert 3, wind-up 6, warn 10, recover 12,
  sneak 13, warn pop 16, or a drinker with its head up) within 30 m at full strength; calm (graze 0, lie 19) within 8 m at 0.6.
- Not while moving faster than 1.5 m/s, in an attack or charge, or while a one-shot clip plays: then the clip's own head shows.
- Limits: 70 degrees either side, 35 up, 30 down; a player further round than 110 degrees (behind the shoulder) is not watched.
  The head swings at about 170 degrees a second and starts or stops watching over 0.4 s.
- The neck bone (the head's parent, when its name has "neck") takes 40% of the turn and the head the rest. The turn is built in
  the body's frame and carried into each bone's parent frame, so no rig's bone axes need listing. A row with `"head_look": false`
  keeps its clip's head.
Test: `src/worldgen/tools/test_head_look.gd`.

## Server speeds the legs can play (23 Nov 2026)

A run clip plays at most `RATE_MAX` (2.5) times the speed it was made at. A species the server runs faster than that slides on its
legs. Lane A's slides at d937f0be5 found the elephant's only run clip at 2.46 m/s (legs top out at 6.2 m/s) under a flee of 10 and a
charge of 11 m/s: feet off on about 560 of 1,900 moving samples. Coordinator ruling (Dave's rule: real behaviour, no sliding; real
elephants top out near 7 m/s): elephant and mammoth flee at 6.0 m/s and charge at 6.5 m/s. Same ruling for the other kinds over
their clips' top: rat flees at 3.0 (clip 1.19), mink 5.2 (clip 2.09; its charge stays 5), guineafowl 6.3 (clip 2.52), horse 13.7 (clip
5.5). Left as they are: the dog's bloodhound look (clip 3.66 under a flee of 10, one look of two) and the duck (its 14 m/s is flight).

## How to confirm (Lane A)

- The creature check or the game log lists `feet move X m/s` or `feet measured X m/s, too far from the row's Y` for each walk and run.
  The lynx, guineafowl, kangaroo and rabbit lines should now be near their row speeds or rejected.
- Watch a fleeing deer, rabbit, lynx and elephant: the legs keep pace with the ground and the clip does not flick to idle.
- Creature check strips for the wolf, deer, cow, chamois and fox (`--kinds=wolf,deer,cow,chamois,fox`): the warn and lying roles show
  a standing, alert pose and a lying pose, not grazing. A wolf backing off after a bite trots.
- One-shots (play, not the creature check): spear a standing deer of the second look or a bear: it flinches with a hit clip. A bear's
  charge ends in a swipe or bite. A killed deer of the second look falls, then the carcass is left; it should read as the animal
  dropping onto its carcass, not as two bodies (if it reads as two, shorten DIE_MAX_S).
