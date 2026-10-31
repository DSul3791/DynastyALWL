# Flora system handover (flora session, 2026-10-31)

Branch `claude/flora-density-v2` (merged into DailyDev by the moderator in steps). One page: what is where.

## Placement (server and tools) — `src/worldgen/runtime/flora_placer.gd`, `data/tables/flora.json`
- **Rows**: one flora.json entry per species: `per_hectare` by biome, `moisture`, `max_slope_deg`, `altitude_m` (real metres: the baked tile heights were mis-decoded until the 31 Oct fix), `season` (the in-season rule reads it), `yields`.
  `future: true` = no model yet: never placed, never built (fig, olive, pomegranate, mango, orange, lemon).
- **Densities**: `TREE_DENSITY` 4.6 (about 150 trees per hectare in temperate forest), `SHRUB_DENSITY` 3; `data/tables/tile_rules.json runtime_flora`.
- **Patch rules** (`"patch": {every_m, chance, count, radius_m, scale, spacing_m, by_biome}`): clumps. `by_biome` is decided per patch (never plant by plant). Used by tall grass (patches of 14-20), the 13 thicket shrubs (5-19 per clump), moss, mushrooms, berry plants.
- **Shore rule** (`"shore": {within_m, biomes}`): reeds, riverbraid, watercress, mint, alder, willow only near water (tile water cells or the settled water) in the listed biomes.
- **Starter clearing**: no tree or shrub within 10 m of the spawn point or 6 m of an NPC marker (soft 5 m edge); spawn point in `src/shared/spawn_point.gd`, markers in `data/npcs/markers.json`.
- **Starter orchard**: 12 fruit trees in rows 60 m east, 45 m south of the spawn (`ORCHARD_*`), planted first.
- **Layout version** `flora_layout.gd` (17): bump on any change that moves plants; saved removals and harvest marks are cleared under another layout.

## Harvest, season and fruit
- **In-season rule** (`src/shared/gather_rules.gd`): `in_season`, `hidden_out_of_season`; herbs, flowers and mushrooms out of season are not drawn (not grass, ferns, reeds, woody plants, berry bushes) and offer no prompt; the server refuses out-of-season gathers quietly (`server_items.gather`).
- **Fruit store** (`drops.json fruit_tree`, `server_items.gd` `_gather_fruit_tree`, `flora_fruit` rpc, `harvest.gd`, `flora_view.gd fruit_taken`): per tree store scaled by size and id, picks limited by weight, refill each season, saved in `world_items.json` key `fruit`; prompt "Press E to pick X (N left)"; drawn fruit thins in five levels (Kathleen's fruit shader, instance custom alpha).
- **Varieties**: 13 temperate rows (apple early/summer/autumn/keeping/cooking, pear x3, sour cherry, plum, damson, quince, medlar), `"seasonal": true` rows are built per season. Calendar is by season name; `data/look/seasons.json` (looks) and Sal's `data/items/seasons.json` (items).
- **Seasons in code**: hardwood leaf colour by season (`flora_view._leaf_tint`), grass tint and blade share (`grass_view.set_season`), preview with `--flora-season=NAME` or `--flora-day=N`.

## Client and cost (`src/flora/flora_view.gd`, `src/client/grass_view.gd`, `src/client/ambient_critters.gd`)
- **Colliders**: trees by trunk; shrubs 0.9 m and taller get a stem cylinder, a clump of 4+ shares one; fallen logs of 4 m and more get a capsule.
- **Quality shares**: shrub and plant parts are one per chunk up to High; shrub share drawn Low 0.4, Medium 0.6, High and Ultra 1.0.
- **Ground grass** thins (30 percent kept) within 2 m of tall-grass patch plants so the plumes stand out.
- **Critters** (butterflies, bees, dragonflies, birds, fireflies): client only, by zone, season, hour, rain.
- **Measured cost** (RTX 2060 SUPER, High, quiet PC): spawn draw calls +10 percent, forest meadow +21 percent, primitives about x2, frame time +1.4 ms (about 100 fps).

## Animals (`src/stream/server_animals.gd`, `data/animals/animals.json`)
Biome weights and hour chances per species (`biomes`, `active`), near spawns 60-120 m (`near_share`), exclusion circle on the real spawn, `model: false` rows are never spawned, off-hours animals leave when no player is within 40 m.

## Tools and tests (all headless: `godot --headless --path . --script res://src/worldgen/tools/NAME.gd`)
Tools: `flora_density.gd` + `tools/flora_density_report.py` (counts per km2 by biome), `flora_near.gd` (nearest plant from a spot: first-hour table), `flora_water.gd`, `flora_diag.gd`, `flora_tris.gd` (triangles per model), `orchard_site.gd`; `tools/world_alive.sh` (Tyler's per-biome table).
Tests: `test_flora_density` (placement, thickets, orchard, seasons, future guard, colliders), `test_fruit_tree`, `test_animal_spawn_wiring`, `test_ambient_critters`, plus the standard flora and animal lists (`test_flora_close`, `test_flora_budget`, `test_server_items`, `test_spawn_dry`, `test_first_hour`, `test_wolves`, `test_animals`...).
Pictures and numbers: `E:/Software/godotDev/DynastyALWL_Evidence/flora_density5` to `flora_density8` (before/after spawn, meadow, coast, orchard, tall grass).

## Open
Month-level fruit calendar; models for the future fruit trees, lichen and vines, ferns near streams; orchards at the old town; real-game check of the pick prompt and the thinning tree; elder thickets (88 percent in clumps of 4+, target 90); draw-call growth at the meadow (+21 percent) if a weaker PC needs it: far-tree merging, then lower `TREE_DENSITY`.
