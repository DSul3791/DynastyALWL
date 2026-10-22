# Sound gaps: every action and what it sounds like

Written by the Sounds thread (job 61, 2026-10-20) from CONTROLS.md and the ACT_* kinds in `src/stream/terrain_net.gd`. Status: **done** (a real sound plays), **filled** (added in this pass), **open** (no sound yet, with the reason or the cheap fix). Re-check when an input or ACT kind is added.

| Action (key / ACT) | Sound | Status |
|---|---|---|
| Walk, jog, run | footsteps by ground, gait, gear; grass swish | done |
| Jump (Space) | push-off step (soft, like a step) | filled (build 243) |
| Land after a fall | heavy step | done |
| Fly toggle (G/F), fly | wind rush while flying | done (admin, no cue for the toggle) |
| Swim, dive, surface | splash, strokes, under hum | done |
| Crouch / sit / lie (C X Z, ACT_STANCE) | cloth rustle, rise, settle; softer crouched steps | done (build 238) |
| Inspect toggle (/) | ui on / off | done |
| Esc menu buttons | ui click | done |
| Quality F2 | chime | done |
| F3 debug, + / - spring volume, J jitter, Ctrl+Shift+G probe | none | open on purpose (admin tools) |
| Ctrl+X admin dig | dig sound by material | done |
| Hotbar 1 to 8 | tick | done (build 242) |
| I inventory open / close | pouch cues | done |
| Pick up item (E, ACT_PICKUP) | item_pickup | done |
| Drop (ACT_DROP) / throw item (ACT_THROW) | item_drop; spear throw whistle and hit | done |
| Move / split stacks (ACT_MOVE, ACT_SPLIT) | item_swap | done |
| Craft (ACT_CRAFT) | craft_start, per-recipe work sound, craft_done | done |
| Place fire / lean-to / chest (ACT_PLACE) | place cues | done |
| Take down a structure (hold E) | pick-up cue | done (no sound for the hold itself: open, cheap) |
| Chest open / put / take / close | creak, container clunks, screen cue | done |
| Chop tree (ACT_HIT) | axe on wood, creak, crash, stump chips | done |
| Mine bare rock (ACT_MINE) | axe on stone | done |
| Process felled trunk (ACT_PROCESS) | axe on wood | done |
| Chopping block (ACT_USE_STRUCT) | chop and plank sounds | done |
| Fuel / cook / light a fire (ACT_FUEL, ACT_COOK, ACT_LIGHT) | fuel, sizzle, light; loops and put-out | done |
| Eat / apply medicine (ACT_EAT) | crunch, soft, gulp, poultice, bandage | done |
| Hungry | stomach growl | done |
| Repair tool (ACT_REPAIR), tool breaks | repair and break cues | done |
| Harvest plant (E) | twist, pull, pluck, snap, snip plus rustle | done |
| Spear jab / aim / throw | jab; throw heave; (raise-to-aim has none) | done; aim raise open (cheap) |
| Swing an axe or pick in the air (miss) | none; only strikes sound | built (build 262): `hit_swing` whoosh on every swing |
| Held torch / lantern | flame loops | done |
| Exertion, over-exertion, faint, wake | breath, heart, heaves, world fade | done |
| Weather, wind, water, animals, bells | ambient layers | done |
| Rejected action (pack full, cannot place, no tool) | none | call point built (build 266): `sound.itemfx.reject(reason)`; waits for the server reject event (Items job 62) to call it |
| Stand up blocked by a low ceiling | none | open, rare |
| Walking into water from land (splash) | step_water / splash | done |
| Fall damage | none | open: no damage system yet |
