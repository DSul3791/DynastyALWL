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
  `pace()`. stood_ms is gone.
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
- Server: `make_way`. A standing animal a player walks into steps out of them at its walking pace (robot play-testers, 23 Nov 2026: a dog
  0.02 m from a player's middle, a deer 0.22 m, a horse 0.15 m). Birds in the air, perched or burrowed animals, swimmers and a camp's tied
  horses stay, and so does big game warning, charging or recovering. Pack wolves move in the pack brain and are not covered (a resting
  pack wolf a player walks into stays; a known gap). Cost: the nearest player's distance is already worked out each step; one compare.
- Tests: test_animal_motion_buffer.gd (a corner run: within 0.5 m, speed eased, facing turn rate), test_animal_contact.gd (make_way).
