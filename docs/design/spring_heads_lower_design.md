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
| Under the rule | 152 of 187 |

**Walk.** A spring head outside the belt moves down its own reach, at most 800 m, to the first belt cell. It stops at a confluence or a lake, because it does not walk onto another stream.

**Stream above the new head.** The cells above the new head stop being stream (`vis` off). They become dry gullies. Their water still runs down in the flows, so the flow downstream is unchanged. The new head carries the old head's groundwater and dry-season flow, and records where it came from in `lowered_from`.

**No belt cell within 800 m.** The head is a seep, not a spring. Its runnel stays as it is, with no spring cover and no drink point. That is honest for cliff country.

**Not affected.** Lake outlets and seeps are left alone.

**Tile 3,4 (slope rule, measured on the 687b72b8 tile with the walk approximated downhill):**

| Outcome | Heads | Detail |
|---|---|---|
| Stay | 80 | |
| Move | 100 | median 243 m |
| Become seeps | 7 | |
| Beach-sand heads | 9 | flat already |

The network run on Dino gives the real counts. They are printed in the summary as `spring_heads_lowered` and `cliff_seeps`.

**Record changes.** These follow by themselves:
- the heads and reaches;
- `below_spring_m` and `spring_y`;
- the drink sections;
- the tile's water class, and with it the settled water. The settler puts its springs at the reach heads.

**Versions.** TERRAIN 75, FloraLayout 29.

## 2. Plants grow thicker by water (Dave, 17:42 local), PR 2

Dave, 17:42 local: "they grow 100% thicker, and grass grows taller right at the water and its growth deminishes as it gets further from the water until it gets to normal growth at 6 meters away."

At 17:44 to 17:45 local he gave the purpose: "if someone carves a trench to water their crops the crops will grow better out from around the trench. and multiple ditches could irrigate a nice farm".

**One growth rule in the plant code.** Every species and the grass read the same value: the distance d from the plant to the nearest water edge. The wetness is

W = clamp(1 − d / 6 m, 0, 1).

| At W = 1, the water's edge | Effect |
|---|---|
| Plants and shrubs | density × 2 (one extra candidate with chance W next to each normal one, so the boost fades with W) |
| Grass | thickness × 2 and taller (Kathleen, client grass) |
| Plant size | up to 25% further up the species' height range |
| Moisture filter | wet-ground species qualify by the bank |

At 6 m from the water, everything is normal growth. The same 6 m fade applies to every water: spring heads, brooks, rivers and lakes. It replaces the 12/20/30/60 m reaches of the first draft.

**Live water, not a baked section.** The distance is measured at runtime from the live water: the tile's water level plus the dug-region water (Sullivan water). That covers:
- natural rivers, lakes, brooks, seasonal brooks and springs;
- a player's trench, ditch or pond, as soon as water stands in it.

So several ditches irrigate a farm. Nothing is baked: an 8 m tile sample is wider than the whole 6 m fade, so a baked field could not hold it anyway. The 4 m bank and bed margins stay as they are.

**Kept cheap.**
- The placer works out W only for candidates near water. A candidate more than 6 m from any water sample is skipped with the existing coarse check.
- W is worked out when a flora chunk is built.
- Chunks are already rebuilt when the water changes near them (`water_changed_in`), so a new trench greens up on that rebuild. Nothing runs per frame.
- Kathleen's grass computes its own 1 m distance per grass cell when a cell is built.

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
- network.py, params.json and test_network.py, with TERRAIN 75 and FloraLayout 29.
- Bake class. David4 runs the Python tests, then Dino reruns network, record, the 9 tiles (9 threads) and settle, with the tiles on the branch.
- About 10 min, estimated from today's stages: network 57 s, record 53 s, bake 132 s, settle about 6 min. Not timed yet.

**PR 2: growth rule and animals.**
- The placer's growth rule, Kathleen's client grass, and the animal spring hook (section 3).
- Code class, with no rebake. It takes one FloraLayout bump.

**Tests.**
- PR 1: the head walk-down, the seep fallback, a head in the belt staying, a lake outlet staying, and the belt slope.
- PR 2: W at 0, 3 and 6 m; a doubled density at the edge; a trench counting as water; `drink_spot` picking a spring.
