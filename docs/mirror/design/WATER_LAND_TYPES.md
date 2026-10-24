# Water decides the land: land types, plant nodes and succession

FINAL (Dave's answers 24 Oct 19:23 UTC folded in; see section 9). Draft 2 base 24 Oct (folds in reviews by Steve, Sonny, Kathleen, Sal; 1,921 samples per tile side confirmed in test_worldgen). DESIGN ONLY (devstop is on, no code). Asked by Dave 24 Oct 14:09 UTC.
Facts come from the code on claude/generator-v2 (head b107507), tech/WATER_FLOOD_PLAN.md and the reviews of Steve (water), Sonny (terrain), Kathleen (flora) and Sal (items).

Dave's idea in one line: look at the water that is really there, name the land from it, grow the plants that fit that name, and when the water changes let the old plants slowly die off and the fitting ones move in.

Legend: EXISTS = in the code today. PARTLY = half there. MISSING = to build.

---

## 1. What the game already knows about water

1. **Baked (static, in the tile file, 8 m grid, 1,921 x 1,921 samples):** `water_class` per cell, ONLY 4 values: 0 none, 1 ocean, 2 lake, 3 river (marsh and estuary are NOT water classes; Sonny). Marsh exists only as a BIOME from the climate step (ground under 4 m high, slope under 3 deg, moisture 0.62+, peat soil), so "baked marsh" means low flat wet coastal ground, not shallow water, `water_surface`, `moisture` (0-255), `soil` (includes peat, mud, alluvium, silt, clay), `flow` (drainage), `fertility`. EXISTS.
2. **Live (server, runtime):** the water sim (`water_sim.gd`, real shallow-water flow on the same 8 m grid) gives depth and speed per cell. `data.sim_levels` holds the settled level the tile uses. EXISTS.
3. **The water DOES change at runtime today.** (a) `dig` and `fill` (spade, DIGS2 records, replayed into tiles as they load) change the ground the sim sees. One spade sphere (about 1 m) is tiny against an 8 m cell, so a real dam needs many fills; "a dam backs water up" is plausible but NOT yet proven numerically (Steve). (b) Rain and storms only scale the SPRINGS (x10 to x20 in a big storm, lagged by minutes). Rain does NOT wet land cells; floodplain wetness comes only from river swell reaching the banks. (c) Heat: `river_dry` shrinks spring flow by up to 70% (floor 0.2 of start flow), so in summer a river can slow below 0.3 m/s. EXISTS. So dams and reroutes need no new water code, but the dam claim needs a test (R1).
4. **Limits of the live water:** at most 4 tiles run at once (centre plus river/lake neighbours), 1.2 GB water memory, one thread at 0.5 duty. Tiles outside that set keep nothing live. **A normal server start is a DRY START** (unless --settled-water): every restart refills from the springs with a 6 h simulated run (START_SECONDS 21600). The saved "DWAT" file (depth in cm, no speed) is written when a tile unloads and is NOT used at a normal restart (Steve). So land types can only change where the water is live (near players), which matches the "updates only near players" rule. EXISTS.
5. **Drawn thresholds already in code:** water counts as drawn from 12 cm (WET_M), 60 cm on steep drops, 1 cm on baked channels. Water wheel needs speed 0.3 m/s over 2 m (`data/water_flow.json`). I reuse these numbers so nothing contradicts what the player sees.
6. **Seasons and time:** one game day = one real hour (RATIO 24); year = 365 game days = 15.2 real days; seasons 91 days each (`game_clock.gd`). EXISTS.
7. **Flora today:** never baked. The server works out every 256 m chunk from the tile's biome + moisture + water class + slope + seed and stores ONLY removals (`flora_removed.json`, keyed by item id, guarded by `flora_layout.gd` VERSION). Clients get the result as `deliver_flora`. Species rules: `moisture` range, `water` list (classes it may stand in), `per_hectare` per biome. Trees and shrubs never stand in water, only at the edge (4 m margin); within 0.3 m of the water level the ground stays bare except reeds. EXISTS.
8. **Why "all land has the same plants":** biome and moisture are baked and never look at the live water. Only marsh biome cells get alder/willow style plants, and only where the bake painted marsh. MISSING link: live water -> flora.

**Answered by the team:** Steve: decayed running averages are cheap (1 byte each for depth, speed, wet share, updated once per game hour; 3 bytes x 3.69 M cells = 11 MB per live tile; save at unload AND about every 10 real minutes); a chunk-refresh push is fine (needs a protocol number); the 12 cm line, 8 m grid, 4 tiles and 1.2 GB are right. Sonny: the bake paints a river where the surface is 0.05 m above the bed and gives flow only above 0.35 km2 catchment; lakes need 0.05 km2 and 0.5 m depth; baked small streams are already 0.85-1.0 m deep; baked moisture gets +0.22 within 240 m of fresh water (a distance bonus, not a water table). The 0.12 m draw rule is runtime only, so shallow wetland CANNOT be read from the bake.

---

## 2. Land types (classes) and how a cell gets one

Each 8 m cell is read through **slowly decaying averages** (time constant about 30 game days = 30 real hours; not a stored 30-day history) so a single storm does not rename the land. Three one-byte numbers per cell: depth, speed, wet share (share of time with water over 12 cm), updated once per game hour.

**Floors from the bake (Steve and Sonny):** the baked `water_class` (lake, river) is a FLOOR. A cell the bake calls river stays river-or-wetter even if a summer drought (`river_dry`) drops its speed under 0.3 m/s; it can be demoted only by a long, real loss of water. The baked marsh and peat biome is the natural baseline for marsh/bog. Wide flat valley floors beside rivers are the floodplain candidates.

| Type | Depth (mean) | Speed | Wet share | Extent | Notes |
|---|---|---|---|---|---|
| Lake | 1.0 m or more | under 0.1 m/s | 90%+ | 4+ cells joined | Dave: no minimum lake size for the bake; for the runtime label 4 cells stops puddles. Ponds are never placed. Open water, shore ring below. |
| River | 0.12 m or more | 0.3 m/s or more | 80%+ | strip of any length | Same 0.3 as the water wheel rule. Up to 20 m deep at the mouth (Dave 24 Oct). |
| Marsh (open wetland) | 0.12-0.6 m | under 0.3 | 70%+ | 8+ cells (about 500 m2) | Reeds and sedges, no trees. Mineral soil. |
| Swamp (wooded) | 0.12-0.6 m | under 0.3 | 70%+ | 8+ cells | Marsh conditions on fertile mineral soil, low and warm: trees tolerate it. |
| Bog (peat) | 0.05-0.4 m, slow drain | under 0.1 | 60%+ | 8+ cells | Peat soil or a cool wet flat; acidic, poor soil, low fertility. |
| Floodplain / wet meadow | 0-0.5 m | any | 5-40% (floods then drains) | beside river | Seasonal flood land; the best soil (alluvium) = farmland. |
| Shore ring | within 3 cells of lake/river/marsh | n/a | n/a | n/a | Water-edge plants (the existing 4 m edge margin, widened to a belt). |
| Dry land | else | n/a | under 5% | n/a | Today's biome flora unchanged. |

Swamp vs marsh vs bog is decided by soil and climate, not by water alone: peat or cool + low fertility = bog; fertile mineral soil + warm = swamp (trees); otherwise marsh. Water only says "it is shallow and boggy".

**Dead-end cases (decided here, easy to change):** rivers wider than 3 cells keep lake rules in the middle only if speed is under 0.1; a river that is dammed becomes lake upstream and floodplain/marsh downstream by itself, because speed and depth change.

---

## 3. Plant nodes: data model

1. **Node = 32 m x 32 m block (4 x 4 water cells), 64 per flora chunk.** Small enough for a pond, big enough that a tile is cheap. Chosen by me (technical).
2. **Most land has no node record at all.** A node without a record is in its natural state: the placer gives exactly today's flora (no change, no storage, no risk).
3. **A record exists only where the live water disagrees with the natural type** for longer than a deadband (default 10 game days, stops flicker). Record: `{node, from_type, to_type, t0_day}` plus an optional `second_from` if the target changes again mid-change (see 4.7). About 20 bytes each.
4. **Derived, not stored, per plant:** every plant has a fixed hash h in [0,1) from (flora seed, chunk, species, item id). The placer already makes that stable id. With p = progress of the change for that plant's life form:
   - an OLD-type plant survives while h > p, and starts dying at h <= p;
   - a NEW-type plant exists once h <= p (young first);
   - nothing per plant is saved, only the node record, so removals and the layout version keep working.
5. **Baseline rule (important, confirmed by Steve):** because every normal start is a dry start that refills over 6 simulated hours, the natural type comes from the BAKED tile (biome marsh/peat, lake/river classes, soil, moisture) plus the settled water, never from the first minutes after a restart. Counting changes starts only after the tile's settle stop test passes. The saved signature (section 3.6) is what carries a real change across restarts; if it is missing, the node is natural.
6. **Persistence:** the running signature (3 bytes per cell, 11 MB per live tile) plus the sparse node records go in a new per-tile file next to the water file, versioned like `water_store.gd`, saved at unload and about every 10 real minutes. MISSING.
7. **Reversal:** if the water goes back before the change is done, the record flips direction from the current progress (no pop). If it changes to a third type, the node keeps its dominant current type as `from_type` and restarts (a small visual pop is accepted).

---

## 4. Succession over time

**4.1 Speed.** Each life form has its own duration D (game days; at one game day per real hour, 24 game days = one real day):

| Life form | Drowns / dries out over | New type arrives over | Real time (24 game days = 1 day) |
|---|---|---|---|
| Herbs, grasses, reeds | 10-20 days | 10-20 days | half a day |
| Shrubs | 30-60 days | 40-80 days | 1-3 days |
| Trees (adult) | 60-150 days (about a season to 1.6 seasons) | saplings from day 40; adult size is slow | 3-6 real days to die; new woods grow over a month+ |

2. **Stress only in the growing season** (spring to autumn counts 1.0, winter 0.25) so a winter flood does not kill a forest overnight. Per-species wet and dry tolerance goes in `flora.json` (MISSING, Kathleen's values): willow and alder high wet, low dry; oak and sweet chestnut medium; spruce, balsam fir and beech low wet (die first in a flood); scots pine, wardpine and birch tolerate bog; fruit trees low wet.
3. **Dead trees visible?** Yes, I recommend it: a tree that "dies" stays 20-30 game days as a bare dead tree (grey/leafless; the models already have bare variants for berries, and `young` sizes), then falls and vanishes. It gives firewood and tinder fungus (tinder_fungus is a listed species). Kathleen: dead variant = bare trunk, snapped limbs, grey bark, no crown, about 40-60% of the live triangles, one extra mesh per species (MISSING), then a fallen log. Saplings reuse the young-size builder at 15-40% height. **GAP (Kathleen):** a flora item today is only species + cell, so the client cannot know "dead": R3 needs a state byte (alive, dying, dead, sapling) in `deliver_flora` or a separate dead item id range; tell Steve before R3 (new protocol number). Without it: trees just vanish at the chunk refresh (cheap first version).
4. **Replacement rules:** the new type brings its own species list (section 5). A new plant is placed only where the old one is gone and the slope/water/soil rules pass (same checks the placer already runs). Pioneer order: herbs first, then shrubs, then trees. A drained lake bed (mud, lake sediment) starts bare, then tall grass, nettle, dandelion, then willow/alder, then meadow or woods.
5. **Performance:** the water thread already runs only near players. Signature update = one pass over WET cells once per game hour (wet cells only; a dry tile costs nothing). Nodes re-evaluate once per game hour for records near players; the server calls the existing `server_flora.invalidate(chunk)` and resends the chunk only when a progress step passes 10% (not every tick). **Offline catch-up:** progress is a function of the clock (`now - t0`), so a chunk nobody visited for a month just reads the right state the moment someone arrives. No per-day simulation.
6. **Protocol:** none new for R1/R2. R3 needs the dead/sapling state byte and a chunk refresh (resend is fine per Steve; a new message takes the next protocol number, 77 Steve, 75 Sal were taken).
7. **Rollback safety:** the node file has a version; a bump or bad file means "all nodes natural". Nothing in the bake or tile files changes.

---

## 5. Plant lists by land type (our species, from `flora.json`)

All names below EXIST in flora.json (127 entries; Kathleen). Fields to add: a per-type `per_hectare` weight (like today's per-biome weights) and the wet/dry tolerance.

| Type | Trees | Shrubs | Plants / herbs |
|---|---|---|---|
| Lake shore ring | willow, alder (edge) | hagwillow | reeds, riverbraid, stormreed, stillwater_lotus (lake), tall_grass |
| River bank | willow, alder | hagwillow, elder | watercress, wild_mint, meadowsweet, angelica, reeds, riverbraid |
| Marsh (open) | few alder | none | reeds, cotton_grass, stormreed, comfrey, valerian, meadowsweet, angelica, wild_mint, cranberry, cloudberry, pilgrims_cup, wispbloom (night glow) |
| Swamp (wooded) | alder, willow, mangrove (warm coast only) | hagwillow, elder | fern, hushfern, mushrooms, tinder_fungus, fly_agaric, nettle, reeds |
| Bog (peat) | stunted scots_pine, dwarf birch | dwarf_birch, heather | cranberry, cloudberry, cotton_grass, crowberry, blueberry, staunchmoss, heather |
| Floodplain / wet meadow | willow, alder, oak on the dry edge | elder, hazel | tall_grass, meadowsweet, nettle, wild_garlic, comfrey, flax, dandelion |
| Dry land | unchanged | unchanged | unchanged |

Missing wet species (Kathleen), priority first: cattail/bulrush, sedge tussock, sphagnum look, marsh marigold; then sundew, bog asphodel, bog myrtle, yellow flag iris, purple loosestrife, horsetail.

**Items (Sal):** thatch EXISTS (item 1146; reeds, tall grass and heather yield it) but no recipe uses it yet. Reeds give thatch + plant fibre. Peat: digging peat soil (soil 6) gives only generic soil; there is NO peat item, fuel or recipe. Add a `peat` gathered item, only in bog cells. Bog iron is missing entirely (new item, ore row, recipe; DESIGN_IDEAS derives it at runtime from marsh biome + peat soil). Clay is fine (dig yield, used in clay pot and stone forge kit). Lotus, cotton grass and riverbraid have no gathered item; cattail and sedge are missing.

**How to get the species into the placer without new code first:** map each land type to a virtual biome and moisture the placer already understands. Marsh biome (id 10) already feeds alder 30/ha and the `water: [marsh]` species. New biomes `swamp`, `bog`, `floodplain` are append-only rows in `biomes.json` plus per-hectare columns in `flora.json`; the flora layout VERSION is bumped when they ship.

---

## 6. Player effects and the bake

1. **Dams, reroutes, floods, drying** are already physics (section 1.3). Land types follow within about 30 game days of the new water settling; the first visible change is the herbs, then shrubs, trees last.
2. **Flood:** storm and spring-melt floods raise water briefly; they only make a floodplain (wet share 5-40%), they do not rename land to swamp, because of the long window. Flood damage to crops and buildings is the separate plan in tech/WATER_FLOOD_PLAN.md (damage numbers wait for Dave). Combine later: repeated floods = more floodplain plants.
3. **Drying out:** a cut-off lake shrinks, edge cells fall under the wet-share threshold, become bare mud, then pioneer plants, then dry-land plants. A drained marsh turns into wet meadow, then farmland-capable ground.
4. **Farmland (Dave 24 Oct, NO to "exempt"):** farmland is NOT exempt from the water. It must never change overnight. If the water is rerouted or floods a field, a **timer starts** that slowly hurts the crops; it takes about **a week** (Dave: "at least a week"; set to 14 GAME days = 14 real hours at one game day per real hour, as ONE tunable value `farm_flood_days` in the water-land table; a real week would be 168 game days, which I read as too slow, so confirm if he meant that) before the crops die. The farmer can find the cause and fix it, dig ditches to run the water off, or build dams and ditches around the field. **Once the water clears, the land stops being under threat of change** and the timer resets. Same logic for the wild land change: the timer (the node's progress) runs back if the water returns to normal. Hoe and spade EXIST, but the hoe only treads paths and nothing tracks tilled cells; farmland cells and crop growth are MISSING (Sal). A tilled cell reads waterlogging from the same signature (proposed, to confirm with Steve).
5. **Tile bake stays static.** No rebake is needed: baked `water_class`, `moisture`, `soil` stay the natural baseline; the live signature and node file sit on top. Rivers, lakes and the settled water in the bake are untouched. A rebake of the island later just resets the baseline (natural nodes). The only bake tie: if Sonny later bakes real swamp/bog/marsh biomes, the natural type gets them for free.
6. **Soil under the new type?** Real swamps lay peat and mud. Version 1: no soil change (plants only). Version 2: a drained lake bed keeps mud/lake_sediment colours until plants cover it (colours already derived at runtime, per ground-colours note).

---

## 7. Staged plan (nothing needs a bake)

**R1: Name the land (about 2-3 build slots).** Read only. Also run the dam test: how many fills make a dam that really backs water up? Per-cell running signature, classification, a debug view (admin overlay: lake/river/marsh/swamp/bog/floodplain/dry), tests on the nine starter tiles. Result: Dave can SEE where the game thinks each type is, before any plant changes. Needs: Steve (signature + file), Sonny (check the baseline against the bake). No gameplay change, zero risk.
**R2: Plants follow the type (about 3-4 slots).** Natural types (baked marsh/peat biome plus river/lake classes) drive the plant lists (new biome rows, flora.json columns, wet/dry tolerance), so baked swamps, marshes and bogs already look different. Add cattail, sedge tussock, sphagnum, marsh marigold and a `peat` item here. Still no change over time. Needs: Kathleen (lists, numbers), Sal (peat/reed links), flora layout VERSION bump.
**R3: Succession (about 3-5 slots).** Node records, dead/sapling state byte, progress by hash, offline catch-up, chunk refresh, dead-tree look (or a fade-out first), save file. Then dams and reroutes show their effect on plants. Needs: Steve (server hook and refresh), Kathleen (dead tree, saplings), Sonny (test dam/reroute on the starter river).
**R4 later:** farmland ties, soil change (peat growth, mud drying), flood damage (flood plan), a player "survey" hint ("this ground is turning to marsh").

**Build order after the devstop (final):**
1. R1: land-type signature and admin map (Steve + Sonny, baseline from baked biome and river/lake classes, counting after the settle).
2. P1 dam test (with R1): sim-side set-ground-height step, scripted fills in the starter river, measure level upstream.
3. P1b water stability test: time step from wave + flow speed, outflow limited to donor water, scripted 3 m pond breach, mass balance, no NaN.
4. R2: plants by land type (new biome rows, per-type weights, wet/dry tolerance, new species cattail, sedge tussock, sphagnum, marsh marigold, peat item).
5. P2: barrier records, load and capacity, warning, slow breach.
6. R3: succession (node records, dead/sapling state byte, chunk refresh, farmland flood timer).
7. P3: wash-away (client sweep, server damage check, item sync), then structures.
8. P4: bridge pieces and flood ratings (Sal).

## 8. Honest feasibility

- Easy: classification (reads data the sim already has), plant lists (species and water rules already exist), persistence (small files like the water store).
- Medium: the baseline rule across restarts and dry starts; making the 30-day window feel right; tuning thresholds on real tiles.
- Hardest: dead trees and saplings that look right, and keeping chunk refreshes cheap while many players are in one valley.
- Risk to watch: summer drought (river_dry) making a river read as marsh (answer: baked class is a floor); a dam that never actually raises the water (test in R1); any spot where the sim never settles (leaky edges) would read as a lake; the deadband plus the settle rule (3.5) protect against it.
- Not in scope: ocean/estuary succession, snow/ice, fire.

## 9. Final decisions (Dave, 24 Oct)

YES: wl-r1-first (R1 first, with the dam test), wl-window (30 game day slow average), wl-dam-order (dam test, then water stability test, then strength and breach, then wash-away), wl-bridges (low plank bridges and fords wash out in floods, high stone bridges with piers survive), wl-dead-trees (dead trees visible 20 to 30 game days, then fall), wl-tree-speed (trees die over 3 to 6 real days, herbs half a day), wl-soil-types (swamp, marsh or bog by soil and climate), wl-lake-size (4+ cells = lake label), wl-dam-strength (material, thickness, bracing; dirt erodes if overtopped), wl-dam-breach (slow, with warning), wl-wash-away (client sweep, light damage, no death at first), wl-flood-plain (flood = floodplain only).

NO, with a better rule: wl-farmland. Farmland is not exempt. A flood or reroute starts a slow timer (about a week) that hurts the crops. Ditches, dams around the field and fixing the cause stop it. When the water clears the land stops being under threat (see 6.4).

Technical choices (node size, window, deadband, file format) are mine.

---

## 10. Dams, water pressure, breaches, wash-away and bridges (Dave 24 Oct 15:52)

Dave's rules: a dam must hold the water that backs up behind it. An alternate route that lets water run away relieves the pressure and is fine. Too much load and the water breaks the dam, a structure or player-placed dirt. Stone holds more than dirt; bracing with stone or dirt behind holds more. A breach washes players and things downriver. This makes bridges important. PLAN ONLY, build after the devstop.

### 10.1 What the water code does today (EXISTS / MISSING)
1. Shallow-water flow on the 8 m grid with gravity, Manning friction and a speed ceiling of 12 m/s (`water_sim.gd`). EXISTS.
2. Ground is one height per 8 m cell. `fill` raises a cell to the top of a spade sphere, `dig` lowers it; both are saved (DIGS2). The sim has NO idea of material, thickness, strength, load or breaking. MISSING.
3. Water has no pressure rule beyond its level, and nothing moves a player or item with the current (Steve confirmed). MISSING. Swimming and oxygen cover deep water but nothing fights the current yet.
4. Whether a player-built dam really backs water up is unproven (a ~1 m sphere is far smaller than an 8 m cell). Test it first (R1 dam test).
5. The flood plan (tech/WATER_FLOOD_PLAN.md) already proposes a once-per-minute check of water level at each placed item's footprint for crop and building damage. Reuse that hook. PLAN only.

6. **Where a dam works (Sonny):** a dam only backs water up if it spans the WHOLE valley floor, wall to wall, and stands taller than the flood stage. Lowland floodplains sit only about 0.4 m above the river, so water simply goes round. Ground is one height per 8 m cell and a brook is 1-2 cells wide, so two raised cells close a brook. Run the R1 dam test in a gully or canyon reach (steep walls, 10-25 m deep), and at least 1 km from tile edges (tiles settle alone; seams can differ by about 1 m).

### 10.2 Pressure and strength model (simple, game-scaled; numbers are placeholders to tune)
1. A dam is a **barrier record**, not a sim change: `{line of cells, material, height, thickness, bracing, built_day}`. Sparse, a few bytes, saved with the tile. The ground height in the sim still comes from fill/dig, so the water behaves as it does now; the record only decides when the barrier FAILS.
2. **Load** per metre of dam = (upstream depth at the dam minus downstream depth) squared. Real water pressure grows with depth squared, so doubling the depth gives four times the load.
3. **Capacity** per metre = material strength x thickness x bracing factor.

| Material | Strength | Notes |
|---|---|---|
| Loose dirt | 1.0 | cheapest; overtopping erodes it |
| Packed earth / clay core | 1.5 | clay (exists as a dig yield) seals seepage |
| Wood / log crib | 1.5 | rots over time (later) |
| Stone | 3.0 | holds most; stone piles exist |
| Mortared stone | 4.0 | later tier |

Bracing: dirt or stone piled behind (downstream side) x1.5, stone buttress x2.0. Thickness counts in metres, minimum 1. Example (placeholder): a 2 m thick dirt dam holds about 1.7 m of water; the same in stone about 2.8 m; stone braced with stone about 3.9 m.
4. **Spill relief:** any water leaving over the crest, through a spillway or into an alternate channel lowers the upstream depth, so the load stays under capacity. This falls out of the sim for free, because the level is real. A built spillway (a low stone notch) is the safe way to hold a big pond.
5. **Overtopping:** earth fails if water flows over the crest deeper than about 0.2 m for about 5 game minutes (erosion). Stone does not erode. This is the main real-life dam failure, so it is in version 1.
6. **Cumulative stress:** load over 80% of capacity for a long time (hours) slowly weakens the dam; a quick storm that peaks high does not break it. Keeps the system kind to players.

### 10.3 Breach and wash-away
1. **Breach:** when load exceeds capacity (or overtopping erodes), the barrier fails over 30-90 real seconds: the cells of the record are lowered with the existing `dig` step by step, starting with a notch at the weakest point and widening. The sim then releases the water at its own pace (Dave decided earlier: "breaking a dam lets the stored water run out at the same visible pace"). No new flow code.
2. **Warning (kind to players):** a groan and creak sound plus a chat line ("The dam is straining") at 80% load, and a rumble before the notch opens, as in the flood plan. A breach is never instant.
3. **Wash-away rule (new, MISSING):** movement is client-authoritative, so the sweep is applied in the CLIENT controller from the water grid velocities it already draws with; the server only validates damage. Items are server-owned and move through the existing item sync (once a second). Hazard, for entities standing in wet cells, hazard = depth x speed (m2/s). Under 0.3: wade. 0.3-0.6: slowed, stumble. Over 0.6 (the usual real flood-safety line): swept, pushed at about 60% of the water velocity, tumbling, until the water is slower or the player swims or grabs the bank. Loose dropped items and small light objects (crops, fences, light sheds) are carried the same way and dropped where the water slows. Damage: light (bruises), no death in version 1 (the principles say safe and kind); oxygen and swimming exist and cover deep water (Steve to confirm).
4. **Structures:** low buildings and fields use the same hazard check against a rating per building tier (thatch low, log medium, stone high), using the flood plan's once-per-minute footprint check. Damage rules wait for Dave's numbers, as the flood plan says.

### 10.3b Sim stability and the ground step (Steve)
1. **Time step is the real risk, not the 12 m/s ceiling.** Today dt ignores flow speed: wave speed 5.4 + flow 12 = 17 m/s over an 8 m cell needs dt under 0.32 s, while a 3 m pond runs at about 1.0 s. Fix: dt from sqrt(g h) plus the fastest face speed, and limit each face's outflow to the water in the donor cell.
2. **Test first:** a headless scripted breach of a 3 m pond; check mass balance, no NaN, no sloshing.
3. **Ground step:** a breach by dig lowers voxels, but the sim cell height follows only through ~1 m edit spheres on 8 m cells. The barrier record needs a sim-side "set ground height" step (the same one the dam proof needs). MISSING.

### 10.4 Server cost
Barrier records are tens per tile, checked once per second only for live tiles. The wash-away check is one pass per second over entities in fast wet cells. Neither touches the water thread; a breach by dig must NEVER run during a settle (Sonny); the breach uses the dig the thread already replays. The risk is sim stability at a breach (speed ceiling 12 m/s) and the dry start: every restart refills from springs over 6 simulated hours, so a dam must not fail during that refill (R1 and R2 soak tests). Dams are ground edits applied before the settle, and big ponds will not be full when the 6 h settle ends, so barrier checks start only after the settle, "still filling" is normal and never a failure, and the saved water (DWAT) must be kept at unload so restarts do not empty ponds.

### 10.5 What to build first
1. P1 (with R1): prove a dam backs up water, with the sim-side set-ground-height step. Scripted fills in the starter river, measure level upstream.
2. P1b: stability test (time step from wave + flow speed, outflow limit, scripted breach of a 3 m pond, mass balance). Must pass before any breach ships.
3. P2: barrier records, load and capacity, warning, breach. Flooding only; nothing is swept yet. Checks start only after the dry-start settle.
4. P3: wash-away (client controller sweep from water velocities, server validates damage; items via item sync), then structures.
5. P4: bridge pieces and ratings (below). Needs Sal.

### 10.6 Bridges
Rivers now matter: you cross them safely or get swept. Needs, for Sal (building tiers): (1) a **ford** (shallow stretch, hazard under 0.3, marked with stepping stones, free); (2) a **log or plank bridge** (cheap, deck low, can be washed out); (3) a **stone bridge with piers** (high deck, survives floods). Each bridge has a **deck height** that should sit above the flood stage of THAT river (normal depth from the bake, 0.85-1.0 m for small streams, plus the storm rise Steve measures; about 1 m clearance). Flood stage per river needs no terrain change, and **piers in the water** take load by the same depth x speed rule on their cross-section. A bridge whose deck goes under or whose piers are overloaded fails like a dam: warning, then the deck floats away and carries anything on it downstream. Building tiers need a span piece and a pier piece with a flood rating per tier; the flood plan's footprint check is reused. Everything on a failed bridge is lost only if the player ignored the warning; players standing on it get the swept rule.

---

## 11. STATUS: UN-PARKED (Dave 24 Oct 19:42 UTC: "the water and fish are part of all that")

Work restarts at the build order in section 7, as plans and branch work. Devstop still holds merges and bakes. First plan: design/WATER_ACTION_PLANS.md (branch claude/water-r1-landmap: R1 land map + dam test). Fish and drinking water (EARLY_GAME_LIST items 8, 9; FISH_AND_FISHING_PLAN.md) read the same water; the land-type map gives them "fishable water" (lake, river, deep) for free.
