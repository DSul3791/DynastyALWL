# Robot play-testers

**Status: test tooling, 23 Nov 2026.** Why: build 9257's first hour on Dave's server, with his friends over the internet, found faults every
one-machine test had missed (animals teleporting and passing through players, another player's held spear floating, crouch-walking blocked
under trees, the pack not updating after a queued craft). The robots play the first hours the way a new player does, over a simulated
internet link, and check what they see against what the server believes.

## Run
```
tools/robots.sh                    # 3 robots, plan first_hours, 60 ms +- 25 ms each way, 2% loss; about 10 minutes on 4 CPUs (both passes)
tools/robots.sh 2 first_hours --delay-ms 75 --jitter-ms 30 --loss 0.03
tools/robots.sh 2 watch --delay-ms 120 --jitter-ms 30 --loss 0.03   # one robot draws another; robot_watch.py prints PASS/FAIL; about 3 min
tools/robots.sh 2 wolves_alone     # the wolf battle ring: one robot with raw meat far from town, an admin pack; about 3 min
tools/robots.sh 2 wolves           # the same, and the second robot comes in 3 s into the rush
python3 tools/robot_check.py /tmp/robots_XXXX     # read a finished run's logs again
python3 tools/test_robot_tools.py                 # the Python tools' self-test (no Godot)
```
Needs `godot` (the voxel-tools build) and python3. Where Godot may run follows `ai-team/TEST_GATES.md` and the coordinator: cloud Godot runs only under Dave's 22 Nov 2026 permission (to Wed 25 Nov 2026, recipe in the coordinator's CLOUD_TESTS.md); otherwise Lane B. Never Dave's PC while he plays. Exit 0 = every invariant held, 1 = a finding, 2 = the run broke.

## Pieces
| File | What it does |
|---|---|
| `tools/lossy_link.py` | UDP and TCP relay in front of the server: delay, jitter and loss each way (the block line too, through the client's test flag `--block-port=`). Standard library only. |
| `src/client/robot_play.gd` | The real client, headless, driven by key presses (`--robot=NAME`, `--robot-plan=`, `--robot-admin`). Prints `ROBOT` lines. |
| `src/server/robot_audit.gd` (with `src/shared/robot_rules.gd`, the pack signature both sides print) | Server flag `--robot-audit`: prints the server's pack signature per player, refusals sent, animals that jump (measured over the animal's own step time, with the looks around it) or stand inside a player, wolf pack phases, and every melee blow at an animal with what it struck at the judged moment. Prints `AUDIT` lines. No protocol change. |
| `tools/robots.sh` | Server, link, the robots at one spawn (so they meet the same animals and see each other), then a rejoin pass. |
| `tools/robot_watch.py` | Plan `watch` only: per leg of the walker, the fastest drawn speed over 50 ms against its real speed (above 1.5x fails), stalls, overshoot and settle at the stop; held item at a hand mount; swing clip within 1 s; asleep bit. |
| `tools/robot_check.py` | Reads the logs and fails the run on a broken invariant. `tools/robot_known_errors.txt` lists engine ERROR lines allowed (only the leak notice at exit). |

## The plan a robot plays (first_hours)
Join; given 45 plant fibre, 14 sticks and 10 stones (admin, local server only); queue and craft twine x12, stone axe, stone hammer, wooden
spear, stone spear, snare, stone knife; drop a stick and pick it up; walk each way standing and crouched; walk to the thickest trees within
150 m and crouch from trunk to trunk; spear in hand, hunt a rabbit, a deer and a wolf in turn, every robot on the same animal (the lowest id
within 120 m; with none of those near, the nearest other wild ground animal), striking with the screen time a player's blow carries (protocol
155), and print one `HUNT` line per fight (strikes, hits, its health share, down or up, the robot's health before and after); build a wicker
basket (knife), put twine in and take it out; eat wild apples and drink at the nearest water; made tired (admin energy 40), lie down, sleep
(the server must say asleep), wake; queue a craft and quit mid-craft. Then rejoin (plan `rejoin`): the pack came back, and the mid-craft quit
lost nothing (fibre plus 3 x twine the same). Every robot also prints `POSE` (its stance, place, speed) and `SEES` (each other player as
drawn: stance, place, clip) twice a second; robot_check.py compares them (wrong stance or clip held 2 s, drawn over 1.5 m off its track).

Plan `watch`: Robot 1 walks and runs six legs with the axe in hand, swings three times, sleeps; Robot 2 logs how it draws Robot 1 every frame.
Plan `wolves` / `wolves_alone`: Robot 1 runs about 380 m out of town (beyond the packs' town_keep_m) with 3 raw meat, an admin pack is placed
25 m off, and the robot is given a spear only once the rush starts (a spear on the hotbar keeps a pack off, by design). It prints one `WOLVES`
line (outcome, bites and the gaps between them, strikes, hits on wolves, most wolves within 3 m, health); the server prints each pack's phase
(`AUDIT wolfpack`); each jab prints a `JAB` line (the animals drawn within 6 m) beside the server's `AUDIT strike`. No rejoin pass follows
watch or the wolf plans. Plan `light` (walk,
stances, forest, watch) builds, drops and takes nothing, for a live server; it still makes a character record there that real players see, so a live run needs the coordinator's OK first and robots named as robots. On a live server there is no `--robot-audit` server log, so only the robots' own ROBOT lines can be read (robot_check.py needs the AUDIT lines and reports such a run as broken).

## Invariants
- **pack**: after every action, once quiet, the client's pack equals the server's (`CHECK pack` against `AUDIT pack`).
- **craft / pickup**: a finished craft is in the pack; a dropped item shows in the world and comes back when picked up.
- **jump**: no drawn animal or player moves farther in one frame than its top speed allows (client); no animal steps farther than its top
  speed allows (server).
- **inside**: no animal's middle inside a player's capsule (client and server).
- **held**: a remote player's held item hangs on its right hand mount, and the mount stays within 0.25 m of the hand bone (it sits about 0.11 m off it); a run where robots played together and none measured a held item fails too.
- **blocked**: keys held crouched and no movement where standing at the same spot moves freely.
- **rejoin**: the pack after quit and rejoin is the pack at quit.
- **refusals**: each refusal is listed as a NOTE, with or without words (many are a sound only, by design).
- **hunt**: a fight of 10 or more strikes with no hit is a finding (each fight is listed either way).
- **others**: each robot's view of another (`SEES`) is on the path that one walked (its `POSE` lines) within 1.5 m, in the stance it held for 2 s and with a clip of that stance, four misses or more is a finding; robots that played together with no view matched fail too.
- **watch** (plan watch, robot_watch.py): jumps over 1.5x the walker's speed, stalls, overshoot, settle, held item, swing, sleep, and at least 4 of the 6 legs measured.
- **exit**: every robot client exits 0 (an abort or a timeout is a finding).
- **errors**: no SCRIPT ERROR (or unlisted engine ERROR) in any log; every robot joined and finished.

## Where it fits (an unapproved proposal for the coordinator; the gate rules are only those in `ai-team/TEST_GATES.md`)
About 10 minutes on 4 CPUs, no GPU, so it never needs Dave's PC: Lane B, or the cloud while Dave's cloud permission lasts. Proposed, not
adopted: a main gate job beside the server smokes on the exact candidate, and a change-plan extra for PRs touching `src/stream`,
`src/client/animal_view.gd`, `src/client/player_view.gd`, `src/client/motion_buffer.gd`, `src/server`, the movement code in
`terrain_client.gd` or the pack screens. A finding goes to the coordinator like any other fault, with the robot's line (what, where, how to
reproduce).
