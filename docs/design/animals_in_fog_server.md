# Animals in fog: the server half

**Owner:** Steve, for `src/stream/server_animals.gd`, `server_wolves.gd` and `server_flight.gd`.
**Asked by:** MikeW, `docs/design/ANIMAL_FOG.md` (his branch `claude/mikew-eye-placement`), section "Requests to Steve". The client half (eye shine, steam, herd spacing on screen) is his.
**Research:** Jamie, `docs/knowledge/fog-and-visibility.md` (#716), lessons 1, 4 and 5 and the Animals table.
**Status:** built and always on with the weather rules since 9 Nov 2026. Dave's no-flags rule removed the `weather.fog.on` switch, and with it the old flat `mist_sight` and `mist_spook` cuts. Static checks only; tests run on Dave's PC.
**The knob:** how thick the look draws the valley fog. Kathleen's full valley fog is 95% white at about 220 m. Jamie gives 50 to 180 m in a valley floor at its height. A thicker look (a larger `MIST_INSIDE_THICK`, mirrored by `Weather.VIS_MIST_THICK`) makes the spook and wolf rules bite.
**Decided:** coordinator, 8 Nov 2026, from MikeW's requests. Dave may revert.

## 1. What happens today (read from the code on the animal stack, 8 Nov; not tested)

- The shared weather carries `mist` (0 to 1, the valley fog's strength) and `mist_top_m` (the top of the layer above sea level). Both come from `weather.gd`, so the server already has them.
- `server_animals._read_weather` keeps `mist` only, and `weather.on` (on) uses it in two flat cuts that ignore distance and height:
  - sight × (1 − `mist_sight` 0.6 × mist);
  - spook and alert distance × (1 − `mist_spook` 0.3 × mist).
- So a deer on a hill above the fog is as blind as one in it. A deer 10 m away in dense fog sees no better than one 300 m away.
- Wolves shadow a player at `stalk_m` 25 m in every weather. Crows sit on a perch only for `perch_s` (and stay up in a storm). Deer keep their clear-day hours.

## 2. What the player will notice

- **In fog you can get closer.** A deer cannot tell you from a stump past half the visibility. In full valley fog (V about 220 m) it knows you by eye only inside about 110 m, and sees you clearly inside 55 m. Past that it has only hearing and smell (`senses.blind_factor` 0.35), so a player 100 m off seems about 200 m off. That cuts the far alerts and the long-range noticing. A deer's 30 m spook range lies inside the 55 m it still sees clearly, so the spook itself is unchanged in the game's fog today. It shrinks to hearing and smell only where V drops under about 120 m, and the look's thickest is about 170 m.
- **On the hill above the fog sea**, animals see as on a clear day.
- **Wolves come closer** in dense fog: a shadowing pack closes from 25 m to half the visibility (never under 10 m). That takes V under 50 m, so with the look's numbers today (thickest about 170 m) the pack keeps its 25 m. The rule is ready for denser fog.
- **Birds sit it out.** In thick fog (V under 250 m, which is the look's full valley fog):
  - crows stay on their perch;
  - songbirds, grouse and other "bird" role animals hardly move;
  - geese, ducks and seabirds sit where they are.
- **Deer stay out later.** On a foggy morning they keep their dawn hours up to 1.5 game hours longer, and they graze along the wood edge rather than in the open.
- **Herds bunch.** Stock and deer keep half their clear-day distance from the herd's centre, and wander half as far.

## 3. The visibility at an animal

`fog_v(pos)` gives the visibility V in metres at a point. It comes from `Weather.visibility_m(state, height_m)`, a new shared function, so the server and the client's look agree on one V.

- **The rule** is the one Kathleen's `weather_look.gd` draws its fog by (#724, `visibility_of_density`). Koschmieder with a 5% threshold gives V = 3 / extinction. The extinction is the clear haze (0.0009 per m, `LookSettings.FOG_DENSITY`) times 1 + 5 rain + 4 snow + 3 storm + 14 × how deep the point is in the valley fog, at most 20 times.
- **How deep the point is in the fog** is `mist` eased over ±6 m across `mist_top_m`, the same ease as the look (`valley_fog.md`).
- **Numbers:**
  - clear air: about 3.3 km;
  - mist 0.6, deep inside the layer: about 355 m;
  - full valley fog: about 220 m;
  - the thickest (fog plus heavy rain): about 170 m.
- **Rain and snow** thin the view everywhere, inside the fog or not.
- **With no animal position:** the activity, wander and herd rules (4 to 6) use the valley fog's own V deep inside the layer, from `mist` alone, so heavy rain without fog does not trigger the fog rules.
- **Sea fog** (#608) is not in the shared weather yet. When it is, it joins this rule and nothing here changes shape.
- **The constants are copied.** `weather.gd` keeps them as `VIS_HAZE_DENSITY`, `VIS_MIST_THICK`, `VIS_MIST_EDGE_M` and `VIS_THICK_MAX`, beside the look's own. If the look changes, these change with it; better, the look could read them from `weather.gd` (Kathleen's call).

## 4. The rules

All of these replace the old flat `mist_sight` and `mist_spook` cuts, which were deleted on 9 Nov 2026, so fog is never counted twice.

1. **Sight** (Jamie lesson 1: recognise at ½ V, detail at ¼ V). The sight share from the line-of-sight test is multiplied by a fog share:
   - 1 out to V/4;
   - falling straight to 0 at V/2;
   - 0 beyond.
   The animal's clear sight is unchanged inside V/4, so this is min(clear range, ½ V). At 0, `_sense_factor` already falls to `blind_factor`: only hearing and smell are left.
2. **Spook range falls to hearing and smell.** This needs no new number. A player the animal cannot see is sensed at `blind_factor` of the distance, times the wind's scent rule, so the spook range shrinks to what it hears and smells. Hearing is not cut. The brush noise and `always_notice_m` 8 m stay as they are.
3. **Wolves close in to half V.** The shadowing ring is min(`stalk_m`, max(V/2, `wolf_min_m` 10)) at the player. They still lose the player at `lose_m`; they follow by scent.
4. **Birds sit it out** while V at the bird is under `sit_below_m` 250. Jamie: most birds land and sit out thick fog, which she gives as 50 to 180 m in a valley floor at its height. The look draws that full valley fog at 220 m, so the threshold sits just above it (judged):
   - a perched bird (the crow) does not come down, as in a storm;
   - "bird" role animals and the `sit_species` list (goose, duck, seabird) wander × `bird_wander_x` 0.15;
   - a bird still flies when a player comes inside its spook range, which is itself shorter in fog.
5. **Deer late and at the wood edge** (Jamie: the dawn retreat is delayed 1 to 2 hours, near the wood edge). While the fog layer's own V is under `deer_v_m` 1,000 (activity and wander have no animal position, so rules 4 to 6 use the layer's V; sight and wolves use V at the point):
   - for "deer" role animals the hours from 08:00 to 08:00 + `deer_late_h` 1.5 count as "dusk" for their activity;
   - each new grazing target is tried up to `edge_tries` 3 times. The first one that is open ground with tree crowns within `edge_m` 15 m (four directions) is kept, otherwise the last one.
6. **Herds bunch** (Jamie's table: herd spread halved, they move less). Under the same V, for "stock" and "deer" role animals, `herd_pull_m` and the wander distance are × `herd_x` 0.5.

## 5. Data (`animals.json` `weather.fog`)

```
"fog": {"on": false, "wolf_min_m": 10.0,
        "sit_below_m": 250.0, "bird_wander_x": 0.15, "sit_species": ["goose", "duck", "seabird"],
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
  - clear air gives 3,333 m;
  - mist 1 inside the layer gives 222 m;
  - a point 20 m above `mist_top_m` gives 3,333 m;
  - mist 1 with rain 1 gives the cap, 167 m.
- **Sight:** at V 120, the fog share is 1 at 25 m, 0.5 at 45 m and 0 at 70 m.
- **Sight in full valley fog:** a player 100 m off is sensed at about 200 m; in clear air at 100 m.
- **No switch:** the test checks that the fog rules are on, with no `on` key (9 Nov 2026).
- **Wolves:** the ring is 25 m in clear air and in full valley fog, 15 m at V 30, and never under 10 m.
- **Birds:** a perched crow in full valley fog does not come down after its timer, and in clear air it does.
- **Deer:** at 09:00 in fog a deer's activity period is "dusk", and in clear air it is "day".
