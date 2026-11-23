# Robot play-testers

**Status: test tooling, 23 Nov 2026.** Why: build 9257's first hour on Dave's server, with his friends over the internet, found faults every
one-machine test had missed (animals teleporting and passing through players, another player's held spear floating, crouch-walking blocked
under trees, the pack not updating after a queued craft). The robots play the first hours the way a new player does, over a simulated
internet link, and check what they see against what the server believes.

## Run
```
tools/robots.sh                    # 3 robots, plan first_hours, 60 ms +- 25 ms each way, 2% loss; about 7 minutes in the cloud
tools/robots.sh 2 first_hours --delay-ms 75 --jitter-ms 30 --loss 0.03
python3 tools/robot_check.py /tmp/robots_XXXX     # read a finished run's logs again
python3 tools/test_robot_tools.py                 # the Python tools' self-test (no Godot)
```
Needs `godot` (the voxel build, see the cloud recipe) and python3. Exit 0 = every invariant held, 1 = a finding, 2 = the run broke.

## Pieces
| File | What it does |
|---|---|
| `tools/lossy_link.py` | UDP and TCP relay in front of the server: delay, jitter and loss each way (the block line too, through the client's test flag `--block-port=`). Standard library only. |
| `src/client/robot_play.gd` | The real client, headless, driven by key presses (`--robot=NAME`, `--robot-plan=`, `--robot-admin`). Prints `ROBOT` lines. |
| `src/server/robot_audit.gd` | Server flag `--robot-audit`: prints the server's pack signature per player, refusals sent, animals that jump or stand inside a player. Prints `AUDIT` lines. No protocol change. |
| `tools/robots.sh` | Server, link, the robots at one spawn (so they meet the same animals and see each other), then a rejoin pass. |
| `tools/robot_check.py` | Reads the logs and fails the run on a broken invariant. `tools/robot_known_errors.txt` lists engine ERROR lines allowed (none yet). |

## The plan a robot plays (first_hours)
Join; given 45 plant fibre, 14 sticks and 10 stones (admin, local server only); queue and craft twine x12, stone axe, stone hammer, wooden
spear, stone spear, snare, stone knife; drop a stick and pick it up; walk each way standing and crouched; walk to the thickest trees within
150 m and crouch from trunk to trunk; spear in hand, chase the nearest ground game (rabbit, deer, wolf first) and strike, with the other
robots after the same animal; lie down, sleep, wake; quit. Then rejoin (plan `rejoin`) and check the pack came back. Plan `light` (walk,
stances, forest, watch) changes nothing in the world, for a live server.

## Invariants
- **pack**: after every action, once quiet, the client's pack equals the server's (`CHECK pack` against `AUDIT pack`).
- **craft / pickup**: a finished craft is in the pack; a dropped item shows in the world and comes back when picked up.
- **jump**: no drawn animal or player moves farther in one frame than its top speed allows (client); no animal steps farther than its top
  speed allows (server).
- **inside**: no animal's middle inside a player's capsule (client and server).
- **held**: a remote player's held item stays within 0.35 m of its right hand bone.
- **blocked**: keys held crouched and no movement where standing at the same spot moves freely.
- **refusal**: no server refusal without a message to the player.
- **rejoin**: the pack after quit and rejoin is the pack at quit.
- **errors**: no SCRIPT ERROR (or unlisted engine ERROR) in any log; every robot joined and finished.

## Where it fits (proposal for the coordinator; the gate rules themselves are in `ai-team/TEST_GATES.md`)
About 7 minutes on 4 CPUs, no GPU: a cloud job (until the cloud runs end) or Lane B, never Dave's PC. Proposed as a main gate job beside
the server smokes, on the exact candidate, and as a change-plan extra for PRs touching `src/stream`, `src/client/animal_view.gd`,
`src/client/player_view.gd`, `src/client/motion_buffer.gd`, `src/server`, the movement code in `terrain_client.gd` or the pack screens.
A finding is filed with the coordinator like any other fault, with the robot's line (what, where, how to reproduce).
