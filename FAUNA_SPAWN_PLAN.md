# Fauna spawn data plan (Sal, 2026-10-31)

## Where the animal code reads its data
`data/animals/animals.json` (read by src/stream/server_animals.gd, top-up loop around line 610). Each species row has `target_per_player`, `spawn_share` (chance per top-up), `herd` [min, max], `habitat` {`slope_max`, `water_edge_m`, `forest`...}, a `flock` block for birds on water, `exclude` for the starter tile, and movement numbers. Carcass loot is separate (`data/items/carcass.json`); look data is `data/animals/carcass.json`.

## What is missing for a rich, biome-true fauna
The loop picks a random spot 150 to 250 m from each player and asks only "is it too steep, too high, at a water edge, under trees?". It does not know the **biome**, the **time of day**, or the **season**. So every species spawns everywhere it can stand.

## The data (new, this round)
`data/animals/spawn_plan.json`: 44 non-live species (the 7 live ones keep their rows) in the animals.json row shape, generated from FAUNA_BY_BIOME.md's source: `target_per_player` (4 ambient, 3 under 5 kg, 2 under 60 kg, 1 above), `spawn_share` from rarity (1 common: 1.0, 2: 0.8, 3: 0.5, 4: 0.3, 5: 0.15), `herd` from the group size, plus three new keys: **`biomes`** (biome name from data/tables/biomes.json to weight), **`active`** {day, dusk, night}, **`class`** (land, bird, water, shore, ambient). Fish and shore life are listed (class water and shore) but spawn through other systems (fish_schools.json, tide-line nodes in WATER_GATHER_SPEC.md), so the animal loop must skip those two classes.

## Code job (short, for Tyler or a code owner; I asked Tyler which file, animals.json above is what the code reads)
1. After `_habitat_score`, add a biome weight: look up the biome at the candidate spot (tile biome id to name via biomes.json) and multiply the score by `biomes[name]`, rejecting weight 0 or a missing entry when the species has a `biomes` table.
2. Gate by `active`: skip species whose `active.<now>` is false (day 6 to 18, dusk 4 to 6 and 18 to 20, night otherwise; use the existing game clock).
3. Skip `class` water and shore in this loop (other systems own them).
4. Merge: for each species in spawn_plan.json add the row to animals.json **only when its model, movement numbers and carcass look exist** (ANIMAL_SPEC.md lists what is missing). Rabbit/deer/fox-style movement numbers can be copied from the nearest live species (hare from rabbit, goat from deer, lynx from fox, bear from moose).
5. Tests: test_animals (a species with `biomes` {marsh: 1} never spawns on forest ground; a night-only species does not spawn at noon), animals timing check must stay under its budget (cap 150 animals unchanged).

## Sizes to expect (per player, rough)
Forest: deer herd 5, boar 2, fox 1, squirrel and songbirds as ambient. Beach: seabird colony 3, seals 2 by the shore, crabs. Marsh: ducks, frogs, otter. Alpine: goat, sheep, eagle. All are Sal's starting numbers; tune by play.
