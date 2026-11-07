# Terrain and water rebuild: one watershed system (design)

Sonny, 7 Nov 2026. Dave's assignment of 19:05 UTC: rebuild the terrain generator and the water so they are planned as one natural system, from the first stage. The governing reference is `docs/water/Dynasty_How_Natural_Watersheds_Work.md` ("the watershed document"). Dave has said it overrides every earlier note. Its section 14, "What We Expect to Have", sets the design objectives. Everything below is checked against that section, against "What we should never see", and against the follow-the-water test.

This doc replaces `docs/water/terrain_water_pipeline.md` (#529), whose P1 to P6 plan kept the old order. #530, #531 and #532 stay on hold. Their useful parts are named in section 6.

Where this doc states a natural fact or a method, it names the source (section 9). Where a number has not been measured on our island yet, it says so.

---

## 1. Why the current approach fails

I traced the bake from the first stage: `world_elevation.gd`, then `river_network.gd`, `tile_height.gd`, `tools/erosion_precarve`, `tile_baker.gd` and `tile_water.gd` / `tile_drainage.gd`, then the passes after the water. The order today is:

1. **World elevation, 160 m cells** (`world_elevation.gd`): island shapes, mountains, shelves, craters, bays.
2. **World rivers, 160 m** (`river_network.gd`): a priority flood that makes river chains, then smooth curves with a random sideways "meander" push. They are used as **valley guides**, so the tile height cuts valleys around them.
3. **Tile height, 8 m** (`tile_height.gd`): cubic upsampling, valleys cut around the guides, detail noise (several octaves), summit sharpening.
4. **Erosion pre-carve**: an offline landscape model (`tools/erosion_precarve`, stream power, Braun and Willett 2013) run on the pre-erosion heights at 16 to 32 m. It is stored as a **delta** (after minus before), then soft-capped (fill at most 12 m), smoothed where steep, faded at the frame edge, and added to the 8 m ground.
5. **Strata ledges, then scree aprons**, added after the erosion.
6. **Rolling swells and hills** (`tile_rolling.gd`, up to about 80 m summed). Before P1 they were added after the water.
7. **Water** (`tile_drainage.gd`): routing over the result, then lakes. Channels are carved by rule (`drainage_channels.gd`: fixed extra depth, bank dykes, bank cones, head ponds, spring caves by rule).
8. **Eight repair passes after the water**: pond levels clamped to their spill, river mend (digging through ridges), join corners, river mouths (twice), valley drain (raising land beside rivers), drain hollows (filling dry pits), spring and cave sites by rule.

Why this cannot give the results in section 14:

- **Three different river systems.** The 160 m world rivers shape the valleys, the erosion model makes its own drainage, and the tile drainage routes again over ground the other two never saw. They disagree. The pre-carve README warns of this itself: "32 m routing can disagree with 8 m routing, so rivers may leave carved valleys".
- **The ground is changed after it was drained.** The erosion result is applied as a capped, smoothed delta onto a different surface (the fine detail noise it never saw). Then ledges, scree and hills are added on top. Each of those adds closed hollows and dams. Dino's census on tile 3,4 (7 Nov) measured this: 43,826 hollow cells before the rolling step, and 6 times the hollow volume after it, up to 23.6 m deep.
- **Water placed by rule, not by supply.** Channel depth is a fixed number (5 m extra, at most 8 m), whatever the flow. Every head was given a pond or a cave. Lakes are kept or dried by a catchment threshold, not a water balance. The watershed document names all three as things we should never see: uniform trenches, deep gullies under tiny flows, and every stream beginning at a head pond or a cave mouth.
- **Repairs instead of causes.** Each repair pass fixes one symptom and makes another. The TERRAIN_VERSION history (44 on 30 Oct to 61 on 7 Nov) is that loop.
- **Brooks are carved into 8 m cells.** A 1 to 2 m brook cut into 8 m cells becomes an 8 m trench. The document says "Avoid carving uniformly deep trenches under every stream".
- **Nothing models groundwater, seasons or wetland saturation.** So springs, seeps, wetlands and flow regimes cannot be placed for a natural reason. Sections 2, 3, 7 and 8 of the document need these.

The cure is not another pass. It is a new order: **landform, rock and climate first; then one landscape-evolution and hydrology model that makes the ground and the water together; then the tiles read its result.**

---

## 2. Design principles (from the watershed document)

1. **One drainage truth.** One flow-routing graph, on the final ground, gives every basin, divide, channel, lake and outlet. No second routing anywhere.
2. **Ground and water are made together.** Valleys come from the water that carved them: the erosion model's own channels. Nothing raises or cuts the ground after the hydrology, except sub-cell channel detail drawn from the same record (section 4.6).
3. **Size follows supply.** Discharge = rain-weighted catchment, minus losses. Width, depth and valley shape come from discharge and slope by measured relations, not from fixed numbers.
4. **Water appears for a reason.** Channel heads come from a slope-area threshold. Springs and seeps come from a groundwater model. Lakes come from basins and a water balance. Wetlands come from saturation. Cave springs come only from soluble or fractured rock with enough catchment.
5. **Variety from conditions.** Rock, rain and slope differ between catchments, so their water differs. No random templates.
6. **Seams by construction.** The whole baked island is solved on one grid, and tiles sample it by world position.

---

## 3. The new pipeline

All heavy stages run offline on Dave's PC (Dino), never in the cloud. They are deterministic for a given seed and parameters. One tool, `tools/watershed/` (Python with numba, building on `tools/erosion_precarve`), writes one island record. The Godot tile bake becomes a reader of that record.

### Stage A: landform, rock, climate (inputs, kept from today)
- **A1 macro landform**: `world_elevation.gd` exported as raw heights (the export already exists) with **no** fine detail noise, **no** valley guides and **no** rolling hills. It gives the coastline, the massifs and the base level.
- **A2 tectonic uplift field**: where and how fast the land rose. It comes from the macro landform (the existing "design uplift"). The variety the rolling hills and the detail noise gave today moves here, as uplift variation at hill scale. Erosion then turns it into real ridges and spurs with drainage between them, never closed bumps.
- **A3 rock**: `tile_geology` provinces and layers (`rock.py` already loads them). Per cell this gives erodibility (K), permeability, and soluble rock (limestone, marble). Hard beds make ledges, gorges and falls; soft beds make wide valleys (document section 10, "Geological controls").
- **A4 climate**: rain and snow per cell from wind and relief (orographic), plus seasonal shares (snowmelt). Today `climate.py` reads moisture from a finished bake, which is circular. In the rebuild the climate is computed from A1 and the world air before any water.

### Stage B: landscape evolution (the ground)
Stream power with deposition (FastScape style: Braun and Willett 2013; deposition per Yuan et al. 2019), plus hillslope diffusion:
- discharge-driven erosion, using rain-weighted area, not plain area;
- K from rock, and a threshold so weak flows do not incise ("no deep gullies under tiny flows");
- sediment deposition where carrying capacity drops (inside bends, valley floors, lake entries, coast), so floodplains and deltas form;
- run long enough to approach steady state, at 16 m over the nine tiles (8.3 M cells; the existing model runs about 1 M years in minutes at this size). The final 8 m ground is the 16 m result refined, plus small hillslope roughness that cannot make pits (section 4.6).

The output is the **final ground**, not a delta, together with the routing graph it was eroded with.

### Stage C: hydrology on the final ground (the water)
- **C1 routing**: priority flood (Barnes et al. 2014) and steepest descent on the final ground. That gives basins, divides, receivers and rain-weighted discharge. This is the only routing.
- **C2 lakes**: each depression left after Stage B is tested with a water balance: inflow (catchment rain plus groundwater) against evaporation and seepage over its area. If inflow wins, it fills to its lowest saddle (the controlling spill point) and a river leaves there. If it never fills, it is a pond at its balance level, or a seasonal wetland. A closed basin needs that explanation, which makes them rare (document section 6, and "closed basins are exceptional").
- **C3 groundwater**: a steady water-table solve on a coarse grid (64 m), with recharge = rain minus runoff and transmissivity from rock. Where the water table meets the ground there is seepage: springs at slope breaks and permeability contrasts, broad seeps, and wetlands on flats (USGS; document sections 3 and 7). Each stream gets a baseflow share, and that sets perennial versus intermittent.
- **C4 channel heads**: a channel starts where drainage area times slope passes a threshold (Montgomery and Dietrich 1988). The threshold rises in dry or permeable ground, so heads sit higher in wet catchments and lower in dry ones. A head is then labelled by what feeds it: a seep or damp hollow (the common case), a spring, a wetland outlet, a lake outlet, or a seasonal rill. Ponds and caves are never added to make a head.
- **C5 network**: reaches between confluences, each with discharge (mean, wet season, dry season), slope, flow regime (perennial, intermittent or ephemeral), width and depth from hydraulic geometry (width about Q^0.5, depth about Q^0.4: Leopold and Maddock 1953), and reach type from slope (cascade above about 0.065, step-pool 0.03 to 0.065, plane-bed 0.015 to 0.03, pool-riffle below that: Montgomery and Buffington 1997). Meanders only on pool-riffle reaches with room in the valley floor. Falls only where the bed drops sharply over hard rock.
- **C6 wetlands**: cells that stay saturated (water table at or near the ground, low slope, convergent flow). They are typed by the document's section 7 and EPA definitions: marsh (surface water, soft plants), swamp (woody), fen (groundwater fed, peat), bog (rain fed, peat, acidic).
- **C7 cave springs**: only where soluble rock (limestone or marble) has a catchment that drains underground (sinks, a losing reach), with the outlet lower down where the rock meets the surface. The spring's flow equals what the karst catchment loses. Rare by construction.
- **C8 coast outlets**: from slope, sediment load and coast shape: a rocky outlet, a tidal creek, an estuary or a delta (document section 9).

### Stage D: the island water record
One record, written once per bake and read by everything:
- per-cell rasters at 8 m: ground, water class (sea, lake, river, wetland by type, seasonal), water level, discharge, flow regime, depth to water table, basin id;
- vector network: reaches (polyline, Q per season, width, depth, reach type, regime), heads (kind), confluences, falls, lakes (level, spill point, outlet reach), springs and seeps, cave springs, coast outlets.

Tiles are cut from it by world position, so seams agree by construction.

### Stage E: readers
- **Tile bake** (`tile_baker.gd`): heights and water come from the record. The rule channels and all eight repair passes are switched off and archived (section 6).
- **Runtime ground**: brooks narrower than a cell are drawn from the reach polylines at voxel scale (their real width and depth), not as 8 m trenches.
- **Live water** (the 2 m and 8 m sims): seeded from the record's levels and discharges. Players' ditches still change it, because the sim stays the truth at runtime.
- **Falls, water sounds, caves, climate, biomes, sites**: read the record instead of working the water out again.

---

## 4. Details that decide whether it looks right

### 4.1 Hills that drain
Hills come from uplift variation that is then eroded (A2 and B), so every hillside has its own drainage. No closed bump is ever added after the erosion. This replaces `tile_rolling.gd` and the hill passes in `tile_height.gd`.

### 4.2 Channels sized by supply
Bed width and depth follow discharge (C5). A seep rill is centimetres to a metre; a lowland river is many metres. Valley shape comes from Stage B: V-shaped where steep and hard, broad floodplains where gentle and depositional. Not every steep brook gets a floodplain.

### 4.3 Lakes that spill where they should
The outlet is always the lowest saddle (C2). The level comes from the balance, so a lake never overflows through an arbitrary higher shore.

### 4.4 Headwaters that are mostly subtle
Most heads are seeps, damp hollows, and rills that merge. Spring pools exist only where groundwater discharge is strong enough to keep one. Caves exist only per C7.

### 4.5 Seasons
The record keeps wet-season, mean and dry-season discharge, and the regime. Later the live sim can scale its sources by season. Then drought exposes intermittent beds and lowers shallow ponds, while groundwater-fed springs persist (document section 8).

### 4.6 Fine detail without pits
The 8 m ground is the 16 m result refined with a smooth interpolation. It adds roughness only on hillslopes away from channels, and that roughness is depression-checked: a priority flood after it must show no new closed cells, or the roughness is removed there. Channel beds come from the reach polylines, at the reach's width and depth.

---

## 5. How we will validate (no success by "it runs")

Every check runs on Dave's PC (Dino or David4), never in the cloud.

1. **Never-see checks, automated** (one test per bullet of the document's list), for example:
   - no reach whose discharge does not grow at a confluence;
   - no head without a supply in the record;
   - no water level above its own spill;
   - no pond on ground steeper than a threshold without a dam (barrier) cell;
   - no wetland on freely draining steep ground;
   - no flow uphill: every reach strictly descends, with falls flagged;
   - incision depth scaled to discharge (no deep cut where Q is tiny);
   - no single shape repeated across catchments (variation statistics for meander wavelength and fall spacing);
   - closed basins counted and each one explained.
2. **Follow-the-water report.** A tool that picks heads in several contrasting basins and walks each to its destination. It prints, at each step, supply, discharge, width, slope, reach type, tributaries joined and destination, and writes a profile picture. Dave reads these.
3. **Overview maps**: basins coloured, network by order, lakes and wetlands, heads by kind, groundwater depth.
4. **Ground pictures by Dino** at chosen points in contrasting basins, and in the old trouble spots from Dave's play test.
5. **Seams**: the existing edge_match check, 0 hard failures.
6. **Godot 4.7.2 and Voxel Tools**: the tile format and the runtime reader stay compatible; any change is versioned (TERRAIN_VERSION bump) and listed in section 7.

---

## 6. What happens to today's code

**Reused**
- `world_elevation.gd` (macro landform), with its fine detail switched off for the export;
- `tile_geology.gd` and `rock.py` (rock), and the climate rules;
- the erosion model in `tools/erosion_precarve` (it becomes Stage B, extended with discharge, threshold and K);
- the priority flood and flow code (C1);
- the tile file format and readers; the 2 m and 8 m live sims; `drainage_natural.gd`'s flow-sized width and depth ideas (folded into C5).

**Retired**, moved to `proposed_removals/` per Dave's rule, once the record replaces them:
- `river_network.gd` as a valley guide;
- valley shaping and hill detail in `tile_height.gd`;
- `tile_rolling.gd`;
- `drainage_channels.gd` rule carving, banks, head ponds and spring caves by rule;
- `tile_pond_level.gd`, `tile_river_mend.gd`, `tile_river_mouth.gd`, `tile_valley_drain.gd`;
- the spring-cave and head-pond placement in `tile_sites.gd`.

**Held PRs**: #530 (hills before water), #531 (a source at every head) and #532 (natural rivers on) are superseded. #531 conflicts with the document directly. I will close them with a pointer here once Dave accepts this design.

---

## 7. Breaking changes for other systems (to repair later)

Per Dave, these are listed, not fixed now:
- **Spawn point** (`spawn_point.gd`): must be re-chosen on the new ground with island_checks `--spawn-search`.
- **Caves and dens in `tile_sites.gd`**: goblin dens and bear caves are placed from spring caves. With far fewer cave springs, den placement needs a new source (dry caves in the same rock).
- **Climate, biomes and flora**: these read water class and flow, which change meaning and values (wetland types are new).
- **Ores and placer deposits**: placer gold follows rivers and must follow the new network.
- **Waterfalls, water sounds, cave streams**: must read the record (section 3E). Until then they may draw in the wrong places.
- **NPC markers, paths and settlements**: positions may end up in water or on steep ground.
- **Tests**: tests pinned to the old tiles (test_river_surface, test_head_pond_fill, test_drainage_fill, test_tile_lakes and others) are re-pinned or archived with a REMOVALS row as each step lands.

---

## 8. Steps (small PRs, each baked and checked on Dave's PC)

| step | what | result Dave can see |
|---|---|---|
| R0 | this design | this doc |
| R1 | Stage A inputs: raw macro landform with no detail, uplift field, rock and climate maps for the nine tiles; export tools | input maps (pictures) |
| R2 | Stage B: landscape evolution with discharge, rock K, threshold and deposition | before and after relief maps, basin map |
| R3 | Stage C1 to C2: routing, basins, lakes by water balance | basin and lake maps, closed-basin list with reasons |
| R4 | Stage C3, C4, C6: groundwater, heads, wetlands | head kinds map, wetland map, groundwater depth |
| R5 | Stage C5, C7, C8: network, reach types, cave springs, coast outlets; never-see checks; follow-the-water report | follow-the-water profiles in several basins |
| R6 | Stage D and E: record file, tile bake reads it, old passes switched off; TERRAIN_VERSION bump, nine-tile rebake | the island in game |
| R7 | runtime: sub-cell brooks from polylines; live water seeded from the record; falls and sounds read it | walk the island |
| R8 | archive the retired code; list the dependent-system repairs | clean tree |

Steps R1 to R5 are offline tools and pictures, with no game change. Dave can judge the watershed from the maps before any tile is rebaked.

---

## 9. Sources
- Dave: `docs/water/Dynasty_How_Natural_Watersheds_Work.md` (the governing reference).
- Braun, J. and Willett, S. D. (2013), a fast implicit stream-power solver (FastScape); Landlab FastscapeEroder docs: https://landlab.readthedocs.io/en/latest/generated/api/landlab.components.stream_power.fastscape_stream_power.html
- Yuan, X. et al. (2019), "A new efficient method to solve the stream power law model taking into account sediment deposition", JGR Earth Surface.
- Barnes, R., Lehman, C. and Mulla, D. (2014), priority-flood depression filling.
- Montgomery, D. R. and Dietrich, W. E. (1988), "Where do channels begin?", Nature 336: channel-head source area falls as slope rises; drier regions have larger source areas. https://link.springer.com/article/10.1038/336232a0
- Montgomery, D. R. and Buffington, J. M. (1997), channel-reach morphology: cascade above about 0.065, step-pool 0.03 to 0.065, plane-bed 0.015 to 0.03, pool-riffle below about 0.015; distributions overlap. https://fs.usda.gov/rm/boise/publications/watershed/rmrs_1997_montomeryr001.pdf
- Leopold, L. B. and Maddock, T. (1953), downstream hydraulic geometry, average exponents width 0.5, depth 0.4, velocity 0.1 (USGS PP 252; summary in USGS OFR 82-436: https://pubs.usgs.gov/of/1982/0436/report.pdf)
- Groundwater, gaining and losing streams, baseflow, springs and seeps: https://waterportal.ca/gw-surface/ ; USGS Water Science School.
- Topography-controlled versus recharge-controlled water tables (Haitjema and Mitchell-Bruker 2005; Gleeson et al. 2011): https://pubs.usgs.gov/publication/70003883
- Wetland types (EPA): https://19january2025snapshot.epa.gov/wetlands/classification-and-types-wetlands/index.html
