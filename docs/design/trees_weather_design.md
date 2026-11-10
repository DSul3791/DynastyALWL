# Trees in weather: sway by wind, bare winter broadleaves, snow that holds and sheds

**Owner:** Kathleen. **Status:** design, 8 Nov 2026.
**Reads:** Jamie's research page `docs/knowledge/trees-in-weather.md` (#675): "Crown motion by wind", "Leaf fall by season", "Snow on trees" and never-see checks 1 to 3. Wind in m/s = 20 x wind^1.3 (`wind-over-terrain.md`, #637).

Three separate PRs, each behind its own switch, which stays off until Dino's pictures:

| Part | Switch | Base |
|---|---|---|
| A. Sway by wind | `--tree-wind` | this note |
| B. Bare broadleaves in winter | always on (Dave, 8 Nov) | this note |
| C. Snow that holds and sheds | `--tree-snow` | #607 (snow on branches) |

## 1. What is wrong today (read from the code on main)

- **Sway ignores the wind** (never-see 1).
  - Every flora shader moves the crown with two fixed sines, `sin(TIME*0.9) + 0.4 sin(TIME*1.9)`, times a fixed `sway` (broadleaf 0.012, conifer 0.006). That is about 0.3 m at the top of a 20 m tree, all the time.
  - A calm and a gale look the same.
  - The flutter of the leaves is fixed too.
- **Winter broadleaves keep a full crown of brown leaves** (never-see 2).
  - `_leaf_tint` turns the leaves brown in winter.
  - Only species whose `flora.json` row says `"seasonal": true` are rebuilt per season. Those are the fruit trees, rowan and the bushes.
  - Oak, beech, birch, alder, willow, maple, sweet chestnut and walnut all have a bare winter build in `tree_builder.gd` (`season == "winter"`), but it is never asked for.
- **Snow on trees follows the ground's snow** (#607).
  - #607 whitens crowns and branches by the ground's snow memory.
  - Jamie: conifers hold about half a snowfall for weeks in frost and shed it within hours in a thaw or in wind over about 8 m/s. Bare broadleaves hold only a thin line on top of the branches.
  - Ground snow lies on through a thaw day. Tree snow should not (never-see 3).

## 2. Part A: sway by wind (`--tree-wind`)

### The amount

Wind drag goes with the square of the speed, so the sway is scaled by

`k(u) = smoothstep(1.5, 3.0, u) x (u / 12)²` (u in m/s, the world wind, capped at k = 7).

| Wind | k | Top of a 20 m broadleaf (today's 0.012 x 20 m x k) | Jamie's table |
|---|---|---|---|
| under 2 m/s | 0 | still | still |
| 5 m/s | 0.17 | 0.04 m | none, twigs move |
| 8 m/s | 0.44 | 0.1 m | slight lean of young trees |
| 12 m/s | 1.0 | 0.24 m | old trees 0.1 to 0.3 m |
| 17 m/s | 2.0 | 0.5 m | 0.3 to 1 m |
| 25 m/s | 4.3 | 1.0 m | 1 to 2 m, hard gust swings |

### Rhythm and lean

- **Rhythm:** the two fixed sines become one main sway at 0.26 Hz (Jamie: a mature tree sways at 0.2 to 0.5 Hz), with a slow gust envelope (0.6 + 0.4 sin at about 0.06 Hz, a different phase per place). It follows gusts rather than ticking.
- **Lean:** the crown also leans downwind, by half the sway amount, along the wind's heading (`wind_dir`, where it blows toward). So the swing is about a bent mean, not about upright.

### Flutter and stiffness

- **Flutter:** the leaf flutter is scaled by `0.1 + 0.9 x smoothstep(2, 8, u)`. It is near still in a calm and constant from about 8 m/s.
- **Stiffness:** each material's own `sway` stays as its stiffness. Conifers move half as much as broadleaves, palms more, and grass the most.

### How it is fed

- **Shared uniforms:** every flora shader that sways (leaves, bark, flower heads, stems, reeds, herbs) gets the same three uniforms, `wind_k`, `wind_flutter` and `wind_to` (vec2). They must all move together, or the crowns would come off their trunks.
- **One setter:** `FloraView.set_wind(wind_ms, heading)` writes them to every flora material once a second. `weather_look.gd` calls it with the eased world wind, so forced shot weather counts.
- **Switch off:** the uniforms keep their defaults (k = 1, flutter 1, no lean), and the shaders take the old two-sine path. Today's look is kept exactly.

## 3. Part B: bare broadleaves in winter (always on since Dave's 8 Nov ruling)

- **Which species:** with the switch, the temperate deciduous broadleaves are rebuilt per season like the fruit trees, so winter draws their bare build. Those are oak, beech, birch, alder, willow, maple, sweet chestnut, walnut and the witness tree.
- **Which stay leafy:** evergreen broadleaves keep their leaves. Those are mahogany, mangrove, acacia, olive, orange, lemon, mango, fig, pomegranate and the fantasy evergreens.
- **How:** the list is a const in `flora_view.gd` (`DECIDUOUS`). `set_fruiting` already marks `"seasonal"` rows. The switch adds these names, so `_start_seasonal` builds their winter models on its worker, once per season change.
- **Leaf tint:** the brown winter tint stays for any broadleaf not in the list, so it is unchanged.
- **Cost:** about ten more species' models built on the worker at each season change, the same path the fruit trees take today. They are never picked, so only the plain build is made (no stripped one).
- **Far trees:** the impostor cards are captured in leaf, so in winter a deciduous species past the impostor distance draws its bare far model instead of its card. Bare far models are light, but David4's flora budget run should confirm the draw count in winter.
- **Left for later:** autumn leaf fall within the season (Jamie: most leaves come down in a few days of wet wind from mid-autumn), and young beech and oak keeping dead leaves.

## 4. Part C: snow that holds and sheds (`--tree-snow`, on #607)

A crown snow memory of its own, beside the ground's, one value per crown kind:

- **Conifer:**
  - it rises with falling snow to at most 0.5 of the ground's full cover (Jamie: about half a snowfall is caught);
  - in frost it holds for weeks, losing 1 % a game hour;
  - above 0 °C, or in wind over 8 m/s, it sheds within about 3 game hours.
- **Bare broadleaf:** at most 0.35 (a thin line on top of the branches), shedding the same way.
- **Broadleaf in leaf** (an early or late snowfall): it loads like a conifer.
- **The ground under a conifer crown:** shallower, a little over half the open depth. That is left to the ground snow work.
- **How it is fed:**
  - `weather_look.gd` steps the two values with the game clock and calls `flora.set_snow_kinds(conifer, broadleaf)` instead of `set_snow(ground)`;
  - the conifer materials get one value and the broadleaf and bark materials the other;
  - with the switch off, #607's `set_snow(ground)` is used, as now.

## 5. Never-see checks

1. Trees swaying the same in a calm and a gale. Test (`test_tree_sway.gd`): `k(1) = 0`, `k(12) = 1`, `k(25) > 4`, and every swaying material gets the same wind.
2. Full green or full brown crowns on oak, beech or birch in deep winter. Test (`test_bare_winter.gd`): the deciduous names are seasonal and the evergreens are not.
3. Snow on conifers through a thaw day. Test: the crown snow after 3 thaw hours is under 0.1. Snow piled thick on bare twigs: the bare broadleaf cap is 0.35.

## 6. Pictures (Dino, switch on and off)

The shot format is `src/debug/shot_runner.gd`: `name:x,agl,z,yaw_deg,pitch_deg,hour[,weather]`. Yaw 90 faces west (-X). One camera for all parts, near the spawn (53296, 68080):

- **Camera:** x 53326, z 68056, 4 m above the ground, yaw 90 (looking west toward the spawn), pitch -3, hour 12.
- **If no broadleaf stands 20 to 40 m ahead in the first frame:** run `flora_near.gd -- --at=53296,68080 --species=oak,beech,birch,alder` and put the camera 30 m east of the nearest stand, same height, yaw and pitch. Send me the numbers used.
- **Far check (B only):** x 53726, z 68056, 40 m up, yaw 90, pitch -4: the same stand from 400 m, where the far images are drawn.

### A. Sway by wind (`--tree-wind`, then the same run without it)

Two shots of each weather, back to back, so the pair shows the motion:

`--shots="wind_clear_1:53326,4,68056,90,-3,12,clear;wind_clear_2:53326,4,68056,90,-3,12,clear;wind_rain_1:53326,4,68056,90,-3,12,rain;wind_rain_2:53326,4,68056,90,-3,12,rain;wind_storm_1:53326,4,68056,90,-3,12,storm;wind_storm_2:53326,4,68056,90,-3,12,storm"`

- `clear` (calm): the two frames match.
- `rain` (wind 0.3, 4.2 m/s): leaves moved, trunks still.
- `storm` (wind 0.8, 15 m/s): crowns swung, leaning downwind.

### B. Bare broadleaves in winter (`--bare-winter --flora-day=320`, then `--flora-day=100`, then both again without the switch)

`--shots="bare_near:53326,4,68056,90,-3,12,clear;bare_far:53726,40,68056,90,-4,12,clear"`

- Day 320 with the switch: bare branches near and far. Day 100: full crowns.

### C. Snow that holds and sheds (`--tree-snow --flora-day=320 --shot-settle=460 --shot-admin`, then without the switch)

`--shots="snow_on:53326,4,68056,90,-3,12,snow;snow_after:53326,4,68056,90,-3,12,clear"`

- `snow_on`: a spruce and an oak in frame, snow on the conifer crown, a thin line on the oak's branches.
- `snow_after` (460 s is about 3 game hours): with the air above 0 °C (F3 line) the conifer is clear. In frost it still holds snow. The crowns are never whiter than the ground.
