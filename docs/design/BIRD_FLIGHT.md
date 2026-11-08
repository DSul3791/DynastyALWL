# Birds in flight on the client (MikeW, 8 Nov 2026; built on the life layer)

Follows FLIGHT_RIGS.md for the birds we have. The server decides when a bird is in the air (state 15: the duck and gull flocks today; single birds when the server flight states land); the client makes it look like flight.

**Built (row `flight`):**
- **Take-off:** the row's take-off clip plays once as the bird enters the air (goose `TakeOff_RunUp`, pheasant and guineafowl `TakeOf_BounceOff`, crow `FlyUp`).
- **Flap and glide in turns:** `flap_s` seconds of flapping, then `glide_s` of gliding, repeating; the flap clip runs at the species' **wingbeat** (`beat_hz`: pheasant 9, guineafowl 8, duck 5, crow 4, goose 3), the glide at its own rate.
- **Flap-bounce:** small birds (`bob_m` 2 to 4 cm: duck, pheasant, guineafowl, crow) bob with each beat.
- **Landing flare:** the landing clip plays once as the bird comes down (`Landing_Touch`), then the ground clips take over (the perch settle is the end of that clip).
- Rows: duck, goose, pheasant, guineafowl, crow.

**Soar circles** (eagle, raven): a path, so it belongs to the server (FLIGHT_RIGS.md section 2, `soar_m`); the client's part is the long `glide_s` in the eagle's prepared row.

**Prepared rows** for the eagle, raven and owl: `data/animals/pending_models.json` (not read by the game) with every key filled except the clip names, which come from the files when Dave's models arrive.

**Check:** `creature_motion --kinds=goose,pheasant --state=15 --frames=8 --every=0.3` (take-off then flap and glide), and the duck flock taking off in the live game.

## Part 2: single birds in flight (Steve's #653, server design 5b60ee80)

The server will fly single birds by time-based segments (flushers: pheasant, grouse, guineafowl; perchers: crow; soarers: eagle,
raven). The client side, on the life layer:
- **State 17 gliding** is in `AIR_STATES` with 15. A bird sent 17 plays its row's glide clip; once a bird has been sent 17, its 15
  always means flapping (the server decides the glide). Flocks that never send 17 keep the timed flap and glide turns.
- **Take-off and landing** already play once on entering 15 or 17 from the ground and on coming back to 0 (part 1).
- **Perched:** state 0 at a height is a bird on a branch or crag; the position carries the height, nothing more to do.
- **Banking** (flag `flight_bank`, off): the bank comes from the heading's turn rate (0.6 x rad/s, at most 45 degrees), eased, on the
  Rig's roll; level again once down.
- **Raven roll:** `play_roll(id, turns)` plays a half (0.5) or full (1.0) roll over 1 s on top of the bank; a second event inside
  that second (rolls come in pairs) queues behind it. The protocol handler calls it when Steve's roll event arrives (wire format in
  his server_flight step 2).
- Check: run sheet m28 (crow and pheasant turning at 0.8 rad/s, the crow rolling).


## Part 3: birds and bats posed from their skeletons (flag `bird_rig`, for Dave's Meshy eagle, raven, owl and bat)

Dave prefers rigged models fixed by posing the skeleton in code. A Meshy bird may come with a good skeleton and few or no clips, so
the flight is built from its own wing bones, the way MODEL_QUIRKS.md's posed states are. Nothing happens until such a model arrives:
the code runs only for a row that asks for it (`posed_flight: true`, set in the four pending rows) or whose `flight.flap` names no
clip; the ducks, geese, pheasants and crows keep their bought clips.

**Bones the code looks for** (any naming; the row's `wing_bones` {l_up, l_fore, l_hand, r_up, r_fore, r_hand} wins, else the first bone
whose lower-case name holds a side word and a part word):
| Part | Side words | Part words |
|---|---|---|
| upper wing (humerus) | left, _l, .l, l_, lft / right, _r, .r, r_, rgt | upperarm, humerus, wing1, wing_01, shoulder, arm (not fore or lower) |
| fore wing (ulna) | as above | forearm, lowerarm, ulna, wing2, wing_02, elbow |
| hand (wrist, primaries) | as above | hand, wrist, wing3, wing_03, finger, tip |

The head and neck for the owl's turn come from the row's `look` bones (HEAD_TRACKING.md), as for every other animal.

**The poses** (bone_offsets.gd state poses, mirrored left and right about the row's `wing_axis`, default z):
| State | Pose | Numbers (row keys) |
|---|---|---|
| 15 flapping | the three bones beat at `flight.beat_hz`, fore and hand lagging (0.12 and 0.22 of a beat), 60 and 40 percent of the swing | `wing_swing_deg`: eagle 35, raven 45, owl 40, bat 60 |
| 17 gliding | the wings held out level, the hands swept back a little | `glide_deg`: eagle 8, raven 10, owl 12, bat 5 |
| 18 sitting, and 0 at rest | folded against the body | `fold_deg`: eagle 70, raven 65, owl 70, bat 85 (wrapped) |
| landing (-20) | wings up and forward for 0.6 s as it comes down from 15 or 17 | 0.9 of the swing |

**Wingbeat by species** (`flight.beat_hz`): golden eagle 2 (long glides between), raven 3.5, owl 2.5 (slow and silent), bat 10 (a
flutter; the colony's swarm jitter, `swarm_fx`, adds the jinks), crow 4, duck 5, pheasant 9 (whirring), as in part 1.

**Banking** is part 2's `flight_bank` (the Rig, through `LifeUtil.rig`), and the raven's roll its `play_roll`; they work on posed and
clipped birds alike. **The owl's head turn** is its `look` row (max 120 degrees, track mode, 25 m).

**Fallback:** with no wing bones found there is a note in the log (`posed flight: no wing bones found`), and the bird keeps whatever
clips it has and the flap bob; a bird with only one side found is not posed (it would fly lopsided). The axis or sign may be wrong
for a given rig: the Dino strip shows it at once, and the row's `wing_axis` or a negative `wing_swing_deg` fixes it without code.

Check: run sheet m49 (the crow posed from its own bones with `--birdrig --posed`, as a stand-in until a Meshy bird arrives), and
DINO_SHOTS.md.
