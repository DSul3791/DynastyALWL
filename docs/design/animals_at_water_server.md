# Animals at water: the server half

**Owner:** Steve, for `src/stream/server_animals.gd` and `server_wolves.gd`.
**Asked by:** MikeW, `docs/design/ANIMAL_DRINK.md` (his branch `claude/mikew-eye-placement`), section "Requests to Steve". The client half (sip and look round, the churned bank, birds bathing) is his, behind `drink_looks`.
**Research:** Steve's `docs/design/drinking_water_design.md` (#719), Sonny's `docs/water/springs_and_drinking_water.md`.
**Status:** design and code behind `animals.json` `drink.on` (off). Static checks only; tests run on Dave's PC.
**Decided:** coordinator, 8 Nov 2026, from MikeW's requests. Dave may revert.

## 1. What happens today (read from the code on the animal stack, 8 Nov; not tested)

- Deer and stock graze and hop round their home, are pulled to their herd's centre, and move for weather (cover in rain, gale and cold, shade in heat).
- Nothing takes them to water. Only the bears' fishing (`den.fish_share`) and the swimmers look for it.
- Wolf packs prowl `prowl_m` 40 m round their home at every hour.
- The server reads water through `water_level(x, z)`: the live sim's surface, NaN on dry land, and 0 over the sea (ground at or under 0).

## 2. What the player will notice (flag on)

- **At dawn and dusk** (the game's "dusk" period, 05:00 to 08:00 and 18:00 to 21:00), most deer and stock (`chance` 0.7 each twilight) walk from their grazing to the nearest fresh water's edge within `reach_m` 300 m.
- **At the bank** each one stands 1 to 3 minutes of real time (`stand_s`) facing the water, head down. The wire state 21 (`DRINK`) lets the client play the drink. Then it walks back to where it was grazing.
- **A herd arrives together**, because one search serves everyone whose home lies in the same 50 m cell. Each animal stands a couple of metres apart along the bank.
- **The sea is never a drinking place**, the same as for players (#719).
- **Wolves wait at the water.** At dawn and dusk a prowling pack hangs about `wolf_back_m` 15 m back from the water nearest its home (within `wolf_water_m` 500 m), roaming `wolf_ring_m` 12 m. That is where the prey come. A player watching a drinking place at dusk may find the pack there too. Stalking, firelight and den guarding are unchanged.

## 3. The rules

1. **When:** during the "dusk" period (`period_of`), once per twilight per animal. The chance is rolled when a grazing spell ends. It is cleared when the period ends.
2. **Who:** `roles` ("deer", "stock"). Never a companion.
3. **Where:** `drink_spot(home, reach_m)`:
   - it looks along rings `ring_m` 25 m apart in `bearings` 8 directions;
   - the first sample on the nearest ring with fresh water (a surface more than `wet_m` 0.05 m over ground above the sea) is the water point;
   - from there it steps back toward the animal 2 m at a time, up to one ring, to the first dry ground, which is the stand.
   - The answer, or "none", is kept per 50 m cell (and reach) for `cache_s` 600 real seconds.
   - **Cost:** at most 96 water and ground samples for one search, and one search per herd per twilight.
4. **The walk:** the animal's home moves to the stand plus a small jitter, and it hops there. The herd's pull to its centre is held off while it does. Within `near_m` 4 m of the stand, it faces the water point and grazes there for `stand_s`; that is `DRINK` on the wire. When the time is up, or after `max_legs` 12 legs that never arrive, or when the twilight ends, home goes back to where it was.
5. **Weather first:** the weather moves (cover, shade, gale drift, hunch) run before the drink, so a deer in a downpour shelters and does not walk to the water.
6. **Wolves:** `wolf_wait_point(home)`, during the same period, is `wolf_back_m` back from the stand, away from the water, at the water nearest the pack's home. The prowl wanders round it instead of the home.

## 4. Springs first, later

MikeW's ask says springs first. The server has no spring positions until #719 step 2 bakes the `drink` rows into the tiles. Until then, the nearest fresh sim water wins: a pool, a lake edge or a brook in spate. When the rows arrive, `drink_spot` asks them first, in `drink_rules.gd`'s order (spring, river, lake, brook, puddle). Nothing else changes shape.

## 5. Data (`animals.json` `drink`)

```
"drink": {"on": false, "roles": ["deer", "stock"], "chance": 0.7, "reach_m": 300.0, "ring_m": 25.0, "bearings": 8,
          "wet_m": 0.05, "cache_s": 600.0, "near_m": 4.0, "stand_s": [60.0, 180.0], "max_legs": 12,
          "wolf_water_m": 500.0, "wolf_back_m": 15.0, "wolf_ring_m": 12.0}
```

It has its own flag rather than `vitals.json` `thirst.sources`: that flag is the players' drink, on another stack (#720), and it is read by `server_items`.

## 6. Tests (static checks only in the cloud; run on Dave's PC)

New `test_animals_drink.gd`, with a stub lake east of x 100 m:
- **Flag off:** a deer does not go.
- **The search:** the stand is on dry ground just short of the lake's edge.
- **At dawn:**
  - the deer heads there;
  - at the bank it stands 60 s or more facing the water, sent as state 21;
  - then it goes home;
  - it goes only once in a twilight.
- **At noon:** it does not go.
- **The sea:** never a drinking place.
- **Wolves:** at dusk the wait point is 15 m back from the water. At noon there is none.
