# Dynasty water: task list (Sonny, from 1 Nov 2026)

Standing rule from Dave: when the assigned work is done, write three more tasks that belong to the water job here, do them, then write three more, until nothing is left that would improve the game. Ponytail rules, 3 heavy Godot jobs at most (`tools/godot_slot.sh`), nothing merged into the daily or main. Each task ends with what passed, what was skipped, and the risk.

## Round 1 (assigned by the moderator, 1 Nov)

1. **A real-game picture of water2.** The first try put the camera under the ground (a walking shot fell through), the second was open sea (ground -49 there). Pick a spot with real river or lake (`probe_pick_spot.gd`), fly the camera (more than 40 m up, no collision), picture with `--server-arg --water2`, and the same spot without the flag. Status: spot probe written, waiting for a free Godot slot.
2. **Cut the cost.** Lakes should sleep (all 64 blocks stay awake in `probe_water_cost.gd`, 101-116 ms per simulated second), and the held rivers should not drain or cost anything when nothing changes. Find why they never rest, fix it, measure again.
3. **Stage e.** Swim and drown wired to the real player, windows following players, digs and fills reaching the field, the protocol flow channel. Order decided after 1 and 2.

## Round 2 (candidates, not started)

4. Windows that follow players (a field per player, shared seams): needed before any second player can see live water.
5. Slow tests on this branch: `test_worldgen`, `test_water_soak`.
6. Long-run check of held rivers (a simulated hour): drift, drain, flooding.
