# Single birds in flight: server states and paths

**Owner:** Steve (server). **Client:** MikeW, whose flight layer (`docs/design/BIRD_FLIGHT.md`, `FLIGHT_RIGS.md` on his branches) already plays take-off, flap and glide, and landing from the state. **Status:** design, 8 Nov 2026.
**Code:** `src/stream/server_animals.gd`, a new `src/stream/server_flight.gd`, and `data/animals/animals.json` `flight` rows.
**Related:**
- `animals_in_weather_design.md` (#646): no flying in heavy rain or a storm.
- [wind-over-terrain.md](../knowledge/wind-over-terrain.md) (Jamie, #637): wind m/s = 20 × wind^1.3, and crest speed-up.

## 1. Today

Only flocks fly. Duck and gull flocks rise together in state 15 and are gone once they have flown `fly_m` (`server_flocks.gd`). Single birds (pheasant, grouse, guineafowl, crow) run from a player like a rabbit, on foot at `flee_mps` 7.5. The eagle and raven have no model yet.

## 2. What happens in life

| Bird | Escape or travel | Numbers | Source |
|---|---|---|---|
| Pheasant (and grouse, guineafowl: judged alike) | sits tight, then bursts up almost vertically with no run-up, flies straight, locks its wings and glides down into cover, then runs | typical flight about 200 m (up to 2 km); 10 to 15 m up; 61 to 77 km/h (17 to 21 m/s); a minute or two at most | birdfact, "Can pheasants fly?" |
| Crow, raven | flap to a tree or a crag; ravens ride ridge updrafts and roll in play | rolls about 1 s, half and full rolls, often in pairs | Montana Public Radio, "Ravens at play" |
| Golden eagle | soars on thermals in light wind, and on slope (orographic) lift as the wind rises | thermals: climbs 1.8 m/s, glides out at about 17.6 m/s; slope lift: climbs about 1.0 m/s at 11 to 13 m/s. Each 1 m/s more wind gives about 20 m lower flight and about 27 m smaller climbs; it uses slope lift above about 12 m/s | Katzner et al. 2012, Biol. Lett., "Topography drives migratory flight altitude of golden eagles" |

What the game takes from this:
- the pheasant burst and glide;
- ravens on ridges in wind;
- eagles circling in thermals on calm sunny days, and beating along windward ridges on windy ones.

## 3. Wire states (MikeW's layer)

- **0, ground or perched.** On a tree or crag, the position's height is the perch.
- **3, alert.**
- **15, flying (flapping).** Entering 15 from the ground plays the take-off clip once.
- **17, gliding (new, FLIGHT_RIGS.md).** A client without it falls back to 15.
- **Back to 0:** the landing clip plays once.

The row's position already carries the height, and its heading carries the way the bird faces. The client works out the bank from the turn rate.

## 4. Flight as segments, not steps

A bird in the air follows a list of segments. Each is a pure function of game time:
- `line`: from, to, speed, and climb or sink;
- `circle`: centre, radius, turn direction, climb, start angle;
- `beat`: a straight leg along a ridge and back.

The server writes the bird's position from the segment it is in, at whatever rate that bird is ticked. So a far bird, ticked at 0.5 Hz, is in the same place when a player comes near as it would be at 10 Hz. A segment ends on time, and the next one is planned then.

**Never in the ground:** each segment is checked at plan time every 10 m along it, and kept `clear_m` (3) or more over the ground. A circle is checked at 8 points. If a check fails, the segment climbs first.

## 5. Flushers: pheasant, grouse, guineafowl (step 1)

The row is `"flight": {"kind": "flush", "flush_m": 9, "climb_m": [10, 15], "fly_m": [120, 300], "fly_mps": 18, "glide_share": 0.3, "run_m": 8}`.

- **Sitting tight:** the bird stays down until a player is within `flush_m`, which is closer than `spook_m` (lesson: it sits tight). A crouched, still player gets closer, through the usual senses. A dog or a player running at it flushes it at `spook_m`.
- **The burst:** a `line` straight up to `climb_m` in about 1.5 s, in state 15.
- **Away:** a flapping `line` away from the threat to 70% of `fly_m`. It bends toward the nearest cover (`canopy`) within 45° if there is one.
- **The glide:** the last 30% is a gliding `line` (state 17) down to the ground.
- **Landing:** state 0, then a run of `run_m` on foot (HOP) into cover. Its `home` moves there.
- **In the air it is out of reach of a spear,** but an arrow can still hit it, because the hit test is 3D (`target_on_segment`). It keeps its alarm group (#636), so the other ground birds near it flush too.

## 6. Perchers: crow (step 1)

The row is `"flight": {"kind": "perch", "perch": "tree", "fly_m": [40, 150], "fly_mps": 12, "glide_share": 0.4, "perch_up_m": 8}`.

- **Spooked:** it flies to a point under tree crowns (`canopy`) 40 to 150 m away from the threat, and perches `perch_up_m` up (state 0 at that height).
- **Coming down:** after a while, or once the player is past `safe_m`, it comes down to the ground to feed again.
- **No tree in reach:** it flies `fly_m` and lands on open ground, like a flusher.

## 7. Soarers: eagle, raven (step 2, when the models arrive)

The row is `"flight": {"kind": "soar", "perch": "cliff"|"tree", "soar_m": [120, 400], "fly_mps": 14, "thermal_r_m": [40, 80], "climb_mps": 1.8, "ridge_climb_mps": 1.0, "play": false}`. The raven has `play: true`.

The mode is picked each time a segment ends, from the weather and the ground round the bird's home:

| Mode | When | Path |
|---|---|---|
| **Thermal** | `sun` 0.6 or more, `wind` under 0.4, 10:00 to 16:00 | `circle`s of radius `thermal_r_m`, climbing at `climb_mps` and drifting downwind at the wind's speed, up to the top of `soar_m`; then a gliding `line` (state 17) out to the next thermal, sinking about 2 m/s at about 17 m/s |
| **Ridge** | `wind` 0.3 or more (about 4 m/s) and a windward slope near home (slope over 10°, facing within 45° of upwind, sampled on a 64 m ring) | `beat`s along the crest line 30 to 80 m above the windward slope, mostly gliding. Lower the stronger the wind: 20 m lower per m/s (Katzner) |
| **Perch** | calm and overcast, dusk, night, or rain over 0.6 or a storm (#646) | at its perch: a cliff (a sample steeper than 40° beside a drop) or a tree |

- **Raven play:** in ridge mode, a raven sends a one-shot `roll` event about once a minute (the client plays a half or full roll), often in pairs.
- **Later:** a raven follows a hunter at a distance, and comes down to a carcass (the carcass hook).
- **Owl:** night only, through `active`. It perches by day.
- **Visibility:** `soar_m` keeps eagles where a player can see them. Real migrating eagles fly near 1 km up (Katzner: 965 m mean), which is too high to read in the game.

## 8. Weather

- In rain over 0.6 or a storm, nothing takes off unless it is flushed. A bird in the air goes to its perch or cover.
- In a gale (`wind` 0.6 or more), flushers fly shorter (`fly_m` × 0.6) and with the wind behind them, and crows stay down.
- With a storm ahead (#646), the soarers are out more by day.

## 9. Steps

1. **`server_flight.gd`:** segments; flushers and perchers (pheasant, grouse, guineafowl, crow); state 17; the clearance check.
   **Test `test_bird_flight`:**
   - a pheasant sits until 9 m, rises 10 to 15 m, flies 120 to 300 m, glides, lands and runs;
   - its position is the same at 0.5 Hz and 10 Hz ticks;
   - it is never under ground + 3 m over a made-up hill;
   - a crow perches up a tree;
   - it does not fly in a storm.
2. **Soarers** (with the eagle and raven models): thermal and ridge modes, perches, raven rolls. **Test:** over a made-up ridge with wind across it, a raven beats along the windward side, and on a calm sunny noon an eagle circles and climbs.
3. **Later:** the raven follows a hunter and comes to a carcass, and the owl.

## 10. Sources

- Katzner, T. E. et al. (2012), "Topography drives migratory flight altitude of golden eagles: implications for on-shore wind energy development", Biology Letters 8: https://pmc.ncbi.nlm.nih.gov/articles/PMC3440984
- birdfact, "Can pheasants fly? Flight speed, distance, height and more": https://birdfact.com/articles/can-pheasants-fly
- Montana Public Radio, "Ravens at play": https://www.mtpr.org/post/ravens-play
