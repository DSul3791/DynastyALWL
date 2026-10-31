# Season data for the looks (flora session, 2026-10-31)

File: `data/look/seasons.json`. Nothing in the game reads it yet; it is the contract for Kathleen's season passes (winter grass, snow dusting, spring blossom) and for later code.

- **Calendar:** 365-day year, four equal seasons by day of year (spring days 0 to 90, summer 91 to 181, autumn 182 to 272, winter 273 to 364); a game day is one real hour. `GameClock.season()` already gives the name. `transition_days` (14) is how long colour, blossom, leaf fall and snow ease in before a season starts.
- **Biome flags:** `climate_by_biome` lists biomes with lasting snow (boreal forest, tundra, alpine meadow), a light dusting (temperate and mixed forest, grassland, heath, marsh), none (beach, tropical, desert, savanna) and biomes with no seasonal colour (tropical forest, mangrove, desert).
- **Ground:** `ground` gives grass tint and blade share per season (winter: brown, 60 percent of the blades, 40 percent dusted) and how tall grass changes (seed heads in summer, straw in autumn).
- **Per species** (`species`, generated from `data/tables/flora.json`): trees are deciduous or evergreen (broadleaf blossoms in spring for the fruit trees and rowan/hawthorn, colour in autumn, bare in winter; conifers evergreen with snow on boughs); shrubs list their fruit season; herbs list their bloom or yield seasons and `dies back` in winter unless they are listed for winter. `bare_model_exists` marks trees that already have a winter-bare model in `tree_builder.gd` (birch, willow, alder, beech, apple, rowan).
- **Not decided here:** exact snow thresholds per biome beyond the classes; blossom colours; whether winter hides the plants that die back or shows brown stubs (the file says brown stubs at 25 percent height).
