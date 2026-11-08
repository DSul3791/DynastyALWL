# R7 plan: colossal starter peaks, the record in the game, and live water from it

Sonny, 8 Nov 2026. This plan covers what comes after R5 (the stream network), R6 (the island water record) and the spring store (#726). It sets the order of work, the ws580i run, and the R7 runtime work. The governing design is [watershed_rebuild_design.md](../water/watershed_rebuild_design.md), section 3, R7 method. The acceptance lines extend `/mnt/project-files/water/r7_acceptance.md`.

Numbers come from Jamie's pages:
- [cirques-and-horns.md](../knowledge/cirques-and-horns.md) (#654);
- `docs/knowledge/groundwater-layers-recession.md` (#713, not yet on main);
- [specific-yield.md](../knowledge/specific-yield.md) (#686).

The water plans named in backticks are on the R chain (#537 to #648) until it merges.

## 1. The headline: colossal peaks on the starter island (D-10)

Dave's rule D-10: the starter island has colossal, epic peaks. Erosion never takes a summit below its landform target, and no summit guard is used: each stage meets the rule physically. Every stage after the landform must keep the peaks. R7 must then show them in the game.

**The peaks, as ws580g measured them (ws580h re-checks):**

| peak | world x, z | landform height | what it should become |
|---|---|---|---|
| starter summit | 54800, 71424 | 1,441 m | a horn: three or more cirque headwalls within 200 to 400 m of the top |
| second massif | 66800, 79760 (zoom at 66960, 79296) | 977 m | granite under it now (rule 3 on the ground), so the ice can no longer take 320 m |
| the peak beside it | 65360, 81520 | 910 m | granite too, the same rule |

**What makes a horn, and our settings (#654):**
- **Headwall retreat.** While a cirque glacier is active, hard crystalline rock retreats 0.5 to 1.0 mm a year. Lochnagar is about 1.0, Ben Ohau 0.44.
  - Our history gives 1,039,600 years of active ice: 39 cycles of the 41 kyr world at 16.4 kyr each, plus 10 of the 100 kyr world at 40 kyr each.
  - That is 0.5 to 1.0 km of headwall retreat. #654's table puts that between an Arran or Cuillin ridge (500 m) and a Matterhorn-scale horn (1 km, which needs 1 to 2 Myr of active time).
- **The first cycle cuts the cirque basin**, about 150 to 200 m deep. Later cycles deepen it about ten times more slowly. Rule 6 line 10 checks this: later deepening is at most a fifth of the early rate.
- **The summits barely change.** A granite plateau loses about 0.0016 mm a year (Hall et al. 2024), or 1.6 m per million years. Rule 6 line 4 keeps every checked summit within 25 m of its landform height.
- **The shady side works harder.** The starter island sits at 57° S, so the shady lee quarter faces SE (`glacial.shady_bearing_deg` 135).
  - The snowline lies 75 m lower on steep SE faces and 75 m higher on NW faces. That gives a 150 m difference, the middle of the sourced 110 to 220 m.
  - SE headwalls should retreat 1.5 to 2 times faster than NW ones (judged), and SE cirque floors should sit 100 to 200 m lower.

**Never-see (#654):**
- a horn on a peak with cirques on one side only;
- a granite summit or plateau lowered as fast as the cirque walls cutting into it;
- cirque floors deepening at the same rate every cycle;
- deep cirques on the sunny NW faces while the shady SE faces have none;
- a dome, a ring cliff round the top, or a star of straight rays (rule 6 lines 7 and 12).

**Every stage keeps the summit.** Each line below is checked on that stage's own files:

| stage | check | from |
|---|---|---|
| landform | summit heights within 1 m of ws580g; valley heads at least 50 m deep within 1 km | `peaks_landform` lines 1 to 3 |
| river era (R2, t100k) | `summit_m` no more than 10 m under `landform_summit_m` | ws580h stage 2 |
| ice (R2b) | every checked summit within 25 m of its landform height; `summit_m` at least 1,410 m, never outside 1,000 to 1,450 m | rule 6 line 4, ws580h stage 3 |
| lakes (R3) and record (R6) | R3 fills only leftover hollows, so the record's `summary.summit_16m` (R3's ground) equals R2b's `summit_m`; `summary.summit_8m` within 1 m of `summit_16m` | ws580i stage 4, r7_acceptance stage 1 |
| bake and reader (M2) | in-game height at the summit cell equals the record within 1 mm | r7_acceptance stage 2, plus this summit point |
| far drawing (R7) | the horn still reads as a pyramid at the far terrain levels | Dino's shots C1 to C4 (section 5) |

## 2. Order of work

1. **ws580h** (Dino, queued, about 2 h). Rule 3 on the ground and rule 6. Judged against `/mnt/project-files/water/ws580h_signoff.md`.
2. **ws580i** (Dino, section 3; not yet timed on Dave's PC). R3 lakes, R4 groundwater with each spring's store, R5 network and R6 record, all run on ws580h's ground. If ws580h fails, its fix run takes the name ws580i and this list moves to ws580j.
3. **Gates.**
   - David4 runs the unit tests and the CI for #580, the R chain and #726. #726 passed on 4e5cdbb8: 13 spring store tests, 10 network tests and 9 peaks tests.
   - Tyler merges in stack order on each pass. R5 #648 waits for Dave's yes, as before.
4. **R6 rebake.**
   - `water_source` "record", one TERRAIN_VERSION bump (70, if nothing else takes it first), and the nine starter tiles (2,3 to 4,5) rebaked on Dave's PC.
   - Then r7_acceptance stage 1 (the record) and stage 2 (Steve's M2 reader).
5. **R7 runtime** (section 4), then the walk: r7_acceptance stages 3 and 4, plus the lines in section 5.
6. **R8.** Retired passes move to `proposed_removals/` in three PRs, each proven harmless by byte-identical tiles. Only Dave's yes deletes them.

## 3. ws580i run list (Dino, on Dave's PC)

**Setup.**
- Checkout: Dino's `bake_536` worktree, at the #726 head named in the chain message. That head has the R chain's code, the spring store, and `plots.py zoom_network`.
- `<ws580h>` is the passed ws580h folder and `<ws580i>` the new one.
- Report each stage word for word. Copy these to the shared folder unchanged, with 580i in each name: `lakes.png`, `lakes.json`, `lakes_manifest.json`, `groundwater.png`, `groundwater_manifest.json`, `network.png`, `network_manifest.json`, `follow_the_water.md`, the record's `manifest.json`, and every zoom picture.

### Stage 1: lakes (R3)

```
python tools\watershed\lakes.py <ws580h>\inputs <ws580h geology16> <ws580h>\glacial <ws580i>\lakes
```

Pass when:
- `unexplained_lakes` is 0;
- `overflow_lost_m3_s` is 0;
- closed lakes are rare, each with its reason (leaky rock or a tiny catchment);
- there are tarns in the summit's cirques.

Reported, not judged: the lake count and `lake_km2`.

### Stage 2: groundwater (R4, with the spring store)

```
python tools\watershed\groundwater.py <ws580h>\inputs <ws580h geology16> <ws580h>\glacial <ws580i>\lakes <ws580i>\groundwater
```

Pass when:
- `balance_m3_s.closure` is under 1% of `recharge`;
- `wetland_on_steep_ground_cells` is 0;
- `summary.stores.cells` is above 0. Stage 3 then proves that every cell putting groundwater out has stores, because R5 stops if one has none.

Reported, not judged, against #713's table (c):

| rock | #713 base flow τ |
|---|---|
| hard rock rock store | 6 months to 2 years |
| hard rock soil store, and shale | 1 to 4 weeks (shale 1 to 3) |
| chalk | 2 to 6 months |
| sandstone | 1 to 6 months |
| karst conduit | 2 to 10 days |
| karst matrix | 3 months to 2 years |

- `summary.stores.diffuse_tau_by_rock` gives the quartiles to compare.
- Nothing should read hours or millennia.
- R4's heads on granite, slate, shale, coal and basalt move by design, because the near-surface zones now carry about 0.7 m²/day there.

### Stage 3: network (R5)

```
python tools\watershed\network.py <ws580h>\inputs <ws580h geology16> <ws580h>\glacial <ws580i>\lakes <ws580i>\groundwater <ws580i>\network
```

Pass when:
- `summary.stores.source` reads "each spring (groundwater.npz stores)";
- `density_km_per_km2.streams` is 2.25;
- every `never_see` count is 0 or empty;
- the falls are few, of varied height, and each has a cause.

Reported, not judged:
- `summary.stores.flow_weighted.dry` against `island_store.dry`;
- `perennial_km` both ways;
- `springs_over_perennial` both ways;
- `springs_by_main_store`.

### Stage 4: record (R6)

```
python tools\watershed\record.py <ws580h>\inputs <ws580h>\glacial <ws580i>\lakes <ws580i>\groundwater <ws580i>\out --network=<ws580i>\network
```

Pass when:
- r7_acceptance stage 1 passes, except two lines: `complete` stays false until rivers are carved (R6 item 3), and `missing` lists only the items it names today;
- `summary.summit_16m` equals R2b's `summit_m` (section 1).

### Zooms

Each takes a few seconds. Every zoom is drawn twice, from the same folder names:

```
python tools\watershed\plots.py zoom <ws580h>\glacial X Z [SIZE_M]
python tools\watershed\plots.py zoom_network <ws580i>\network X Z [SIZE_M]
```

The first draws the final ground beside the river-era ground and the slope. The second draws the streams by regime, lakes, falls and springs (sized by their dry flow, coloured by their main store) over the ground.

| zoom | X Z | SIZE_M | look for |
|---|---|---|---|
| Z1 starter summit | 54800 71424 | 6000 | cirques on three or more sides with arêtes between them and a pyramid top; tarns in the cirques; streams starting in the valley heads; the deeper cirques on the SE side |
| Z2 spawn | 53296 68080 | 6000 | the nearest perennial water and springs to the spawn; no stream crossing a divide; wetlands only on gentle ground |
| Z3 second massif | 66960 79296 | 6000 | the massif standing within 25 m of its 977 m; cirques and arêtes, not a dome |
| Z4 cave 3,4#8002 | 56520 72360 | 2000 | the spring at the cave mouth (533 m) and its brook; on cave-forming rock its main store is the matrix (about 250 days), so it runs through the dry quarter |
| Z5 to Z7 follow the water | the head and outlet `pos` that `follow_the_water.md` prints for its first three basins | 6000 | each basin's feature list in order on the picture: head kind, reach types, falls, lakes, wetlands, outlet |

## 4. R7 runtime work

The R7 method's eight items stand as written in [watershed_rebuild_design.md](../water/watershed_rebuild_design.md): seeding, one friction, brooks from polylines, falls, lakes, sounds, snow and fog, and checks. Steve's reader (`water_record.gd`, [stage_e_readers_design.md](../water/stage_e_readers_design.md)) serves them all. The brooks follow [cave_lod_carving_design.md](cave_lod_carving_design.md): one shape at every collision level.

This plan adds the springs (item 1 in detail) and the peaks (section 5).

### 4.1 Springs, live

The spring store's rows (`spring_store_build_plan.md` section 4) give each spring its stores, each with a share of the recharge and a τ. The runtime spring follows them.

**1. The flow through the year.** R5 adds `q_month_m3_s` (12 values) to each store row. Each value is the store's response to the island's recharge shape, at the middle of each month, times the spring's `m3_s` and the store's share. The live spring puts in the sum for the current day, read between months.
- This replaces the three season shares for springs. Reaches keep `q_wet`, `q_mean` and `q_dry` until the live sim needs more.

**2. A drought.** From the start of a rain-free spell, the weather owner keeps the spell's start day. Each store falls on its own:

  q(t) = Σ q_month,k(start) × exp(−t / τ_k).

- A karst spring's conduit part (τ 5 days) is gone in a week or two. The matrix (about 250 days) then holds it through the summer.
- A gravel terrace spring hardly changes in a month.
- A seep at the foot of drift (τ of weeks) fails in August while the rock spring above it trickles on. That is #713's honest version of the #686 line.

**3. A storm.** A storm's recharge adds to each store and drains out at that store's τ. R4 adds `gw_recharge_mm_yr` and `gw_rain_mm_yr` (catchment means) and R5 passes them to the spring row. Then:
- the storm's recharge is the storm's rain × recharge / rain;
- store k adds q_k(t) = `m3_s` × share_k × (storm recharge ÷ mean daily recharge) ÷ τ_k × exp(−t / τ_k), with the mean daily recharge `gw_recharge_mm_yr` ÷ 365.25;
- the pulse's volume is the storm's share of the year's recharge, so the year's mean does not change.

So a karst spring rises within a day and falls back within a week, as #713 lesson 3 says. A chalk or gravel spring hardly moves after a storm.

**4. Temperature.** Spring water comes out at the year's mean air temperature at its height plus about 1 °C: `sea_level_mean_c` − `lapse_c_per_km` × height in km + 1 (Anderson 2005, `springs_and_drinking_water.md`). Springs do not freeze. Seeps, spread thin, do.

**5. Drinking.** `fresh_m` now counts springs whose dry flow is at least 1e-5 m³/s, so a den or the drink search finds them. The reader's `springs_in(rect)` gives the row.

### 4.2 Who builds what

| part | owner | where |
|---|---|---|
| `q_month_m3_s`, `gw_recharge_mm_yr`, `gw_rain_mm_yr` | Sonny | R4 and R5, a short PR above #726 with its unit tests listed for David4 |
| `plots.py zoom_network` | Sonny | #726, before ws580i |
| reading the new spring keys, and live spring sources by month, drought and storm | Steve's reader; the runtime water owner for the 8 m field and the 2 m regions | after M2 |
| fall and rapids sounds from the record; the calm-lake roar | Kathleen (sound outdoors) | R7 item 6 |
| snow window and fog pools from the record | Kathleen with the weather owner | R7 item 7 |
| pictures | Dino | ws580i zooms, then the R7 walk |
| headless gates | David4 | M2 and R7 stages 2 and 3 |

## 5. Acceptance lines this plan adds to r7_acceptance.md

**Stage 2 (M2):** the in-game height at the starter summit (54800, 71424) and at the second massif (66800, 79760) equals the record's `ground` within 1 mm.

**Stage 3 (R7, David4 headless, season clock forced):**
- **Dry season.** Set the season to dry and the weather to a 30-day rain-free spell.
  - Every karst spring still runs, at least a third of its dry flow.
  - No granite or slate hillside has the rock spring and the soil seep failing together.
  - No shale valley holds a strong summer base flow: a reach fed mostly from shale runs under 0.3 of its mean flow (#713 base flow index 0.2 to 0.3).
- **Storm.** Feed a 30 mm storm.
  - Karst springs peak within a day, and a week after the storm they run under twice their pre-storm flow.
  - Chalk and gravel springs rise less than 20% in the first day. Chalk is not cave-forming here (`rock.cave_forming` is limestone and marble), so it has one diffuse store of months.
- **Spring flow.** Each live spring's flow at day 0 equals its row's month value within 1%.

**Stage 4 (Dino's walk).** The camera shots for the peaks. Positions are world x, y, z in metres. The look target is the summit, at its record height.

| shot | camera | look at | shows |
|---|---|---|---|
| C1 from the spawn | 53296, ground + 1.7, 68080 | 54800, `summit_8m`, 71424 (bearing 156°, 3.67 km) | the horn as the player first sees it, at the default view distance |
| C2 the shady side | 56214, 1200, 72838 (2 km SE of the top) | the summit | the SE cirques, the deeper ones, with arêtes between them |
| C3 the sunny side | 53386, 1200, 70010 (2 km NW of the top) | the summit | the NW faces: smaller cirques or none, never deeper than the SE ones |
| C4 the second massif | 66960, ground + 1.7, 79296 | 66800, its record top, 79760 | granite cirques and arêtes, not a dome |

Bearings are from north (−z), turning through east (+x).

Each shot is taken at noon, in clear weather, in summer (the wet quarter's end). It is then taken again with the far terrain levels forced, so the silhouette shows at every level.
- **Pass:** the top reads as a pyramid with three or more faces, at every level.
- **Fail:** any dome or ring cliff, or SE and NW faces that look the same.

**Never-see (#713, on the dry-season and storm runs):**
- a karst spring still in flood a week after a storm, or dry in a normal summer;
- a granite or slate hillside where the rock spring and the soil seep fail together in August;
- a shale valley with a strong summer base flow;
- a chalk stream that rises within hours of a storm;
- any spring whose τ reads in hours or millennia.

## 6. What does not change

- The live water stays the truth at runtime. A dug ditch still changes where the water goes, and the record is only where it starts.
- The mean water budget and the record's raster field list do not change. `network.json` rows only gain keys.
- No TERRAIN_VERSION bump comes from R7 itself. R6's rebake bumps it once.
- `network.season.baseflow_recession_days` stays as the fallback for old R4 runs. It goes to `proposed_removals/` after ws580i's stage 3 passes, and only Dave's yes deletes it.
