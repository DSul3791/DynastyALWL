# Posed states: a pose built from bones for a state the file has no clip for (MikeW, 8 Nov 2026)

Steve's bear threat ladder (#600) adds state 16, the jaw-pop. The brown bear's file has a fitting clip (`Attack_IdleAngry_01_Low`); the black bear's has none, so it would show only its warning pose. A model row's `state_poses` lays a pose over whatever clip plays in that state, in the same bone layer as the crow's posture, tails, ears, breathing and head tracking.

```
"state_poses": {"16": {"period_s": 0.45,
  "bones": {"Neck1": [12, 0, 0], "Head": [12, 0, 0], "Jaw": [18, 0, 0], "LegFL1": [-10, 0, 0]},
  "waves": {"Jaw": [0.0, 10, "x"], "LegFL1": [0.0, 14, "x"], "LegFL2": [0.1, 10, "x"], "Head": [0.25, 3, "x"]}}}
```
- `bones`: held turns (degrees, the bone's own axes): the black bear drops its head and neck, opens its jaw and lifts a forepaw.
- `waves`: repeating swings on top: the jaw pops open and shut, the forepaw stamps, the head jerks a little.
- The pose eases in and out over 0.25 s as the state starts and ends. The clip underneath is the warning clip (state 16 falls back to 10 when the row maps no "16" clip).
- Axes are a first guess: the creature check with `--roles` cannot show a state pose, so the check is the moving-frame session (or a `--state=16` option that sets the pose weight to 1 in a still strip).

Any other species can use it for a state its file lacks: a goblin's taunt, a cat's arched back, a dog's play bow.
