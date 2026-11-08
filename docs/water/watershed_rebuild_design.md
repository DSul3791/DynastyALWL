# Terrain and water rebuild: one watershed system (design)

Sonny, 7 Nov 2026. Dave's assignment of 19:05 UTC: rebuild the terrain generator and the water so they are planned as one natural system, from the first stage. The governing reference is `docs/water/Dynasty_How_Natural_Watersheds_Work.md` ("the watershed document"). Dave has said it overrides every earlier note. Its section 14, "What We Expect to Have", sets the design objectives. Everything below is checked against that section, against "What we should never see", and against the follow-the-water test.

This doc replaces `docs/water/terrain_water_pipeline.md` (#529), whose P1 to P6 plan kept the old order. #530, #531 and #532 stay on hold. Their useful parts are named in section 6.

Where this doc states a natural fact or a method, it names the source (section 9). Where a number has not been measured on our island yet, it says so.

**Revision, 7 Nov 2026 (Dave asked for a reread of the document and the assignment).** The direction stands. The reread, with Dino's first input maps (R1 run), changed these parts: rain is a storm-time rate scaled to its share of the year (A4); uplift has no hill-scale pattern (A2); rock carries water properties and faults (A3); one water budget drives both the erosion and the rivers (principle 7, A5, B1); lakes come from named natural causes, chiefly a glacial history of the high ground (B2, B3, C2); groundwater has its own divides and streams can lose water (C3, C5); cave springs also come from fractured basalt and faults (C7); every feature can answer the document's seven questions (principle 8, D); and new checks (section 5). Section 4.7 explains how the document's note about architecture is read alongside the assignment.

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
7. **One water budget for ground and water.** The same runoff (rain, minus evaporation, split by the rock into quick runoff and groundwater recharge) drives the erosion that shapes the valleys and the rivers that later run in them. If the erosion used all the rain while the rivers used only what runs off, chalk, limestone and dry slopes would get valleys cut by water that is not there: deep valleys with no stream, which the document's last never-see item forbids (water and ground that disagree).
8. **Every feature can explain itself.** Each lake, spring, seep, head, wetland, reach and outlet carries in the record the answers to the document's seven plausibility questions (section 13): what area and pathways feed it, why it is here and not nearby, what controls its level or outlet, what rock and soil made it, how it behaves in storm, normal weather and drought, what evidence it leaves, and how it reaches the coast or an internal sink. A feature that cannot answer one is a defect.

---

## 3. The new pipeline

All heavy stages run offline on Dave's PC (Dino), never in the cloud. They are deterministic for a given seed and parameters. One tool, `tools/watershed/` (Python with numba, building on `tools/erosion_precarve`), writes one island record. The Godot tile bake becomes a reader of that record.

### Stage A: landform, rock, climate (inputs, kept from today)
- **A1 macro landform**: `world_elevation.gd` exported as raw heights (the export already exists) with **no** fine detail noise, **no** valley guides and **no** rolling hills. It gives the coastline, the massifs and the base level.
- **A2 tectonic uplift field**: where and how fast the land rose. It comes from the macro landform (the existing "design uplift"), smoothed, so it varies only at the scale of the massifs. Nothing is added at hill scale: the first R1 run tried plane waves at 1 to 2 km and they showed as regular blobs, an arbitrary pattern (document section 11: "Variety should emerge from differing environmental conditions rather than arbitrary randomization"). The variety the rolling hills and detail noise gave today comes instead from the rock bands, the rain and the drainage itself. Fault blocks from `tile_geology` may later step the uplift, because that is a geological cause.
- **A3 rock**: `tile_geology` provinces, layers and features (`rock.py` already loads the layers). Per cell this gives erodibility (K) and the rock's water properties:
  - **aquifers and aquitards**: chalk and sandstone hold and pass water (porous aquifers); limestone and marble pass it through dissolved fractures (karst); basalt through joints and lava tubes; shale, slate, coal measures and most granite hardly at all. Springs and seeps form where a permeable bed lies on a tight one (document section 3), and the R1 map shows many such contacts in the folded bands, so spring lines along them are expected;
  - **soluble rock**: limestone, marble and chalk. Caves form mainly in limestone and marble; chalk is weak and porous, so it gives dry valleys, seasonal bournes and springs at its base, rarely caves;
  - **faults and joints** (`tile_geology` already places faults): weaker, more permeable zones, so valleys can follow them (rectangular drainage), springs can rise along them, and drainage can be redirected (document sections 3, 4 and 10).
  The first R1 map shows folded alternating hard and soft beds (sandstone, limestone, slate against shale, chalk, tuff). Where they strike across a massif, trellis drainage should emerge from the erosion by itself (document section 4). Hard beds make ledges, gorges and falls; soft beds make wide valleys (section 10). Numbers for permeability by rock type are researched before R4 (Gleeson et al. 2011 and the British Geological Survey aquifer classes are the starting points).
- **A4 climate**: rain from wind and relief by the linear orographic model (Smith and Barstad 2004). That model gives the rain rate while moist air is lifted, not a yearly total, so the yearly rain is the background plus the orographic rate times the share of the year with moist onshore flow (`storm_share`). The share is calibrated once against a real maritime peak (Ben Nevis, 1,345 m: 4,104 mm a year, observatory mean 1883 to 1904) and then fixed as a climate property. The first run, without it, peaked at 13,300 mm a year, which is beyond any temperate mountain of this height. Snow: the share of precipitation falling as snow comes from temperature, falling with height by the lapse rate; snowmelt makes the spring high flow (document section 8). Today `climate.py` reads moisture from a finished bake, which is circular. In the rebuild the climate is computed from A1 and the world air before any water.
- **A5 runoff (new)**: one water budget, computed here and used by every later stage (principle 7). Evaporation by the Fu form of the Budyko curve (ET/P from the rain and the potential evaporation, 483 mm a year, the MORECS mean for Scotland; the Institute of Hydrology finds it changes little with height in such uplands), then the rest split by the rock into quick runoff and groundwater recharge by the rock's base flow index (UK Low Flow Studies, table 3.3: chalk about 0.94, old limestone about 0.5, mudstones and hard rocks about 0.4). Code: `tools/watershed/runoff.py`; values and sources in `params.json`. Stage B erodes with the quick runoff, so a valley is as large as the floods that really run in it; Stage C sends the recharge through the groundwater to springs, seeps and baseflow. Rocks the UK tables do not cover (marble, slate, granite, basalt, tuff) take the nearest class for now and are flagged for the R4 research pass.

### Stage B: landscape evolution (the ground)
Three parts, in the order the land would have lived through them.

**B1 the long river era.** Stream power with deposition (FastScape style: Braun and Willett 2013; deposition per Yuan et al. 2019), plus hillslope creep:
- erosion driven by the quick runoff of A5 accumulated downstream, not by the rain alone, so permeable and dry ground cuts less (principle 7);
- K from rock, and a channel threshold so weak flows do not incise ("no deep gullies under tiny flows"). The threshold is on the runoff-weighted area together with slope (the slope-area form of Montgomery and Dietrich 1988), not a fixed area, so wet hills carry more channels than dry or permeable ones (document sections 1 and 8);
- creep rate from the rock and its soil cover, and from the climate: valley spacing is set by the balance of creep and channel cutting (Perron et al. 2009), so one creep rate everywhere would space valleys evenly across unrelated catchments (a never-see item). R2 scales creep by the rock and cover (as `lem.py` did); a climate term waits for a source;
- sediment deposition where carrying capacity drops (inside bends, valley floors, lake entries, coast), so floodplains and deltas form;
- threshold hillslopes: past a threshold angle hillslopes fail by landslides, so their mean angle stays near it whatever the erosion rate (Burbank et al. 1996; Montgomery 2001). Linear creep has no such limit; run 624bd23c grew a ridge more than 1,000 m above its landform with 40 to 45 degree flanks. Each cell is therefore capped at the threshold slope (35 degrees over a 16 m cell) above its receiver inside the implicit solve, and what a slide removes joins the sediment carried downstream (talus and fans at the slope foot; the hybrid landslide model of Campforts et al. 2020 routes debris the same way). The threshold is set by rock, because hard rock holds steeper walls (Schmidt and Montgomery 1995): granite and basalt 48 degrees, slate and marble 44, limestone 42, sandstone 40, tuff 38, and 35 for shale, coal, chalk and under loose cover over 1 m. These are the art goal's light fantasy exaggeration within real hard-rock walls (the Skye Cuillin, Glen Coe), so tall peaks stand as walls and are not cut back to soft-rock angles;
- run long enough to reach steady state, at 16 m over the nine tiles (8.3 M cells). The summary reports how fast the summit and the mean land height still change over the last tenth of the run; near zero means uplift and erosion balance. Steady-state relief scales with uplift over erodibility, so the uplift is calibrated once so that the final ground matches the landform's heights at the scale of the massifs (Sal's relief bands), rather than shaping the result afterwards. One scalar was not enough: run c3b1b846 (with the slope limit) had its summit at 835 m against 1,459 m but its mean land at 190 m against 155 m, because the flat-topped, broad uplift raised the flanks while the rivers cut the centres. So the uplift is scaled by the ratio of the landform to the previous result, both smoothed at the uplift's own scale (`evolve.py --calibrate`), which keeps hill-scale pattern out of the uplift (R1's rule).
- **Dissection, not steady state (8 Nov, after run 506dadff).** The massif-scale calibration matched (mean mismatch 9 m), yet the summit stood at 894 m against 1,459 m. A steady state keeps the landform only at the smoothing scale: with threshold slopes and the valley spacing set by D/K, no peak stands more than a couple of hundred metres above its valleys. Real islands of this kind (Arran, Skye, the Highlands) are not in steady state; they are uplifted surfaces that rivers and then ice are still cutting into. So B1 now dissects the landform as it stands (`uplift_share` 0: the landform is the land as uplifted) and the run length is chosen from snapshots by the checks: summits near the landform's, the main valleys reaching into the massif cores, and the drainage and slope figures. Island character (tall alpine, rolling, low) is set per island and seed at the landform stage (`summit_m` by island type in `worlds/base_world/plan/sketch_rules.json`, and the giant-peak roll); the erosion stage carves valleys into it and must not flatten it. The summary reports land height percentiles and the 2 km local relief on high ground against the landform's.
- **Measured creep (8 Nov, after run 11bbbcc9).** Dissection with D 0.15 m²/yr wore the island to a low plain (summit 680 m at 0.25 Myr, 167 m at 2 Myr) and took 200 m off the summit in the first 5 kyr step. That D was chosen only to keep D/K while K was raised for a quick steady state; it is 30 to 50 times measured soil creep (about 0.003 m²/yr, Roering et al. 1999). Here the valley spacing comes from the channel-head rule, not D/K, so D is a measured value again (0.005 m²/yr). The summary checks each landform peak above 600 m against the highest ground now within 200 m of it (the summit rule: valleys carved, peaks kept), and splits the height change into river and slides against creep, so the process that sets the peaks is known. If the peaks still fall, the candidates are an incision threshold (small steep headwater flows cannot cut bedrock, the document's "no deep gullies under tiny flows"; Snyder et al. 2003, DiBiase and Whipple 2011) and hard rock under the tall peaks at the geology stage.
- *Breaking change:* `uplift_share` 0 means B1 no longer reaches a steady state, so `last_tenth_*` now measure how fast the ground is still being worn down, not a balance. The calibration (`--calibrate`) stays for runs with uplift.

A long river era fills closed hollows with sediment. That is right in nature too, and it means any hollow left at its end is not, by itself, a lake.

**B2 glacial history (new).** The island's climate has snowy winters, a treeline at 620 m and summits near 1,450 m. A landscape like that (western Scotland, Norway, coastal British Columbia) carries a recent glacial history on its high ground, and that history is where most of its lakes, many of its falls and much of its wetland come from. The document names it twice (sections 6, 10 and 11: "glacial depressions", "glacial history"). So after B1:
- an ice stage with a lowered snowline (the equilibrium-line altitude, a parameter): glaciers grow where snow outlasts melt and flow down the B1 valleys;
- glacial erosion rises with ice flux and sliding, so it is strongest where ice converges and is confined: bowl-shaped cirques at valley heads (tarns after the ice), U-shaped troughs, and overdeepened rock basins behind bedrock sills at confluences and narrows (Kessler, Anderson and Briner 2008; Alley et al. 2003);
- tributary valleys with less ice are left hanging above the main trough: natural falls with a cause;
- moraines where the ice ended dam valleys (moraine lakes); till and hummocky ground in the lowlands it reached (kettle ponds, poorly drained flats for fens and bogs); outwash below the ice margins (braided channels have a reason there);
- then a short post-glacial era (about 11,700 years) of river and creep work, too short to fill these basins, as in nature.
Where the chosen snowline puts no ice, there is no glacial imprint: glaciated and unglaciated catchments then differ by cause (document section 11). The model is chosen by research before any code (step R2b).

*Research so far (7 Nov):*
- **Model.** A glacial stream-power law (Hergarten 2021, Earth Surface Dynamics 9:937; benchmarked against the process-based iSOSIA ice model by Liebl et al. 2023, Geoscientific Model Development 16:1315, both in OpenLEM). Erosion is E = K_g A_i^m S^n, where A_i is the ice flux expressed as an equivalent catchment area and S is the slope of the ice surface. Ice flux comes from a mass balance that is linear in height above the snowline: below the snowline the ice melts, and ice production comes from the same precipitation field (A4). Fluvial and glacial erosion mix as K_eff = γ^m K_g + (1 − γ)^m K_f with γ = A_i / A. Glacier width scales as A_i^0.3. The finite-thickness version, with a constant thickness-to-width ratio, lets the ice surface stand above the bed. It has the same implicit, outlet-up form as our B1 solver, so it extends `evolve.py` rather than adding a second model, and it runs on millions of cells on a PC.
- **What it gives, per the benchmark:** hanging valleys and steps at confluences, in roughly the same places as iSOSIA; overdeepenings (the rock basins that become lakes); and flat-floored valleys from V-shaped ones, with some V left. Its stated limit is that it "cannot replace process-based models such as iSOSIA but is complementary to them". Cirques are not shown in the parts read so far, so their shape is checked on our maps before we rely on them.
- **Snowline.** For a stadial like Scotland's last one, a reconstructed equilibrium line at Coire Breac (eastern Grampians) is 487 m (Loch Lomond Stadial). Ours comes from the mass balance with the A4 precipitation, so the wet west builds more ice than the dry lee, which adds regional variety by cause.
- **Moraines.** Hergarten 2021 uses a shared stream-power law, E/K_d + Q_s/(K_t A) = A^m S^n (his eq. 3). It is the same erosion-deposition balance as our B1 solver, with K_d/K_t taking the place of G. The glacier carries sediment while its transport capacity lasts and drops it where the ice flux falls near the terminus, where meltwater may cut it again (eqs. 30 to 36: one sediment flux, carried by whichever of ice or meltwater spends less power). The paper does not build moraine ridges as such, so moraine dams are a result to check on our maps, not a promise.

*R2b method:*
1. Mass balance on the ice surface: the share of precipitation that becomes ice rises linearly from 0 at the snowline H_e to 1 at H_f, and is negative below H_e (melt). The precipitation is A4's field. Ice flux A_i accumulates down the routing like discharge until it reaches zero (the terminus).
2. Width w = a A_i^0.3 and thickness h = δ w. The ice flux is spread over a swath (his section 3). Every cell with ice is a start point c0 on its cardinal path, where each upstream point is the largest donor. Donors of c0 that are off the path join c0's swath if they lie within w_i/2 of an upstream path point c_i, and the search repeats outward through their donors. A swath cell takes the ice flux of its path point, and where swaths overlap the largest flux wins. Erosion then uses A_i,eff = A^0.25 A_i^0.75 (his eq. 22, ε = 0.25). The weighting by the unextended total flux A keeps a slightly parabolic valley floor and stops flow running in parallel lines down the flat floor.
3. Each step: add h to the ground, route on the ice surface (depressions in it filled), solve the same implicit erosion-deposition with K_eff = γ^m K_g + (1 − γ)^m K_f and γ = A_i / A, then subtract h.
4. Climate history: B1's long river era, then one cold stage with the snowline lowered (the parameter, starting near the stadial value), then the post-glacial era (about 11,700 years) of river and creep work with today's climate.
5. Outputs: each lake basin's cause (cirque, rock basin behind a sill, moraine or till dam), hanging-valley lips (fall candidates), till and outwash cover, and the ice extent, for R3 and R5.

*R2b as coded (`tools/watershed/glacial.py`, 7 Nov):* the method above, starting from B1's saved ground so the ice settings can be rerun alone. Choices the paper leaves open, each written in the code:
- the swath half-width is measured from each ice cell, walking up its donor tree, rather than from the nearest upstream path point; cells further up the valley get the swaths of the path cells there, which carry almost the same flux;
- the ice thickness comes from the effective flux A^0.25 A_i^0.75, so it thins toward the swath margins;
- the slope limit of B1 does not apply to ice cells (a glacier front is steep ice, not a hillslope). Ice-free walls are measured against the ice surface beside them, because the ice holds them up. After it melts, the post-glacial era lets oversteepened walls fail, as paraglacial rock slope failures do (a cause for landslide dams);
- the ice-free walls and the post-glacial era use B1's slope limit by rock, so hard-rock trough sides and cirque headwalls stand steep (up to 48 degrees in granite and basalt) while soft rock and till relax to 35;
- the uplift is the one B1 used (`uplift` in its ground.npz), so with B1 dissecting the landform (no uplift) the cold stage adds none either;
- the cold-stage water is the rain that does not become ice, plus melt where ice arrives, less a cold-stage evaporation. All of it is quick, because frozen ground makes even chalk impervious (Goudie 1990);
- land never goes below sea level, so no fjords: the coastline is fixed in this model.
Each hollow left after the post-glacial era is labelled ice-scoured floor, glacial deposit sill, other sediment sill, or none, for R3.

**B3 other lake makers, by condition.** Each is a named cause the lake table records:
- karst sinkholes (dolines) on limestone and chalk, where water dissolves the rock and drains down (closed, and explainable);
- landslide dams in steep valleys of weak rock, rare, where slope, relief and rock make a failure likely;
- oxbows and backswamps on meandering lowland reaches (stage C5);
- coastal lagoons behind bars where sediment supply is high and the shore is low (stage C8);
- beaver ponds belong to the ecology later (small, low-gradient streams near woodland); they are not made here.

The output is the **final ground**, not a delta, together with the routing graph it was eroded with. The final 8 m ground is the 16 m result refined, plus small hillslope roughness that cannot make pits (section 4.6).

### Stage C: hydrology on the final ground (the water)
- **C1 routing**: priority flood (Barnes et al. 2014) and steepest descent on the final ground. That gives basins, divides, receivers and rain-weighted discharge. This is the only routing.
- **C2 lakes**: every depression of the final ground is first given its cause from Stage B (cirque, glacial rock basin, moraine dam, kettle, doline, landslide dam, oxbow, lagoon). A hollow with no cause is a numerical leftover, a few decimetres of resampling, and is filled; it is not a lake. Each caused depression is then tested with a water balance (fill, spill and merge over the depression hierarchy: Barnes et al. 2020 and 2021): inflow (its catchment's runoff plus groundwater) against evaporation and seepage over its area. If inflow wins, it fills to its lowest saddle (the controlling spill point) and a river leaves there; full neighbours merge into one lake. If it never fills, it is a pond at its balance level, or a seasonal wetland. A closed basin needs that explanation, which makes them rare (document section 6, and "closed basins are exceptional").
- **C3 groundwater**: a steady water-table solve on a coarse grid (64 m), with recharge from A5 and transmissivity from rock. The water table follows hydraulic head, not the surface routing, so a groundwater divide can sit off the surface divide, and karst conduits can carry water under a ridge to a spring in the next basin (document section 3). Where the water table meets the ground there is seepage: springs at slope breaks and where a permeable bed meets a tight one, broad seeps, and wetlands on flats (USGS; document sections 3 and 7). Each stream gets a baseflow share, and that sets perennial versus intermittent.
- **C4 channel heads**: a channel starts where drainage area times slope passes a threshold (Montgomery and Dietrich 1988). The threshold rises in dry or permeable ground, so heads sit higher in wet catchments and lower in dry ones. A head is then labelled by what feeds it: a seep or damp hollow (the common case), a spring, a wetland outlet, a lake outlet, or a seasonal rill. Ponds and caves are never added to make a head.
- **C5 network**: reaches between confluences. Discharge is the quick runoff from upstream plus groundwater gained, minus water lost where the bed lies above the water table (losing reaches on permeable rock, karst and alluvium), so a river can shrink as well as grow (document section 4). Each reach has discharge (mean, wet season, dry season), slope, flow regime (perennial, intermittent or ephemeral), width and depth from hydraulic geometry (width about Q^0.5, depth about Q^0.4: Leopold and Maddock 1953), and reach type from slope (cascade above about 0.065, step-pool 0.03 to 0.065, plane-bed 0.015 to 0.03, pool-riffle below that: Montgomery and Buffington 1997). Meanders only on pool-riffle reaches with room in the valley floor, their wavelength scaled to the channel width, so meanders differ between rivers. Falls only where the bed drops sharply over hard rock or from a hanging valley. Natural levees only on lowland alluvial reaches with fine sediment, low and broad (not the retired bank walls). More than one channel only in wetlands, deltas and braided outwash, where the conditions for it exist (a never-see item).
- **C6 wetlands**: cells that stay saturated (water table at or near the ground, low slope, convergent flow). They are typed by the document's section 7 and EPA definitions: marsh (surface water, soft plants), swamp (woody), fen (groundwater fed, peat), bog (rain fed, peat, acidic).
- **C7 cave springs**: only where the rock lets water travel underground in open passages: limestone and marble (karst caves), fractured basalt (lava tubes, which `tile_rules` already defines) and fault zones; chalk mainly gives springs without caves. The cave catchment drains underground (sinkholes, a losing reach) and the outlet sits lower down where the passage meets the surface, perhaps in another surface basin. The spring's flow equals what that underground catchment receives, so no large river comes from a small opening without supply. Rare by construction.
- **C8 coast outlets**: from slope, sediment load and coast shape: a rocky outlet, a tidal creek, an estuary or a delta (document section 9).

### Stage D: the island water record
One record, written once per bake and read by everything:
- per-cell rasters at 8 m: ground, water class (sea, lake, river, wetland by type, seasonal), water level, discharge, flow regime, depth to water table, basin id;
- vector network: reaches (polyline, Q per season, width, depth, reach type, regime), heads (kind), confluences, falls, lakes (cause, level, spill point, outlet reach), springs and seeps, cave springs, coast outlets;
- per feature, the answers to the seven plausibility questions (principle 8);
- per reach and lake, what the water should look like (document section 12): bed material (boulders, cobbles, gravel, sand, silt, peat), sediment load (clear, cloudy after rain, silty), peat colour where fed from bogs, and turbulence class. The water and ground shaders read these later, so the look agrees with the hydrology.

Tiles are cut from it by world position, so seams agree by construction.

*Record layout, agreed with Steve's Stage E design (#541), 7 Nov:*
- rasters are raw little-endian grids at 8 m, one set per tile, (T+1)² samples with shared edge samples (the `export_raw_heights` convention);
- vectors live in one island-wide `record/network.json`, so a reach that crosses a tile edge stays one object with one id and is never clipped at a seam;
- `record/manifest.json` holds the record version, params, input hashes, origin and cell size. Units are metres and m³/s, in world x, z and y up;
- water class codes: 0 none, 1 ocean, 2 lake, 3 river (kept from today), then 4 marsh, 5 swamp, 6 fen, 7 bog, 8 seasonal channel, 9 seasonal pond, 10 salt marsh or tidal flat. Perennial, intermittent or ephemeral is carried by the regime raster;
- extra rasters: `fresh_m` (distance to perennial fresh water) and `sediment_m` (loose cover), both computed island-wide so seams agree;
- each reach carries wet-season, mean and dry-season flow, bed material and its downstream reach id. Karst sinks are listed with the id of the cave spring they feed;
- ids are deterministic from the seed and params: stable within one record version, never kept across rebakes.

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

### 4.7 The document's note on architecture
The document says it describes natural behaviour, not a replacement architecture, and asks Claude to preserve the architecture where it works. Dave's assignment then authorises redesigning the terrain generator and the water "wherever necessary", while reusing what genuinely supports the new approach. I read the two together: the generation order is rebuilt because it is the cause of the failures (section 1), and everything else in the game's architecture is kept: Voxel Tools terrain, the tile format and bake, the geology and climate rules, the 2 m and 8 m live water, and the readers, which switch to one record. Old tools that place features by chance are not reused: `lem.py`'s random "tarn" sink patches and `meander.py`'s random meanders.

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
   - closed basins counted and each one explained;
   - every lake has a named cause from Stage B (no leftover pits as lakes);
   - every feature answers the seven questions (principle 8);
   - confluences point downstream (junction angles acute, not T-shaped);
   - valley spacing and channel density differ between catchments in step with their rock and rain, not evenly across the island;
   - rain stays within real bounds for the climate (the calibration peak in `params.json`).
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
| R2 | Stage B1: the long river era with quick runoff (A5), rock K and creep, a slope-area threshold and deposition | before and after relief maps, basin map |
| R2b | Stage B2 and B3: glacial history (model chosen by research first), then other lake makers by condition | cirques, troughs, lake basins with causes |
| R3 | Stage C1 to C2: routing, basins, lakes by water balance | basin and lake maps, closed-basin list with reasons |
| R4 | Stage C3, C4, C6: groundwater, heads, wetlands | head kinds map, wetland map, groundwater depth |
| R5 | Stage C5, C7, C8: network, reach types, cave springs, coast outlets; never-see checks; follow-the-water report. Cave passages from sink to spring are sized in the record so they hold at LOD 2: every passage and chamber a player can see from inside is at least 3.6 m in half-width and half-height (about 7.2 m wide and tall) wherever the rock over it allows, keeping Dave's small, medium and large difference above that floor; a narrower passage must be a dead end that LOD 2 closes in full. Formations, scatter, cave streams and pools sit on that baked section, and the generator carves the baked size at LOD 0 to 2 with no per-level widening (test_cave_lods check 4, the LOD 2 lip count, must read 0). Source: docs/design/cave_lod_carving_design.md (#554) | follow-the-water profiles in several basins |
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
- Perron, J. T., Kirchner, J. W. and Dietrich, W. E. (2009), "Formation of evenly spaced ridges and valleys", Nature 460: valley spacing set by the ratio of soil creep to channel incision.
- Overdeepening and glacial erosion (cirque floors, constrictions, sills; fjord and tarn lakes): Kessler, Anderson and Briner (2008), Nature Geoscience; Alley et al. (2003), Nature; summary at https://en.wikipedia.org/wiki/Overdeepening (checked 7 Nov 2026).
- Glacial stream power: Hergarten, S. (2021), "Modeling glacial and fluvial landform evolution at large scales using a stream-power approach", Earth Surface Dynamics 9:937-952, https://esurf.copernicus.org/articles/9/937/2021/ ; Liebl, M., Robl, J., Hergarten, S., Egholm, D. L. and Stüwe, K. (2023), OpenLEM against iSOSIA, Geoscientific Model Development 16:1315-1343, https://gmd.copernicus.org/articles/16/1315/2023/
- Loch Lomond Stadial equilibrium line at Coire Breac, 487 ± 15 m: https://core.ac.uk/download/30663194.pdf
- Runoff split by rock: Institute of Hydrology (1980), Low Flow Studies report 3, table 3.3, https://nora.nerc.ac.uk/id/eprint/9098/1/Low_Flow_03.pdf ; Bloomfield, Bricker and Newell (2011), http://nora.nerc.ac.uk/id/eprint/15338/ ; potential evaporation for Scotland (MORECS 1961-93, 483 mm/yr): https://nora.nerc.ac.uk/id/eprint/15503/1/N015503CR.pdf
- Threshold hillslopes: Burbank, D. W. et al. 1996, Bedrock incision, rock uplift and threshold hillslopes in the northwestern Himalayas, Nature 379:505 (abstract: hillslope angles steep and essentially independent of erosion rate); Montgomery, D. R. 2001, Slope distributions, threshold hillslopes, and steady-state topography, American Journal of Science 301:432; Roering, J. J., Kirchner, J. W. and Dietrich, W. E. 1999, Water Resources Research 35:853 (nonlinear creep toward a critical slope); Campforts, B. et al. 2020, BedrockLandslider 1.0, Geoscientific Model Development 13:3863 (cited by Landlab's ThresholdEroder, which deletes the slide volume; ours routes it as sediment); Schmidt, K. M. and Montgomery, D. R. 1995, Limits to relief, Science 270:617.
- Rain calibration: Ben Nevis summit observatory 1883 to 1904, mean 4,103.8 mm a year at 1,345 m (https://en.wikipedia.org/wiki/Ben_Nevis climate table, checked 7 Nov 2026).
- Depression hierarchy and fill-spill-merge: Barnes, Callaghan and Wickert (2020, 2021), Earth Surface Dynamics.
- Evaporation: Fu (1981) form of the Budyko curve; Zhang et al. (2004) for the parameter. Permeability by rock type: Gleeson et al. (2011), Geophysical Research Letters (values still to be read from the paper).
