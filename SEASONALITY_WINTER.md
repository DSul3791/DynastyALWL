# Seasonality and the winter survival chain (Sal, 2026-10-31)

From data/tables/flora.json (`season`), drops.json (berry and harvest rows), fish_schools.json (`only_in`), carcass.json and the new items. A plant with `all` is available all year. Winter is the hard season: this is what the data gives a player, and where it falls short.

## Plants by season (counts are species in flora.json; kind plant or shrub)
| Season | Species | Foods and materials worth knowing |
|---|---|---|
| Spring | wild garlic, morel (spring only); nettle, wild rose, wild mint, sorrel (spring and summer); hawthorn, heartroot (spring, autumn) | wild garlic leaves and bulbs, morels, nettle greens and fibre, sorrel leaves |
| Summer | 34 species only in summer, including raspberry, blueberry, cloudberry, wild strawberry, flax, samphire, cotton grass | most berries, flax and linseed, cotton grass tinder |
| Summer and autumn | bramble, heather, mushrooms, wild carrot, chanterelle, puffball, prickly pear, belladonna (poison) | blackberries, wild carrot roots, mushrooms |
| Autumn | 16 species, including hazel, lingonberry, cranberry, crowberry, blackthorn, sea buckthorn, valerian, burdock | hazelnuts, sloes, cranberries, rose hips (now with the flora fix), valerian and burdock roots |
| Autumn and winter | juniper, emberroot, rimecap | juniper berries, emberroots (fuel), rimecap caps |
| Winter | sleetberry, frostglass orchid (both unusual plants) | sleetberries |
| All year | gorse, dwarf birch, saltbush, reeds, rosemary, aloe, tinder fungus, staunchmoss, wild banana (tropical) | kindling, thatch, rosemary, staunchmoss |

Fish: trout (brook, river), perch, pike, carp (lakes and ponds) are year round; salmon runs in autumn only; mackerel in summer only (fish_schools.json). Game (deer, boar, rabbit, wolf, fox, moose, birds) is year round in the data; no hibernation or migration is coded.

## What a winter player can eat (today's data)
1. **Hunting and fishing year round:** raw meat and fish cook into roast meat and roast fish at any fire (cooking.json).
2. **Stored food from autumn:** Smoked fish (keeps weeks), Fruit leather, Honey loaf (240 h shelf life), Trail bread (950 kcal), Nut paste, Chestnut cakes, Berry compote, Baked apples, Flour from stored grain (once farming exists). Spoilage hours are in spoilage.json.
3. **Winter plants:** juniper berries, sleetberries, rosemary and shoots of aloe in warm places. This is thin: no root cellar, no ice fishing, no winter greens.
4. **Shore life** (new): seaweed, shellfish, crab, eggs (nesting season only) when code lets players gather them.

## What a winter player wears (CLOTHING_WARMTH.md)
Cold at -10 C needs about 0.33 insulation: a full hide set (0.77). At -20 C: 0.5 (wool, 0.85 cap). Fire adds 20 C within 4 m; firewood and a shelter come from the early recipes.

## Gaps and proposals
- **Stored-food stock:** the starting 3-day chain (kill a deer, smoke it) needs a **Drying rack** and **salt** (sea salt waits on WATER_GATHER_SPEC.md). Proposal: Jerky (raw meat 2 + salt 1, drying rack) and Salted fish; both new items, not made yet.
- **Winter forage:** add 2 or 3 hardy winter food plants to the flora table (rose hips and hazelnuts already keep into early winter by item shelf life; add dried berries as a recipe, 2 berries into 1 dried berries, at a campfire, long shelf life).
- **Hibernation:** bears and hedgehogs should be absent in winter (ANIMAL_SPEC.md behaviour list); a winter game scarcity would sharpen the stored-food chain.
- **Measured?** Nothing here is play-tested. Numbers (cold needs) come from warmth.json's formula; edible winter plant count from flora.json.
