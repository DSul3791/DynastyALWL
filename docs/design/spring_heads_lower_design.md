# Spring heads in the green belt (design, Steve, 9 Nov 2026)

Dave, 17:14 local: "change the generation that places the springs to move them down along their own flow path until they are within the bushes and grass belt where we will cover them with grass, some bushes and tall grass because the water makes life abundant there. which also is a great place for animals to visit regularly because of the abundant water and food for them."

Being built now (Dave 17:42 local lifted the hold). The measurements behind it are in spring_heads_lower_note.md; the species are in Kathleen's spring_green_ring_species.md (both in the shared flora folder).

## 1. The walk-down (water record, tools/watershed/network.py), PR 1

**The belt.** A head is in the green belt when the ground round it is 30° or less, averaged over 48 m (3 × 3 cells of the 16 m grid). This is the rule as built: `spring_heads.belt_slope_deg` in params.json.

It replaces the first draft's three-part test (slope ≤ 40°, grass soil, fertility ≥ 20). That test, run along the stream, landed heads in gorges whose banks were bare. Since #863 the tile's soil follows slope: good soil grows to 30° and stony soil to 45°. So the slope of the surroundings is the honest measure, and network.py can see slope, where it cannot see the tile's soil.

I checked this against the baked tile 3,4. A head counts as having green banks when, on the dry ground within 16 m, at least half is grass soil and at least half has fertility of 20 or more.

| | Heads with green banks |
|---|---|
| Today | 86 of 187 |
| Under the rule (first estimate, a straight downhill walk) | 152 of 187 |

The prediction below follows network.py's walk and replaces this estimate: 87 of 196 green today, 140 of 189 after.

**Walk.** A spring head outside the belt moves down its own flow path, at most 800 m, to the first belt cell. It walks on past a junction with another stream. Past the junction the spring comes up on the bank of the joined stream, and only its own branch, above the junction, goes dry. A belt cell another spring already took is passed, so the spring comes up at the next belt cell down the bank and two springs never become one. If both branches above a joined stretch move down past it, that stretch goes dry too. (Fixed 9 Nov 2026 after Dino's first rebake: that walk stopped at the junction and turned about 70 heads on tile 3,4 into seeps, so ground springs fell from 196 to 131.)

**Stream above the new head.** The cells above the new head stop being stream (`vis` off). They become dry gullies. Their water still runs down in the flows, so the flow downstream is unchanged. The new head carries the old head's groundwater and dry-season flow, and records where it came from in `lowered_from`.

**No belt cell within 800 m.** The head is a seep, not a spring. Its runnel stays as it is, with no spring cover and no drink point. That is honest for cliff country.

**Not affected.** Lake outlets and seeps are left alone.

**Predicted from the baked tiles (main at 5656b986).** This follows network.py's walk, junctions included. It walks the steepest-descent path on the tile heights at 16 m and judges the belt by network.py's slope rule:

| Tile | Ground springs today | Stay | Beach | Walk down | Seeps | Springs after | Green banks today → after |
|---|---|---|---|---|---|---|---|
| 3,4 | 196 | 84 | 9 | 96 (median 199 m) | 7 | 189 | 87 → 140 |
| 4,5 | 66 | 23 | 0 | 28 (median 296 m) | 15 | 51 | 24 → 42 |
| 3,3 | 19 | 10 | 4 | 5 (median 96 m) | 0 | 19 | 9 → 12 |

Tile 4,5 is cliff country: 15 heads have no belt within 800 m, so they become seeps by design. The spring caves are rolled from the spring heads afterwards, so the cave count can move too. Heads in flatter ground pass the hillside test for a cave less often, and the floor of one den per tile still holds.

The network run on Dino gives the real counts. They are printed in the summary as `spring_heads_lowered` and `cliff_seeps`.

**Record changes.** These follow by themselves:
- the heads and reaches;
- `below_spring_m` and `spring_y`;
- the drink sections;
- the tile's water class, and with it the settled water. The settler puts its springs at the reach heads.

**Versions.** TERRAIN 75, FloraLayout 30 (#870, the growth rule, took 29 when it merged first).

## 2. Plants grow thicker by water (Dave, 17:42 local), PR 2

Dave, 17:42 local: "they grow 100% thicker, and grass grows taller right at the water and its growth deminishes as it gets further from the water until it gets to normal growth at 6 meters away."

At 17:44 to 17:45 local he gave the purpose: "if someone carves a trench to water their crops the crops will grow better out from around the trench. and multiple ditches could irrigate a nice farm".

**One growth rule in the plant code.** Every species and the grass read the same value: the distance d from the plant to the nearest water edge. The wetness is

W = clamp(1 − d / 6 m, 0, 1).

| At W = 1, the water's edge | Effect |
|---|---|
| Plants and shrubs | density × 2 (one extra candidate with chance W next to each normal one, so the boost fades with W) |
| Grass | thickness × 2 and taller (Kathleen, client grass) |
| Plant size | up to 25% taller |
| Moisture filter | wet-ground species qualify by the bank |

At 6 m from the water, everything is normal growth. The same 6 m fade applies to every water: spring heads, brooks, rivers and lakes. It replaces the 12/20/30/60 m reaches of the first draft.

**Live water, not a baked section.** The distance is measured at runtime from the live water: the tile's water level plus the dug-region water (Sullivan water). That covers:
- natural rivers, lakes, brooks, seasonal brooks and springs;
- a player's trench, ditch or pond, as soon as water stands in it.

So several ditches irrigate a farm. Nothing is baked: an 8 m tile sample is wider than the whole 6 m fade, so a baked field could not hold it anyway. The 4 m bank and bed margins stay as they are.

**Kept cheap.**
- The placer works out W once per 2 m cell per chunk.
- It only does so for chunks with fresh water within reach. Everywhere else nothing changes.
- Nothing runs per frame.

**Live water and trenches.** Plants follow a new trench the next time that flora chunk is rebuilt, for example after a server restart. That is not instant. Kathleen's grass (#869) reads the live water each time a grass cell is built, so it greens up right away. Crops will read the same W live once farming exists.

As built in #870:
- a second plant per cell, W of the time, on new item numbers;
- plants up to 25% taller;
- the ground reads up to 50/255 wetter for the moisture range;
- trees unchanged;
- a bank 3 m or more above the water stays normal (Kathleen's roots factor).

**Spring heads.** A ground spring is water too, so its surroundings get W = 1 at the head without a separate ring. Kathleen's wet-ring species (tall_grass, fern, meadowsweet, angelica, valerian, comfrey, nettle, mint and watercress at the bank) are the species that qualify there through the moisture filter. The core hiding clump stays.

**Next step (not in PR 2): drought.** This is the other end of the same rule. Where the moisture is low and no water is within reach, growth drops below normal: thinner, shorter and paler, with dry-ground species favoured.

**Crops.** When farming lands, crops read the same W. A bed within 6 m of water needs fewer buckets and grows faster. That is Dave's irrigation case. Farming is not built yet: crops.json is read by nothing.

## 3. Animals come to the springs (server_animals.gd)

**What exists today.** At twilight, deer and stock go to water with a 0.7 chance, within 300 m. `drink_spot` searches rings 25 m apart in 8 directions for a fresh water surface. Each animal stands 60 to 180 s in GRAZE, then goes home. Wolves wait `wait_m` back from the same spot (`wolf_wait_point`). Springs stay open in frost (`spring_ice_x`). A spring runnel is narrow, so the ring search mostly misses it. In effect, springs are not drink places for animals today.

**Minimal hook: three small changes, no new system.**

1. **Springs first.** `drink_spot` first looks at the tile's ground springs within reach. These come from TileTerrainData.ground_springs, the same list DrinkRules reads. The nearest spring wins:
   - the water point is the head;
   - the stand spot is 4 m out on the dry side, on the ring.

   Only when no spring is within reach does the ring search run. The result is cached per 50 m cell, as today.
2. **Stay to eat.** After drinking at a spring, the animal grazes in the ring for one more graze span inside 10 m (`spring_graze_s`, about 120 to 300 s). Then it goes home. The food bushes put goblin and berry foragers there too, through the existing `berry_bushes` hook.
3. **Wolves follow.** No change is needed. `wolf_wait_point` already uses `drink_spot`, so packs will wait near springs at dawn and dusk. Springs become hunting ground too.

In winter, springs that stay open become the main water, which fits the ice rule already in place.

## 4. Build and bake

**PR 1: walk-down.**
- network.py, params.json and test_network.py, with TERRAIN 75 and FloraLayout 30.
- Bake class. David4 runs the Python tests, then Dino reruns network, record, the 9 tiles (9 threads) and settle, with the tiles on the branch.
- About 10 min, estimated from today's stages: network 57 s, record 53 s, bake 132 s, settle about 6 min. Not timed yet.

**PR 2: growth rule and animals.**
- The placer's growth rule, Kathleen's client grass, and the animal spring hook (section 3).
- Code class, with no rebake. It takes one FloraLayout bump.

**Tests.**
- PR 1: the head walk-down, the seep fallback, a head in the belt staying, a lake outlet staying, and the belt slope.
- PR 2: W at 0, 3 and 6 m; a doubled density at the edge; a trench counting as water; `drink_spot` picking a spring.

## 5. Next: one growth rule for the whole island (Dave, 17:50 local), design only

Dave, 17:50 local: "normal rain conditions soak the ground and provide a certain amount of water reserve in the ground. if for some reason its raining alot in an area that provides lots of water but it reduces the amount of sun and most plants need sun. some plants will thrive in the wet dark and some will struggle and rot. but the other way can happen too. too much sun and not enough rain. the ground will have different types of soil as well so rich farming land with tree cover and irrigation will thrive with sun and water but poor soil miight dry out to fast. in the future we also need to have a way for farmers to adjust the soil with machinery and pete, sand, clay etc."

Section 2 is the first input of a single rule. Every plant, the grass and later crops read one growth score from four inputs. Each species compares that score with its own preferences.

| Input | Where it comes from | Exists today |
|---|---|---|
| **Water by the plant** | W, from the live distance to the water's edge (section 2) | yes, #870 and #869 |
| **Water held in the ground** | a reserve per soil sample: rain fills it, sun and wind empty it, and it is capped by the soil's holding capacity (clay and peat hold a lot, sand and gravel little). It is the tile's moisture as the base, plus the weather's recent rain | moisture and weather exist; the reserve is new |
| **Sun** | the cloud cover from the weather (a long wet spell is dark), plus canopy shade (the placer already knows crowns) | weather cloud exists; shade exists in the placer |
| **Soil** | the soil id and fertility per sample | yes |

**How a species reads them.** Each flora row gets a water range and a sun range, with a "likes wet and dark" or "likes dry and bright" lean:
- ferns, moss, mushrooms and meadowsweet thrive in the wet and dark;
- grain, berries and grass want sun;
- heather and gorse take dry and poor ground.

Growth is best inside both ranges. It falls off outside them: rot when too wet and dark, drought when too dry and bright. Poor soil narrows the water range, so sand dries out first. Rich soil widens it.

**What it changes.**
- Density, height and colour: greener when thriving, yellow when in drought, brown and patchy when rotting.
- For crops: speed and yield.
- Irrigation is simply W on top of the reserve. A ditch beside a sandy field keeps it in range through a dry spell.

**Soil amendment (future).** A farmer can change a soil sample's id or capacity by working in peat, sand or clay (and later with machinery). That moves the field's ranges. It needs a saved per-sample soil edit, the same kind of store as digs.

**Cost.** The reserve is updated once per game hour per loaded tile, at 8 m samples. Plants read it when their chunk is built, and grass and crops read it live. Nothing runs per frame.

**Order.** First the reserve and sun inputs, read by crops when farming lands. Then the flora placer reads the score in place of today's fixed moisture filter. Soil amendment comes last.

## 6. Weather (future, Dave, 18:08 local), design only

Dave: "I don't believe they should move or travel like in the real world but each zone gets its own weather systems based on there climate zones and latitude."

- **Rule.** Weather does not travel across the map. Each climate zone (its latitude row) makes its own weather: its temperature range, how often storms, light rain or snow come, and the mix between them.
- **Day and night.** The sun's day and night cycle drives the daily temperature swing.
- **What exists today.** src/shared/weather.gd already works this way. It is a pure function of the seed, the clock, the zone row and the altitude, and nothing moves across the map. Its "fronts" are spells in time within one zone. climate.gd gives each zone its mean, seasonal swing, daily range (the day and night swing) and rain per year.
- **Still to decide.** How far the zones differ from one another. Whether neighbouring zones blend at their borders, so that a step from one row to the next is not a cliff. And whether mountains get their own local storms beyond the altitude cooling.
- **Link to section 5.** Rain fills the ground reserve, and cloud cuts the sun, so the growth score reads the zone's own weather.

**Chosen direction (Dave, 18:13 local).** "neighbors east and west share similar weather patterns ... a server based weather map that sends randomized weather across the map following the sun or the spin of the earth ... each client gets the weather from the server no matter where they are and its interpreted according to what lattitude they are in on the map."

- **One weather field, read by latitude.** There is one random weather field over the whole map. Each place reads it through its latitude row: the temperature, rain or snow, and storm or light rain. Borders are seamless east and west.
- **How today's code fits.** It already is one field. `Weather.state(seed, clock, zone, altitude, row)` takes no east-west position, and the front noise has no zone in it, so every row sees the same fronts at the same moment. The zone only decides what a front means: a rainstorm in the temperate rows, snow in the arctic rows, nothing much in the desert rows. So a sailor crossing an east-west border today sees no jump.
- **Who computes it.** The server is the authority (it uses `_weather_at` for thunder, rivers and animals). Each client works out the same answer from the same seed and clock, so no weather is sent over the network.
- **What changes.** Fronts move along the rows. The noise is read at (clock − x / speed), so a front sweeps the map east or west with the zone's prevailing wind (westerlies in the mid rows, easterly trades near the equator) over hours to a day. That also gives Dave's "following the sun or the spin of the earth".
- **Cost.** It stays a pure function: one extra input (x) and nothing stored. It stays seamless because the field is continuous in x, and the wrap seam needs the speed to divide the world's width evenly.
- **Still open.** Blending at north-south zone borders (rows), and local mountain storms.
- **Recommendation (coordinator, 18:14 local, agreed).** The server owns the weather seed and clock. The server and every client compute the same weather field for the whole world from them, so no weather map is pushed over the network. The field drifts slowly over hours; it does not snap with the sun. Each latitude row reads it as temperature and as rain or snow, and borders are seamless.
- **Which way it drifts (agreed, 18:14 local).** The drift follows each zone's prevailing wind, which the wind code already has. That keeps the wind and the incoming weather in agreement.
  - Mid rows, including the starter island at 34° S: weather comes in on the westerlies, so it drifts west to east.
  - Rows near the equator: the trade winds carry it east to west.
