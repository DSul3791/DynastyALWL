# Backpacks

Dave's design, 15 Nov 2026 (project chat and thread "Review backpack plan against game"). Built on branch `claude/project-thread-t2kp6y`.

## Rulings (Dave)
- Backpacks are simple. They add no inventory slots; they raise how much weight you can carry, because they improve how you carry it.
- Four tiers, all fabric or leather (not wicker or wood), named by quality: Simple, Improved, Quality, Advanced.
- They replace the existing packs: Hide - Backpack, Leather - Backpack, Wicker - Pack basket and Traveller's rucksack are retired (the Wooden - Pack frame was already retired). A saved old pack loads as its new tier (`data/items/renames.json`): Hide and Wicker as Simple, Leather as Improved, Traveller's rucksack as Quality.
- A pack is mounted in the Back slot beside the character picture on the inventory screen. Mounted, it shows on the character and raises carry weight; a pack in the inventory does nothing.
- Lowest tier +5 kg, top tier +50 kg.
- Materials and stations:

| Pack | Materials | Where |
|---|---|---|
| Simple - Backpack | 5 Hide, 20 Twine, 4 Stick | by hand |
| Improved - Backpack | 5 Leather, 20 Twine, 1 Hardwood board | Leatherworking table |
| Quality - Backpack | 10 Leather, 20 Sinew, 15 nails (any kind), 2 Hardwood board | Leatherworking table |
| Advanced - Backpack | 2 Steel ingot, 25 Leather, 40 Sinew | Advanced smithy |

- Copper nails are a new item (Dave: "add copper nails to our items list"), and the Quality pack takes any nails (Dave: "really it can use any nails").

## For Dave (assumed on his behalf, provisional; change in data/items only)
- B-1: the middle tiers are +15 kg (Improved) and +30 kg (Quality).
- B-2: the packs themselves weigh 1, 1.5, 2 and 3 kg (`weights.json`).
- B-3: names follow "Tier - Noun" ("Simple - Backpack"), as "Improved - Well".
- B-4: "the tanners/leather station" is the Leatherworking table (the Tanning rack only turns scraped hide into leather).
- B-5: Copper nails: 1 Copper ingot makes 100 at the Primitive smithy (Bronze nails' recipe in copper); they fill every nails need, so they work wherever nails do.
- B-6: Hob sells the Simple - Backpack where he sold the hide pack, and the merchant wears one.
- B-7: values 30, 70, 120 and 220 copper; craft times 20, 24, 30 and 40 s.
- B-8: the menus call the player's own item grid "the inventory" instead of "the backpack" ("Your inventory is full.").
- The packs are drawn with the existing placeholder pack shape until Dave supplies models; the Quality and Advanced icons are recoloured copies of the Simple one.

## Mounting
The Back slot already existed (`src/client/ui/inventory/you_column.gd`, worn position `back:base`); the server only counts worn pieces (`CarryRules.carry_bonus_kg`). New here: a pack dragged from the inventory onto the Back slot is put on (ACT_WEAR), and the worn pack dragged back onto the inventory comes off (ACT_UNWEAR). Use (E) on a pack still puts it on, and the Tab screen still takes it off. No protocol or save-format change.
