# Animals in fog: the server half

**Owner:** Steve, for `src/stream/server_animals.gd`, `server_wolves.gd` and `server_flight.gd`.
**Asked by:** MikeW, `docs/design/ANIMAL_FOG.md` (his branch `claude/mikew-eye-placement`), section "Requests to Steve". The client half (eye shine, steam, herd spacing on screen) is his.
**Research:** Jamie, `docs/knowledge/fog-and-visibility.md` (#716), lessons 1, 4 and 5 and the Animals table.
**Status:** design and code behind `animals.json` `weather.fog.on` (off). Static checks only; tests run on Dave's PC.
**Decided:** coordinator, 8 Nov 2026, from MikeW's requests. Dave may revert.

## 1. What happens today (read from the code on the animal stack, 8 Nov; not tested)

- The shared weather carries `mist` (0 to 1, the valley fog's strength) and `mist_top_m` (the top of the layer above sea level). Both come from `weather.gd`, so the server already has them.
- `server_animals._read_weather` keeps `mist` only, and `weather.on` (on) uses it in two flat cuts that ignore distance and height:
  - sight × (1 − `mist_sight` 0.6 × mist);
  - spook and alert distance × (1 − `mist_spook` 0.3 × mist).
- So a deer on a hill above the fog is as blind as one in it. A deer 10 m away in dense fog sees no better than one 300 m away.
- Wolves shadow a player at `stalk_m` 25 m in every weather. Crows sit on a perch only for `perch_s` (and stay up in a storm). Deer keep their clear-day hours.

## 2. What the player will notice (flag on)

- **In fog you can get close.** A deer cannot tell you from a stump past half the visibility, so in thick fog (V 120 m) it knows you by eye only inside about 60 m. It sees you clearly inside 30 m. Past that it has only hearing and smell, so its spook range falls to about a third of the clear-day one (`senses.blind_factor` 0.35). From downwind, with the wind's scent rule, you get closer still. From upwind it smells you as before.
- **On the hill above the fog sea**, animals see as on a clear day.
- **Wolves come closer.** In dense fog a shadowing pack closes from 25 m to half the visibility (never under 10 m), so you hear them before you see them.
- **Birds sit it out.** In thick fog (V under 180 m):
  - crows stay on their perch;
  - songbirds, grouse and other "bird" role animals hardly move;
  - geese, ducks and seabirds sit where they are.
- **Deer stay out later.** On a foggy morning they keep their dawn hours up to 1.5 game hours longer, and they graze along the wood edge rather than in the open.
- **Herds bunch.** Stock and deer keep half their clear-day distance from the herd's centre, and wander half as far.

## 3. The visibility at an animal

`_fog_v(pos)` gives the visibility V in metres at a point:

- **Kathleen's number first.** If the weather state carries `visibility_m` (asked of Kathleen by MikeW: the V inside the fog), that is the V inside the layer.
- **Otherwise, from `mist`.** V = clear_v^(1 − mist) × fog_v^mist, with `clear_v_m` 20,000 and `fog_v_m` 120 (Jamie's thick fog, 50 to 180 m, in a valley floor at its height). That gives:
  - mist 0.3: about 4 km (haze);
  - mist 0.6: about 930 m (fog);
  - mist 1: 120 m (thick fog).
- **Only inside the layer.** Above `mist_top_m` the air is clear (V = `clear_v_m`). Across the top it is eased over ±`top_ease_m` 6 m, the same ease as Kathleen's look (`valley_fog.md`). Sea fog (#608) is not in the shared weather yet; when Kathleen adds it with `visibility_m`, nothing here changes shape.

## 4. The rules

All of these sit behind `weather.fog.on`. With it on, the old flat `mist_sight` and `mist_spook` cuts are not used, so fog is not counted twice.

1. **Sight** (Jamie lesson 1: recognise at ½ V, detail at ¼ V). The sight share from the line-of-sight test is multiplied by a fog share:
   - 1 out to V/4;
   - falling straight to 0 at V/2;
   - 0 beyond.
   The animal's clear sight is unchanged inside V/4, so this is min(clear range, ½ V). At 0, `_sense_factor` already falls to `blind_factor`: only hearing and smell are left.
2. **Spook range falls to hearing and smell.** This needs no new number. A player the animal cannot see is sensed at `blind_factor` of the distance, times the wind's scent rule, so the spook range shrinks to what it hears and smells. Hearing is not cut. The brush noise and `always_notice_m` 8 m stay as they are.
3. **Wolves close in to half V.** The shadowing ring is min(`stalk_m`, max(V/2, `wolf_min_m` 10)) at the player. They still lose the player at `lose_m`; they follow by scent.
4. **Birds sit it out** while V at the bird is under `sit_below_m` 180 (Jamie: most birds land and sit out thick fog):
   - a perched bird (the crow) does not come down, as in a storm;
   - "bird" role animals and the `sit_species` list (goose, duck, seabird) wander × `bird_wander_x` 0.15;
   - a bird still flies when a player comes inside its spook range, which is itself shorter in fog.
5. **Deer late and at the wood edge** (Jamie: the dawn retreat is delayed 1 to 2 hours, near the wood edge). While the fog layer's own V is under `deer_v_m` 1,000 (activity and wander have no animal position, so rules 4 to 6 use the layer's V; sight and wolves use V at the point):
   - for "deer" role animals the hours from 08:00 to 08:00 + `deer_late_h` 1.5 count as "dusk" for their activity;
   - each new grazing target is tried up to `edge_tries` 3 times. The first one that is open ground with tree crowns within `edge_m` 15 m (four directions) is kept, otherwise the last one.
6. **Herds bunch** (Jamie's table: herd spread halved, they move less). Under the same V, for "stock" and "deer" role animals, `herd_pull_m` and the wander distance are × `herd_x` 0.5.

## 5. Data (`animals.json` `weather.fog`)

```
"fog": {"on": false, "clear_v_m": 20000.0, "fog_v_m": 120.0, "top_ease_m": 6.0, "wolf_min_m": 10.0,
        "sit_below_m": 180.0, "bird_wander_x": 0.15, "sit_species": ["goose", "duck", "seabird"],
        "deer_v_m": 1000.0, "deer_late_h": 1.5, "edge_tries": 3, "edge_m": 15.0, "herd_x": 0.5}
```

## 6. Left out, and why

- **Trail scent × 1.25** (Jamie, judged). Animals do not follow players' trails in the code; only players read animal trails (`trails.json`). So there is nothing to scale yet.
- **"Something moved" at V.** An animal noticing movement out to V would raise alerts in fog, which the research does not ask for. Left out.
- **Raptors.** There are none in `animals.json` yet (the eagle model is missing). The crow is the one perching bird.
- **Eye shine, steam, on-screen herd spacing:** MikeW's client half.

## 7. Tests (static checks only in the cloud; run on Dave's PC)

New `test_animals_fog.gd`, with stub weather and ground:
- **V:**
  - mist 0 gives 20 km;
  - mist 1 inside the layer gives 120 m;
  - a point 20 m above `mist_top_m` gives 20 km;
  - with `visibility_m` 60 in the state, V inside is 60.
- **Sight:** at V 120, the fog share is 1 at 25 m, 0.5 at 45 m and 0 at 70 m.
- **Spook:** with `visibility_m` 40 and the flag on, a deer senses a standing player 25 m off as farther than its 30 m spook range. In clear air it does not.
- **Flag off:** the old `mist_sight` cut is used and `_fog_v` is not.
- **Wolves:** the ring is 25 m in clear air, 25 m at V 120, and 15 m at V 30.
- **Birds:** a perched crow under V 100 does not come down after its timer, and in clear air it does.
- **Deer:** at 09:00 in fog a deer's activity period is "dusk", and in clear air it is "day".
