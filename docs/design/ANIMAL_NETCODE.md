# Animals over a real connection (23 Nov 2026)

Dave's first game on the real server (Linux Docker, friends over the internet and the LAN, build 9257): "animals were still teleporting
and jumping right through us ... battle was almost impossible. the animals are like really bad animatronics". Then: "they might need more
freedom client side", and "check on the internet for the best practices". This page keeps the research, the diagnosis and what protocol 154
changed. The play-test write-ups for Dave are in the project files (animal-motion/DIAGNOSIS_2026-11-23.md, RESEARCH_2026-11-23.md).

## What other games do (sources)

1. **Snapshot interpolation with a jitter buffer.** Other creatures are drawn a little in the past, between two updates already received.
   The buffer is as deep as the connection's jitter needs. Extrapolation is brief and capped. Corrections are blended, not snapped.
   [Gaffer On Games](https://gafferongames.com/post/snapshot_interpolation), [Gambetta](https://gabrielgambetta.com/entity-interpolation.html),
   [Valve](https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking?ref=blog.hathora.dev) (100 ms at 20 updates a second),
   [Unity Netcode](https://docs.unity3d.com/Packages/com.unity.netcode@1.8/manual/interpolation.html),
   [Mirror](https://mirror-networking.gitbook.io/docs/guides/snapshot-interpolation).
2. **The server decides, the client draws the body.** The server owns position, intent and hits. The client owns the curve, acceleration,
   feet and head. [Overwatch, GDC](https://gdcvault.com/play/1024001),
   [RDR2 horses](https://gamedeveloper.com/design/rockstar-s-quest-for-the-ultimate-video-game-horse).
3. **Steering with limits.** Top speed, top acceleration, top turn rate, arrival that slows down, separation in a herd.
   [Reynolds' steering (Georgia Tech slides)](https://faculty.cc.gatech.edu/~surban6/2016-cs4731/lectures/2016_05_31_steering.pdf).
4. **Feet matched to the ground.** Clip rate and walk/run blend by speed; stride and orientation warping; foot IK.
   [Unreal pose warping](https://dev.epicgames.com/documentation/unreal-engine/pose-warping-in-unreal-engine),
   [Godot AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html).
5. **Turn in place, arc when moving; big animals turn slowly.**
   [RDR2 horses, GDC](https://gdcvault.com/play/1027230/AI-Summit-Making-the-Believable).
6. **Head look-at before acting**: the cheapest readable sign of awareness.
   [Upper-body movement in gameplay](https://gamedeveloper.com/art/head-over-heels-upper-body-movement-in-gameplay).
7. **Wind-up, committed strike, recovery** for every attack.
   [Dark Souls 3 attack anatomy](https://www.gamedeveloper.com/game-platforms/anatomy-of-an-enemy-attack-in-dark-souls-3),
   [telegraphing](https://gamedeveloper.com/design/enemy-attacks-and-telegraphing),
   [Monster Hunter](https://kotaku.com/monster-hunters-animations-make-you-a-better-player-1822776242).
8. **The committed part played locally**: a locked lunge is drawn at the present.
   [Unreal: locally predicted AI abilities](https://forums.unrealengine.com/t/locally-predicted-ai-abilities-for-hitreaction/2720548).
9. **Attack places round the target, stop at the body.**
   [Battle circle](https://code.tutsplus.com/battle-circle-ai-let-your-player-feel-like-theyre-fighting-lots-of-enemies--gamedev-13535t),
   [attack tokens](https://www.strayspark.studio/blog/attack-token-system-ue5-group-combat-that-feels-fair).
10. **Lag compensation** for the player's hits: the server checks against where the player saw the target.
    [Valve](https://developer.valvesoftware.com/wiki/Lag_Compensation).
11. **Steady decisions**: awareness that builds up, a foe held for a moment, real hit reactions.
    [Fair, readable, responsive AI](https://lghts.itch.io/iron-reclamation/devlog/1092177/making-combat-feel-good-fair-readable-and-responsive-ai).

## What ours did, and why only on the real server

- **ENet threw the rows away.** Every ping that came back slower than the recent ones lowered ENet's packet throttle. The share it
  lowered is the share of unreliable packets ENet drops on purpose before sending (ENet peer.c `enet_peer_throttle`, protocol.c, the
  unreliable branch; defaults 5000 ms, 2, 2). On a LAN the ping never wobbles; over the internet it always does. It hit three things:
  - the animal rows;
  - `players`;
  - `report_position`, so the server saw our own position late and in bursts, which read as running.
- **A stand was guessed.** The client took a gap in arrivals of over three row gaps as a stand. A lost batch looked the same, so the
  animal stood, then jumped. Standing rows were stamped only once (stood_ms).
- **A fixed delay.** One arrival gap plus 0.15 s, clamped to 0.7 s. It did not grow with the connection's lateness or its holes, and a
  late point snapped the body.
- **Fights 0.4 to 0.8 s old.** A charge at 11 m/s was drawn 4 to 9 m behind. It never stopped at the player, and wolves walked to the
  player's exact spot.
- Model of the old path (an animal that runs 3 s at 10 m/s, zigzagging, then stands 2 s), in visible jumps over 0.5 m a minute:

  | connection | jumps a minute |
  |---|---|
  | LAN | 4.6 |
  | internet, 40 ms | 5.0 |
  | + 10% loss | 14 |
  | + 30% loss | 37 |
  | + 50% loss | 67 |

  The new path gives 0 in every case.
- Still to do (next PRs):
  - **robot steering**: full speed from the first step, a dead stop, the heading snapped each step, fixed detour angles, sharp
    zigzags;
  - straight lines between points;
  - no look-at;
  - no lag compensation for player hits;
  - the foe flips between two players each step.

## Protocol 154 (this change)

- data/network.json `packet_throttle_*`, applied by net_settings.gd on both ends: deceleration 0, so nothing is dropped on purpose.
- Server rows_near: a standing animal's row carries the send time every send. `moving` comes from the step; wolves set it in
  `pace()`. stood_ms is gone (the later `stopped_ms`, step 4 of "Plans", is another thing: when its step stopped it).
- Client motion_buffer.gd:
  - the row clock (`clock_new`, `clock_note`, `clock_delay`) sets the delay from the server-time interval, the share of holes and the
    lateness;
  - animals push with no pause guess;
  - `smooth()` keeps the body from moving more than a normal frame's way and blends the rest away;
  - KEEP 6.
- Client animal_view.gd: warn, charge, recover and jaw-pop (AHEAD_STATES) are drawn at the present. Only a charge carries on past its
  newest point, and a charge is never drawn inside the local player.
- Server: data/animals/contact.json gives each species' reach.
  - `keep_off_players` holds any step that would enter a player, also for wolves.
  - A charge that hits stops against the player (`server_big_game.stop_at`).
  - For every fighter, body plus player half width stays inside hit_m.
- `smooth()` takes the speed of the leg being drawn (`speed_at`), not the newest one: at a stop the newest leg is the standing one while the body
  is still running a delay behind (gate review). A charge's carry is at most two legs' time and 15 m/s (`CARRY_MPS`); the client stops a carried
  charge on the near side of the player (`AnimalContact.stop_toward`), never flipping it through.
- Cost: no new CPU of note (one distance per player for each animal that moved; one clock read a row). Bandwidth: standing rows now change
  every send, so the server's "unchanged rows only every 2 s" skip no longer holds while any animal is within 120 m: about 30 rows x 40 B x 4 a
  second, roughly 5 KB/s a player at the 30-row cap (the probe measures it). Moving animals already made every batch differ.
- Tests: test_animal_motion_buffer.gd (the row clock, smooth, the whole path at 0 to 50% loss: no frame jump over 0.5 m; the old path
  jumps); test_animal_contact.gd (charges at 20 and 2 steps a second never enter the player; keep_off; standing rows stamped).

## The body's own feet (PR 2; no protocol change)

Dave's "more freedom client side". The server still owns where every animal is, what it does, a charge's locked line and every hit; the
client only decides how the body gets from one drawn point to the next.
- `MotionBuffer.follow`: a critically damped spring (the SmoothDamp form, steady at any frame rate) on the drawn point `FOLLOW_S` (0.15 s)
  ahead along its own way. A start or stop eases over about 0.15 s, a sharp server corner (the steering's instant turns and fixed detour
  angles) is drawn as a short curve, and a steady run is not lagged. It stays within about 0.25 m of the point at 6 m/s. Charges, warns
  and recovers (drawn at the present) skip it and keep their exact line (`follow_hold`), so the contact stop and hits stay where the server has them.
- `MotionBuffer.face`: the body faces the way its feet go when it moves, its sent heading when it stands, turned at most
  `AnimalContact.draw_turn_rad_s` (a full turn in 0.5 s plus its body size: wolf 5.7 rad/s, elephant 2.3) and never snapped. The old facing
  lerped 10 a second toward each row's heading, so a row heading that spun 200+ rad/s (the probe) spun the body.
- Every drawn body, not only a charge, is held out of the local player (`stop_toward`): the spring eases a little past a wolf's or dog's stop.
- Never held at the player's edge (robot runs 23 Nov 2026: a bear held there while the server's bear ran on, inside the player, then a 42 m
  jump when let go). An animal already past the player is drawn going round them (`AnimalContact.round_toward`), no faster a frame than
  the drawing's own room (so `MotionBuffer.smooth` keeps up instead of cutting across), then on in a straight line; one the player walked
  into steps out to the edge on its own side. Only a charge (state 11, carried on past its newest point) still waits on its own side until
  its next row. Test: `test_animal_contact.gd`, the game's own loop at 30, 60 and 144 fps.
- Server: `make_way`. A standing animal a player walks into steps out of them at up to half its flee speed (its walking pace at least) (robot play-testers, 23 Nov 2026: a dog
  0.02 m from a player's middle, a deer 0.22 m, a horse 0.15 m). Birds in the air, perched or burrowed animals, swimmers and a camp's tied
  horses stay; big game warning, charging or recovering steps out too (held on the circle by stop_at, no flapping). Pack wolves move in the pack brain, which does the same for a wolf that stood
  this think (server_wolves `_make_way`), except in a rush. A body of `AnimalContact.BLOCK_M` or more that a player only leans on (the walker is stopped `WALK_INTO_M` inside it; `LEAN_M` or less) shifts at `LEANED_MPS` (0.5 m/s), never shoved along (robots 23 Nov 2026: two robots leaning on an idle elephant pushed it at 3 to 5 m/s); a walker held at one 2.5 s goes through (animal_view `PINNED_MS`). Cost: the nearest player's distance is already worked out each step; one compare.
- Tests: test_animal_motion_buffer.gd (a corner run: within 0.5 m, speed eased, facing turn rate), test_animal_contact.gd (make_way).

## Fair hits (PR 3, protocol 155)

The player sees each animal about 0.35 s in the past (the row clock's delay) plus half the ping; the server used to judge a blow against
where the animal is now, so a blow at a running deer that looked square missed. This is the usual fix (Valve's lag compensation, Bernier 2001,
in the sources above), with the server still the judge:
- The client sends, with each blow (`ACT_STRIKE` b and count), the server moment its screen showed the animals at
  (`animal_view.seen_server_ms`: the draw time, and the present a committed charge is drawn at).
- The server keeps each animal's last places (`note_past`: [ms, position] at each move, about 0.75 s of them) and finds the target and
  the struck point where the animal was then (`pos_at`, `target_along`, `jab_point`). The damage, the zone and everything after happen now.
- It never goes back more than `rewind_max_ms` (500): a client claiming an older moment is judged at 500 ms back, so a laggy or lying
  client cannot hit an animal that left long since. 500 rather than 250 because the honest delay of a normal internet game is about 0.4 s.
- Arrows and thrown spears (protocol 157): the client sends `ACT_SEEN` (the same two times) just before `ACT_SHOOT` or `ACT_THROW`. The
  server keeps, with the flight, how far behind the server the shooter's screen was (`server_items.shot_lag`), and every step of the
  flight takes each animal where that player sees it at that moment (`target_on_segment` with `pos_at`), so an arrow that meets a deer
  on the archer's screen meets it on the server. The struck point is moved onto the body as it is now.
- Not covered: the charge still hits by where the animal is now.
- A held foe (server_big_game `_foe`, `foe_peer`): big game that warns at a player, or is hurt by one, keeps that player as its foe for as
  long as it fights and they stay within calm_m, instead of turning to whichever player is nearest that step. With two players near, it
  turned between them every step and never pressed a charge home.

## Plans: the client plays the animal at the present (24 Nov 2026, protocol 168)

Dave, 24 Nov 2026: "give as much control to the client as it takes to make them feel natural and fight like they should in a real great
video game. imagine blizzard was bulding this it has to be that good." The coordinator's reading: the server sends plans and the client
plays them smoothly, the server correcting only when badly off; further toward the client wherever the feel needs it, as long as hits stay
fair and a cheater cannot run the animals. Stare-before-flee, growl-before-attack, the fair dodge and the per-kind close attacks stay.

**Why animals still feel late.** Every animal except a committed charge is drawn the row clock's delay behind (an interval, more with holes,
plus the lateness: 0.35 to 0.8 s over the internet). A deer the player walks up to bolts on screen half a second after the server bolted it;
a boar's warning ends and it strikes while its body is still drawn walking in; the player's spear judged where the screen showed the animal
(lag compensation, above) and its own body stopped by where it is drawn. Charges were moved to the present (AHEAD_STATES) and read much better;
the rest are not, because carrying a walker on past its newest point overshot every stop and turn.

**The plan.** Each moving animal's row carries where it is going: its target on the ground (Vector2 x, z), from the step's own `target`.
The client then draws every animal on the ground (not birds in the air, states 15 and 17) at the present, like a charge: between the two
newest points, and past the newest one on along its last leg, never past the plan's target (no overshoot at a stop), for up to
`PLAN_CARRY_S`. A standing animal holds: for `STOP_PLAN_MS` after its step stopped it, its plan is where it stands (step 4). The feet (`follow`), the facing, the contact stop and `smooth` are as before.
The server still decides everything: where it goes, its state, every blow. A client can only draw; nothing it sends moves an animal.

**Fair hits stay fair.** The player's blows are judged at `present_ms` for every animal on the ground, as for a charge: the moment the screen
shows it, never more than `rewind_max_ms` back.

**Steps, largest gain in feel first.**
1. Plans and present drawing for every ground animal (this, protocol 168). Every reaction is seen up to 0.8 s sooner; what the player
   sees, dodges and stabs is where the server has it.
2. The path, not only the end: while a step goes well off the line to its goal (Steering turning it round a tree, rock, water or wall,
   over `BEND_RAD`), the plan is the way it is going, `PLAN_AHEAD_S` on at its pace (`server_animals.bend_plan`, also called by the pack brain), so the client carries it
   on along that next stretch with the server instead of holding it until the next row. Steering is one step at a time (no path is planned ahead), so this is
   the next stretch, not a whole route. No protocol change.
3. The player's own blow shows as it lands, not a round trip later: when a melee blow or spear jab goes, the client runs the server's own
   test (`target_along`, on the animals as drawn, where the server judges it) `PREDICT_MARGIN_M` inside the item's reach, on the nearest body,
   with nothing solid between (the server's `blow_blocked`), and at most once per its `recover_ms` plus `PREDICT_SLACK_MS` (the server's pace,
   which counts arrivals; a rope never), and the body flinches with the flesh thud at once (`held_item.blow_landing`,
   `animal_view.predict_hit`). The server's `animal_hit` for that animal within `PREDICT_KEEP_S` plays no second flinch or thud
   (`confirm_hit`); any other hit plays as before. The damage, the number and the blood still come only from the server, so a blow it judges a
   miss after all has only flinched (a fifth of a second, and the model's hit clip where it has one). No protocol change.
4. Measured by the robots over a lossy link: frame jumps, drawn-to-server distance, blows landed against where drawn (`robot_kinds.py`,
   which also splits the gaps by state and speed, prints the worst two-robot gaps with `--episodes=N`, and how each body was drawn: the
   correction left, time past its newest point, plan, lateness). First runs (24 Nov 2026, 120 ms, 30 ms jitter, 3% loss, two robots): the
   drawn animal's median distance from the server's own place went from about 2 m to about 0.5 m (deer, boar) and 0 for a bear at the
   player, and blows land with the animal drawn 0.03 to 0.2 m from where the server had it. But a fleeing deer could trail its place by 5 to 9 m
   for seconds on one screen: not holds (past its newest point over `PLAN_CARRY_S` in under 1% of samples) but the correction `smooth` keeps,
   drained at 1.3 times the leg's speed at most. A faster drain for a trailing correction (merged 24 Nov 2026) showed big gains in robot
   runs that did not hold on a rerun: robot numbers vary too much run to run to judge a change by (the same head gave a 95th two-robot gap of
   1.0 m and 2.4 m). So a fixed replay was made (`test_animal_draw_replay.gd`): one deer track (grazing, a 12 m/s zig-zag bolt, a dead stop),
   one seeded lossy link, the client's own drawing. It showed the faster drain changed nothing (correction 95th 1.41 against 1.39 m), and
   it was deleted. The replay found two causes. One was the stop: when the row that first sends where a fleeing deer stopped went out after
   it stopped, it was sent as standing, with no plan, and the client carried the body on past the stop at its last speed (measured 1.5 m at
   12 m/s), then pulled it back 2.4 m, drained at 0.9 m/s as a standing body. Now for `STOP_PLAN_MS` after its own step stopped it (the tick's or,
   for a pack wolf, the pack brain's `pace`), an animal's rows carry a plan of where it stands (`server_animals.row_plan`, no protocol change: a plan's end already holds the body), so
   every player's client holds it at its stop. Replayed at ten send phases (how a stop falls against a send decides whether it happens):
   (the deer track; the wolf's stamp is checked in test_hunt_feedback) frames with over 1 m of correction while standing after a bolt 756 to 0, the correction left 95th 1.82 to 1.68 m, drawn against the
   server median 0.45 to 0.33 m, 95th 2.38 to 2.31 m; no phase worse. The other, now most of what is left: starts and turns. The row with
   the new way arrives 0.1 to 0.35 s after the moment drawn, so the point jumps 1 to 2 m forward and `smooth` eases it in at up to 1.35
   times the leg's speed (its room, 1.05 times, and its catch-up, `CATCH_X`); by send phase the correction 95th is 0.7 to 2.3 m. Not
   drawing ahead of the server is the price. An option kept for after Dave's play test: send a row at once when an animal starts, turns
   or stops (one phase: correction 95th 0.7 to about 0.4 to 0.66 m, but about 25% more sends on that zig-zag track).
