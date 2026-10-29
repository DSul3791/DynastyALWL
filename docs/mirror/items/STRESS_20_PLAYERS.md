# Items server stress: simulated players (Items job 64, 2026-10-20)

Script: src/worldgen/tools/stress_items_players.gd (server_items only, no network, flat-ish test ground, headless).
Each player walks (position report 4x a second), has a crafting queue, places fires and chests, eats, drops items; 25 real seconds
at the server's 20 Hz tick (about 10 game minutes). Players start spread over 400 m x 400 m.

| players | world records | tick avg | tick p99 | tick worst | save | memory growth |
|---|---|---|---|---|---|---|
| 5 | 164 | 0.11 ms | 0.68 ms | 0.77 ms | 1.1 ms | 0.2 MB |
| 10 | 250 | 0.22 ms | 1.36 ms | 1.84 ms | 1.7 ms | 0.3 MB |
| 20 | 277 | 0.47 ms | 2.80 ms | 3.19 ms | 1.9 ms | 0.4 MB |
| 40 | 352 | 0.94 ms | 7.14 ms | 8.43 ms | 3.0 ms | 0.7 MB |

Messages per second, all 20 players together: craft_queue 8.6, slots 16, world_items 15.5 (1.7 KB/s), vitals 1.6, strain 0.8, full 0.8;
all under 2 KB/s in total. At 40 players about 4.5 KB/s in total.

Scaling: the average tick is linear in players (about 0.023 ms each). The spikes (p99 / worst) are the 4 Hz slow tick plus the world sync
that lays out scatter cells around every player and then, for every scatter item, checks distance to every player (items x players);
at 40 players that spike reaches 8 ms, still well under the 50 ms tick. Nothing here scales badly at 20 players. If it ever matters:
bucket scatter items by cell so the far-item cleanup does not loop over every pair, and spread the cell layout over more ticks.
Not measured: network (reliable RPC cost per message) and terrain/flora work, which are outside the item server.

## Rerun with the new systems (refill 15:20, builds 418 to 441)
The same script now also has every player wear a cloak, cast a rod, jab a spear, place camp benches, queue a station recipe, and die now and then (remains, energy, warmth, sickness and skills messages, weather with rain and cold, half the ground counting as water). Numbers on the same machine (cloud container, lavapipe not involved):

| players | world records | tick avg | tick p99 | tick worst | save | memory growth |
|---|---|---|---|---|---|---|
| 5 | 178 | 0.37 ms | 2.0 ms | 4.0 ms | 1.3 ms | 0.3 MB |
| 10 | 275 | 0.78 ms | 4.1 ms | 6.9 ms | 2.4 ms | 0.4 MB |
| 20 | 338 | 1.75 ms | 11.6 ms | 16.6 ms | 3.3 ms | 0.7 MB |
| 40 | 435 | 3.20 ms | 19.4 ms | 24.2 ms | 4.8 ms | 1.1 MB |

Messages at 20 players, all together: world_items 16 per second (2.8 KB/s), slots 14, strain 5, craft queue 5, warmth 2.3, notices 2.4, energy 1, skills 0.8, worn 1.4, remains 1, sick 0.8; about 4 KB/s in total (40 players about 9 KB/s). Nothing new is heavy on the wire.

The average tick grew about 3.7 times against the first run (0.47 ms at 20 players), mostly from the 4 Hz vitals tick, which now does food, water, warmth, sickness, energy, breath and strain for each player: about 0.3 ms per player, 6.5 ms for 20 in one slow tick (it lands on the p99). Per player: the warmth target 0.014 ms, the warmth tick 0.016, the energy tick 0.022, the rest are dictionary lookups into the settings (vitals, sleep, energy, exertion). Spoilage adds 0.4 ms per 15 s; crafting 0.14 ms; fires 0.09 ms. Everything is linear in players and far under the 50 ms tick (worst 16.6 ms at 20, 24.2 ms at 40). Not measured: the scans for stations (world records) and fire proximity per player, which grow with players x records; at 400 records they cost nothing visible. If the server tick ever gets tight: cache the settings floats once per tick, run the vitals tick for a quarter of the players each slow tick, and bucket fires and stations by 32 m cell.
