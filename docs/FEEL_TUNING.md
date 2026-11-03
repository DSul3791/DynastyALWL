# First-person feel: what is tuned where

One place to find every number that shapes how movement, tools and hits feel. Change a number, restart, look. All of these are untested by a human until Dave has seen them in the window (2 Nov 2026), so expect to tune.

| Feel | File | Constant or function | Now |
|---|---|---|---|
| Walk bob (eye dip at each footfall) | `scenes/terrain_client/terrain_client.gd` | `BOB_M`, `SWAY_M`, `SWAY_DEG`, `STEP_M` (walk, jog, run) | 4 / 5.2 / 6.4 cm |
| Wider view at speed | same | `FOV_BASE`, `FOV_RUN_EXTRA` | 75, +5 degrees at a run |
| Swimming head bob | same, `_update_bob` | inline: 1.8 to 3 cm rise and fall, 0.5 to 1 degree roll | |
| Landing dip | `src/client/feel_kicks.gd` | `LAND_MIN_SPEED`, `LAND_DIP_M`, `LAND_MAX_M` | below 3 m/s none; up to 16 cm |
| Tool blow jolt | same | `STRIKE_DIP_M`, `STRIKE_ROLL_DEG` | 8 cm impulse, 0.5 degree roll |
| Hurt jolt (health drops by 2 or more) | same | `hurt()` | up to 12 cm, 2.5 degrees |
| Jump takeoff dip | same | `jump()` | 4 cm impulse |
| The spring itself | same | `STIFFNESS`, `DAMPING` | 190, 17 (slightly under damped, one soft overshoot) |
| Hit chips (wood or grit) | same | `chips()` | 10 pieces, 0.7 s |
| Hit stop (freeze at impact) | `src/client/held_item.gd` | `HIT_STOP_S` | 0.045 s |
| Swing timing and impact frame | `src/client/ragdoll_body.gd`, `held_item.gd` | `SWING_FP_S`, `HIT_AT` | 0.95 s, impact at 0.5 s |
| Sideways swing (trees, upright things) | `ragdoll_body.gd` | `_swing_fp` | |
| Overhead swing (ground, logs, stumps, rocks) | same | `_swing_fp_down`; chosen by `_aim_at_ground` in `held_item.gd` | |
| Arms at rest (out of view unless swinging) | `held_item.gd` | `REST_BACK_M`, `REST_DOWN_M`, `REST_PITCH_DEG`, `ARMS_POS` | 22 cm back |
| Arms spacing | `ragdoll_body.gd` | `ARMS_SPREAD` | 1.3 |
| Arm skin | `src/client/character/dynasty_arms.gd` | `SKIN_TEXTURE` (the file's texture with dark patches painted out) | |

## Turning the camera effects down or off
`user://input_settings.cfg` (the same file as auto pickup) takes `[feel]` `intensity = 0.0` to `1.5`. It scales the walking bob and sway and the landing, blow, hurt, jump, thud and gather kicks. 1.0 is as tuned, 0 is none. There is no menu entry yet. (The run FOV widening and the swimming bob are in the open PRs #173 and #231 and should follow this scale once they merge.)

## Known open items
- Axe hand grip: the hands are rigid (no finger bend), so how they sit on the handle needs a rig shot before the mount (`_build_mounts` in `ragdoll_body.gd`) is moved.
- All of the above need a windowed look; none has been run in Godot by the author.
