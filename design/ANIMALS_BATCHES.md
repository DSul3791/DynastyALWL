# Adding the animals we have models for (Dave 7 Nov 2026)

Dave: "Add all the animals that we have models for." Source: the WildMesh 3D Ultimate Animal Pack (Realistic set, bought; model files are never committed, `/assets/animals/` is ignored; copy a kind's folder into `assets/animals/<kind>/` on a build machine). Species numbers are below 100; the next free number is kept in `KIND_OF_SPECIES` in `src/client/animal_view.gd`.

## What a species needs (the donkey's recipe)
`data/animals/animals.json` row (movement, habitat, biomes, defend, temperament); `models.json` row (scene, clips by role, materials, length_m); `data/animals/carcass.json` (look); `data/items/carcass.json` (parts); `data/items/seasons.json` (`game`); `data/animals/animal_sign.json`; a `<kind>_step` slot in `data/sound/batch1_slots.json`; a `KIND_OF_SPECIES` entry and a code-built stand-in in `animal_view.gd`; the kind added to the "newer species" lists in the six animal tests so their seeded counts stay as they were.

## One spec per species
`python tools/add_species.py spec.json` does the whole recipe above from one file (fields: kind, number, name, copy, row, model, carcass_look, carcass_items, season, sign, step, stand_in; see the tool's header). Then install the model, import, and run the creature check with `--clips` to pick each role's clip; fix the row until every column looks right.

## Generic fixes (in animal_view.gd, for every model)
- **Wrong clip by name:** role words never pick death, hit, interact, start, end or stop clips (the raccoon's "dead run" was its run; the cow's "WalkEnd" its walk).
- **Imported pose is not standing:** `size_clip` sizes and grounds the model by that clip's first frame (the crow is imported with its wings spread).
- **Texture alpha is not a cut-out:** a material entry with `"opaque": true` is drawn solid (the goat was invisible).
- Also: clip travel (root motion) taken out with walk and run played at the clip's own speed; a refused flat clip falls back to the next; skinned meshes sized through their bind; `young_model` draws a young animal from its own model (the calf).

## Batches
1. Wild, forest and mountain (this PR): lynx 17, black bear 18, elk 19, bighorn sheep 20, mountain goat 21, beaver 22.
2. Wild, small and birds (#540): chamois 23, mink 24, raccoon 25, rat 26, crow 27, pheasant 28, goose 29. Fish (trout, tuna, bluegill) need the fishing system, not the land animal rows: left to a later design.
3. Farm and tame (#542): cow 30 (calf as its young_model), goat 31, chicken 32 (hen, rooster), cat 33, dog 34 (labrador, bloodhound), wild ox 35 (the pack's buffalo). Farm animals do not spawn wild.

Variants (Deer_1, Doe, Buck, RedDeerMale, Wolf_1, Fox_1, Donkey_1, WildBoar, BrownBear) fold into the existing species and get no number.
Left out, wrong world: elephant, alligator, camel, kangaroo, lion, lioness, leopard, tiger, hyena, honey badger, rhinoceros, warthog, wildebeest, pronghorn, guineafowl. Mammoth: optional fantasy, not planned.

## Rules for the numbers
First-pass numbers are copied from the nearest live species (lynx from fox, black bear from brown bear without a den, elk from moose with deer herds, bighorn and goat from deer on steep ground, beaver from rabbit at the water edge) and are for QA to tune. No new mechanics: a beaver does not swim or build, a farm animal is not tameable until the taming design says so. Step sounds borrow existing clips.
