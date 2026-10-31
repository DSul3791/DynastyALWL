# Medicine, poisons and cures (Sal, 2026-10-31)

## What the game has today
- **Items:** plantain leaves, comfrey leaves, staunchmoss, yarrow, willow bark, chamomile flowers, valerian roots, arnica flowers, meadowsweet flowers, mugwort, St John's wort, feverfew, lavender flowers, aloe gel (all gathered items; most are plants in flora.json). Poisonous: belladonna (berries, leaves), henbane, wolfsbane roots, foxglove leaves, fly agaric caps, hushfern. Look-alikes are already listed in gathered.json so inspection can trick a careless player.
- **Recipes (category Medicine, 6):** plantain poultice, comfrey poultice, leaf bandage (plantain + fibre), mossy bandage (staunchmoss + fibre), herb salve (comfrey 2 + animal fat), splint (2 sticks + twine). Teas: stomach tea, chamomile tea, willow bark tea (vitals.json medicines: cure sickness in 10, 6, 5 game hours; "medicine" 18).
- **Systems:** sickness from rotten or raw food (sickness.json, lasts about 24 game hours); health and bleeding exist (blood drops, bleed rate). Poison from plants gives no food value ("plants whose flora uses include poison give nothing", vitals.json) but no poisoning status exists yet.

## Proposed chain (data design; code marked)
| Ailment | Cause | Early cure (no tools) | Better cure | Notes |
|---|---|---|---|---|
| Bleeding | animal bite, spear | Mossy bandage (staunchmoss + fibre), Leaf bandage | Yarrow bandage (yarrow + fibre) | yarrow was called staunchweed in folk use (general knowledge) |
| Bruises and sprains | falls, hits | Comfrey poultice | Herb salve (comfrey + fat), arnica salve (arnica flowers + fat; external only) | arnica is toxic if eaten |
| Broken limb (limp) | wolf maul, fall | Splint (sticks + twine) | splint + salve | limp rules exist (vitals.json) |
| Food sickness | raw or rotten food | Stomach tea, chamomile tea | Medicine (the 18 h cure) | chamomile for upset stomach is folk use |
| Fever, headache | cold, illness | Willow bark tea (salicin, the source of aspirin) | feverfew tea | willow bark is now a trunk drop |
| Poor sleep | stress | Valerian root tea | lavender pillow | valerian is a folk sleep aid |
| Burn | fire | Aloe gel (hot biomes) | Herb salve | aloe in desert and scrub |
| Poisoning (NEW) | eating belladonna, henbane, wolfsbane, fly agaric, foxglove | Charcoal (burnt wood, eaten) and water; rest | Medicine | **needs code**: a poison status like sickness with its own damage and cure list |

Real references are general herbal folk knowledge (plantain for stings, comfrey as knitbone, yarrow for wounds, willow bark as the aspirin source, chamomile and valerian as calming herbs, foxglove containing digitalis, belladonna atropine, henbane and wolfsbane toxic). None is individually sourced in this pass, and the game should not present them as medical advice.

## Data to add next (not done this round)
1. Recipes: Yarrow bandage, Arnica salve, Feverfew tea, Valerian tea, Charcoal (campfire: 2 firewood) and Antidote (charcoal + water), all at most 3 ingredients; items for the teas and charcoal.
2. `vitals.json` medicines entries for the new teas, plus a `poison` block mirroring `sickness.json`.
3. Poison look-alike cases in the guide's inspection mode (belladonna berries against blueberries and cranberries, already in the data).
Code: poison status, antidote cure list, bleeding stops with bandages. Tests: sickness-like cases in test_server_items.
