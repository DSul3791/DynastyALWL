# Drop table audit (Items and crafting job 21, 2026-10-20)

For Dave. Every flora species with how it gives items today and the tool rule I propose. UPDATE 2026-10-20: Dave said yes, so the rule below is now in the game (drops.json tool_rules). Roots and bulbs need a spade (new wooden spade: 2 sticks, the stone is kept), bark, gum, sap, resin and oil need a stone knife, wood needs the axe; berries, leaves, flowers and herbs stay by hand. Felled trunks now also give a root ball with the last log and a species' own nut or fruit instead of generic seeds.

## What happens today

- **Plants and shrubs (E or the axe swing):** the plant gives its fixed drop from drops.json (fibre for flax, grasses and nettle; sticks for any shrub) plus ONE random natural yield from its list when in season, 1 to 3 of it. The plant stays and is bare for 3 game days.
- **Trees:** cannot be picked. Chop with the stone axe, the tree falls, work the trunk (branches and leaves, then logs, bark and seeds).
- **Rock:** the axe on rock ground gives stone (6 per 8 m patch, regrows 1 per 5 minutes). Loose stones and sticks also lie on the ground. No ore or clay drops exist yet (rock table has 11 rock types, resource table 31 resources).
- **Tool gating is on** (see update above). A plant whose only yields need a tool you lack gives nothing and tells you which tool.

## Gaps to settle

- 102 plant and shrub species are gatherable. Of their yields, 13 are roots or bulbs (proposed: need a spade, hand digging until a spade exists), 2 are bark, gum, sap or oil (proposed: stone knife), 5 are wood or withies (proposed: stone axe).
- Herb, berry and food items have no effects yet; only plantain, comfrey, yarrow and staunchmoss feed a recipe (poultice, bandage).
- Rock outcrops: stone only. Proposed: limestone, granite, basalt, sandstone, slate, marble, chalk, tuff all give plain stone for now; flint (resource table) should give flint shards for a better knife; clay from clay pits needs a spade; ore (iron, copper, tin...) needs a pick, which is the stone axe, but a stone axe cannot break ore, so metal tools need a first stone-hammer step. Needs a design call.
- Questions: should the spade be the next hand tool (roots, clay, digging)? Should shrubs give wood by hand? (I recommend no: sticks only, wood needs the axe.)

## Table (plants and shrubs)

| Species | Kind | Rarity | Season | Today | Proposed rule per yield |
|---|---|---|---|---|---|
| Hazel | shrub | common | autumn | hand: one random yield | poles -> hand; hazelnuts -> hand |
| Bramble | shrub | common | summer, autumn | hand: one random yield | blackberries -> hand; thorny_canes -> hand |
| Juniper | shrub | uncommon | autumn, winter | hand: one random yield | juniper_berries -> hand; wood -> axe |
| Gorse | shrub | common | all | hand: one random yield | kindling -> hand; fodder -> hand |
| Dwarf birch | shrub | common | all | hand: one random yield | kindling -> hand |
| Saltbush | shrub | common | all | hand: one random yield | fodder -> hand; potash -> hand |
| Cactus | shrub | uncommon | all | hand: one random yield | water -> hand; spines -> hand |
| Fern | plant | common | spring, summer, autumn | hand: one random yield | bedding -> hand; fiddleheads -> hand |
| Heather | plant | common | summer, autumn | hand: one random yield | thatch -> hand; bedding -> hand; honey_flowers -> hand |
| Reeds | plant | common | all | hand: plant_fibre + one random yield | thatch -> hand; reed_stems -> hand |
| Wild flax | plant | uncommon | summer | hand: plant_fibre + one random yield | fibre -> hand; linseed -> hand |
| Tall grass | plant | common | spring, summer, autumn | hand: plant_fibre + one random yield | thatch -> hand; straw -> hand; fibre -> hand |
| Nettle | plant | common | spring, summer | hand: plant_fibre + one random yield | fibre -> hand; greens -> hand |
| Cotton grass | plant | common | summer | hand: one random yield | tinder -> hand; stuffing -> hand |
| Alpine flowers | plant | uncommon | summer | hand: one random yield | herbs -> hand; dye -> hand |
| Mushrooms | plant | common | summer, autumn | hand: one random yield | food -> hand; tinder_fungus -> hand |
| Blueberry | plant | common | summer | hand: one random yield | blueberries -> hand; leaves -> hand |
| Lingonberry | plant | common | autumn | hand: one random yield | lingonberries -> hand; leaves -> hand |
| Cranberry | plant | common | autumn | hand: one random yield | cranberries -> hand |
| Cloudberry | plant | rare | summer | hand: one random yield | cloudberries -> hand |
| Wild strawberry | plant | common | summer | hand: one random yield | strawberries -> hand; leaves -> hand |
| Raspberry | shrub | common | summer | hand: one random yield | raspberries -> hand; raspberry_leaves -> hand |
| Crowberry | plant | common | autumn | hand: one random yield | crowberries -> hand |
| Elder | shrub | uncommon | spring, summer, autumn | hand: one random yield | elderberries -> hand; elderflowers -> hand; wood -> axe |
| Wild rose | shrub | common | summer, autumn | hand: one random yield | rose_hips -> hand; rose_petals -> hand |
| Blackthorn | shrub | common | autumn | hand: one random yield | sloes -> hand; thorny_wood -> axe |
| Hawthorn | shrub | common | spring, autumn | hand: one random yield | haws -> hand; hawthorn_blossom -> hand; hard_wood -> axe |
| Sea buckthorn | shrub | uncommon | autumn | hand: one random yield | sea_buckthorn_berries -> hand; oil -> knife |
| Wild garlic | plant | common | spring | hand: one random yield | wild_garlic_leaves -> hand; wild_garlic_bulbs -> spade |
| Wild thyme | plant | common | spring, summer, autumn | hand: one random yield | thyme -> hand |
| Water mint | plant | common | spring, summer | hand: one random yield | mint -> hand |
| Sorrel | plant | common | spring, summer | hand: one random yield | sorrel_leaves -> hand |
| Dandelion | plant | common | spring, summer, autumn | hand: one random yield | dandelion_leaves -> hand; dandelion_roots -> spade; dandelion_flowers -> hand |
| Wild carrot | plant | common | summer, autumn | hand: one random yield | wild_carrot_roots -> spade; seeds -> hand |
| Watercress | plant | uncommon | spring, summer, autumn | hand: one random yield | watercress -> hand |
| Samphire | plant | common | summer | hand: one random yield | samphire -> hand |
| Wild marjoram | plant | uncommon | summer | hand: one random yield | marjoram -> hand |
| Wild sage | plant | common | spring, summer, autumn | hand: one random yield | sage -> hand |
| Rosemary | shrub | common | all | hand: one random yield | rosemary -> hand |
| Lavender | plant | uncommon | summer | hand: one random yield | lavender_flowers -> hand |
| Yarrow | plant | common | summer | hand: yarrow + one random yield | yarrow -> hand |
| Ribwort plantain | plant | common | spring, summer, autumn | hand: plantain_leaves + one random yield | plantain_leaves -> hand; seeds -> hand |
| Chamomile | plant | common | summer | hand: one random yield | chamomile_flowers -> hand |
| Comfrey | plant | common | spring, summer, autumn | hand: comfrey_leaves + one random yield | comfrey_leaves -> hand; comfrey_roots -> spade |
| St John's wort | plant | uncommon | summer | hand: one random yield | st_johns_wort -> hand |
| Valerian | plant | uncommon | autumn | hand: one random yield | valerian_roots -> spade |
| Meadowsweet | plant | common | summer | hand: one random yield | meadowsweet_flowers -> hand |
| Feverfew | plant | uncommon | summer | hand: one random yield | feverfew -> hand |
| Burdock | plant | common | autumn | hand: one random yield | burdock_roots -> spade; burrs -> hand |
| Mugwort | plant | common | summer | hand: one random yield | mugwort -> hand |
| Arnica | plant | rare | summer | hand: one random yield | arnica_flowers -> hand |
| Angelica | plant | uncommon | summer | hand: one random yield | angelica_roots -> spade; angelica_stems -> hand |
| Aloe | plant | uncommon | all | hand: one random yield | aloe_gel -> hand |
| Foxglove | plant | uncommon | summer | hand: one random yield | foxglove_leaves -> hand |
| Deadly nightshade | plant | rare | summer, autumn | hand: one random yield | belladonna_berries -> hand; belladonna_leaves -> hand |
| Wolfsbane | plant | rare | summer | hand: one random yield | wolfsbane_roots -> spade |
| Henbane | plant | rare | summer | hand: one random yield | henbane_seeds -> hand; henbane_leaves -> hand |
| Chanterelle | plant | uncommon | summer, autumn | hand: one random yield | chanterelles -> hand |
| Porcini | plant | uncommon | autumn | hand: one random yield | porcini -> hand |
| Morel | plant | rare | spring | hand: one random yield | morels -> hand |
| Fly agaric | plant | uncommon | autumn | hand: one random yield | fly_agaric_caps -> hand |
| Giant puffball | plant | rare | summer, autumn | hand: one random yield | puffball -> hand |
| Tinder fungus | plant | common | all | hand: one random yield | amadou -> hand |
| Wild banana | shrub | common | all | hand: one random yield | bananas -> hand; banana_leaves -> hand |
| Prickly pear | shrub | common | summer, autumn | hand: one random yield | prickly_pears -> hand; cactus_pads -> hand |
| Owlpetal | plant | rare | summer | hand: one random yield | owlpetals -> hand |
| Staunchmoss | plant | uncommon | all | hand: staunchmoss + one random yield | staunchmoss -> hand |
| Emberroot | plant | uncommon | autumn, winter | hand: one random yield | emberroots -> spade |
| Rimecap | plant | uncommon | autumn, winter | hand: one random yield | rimecap_caps -> hand |
| Wispbloom | plant | rare | summer, autumn | hand: one random yield | wispbloom_heads -> hand |
| Drakethorn | shrub | uncommon | autumn | hand: one random yield | drakethorn_berries -> hand |
| Sunberry | shrub | uncommon | summer | hand: one random yield | sunberries -> hand |
| Hushfern | plant | uncommon | summer, autumn | hand: one random yield | hushfern_fronds -> hand |
| Lumencap | plant | uncommon | autumn | hand: one random yield | lumencap_caps -> hand |
| Hag willow | shrub | rare | all | hand: one random yield | hagwillow_bark -> knife; hagwillow_withies -> axe |
| Heartroot | plant | rare | spring, autumn | hand: one random yield | heartroots -> spade |
| Tideglass weed | plant | uncommon | summer | hand: one random yield | tideglass_fronds -> hand |
| Gloomthistle | plant | uncommon | autumn | hand: one random yield | gloomthistle_heads -> hand; gloomthistle_down -> hand |
| Dewlantern | plant | common | spring, summer | hand: one random yield | lantern_dew -> hand |
| Honeyspindle | shrub | common | summer | hand: one random yield | honeyspindle_nectar -> hand; honeyspindle_pods -> hand |
| Marrowroot | plant | common | autumn | hand: one random yield | marrowroots -> spade |
| Riverbraid | plant | common | summer, autumn | hand: plant_fibre + one random yield | riverbraid_stems -> hand |
| Brinebell | plant | common | summer | hand: one random yield | brinebells -> hand |
| Sleetberry | shrub | common | winter | hand: one random yield | sleetberries -> hand |
| Quenchbell | plant | uncommon | summer | hand: one random yield | quenchbell_heads -> hand |
| Whisperfern | plant | uncommon | summer, autumn | hand: one random yield | whisperfern_fronds -> hand |
| Cinderfoot | plant | uncommon | all | hand: one random yield | cinderfoot_caps -> hand |
| Duskmallow | plant | uncommon | summer, autumn | hand: one random yield | duskmallow_flowers -> hand; duskmallow_roots -> spade |
| Tanglewort | plant | uncommon | all | hand: plant_fibre + one random yield | tanglewort_vines -> hand |
| Stormreed | plant | uncommon | summer, autumn | hand: one random yield | stormreed_stalks -> hand |
| Truthsage | plant | rare | summer | hand: one random yield | truthsage_leaves -> hand |
| Mirrorcap | plant | rare | autumn | hand: one random yield | mirrorcap_caps -> hand |
| Echo moss | plant | rare | all | hand: one random yield | echo_moss -> hand |
| Nightcrown | plant | rare | summer | hand: one random yield | nightcrown_blooms -> hand |
| Mournbloom | plant | rare | autumn | hand: one random yield | mournbloom_petals -> hand |
| Pilgrim's cup | plant | rare | summer | hand: one random yield | pilgrims_cup_water -> hand; pilgrims_cup_pitchers -> hand |
| Sunsilver vine | shrub | very_rare | summer | hand: one random yield | sunsilver_leaves -> hand |
| Frostglass orchid | plant | very_rare | winter | hand: one random yield | frostglass_petals -> hand |
| Sevenyear lily | plant | very_rare | summer | hand: one random yield | sevenyear_bulbs -> spade; sevenyear_blossoms -> hand |
| Stillwater lotus | plant | very_rare | summer | hand: one random yield | stillwater_seeds -> hand; stillwater_petals -> hand |
| Gloaming star | plant | legendary | all | hand: one random yield | gloaming_star -> hand |
| Tidecrown | plant | legendary | summer | hand: one random yield | tidecrown_pearls -> hand |

## Table (trees)

| Species | Rarity | Today | Yields once felled |
|---|---|---|---|
| Oak | common | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | hardwood needs axe; acorns needs hand; bark needs knife |
| Beech | common | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | hardwood needs axe; beechnuts needs hand |
| Birch | common | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | wood needs axe; birch_bark needs knife; sap needs knife |
| Scots pine | common | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | softwood needs axe; resin needs knife; pine_tar needs hand |
| Spruce | common | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | softwood needs axe; resin needs knife |
| Alder | common | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | wood needs axe; charcoal_wood needs axe |
| Willow | common | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | wood needs axe; withies needs axe; willow_bark needs knife |
| Coconut palm | uncommon | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | palm_wood needs axe; coconuts needs hand; palm_fronds needs hand |
| Tropical hardwood | common | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | hardwood needs axe; resin needs knife |
| Acacia | uncommon | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | hardwood needs axe; gum needs knife |
| Mangrove | common | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | wood needs axe; tannin_bark needs knife |
| Rowan | uncommon | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | rowan_berries needs hand; wood needs axe |
| Crab apple | uncommon | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | crab_apples needs hand; wood needs axe |
| Wild pear | rare | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | wild_pears needs hand; wood needs axe |
| Wild cherry | uncommon | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | cherries needs hand; cherry_wood needs axe; gum needs knife |
| Sweet chestnut | uncommon | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | chestnuts needs hand; timber needs hand |
| Walnut | rare | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | walnuts needs hand; walnut_husks needs hand; fine_wood needs axe |
| Date palm | rare | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | dates needs hand; palm_fronds needs hand; palm_wood needs axe |
| Mirrorbark | rare | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | mirrorbark_bark needs knife; mirrorbark_wood needs axe |
| Wardpine | rare | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | wardpine_resin needs hand; wardpine_wood needs axe |
| Hearthwood | rare | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | hearthwood_logs needs hand |
| Everember | legendary | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | everember_needles needs hand; everember_wood needs axe; everember_sap needs hand |
| Witness tree | uncommon | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | witness_leaves needs hand; witness_bark needs knife |
| Balsam fir | common | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | softwood needs axe; resin needs knife; bedding needs hand |
| Sugar maple | common | felled with axe, trunk worked: sticks, leaves, logs, bark (30%), seeds (15%) | wood needs axe; sap needs knife |
