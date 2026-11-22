# WS acquisition: resource acquisition and world interactions

Scope: the 145 ids in `work/raw_inputs.json` and the 20 `gather:` goals in `work/goals_parsed.json`. Per-item ledger: `work/ws_acquisition.json`, with status, mechanism, tool, where, evidence and notes for each id.

Method: a static read of the data tables and the server and client code in the checked-out tree (branch `claude/project-thread-d8jals`, baseline dev dc2fa52). Godot was not run and no tests were run. Every claim here is CODE_VERIFIED at best. Where an existing test file is named, it is cited for reference only and was not run in this audit. Authority class of all evidence: IMPLEMENTED (actual code and data). Unless a row says otherwise, `SI` means `src/stream/server_items.gd` and `TS` means `scenes/terrain_server/terrain_server.gd`.

## Result counts
- SOURCED: 101.
- SOURCED_CONDITIONAL: 35. These depend on biome, season, geology, the sea, a specific tool, or a rare spawn.
- NO_SOURCE: 9: `tannin_bark`, `pine_tar`, `flax`, `wheat`, `barley`, `oats`, `rye`, `quill`, `obsidian`.
- `water` is SOURCED_CONDITIONAL only through a desert cactus. In any non-desert start it is effectively unavailable (A-03).
- Downstream impact: a recipe-graph fixpoint over the unlocked recipes in `recipes.json`, with ingredient groups expanded, run on the goal materials:
  - The 9 NO_SOURCE ids block **83 goals**. Of these, 9 are MAIN: `gather:tannin_bark`, `craft:leather`, `gather:pine_tar`, `craft:tar`, `craft:water_wheel`, `build:saw_mill`, `craft:bronze_sword`, `craft:iron_sword` and `craft:steel_sword`.
  - Treating `water` as unavailable too blocks **122 goals**, 16 of them MAIN. The extra MAIN goals are `craft:concrete`, `build:engineered_foundation`, `build:engineered_wall`, `build:fortified_foundation`, `build:fortified_wall`, `build:fortified_doorway` and `build:fortified_gate`.
  - The goal lists are produced by the impact script. That script was not saved to the work folder and can be added on request. Station reachability is not included (the stations workstream covers it).

## Primitive-survival facts (code)
- **E on plants.** The client sends `cut_flora`, which reaches `TS:1835-1882` and `SI:1563-1646`.
  - Trees are refused unless they are listed in `drops.json#fruit_tree` (`TS:1862-1865`, `src/client/harvest.gd:277-279`).
  - A species with a `harvest_yield` or `berry_yield` row gives only that product. Its other flora `yields` are shadowed. It gives the product once a season, by hand with no tool check, and the plant stays standing and bare (`SI:1761-1806`).
  - Any other plant or shrub gives its `drops.json#by_species` rows (shrubs fall back to `by_kind.shrub` = 1-3 sticks), plus one random usable flora yield of 1-3. A yield whose id ends in a `tool_rules` suffix needs that tool on the hotbar (`SI:1596-1640`).
  - The picked plant is removed from the world (`TS:1882`).
  - Holding E sweeps plants and loose items within 2 m (`src/client/harvest.gd:62-104`).
- **Plant fibre.**
  - Tall grass: 1-3 per plant, plus 2 thatch, 1-3 straw and one random natural yield. Spring to autumn.
  - Nettle: 1-2 per plant, plus 2-4 nettles. Spring and summer.
  - Other sources: reeds 2-3 (all seasons), wild flax 2-4 (summer), riverbraid 2-3, tanglewort 1-2.
  - All by E, no tool.
  - Thatching grass gives no fibre: its harvest row (thatch x10) shadows its `plant_fibre` yield.
  - In winter only reeds and tanglewort give fibre. Hob sells plant fibre (`data/npcs/shops.json#hob.stock`).
- **Sticks.**
  - Loose scatter sticks: up to 2 per 32 m cell, with more near spawn. Pick up with E. One E on a heap takes up to 10 (`data/items/pickup_batch.json`, `SI:4706`).
  - Dead branches drawn on the forest floor: E gives 1 (`src/client/harvest.gd:105-122`, `SI:3543-3557`).
  - Shrubs (E): 1-3. Fallen logs, hollow logs and old stumps (E): 3-6, 2-4 and 1-3 respectively.
  - Felled crowns scatter about 30 sticks. An axe on a bush gives 2-4. Chopping a stump also gives sticks.
  - Auto pickup is toggled with P and is off by default (`src/client/auto_pickup.gd:3`). Hob sells sticks.
- **Stones vs boulders.**
  - Loose stones: ground scatter on slopes and rock, bank stones by water (6% of them are flint), and cave stones. Pick up with E.
  - Boulders cannot be picked up. A pick or axe **held in hand and on the hotbar** breaks stones off a boulder (`SI:5568-5682`). Rates: stone pick 1 per blow, stone axe 0.5 per blow (and the axe wears 5 per blow).
  - A pick or axe on bare rock gives 1 stone per blow, limited per patch (`SI:3560-3606`).
  - Spade digs on stony soil or rock also give stone. Hob sells stones.
- **Logs.**
  - A felled tree auto-splits into whole 2.44 m logs on the ground (`SI:6640-6745`). Species with a retired log item give the plain `log`.
  - Species logs are shoulder items: carried one at a time, picked up with E (`SI:4637-4652`) and put down with Q.
  - A craft or blueprint that needs the `log`, `log_spruce` or `log_oak` group takes the shoulder log first, then logs lying within 3 m, then the pack (`SI:15836-15925`, `SI:17005`).
- **Large blocks.** An axe swung at a shoulder log lying on the ground gives 3 large blocks: hardwood for oak, beech, birch, maple, walnut and tropical hardwood; soft for spruce and Scots pine. A plain log gives 3 small soft blocks (default class softwood). A pick turns any log into kindling (`SI:9223-9278`). The chopping block splits blocks into firewood (`SI:9170-9204`).
- **Kindling and tinder.**
  - Both are made by known recipes: kindling from 1 stick gives 3, tinder from 2 thatch gives 2 (`recipes.json#recipes.kindling`, `#recipes.tinder`).
  - Kindling also comes from chopping stumps and short trunks, from pick blows on wood, and as the `fell` goal reward.
  - Fires accept plant fibre as tinder, and also tinder, birch bark, tinder fungus or kindling (`cooking.json#tinder`, `#tinder_also`).
- **Water.**
  - E at fresh water drinks (`SI:18363`).
  - With a container in hand, E fills it in millilitres, stored as slot wear (`SI:18396-18405`). It never creates the `water` item.
  - E at the sea with a bucket, clay jug or waterskin in the pack gives `sea_water` (`SI:13965-13977`).
- **Cooking.** `roast_*` items are not made by recipes. Raw meat, fish, shellfish or crab put in a lit campfire's store cook one at a time every 8 s (`SI:9834-9866`), or through the cook action (`SI:7647-7672`). `cooking.json#cookable_suffixes` is empty.

## Findings

**A-01 HIGH: `tannin_bark` has no source; `gather:tannin_bark` cannot be done.**
- `drops.json#harvest_yield.oak` (tannin bark x3) is dead data. An oak is a tree outside `fruit_tree`, so E is refused both on the client (`src/client/harvest.gd:277-279`) and on the server (`TS:1862-1865`).
- Mangrove's flora yield is also on a tree, so it cannot be picked either.
- No trunk, felling, carcass, shop or recipe row produces tannin bark. A felled oak gives acorns and plain `bark`.
- The route tests hand it out directly: `test_mission001_walkthrough.gd:606` says "no route test proves stripping bark", and `docs/ai-team/missions/M001/T19_RESULTS.md:35` lists it among gives with no gathering route test.
- The draft text "the flora table identifies mangrove" is a lead, not a mechanism.
- Blocks: `gather:tannin_bark`, `craft:leather`, `craft:heavy_leather`, and every leather and leather-strap goal: the bronze, iron and steel swords, axes and armour, `build:bellows`, the leather furniture and the spyglass (83 goals in total with the A-02 and A-04 items).
- This is a design-versus-code conflict that needs escalating, not an instruction fix. Do not invent a stripping method.

**A-02 HIGH: `pine_tar` has no source; `gather:pine_tar` is wrong.**
- A Scots pine is a tree, so E is refused.
- The trunk seed roll hands out only the first `trunk.by_species` row, and for `scots_pine` that row is `resin` (`SI:6527-6533`, `SI:6886-6900`). Pine tar never drops.
- Blocks: `craft:tar`, then `craft:water_wheel`, then `build:saw_mill` (all MAIN).
- The `pitch` group is not affected: resin or animal fat fills it.

**A-03 HIGH: the `water` ingredient is effectively unobtainable outside deserts.**
- The only code path that hands out `water` items is E on a cactus (hot_desert or dry_scrub, `flora.json#cactus`).
- Filling a container stores millilitres, not `water` items, and no craft code converts container millilitres into the ingredient.
- 26 unlocked recipes need `water`, including leather, concrete, the teas and soups, flatbread and fruit juice.
- The route tests give water by fiat (`test_textile_route.gd:209`, `test_mission001_walkthrough.gd:612/831`, "no route test proves drawing water").
- Affects 20 goals directly, and `craft:concrete` brings in the engineered and fortified building goals.

**A-04 HIGH: grain crops and `flax` cannot be obtained in play; `gather:flax` cannot be done.**
- `wheat`, `barley`, `oats`, `rye` and `flax` come only from crop yields (`crops.json`).
- The server implements sow and harvest (`SI:14635`, `SI:14757`), but the client only ever sends `ACT_TILL` (`src/client/held_item.gd:2064`). No client or scene code sends `ACT_SOW`, `ACT_HARVEST` or `ACT_WATER_BED`.
- Wild flax (E) gives plant fibre, linseed and flax seeds, never the `flax` item.
- Blocks: `gather:flax`, `craft:linen` and all linen clothing, `craft:tool_roll`, `craft:tabard`, `craft:flour` (and so the bread chains), and the oat and barley dishes.
- `test_farming.gd` calls the server functions directly, so it does not prove a client route.

**A-05 MED: `quill` and `obsidian` have no source.**
- `quill`: only porcupine and hedgehog carcasses give quills, and neither species has an `animals.json` row, so neither spawns.
- `obsidian`: no boulder, dig, drop, shop or carcass table gives it.
- No goal's materials use either id today. `obsidian_knife` is unobtainable.

**A-06 MED: `gather:iron_ore` is incomplete.**
- A rock outcrop needs a **bronze, iron or steel pick** (`boulders.json#ore.needs_material.iron`, `SI:5616-5622`). A stone pick is told "This pick is too soft for that ore".
- The early route is bog iron: any spade, including the wooden spade from 2 sticks, dug on a bog-iron deposit in fen, bog, marsh or swamp. It gives 1-2 per dig, from a deposit of 6-12 that regrows 1 every 3 game days (`digging.json#bog_iron`, `SI:3405-3445`).
- The instruction should name both routes and both tools.

**A-07 MED: `gather:flint` says "under source verification", but it is sourced.**
- Bank stones by water are 6% flint and are picked up with E (`drops.json#ground_scatter.bank.flint`, `SI:5770-5772`).
- Any stone broken off a boulder with a pick or axe is flint 4% of the time, or 8% within 6 m of water (`boulders.json#flint`, `SI:5650-5662`).
- Cave stones also roll flint. The existing test is `test_flint.gd` (not run).

**A-08 MED: `gather:limestone` placeholder; the source is confirmed but depends on geology.**
- A pick (any material) on a boulder over limestone, chalk or marble bedrock works only where the boulder is not already an ore outcrop.
- Half of those boulders are limestone boulders, and each piece is limestone with chance 0.4 (`boulders.json#ore.rocks`, `SI:5529-5552`).
- An axe never yields limestone, because only a pick takes rock pieces (`SI:5616`).

**A-09 MED: `gather:copper_ore` and `gather:tin_ore` are correct but should add details.**
- A **pick held in hand** is needed, and a stone pickaxe is enough. An axe on an outcrop gives only stone.
- Outcrops are 40% of the boulders within 40 m of an ore body, and pieces are ore 30% of the time.
- Outcrops have a distinct look (`src/client/inventory_view.gd:124-139`).

**A-10 MED: `gather:wool` is conditional.**
- In play only bighorn give wool (alpine meadow, bare rock, tundra, heath). The wild sheep in `carcass.json` never spawns.
- The draft says "source audit pending". Replace that with: hunt a bighorn, then dress the carcass with a knife.
- `craft:wool_cloth` depends on it.

**A-11 MED: tide-line gathering is blocked while a water container is in the pack.**
- `gather_edge` checks for a bucket, clay jug or waterskin first and fills sea water instead (`SI:13969-13977`). The prompt follows the same rule (`shore_rules.gd:65-66`).
- So shellfish, crab, seaweed and shore eggs need an empty-handed visit.
- Crabs appear only from 18:00 to 06:00. Eggs on the shore appear in spring and summer only.
- Affects `craft:mussel_stew`, `craft:seaweed_soup`, `craft:uncooked_crab_cakes` and the egg dishes.

**A-12 MED: inland bird nests cannot be robbed from the client.**
- The server's `take_nest` (`SI:14042-14073`) is reached only through `ACT_GATHER_EDGE`. The client sends that only from the shore prompt, which requires the sea nearby (`shore_rules.gd:62-63`, `terrain_client.gd:1489-1493,2016-2017`).
- `nest_view.nearest()` is never called.
- Eggs still come from the shore "nest" node and from seabird carcasses. The grouse nest's extra feather is unreachable.
- Goals using `egg` (`craft:boiled_egg`, `craft:egg_nettle_fry`, `craft:herb_omelette`) depend on the coast.

**A-13 MED: `honeyspindle_nectar` is a narrow source used by 12 goals.**
- Source: E on the fantasy shrub honeyspindle in summer only, with a knife on the hotbar. The knife is required because the id ends in "tar", a knife suffix in `drops.json#tool_rules`, so the requirement is accidental. Each pick picks at random between nectar and pods.
- Goals: `craft:energy_bar`, `craft:unbaked_chestnut_cakes`, `craft:unbaked_honey_loaf`, `craft:apple_sauce`, `craft:baked_apples`, `craft:berry_compote`, `craft:fruit_leather`, `craft:nut_paste`, `craft:plum_jam`, `craft:preserved_damsons`, `craft:quince_paste`, `craft:stewed_pears`.
- `T19_RESULTS.md:35` lists it as having no gathering route test.

**A-14 LOW: `gather:log` is mostly correct but incomplete.**
- Any axe works, not only a stone axe, and a pick fells very slowly. The axe must be held in hand on the hotbar.
- The trunk splits into logs on the ground by itself. Logs are picked up one at a time onto the shoulder (E) and put down with Q.
- Crafts take logs within 3 m. The instruction should mention the shoulder carry.

**A-15 LOW: the `gather:log_oak` and `gather:log_spruce` wording and the group semantics.**
- The `log_oak` group (Hardwood log) also accepts beech, birch, tropical hardwood, walnut and maple logs.
- The `log_spruce` group (Softwood log) also accepts Scots pine and the plain Log. Balsam fir is a softwood but gives the plain Log.
- If the runtime goal counts only the exact `log_oak` item, only oak qualifies. Oak is rarer than beech (10 per ha against 72 per ha in temperate forest). The runtime workstream should confirm the goal check.

**A-16 LOW: `gather:stone` is correct; add the tool rule.**
- Breaking a boulder needs a pick or axe in hand. A stone axe gives half rate and wears 5 per blow.
- A pick or axe on bare rock also gives stone.

**A-17 LOW: `gather:stick` is correct; it could mention more sources.**
- Holding E takes up to 10 sticks from nearby heaps, and dead branches on the forest floor can be picked with E.
- Shrubs also give 1-3 sticks.

**A-18 LOW: `gather:thatch` is correct.**
- Thatching grass gives 10 (all seasons, harvest row), reeds 8 (all seasons), heather 4 (summer and autumn) and tall grass 2 (spring to autumn), each plus a random natural yield.
- Felling birch and conifers also drops thatch-bark.

**A-19 LOW: `gather:clay` and `gather:sand` are correct.**
- Any spade works: the wooden spade (2 sticks) or Hob's.
- Clay also comes up with chance 0.35 under loam and forest humus, and 0.5 under silt and alluvium (`digging.json#under`).

**A-20 LOW: `gather:hide`, `gather:bone` and `gather:animal_fat` are correct.**
- Kill the animal with a spear jab or throw, a bow, or a snare (snares catch rabbit or fox). Then swing a knife **in hand** at the carcass (`SI:2288-2341`).
- Carcasses rot after 2 game days and are not saved.
- Animal fat comes from medium and large mammals (deer, boar, moose, beaver, bear, seal, elk and others), not from rabbits.

**A-21 LOW: the `fibre` goal (existing) is correct but seasonal.**
- Tall grass gives 1-3 and nettles 1-2 per plant. Each picked plant disappears.
- In winter neither is in season. Reeds or Hob are the winter fallback.

**A-22 LOW: the `drink` goal is correct.**
- E within 3 m of fresh water drinks.
- Sea water is refused ("Salt water..."). Frozen water needs an ice hole.
- With a container in hand, E fills it instead of drinking (`SI:18396-18405`).

**A-23 LOW: other conditional sources (for the ledger notes).**
- Biome-locked:
  - Dry scrub, savanna and hot desert: figs, rosemary, sage, marjoram, prickly pears, potash.
  - Tropical forest: bananas, tropical hardwood log.
  - Desert: water (cactus).
- Season-locked: every berry and fruit, every mushroom, the wild vegetables, and nettles.
- Fish:
  - Rod, spear and trap catches come from the cell type: trout, perch, carp, pike.
  - Salmon (autumn), eel (summer and autumn), herring, mackerel, smelt and cod come only from schools, by rod or net. Spears and traps never use schools (`SI:13619`, `SI:13794`).
- Ores: copper, tin, coal and limestone depend on geology.
- Animals:
  - Wool: bighorn only.
  - Down: duck or goose only.
  - Horn: mountain and savanna species.
  - Seal meat: seals on beaches.

**A-24 LOW: `fish` (existing) and hook.**
- A fishing rod needs 2 sticks, 2 twine **and 1 hook** (the hook is made from bone).
- The runtime hint in `starter_goals.json#fish` omits the hook.
- A fishing spear (1 stick, knife kept) or a stone spear catches stream and pond fish without a rod.

## Draft section 3 claim: 43 "unconfirmed" raw sources (`PLAYER_GOALS_REWARDS_DRAFT.md:763`)
Confirmed **unobtainable** (6):
- `oats`, `barley`, `wheat`, `rye`, `flax`: A-04.
- `quill`: A-05.

Refuted, these are **sourced** (each row in the JSON has evidence):
- Carcass, with a weapon and a knife: `raw_meat`, `feather`, `sinew`, `fur`, `gut`, `antler`, `tusk`.
- Digging: `soil`, `worm`.
- Ingredient groups, sourced through their members: `herbs`, `fish`, `pitch`, `fruit`, `nuts`, `mushrooms`, `berries`.
- Fishing: `perch`, `trout`.
- Boulders and bank stones: `flint`.
- Other: `rotten_food` (spoilage), `seed_bundle` (trunk seed roll), `wooden_block_soft_large` (axe on a softwood shoulder log), `roast_meat` and `roast_fish` (campfire).

Refuted, these are **conditional** sources:
- Shore: `egg` (shore node or seabird; inland nests unreachable), `shellfish`, `crab_meat`, `seaweed`, `sea_water`.
- Animals: `seal_meat`, `horn`, `down`, `wool`.
- Digging: `gravel`, `crystal_lens`.
- Fish schools: `herring`.
- Cooking: `roast_shellfish`.

Not in the 43, but found to have **no source**: `tannin_bark`, `pine_tar`, `obsidian`. `water` is desert-only.
