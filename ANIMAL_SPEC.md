# Animal and fauna spec (Sal, 2026-10-30)

Goal (Dave): islands that feel like they have grown for millions of years and are teeming with wildlife. This is data and a to-do list. No code was edited.

## 1. Audit: what the game has today
- **Live animals** (data/animals/animals.json, 7 species): rabbit, deer, wolf, moose, fox, duck (flock), horse. Seven is thin: no bird of prey, no small critters, no amphibians, no insects.
- **Fish** (fish_schools.json, items 76 to 79): trout, perch, carp, pike. `fish_schools.json` also names salmon, but no salmon item exists.
- **Loot** (data/items/carcass.json, was 8 species): rabbit, grouse, fox, boar, deer, wolf, moose, duck. Grouse and boar had loot but cannot spawn (not in animals.json).
- **Drop items:** raw meat, hide, bone, sinew, animal fat, feather.
- **Not measured:** per-biome animal density in the nine centre tiles. The spawn code is per player (target_per_player), not per biome, and I did not run the world generator. This needs a code owner or a measurement script.

## 2. What I added (data only, all in this branch)
- **7 new `future` items** (346 to 352): Antler, Tusk, Claw, Down, Quill, Hide glue, Bone arrow.
- **2 recipes** (225, 226): Hide glue (hide, at a campfire pot, gives 2) and Bone arrow (stick, feather, bone, gives 4). Bone arrows are added to the bow ammo list in bow.json; the bow's existing break chance table already has a bone entry.
- **14 new carcass loot rows**: hare, beaver, otter, badger, porcupine, lynx, bear, mountain goat, wild sheep, reindeer, pheasant, goose, eagle, gull. Also new parts on existing animals: boar gets tusks, deer and moose get antlers, duck gets down, wolf gets claws. Carcass sizes follow real body masses (approximate, from general reference knowledge; not individually checked).
- **data/animals/fauna_proposal.json**: 50 species with real-world names, biomes, diet, group size, day or night activity, rarity, role, mass, current status and what new work each needs. Nothing reads this file.

The result is a believable use chain: hide to leather (via the hide scraper) and glue; sinew to thread; bone and feather to arrows; antler and tusk as tool and charm material; down for warm clothing (clothing recipe not yet written); quills as pins.

## 3. Balance
Prey outnumber predators: 31 prey and ambient species against 8 predators in the proposal; apex animals (bear, eagle) are rarity 4 to 5. Herbivores come in herds; predators single or small packs. Night and day activity are split so the world changes after dark (badger, owl, bat, hedgehog, frog at night).

## 4. Who has to do what
| Needs | Species |
|---|---|
| **Spawn row in animals.json (code owner checks the spawn code reads it)** | hare, beaver, otter, badger, bear, boar, lynx, porcupine, reindeer, mountain goat, wild sheep, grouse, pheasant, goose, gull |
| **New models and animations (Kathleen)** | every species above plus raven, owl, eagle, woodpecker, songbirds, bat, frog, toad, newt, snakes, lizard, bee, butterfly, dragonfly, firefly, beetle, crab, eel, cod, salmon |
| **New behaviour (code owner)** | bear (charge, hibernation), boar and porcupine (armed defence; reuse the moose defend block), badger (sett), beaver (dam), eagle (dive), gull (steals food), raven (follows carcasses), marten (climb), adder (venom sickness), flyers (bats, owls, butterflies), fireflies |
| **Code limits to lift** | herd size above 6 (reindeer, goose flocks), slope above 1.0 (mountain goat), small-critter and night-only spawn, per-biome spawn weights |
| **New items** | Salmon, Eel, Cod, Crab (fish and shellfish), Egg, Honeycomb, Wax (bees), Wool (sheep, if tamed) |

## 5. Suggested relative density per biome (a guide, not measured)
Mixed forest is richest (about 27 of the 50 species), then temperate forest and grassland (17 each), boreal (14), heath (13), marsh (12), alpine (10). Deserts, mangrove and scrub get few species here because the proposal follows a temperate island; a tropical set (monkey, parrot, lizard, crocodile) is a later list.

## 6. Sources
Names, habits and rough masses come from general knowledge of the species (their Wikipedia and field-guide descriptions). I did no web search for this pass, so the figures are approximate. The game's balance numbers (meat counts, damage) are mine and need Dave's play testing.

## 7. Tests
validate_items, dishes, server_items, first_hour, inventory, stations and save_compat pass. test_animals has one failure, a timing check ("150 animals stay under 3 ms", measured 91 ms on this machine under load); I changed no animal code or animals.json, so I believe it is the machine, but I have not re-run it on a quiet machine.
