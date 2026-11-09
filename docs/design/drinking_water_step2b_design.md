# Drinking water step 2b: brooks by regime from the baked tiles (design)

Steve, 9 Nov 2026. This is a draft for Sonny to review, with no code yet. It is build step 2b of `docs/design/drinking_water_design.md` section 7. Step 2a (#816) already made the record's ground springs spring water. This step brings in the brooks: a brook runs or dries by its regime and by the season, and below a spring it stays open for some distance in frost. The rule is in `drink_rules.gd` already. Only the data is missing at run time.

## 1. What the rule needs, and what the tiles hold today

`DrinkRules` reads a brook row as {`regime`, `dry_ok`, `below_spring_m`, `q_m3_s`, `width_m`, `spring_c`}:
- `regime`: 1 perennial, 2 intermittent, 3 ephemeral;
- `dry_ok`: the row keeps baseflow in a dry August;
- `below_spring_m`: how far down the channel from its spring, INF when no spring feeds it;
- `q_m3_s`: the spring's flow, for Jamie's open length, 440 m × √(L/s) × cold;
- `width_m`: the channel, for the cooling scale;
- `spring_c`: the spring's water, the year mean at its height.

**The tiles today** hold `water_class`, `water_surface`, `flow` and `fresh_m`, plus the ground springs and cave streams in the sites. None of these say regime or distance below a spring, so `water_source` calls every wet channel cell a river or a puddle.

**The record already has** 8 m rasters for `regime` and `discharge`. It also has `network.json`, whose reaches carry 16 m rows with `bankfull_width_m`, `q_dry_m3_s` and `q_base_dry_m3_s`, and whose heads have `kind: "spring"` and `groundwater_m3_s`. The record lives only on Dave's PC, so the game must read these through the tile files.

## 2. Proposal: per-sample rasters, baked like `fresh_m`

**Recommended: the record writes the extra rasters, and the bake copies them.** Distance below a spring is a walk along the channel graph, which `network.py` already holds. Doing the walk in the record keeps it island-wide, so the values agree across tile seams with no frame. The bake then crops each raster to the tile, as it does `fresh_m`.

These are the new 8 m record rasters, set only on channel cells (regime above 0) and 0 or "none" everywhere else:

| raster | type | meaning |
|---|---|---|
| `regime` | u1 | already there |
| `dry_ok` | u1 | 1 where `q_base_dry_m3_s` > 0 (baseflow lasts through a dry August) |
| `width_m` | u1 | bankfull width in 0.1 m steps, capped at 25.5 m |
| `below_spring_m` | u2 | distance in 2 m steps down the channel from the nearest spring upstream; 65535 for none |
| `spring_lps` | u2 | that spring's flow in 0.01 L/s steps (the head's `groundwater_m3_s`) |
| `spring_y` | i2 | that spring's height in 0.1 m steps (its water temperature is the year mean there) |

- **"Nearest spring upstream"** means: walk up the reach graph, through `down` links in reverse, to every spring head that drains into the cell, and take the one with the shortest channel distance. A confluence of two spring brooks takes the nearer, which is the warmer water. This is a judged simplification of mixing, and Sonny may know a better one.
- **Tile sections:** `drink_regime` u1 (regime in bits 0–1, `dry_ok` in bit 7), plus `drink_width`, `drink_below`, `drink_spring_lps` and `drink_spring_y`. The sections are zstd-compressed and almost all zero, so a tile grows by well under 1 MB.
- **Reader:** `TileTerrainData` gains `drink_row(k) -> Dictionary`. It returns {} where there is no channel, otherwise a brook row in `DrinkRules` form. `spring_c` comes from `Weather.year_mean_c(group, spring_y)`.
- **`water_source`:** at each of its five points, a sample with a drink row gives that brook row in place of today's "river" or "puddle". Lakes, salt and ground springs are unchanged. A wet sample with no channel stays a puddle.

**The other way, not recommended:** bake per-tile lists of reach rows from `network.json`, with `below_spring_m` worked out in the bake. That means a graph walk in GDScript on every tile bake, and it puts reaches cut at tile edges into the tile list. Sonny warned against cutting reaches at edges on #541.

## 3. What the player notices

- In a dry August, an intermittent brook with no rain for a day is a dry bed ("say_dry"), and an ephemeral gully is dry except in rain. Today both are a drink wherever the settled water shows.
- On a frosty night the brook just below a spring is open to drink, and farther down it asks for an ice hole. Today every brook follows the lake's ice rule.
- Nothing changes on a lake, the sea or a ground spring.

## 4. Cost

- **The record:** six rasters from data `network.py` already has. Sonny's estimate is needed. The graph walk is small, thousands of reaches.
- **The bake:** copy and crop, like `fresh_m`, in seconds. TERRAIN_VERSION does not change, because the blocks don't change, only the drink data. The tile stamp changes, so servers re-read the tiles.
- **The rebake:** a record run (`record.py` only) plus the 9-tile bake from the setup cache, on Dave's PC. Then the settle runs, but it doesn't read these sections, so the `.water` files are compared with cmp.
- **Tests (on Dave's PC):**
  - `test_bake_from_record` gets a made-up network with one spring, a perennial reach and an intermittent reach, and checks the baked sections;
  - `test_drinking_water` checks `drink_row` on a stub tile.

## 5. Questions for Sonny

1. Can the record write the five new rasters, and is "nearest spring upstream by channel distance" the right rule where two spring brooks join?
2. Is `q_base_dry_m3_s` > 0 the right test for "keeps baseflow in a dry August", or should it be a share of the wet flow?
3. Do cave springs, whose streams leave a spring cave, count as springs for `below_spring_m`? I'd say yes, from the cave mouth.
