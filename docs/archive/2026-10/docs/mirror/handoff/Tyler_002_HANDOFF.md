# Tyler_002 handoff (2026-10-22, Dave: done for the night)
Role: Problem Solver; owns everything not assigned to another thread (crash hunt, telemetry, server stalls, networking, HUD plumbing, performance, movement, threading). Writes code. Zero GDScript warnings (`tools/check_warnings.sh --changed`), every build in tech/BUILD_LOG.md, headless client load before pushing, questions only in questions/QUESTIONS.md, tests for Dave in tech/TEST_QUEUE.md.

## Pushed this iteration (claude/generator-v2)
- 614 ground compaction (settled copies of busy blocks; kill switch `settled_ground` in data/network.json; tests in src/worldgen/tools/test_ground_settle.gd).
- 615/618 grass: none within 0.9 m of a dug edge and none within 0.9 m of any 0.8 m drop (reads the cell's own rays); NPC labels depth tested.
- 616/619/621 look-angle ruler: marks every 10 degrees plus 45, shows underground, in open pits and in water (src/client/horizon_indicator.gd).
- 619 crash note says plainly how the last run ended; held-item caption sits above the hotbar.
- 621 launcher replaces an old server from another checkout or waits for a closing one (server writes user://server_run.json); join screen names a silent server after 20 s; server telemetry logs start-up and shutdown.
- 631/644 void rescue: off the floor in empty space under the world, only with the 42 m column below loaded, once per 6 s. Willy's 625 handles the player inside rock.
- 632 exhaustion sleep: minutes left on screen, hold Space to wake from 30 percent (data/items/energy.json forced.manual_wake_at).
- Tests: --embed-test, --dig-next-test; quick-key and plant-pick tests wait out a cold server.
- tools/bots.sh and scenes/bot: protocol-only bots (numbers in tech/BOTS.md). Scale testing is PARKED by Dave's present-focus rule: do not extend.

## Open / not verified
- Launcher replace-old-server path never run end to end (test card item e in tech/TEST_QUEUE.md).
- Rock dig dropping Dave under the world not reproduced headless (48 digs around a standing player did nothing). Rescues are in; the cause is unknown. Compaction-off experiment (settled_ground 0) not run on Dave's world.
- Spade "does nothing" fix (610 cap, 614 compaction) not confirmed by Dave; stuck-on-hole-rim cause unknown.
- New lake by the head pond (Sonny's area): digs can be ruled out only from Dave's local digs.dat (not in the repo); offered a server log line of dig counts near the pond.
- Parked: load-adaptive exertion (Dave answered: only server overload counts, not a player's own weak link), QoS design, sharding, light-communication section in SCALE_PLAN.
- Server restart needed after Pull for 614, 621 (server note), 632, settled_ground.
