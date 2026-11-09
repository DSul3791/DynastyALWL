# Drinking water step 2b: brooks by regime from the baked tiles (design)

Steve, 9 Nov 2026, agreed with Sonny the same day. Design only: no code in this note. It is build step 2b of `docs/design/drinking_water_design.md` section 7. Step 2a (#816) already made the record's ground springs spring water. This step brings in the brooks: a brook runs or dries by its regime and by the season, and below a spring it stays open for some distance in frost. The rule is in `drink_rules.gd` already. Only the data is missing at run time.

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

## 2. Design (agreed with Sonny, 9 Nov 2026)

**Rasters, not reach lists.** The record writes the channel rasters, and the bake copies them into tile sections, as it does `fresh_m`. The walk below a spring is done once, island-wide, in the record. So the values agree across tile seams with no frame, and no reach is cut at a tile edge (Sonny on #541).

**Record side (Sonny's PR):**
- `network.py` already holds the cell graph (order, rec, step). It writes three new 16 m rasters into `network.npz`: `below_spring_m`, `spring_q` and `spring_y`.
- `width_m` (bankfull, on stream cells) and `regime` are already there.
- `record.py` refines them to 8 m by nearest, as it does `regime8`, and writes them.

**Which spring governs a cell.** It is not the nearest one. A cell freezes when `below_spring_m` > 440 × x × √q (q in L/s), and x and the breeze factor are the same for every spring on a given night. So the spring that keeps a cell open is the one with the smallest d / √q, and it is the same spring every night. The rasters store that spring's d, q and y.
- **How:** walk each spring head down `rec` through stream cells, keeping the smallest d / √q at each cell. That is about 350 walks on ws580v, a matter of seconds.
- **Lakes:** a walk stops at a lake or the sea. Lake water mixes, so below a lake a cell is INF unless another spring joins it there.
- **Caves:** spring caves sit on the same R5 spring heads (the cave mouth is the head's sample). Walking from every spring head covers caves and ground springs alike, and the record never needs to know which heads become caves.

**Raster and section layout.** All are set only on channel cells (regime above 0) and 0 or "none" elsewhere:

| record raster | tile section | type | meaning |
|---|---|---|---|
| `regime` (already there) | `drink_regime` | u1 | 1 perennial, 2 intermittent, 3 ephemeral |
| `width_m` | `drink_width` | u1 | bankfull width in 0.1 m steps, capped at 25.5 m |
| `below_spring_m` | `drink_below` | u2 | channel distance from the governing spring in 2 m steps; 65535 for none |
| `spring_q` | `drink_spring_q` | u2 | the governing spring's flow in the record's log discharge code (`enc_q`). A plain 0.01 L/s step would top out at 655 L/s, and head flows are 5 × 5 sums that can pass that. |
| `spring_y` | `drink_spring_y` | i2 | the governing spring's height in 0.1 m steps (its water is the year mean there) |

- **No `dry_ok` raster.** `q_base_dry` is routed groundwater, so it is above 0 below any seep at all. Regime 1 is already the stream cells with `q_base_dry` at least `perennial_baseflow_m3_s` (1 L/s), so `dry_ok` is exactly `regime == 1`.
- The sections are zstd-compressed and almost all zero, so a tile grows by well under 1 MB.

**Game side (my PR, after Sonny's):**
- `tile_baker` adds the five rasters to `RECORD_FIELDS` and crops them into the sections. A tile with no such raster keeps none, and its drink is as today.
- `TileTerrainData` gains `drink_row(k) -> Dictionary`. It returns {} where there is no channel, otherwise {`kind` "brook", `regime`, `dry_ok` (regime == 1), `below_spring_m` (INF for none), `q_m3_s` (the spring's), `width_m`, `spring_c` (`Weather.year_mean_c(group, spring_y)`)}.
- `water_source`: at each of its five points, a sample with a drink row gives that brook row in place of today's "river" or "puddle". Lakes, salt and ground springs are unchanged, and a wet sample with no channel stays a puddle.

## 3. What the player notices

- In a dry August, an intermittent brook with no rain for a day is a dry bed ("say_dry"), and an ephemeral gully is dry except in rain. Today both are a drink wherever the settled water shows.
- On a frosty night the brook just below a spring is open to drink, and farther down it asks for an ice hole. Today every brook follows the lake's ice rule.
- Nothing changes on a lake, the sea or a ground spring.

## 4. Cost

- **The record:** rerun `network.py` and `record.py` on ws580v's chain folders, a few minutes (Sonny's estimate).
- **The bake:** the 9 tiles bake from the setup cache in about 59 s, since the record isn't in the setup key. TERRAIN_VERSION does not change, because the blocks don't, only the drink data. The tile stamp changes, so servers re-read the tiles.
- **Dino's checks:** cmp shows the old record rasters and the `.water` files unchanged.
- **Tests (on Dave's PC):**
  - `test_bake_from_record` gets a made-up network with one spring, a perennial reach and an intermittent reach, and checks the baked sections;
  - `test_drinking_water` checks `drink_row` on a stub tile.

## 5. Order

1. This note, as agreed.
2. Sonny's record PR (`network.py`, `record.py`), with the record rerun on Dave's PC.
3. My game PR (`tile_baker`, `TileTerrainData.drink_row`, `water_source`, tests), with the 9-tile rebake on Dave's PC.
