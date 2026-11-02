# World-alive targets (proposal by Tyler, 31 Oct 2026)

`tools/world_alive.sh` measures the nine centre tiles and compares each figure with the rows below; results go to `WORLD_ALIVE_LOG.md`.
A row is `| biome | metric | min | max | source |`. Biome `*` is the whole island. Change a number here, not in the tool. `-` means no limit.
Metrics: `<layer>_ha` is items per hectare (layers: trees, shrubs, berry, tallgrass, ferns, other_plants); `<species>_km2` is the game's NOMINAL stocking per km2
(what the server keeps filled around a player, not a census); `water_*_pct` is a share of cells; `river_km` is the estimated river length.

## How much to trust these numbers
These are PROPOSALS for a game that wants to look and feel real, not measurements of one real place. Confidence is marked per row: H (a published range I
checked), M (a well known textbook range I could not re-check tonight), L (my judgement for game feel). A web search on 31 Oct found only part of what the table needs
(see Sources); the rest is from general ecology references and is marked M or L. Dave or Kathleen should overrule any row.
In the game one flora "item" is one plant or one cluster as the placer makes it, so per-hectare figures for ground plants are item counts, not stems.

| biome | metric | min | max | source and confidence |
|---|---|---|---|---|
| temperate_forest | trees_ha | 150 | 600 | Swiss National Forest Inventory density classes for living trees of 12 cm and up run from 0-100 to over 600 stems/ha [1]; mature temperate stands are mostly 150-600. M |
| mixed_forest | trees_ha | 200 | 700 | as above, mixed stands a little denser. M |
| boreal_forest | trees_ha | 300 | 1200 | northern conifer stands carry more, thinner stems (Swedish NFI publishes this [2], figure not re-checked). L |
| temperate_grassland | trees_ha | 0 | 10 | open meadow with a few hedge or lone trees. L |
| heath | trees_ha | 0 | 40 | scattered pine and birch. L |
| temperate_forest | shrubs_ha | 60 | 600 | understorey shrubs (hazel, elder, hawthorn); a forest with almost none looks bare. L |
| mixed_forest | shrubs_ha | 60 | 600 | as above. L |
| temperate_forest | berry_ha | 20 | 200 | bramble and raspberry patches in clearings and edges. L |
| temperate_forest | ferns_ha | 50 | 500 | ferns are patchy, dense under closed canopy. L |
| mixed_forest | ferns_ha | 30 | 400 | as above. L |
| temperate_grassland | tallgrass_ha | 100 | 1000 | tall grass patches fill open ground. L |
| heath | shrubs_ha | 60 | 600 | gorse and juniper. L |
| * | water_fresh_of_land_pct | 1.5 | 6 | lakes and rivers cover about 2 to 10 percent of the land of temperate and northern countries (e.g. Finland about 10, UK about 2); general reference, not re-checked. M |
| * | river_km | 200 | 700 | permanent mapped streams run about 0.5 to 2 km per km2 of land in humid temperate country; the nine tiles hold about 370 km2 of land. M |
| * | water_lake_pct | 0.2 | - | the island should have lakes (Dave's vision: lakes from the fill). L |
| temperate_forest | deer_km2 | 2 | 60 | real roe and red deer densities are about 1 to 20 per km2 (Turkish reserve 0.45-2.05 [3], Scottish estates 9-13 [4], wild range up to about 20); the upper limit is 3 times that, because the game needs herds to be met. M |
| temperate_forest | rabbit_km2 | 5 | 150 | rabbits are patchy, 5 to 100 and up per km2. L |
| temperate_forest | fox_km2 | 0.5 | 10 | red fox about 0.5 to 3 per km2; times 3. M |
| temperate_forest | moose_km2 | 0.1 | 6 | moose about 0.2 to 2 per km2; times 3. M |
| mixed_forest | deer_km2 | 2 | 60 | as above. M |
| temperate_grassland | deer_km2 | 2 | 60 | as above. M |
| temperate_grassland | rabbit_km2 | 5 | 150 | as above. L |

## Sources
1. Swiss National Forest Inventory, density of living trees and shrubs (12 cm and up), classes 0-100 up to over 600 stems/ha: https://www.lfi.ch/api/data-catalog/var/1925
2. Swedish National Forest Inventory (sample tree data), for boreal stem counts: https://researchdata.se/en/catalogue/dataset/2024-639 (values not read tonight)
3. Red deer and roe deer density in Yedigoller-Yesiloz reserves, Turkey: https://avesis.iuc.edu.tr/yayin/28c23160-450b-4cec-9f9c-ddae0b2da509/monitoring-red-deer-and-roe-deer-population-density-in-yedigoller-yesiloz-wildlife-reserves-in-turkey
4. Scottish deer management group estate counts (9.6 and 12.9 deer per km2, mixed species): https://knoydartdmg.deer-management.co.uk/?p=15
Search found no usable figures for rabbit, fox, moose or horse density; those rows are from general knowledge and carry M or L.
