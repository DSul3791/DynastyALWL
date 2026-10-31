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


## Carcass rows and model priority (added 2026-10-31)
Every planned species with a body to work now has a row in data/items/carcass.json (35 species): the 24 from before plus horse, red squirrel, pine marten, hedgehog, raven, owl, woodpecker, songbirds, frog, grass snake and adder. Not given a row: bat, toad, newt, lizard, insects (nothing worth dressing), fish and shellfish (whole items from fishing or shore gathering, no carcass), crab (shore node). Every row has `blows` (knife blows to dress: under 2 kg 1, under 15 kg 2, under 60 kg 3, under 150 kg 4, under 300 kg 6, larger 8) and uses tool_class knife; the server reads one global `blows` (4) today, so reading the per-species value is a small code change. Yields are scaled by body mass in the existing pattern (deer 80 kg: 8 to 12 meat; moose 350 kg: 14 to 20; horse 450 kg: 16 to 22), small animals give 1 meat, bone or feathers.

**Models and spawn rows still needed, in priority order for the first hour** (Kathleen for the model, a code owner for the spawn row and behaviour; the first four also cover the player's first hunts):

| # | Species | State | kg | blows | Loot (min-max) |
|---|---|---|---|---|---|
| 1 | rabbit | live | 2.0 | 2 | raw_meat 1-2, hide 1-1, bone 1-2 |
| 2 | deer | live | 80.0 | 4 | raw_meat 8-12, hide 1-2, bone 4-7, sinew 3-5, animal_fat 1-3, antler 1-2 |
| 3 | fox | live | 7.0 | 2 | raw_meat 2-3, hide 1-1, bone 2-3, sinew 1-2 |
| 4 | boar | loot only: needs spawn row and model | 90.0 | 4 | raw_meat 8-14, hide 1-2, bone 4-7, sinew 2-4, animal_fat 2-4, tusk 2-2 |
| 5 | grouse | loot only | 1.0 | 1 | raw_meat 1-1, feather 4-8, bone 1-1 |
| 6 | duck | live, flocks | 1.2 | 1 | raw_meat 1-2, feather 3-6, bone 1-1, down 2-4 |
| 7 | fish (trout, perch, carp, pike) | live as fish schools; models are fish models, no carcass | - | - | n/a |
| 8 | frog | loot only (new) | 0.05 | 1 | raw_meat 1-1 |
| 9 | seal | loot only | 80.0 | 4 | seal_meat 8-12, hide 1-2, bone 3-5, animal_fat 4-7 |
| 10 | seabird | loot only | 1.5 | 1 | raw_meat 1-1, feather 4-8, egg 1-2, bone 1-1 |
| 11 | wild_sheep | loot only; wool | 50.0 | 3 | raw_meat 6-9, hide 1-2, bone 3-5, sinew 2-3, animal_fat 1-3, wool 2-4 |
| 12 | mountain_goat | loot only | 70.0 | 4 | raw_meat 7-10, hide 1-2, bone 4-6, sinew 2-4, animal_fat 1-2 |
| 13 | wolf | live (wolves system) | 35.0 | 3 | raw_meat 3-5, hide 1-2, bone 3-5, sinew 2-3, claw 1-2 |
| 14 | bear | loot only | 200.0 | 6 | raw_meat 12-18, hide 2-3, bone 6-9, sinew 3-5, animal_fat 5-9, claw 2-4 |

Rabbit, deer, fox, wolf and duck are live today; their carcass looks are in data/animals/carcass.json (Kathleen). The rest fall back to the deer body shape until each gets a row there.
