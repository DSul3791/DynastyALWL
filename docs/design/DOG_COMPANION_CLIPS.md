# The dog companion: client clips (MikeW, 8 Nov 2026)

Client side of Steve's dog companion (#606, `dog_companion_design.md`). The server decides what the dog does; the client only needs a clip for each thing it can be seen doing. The dog is species 34 with two looks (labrador, bloodhound).

## States (agreed numbers, for Steve's server step)
| What the dog does | Wire state | Client clip (labrador) | Client clip (bloodhound) |
|---|---|---|---|
| stands by its owner, tail wagging | 0 (graze) | `idle_sniff_01` (the file has no tail-wag loop; a tail wag can be laid over with a `gait` on the tail bones later) | `Idle` |
| alert | 3 | `Idle` (head up) | `Idle` |
| follows its owner | walk / run by speed | `walk_fwd_01`, `run_fwd_01`; trot is the walk at speed (`trot_fwd_01` if a separate trot is wanted) | `walk fwd`, `run fwd` |
| barks a warning (bear, wolves, goblins within `warn_m`) | 10 (warn): the existing "threat" call carries the bark sound | `idle_bark_04_warning` | `Idle` (no bark clip) |
| **sits** (stay) | **18** (new) | `idle_sit_one_off_step_01` | the last 0.4 s of `idle to idle sit` held as a loop (`clip_loop`) |
| **lies down** (rests at night or a long stay) | **19** (new) | `idle_lay_one_off_01` | the last 0.4 s of `idle to idle lay` held as a loop |
| sleeps | 19 at night (same clip; `interact_bed_sleep_exist_01` later) | | |

States 13 to 17 are taken (thief, flock, jaw-pop, glide). 18 and 19 are free; Steve's server sends them when the dog stays (sit) or rests (lie). A client that does not know them draws the graze clip (role fallback), so the numbers are safe before the server sends them.

## Data
In `models.json` the dog row's clips gain `"10"`, `"18"`, `"19"`; the bloodhound look gets `"18"`, `"19"` and a `clip_loop` for both. No code change: `_animate_model` already plays `clips[str(state)]` and walk/run by speed.

## Check
`creature_check --kinds=dog --roles=...` and `--id=1`, then Dave's PC picture of a dog sitting and lying (with Steve's step 2).
