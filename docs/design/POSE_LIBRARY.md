# The pose library (MikeW, 8 Nov 2026)

Dave's preference: rigged models fixed by posing the skeleton in code. Many bought or Meshy models have no clip for some of the
states the server sends (sit, lie, hunch, drink) or the looks need (sleep, groom). `src/client/pose_library.gd` (`PoseLib`) holds one
table of poses by **body part**, and resolves the parts on each rig to its own bones, so one table serves every family. Behind
`pose_lib` (off); with it on, every state below that a row has **neither a clip nor its own `state_poses` entry** for gets the
library's pose (the row's own clip or pose always wins).

## States (Steve's numbers, exactly)
| Key | State | Pose |
|---|---|---|
| 3 | ALERT | alert |
| 18 | sit (dog companion) | sit |
| 19 | lie (dog companion) | lie |
| 20 | HUNCH (#646, in cover #701) | hunch |
| 21 | DRINK (Steve #734: deer and stock at fresh water at dawn and dusk, 1 to 3 minutes facing it) | drink |
| -1 | sleep (the client's own sleep key, POSED_STATES.md) | sleep |
| (idle) | groom | groom (for the idle table) |
| -40 | (client) the fall on bare ice | splay: Jamie #736, a deer down on all fours, legs out; rows with legs, with `ice_looks` |

## The poses (degrees about the row's `pose_axis`, default x, times `pose_sign`; blend time to reach them)
| Pose | Neck (shared) | Head | Spine (each) | Front legs (upper, lower x -1.2) | Hind legs | Turn | Blend s |
|---|---|---|---|---|---|---|---|
| alert | -8 (up) | +4 | | | | | 0.25 |
| hunch | +12 | -4 | +4 | | | | 0.8 |
| drink | +22 (down to the water) | -10 | | -6 | | | 0.6 |
| sleep | +25 | -6 | +6 | -45 (folded) | +45 | | 1.5 |
| lie | +6 | -2 | | -60 | +60 | | 1.0 |
| sit | -6 | | -10 | | +55 | | 0.8 |
| groom | +10 | +8 | | | | neck +25, head +15 about y | 0.5 |
| splay (the fall on bare ice, client key -40) | -4 | +6 | | -10, and each upper bone 35 out sideways about z | +10, and 35 out sideways | | 0.15 |
The neck angle is shared out along the neck bones (twice the angle over their count each), so a long neck bends smoothly.

## Rig families and their parts
The parts come from what the rows already name, so no bone list is repeated:
| Family | Rows | Neck and head (the row's `look` bones) | Legs (the row's `feet` chains: front first) | Spine (bone names with "spine") | Axis |
|---|---|---|---|---|---|
| deer-like (WildMesh) | deer, moose, wolf, fox | Neck1, Neck2, Neck3, Head | LegFL1/2, LegFR1/2, LegBL1/2, LegBR1/2 (deer) | Spine1, Spine2 | x |
| "Rig" prefix | elk, bear | RigNeck1..3, RigHead | (none yet) | the rig's spine bones | x |
| stock (UE-style) | horse, donkey | neck_02..04, head | upperarm, lowerarm, upperleg, lowerleg (horse) | spine_0x | x |
| biped-style (3ds Max Bip001) | cow, buffalo | Bip001-Neck, Neck1, Neck2, Bip001-Head | Bip001-L/R-UpperArm, Forearm, Thigh, Calf (cow) | Bip001-Spine | to check (`pose_axis`) |
| goat-like | goat | NeckBase, Neck_01, Neck_02, Head | (none yet) | the rig's spine | x |
| boar | boar, warthog | (no look row yet: add one to pose the head) | (none) | | x |
| bird | crow, Meshy birds | (look rows to add) | wings: BIRD_FLIGHT.md part 3 (perch fold) | | z for the wings |
A family with no neck or legs in its row gets only the parts it has (a bear with no feet row gets the neck, head and spine of
"lie", not the legs); a pose with none of its parts is skipped and the clip plays as before. A rig whose axis differs (the Bip001
cow) is corrected per row with `pose_axis` and `pose_sign`, as the Dino strip shows.

## How the looks call it
- At model build: `PoseLib.parts(skeleton, row)` and `PoseLib.build(pose, parts, row)` for each state above; registered as state poses
  on the bone layer, with their blend times in `pose_blend` (bone_offsets.gd).
- Each frame the posed block takes the state as its pose key, as for every state pose; drinking at a bank (water_life's spot, or
  Steve's state 21) takes the drink pose; the blend time is the library's.
- Logged per model: `pose library: [keys]`.

## The fall on bare ice (with `ice_looks`, Jamie #736)
A deer (any kind not sure-footed on ice) running on bare ice falls about once in three running strides and stays down splayed for 2 to
4 s: the splay pose, the body lowered 35 percent of its height, the legs still; then it gets up. On snowy ice, never. Without the pose
library, pr22's slips only.

## Check
Run sheet m58 (deer, horse and cow in states 20, 21 and 19 with `--poselib`: heads low for 20 and 21, legs folded for 19 where the
row has feet), m59 (a deer running on bare ice with `--poselib --ice`: down splayed in some frames) and DINO_SHOTS.md.
