# Fish plan B build notes (claude/steve-fish-classifier, RESTART, approved in Steve_fish_classifier.md)
Built on claude/water-r1-landmap (R1), merged with generator-v2. Reuse, as Tyler required: `server_fish_water.gd` SHARES the land-type map's constants (LandType.BAKED_RIVER, BAKED_LAKE, WET_M) and does not write a second classifier; the fishing kinds (brook, river, lake, pond, sea bands) are a mapping of the same baked classes plus depth.
- src/server/server_fish_water.gd: water_kind_at(x, z) -> {kind, depth}; read only; probe = the server's `_water_at` (live water level and ground, so dug/filled ground counts) plus the baked tile water_class.
- data/water/fish_water.json: sea bands 0-5 / 5-30 / 30+ m, brook = river 8 m wide or less and under 1 m deep, pond = 40 joined wet cells or fewer (about 0.26 ha).
- Cache: per 8 m cell (not per 128 m fishing cell: a lake and a brook can share one 128 m cell), 20 s ttl so dug or rising water shows, 20000 entries max.
- Hook: `items.water_kind_at(x, z)` set in terrain_server.
- Test: test_fish_water.gd (sea 3/13/40 m, brook, river, lake, pond, land never water, dug hole after ttl, cached cost under 0.05 ms).
Needs David3: test_fish_water, test_land_type, local_check 233, parse_scan.
