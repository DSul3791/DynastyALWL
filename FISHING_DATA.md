# Fishing data (Sal, 2026-10-31)

Read from data/items/fishing.json, fish_schools.json, vitals/spoilage/cooking and server fishing code (Tyler's model, Items refill 12). Real-world notes are general knowledge, not individually sourced.

## What the code reads today
- **Rod** (item 75): click at water within 8 m, wait 6 to 22 s, a bite window of 3 s, second click lands it. Chance 0.55 x skill x time of day (dawn and dusk x1.3, midday x0.7, night x0.9) x weather (rain x1.2, storm x0.4) x bait x stock, never above 0.93. Bait: berries, raw meat, plant fibre (x1.3). Cold water (under 5 C) x0.6; ice fishing through a cut hole.
- **Species by water type (rod):** stream: trout 0.7, perch 0.3. Pond: carp 0.6, perch 0.4. Lake: pike 0.3, perch 0.4, carp 0.3.
- **Fish schools (net and world fish):** brook: trout. River: trout 0.5, salmon 0.3, eel 0.2. Lake: perch, pike, carp. Pond: carp, perch. Sea shallows: herring 0.3, mackerel 0.25, smelt 0.2, cod 0.25. Seasons (only_in): salmon autumn, mackerel summer, herring spring/autumn/winter, smelt spring/winter, eel summer/autumn (my additions to herring, smelt, eel).
- **Shore net** (item 260): wading depth water only, hold 20 s, 1 to 3 tries.
- **Stock:** each 128 m water cell holds 6 to 14 fish, regrows one per 300 s (150 s at sea).

## Added this round (data)
Items salmon 419, herring 420, mackerel 421, smelt 422, eel 423, cod 424 (caught from the fish schools; food, cook into roast fish at a fire, raw is sickness bait like the others). kcal: salmon 320, mackerel 280, eel 300, herring 240, cod 200, smelt 150. Shelf life of raw fish 12 hours (eel 24). validate_items now counts fish in fish_schools.json as obtainable.

## Edibility and safety (general knowledge)
All fish here are edible cooked. Eel must be cooked (raw eel blood is toxic). Oily fish (mackerel, herring) spoil fast; the game gives them the same 12 h as trout. Pike and perch are fine; carp is muddy but safe.

## Proposals not built
| Idea | Data needed | Code |
|---|---|---|
| Fish trap (basket) set in a stream overnight | recipe: 10 sticks + 4 twine; structure; catch table by water | place, check next day |
| Bone fish hook, better bait (worms, grubs, fish guts) | items; fishing.json `bait` list; bait_mult per bait | bait choice in the cast |
| Spear fishing in shallows | spear tool class gets a fishing roll | exists as "Not built" in fishing.json |
| Sea rod vs river rod | rod tiers: wood rod, bone-hook rod, line of sinew | species by rod |
| Smoking and salting | smoked fish, salted fish (dishes added); drying rack structure | station |
| Seasons for rod fishing | fishing.json `only_in` mirrored from fish_schools | the rod species roll reads it |

## Use in the game
Edible fish feed the stored-food chain (SEASONALITY_WINTER.md), the fisher NPC buys them (shops_proposal.json) and the starter goal "Catch a fish" (starter_goals.json) rewards the first catch.
