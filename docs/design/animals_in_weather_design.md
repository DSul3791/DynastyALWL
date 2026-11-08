# Animals in weather: server behaviour

**Owner:** Steve (server). **Client:** MikeW (clips and poses). **Status:** design, 8 Nov 2026.
**Research:** `docs/knowledge/animals-in-weather.md` (Jamie, #639). Lesson numbers below are that page's. Wind speeds use the mapping in `wind-over-terrain.md` (#637): m/s = 20 × wind^1.3.
**Code:** `src/stream/server_animals.gd`, `src/stream/server_wolves.gd`, `data/animals/animals.json`.

## 1. What is there today

`ServerAnimals.tick` reads the weather dictionary through `wind` each tick, but it keeps only `wind` and `wind_dir`, and it uses them only for scent (`_sense_factor`). Nothing reacts to rain, snow, a storm, fog, the temperature, or what the weather will do next. (The bed and closed-room factor bug Jamie found there is fixed in #643.)

The weather is `src/shared/weather.gd` `state(seed, game_s, group, ...)`, a pure function of game time. So the server can look ahead without storing anything.

## 2. The rule

Weather tilts what an animal does. It never adds a new way to die or a new attack, and never scripts a "sign":
- cows lying down before rain is a myth (lesson 1), so it is never used;
- every number is a multiplier on rows that already exist (spook distance, activity, wander, rest), so a calm day is exactly today's behaviour;
- the look to get right is a gale: every animal in the open faces about the same way.

## 3. One weather read per tick

Every tick the server builds `_wx`:
- `rain`, `snow`, `storm`, `wind` and `wind_dir` from today's dictionary;
- `mist` from Jamie's valley fog (#603) when it lands, 0 until then;
- `air_c`, the one live temperature from #620 (`temp_c` until that lands).

A new callable, `weather_ahead(hours) -> Dictionary`, is wired by the server to `WeatherScript.state` at now + hours. Once a game minute, the server samples it every 3 h from 12 to 24 h ahead. `_storm_ahead` is true when any sample has `storm` 0.5 or more. That is the falling pressure the birds feel (lesson 4). Tests set `weather_ahead` directly.

## 4. Roles (data, per species)

Each species row gets `"weather": "<role>"`. A row without one behaves as today.

| Role | Species now | Behaviour (sections 5 to 9) |
|---|---|---|
| `deer` | deer, elk, moose, chamois, pronghorn | poor coats: always seek cover in rain and storms; graze into the wind; down to lower ground and conifers in cold and snow |
| `stock` | horse, donkey, cow, goat, buffalo, wildebeest, camel, bighorn, mountain_goat | seek cover in rain half the time (stable per animal); in a gale turn their rumps to the wind and drift downwind; shade at midday in heat |
| `small` | rabbit, rat, mink, raccoon, beaver | stay in burrows in rain and wind; out in light rain or just after it |
| `bird` | songbirds, crow, pheasant, grouse, guineafowl, chicken, goose | perch in cover in heavy rain; feed more before a storm; ground birds feed right after rain |
| `hunter` | wolf, fox, lynx, puma, lion, leopard, tiger, hyena, bear, black_bear | a little more active in wind; face into the wind when they travel; wolves move less in snowfall |
| `bat` | none yet (no model) | stays in above wind 0.35 or in rain heavier than drizzle |

Goblins, the dog companion, pups and orphans keep their own rules: den life, companion step and pup step run before any weather rule.

## 5. Wind (step 1)

- **Prey are jumpier** (lesson 3: vigilance about doubles). For `deer`, `stock`, `small` and `bird`, spook_m and alert_m are multiplied by `lerp(1, 1.4, clamp(wind / 0.6, 0, 1))`. That is ×1.2 at wind 0.3 and ×1.4 at 0.6.
- **Hares and rabbits are less active** (lesson 3). For `small`, the activity chance is cut by 25% above wind 0.25 (about 3.5 m/s) and by 65% above 0.35. When a grazing timer runs out, a `small` animal with a burrow near goes down with that chance (state `HIDDEN`, its usual hide time).
- **Hunters hunt more** (lesson 3, lynx +25%): for `hunter`, the activity chance is ×1.25, up to 1.
- **Into the wind** (lesson 2): in wind under 0.6, a `deer` or `hunter` picks its next wander target within ±40° of upwind 70% of the time. A grazing animal faces the way it last moved, so it faces into the wind with no new pose.

## 6. Rain and storms (step 1 for numbers, step 2 for cover)

Rain means `rain` 0.4 or more.
- **Grazing drops** (lesson 1: −62%). For `deer` and `stock`, 60% of each graze becomes a new state `HUNCH` (20): standing still, head low, ears back, tail clamped. The rest stays `GRAZE`. Wet animals never lie down (lesson 1). Wild animals have no lying state today, so this only matters once one is added.
- **Cover within 100 m** (lesson 2, step 2). A `deer` always, and a `stock` animal half the time (by its id), looks once for cover when the rain starts:
  - it samples 8 directions at 25, 50, 75 and 100 m and takes the nearest point under tree crowns (`canopy`);
  - a crag's lee joins this when `wind-over-terrain.md` gives a lee test;
  - its `home` moves there, and the old home is kept as `dry_home`;
  - one game hour after the rain stops, it walks back.
- **`small`:** in burrows in rain over 0.6. They come out in light rain and for 30 game minutes after it stops, with activity ×1.3 then.
- **`bird`:** perch in cover in rain over 0.6 (their activity ×0.3). Ground birds get activity ×1.3 for 30 game minutes after rain.
- **A storm or snowfall** (`storm` 0.5 or more, or `snow` 0.5 or more) beds most animals down: activity ×0.3 and wander_m ×0.3. Back to normal within a game day (lesson 5), with a feeding burst the morning after (activity ×1.3 until noon).

## 7. Gales (step 2)

A gale is `wind` 0.6 or more, or `storm` 0.5 or more.
- **`stock` turn their rumps to the wind and drift** (lesson 7). Their wander targets go downwind, at about 3 m per game minute. Their heading is set to `wind_dir`, the way the wind blows toward.
- **`deer` go into woodland** (the cover search above), or failing that, to lower ground (the lowest of the 8 samples).
- **Wild bison or aurochs, if added, face into the storm and walk.** This is a role flag `faces_storm` on the row.

## 8. Before a storm (step 1)

When `_storm_ahead` is true:
- `bird`, `small` and `deer` feed about 1.4 times as much (lesson 4). Their rest is skipped by day (`resting()` returns false between dawn and dusk), and their activity is ×1.4, up to 1.
- Insects are quieter. That is a client and sound matter: the server sends `storm_ahead` in the weather it already shares.

## 9. Snow and cold (step 3)

- **Wolves in snowfall** (lesson 5) travel shorter and slower. In `snow` 0.3 or more:
  - pack walk and trot speeds ×0.6 and roam radius ×0.5 in `server_wolves.gd` `_walk`;
  - the chase is unchanged;
  - back to normal when the snow stops (within a day, lesson 5).
- **`deer` in the cold** (lesson 2): below −5 °C `air_c` or with lying snow, their wander targets pull toward conifer stands (`biome_at` evergreen rows) and lower ground.
- **Cold calm nights:** animals bed on slopes a little above the valley floor. This needs the cold-air pooling mask (Jamie's R6 note), so it waits for it.
- **Heat** (summer, `air_c` above 22 °C): `stock` seek shade at midday with the same cover search (lesson 8).

## 10. Fog (step 1)

Prey lean on hearing and smell. With `mist` above 0:
- `_sight` is cut by `1 − 0.6 × mist`;
- spook_m is cut by `1 − 0.3 × mist`.

The wind's scent and the undergrowth noise are untouched, so a downwind player is still smelled.

## 11. The client (MikeW)

- **New state 20 `HUNCH`:** standing still, head low, ears back, tail tucked. Without a clip it falls back to idle.
- **Gale heading:** `stock` in a gale face downwind (their heading is sent as it is today), so no new clip.
- **`storm_ahead`:** goes in the weather the server already sends, for insect sounds and low swallows.
- **Bats:** wait for the model and the role rule above.

## 12. Steps (each its own PR, design first, flags in animals.json `weather.on`)

1. Read `_wx` and `weather_ahead`; roles in data; the numeric tilts: wind jumpiness, small animals and hunters in wind, before a storm, storm bed-down, fog. **Test:** `test_animals_weather`, run against fixed weather dictionaries.
2. Rain cover search, `HUNCH`, gales (rumps to the wind, drift, deer to woodland).
3. Wolves in snowfall, deer in cold and snow, stock in shade in heat.

## 13. Never-see checks (from the knowledge page)

`test_animals_weather` checks each of these on fixed weather:
- a herd grazing in the open through a downpour;
- stock in a gale facing every which way;
- wolves pacing far and fast in a blizzard;
- hares as busy on a windy day as on a calm one;
- any weather-scripted lying down.
