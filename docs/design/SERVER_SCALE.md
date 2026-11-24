# Server scale: from 32 players to hundreds, then thousands

Dave, 23 Nov 2026: "Ultimately we want the server to hold hundred if not thousands of players."
This is the measured starting point and the plan, in order of gain. Not yet played. The 32-player cap stays until Dave changes it.

## How it was measured

- Cloud box, 4 CPUs, dev `33487771`. Throwaway servers and stores only, never the live server.
- `tools/load_test.sh` bots (walk, dig, chop, craft, hunt, lay blueprints), 120 s each. Clustered = all near one spot; spread = over 2 km.
- The player cap was lifted in a throwaway copy only, so more than 32 could join.
- The bots ran on the same 4 CPUs (at low priority), so the larger runs are a little worse than a real server would be.
- Earlier work: the load test thread's CAPACITY_2026-11-23.md and NEXT_LIMITS_2026-11-23.md (project files, server-load-test), PRs #1637, #1658, #1677.

## Results

| Players | Joined | Frame gap p50 / p95 / max (ms) | Server fps | Server CPU | Memory | Sent per player |
|---|---|---|---|---|---|---|
| 32 clustered | 32 | 70 / 129 / 317 | 116 | 1.2 cores | 1.2 GB | 27 KB/s |
| 64 clustered | 64 | 211 / 385 / 597 | 25 | 1.8 cores | 1.2 GB | 25 KB/s |
| 128 clustered | 117 | 319 / 603 / 767 | 7 | 2.0 cores | 1.2 GB | 15 KB/s |
| 256 clustered | 171 | 337 / 695 / 1063 | 5 | 1.6 cores | 1.2 GB | 10 KB/s |
| 64 spread | 64 | 936 / 1491 / 1582 | 1 | 3.8 cores | 1.3 GB | 6 KB/s |
| 128 spread | 104 | 574 / 1493 / 1747 | 3 | 3.6 cores | 1.3 GB | 2 KB/s |

Closing save 2.5 to 7.5 s. Memory is not a limit (flat about 1.2 GB). At 128 and above, players could not even join: the
server was too busy to answer the join handshake in time.

**What breaks first: the main thread.** Almost all game logic runs on one thread. It is full at about 64 clustered players
(at 32 it is already 72% busy). Spread players hit a second wall sooner: making new ground uses every CPU, and the bots waited a
minute for ground.

Per-player traffic is about 25 KB/s (0.2 Mbit/s): 100 players need about 20 Mbit/s upload. Dave's line is 1 Gbit, so this is not a near limit.

## Top costs (main thread, ms per second, 64 clustered)

| Cost | ms/s | Grows with |
|---|---|---|
| Items tick: world item sync (each player looks at every record near them, each second) | about 100 | players x records near them |
| Items tick: vitals (warmth, strain, carry, energy) | about 26 | players |
| Items tick: goals and hints | about 26 | players |
| Network: incoming messages and the engine's sending | 200 to 300 | players |
| Sending animals to each player: every animal looked at, rows built and turned into text, for every player 4 times a second | 69 | players x all animals |
| Sending trails and map, blood trails, burrows | about 30 | players x their counts |
| Animal brains (capped by a time budget, so animals step less often as players rise) | 90 to 130 | animals x all players |
| Sending other players: every player compared with every other 8 times a second | 51 at 64, 82 at 256 | players x players |

The items tick also does all players' vitals and goals in one frame, 4 times a second, so a 64-player server has a 100-400 ms
frame each quarter second even when the average is fine.

## Plan, in order of gain

### Now: cheap and safe (normal PRs, measured before and after)

1. **Animal rows built once, not once per player.** Each animal's row is made once per send pass; a player only picks the near
   ones from a grid. Signatures by hash, not by turning rows into text. PR #1823: the send step went from 172 to 58 ms/s
   at 64 clustered bots, 138 to 72 at 128.
2. **Players found by grid.** Sending other players and the animal brains' "nearest player" look in nearby grid cells, not at
   every player. Removes the two players-x-players costs.
3. **Spread the quarter-second work.** Vitals and goals run for a share of the players each frame instead of all at once. Same
   total, no 100-400 ms frames.
4. **World item sync by change.** A player is sent what changed near them, not a fresh look at every record near them each
   second. The biggest single cost when players crowd one town.
5. **Lighter telemetry and logs at high counts** (the per-peer line grows with players).

Together these should put about 100 to 150 clustered players on one main thread. That is a guess until measured.

### Next: bigger work (needs a design and Dave's yes)

6. **Interest management everywhere.** One shared grid of what is where (players, animals, NPCs, items, fires), used by every
   "near" question and every send. Each player is sent only what is in its area, and far things less often.
7. **Ground making off the critical path.** Spread players wait on new ground: pre-built ground for the whole map (a baked
   world), more worker threads on a bigger box, or ground made on the client from the same seed with only edits sent.
8. **Less traffic per player.** Smaller rows (numbers, not text), send only changes, slower updates for far things.
   Needed before 100 players on a home internet line.
9. **Work off the main thread.** Animal brains and vitals on worker threads, results applied on the main thread.

### Thousands: a different shape (a big design for Dave)

10. **Zones or shards.** The world split into regions, each run by its own server process (or machine); players are handed
    over at the border. One process cannot hold thousands in GDScript.
11. **A separate save service.** A database instead of JSON files, so many processes can save at once.
12. **Hosting.** Thousands of players need data-centre servers and bandwidth, not a home server.

## Dave's rulings, 23 Nov 2026

- "Plan for thousands and be happy when it works for hundreds right now." First target: 100+ players on one server.
- His line is 1 Gbit, so traffic is not the near limit; the CPU is.
- **CPU setting.** "Make the thread/core count a setting we can set for the server to be allowed to use and design around that." His server
  box has 6 cores, 12 threads, and runs 5 other servers; about 15 players there for now, a dedicated server later.
  `DYNASTY_SERVER_CPUS` (compose.yaml, default 4; `--cpus=N` wins) is that setting (deploy/server/SERVER.md, CPUs). Today it sizes the ground makers
  and idle builders; the plan is that every later job moved off the main thread sizes itself from it too.
- **Prebuilt ground.** "The generator part should prebuild our entire world or the parts we are working with right now. The server
  doesn't build anything; it just serves the prebuilt stuff up to the clients." The region for now is the starting nine tiles (Dave: "the starting 9 chunks good enough then we will look at expanding in the future"). The
  plan is in "Prebuilt ground for the nine tiles" below.

## Prebuilt ground for the nine tiles

Built 23 Nov 2026 (Dave: "all needs to be part of the generator. make it a priority"; his ruling the same evening: Wednesday's world
starts fresh, so the first use is a fresh world on the pack). Ground: `src/worldgen/tools/prebuild_ground.gd` (any tile list, `nine`
for all nine; goes on after a stop), `src/stream/ground_pack.gd` and `src/worldgen/tools/install_ground.gd` (refuses a pack from other
tiles, an unfinished one, or a store whose server runs), test `test_ground_pack`. Steps: deploy/server/SERVER.md, "Prebuilt ground".
Speed (24 Nov 2026): one copy of the generator gains little from threads (cloud: 1 thread 380 blocks/s, 3 threads 540; Dave's PC
at 8 threads 217), but copies side by side scale: `--processes=N` runs N one-thread copies and joins them (3 copies 2.4 times one,
the joined pack byte for byte the same as one copy's). Trees and plants: `src/stream/flora_pack.gd` (one file a tile, used only when its fingerprint of tiles, flora data and placer
code matches the server's), built by the same tool (`--plants=0` skips them), copied by the install, test `test_flora_pack`; a
wooded 256 m chunk takes about 3 CPU-seconds and 150 KB. Prebuilt plants are placed over the baked water, so a chunk first seen after
a player dug a pond beside it no longer grows the pond's bank plants (a kept list never followed live water either); a tile re-bake
on a running server drops the pack until one for the new tiles is installed. Not built yet: step 3's switch-off of the idle builders inside the area with a log count, so
the server still makes ground and plants outside the pack. The plan as first written follows.

Measured 23 Nov 2026 with `src/worldgen/tools/prebuild_blocks.gd` (cloud, 3 worker threads, every detail level 0-6 the client
asks for, surface blocks only; caves and deep blocks are left to be made as now), two 1 km squares: one round the starter town,
one in open country. The tool only measures one square. Sizes are of the store's `generated_g1.sqlite` (the tool's own size line still
reads the old name `generated.sqlite` and prints 0 MB). Gzip measured on the smaller file (27.6 to 10.4 MB) and applied to the larger.

| | per km2 | one tile (236 km2) | nine tiles (2,123 km2) |
|---|---|---|---|
| Build time, 3 threads | 35-41 s | 2.3-2.7 h | about 22 h |
| Build time, 11 threads (a guess for Dave's PC, not measured) | about 10 s | about 40 min | about 6 h |
| Disk, as the server keeps it | 26-42 MB | 6-10 GB | 55-90 GB |
| Gzipped for the copy | 10-16 MB | 2.3-3.8 GB | 20-35 GB |

Three quarters of the blocks are the finest level (16 m), so leaving out far levels saves little.

How it would work:
1. A builder on Dave's PC (new) makes the server's generated-ground file for a chosen area from the committed tiles and records
   the terrain version and tile fingerprint it was made from.
2. Install, with the server stopped (new): check that fingerprint against the server's tiles, then copy the file in as
   `generated_g<N+1>.sqlite` and write `generated_generation.txt` (N+1) and `terrain_version.txt`. Without both files the store
   deletes the copy at start; with a wrong fingerprint it throws the file away and makes ground as now. The store already keeps
   player changes apart (`edits.sqlite`, `digs.dat`), so digs and fills stay.
3. The server serves blocks from the file. A block not in it is still made and saved as now (true today), so nobody at the edge
   is stranded. To reach Dave's aim (the server builds nothing) the idle pre-builder is turned off inside the area and a count
   of blocks made outside it goes in the server log (new) to show where the area must grow.
4. Trees and plants are not stored today (the server places them from the tiles on each visit; only removals are saved).
   Prebuilding those is a second step, not measured yet.

Recommendation: start with the starter tile (3,4) only, about 40 minutes on Dave's PC and 2.3-3.8 GB to copy, then the other
eight. Not for the Wednesday package: the builder and install step are new and must first be tried on a copy of the 9257 world
(test_save_9257 and a restart with the new file). A new generation drops the store's "settled" copies; those are a cache remade
from the edit log, so no player change is lost, but the first visits after install remake them.

## Rules kept

- The 32-player cap is Dave's call; nothing here raises it.
- No change may stop the 9257 live save loading (test_save_9257 stays green).
- Nothing is based on where spawn is.
- Load tests run only on throwaway servers in the cloud, never the live server.
