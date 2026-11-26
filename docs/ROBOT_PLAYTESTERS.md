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
ROBOT_S=540 tools/robots.sh 1 snares   # snares on a game trail, beside it, along it and off it; the server prints each one's trail share
ROBOT_BODIES=deer,goose ROBOT_S=120 tools/robots.sh 1 bodies   # a dead body of each kind placed ahead and looked at with inspection on: each must be named "Dead <animal>" (pictures: the client on a real renderer with --robot-admin --robot-plan=bodies)
ROBOT_S=300 tools/robots.sh 3 bear # an admin bear 20 m from the spawn, every robot hunts it with a spear (inside and jump checks); about 4 min
ROBOT_S=200 tools/robots.sh 3 bear_group   # the hunters stand in a tight group (pairs about 1 m apart) and jab a bear set 2 m off
ROBOT_S=200 tools/robots.sh 1 fight_goblin   # (or fight_bandit) every warning, charge and landed blow as the robot drew it; AUDIT enemy_hit on the server
ROBOT_S=400 tools/robots.sh 1 cold # a hard frost (the audit's server_control.txt): down to 1 health, pass out, wake at a rescue spot; then the 1-health floor under a goblin's blows
tools/robots.sh 1 drops            # the link dies mid-action and the robot comes straight back; a 10 s freeze; two clients as one character; about 15 min
python3 tools/robot_check.py /tmp/robots_XXXX     # read a finished run's logs again
python3 tools/test_robot_tools.py                 # the Python tools' self-test (no Godot)
```
Needs `godot` (the voxel-tools build) and python3. Where Godot may run follows `ai-team/TEST_GATES.md` and the coordinator: cloud Godot runs only under Dave's 22 Nov 2026 permission (to Wed 25 Nov 2026, recipe in the coordinator's CLOUD_TESTS.md); otherwise Lane B. Never Dave's PC while he plays. Exit 0 = every invariant held, 1 = a finding, 2 = the run broke. Each robot gets its own user data folder in the run folder (its character): XDG_DATA_HOME on Linux, APPDATA on Windows (Git Bash or MSYS bash, converted with cygpath), so robots on one machine never share a character.

## Pieces
| File | What it does |
|---|---|
| `tools/lossy_link.py` | UDP and TCP relay in front of the server: delay, jitter and loss each way (the block line too, through the client's test flag `--block-port=`). Standard library only. |
| `src/client/robot_play.gd` | The real client, headless, driven by key presses (`--robot=NAME`, `--robot-plan=`, `--robot-admin`). Prints `ROBOT` lines. |
| `src/server/robot_audit.gd` (with `src/shared/robot_rules.gd`, the pack signature both sides print) | Server flag `--robot-audit`: prints the server's pack signature per player, refusals sent, animals that jump (measured over the animal's own step time, with the looks around it) or stand inside a player, wolf pack phases, every melee blow at an animal with what it struck at the judged moment, every goblin, bandit or big game blow at a player (`AUDIT enemy_hit`), snares with their trail share, and the robot control commands (`AUDIT control`, plan cold: the only place it changes the game). Prints `AUDIT` lines. No protocol change. |
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
watch or the wolf plans.

Plan `snares`: given 7 snares, the robot runs to the nearest dry game-trail point the client was sent (trail_signs.routes), sets a snare on
it and four more along trails within 80 m, one 4 m beside the first (no second Tracking practice within 15 m), and one 40 m from every
trail; then waits 150 s 20 m off for a catch. Each set prints a `SNARE` line (set or not, Tracking trained or not, any words), and the
server an `AUDIT snare` line with its trail share (server_traps trail_at; a catch needs on_trail_min 0.1, practice snare_min 0.5). A
snare that neither appears nor is refused in words fails, so does a second practice beside the first or one off every trail. 

Plan `drops` (one robot, players thread 23 Nov 2026): for each case the robot sets up an action (6 twine queued; a wicker basket open with 2
twine put in; asleep; bitten once in a wolf rush 380 m out), saves what must come back, and writes "cut" to the link's control file
(`lossy_link.py --control`): every connection open then goes dead both ways with no goodbye, as when a player's internet drops. robots.sh
starts the same robot again at once (`drop_back`), while the server may still hold the dead connection: it must get in (else a FAIL, and one
more try after 35 s), and find the fibre-plus-twine worth, the pack, the basket (opens, still 2 twine) and a body that stands and walks.
`drop_freeze` stalls the client's main thread 10 s while walking: being dropped for it is a FAIL (the main gate allows a 24.85 s freeze), and
the pack must not change. `drop_twin1`/`drop_twin2`: a second client joins with the same user data (the same character) 30 s after the
first; the server must drop the older one (terrain_server.gd "the older connection is dropped") within 20 s. No rejoin pass follows.

Plan `cold` (one robot; robots.sh forces it): the server's robot audit (only with `--robot-audit`) reads `server_control.txt` in
ROBOT_SHARE: `cold <peer>` turns the weather (weather_now and weather_at, which the warmth reads, for the whole test server) to -25 C with
wind and starts that peer at health 6, warmth 15; `warm <peer>` gives the world's own weather back; `health <peer> <value>` sets health
(at least 1). Each is printed as `AUDIT control`. The robot stands in the frost and must never read health 0 or die, pass out with words,
be moved to a rescue spot (the client gets died "passed out", no death), wake with the traveler's words and health 10 or more, keep every
item and walk after. Then, warm again and 60 m out of town at health 1, it fights a goblin for 40 s: at least one blow must land (the
server's `AUDIT enemy_hit`, result "maimed" at low health), health must read 1 and stay there, no death. No goblin, no blow or no server
log is a FAIL: the floor was not tested.

Plans `fight_goblin` / `fight_bandit`: the shield goes up at the drawn warning on odd charges (sent as the held_item RPC: headless cannot
capture the mouse) and is lowered if the warning never becomes a charge; even charges are a side-step (every other one at run speed). Each
blow prints `ENEMY hit|miss` (warning lead, gap, dodge, shield, facing); the server prints `AUDIT enemy_hit` with its own gap and shield.

Plan `goals` (one robot, Dave 25 Nov 2026 "try to improve the goals playthrough"; `ROBOT_S=2700 ROBOT_GOALS_S=2450 tools/robots.sh 1 goals`,
about 45 minutes; `src/client/robot_goals.gd`): a fresh character with no gifts plays the starter goal book in order, as a player would: it aims
(body yaw and camera pitch) and presses E to gather and drink, left-clicks the axe at trees, bushes and rocks, crafts through the craft queue, places
blueprints and hammers them, lights a campfire, treads a path with the hoe and sells to Hob (closing his shop window after). Each goal prints
`GOAL <id> try|done|stuck`, with GATHER, MADE, FELL, ROCK, BUSHES, BUILT, PATH, SOLD and DROPPED lines on the way, and a WEIGHT line (each item's
real kg, heaviest first) after a goal where the game said "Too heavy". It hunts with a spear (a rabbit, then a deer; with none by the camp it walks
out up to four 300 m legs and chases again) and works the carcass with the knife (HUNT, HUNTWALK, CARCASS lines). When gathering or sweeping up it never presses E on a "talk" prompt, and shuts a talk that opens anyway. For copper it walks up any river its own map shows, else widening loops round the camp, for up to 15 minutes
(EXPLORE lines). It digs clay with the Wooden - Shovel: one dig 1.8 m ahead, a step 1.8 m sideways, so the holes lie side by side;
a row starts 12 m out from the camp and the next one another way and 25 m further when the ground gives no clay (CLAY lines). For charcoal it keeps firewood or a log burning in its camp fire, takes the charcoal out of the fire's store and
comes back when the rest should have burned (one about every 400 s; a log leaves 27, a firewood 3; CHARCOAL lines). A
visit that ends waiting is not one of the goal's two tries (at most 5 visits). Four charcoal from a cold fire take about 27 minutes,
so the goal passes only when the fire was lit early enough in the run. A goal it cannot play yet says "robot cannot" (fish, snare, order, story and others); any other stuck goal is a FAIL line to read: game fault or robot gap, checked against the real numbers before it goes on the bug list.
Between goals it drops what a player would leave behind (logs, seed stacks, spare food over 10, straw and reeds over 20, sticks over 40).

Plan `kind_<species>` (two robots, animal thread 23 Nov 2026; `ROBOT_S=260 tools/robots.sh 2 kind_moose --delay-ms 120 --jitter-ms 30
--loss 0.03`, any species name in data/animals/animals.json; a wolf is a pack: `kind_wolf` is one robot with `ROBOT_S=360`, run 380 m out of town and
unarmed until bitten, since a pack keeps off the town, a player with a spear and a player with another within 10 m): Robot 1 places one 15 m ahead and both hunt it with spears,
two rounds of 70 s (in a round they hunt one after another of the kind until its time is used). Each robot prints a KIND line (the largest
drawn step a frame against the kind's top speed, steps over 1 m, frames drawn inside the other robot; steps in the second after a frame over
250 ms are a freeze's catch-up: up to the run the frozen time allows they count as after_freeze, beyond it they still fail;
every plan's CATCHUP line gives the count), a SLIDE line (feet against ground: only with the bought models, so on Lane A, `LANE_A_SLIDES.md` in project files;
cloud clones leave the models out), A lines every 100 ms (each drawn body of the kind) and P lines (itself), and BITTEN at each health drop.
`python3 tools/robot_kinds.py <run folder>` prints the measures: jumps, slides, shoved (the robot's own body faster than a player runs over
half-second windows), agree (the two clients' drawn places of the same animal at the same moment), each server blow (`AUDIT enemy_hit`)
with where the struck robot drew the animal against where the server had it, and the bites with their drawn state. Robot 1 also writes `where <species
number>` to the server's control file, and the robot audit then prints `AUDIT where <id> <species> <unix ms> <x> <z> <state>` every 0.5 s
for that species: robot_kinds.py holds each robot's drawn places against the server's own between blows, and near the robot the server's
gap to it against the drawn gap. Drawn against server numbers include the client's draw delay (it draws the past by design), not only a
real error. It judges nothing; the FAILs are robot_check's as in every plan.

Plan `together` (two robots at once on one thing, players thread 23 Nov 2026; `ROBOT_S=800 tools/robots.sh 2 together --delay-ms 120
--jitter-ms 30 --loss 0.03`, about 13 min): both run out of the camp, Robot 1 builds a Wicker basket and both open it. Each step starts at
one moment for both (ready files in ROBOT_SHARE, then a shared start 1.5 s on), and Robot 1 adds up the item over both packs, the basket and
the ground within 8 m (TOGETHER lines; a total that changes fails). Steps: both put twine at once; both take at once; both pick up one
dropped stack; Robot 2's link is held silent for 20 s (`hold PORT SECONDS` to the lossy link's control file) while Robot 1 puts more in,
and the total must be the old one plus what went in. After each step each robot's open basket window must match the server's
(`AUDIT chest <id> <ms> <signature> <used>` from the robot audit when a watched chest changes). Then both hammer one wooden crate site,
each with part of its cost (exactly 5 lumber and 8 nails must go in), and both use one rustic door at once (it toggles twice and ends as
it began), then each in turn: both must draw the site and the door the same. Last, Robot 1 watches Robot 2: Robot 2 swings 4 times and
Robot 1's rows must show its swing count change; then Robot 2 is passed out by the cold (`cold <peer>` to the server control file) and
Robot 1 must draw it lying (stance 3) and standing again after it wakes. While a robot is passed out its own stance stays standing, so
robot_check does not count it drawn lying in the 20 s before the rescue as a wrong stance; the rescued robot writes `rescued.txt` in
ROBOT_SHARE so the watcher's jump check takes the rescue's move as deliberate. robot_check also fails a held step when link.log has no
`LINK hold` line with a client held. robots.sh runs this plan with exactly 2 robots.

Plan `trail` (one robot, tracking thread 23 Nov 2026; `tools/robots.sh 1 trail --delay-ms 120 --jitter-ms 30 --loss 0.03`): Dave's report
was a crouch walk stopped on flat ground under a tree by a fern while standing walked on (#1775). The robot goes to the dry game-trail point
with the most trees within 8 m (within 170 m, where trees are loaded), crouches and follows the trail's line in 4 m waypoints for 40 s. A
2 s leg under a quarter of the crouch pace is compared with standing at the same spot (a `blocked` FAIL when standing walks on). It prints
a TRAIL line.

Plan `roam` (animals thread 23 Nov 2026, stuck animals away from the fight; `ROBOT_S=3600 tools/robots.sh 2 roam --delay-ms 120
--jitter-ms 30 --loss 0.03`, an hour of real time is one game day): each robot goes to the nearest water's edge, the thickest woods near, then
500 m of open ground in a direction of its own, and stands 4 min at each, round and round until 2 min before its timeout. In every plan the
robot audit prints `AUDIT stuck <id> <species> <unix ms> <x> <z> <state> to <m> ahead <what>` for an animal within 150 m of a player that
has somewhere to go (its target 2 m or more off; not alert, warning, recovering, sneaking, playing, sitting, lying, hidden, perched, flying or
tied, nor a pack wolf whose pack waits, feeds or guards its den) but has kept within
0.5 m of one spot for 6 s, with what lies 1.5 m toward its target (wall, water, steep, animal, player, fire or none), `AUDIT stuck_end` with
the spell's length, and `AUDIT near` each minute of real time (the mean number of animals near a player by kind, and the span's length). `python3 tools/robot_stuck.py <run folder> ...` prints
per kind the animal-hours watched, the stuck spells and their rate per animal per game day, the median and longest spell, what lay ahead and
the first spots. It judges nothing.

Plan `moves` (one robot, player-movement thread 23 Nov 2026, Dave: motion must be fluid; `ROBOT_S=900 tools/robots.sh 1 moves --delay-ms
120 --jitter-ms 30 --loss 0.03`): the player's own body over a real route, each stretch a ROUTE line: open walk and run in four directions,
strafe and back, jumps while running, crouch on open ground, woods standing and crouched, the crouched trail, a thicket, into the water and
back out over the edge, the hills; then it sets down and hammers up two Refined foundations with a wall, a doorway and stairs, and walks in
through the doorway, along the wall, up and down the stairs, off the edge and back on, standing and crouched (plan `moves_built`: only
these built legs, about 7 min). Every robot client (and a play
with `--motion-audit`) runs the motion audit (`src/client/motion_audit.gd`): `MOTION stop` (held under a quarter of the asked pace for
0.4 s, with what it touched; "no cause" when only the floor), `MOTION slow` (under 70% on flat ground for 1 s), `MOTION snap` (set more
than 0.3 m between walk frames, or moved by the stuck rescue), `MOTION push` (a log or an animal moved it more than 0.15 m) and each minute
`MOTION summary <gait>` (the share of the asked distance made, the counts, and where the rest went: against things, on slopes, on clear
flat ground). It judges nothing.

Plan `seen` (two robots, players thread 23 Nov 2026, protocol 162; `tools/robots.sh 2 seen --delay-ms 120 --jitter-ms 30 --loss 0.03`):
Robot 2 takes a Shortbow in hand and sends the held-item flags 1 (raised), 2 (drawn) and 0, 3 s each; Robot 1 must draw the more byte's
bits 2 then 4 with the bow pose and play the bow_raised and bow_drawn clips (SEEN bow line). Then both go to the nearest water, Robot 2
casts a fishing rod and walks 8 m off: Robot 1 must draw its float within 8 m of it, and no float 3 s after it walked away (SEEN cast line).

Plan `wiggle` (two robots; `tools/robots.sh 2 wiggle [link]`): Robot 1 runs back and forth across a spot in legs of 0.5, 0.7, 0.6 and 0.4 s (they cancel, so it stays on its spot) for 15 s (uneven, so no delay fits a period later); Robot 2,
6 m off, records where it draws Robot 1 each frame and holds it against Robot 1's own place at the same moment less the best-fitting
draw delay (0 to 1500 ms; along a straight back-and-forth the path itself covers any overshoot, so the time is what tells). It prints a
WIGGLE line (the delay, median, 95th, worst) and judges nothing. A bow is held in the left hand, so the held check measures the left hand mount
against the left hand bone for it.

Plan `light` (walk,
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
