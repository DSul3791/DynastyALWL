# Cave air by depth and season

**Owner:** Steve (warmth in `src/stream/server_items.gd`, the helpers in `src/shared/cave_climate.gd`, the numbers in `data/items/warmth.json` `cave_climate`).
**Research:** Jamie #709, `docs/knowledge/underground-climate.md`.
**Decided:** coordinator, 8 Nov 2026. Dave may revert.
**Builds on:** #667, the flat cave at the year mean. This follows on top of #705 and leaves #667 as gated.

## What the player will notice

- **Deep in a cave** the air is the year mean at its height: 5.5 °C at cave 8002, all year and all day. This is unchanged from #667.
- **Near the mouth** the outside air still reaches in. It fades to the deep air over a band of metres that depends on the season and on which way the cave runs.
  - **A cave that climbs from its mouth, like 8002:** summer warmth reaches far (gone by 60 m), while winter cold stays near the mouth (gone by 20 m).
  - **A cave that drops from its mouth (a pit):** the reverse. Winter cold sinks in and stays.
- **The night chill** at the mouth is half the outside one.
- **There is a small draught** in the first 10 m, and none past it. Storms change nothing in caves this size.
- **Drying:**
  - past 20 m, only a fire dries you;
  - at a winter mouth, where the dry outside air comes in, sheltered drying runs at half the cover rate;
  - a summer mouth is wet and does not dry you.

## The rule

- **The air:** `cave_air = lerp(outside − (1 − day_swing_kept) × day_part, deep, smoothstep(near_m, reach_m, depth_m))`, where:
  - `outside` is the warmth tick's own air (the one temperature, less the lapse at your height);
  - `day_part` is `daily_range_c / 2 × day_shape(hour)`, from `Weather.day_part_c`;
  - `deep` is `Climate.year_mean_c` at your height.
- **The bands** come from Jamie's table, `[near_m, reach_m]`. Summer means the outside is warmer than the cave.

  | Cave runs | Summer | Winter |
  |---|---|---|
  | Rises from the mouth | 10, 60 | 5, 20 |
  | Drops from the mouth | 5, 20 | 10, 60 |
  | Level or not known | 10, 40 | 10, 40 |

- **Which way it runs** comes from the grade from the entrance node to the next node in. Over +5% it rises, under −5% it drops, and otherwise it is level. The tile data lists each mouth as `cave_mouths`.
- **depth_m** is the straight distance to the nearest mouth. This is a first pass: bends are not counted, so the "past the second bend" rule falls back to distance.
- **The draught:** 0.06 m/s for each degree between outside and cave, at most 0.6 m/s, inside the first 10 m. It goes through the shared mapping, m/s = 20 × wind^1.3, so 0.45 m/s is a game wind of about 0.05: a few tenths of a degree of chill.
- **Drying:**
  - with shelter, none past `dry_mouth_m` 20;
  - inside it, `winter_dry_share` 0.5 of the cover rate when the outside is 3 °C or more colder than the cave;
  - otherwise none.
- **Not changed:**
  - a cave pool's water stays at the deep air (#667);
  - the optional ±0.5 °C half-year-late swing of deep air is left flat, which Jamie says is fine.

## Where a torch is needed

That is the lighting look (Kathleen, #669), not warmth. Jamie's table, the bend rule and "8002's back two-thirds always" are passed to her.

## Data

All numbers are in `warmth.json` `cave_climate`. Removing the block gives the flat cave of #667 back.

## Tests

Static checks only in the cloud, per Dave's law. New `test_cave_climate.gd`:
- the bands and grades;
- the blend at the mouth, the middle and deep in, for summer and winter in a rising cave and a pit;
- the day swing halved;
- the draught inside and past 10 m;
- drying at a winter mouth, a summer mouth and deep in;
- in the server's warmth, a winter mouth colder than deep in and a summer mouth warmer;
- with no `cave_air` callable, the flat #667 cave.
