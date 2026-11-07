# Adding the animals we have models for (Dave 7 Nov 2026)

Dave: "Add all the animals that we have models for." Source: the WildMesh 3D Ultimate Animal Pack (Realistic set, bought; model files are never committed, `/assets/animals/` is ignored; copy a kind's folder into `assets/animals/<kind>/` on a build machine). Species numbers are below 100; the next free number is kept in `KIND_OF_SPECIES` in `src/client/animal_view.gd`.

## What a species needs (the donkey's recipe)
`data/animals/animals.json` row (movement, habitat, biomes, defend, temperament); `models.json` row (scene, clips by role, materials, length_m); `data/animals/carcass.json` (look); `data/items/carcass.json` (parts); `data/items/seasons.json` (`game`); `data/animals/animal_sign.json`; a `<kind>_step` slot in `data/sound/batch1_slots.json`; a `KIND_OF_SPECIES` entry and a code-built stand-in in `animal_view.gd`; the kind added to the "newer species" lists in the six animal tests so their seeded counts stay as they were.

## Batches
1. Wild, forest and mountain (this PR): lynx 17, black bear 18, elk 19, bighorn sheep 20, mountain goat 21, beaver 22.
2. Wild, small and birds: chamois, mink, raccoon, rat, crow, pheasant, goose. Fish (trout, tuna, bluegill) need the fishing system, not the land animal rows: left to a later design.
3. Farm and tame: cow, calf, goat, chicken, rooster, cat, dogs (labrador, bloodhound), buffalo.

Variants (Deer_1, Doe, Buck, RedDeerMale, Wolf_1, Fox_1, Donkey_1, WildBoar, BrownBear) fold into the existing species and get no number.
Left out, wrong world: elephant, alligator, camel, kangaroo, lion, lioness, leopard, tiger, hyena, honey badger, rhinoceros, warthog, wildebeest, pronghorn, guineafowl. Mammoth: optional fantasy, not planned.

## Rules for the numbers
First-pass numbers are copied from the nearest live species (lynx from fox, black bear from brown bear without a den, elk from moose with deer herds, bighorn and goat from deer on steep ground, beaver from rabbit at the water edge) and are for QA to tune. No new mechanics: a beaver does not swim or build, a farm animal is not tameable until the taming design says so. Step sounds borrow existing clips.
