# Birds and thunder: the server half

**Owner:** Steve, for `src/shared/thunder.gd` and `server_animals.gd`.
**Asked by:** MikeW: birds flush (state 15) on a thunder clap, server side.
**Status:** the shared schedule and the server flush are in code, behind `animals.json` `thunder.on` (off). Since 9 Nov 2026 the client plays its thunder from the same schedule (Kathleen, `weather_sounds.gd`, `thunder_delay_design.md` section 2), so the switch can go (Steve). Static checks only.
**Decided:** coordinator, 8 Nov 2026. Dave may revert.

## 1. What happens today (read from the code, 8 Nov; not tested)

- **The client draws thunder at random.** Each client rolls its own: `weather_sounds.gd`, `_rng`, one strike every 14 to 45 real seconds at the full storm, 250 m to 2.8 km away, in a random direction. It plays them only when the rain is 0.5 or more in a storm. Kathleen's #692 (`--thunder-real`) changes the distances and delays, and is still random.
- **The server knows nothing of thunder.** So "Kathleen's thunder time" does not exist anywhere the server can read. Two players standing together hear different claps.

## 2. What changes

- **A shared strike schedule**, `src/shared/thunder.gd`, `Thunder.strikes(seed, t0, t1, weather, centre, reach)`:
  - the world is cut into 4 km cells and game time into one-minute slots;
  - each cell has a strike in a slot with chance slot / 1,089 game s × storm (at least 0.2 × that), at a hashed point in the cell and a hashed moment in the slot;
  - it needs rain 0.5 or more and a storm above 0, the client's own thunder gate.
  - **The rate is today's,** spread over the ground: within 2.8 km of a player, about one strike every 30 real seconds at storm 1. The server, and every client that asks, get the same strikes.
- **Birds flush when the sound reaches them:**
  - the server keeps each strike near a player as a clap on its way, spreading at 343 m/s;
  - a bird within `flush_m` 800 m (judged) of the strike flies up away from it when the sound gets there. That is a bird with a flight row (crow, grouse, pheasant, guineafowl) or a water flock (duck, goose).
  - On the wire it is state 15, the existing flying state. A perched crow leaves its perch.
  - **Not in this step:** songbirds without a flight row (they have no flight path).
- **The client (Kathleen, 9 Nov 2026, done):** `weather_sounds` asks `Thunder.strikes` for the game seconds since its last read, round the listener out to 15 km, and plays `strike(distance, angle)` for every strike within 3 km and a fixed hashed 1.5 % of the farther ones. The flash, the clap and the birds line up for everyone. The random roll is deleted.

## 3. Data (`animals.json` `thunder`)

```
"thunder": {"on": false, "flush_m": 800.0, "sound_mps": 343.0}
```

## 4. Cost

Per tick and player, the slots crossed (usually one) × the cells within 1 km (at most 4) hashes. Each clap lives at most 2.3 real seconds and checks the animals once a tick.

## 5. Tests (static checks only in the cloud; run on Dave's PC)

New `test_birds_thunder.gd`:
- **The schedule:**
  - the same inputs give the same strikes;
  - there is no thunder without heavy rain or without a storm;
  - the rate is about the client's (600 to 2,400 strikes within 2.8 km in 10 game days, expected about 1,200).
- **The flush:**
  - with the flag off, nothing happens;
  - at the flash, the sound has not reached a crow 200 m off yet;
  - two seconds later it flies up (state 15), while a crow 1.4 km off stays.
