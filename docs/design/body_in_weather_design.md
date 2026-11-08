# The body in weather: slow drying, wet in wind, cold stages, late sickness

**Owner:** Steve (warmth in `data/items/warmth.json` and the warmth tick in `src/stream/server_items.gd`; sickness in `data/items/sickness.json`, `cooking.json raw_sick` and the eat path).
**Research:** [body-in-weather.md](../knowledge/body-in-weather.md) (Jamie, #703).
**Decided:** coordinator, 8 Nov 2026, under Dave's "agree to all recommendations". Dave may revert any of it.
**Status:** design. The code comes in the next PR, server side only, behind two flags that are off by default. With both flags off, nothing changes.

## 1. What the player will notice

- **Wet clothes stay wet.**
  - By a fire you dry from soaked in about 2.5 game hours (6 real minutes), not 10 game minutes.
  - Under a tree or roof you dry in about 10 game hours (25 real minutes).
  - Rain that stops does not dry you, and neither does a cave.
- **Wet plus wind is the killer.**
  - Soaked on a windy hill, the cold bites about two and a half times as hard as dry in still air.
  - Soaked in still air it bites one and a half times as hard, the same as today.
- **The cold comes in three stages, and the third one is quiet.**
  - Mild: you shiver.
  - Moderate: you are freezing, your hands are slow and health drains.
  - Severe: you stop shivering, which is a warning, not a recovery. Your hands are very slow and health drains twice as fast.
  - Cold still never kills; health stops at 1, as Dave set on 21 Oct.
- **Sickness from raw animal food comes late and is not certain.**
  - Eating raw meat, raw fish, shellfish or a raw egg makes you sick only sometimes (for example 1 in 5 for raw meat).
  - When it does, it starts 1 to 3 game days later (1 to 3 real hours), with a line that names what you ate.
  - Plant toxins (beans, acorns, mushrooms) and rotten food still hit at once, as today, because they are toxins and act within hours in life too.

## 2. Drying (warmth.json, flag `body_703.enabled`)

The soak level stays the game's only wetness, from 0 to 1. Until clothing exists, the body counts as dressed in wool, which is the forgiving fibre in Jamie's tables.

| Where | Today (per game hour) | New (per game hour) | Soaked to dry |
|---|---|---|---|
| Within a lit fire's heat reach | 6.0 | `dry_fire_per_h` 0.4 | 2.5 game h |
| On a coal bed's 1.5 m (#685) | none | the same 0.4, once #685 and this code are both on main | 2.5 game h |
| Under a tree or roof, no fire | 1.0 | `dry_cover_per_h` 0.1 | 10 game h |
| In a cave, no fire | 1.0 (counts as cover) | 0.0, already so in #667 | never (the air is 98 to 100% humid) |
| Open air, no rain | 0.0 | 0.0 | never (Dave 5 Nov: only shelter dries you) |

- The cave rule is already in #667: cover dries you only outside a cave, using the same cave check as the cave air. The code for this design is stacked on #667 so it builds on that.
- When clothing types land, linen dries about twice as fast as wool (Jamie). That will be a per-piece multiplier on these rates, not a new table.

## 3. Wet in wind (warmth.json, flag `body_703.enabled`)

- **Today:** `stress *= 1 + (rain_mult − 1) × soak`, with `rain_mult` 1.5 (Dave's rain card). Wind only enters through the dry wind chill, `feels = air − wind × 6 °C`.
- **New:** `stress *= 1 + (rain_mult − 1) × soak + wet_wind_gain × soak × wind`, with `wet_wind_gain` 1.5. The wind here is the same sheltered wind the chill uses: roofs still cut it to 30%.

| Soak | Wind 0 | Wind 0.3 | Wind 0.6 | Jamie, soaked wool against dry and still |
|---|---|---|---|---|
| 0 | 1.0 | 1.0 | 1.0 | 1.0, 1.2, 1.4 (the dry chill covers this) |
| 0.5 | 1.25 | 1.48 | 1.7 | damp wool 1.1, 1.4, 1.8 |
| 1 | 1.5 | 1.95 | 2.4 | soaked wool 1.2, 1.7, 2.5 |

- Still air keeps Dave's 1.5 rather than Jamie's 1.2.
- **Insulation:** the wind also strips the clothes. `insulation *= 1 − 0.9 × soak × min(wind / 0.6, 1)`, so soaked in a gale the clothes keep a tenth of their insulation. This is Pugh's "nearly nothing". Today insulation is 0 (no clothes yet), so this line only matters once clothes exist. The code and its test go in now so that clothing cannot forget it.

## 4. Cold stages (warmth.json, flag `body_703.enabled`)

The warmth bar stays the one number, from 0 to 100. There is no core temperature in the vitals and no new message to the client, so no protocol bump. The stages map onto the bar like this:

| Stage | Core (MSD) | Warmth bar | What the server does |
|---|---|---|---|
| Fine | over 35 °C | 40 to 100 | nothing |
| Mild | 32 to 35 | `cold_at` 40 down to 20 | shivering (today's `shiver_effort`); no regeneration; "You are getting cold" |
| Moderate | 28 to 32 | `hurt_at` 20 down to 8 | health drains (today's `hurt_per_s`); actions take 1.5 times as long (`moderate_pace`); "You are freezing"; shivering stops at warmth 10 (`shiver_stop_at`) |
| Severe | 24 to 28 | under `severe_at` 8 | the drain doubles (`severe_hurt_mult` 2); actions take 2.5 times as long (`severe_pace`); "You have stopped shivering. Get to a fire, now." |

- **Pace:** the slowdown multiplies the existing `action_pace` (craft time and cooldowns), so a freezing player can still light a fire, only slowly. Nothing is refused, because refusing would block the cure.
- **Messages:** they keep the two-level hysteresis. Severe clears at 14 (`severe_clear`).
- **Health:** stays at a floor of 1 (Dave). Severe cold is a near-death state that the player must fix, never a death.

## 5. Late, uncertain sickness (sickness.json, flag `infection.enabled`)

### The rule

- Each raw animal food has odds (`infection.odds`, by item id).
- At the bite the server rolls once, with the world's seeded RNG, so a test can pin it.
- **On a hit,** the bite stores a pending sickness `[game seconds until it starts, hours of sickness, item id]` in the vitals (`sick_due`). The hours come from today's `cooking.json raw_sick` table. The start time is drawn in `onset_h` [24, 72] game hours.
- **On a miss,** nothing happens, and the food is not learned as "ok": it stays unknown until it makes you sick.
- When a pending sickness starts:
  - `make_sick(peer, hours)` runs as today (vomit and diarrhoea symptoms, faster asleep, medicine cures);
  - the player sees "Your stomach turns. It was the raw meat two days ago." (`say_onset`, with the food's name and the whole game days since the bite);
  - eat-once learning marks the food "harm" at that moment, so the next bite gets today's warning.
- **Persistence:** `sick_due` is saved with the vitals, and the loader keeps it (today's loader whitelists the vitals keys). Like `sick`, it counts down in game seconds only while the player is online.
- **First hour:** a new character's first-hour protection still applies. An unknown raw food in the first hour costs food and water only, with no roll.

### The odds

| Food (item ids) | Odds | Jamie's cause | Notes |
|---|---|---|---|
| `raw_meat` | 1 in 5 | mixed game: deer 1 in 15, bear or boar 1 in 3 | the meat has no species today (one item from every carcass), so it takes poultry's 1 in 5 as the middle. The coordinator's bear or boar 1 in 3 applies when butchering gives species meat (a later change to items, the butcher and recipes). |
| `seal_meat` | 1 in 3 | Trichinella, as bear | |
| `egg` | 1 in 10 | Salmonella | judged; Jamie gives no egg row |
| `shellfish`, `crab_meat` | 1 in 10 | Vibrio or norovirus | |
| sea fish: `salmon`, `herring`, `mackerel`, `smelt`, `cod` | 1 in 20 | Anisakis | |
| freshwater fish: `trout`, `perch`, `carp`, `pike`, `eel` | 1 in 30 | tapeworm | |

- **The onset is the same for all of them** (`onset_h` 24 to 72), by the decision, so the player can link the cause. Jamie's real onsets, from 8 hours to 3 weeks, are in the knowledge page if Dave wants them per food later.
- **Cooked food never rolls.** Cooking through is the cure, as in the knowledge page.
- **Plant foods stay as today:** beans, acorns, fiddleheads and mushroom caps sicken at once, every time, because they are toxins. Rotten food is also unchanged.

### Water

- The coordinator's odds are pond water 1 in 5 and spring water never.
- **This waits for the drink items** (Sonny's springs page, my queue item 6), because today drinking has no source: there is one kind of water.
- **Note for Dave:** sickness.json records his 21 Oct rule, "clean and dirty water do not exist". The pond odds would reverse that rule, so the water part is the one piece of this design to confirm with him before it is coded. The same `sick_due` path will carry it, with a source id in place of the item id.

## 6. Data

```
warmth.json  "body_703": {"enabled": false, "dry_fire_per_h": 0.4, "dry_cover_per_h": 0.1,
                          "wet_wind_gain": 1.5, "wet_strip": 0.9, "wet_strip_wind": 0.6,
                          "shiver_stop_at": 10.0, "severe_at": 8.0, "severe_clear": 14.0, "severe_hurt_mult": 2.0,
                          "moderate_pace": 1.5, "severe_pace": 2.5,
                          "say_severe": "You have stopped shivering. Get to a fire, now."}
sickness.json "infection": {"enabled": false, "onset_h": [24, 72], "odds": {"raw_meat": 0.2, ...},
                            "say_onset": "Your stomach turns. It was the %s %s."}
```

Flag off means today's numbers and today's code paths, line for line.

## 7. Tests (static checks only in the cloud, per Dave's law; run on Dave's PC)

New `test_body_weather.gd`:
- **Flags off:** soaked by a fire, the soak falls 6 an hour, and raw meat makes you sick at once (today's behaviour).
- **Drying:** soaked by a fire, 0.4 an hour, so not dry at 2 game hours but dry by 2.6; under a roof 0.1 an hour; in a cave, no change.
- **Wet in wind:** at the same air, soaked at wind 0.6 gives a lower warmth target than soaked in still air, which gives a lower target than dry. With insulation 0.5 hooked in, soaked at wind 0.6 keeps 0.05 of it.
- **Stages:**
  - at warmth 15, action pace is 1.5 times as slow;
  - at warmth 5, it is 2.5 times as slow, the health drain doubles, and there is no shiver effort;
  - health never falls below 1.
- **Sickness:**
  - with the RNG pinned to a hit, raw meat sets `sick_due` and not `sick`;
  - after 23 game hours the player is still well;
  - by 72 game hours they are sick, the onset line is said, and raw meat is now learned as harm;
  - a pinned miss leaves no `sick_due` and does not learn the food;
  - `sick_due` survives a save and a load;
  - cooked meat never rolls;
  - beans still sicken at once.

## 8. Not in this change

- Clothing types (wool, linen, leather) and drying per piece.
- Water sickness: it waits on the drink items and Dave's word (section 5).
- Species meat.
- A core temperature on the Tab screen, which would need a protocol bump.
- Jamie's coming cave and underground climate page (seasonal lag by depth, entrance gradients) will reshape cave air in the cave warmth work (#667), not here.
