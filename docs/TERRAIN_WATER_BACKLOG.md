# Terrain and water backlog (Sonny, 1 Nov 2026)

Owner for every item: the terrain and water agent (Sonny, or whoever takes the role). Read `docs/DYNASTY_WATER_HISTORY.md` and `docs/handoff/HANDOFF_SONNY.md` first. Each line: what, exact next step, why.

## Join and terrain loading
1. **17 s blocked stretch after a connect.** Server telemetry (`crash_reports/telemetry_server_<port>.log`) shows 13 s of main-thread stalls ("between frames (rpc handlers, engine)": 3.5 s, 1.8 s, 1.6 s, 1.1 s ...) in the first 25 s after the client connects. Next: merge branch `join-stall-instrument` (b100e21a, logs `SLOW RPC <name>: N ms` for the join handlers), run one rig join, read the telemetry file, fix the handler named. Why: it is the biggest piece of the 32-38 s join.
2. **near_water cost** fixed on `terrain-near-water-warm` (007cf5f5): 3.7 s a tile to 2-30 ms. Merge it. Tile file read is still 1.4 s per tile, sequential at server start (5 tiles, 7 s): next, prefetch the five starter tiles in parallel.
3. **Block generation for the join** (about 19,000 blocks, 18 s): measure what the client asks for at join and whether a smaller first request with the rest following is acceptable.

## Water
4. **Default flip** on `water-default-flip` (823bf552): new water default, old behind `--water-old` and the Esc > Settings > Gameplay switch. Next: run `test_water_field`, `test_water_flow_texture`, `test_water_window`, `test_water_hub2`, `test_water_soak` (900 s), `test_spawn_dry`, `test_first_hour`, start the launcher once and flip the switch, one rig join. Why: nothing of it has been run.
5. Real-game before/after pictures at a river or lake (agl 50 flying camera; fix `probe_pick_spot.gd` tile origin first) for the QA page.
6. Protocol flow channel + `water_material.gd` patch (plan in `docs/DYNASTY_WATER_STATUS.md`), data side mine, look side to the art team.
7. Windows following players with shared seams; digs and fills reaching the field; swim/drown rules from `water_rules.gd` wired in; one-hour held-river soak (the 30 minute probe showed 98.6 percent drawn, volume 140 percent of start, all 64 blocks awake); cell-list stepping if cost matters.

## Terrain bake set
8. **Bake proposal** (QA card `bake-terrain-set-1`). Branch `terrain-bake-set` (merge of `claude/land-types2-springfeed` + lake-lip on the daily, TERRAIN_VERSION 45, 87817a7b, bdf2ba69). Next when Dave says yes: bake tile (3,4) alone, time it, run `test_tile_lakes`, `test_river_ore`, `test_head_pond_fill`, `test_worldgen`, then the rest with `tools/settle_block.sh`. No tile is committed without Dave's go.
9. `terrain-ports` (43cbbef2): `test_water_soak` film fix and `tools/settle_block.sh`, ported; `erosion-fill-cap` doc is already in the daily archive.

## Old branches (answered to the moderator)
Delete: the 7 already-done, the 15 old bakes and evidence branches. After merge: `claude/water-soak`, `claude/steve-river-seams`, `claude/lake-lip`, `claude/pond-notch`, `claude/steve-spring-feed`, `claude/land-types`, `-types2`, `-types2-springfeed`, `claude/erosion-fill-cap`. `sonny-character`: its only unmerged commit (the water proposal, 8cdfa792) is also on `dynasty-water`, so it can go once `dynasty-water` is merged.
