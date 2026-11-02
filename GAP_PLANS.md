# Three biggest gaps: iron, leather, crops (Sal, 2026-10-31)

Each plan: the data already in the branch, the data still to add, the code the coder must write, and how to prove it works. Gap list comes from BUILD_ORDERS.md.

## 1. Iron (blocks 8+ recipes: nails, hinges, saw blade, rivets, scythe, iron tools, then lumber by saw, water wheel)
**Data in place:** items Iron ore 303, Copper ore 301, Tin ore 302, Coal 304, Pyrite 280; smelting recipes at a forge (iron, copper, tin level 1; steel and bronze level 2); Iron/Steel ingot, Rivets, Nails, Hinges, Saw blade; Stone wedge gives lumber without iron (so iron is no longer a wall for wood).
**Data still to add:** `data/items/ore_nodes.json` (the node table: outcrop kinds, rarity per biome, pick tier needed, yield per blow). Proposed: copper and coal on bare rock and alpine slopes with a stone pick, tin rarer in the same places, iron deeper (bare_rock slope above 0.6) needing a copper-or-better pick. Written as spec in FLINT_ORE_SPEC.md.
**Code:** ore outcrop spawning (derive from terrain hash, like boulders), pick-tier check, drops. Forge buildability: the Stone forge gives forge 1; Large and Master forge (forge 3 and 4) are not buildable: blueprint costs need nails/hinges (circular) so give the Large forge a bronze-and-brick cost first.
**Proof:** gather ore, smelt, make Nails, craft a Hand saw; BUILD_ORDERS.md gap table shrinks from 8 to 0 iron rows.

## 2. Leather (blocks scraper-less hide, leather clothes, armour, quiver, saddle)
**Data in place (this round):** recipes Leather (processed hide + 2 tannin bark + water, at a campfire pot, 30 s), Heavy leather (2 leather + 2 tannin bark, 40 s), Fine leather (leather + animal fat, 30 s); Tannin bark now comes from oak (harvest row, knife needed); Processed hide (hide at hand, keeps the hide scraper); hide scraper needs flint.
**Gaps left (chain):** hide -> **processed hide needs the hide scraper -> scraper needs flint** (no flint source); leather needs `water` (no way to fill a container: WATER_GATHER_SPEC.md); tanning rack and tannery (Dave's ladder: tannery with tubs and racks) are not built, the pot is the stand-in.
**Code:** flint source (FLINT_ORE_SPEC.md step 1) and the water-gather action. Optional later: a Tanning rack structure that halves craft time and gives a quality grade (ITEM_CODE_HANDOFF.md section 5).
**Proof:** hunt a rabbit, get hide, scrape (flint), tan (bark + water at the pot), make Leather cap: BUILD_ORDERS.md leather rows turn "yes".

## 3. Crops (chain seed -> plot -> water -> harvest)
**Data in place:** Wheat, Barley, Carrot, Potato, Turnip, Flax (332 to 337) and their seeds (338 to 343), Quern, Flour recipes, Compost; hoes (wooden, stone, iron, steel); `data/items/crops.json` (new this round, read by nothing: grow days, sow season, water, yields, seeds back, biomes); Straw from tall grass.
**Broken links, in order:**
1. Seeds have no source. Wild grain should give seeds when harvested from grassland patches, or seeds come from the Seed bundle by sorting; data to add once the action exists.
2. No "sow" action: the hoe only paths and digs the ground (server_items.gd `_hoe_ready`). Needs a Tilled bed: hoe on the ground makes a bed cell; a seed item used on a bed plants it.
3. No growth state: a planted crop is a world item with a plant time; ripeness = game days since sowing (crops.json `grow_days`) and rain/water. No plant stage models yet (Kathleen).
4. No watering: a Bucket or Clay jug filled by the water-gather action (WATER_GATHER_SPEC.md) waters a bed; rain counts as watering.
5. Harvest: E on a ripe crop gives `yields`, sickle speeds grain (tool_to_harvest), and returns seeds (`seeds_back`); the bed is empty again.
6. Straw and bedding, flour and bread already exist, so the food chain after harvest works in data (Flour -> Flatbread, Trail bread, Honey loaf).
**Code:** tilled bed structure and sow action, growth timer saved with world items, water, harvest. Tests: test_server_items (sow, grow a game day, ripe, harvest, seeds back), save_compat (bed and crop saved).
