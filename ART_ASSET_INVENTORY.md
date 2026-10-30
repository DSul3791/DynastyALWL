# Art asset inventory

Kathleen (art), generated from the repository at branch `kathleen-art` on 2026-10-30. **Inventory only: nothing was fixed, changed or baked.** Counts are rows/entries that exist in tables, files or code; anything I could not confirm is flagged `unconfirmed`.

## How to read this

* **Quality stage** is my reading of the evidence in the repository. I could not run the game or look at renders, and the earlier art role's critique files (`art/CRITIQUES/`, `art/MODEL_INVENTORY.md`, `art/REFERENCE_PHOTOS.md`, `art/MODEL_PLAN.md`) are **not in this repository at all** (I searched file names and git history). So every stage comes from what the code builds, comments in the look scripts, `ART_DIRECTION.md`, and the archived Kathleen handoffs/action plans under `docs/archive/2026-10/`. No asset is rated 4: nothing in the repo says an asset is finished or photoreal.
* Stages: **0** table row/concept with no visible model found (or not a visible thing); **1** placeholder or primitive shape; **2** basic but recognisable; **3** reviewed and improved (evidence of review rounds or owner feedback in the repo); **4** polished.
* One entry = one table row, file, or builder. Flags: `fantasy` (fantasy species), `future` and `retired` (the `future`/`retired` keys in the item row), `unconfirmed`, `not visible` (concept rows like biomes), `unused` (builder exists, no structure row uses it), `not in game` (reference picture).
* Design document: the art design document already exists, **`ART_DIRECTION.md`** at the repository root (53 numbered sections). It covers the target picture, light, grass, ground, water, trees, rock, character, weather, performance budgets and per-build notes. It does **not** hold palette, scale/size conventions, model conventions, quality tiers or critiques; those are decisions still to be made.

## Summary: counts per category and quality stage

| Category | 0 | 1 | 2 | 3 | 4 | Total |
|---|---|---|---|---|---|---|
| 1 Trees | 0 | 0 | 0 | 25 | 0 | 25 |
| 2 Shrubs and bushes | 0 | 0 | 19 | 7 | 0 | 26 |
| 3 Herbs, flowers and low berries | 0 | 0 | 50 | 0 | 0 | 50 |
| 4 Ferns, grasses and reeds | 0 | 0 | 16 | 0 | 0 | 16 |
| 5 Fungi | 0 | 0 | 11 | 0 | 0 | 11 |
| 6 Natural ground objects | 0 | 0 | 32 | 16 | 0 | 48 |
| 7 Grass cover, litter and painted textures | 0 | 0 | 22 | 4 | 0 | 26 |
| 8 Terrain surface and ground materials | 81 | 0 | 28 | 0 | 0 | 109 |
| 9 Water, sky, weather and light | 2 | 0 | 12 | 10 | 0 | 24 |
| 10 Items: raw materials, wood and crafted parts | 0 | 0 | 101 | 0 | 0 | 101 |
| 11 Items: gathered plant parts and foraged goods | 0 | 0 | 169 | 5 | 0 | 174 |
| 12 Items: food, drink and medicine | 0 | 0 | 37 | 0 | 0 | 37 |
| 13 Items: tools, weapons and ammunition | 1 | 0 | 16 | 24 | 0 | 41 |
| 14 Items: containers, coins, clothing and gear | 0 | 0 | 18 | 0 | 0 | 18 |
| 15 Items: placeable kits | 0 | 0 | 33 | 2 | 0 | 35 |
| 16 Placed structures: shelter, storage, fires and traps | 0 | 0 | 6 | 7 | 0 | 13 |
| 17 Placed structures: building pieces | 0 | 0 | 30 | 0 | 0 | 30 |
| 18 Stations and furniture | 0 | 0 | 9 | 4 | 0 | 13 |
| 19 Creatures, animals and NPCs | 4 | 0 | 10 | 6 | 0 | 20 |
| 20 Player avatar and worn clothing | 0 | 3 | 12 | 2 | 0 | 17 |
| 21 Particles and effects | 1 | 1 | 5 | 3 | 0 | 10 |
| 22 UI icons, HUD pictures and design pictures | 1 | 1 | 19 | 0 | 0 | 21 |
| **All categories** | **90** | **5** | **655** | **115** | **0** | **865** |

Without the concept rows (biomes, geology, air) and the reference pictures: 818 entries; stage 0 56, stage 1 5, stage 2 642, stage 3 115.

**Pending character restyle (Dave, 2026-10-30, via Sonny's plan):** the player body, first-person arms, fist, NPC bodies and the worn-clothing meshes are flagged `pending character restyle`; Dave has decided the character becomes a simple stylised human (simple face, hair, hands) instead of the featureless ragdoll, so their ratings below describe the ragdoll and will be redone when the new body exists.

Flag counts: fantasy 38, retired item rows 56, `future` item rows 130, unconfirmed 60, unused builders 12.

## Index

* [1 Trees](#1-trees) (25)
* [2 Shrubs and bushes](#2-shrubs-and-bushes) (26)
* [3 Herbs, flowers and low berries](#3-herbs-flowers-and-low-berries) (50)
* [4 Ferns, grasses and reeds](#4-ferns-grasses-and-reeds) (16)
* [5 Fungi](#5-fungi) (11)
* [6 Natural ground objects](#6-natural-ground-objects) (48)
* [7 Grass cover, litter and painted textures](#7-grass-cover-litter-and-painted-textures) (26)
* [8 Terrain surface and ground materials](#8-terrain-surface-and-ground-materials) (109)
* [9 Water, sky, weather and light](#9-water-sky-weather-and-light) (24)
* [10 Items: raw materials, wood and crafted parts](#10-items-raw-materials-wood-and-crafted-parts) (101)
* [11 Items: gathered plant parts and foraged goods](#11-items-gathered-plant-parts-and-foraged-goods) (174)
* [12 Items: food, drink and medicine](#12-items-food-drink-and-medicine) (37)
* [13 Items: tools, weapons and ammunition](#13-items-tools-weapons-and-ammunition) (41)
* [14 Items: containers, coins, clothing and gear](#14-items-containers-coins-clothing-and-gear) (18)
* [15 Items: placeable kits](#15-items-placeable-kits) (35)
* [16 Placed structures: shelter, storage, fires and traps](#16-placed-structures-shelter-storage-fires-and-traps) (13)
* [17 Placed structures: building pieces](#17-placed-structures-building-pieces) (30)
* [18 Stations and furniture](#18-stations-and-furniture) (13)
* [19 Creatures, animals and NPCs](#19-creatures-animals-and-npcs) (20)
* [20 Player avatar and worn clothing](#20-player-avatar-and-worn-clothing) (17)
* [21 Particles and effects](#21-particles-and-effects) (10)
* [22 UI icons, HUD pictures and design pictures](#22-ui-icons-hud-pictures-and-design-pictures) (21)
* [Passes and searches](#passes-and-searches)
* [Gaps and uncertainties](#gaps-and-uncertainties)


## 1 Trees

25 entries. Stages: 25 x stage 3.


### kind tree (25)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Oak | oak tree, 14 to 25 m tall | data/tables/flora.json id 0 (oak); built by src/flora/tree_builder.gd | built in code, _oak, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) |
| Beech | beech tree, 6 to 28 m tall | data/tables/flora.json id 1 (beech); built by src/flora/tree_builder.gd | built in code, _beech, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) |
| Birch | birch tree, 9 to 18 m tall | data/tables/flora.json id 2 (birch); built by src/flora/tree_builder.gd | built in code, _birch, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) |
| Scots pine | scots_pine tree, 20 to 35 m tall | data/tables/flora.json id 3 (scots_pine); built by src/flora/tree_builder.gd | built in code, _scots_pine, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) |
| Spruce | spruce tree, 28 to 48 m tall | data/tables/flora.json id 4 (spruce); built by src/flora/tree_builder.gd | built in code, _spruce, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) |
| Alder | alder tree, 8 to 18 m tall | data/tables/flora.json id 5 (alder); built by src/flora/tree_builder.gd | built in code, _alder, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) |
| Willow | willow tree, 5 to 16 m tall | data/tables/flora.json id 6 (willow); built by src/flora/tree_builder.gd | built in code, _willow, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) |
| Coconut palm | coconut_palm tree, 10 to 22 m tall | data/tables/flora.json id 7 (coconut_palm); built by src/flora/tree_builder.gd | built in code, _palm with a look per species (coconut / date / banana), frond cards assets/trees/leaf_palm.png | 3 | curved trunk, drooping fronds and nuts (coconut), rough trunk, upright fronds and date bunches (date); seen in the real game (art/CRITIQUES/trees_2026-10-30): reads as a palm, fronds thin (severity 1 open) |
| Tropical hardwood | tropical_hardwood tree, 22 to 36 m tall | data/tables/flora.json id 8 (tropical_hardwood); built by src/flora/tree_builder.gd | built in code, _tropical_hardwood, 4 variants, near/mid/far models plus impostor | 3 | new species builder; seen in the real game with the look rig, fixed after art/CRITIQUES/trees_2026-10-30 (severity 2 flaws fixed, severity 1 open) |
| Acacia | acacia tree, 6 to 12 m tall | data/tables/flora.json id 9 (acacia); built by src/flora/tree_builder.gd | built in code, _acacia, 4 variants, near/mid/far models plus impostor | 3 | new species builder; seen in the real game with the look rig, fixed after art/CRITIQUES/trees_2026-10-30 (severity 2 flaws fixed, severity 1 open) |
| Mangrove | mangrove tree, 5 to 12 m tall | data/tables/flora.json id 10 (mangrove); built by src/flora/tree_builder.gd | built in code, _mangrove, 4 variants, near/mid/far models plus impostor | 3 | new species builder; seen in the real game with the look rig, fixed after art/CRITIQUES/trees_2026-10-30 (severity 2 flaws fixed, severity 1 open) |
| Rowan | rowan tree, 6 to 14 m tall | data/tables/flora.json id 35 (rowan); built by src/flora/tree_builder.gd | built in code, _rowan, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) |
| Crab apple | wild_apple tree, 4 to 10 m tall | data/tables/flora.json id 40 (wild_apple); built by src/flora/tree_builder.gd | built in code, _wild_apple, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) |
| Wild pear | wild_pear tree, 4 to 15 m tall | data/tables/flora.json id 41 (wild_pear); built by src/flora/tree_builder.gd | built in code, _wild_apple (pear flag), 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) |
| Wild cherry | wild_cherry tree, 4 to 18 m tall | data/tables/flora.json id 42 (wild_cherry); built by src/flora/tree_builder.gd | built in code, _wild_apple (cherry flag), 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) |
| Sweet chestnut | sweet_chestnut tree, 5 to 24 m tall | data/tables/flora.json id 43 (sweet_chestnut); built by src/flora/tree_builder.gd | built in code, _chestnut, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) |
| Walnut | walnut tree, 5 to 22 m tall | data/tables/flora.json id 44 (walnut); built by src/flora/tree_builder.gd | built in code, _chestnut (walnut flag), 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) |
| Date palm | date_palm tree, 12 to 22 m tall | data/tables/flora.json id 81 (date_palm); built by src/flora/tree_builder.gd | built in code, _palm with a look per species (coconut / date / banana), frond cards assets/trees/leaf_palm.png | 3 | curved trunk, drooping fronds and nuts (coconut), rough trunk, upright fronds and date bunches (date); seen in the real game (art/CRITIQUES/trees_2026-10-30): reads as a palm, fronds thin (severity 1 open) |
| Mirrorbark | mirrorbark tree, 4 to 20 m tall fantasy species | data/tables/flora.json id 89 (mirrorbark); built by src/flora/tree_builder.gd | built in code, _mirrorbark, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) [fantasy] |
| Wardpine | wardpine tree, 18 to 36 m tall fantasy species | data/tables/flora.json id 92 (wardpine); built by src/flora/tree_builder.gd | built in code, _wardpine, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) [fantasy] |
| Hearthwood | hearthwood tree, 5 to 26 m tall fantasy species | data/tables/flora.json id 113 (hearthwood); built by src/flora/tree_builder.gd | built in code, _hearthwood, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) [fantasy] |
| Everember | everember tree, 70 to 110 m tall fantasy species | data/tables/flora.json id 122 (everember); built by src/flora/tree_builder.gd | built in code, _everember, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) [fantasy] |
| Witness tree | witness_tree tree, 18 to 28 m tall fantasy species | data/tables/flora.json id 123 (witness_tree); built by src/flora/tree_builder.gd | built in code, _witness, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) [fantasy] |
| Balsam fir | balsam_fir tree, 6 to 21 m tall | data/tables/flora.json id 125 (balsam_fir); built by src/flora/tree_builder.gd | built in code, _balsam_fir, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) |
| Sugar maple | maple tree, 5 to 26 m tall | data/tables/flora.json id 126 (maple); built by src/flora/tree_builder.gd | built in code, _maple, 4 variants, near/mid/far models plus impostor | 3 | species builder with a comment citing the owner's photos/description, 4 variants, season states; cannot confirm by a render (no critique files in repo) |

## 2 Shrubs and bushes

26 entries. Stages: 19 x stage 2, 7 x stage 3.


### berry and thorn shrubs (6)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Hazel | hazel, 4 to 7 m tall | data/tables/flora.json id 11 (hazel); built by src/flora/tree_builder.gd | built in code, _hazel (clump of stems, catkins, nuts), SHRUB kind | 3 | own builder written from the owner's 8-panel photo set (comment); four seasons |
| Bramble | bramble, 1.2 to 2.4 m tall | data/tables/flora.json id 12 (bramble); built by src/flora/tree_builder.gd | built in code, _cane_shrub with SHRUB_LOOKS[bramble] | 3 | rebuilt from the owner's photos after the owner's "No, looks terrible" (archived Kathleen handoff 2026-10-23); clean rig renders were still pending then |
| Blueberry | blueberry, 0.25 to 0.5 m tall | data/tables/flora.json id 27 (blueberry); built by src/flora/tree_builder.gd | built in code, _cane_shrub with SHRUB_LOOKS[blueberry] | 3 | rebuilt from the owner's photos after the owner's "No, looks terrible" (archived Kathleen handoff 2026-10-23); clean rig renders were still pending then |
| Raspberry | raspberry, 1.5 to 2.5 m tall | data/tables/flora.json id 32 (raspberry); built by src/flora/tree_builder.gd | built in code, _cane_shrub with SHRUB_LOOKS[raspberry] | 3 | rebuilt from the owner's photos after the owner's "No, looks terrible" (archived Kathleen handoff 2026-10-23); clean rig renders were still pending then |
| Wild rose | wild_rose, 1.2 to 2.6 m tall | data/tables/flora.json id 36 (wild_rose); built by src/flora/tree_builder.gd | built in code, _cane_shrub with SHRUB_LOOKS[wild_rose] | 3 | rebuilt from the owner's photos after the owner's "No, looks terrible" (archived Kathleen handoff 2026-10-23); clean rig renders were still pending then |
| Blackthorn | blackthorn, 2 to 3.6 m tall | data/tables/flora.json id 37 (blackthorn); built by src/flora/tree_builder.gd | built in code, _blackthorn, look row SHRUB_LOOKS[blackthorn] | 3 | rebuilt after the owner's "looks terrible" on cane berries (archived handoff 2026-10-23); last render before the latest rework judged too sparse; not re-seen |

### other shrubs (cane-shrub family) (16)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Juniper | juniper, 1 to 4 m tall | data/tables/flora.json id 13 (juniper); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[juniper] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours |
| Gorse | gorse, 1 to 2.5 m tall | data/tables/flora.json id 14 (gorse); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[gorse] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours |
| Dwarf birch | dwarf_birch, 0.4 to 1.2 m tall | data/tables/flora.json id 15 (dwarf_birch); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[dwarf_birch] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours |
| Saltbush | saltbush, 0.5 to 1.5 m tall | data/tables/flora.json id 16 (saltbush); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[saltbush] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours |
| Elder | elder, 3 to 7 m tall | data/tables/flora.json id 34 (elder); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[elder] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours |
| Hawthorn | hawthorn, 3 to 7 m tall | data/tables/flora.json id 38 (hawthorn); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[hawthorn] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours |
| Sea buckthorn | sea_buckthorn, 1.5 to 3.5 m tall | data/tables/flora.json id 39 (sea_buckthorn); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[sea_buckthorn] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours |
| Wild sage | wild_sage, 0.3 to 0.7 m tall | data/tables/flora.json id 54 (wild_sage); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[wild_sage] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours |
| Rosemary | rosemary, 0.6 to 1.5 m tall | data/tables/flora.json id 55 (rosemary); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[rosemary] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours |
| Drakethorn | drakethorn, 0.8 to 2 m tall fantasy species | data/tables/flora.json id 88 (drakethorn); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[drakethorn] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours [fantasy] |
| Sunberry | sunberry, 0.5 to 1.4 m tall fantasy species | data/tables/flora.json id 90 (sunberry); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[sunberry] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours [fantasy] |
| Hag willow | hagwillow, 2 to 4 m tall fantasy species | data/tables/flora.json id 94 (hagwillow); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[hagwillow] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours [fantasy] |
| Honeyspindle | honeyspindle, 1 to 2.2 m tall fantasy species | data/tables/flora.json id 99 (honeyspindle); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[honeyspindle] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours [fantasy] |
| Sleetberry | sleetberry, 0.3 to 0.8 m tall fantasy species | data/tables/flora.json id 103 (sleetberry); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[sleetberry] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours [fantasy] |
| Tanglewort | tanglewort, 0.3 to 0.9 m tall fantasy species | data/tables/flora.json id 108 (tanglewort); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[tanglewort] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours [fantasy] |
| Sunsilver vine | sunsilver_vine, 1.5 to 3 m tall fantasy species | data/tables/flora.json id 117 (sunsilver_vine); built by src/flora/tree_builder.gd | built in code, _cane_shrub with CANE_SHRUBS[sunsilver_vine] | 2 | one data row per species from a stated reference ("goal 1b family 5" comment); not seen rendered; fantasy ones follow the listed colours [fantasy] |

### cactus and succulents (3)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Cactus | cactus, 1 to 5 m tall | data/tables/flora.json id 17 (cactus); built by src/flora/tree_builder.gd | built in code, _succulent/_column (cactus) | 2 | builder written from a stated reference (saguaro/aloe/prickly pear, comment in tree_builder.gd); not seen rendered |
| Aloe | aloe, 0.3 to 0.8 m tall | data/tables/flora.json id 69 (aloe); built by src/flora/tree_builder.gd | built in code, _succulent/_column (aloe) | 2 | builder written from a stated reference (saguaro/aloe/prickly pear, comment in tree_builder.gd); not seen rendered |
| Prickly pear | prickly_pear, 0.8 to 2.5 m tall | data/tables/flora.json id 82 (prickly_pear); built by src/flora/tree_builder.gd | built in code, _succulent/_column (prickly_pear) | 2 | builder written from a stated reference (saguaro/aloe/prickly pear, comment in tree_builder.gd); not seen rendered |

### palm shrub (1)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Wild banana | wild_banana, 3 to 6 m tall | data/tables/flora.json id 80 (wild_banana); built by src/flora/tree_builder.gd | built in code, _palm (banana look: soft pseudostem, broad leaves, hanging bunch) | 3 | seen in the real game (art/CRITIQUES/trees_2026-10-30): reads as a banana plant; bunch tiny (severity 1 open) |

## 3 Herbs, flowers and low berries

50 entries. Stages: 50 x stage 2.


### wild flowers and herbs (39)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Heather | heather, 0.2 to 0.6 m tall | data/tables/flora.json id 19 (heather); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[heather] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Wild flax | flax, 0.4 to 0.9 m tall | data/tables/flora.json id 21 (flax); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[flax] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Alpine flowers | alpine_flowers, 0.1 to 0.3 m tall | data/tables/flora.json id 25 (alpine_flowers); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[alpine_flowers] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Wild garlic | wild_garlic, 0.2 to 0.45 m tall | data/tables/flora.json id 45 (wild_garlic); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[wild_garlic] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Wild thyme | wild_thyme, 0.05 to 0.15 m tall | data/tables/flora.json id 46 (wild_thyme); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[wild_thyme] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Water mint | wild_mint, 0.2 to 0.6 m tall | data/tables/flora.json id 47 (wild_mint); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[wild_mint] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Sorrel | sorrel, 0.2 to 0.6 m tall | data/tables/flora.json id 48 (sorrel); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[sorrel] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Dandelion | dandelion, 0.1 to 0.3 m tall | data/tables/flora.json id 49 (dandelion); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[dandelion] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Wild carrot | wild_carrot, 0.4 to 1 m tall | data/tables/flora.json id 50 (wild_carrot); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[wild_carrot] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Watercress | watercress, 0.1 to 0.3 m tall | data/tables/flora.json id 51 (watercress); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[watercress] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Wild marjoram | wild_marjoram, 0.3 to 0.6 m tall | data/tables/flora.json id 53 (wild_marjoram); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[wild_marjoram] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Lavender | lavender, 0.3 to 0.7 m tall | data/tables/flora.json id 56 (lavender); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[lavender] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Yarrow | yarrow, 0.3 to 0.7 m tall | data/tables/flora.json id 57 (yarrow); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[yarrow] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Chamomile | chamomile, 0.2 to 0.5 m tall | data/tables/flora.json id 59 (chamomile); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[chamomile] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| St John's wort | st_johns_wort, 0.3 to 0.8 m tall | data/tables/flora.json id 61 (st_johns_wort); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[st_johns_wort] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Valerian | valerian, 0.6 to 1.5 m tall | data/tables/flora.json id 62 (valerian); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[valerian] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Meadowsweet | meadowsweet, 0.6 to 1.2 m tall | data/tables/flora.json id 63 (meadowsweet); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[meadowsweet] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Feverfew | feverfew, 0.3 to 0.6 m tall | data/tables/flora.json id 64 (feverfew); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[feverfew] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Arnica | arnica, 0.2 to 0.5 m tall | data/tables/flora.json id 67 (arnica); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[arnica] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Angelica | angelica, 1 to 2 m tall | data/tables/flora.json id 68 (angelica); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[angelica] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Foxglove | foxglove, 0.6 to 1.5 m tall | data/tables/flora.json id 70 (foxglove); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[foxglove] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Wolfsbane | wolfsbane, 0.5 to 1.2 m tall | data/tables/flora.json id 72 (wolfsbane); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[wolfsbane] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours |
| Owlpetal | owlpetal, 0.2 to 0.5 m tall fantasy species | data/tables/flora.json id 83 (owlpetal); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[owlpetal] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Emberroot | emberroot, 0.3 to 0.7 m tall fantasy species | data/tables/flora.json id 85 (emberroot); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[emberroot] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Heartroot | heartroot, 0.2 to 0.4 m tall fantasy species | data/tables/flora.json id 95 (heartroot); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[heartroot] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Gloomthistle | gloomthistle, 0.6 to 1.4 m tall fantasy species | data/tables/flora.json id 97 (gloomthistle); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[gloomthistle] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Dewlantern | dewlantern, 0.2 to 0.4 m tall fantasy species | data/tables/flora.json id 98 (dewlantern); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[dewlantern] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Marrowroot | marrowroot, 0.3 to 0.6 m tall fantasy species | data/tables/flora.json id 100 (marrowroot); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[marrowroot] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Brinebell | brinebell, 0.15 to 0.35 m tall fantasy species | data/tables/flora.json id 102 (brinebell); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[brinebell] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Quenchbell | quenchbell, 0.3 to 0.6 m tall fantasy species | data/tables/flora.json id 104 (quenchbell); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[quenchbell] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Duskmallow | duskmallow, 0.4 to 1 m tall fantasy species | data/tables/flora.json id 107 (duskmallow); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[duskmallow] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Truthsage | truthsage, 0.3 to 0.6 m tall fantasy species | data/tables/flora.json id 110 (truthsage); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[truthsage] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Nightcrown | nightcrown, 0.15 to 0.35 m tall fantasy species | data/tables/flora.json id 114 (nightcrown); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[nightcrown] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Mournbloom | mournbloom, 0.3 to 0.7 m tall fantasy species | data/tables/flora.json id 115 (mournbloom); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[mournbloom] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Pilgrim's cup | pilgrims_cup, 0.3 to 0.7 m tall fantasy species | data/tables/flora.json id 116 (pilgrims_cup); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[pilgrims_cup] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Frostglass orchid | frostglass_orchid, 0.15 to 0.3 m tall fantasy species | data/tables/flora.json id 118 (frostglass_orchid); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[frostglass_orchid] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Sevenyear lily | sevenyear_lily, 0.6 to 1.2 m tall fantasy species | data/tables/flora.json id 119 (sevenyear_lily); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[sevenyear_lily] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Stillwater lotus | stillwater_lotus, 0.1 to 0.3 m tall fantasy species | data/tables/flora.json id 120 (stillwater_lotus); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[stillwater_lotus] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |
| Gloaming star | gloaming_star, 0.2 to 0.4 m tall fantasy species | data/tables/flora.json id 121 (gloaming_star); built by src/flora/tree_builder.gd | built in code, _wildflower with WILDFLOWER_LOOKS[gloaming_star] (daisy/umbel/spike/bell head) | 2 | parametric stems + flower head in explicit colours; written from references for the real species (comment), not seen rendered; fantasy ones invented from listed colours [fantasy] |

### broad-leaved herbs (6)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Nettle | nettle, 0.9 to 1.5 m tall | data/tables/flora.json id 23 (nettle); built by src/flora/tree_builder.gd | built in code, _herb (generic upright herb, flower colour fixed) | 2 | built from the owner's nettle photos per archived handoff; the builder is the older generic _herb; not seen rendered |
| Comfrey | comfrey, 0.5 to 1.2 m tall | data/tables/flora.json id 60 (comfrey); built by src/flora/tree_builder.gd | built in code, _leafy_herb with HERB_LOOKS[comfrey] | 2 | rosette + flowering stems; stated reference; not seen rendered |
| Burdock | burdock, 0.6 to 1.5 m tall | data/tables/flora.json id 65 (burdock); built by src/flora/tree_builder.gd | built in code, _leafy_herb with HERB_LOOKS[burdock] | 2 | rosette + flowering stems; stated reference; not seen rendered |
| Mugwort | mugwort, 0.6 to 1.5 m tall | data/tables/flora.json id 66 (mugwort); built by src/flora/tree_builder.gd | built in code, _leafy_herb with HERB_LOOKS[mugwort] | 2 | rosette + flowering stems; stated reference; not seen rendered |
| Deadly nightshade | belladonna, 0.5 to 1.5 m tall | data/tables/flora.json id 71 (belladonna); built by src/flora/tree_builder.gd | built in code, _leafy_herb with HERB_LOOKS[belladonna] | 2 | rosette + flowering stems; stated reference; not seen rendered |
| Henbane | henbane, 0.3 to 0.8 m tall | data/tables/flora.json id 73 (henbane); built by src/flora/tree_builder.gd | built in code, _leafy_herb with HERB_LOOKS[henbane] | 2 | rosette + flowering stems; stated reference; not seen rendered |

### low berries (5)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Lingonberry | lingonberry, 0.1 to 0.3 m tall | data/tables/flora.json id 28 (lingonberry); built by src/flora/tree_builder.gd | built in code, _ground_berry with GROUND_LOOKS[lingonberry] | 2 | built from the owner's blueberry-carpet photos as the reference class (archived handoff); not seen rendered |
| Cranberry | cranberry, 0.1 to 0.2 m tall | data/tables/flora.json id 29 (cranberry); built by src/flora/tree_builder.gd | built in code, _ground_berry with GROUND_LOOKS[cranberry] | 2 | built from the owner's blueberry-carpet photos as the reference class (archived handoff); not seen rendered |
| Cloudberry | cloudberry, 0.1 to 0.25 m tall | data/tables/flora.json id 30 (cloudberry); built by src/flora/tree_builder.gd | built in code, _ground_berry with GROUND_LOOKS[cloudberry] | 2 | built from the owner's blueberry-carpet photos as the reference class (archived handoff); not seen rendered |
| Wild strawberry | wild_strawberry, 0.1 to 0.25 m tall | data/tables/flora.json id 31 (wild_strawberry); built by src/flora/tree_builder.gd | built in code, _ground_berry with GROUND_LOOKS[wild_strawberry] | 2 | built from the owner's blueberry-carpet photos as the reference class (archived handoff); not seen rendered |
| Crowberry | crowberry, 0.1 to 0.3 m tall | data/tables/flora.json id 33 (crowberry); built by src/flora/tree_builder.gd | built in code, _ground_berry with GROUND_LOOKS[crowberry] | 2 | built from the owner's blueberry-carpet photos as the reference class (archived handoff); not seen rendered |

## 4 Ferns, grasses and reeds

16 entries. Stages: 16 x stage 2.


### ferns and mosses (5)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Fern | fern, 0.5 to 1.2 m tall | data/tables/flora.json id 18 (fern); built by src/flora/tree_builder.gd | built in code, _fern_rosette with FERN_LOOKS[fern] | 2 | parametric fronds; stated reference; not seen rendered; echo_moss/staunchmoss use the fern rosette |
| Staunchmoss | staunchmoss, 0.03 to 0.1 m tall fantasy species | data/tables/flora.json id 84 (staunchmoss); built by src/flora/tree_builder.gd | built in code, _fern_rosette with FERN_LOOKS[staunchmoss] | 2 | parametric fronds; stated reference; not seen rendered; echo_moss/staunchmoss use the fern rosette |
| Hushfern | hushfern, 0.3 to 0.9 m tall fantasy species | data/tables/flora.json id 91 (hushfern); built by src/flora/tree_builder.gd | built in code, _fern_rosette with FERN_LOOKS[hushfern] | 2 | parametric fronds; stated reference; not seen rendered; echo_moss/staunchmoss use the fern rosette |
| Whisperfern | whisperfern, 0.4 to 1 m tall fantasy species | data/tables/flora.json id 105 (whisperfern); built by src/flora/tree_builder.gd | built in code, _fern_rosette with FERN_LOOKS[whisperfern] | 2 | parametric fronds; stated reference; not seen rendered; echo_moss/staunchmoss use the fern rosette |
| Echo moss | echo_moss, 0.02 to 0.06 m tall fantasy species | data/tables/flora.json id 112 (echo_moss); built by src/flora/tree_builder.gd | built in code, _fern_rosette with FERN_LOOKS[echo_moss] | 2 | parametric fronds; stated reference; not seen rendered; echo_moss/staunchmoss use the fern rosette |

### reeds and water plants (6)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Reeds | reeds, 1.5 to 3 m tall | data/tables/flora.json id 20 (reeds); built by src/flora/tree_builder.gd | built in code, _reed_stand with REED_LOOKS[reeds] | 2 | parametric stand; fantasy ones recoloured from the same builder; not seen rendered |
| Wispbloom | wispbloom, 0.4 to 1 m tall fantasy species | data/tables/flora.json id 87 (wispbloom); built by src/flora/tree_builder.gd | built in code, _reed_stand with REED_LOOKS[wispbloom] | 2 | parametric stand; fantasy ones recoloured from the same builder; not seen rendered [fantasy] |
| Tideglass weed | tideglass_weed, 0.3 to 0.8 m tall fantasy species | data/tables/flora.json id 96 (tideglass_weed); built by src/flora/tree_builder.gd | built in code, _reed_stand with REED_LOOKS[tideglass_weed] | 2 | parametric stand; fantasy ones recoloured from the same builder; not seen rendered [fantasy] |
| Riverbraid | riverbraid, 0.8 to 1.6 m tall fantasy species | data/tables/flora.json id 101 (riverbraid); built by src/flora/tree_builder.gd | built in code, _reed_stand with REED_LOOKS[riverbraid] | 2 | parametric stand; fantasy ones recoloured from the same builder; not seen rendered [fantasy] |
| Stormreed | stormreed, 1.2 to 2.4 m tall fantasy species | data/tables/flora.json id 109 (stormreed); built by src/flora/tree_builder.gd | built in code, _reed_stand with REED_LOOKS[stormreed] | 2 | parametric stand; fantasy ones recoloured from the same builder; not seen rendered [fantasy] |
| Tidecrown | tidecrown, 0.2 to 0.5 m tall fantasy species | data/tables/flora.json id 124 (tidecrown); built by src/flora/tree_builder.gd | built in code, _reed_stand with REED_LOOKS[tidecrown] | 2 | parametric stand; fantasy ones recoloured from the same builder; not seen rendered [fantasy] |

### grasses (5)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Tall grass | tall_grass, 0.5 to 1 m tall | data/tables/flora.json id 22 (tall_grass); built by src/flora/tree_builder.gd | built in code, _grass_tuft with GRASS_LOOKS[tall_grass] | 2 | parametric tuft; not seen rendered |
| Cotton grass | cotton_grass, 0.2 to 0.5 m tall | data/tables/flora.json id 24 (cotton_grass); built by src/flora/tree_builder.gd | built in code, _grass_tuft with GRASS_LOOKS[cotton_grass] | 2 | parametric tuft; not seen rendered |
| Samphire | samphire, 0.1 to 0.3 m tall | data/tables/flora.json id 52 (samphire); built by src/flora/tree_builder.gd | built in code, _grass_tuft with GRASS_LOOKS[samphire] | 2 | parametric tuft; not seen rendered |
| Ribwort plantain | plantain, 0.1 to 0.4 m tall | data/tables/flora.json id 58 (plantain); built by src/flora/tree_builder.gd | built in code, _grass_tuft with GRASS_LOOKS[plantain] | 2 | parametric tuft; not seen rendered |
| Thatching grass | thatch_grass, 0.8 to 1.4 m tall | data/tables/flora.json id 127 (thatch_grass); built by src/flora/tree_builder.gd | built in code, _grass_tuft with GRASS_LOOKS[thatch_grass] | 2 | parametric tuft; not seen rendered |

## 5 Fungi

11 entries. Stages: 11 x stage 2.


### fungi (11)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Mushrooms | mushrooms, 0.1 to 0.3 m tall | data/tables/flora.json id 26 (mushrooms); built by src/flora/tree_builder.gd | built in code, _mushroom with MUSHROOM_LOOKS[mushrooms] (lathe-turned stem and cap) | 2 | dome/cone/funnel/ball/bracket profiles from real species (comment; owner 2026-10-23 "plants must look like the real thing"); not seen rendered |
| Chanterelle | chanterelle, 0.05 to 0.12 m tall | data/tables/flora.json id 74 (chanterelle); built by src/flora/tree_builder.gd | built in code, _mushroom with MUSHROOM_LOOKS[chanterelle] (lathe-turned stem and cap) | 2 | dome/cone/funnel/ball/bracket profiles from real species (comment; owner 2026-10-23 "plants must look like the real thing"); not seen rendered |
| Porcini | porcini, 0.1 to 0.25 m tall | data/tables/flora.json id 75 (porcini); built by src/flora/tree_builder.gd | built in code, _mushroom with MUSHROOM_LOOKS[porcini] (lathe-turned stem and cap) | 2 | dome/cone/funnel/ball/bracket profiles from real species (comment; owner 2026-10-23 "plants must look like the real thing"); not seen rendered |
| Morel | morel, 0.05 to 0.15 m tall | data/tables/flora.json id 76 (morel); built by src/flora/tree_builder.gd | built in code, _mushroom with MUSHROOM_LOOKS[morel] (lathe-turned stem and cap) | 2 | dome/cone/funnel/ball/bracket profiles from real species (comment; owner 2026-10-23 "plants must look like the real thing"); not seen rendered |
| Fly agaric | fly_agaric, 0.1 to 0.25 m tall | data/tables/flora.json id 77 (fly_agaric); built by src/flora/tree_builder.gd | built in code, _mushroom with MUSHROOM_LOOKS[fly_agaric] (lathe-turned stem and cap) | 2 | dome/cone/funnel/ball/bracket profiles from real species (comment; owner 2026-10-23 "plants must look like the real thing"); not seen rendered |
| Giant puffball | puffball, 0.15 to 0.4 m tall | data/tables/flora.json id 78 (puffball); built by src/flora/tree_builder.gd | built in code, _mushroom with MUSHROOM_LOOKS[puffball] (lathe-turned stem and cap) | 2 | dome/cone/funnel/ball/bracket profiles from real species (comment; owner 2026-10-23 "plants must look like the real thing"); not seen rendered |
| Tinder fungus | tinder_fungus, 0.15 to 0.3 m tall | data/tables/flora.json id 79 (tinder_fungus); built by src/flora/tree_builder.gd | built in code, _mushroom with MUSHROOM_LOOKS[tinder_fungus] (lathe-turned stem and cap) | 2 | dome/cone/funnel/ball/bracket profiles from real species (comment; owner 2026-10-23 "plants must look like the real thing"); not seen rendered |
| Rimecap | rimecap, 0.08 to 0.2 m tall fantasy species | data/tables/flora.json id 86 (rimecap); built by src/flora/tree_builder.gd | built in code, _mushroom with MUSHROOM_LOOKS[rimecap] (lathe-turned stem and cap) | 2 | dome/cone/funnel/ball/bracket profiles from real species (comment; owner 2026-10-23 "plants must look like the real thing"); not seen rendered [fantasy] |
| Lumencap | lumencap, 0.05 to 0.15 m tall fantasy species | data/tables/flora.json id 93 (lumencap); built by src/flora/tree_builder.gd | built in code, _mushroom with MUSHROOM_LOOKS[lumencap] (lathe-turned stem and cap) | 2 | dome/cone/funnel/ball/bracket profiles from real species (comment; owner 2026-10-23 "plants must look like the real thing"); not seen rendered [fantasy] |
| Cinderfoot | cinderfoot, 0.05 to 0.15 m tall fantasy species | data/tables/flora.json id 106 (cinderfoot); built by src/flora/tree_builder.gd | built in code, _mushroom with MUSHROOM_LOOKS[cinderfoot] (lathe-turned stem and cap) | 2 | dome/cone/funnel/ball/bracket profiles from real species (comment; owner 2026-10-23 "plants must look like the real thing"); not seen rendered [fantasy] |
| Mirrorcap | mirrorcap, 0.06 to 0.15 m tall fantasy species | data/tables/flora.json id 111 (mirrorcap); built by src/flora/tree_builder.gd | built in code, _mushroom with MUSHROOM_LOOKS[mirrorcap] (lathe-turned stem and cap) | 2 | dome/cone/funnel/ball/bracket profiles from real species (comment; owner 2026-10-23 "plants must look like the real thing"); not seen rendered [fantasy] |

## 6 Natural ground objects

48 entries. Stages: 32 x stage 2, 16 x stage 3.


### loose pickups (4)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Stone | A loose fist-sized stone | data/items/items.json item stone (#1) | inventory_view._natural_mesh picks one of 6 glb stones (assets/natural_pickups/); fallback RockLook (rock_look.gd, 56-triangle faceted lump); piles via pile_look.gd | 3 | 6 hand-made glb models with vertex colours (1280 triangles each, manifest) is the main look; code fallback is stage 2 |
| Stick | A fallen stick | data/items/items.json item stick (#2) | inventory_view._natural_mesh picks one of 3 glb sticks (assets/natural_pickups/stick_forest_*.glb); fallback _branch_mesh tapered bent tube | 3 | 3 glb models with vertex colours; code fallback is stage 2 |
| Driftwood | Bleached driftwood | data/items/items.json item driftwood (#30) | inventory_view._natural_mesh picks one of 3 glb driftwood pieces (assets/natural_pickups/driftwood_*.glb); fallback _branch_mesh | 3 | 3 glb models with vertex colours; code fallback is stage 2 |
| Log | A full-size log carried on the shoulder | data/items/items.json item log (#4) | inventory_view._mesh_for -> _branch_mesh (tapered bent 6-sided tube) in bark brown; shoulder carry via held_item.set_shoulder (plain cylinder) | 2 | primitive tapered tube; works, bark has no texture |

### imported model files (12)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| driftwood_01_bleached | imported glb pickup model (driftwood) | assets/natural_pickups/driftwood_01_bleached.glb | imported glb (glTF, metres, vertex colours, 1280 triangles per manifest) | 3 | imported hand-made model, vertex colours only; no PBR textures (assets/natural_pickups/README.md); not judged by render |
| driftwood_02_forked | imported glb pickup model (driftwood) | assets/natural_pickups/driftwood_02_forked.glb | imported glb (glTF, metres, vertex colours, 1280 triangles per manifest) | 3 | imported hand-made model, vertex colours only; no PBR textures (assets/natural_pickups/README.md); not judged by render |
| driftwood_03_long | imported glb pickup model (driftwood) | assets/natural_pickups/driftwood_03_long.glb | imported glb (glTF, metres, vertex colours, 1280 triangles per manifest) | 3 | imported hand-made model, vertex colours only; no PBR textures (assets/natural_pickups/README.md); not judged by render |
| stick_forest_01_twig | imported glb pickup model (stick) | assets/natural_pickups/stick_forest_01_twig.glb | imported glb (glTF, metres, vertex colours, 1280 triangles per manifest) | 3 | imported hand-made model, vertex colours only; no PBR textures (assets/natural_pickups/README.md); not judged by render |
| stick_forest_02_snap | imported glb pickup model (stick) | assets/natural_pickups/stick_forest_02_snap.glb | imported glb (glTF, metres, vertex colours, 1280 triangles per manifest) | 3 | imported hand-made model, vertex colours only; no PBR textures (assets/natural_pickups/README.md); not judged by render |
| stick_forest_03_crooked | imported glb pickup model (stick) | assets/natural_pickups/stick_forest_03_crooked.glb | imported glb (glTF, metres, vertex colours, 1280 triangles per manifest) | 3 | imported hand-made model, vertex colours only; no PBR textures (assets/natural_pickups/README.md); not judged by render |
| stone_rough_01_granite | imported glb pickup model (stone) | assets/natural_pickups/stone_rough_01_granite.glb | imported glb (glTF, metres, vertex colours, 1280 triangles per manifest) | 3 | imported hand-made model, vertex colours only; no PBR textures (assets/natural_pickups/README.md); not judged by render |
| stone_rough_02_slate | imported glb pickup model (stone) | assets/natural_pickups/stone_rough_02_slate.glb | imported glb (glTF, metres, vertex colours, 1280 triangles per manifest) | 3 | imported hand-made model, vertex colours only; no PBR textures (assets/natural_pickups/README.md); not judged by render |
| stone_rough_03_ochre | imported glb pickup model (stone) | assets/natural_pickups/stone_rough_03_ochre.glb | imported glb (glTF, metres, vertex colours, 1280 triangles per manifest) | 3 | imported hand-made model, vertex colours only; no PBR textures (assets/natural_pickups/README.md); not judged by render |
| stone_smooth_01_river_grey | imported glb pickup model (stone) | assets/natural_pickups/stone_smooth_01_river_grey.glb | imported glb (glTF, metres, vertex colours, 1280 triangles per manifest) | 3 | imported hand-made model, vertex colours only; no PBR textures (assets/natural_pickups/README.md); not judged by render |
| stone_smooth_02_tan_flat | imported glb pickup model (stone) | assets/natural_pickups/stone_smooth_02_tan_flat.glb | imported glb (glTF, metres, vertex colours, 1280 triangles per manifest) | 3 | imported hand-made model, vertex colours only; no PBR textures (assets/natural_pickups/README.md); not judged by render |
| stone_smooth_03_dark_oval | imported glb pickup model (stone) | assets/natural_pickups/stone_smooth_03_dark_oval.glb | imported glb (glTF, metres, vertex colours, 1280 triangles per manifest) | 3 | imported hand-made model, vertex colours only; no PBR textures (assets/natural_pickups/README.md); not judged by render |

### species logs (27)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Log workbench | Log of ? | data/items/items.json item log_workbench_kit (#85) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain |
| Log workbench | Log of ? | data/items/items.json item log_workbench (#86) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain |
| Oak logs | Log of oak | data/items/items.json item log_oak (#100) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [future] |
| Beech logs | Log of beech | data/items/items.json item log_beech (#103) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Birch logs | Log of birch | data/items/items.json item log_birch (#106) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [future] |
| Scots pine logs | Log of scots_pine | data/items/items.json item log_scots_pine (#109) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [future] |
| Spruce logs | Log of spruce | data/items/items.json item log_spruce (#112) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [future] |
| Alder logs | Log of alder | data/items/items.json item log_alder (#115) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Willow logs | Log of willow | data/items/items.json item log_willow (#118) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Coconut palm logs | Log of coconut_palm | data/items/items.json item log_coconut_palm (#121) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Tropical hardwood logs | Log of tropical_hardwood | data/items/items.json item log_tropical_hardwood (#124) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [future] |
| Acacia logs | Log of acacia | data/items/items.json item log_acacia (#127) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Mangrove logs | Log of mangrove | data/items/items.json item log_mangrove (#130) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Rowan logs | Log of rowan | data/items/items.json item log_rowan (#133) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Crab apple logs | Log of wild_apple | data/items/items.json item log_wild_apple (#136) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Wild pear logs | Log of wild_pear | data/items/items.json item log_wild_pear (#139) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Wild cherry logs | Log of wild_cherry | data/items/items.json item log_wild_cherry (#142) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Sweet chestnut logs | Log of sweet_chestnut | data/items/items.json item log_sweet_chestnut (#145) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Walnut logs | Log of walnut | data/items/items.json item log_walnut (#148) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [future] |
| Date palm logs | Log of date_palm | data/items/items.json item log_date_palm (#151) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Mirrorbark logs | Log of mirrorbark | data/items/items.json item log_mirrorbark (#154) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Wardpine logs | Log of wardpine | data/items/items.json item log_wardpine (#157) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Hearthwood logs | Log of hearthwood | data/items/items.json item log_hearthwood (#160) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Everember logs | Log of everember | data/items/items.json item log_everember (#163) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Witness tree logs | Log of witness_tree | data/items/items.json item log_witness_tree (#166) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Balsam fir logs | Log of balsam_fir | data/items/items.json item log_balsam_fir (#169) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [retired,future] |
| Sugar maple logs | Log of maple | data/items/items.json item log_maple (#172) | same _branch_mesh tube, colour from the tree's bark tint (log_look.gd) | 2 | tube plus species colour (log_look.gd comment); no per-species shape or end grain [future] |

### felled trees and stumps (1)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Felled trunk and stump | A tree cut by the axe: stump and falling trunk | src/client/inventory_view.gd _make_felled (line 894) | built in code (_make_felled): tapered bark cylinders plus pale cut faces with a darker core, branch stubs and root swell; trunk tilts over 1.5 s | 2 | redrawn from bare drums in this pass; compiled, not seen in game |

### boulders (1)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Boulder | Server-owned harvestable boulder (granite with moss on the top and north side) | src/client/grass_view.gd _make_boulder (line 569), BOULDER_SHADER; data/items/boulders.json | built in code (ArrayMesh) with a moss shader | 3 | ART_DIRECTION.md section 32, 42, 43, 49: reworked several times (mossy granite, moved to server objects); not seen rendered |

### rock piles (1)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Rock pile / pile of loose items | Pyramid of rocks for 6 or more loose bulk items | src/client/pile_look.gd; structures.json rock_pile (state 33) | built in code from RockLook lumps, count-driven pyramid | 2 | owner design 2026-10-23; simple stacked lumps |

### shore details (1)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Pebbles | Decorative shore pebbles (not pickable) | src/client/grass_view.gd layer "pebbles" (SCENERY_PEBBLES true) | built in code, instanced lumps | 2 | ART_DIRECTION.md section 26, 43, 44 |

### forest floor (1)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Dead branches | Thin weathered sticks lying under tree crowns | src/client/grass_view.gd BRANCH_SHADER, layer "branches" | built in code, shader-drawn thin sticks | 2 | ART_DIRECTION.md section 24 |

## 7 Grass cover, litter and painted textures

26 entries. Stages: 22 x stage 2, 4 x stage 3.


### ground texture layers (6)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| layer_0_turf.png | tiling 512 px ground texture layer | assets/ground/layer_0_turf.png | generated image (tools/make_ground_textures.py), loaded by ground_material.gd as one texture array | 2 | ART_DIRECTION.md section 7; generated tiling noise-based texture, not photographic |
| layer_1_litter.png | tiling 512 px ground texture layer | assets/ground/layer_1_litter.png | generated image (tools/make_ground_textures.py), loaded by ground_material.gd as one texture array | 2 | ART_DIRECTION.md section 7; generated tiling noise-based texture, not photographic |
| layer_2_gravel.png | tiling 512 px ground texture layer | assets/ground/layer_2_gravel.png | generated image (tools/make_ground_textures.py), loaded by ground_material.gd as one texture array | 2 | ART_DIRECTION.md section 7; generated tiling noise-based texture, not photographic |
| layer_3_mud.png | tiling 512 px ground texture layer | assets/ground/layer_3_mud.png | generated image (tools/make_ground_textures.py), loaded by ground_material.gd as one texture array | 2 | ART_DIRECTION.md section 7; generated tiling noise-based texture, not photographic |
| layer_4_sand.png | tiling 512 px ground texture layer | assets/ground/layer_4_sand.png | generated image (tools/make_ground_textures.py), loaded by ground_material.gd as one texture array | 2 | ART_DIRECTION.md section 7; generated tiling noise-based texture, not photographic |
| layer_5_rock.png | tiling 512 px ground texture layer | assets/ground/layer_5_rock.png | generated image (tools/make_ground_textures.py), loaded by ground_material.gd as one texture array | 2 | ART_DIRECTION.md section 7; generated tiling noise-based texture, not photographic |

### grass and litter textures (5)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| fern.png | fern frond card (fall_growth.gd) | assets/grass/fern.png | generated image (assets/grass/make_grass_textures.py) used on alpha cards in grass_view.gd | 2 | ART_DIRECTION.md sections 12, 14, 21, 33: painted blades redone several times; fern/litter textures simpler |
| grass_short.png | short grass blade card (grass_view layer short) | assets/grass/grass_short.png | generated image (assets/grass/make_grass_textures.py) used on alpha cards in grass_view.gd | 3 | ART_DIRECTION.md sections 12, 14, 21, 33: painted blades redone several times; fern/litter textures simpler |
| grass_tall.png | tall grass/reed card with seed heads (layers tall, reeds) | assets/grass/grass_tall.png | generated image (assets/grass/make_grass_textures.py) used on alpha cards in grass_view.gd | 3 | ART_DIRECTION.md sections 12, 14, 21, 33: painted blades redone several times; fern/litter textures simpler |
| ground_cover.png | flat ground-cover blade card (layer cover) | assets/grass/ground_cover.png | generated image (assets/grass/make_grass_textures.py) used on alpha cards in grass_view.gd | 3 | ART_DIRECTION.md sections 12, 14, 21, 33: painted blades redone several times; fern/litter textures simpler |
| litter.png | fallen leaf litter card (layer leaves) | assets/grass/litter.png | generated image (assets/grass/make_grass_textures.py) used on alpha cards in grass_view.gd | 2 | ART_DIRECTION.md sections 12, 14, 21, 33: painted blades redone several times; fern/litter textures simpler |

### grass layers (code) (3)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Grass cards: ground cover, short grass, tall grass | three layers of instanced crossed cards around the player | src/client/grass_view.gd LAYERS, SHADER (wind, trample, back-light) | built in code, shader cards in distance bands | 3 | ART_DIRECTION.md sections 12, 14, 21, 27, 28, 31, 33, 37, 39: the most iterated visual; sway, back-light, trampling (grass_trample.gd) |
| Forest litter leaf cards | fallen leaves under tree crowns | grass_view.gd layer "leaves" (litter.png) | built in code, flat cards | 2 | ART_DIRECTION.md section 24, 38 |
| Shore reeds | reeds where still water meets land | grass_view.gd layer "reeds" | built in code, tall-grass cards | 2 | ART_DIRECTION.md section 26 |

### tree textures (12)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| bark.png | furrowed bark (hardwood and conifer trunks, ember tree) | assets/trees/bark.png | generated image (assets/trees/make_tree_textures.py, tools/make_bark_textures.py), 128x256 | 2 | ART_DIRECTION.md section 13, 46: three bark textures only |
| bark_birch.png | white birch bark | assets/trees/bark_birch.png | generated image (assets/trees/make_tree_textures.py, tools/make_bark_textures.py), 128x256 | 2 | ART_DIRECTION.md section 13, 46: three bark textures only |
| bark_smooth.png | smooth grey bark (beech, rowan, alder...) | assets/trees/bark_smooth.png | generated image (assets/trees/make_tree_textures.py, tools/make_bark_textures.py), 128x256 | 2 | ART_DIRECTION.md section 13, 46: three bark textures only |
| leaf_broad.png | painted leaf card | assets/trees/leaf_broad.png | generated image on alpha-scissor cards (tree_builder.gd/flora_view.gd) | 2 | ART_DIRECTION.md sections 13, 46; cards read as clumps; not seen rendered |
| leaf_conifer.png | painted leaf card | assets/trees/leaf_conifer.png | generated image on alpha-scissor cards (tree_builder.gd/flora_view.gd) | 2 | ART_DIRECTION.md sections 13, 46; cards read as clumps; not seen rendered |
| leaf_maple.png | painted leaf card | assets/trees/leaf_maple.png | generated image on alpha-scissor cards (tree_builder.gd/flora_view.gd) | 2 | ART_DIRECTION.md sections 13, 46; cards read as clumps; not seen rendered |
| leaf_oak.png | painted leaf card | assets/trees/leaf_oak.png | generated image on alpha-scissor cards (tree_builder.gd/flora_view.gd) | 2 | ART_DIRECTION.md sections 13, 46; cards read as clumps; not seen rendered |
| leaf_palm.png | painted leaf card | assets/trees/leaf_palm.png | generated image on alpha-scissor cards (tree_builder.gd/flora_view.gd) | 2 | ART_DIRECTION.md sections 13, 46; cards read as clumps; not seen rendered |
| leaf_rowan.png | painted leaf card | assets/trees/leaf_rowan.png | generated image on alpha-scissor cards (tree_builder.gd/flora_view.gd) | 2 | ART_DIRECTION.md sections 13, 46; cards read as clumps; not seen rendered |
| leaf_willow.png | painted leaf card | assets/trees/leaf_willow.png | generated image on alpha-scissor cards (tree_builder.gd/flora_view.gd) | 2 | ART_DIRECTION.md sections 13, 46; cards read as clumps; not seen rendered |
| leaf_witness.png | painted leaf card | assets/trees/leaf_witness.png | generated image on alpha-scissor cards (tree_builder.gd/flora_view.gd) | 2 | ART_DIRECTION.md sections 13, 46; cards read as clumps; not seen rendered |
| twig_birch.png | birch winter twig curtain card | assets/trees/twig_birch.png | generated image on alpha-scissor cards (tree_builder.gd/flora_view.gd) | 2 | ART_DIRECTION.md sections 13, 46; cards read as clumps; not seen rendered |

## 8 Terrain surface and ground materials

109 entries. Stages: 81 x stage 0, 28 x stage 2.


### soils (17)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Bare rock | soil bare_rock, colour [0.45, 0.43, 0.4] | data/tables/soils.json id 0 | ground_material.gd shader: palette colour + texture layer layer_5_rock (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Sand | soil sand, colour [0.8, 0.74, 0.55] | data/tables/soils.json id 1 | ground_material.gd shader: palette colour + texture layer layer_4_sand (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Gravel | soil gravel, colour [0.55, 0.52, 0.48] | data/tables/soils.json id 2 | ground_material.gd shader: palette colour + texture layer layer_2_gravel (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Silt | soil silt, colour [0.46, 0.47, 0.3] | data/tables/soils.json id 3 | ground_material.gd shader: palette colour + texture layer layer_0_turf (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Clay | soil clay, colour [0.52, 0.42, 0.3] | data/tables/soils.json id 4 | ground_material.gd shader: palette colour + texture layer layer_3_mud (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Loam | soil loam, colour [0.32, 0.42, 0.2] | data/tables/soils.json id 5 | ground_material.gd shader: palette colour + texture layer layer_0_turf (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Peat | soil peat, colour [0.22, 0.18, 0.12] | data/tables/soils.json id 6 | ground_material.gd shader: palette colour + texture layer layer_1_litter (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Alluvium | soil alluvium, colour [0.34, 0.44, 0.22] | data/tables/soils.json id 7 | ground_material.gd shader: palette colour + texture layer layer_0_turf (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Forest humus | soil forest_humus, colour [0.25, 0.31, 0.16] | data/tables/soils.json id 8 | ground_material.gd shader: palette colour + texture layer layer_1_litter (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Stony soil | soil stony_soil, colour [0.45, 0.45, 0.35] | data/tables/soils.json id 9 | ground_material.gd shader: palette colour + texture layer layer_2_gravel (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Permafrost | soil permafrost, colour [0.52, 0.55, 0.5] | data/tables/soils.json id 10 | ground_material.gd shader: palette colour + texture layer layer_2_gravel (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Snow | soil snow, colour [0.92, 0.94, 0.96] | data/tables/soils.json id 11 | ground_material.gd shader: palette colour + texture layer layer_4_sand (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Glacial ice | soil glacial_ice, colour [0.75, 0.85, 0.92] | data/tables/soils.json id 12 | ground_material.gd shader: palette colour + texture layer layer_4_sand (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Salt flat | soil salt_flat, colour [0.9, 0.88, 0.82] | data/tables/soils.json id 13 | ground_material.gd shader: palette colour + texture layer layer_4_sand (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Volcanic ash | soil volcanic_ash, colour [0.3, 0.28, 0.27] | data/tables/soils.json id 14 | ground_material.gd shader: palette colour + texture layer layer_4_sand (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Beach sand | soil beach_sand, colour [0.86, 0.8, 0.6] | data/tables/soils.json id 15 | ground_material.gd shader: palette colour + texture layer layer_4_sand (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |
| Mud | soil mud, colour [0.3, 0.23, 0.15] | data/tables/soils.json id 16 | ground_material.gd shader: palette colour + texture layer layer_3_mud (assets/ground), steep faces darken to rock | 2 | flat palette colour plus a tiling generated texture (ART_DIRECTION.md section 7: checked only on a flat test patch) |

### rocks (12)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Air | not a visible material (empty space) | data/tables/rocks.json id 0 | none | 0 | air; nothing to draw [not visible] |
| Sediment | rock sediment, colour [0.5, 0.45, 0.35] | data/tables/rocks.json id 1 | ground_material.gd: palette colour + the one shared rock texture layer 5 ("every rock uses layer 5") | 2 | 11 rocks differ by colour only; no per-rock texture or strata detail |
| Shale | rock shale, colour [0.35, 0.35, 0.36] | data/tables/rocks.json id 2 | ground_material.gd: palette colour + the one shared rock texture layer 5 ("every rock uses layer 5") | 2 | 11 rocks differ by colour only; no per-rock texture or strata detail |
| Limestone | rock limestone, colour [0.78, 0.76, 0.7] | data/tables/rocks.json id 3 | ground_material.gd: palette colour + the one shared rock texture layer 5 ("every rock uses layer 5") | 2 | 11 rocks differ by colour only; no per-rock texture or strata detail |
| Coal | rock coal, colour [0.12, 0.12, 0.12] | data/tables/rocks.json id 4 | ground_material.gd: palette colour + the one shared rock texture layer 5 ("every rock uses layer 5") | 2 | 11 rocks differ by colour only; no per-rock texture or strata detail |
| Granite | rock granite, colour [0.62, 0.58, 0.56] | data/tables/rocks.json id 5 | ground_material.gd: palette colour + the one shared rock texture layer 5 ("every rock uses layer 5") | 2 | 11 rocks differ by colour only; no per-rock texture or strata detail |
| Slate | rock slate, colour [0.3, 0.32, 0.36] | data/tables/rocks.json id 6 | ground_material.gd: palette colour + the one shared rock texture layer 5 ("every rock uses layer 5") | 2 | 11 rocks differ by colour only; no per-rock texture or strata detail |
| Basalt | rock basalt, colour [0.22, 0.22, 0.23] | data/tables/rocks.json id 7 | ground_material.gd: palette colour + the one shared rock texture layer 5 ("every rock uses layer 5") | 2 | 11 rocks differ by colour only; no per-rock texture or strata detail |
| Sandstone | rock sandstone, colour [0.76, 0.62, 0.45] | data/tables/rocks.json id 8 | ground_material.gd: palette colour + the one shared rock texture layer 5 ("every rock uses layer 5") | 2 | 11 rocks differ by colour only; no per-rock texture or strata detail |
| Marble | rock marble, colour [0.9, 0.9, 0.88] | data/tables/rocks.json id 9 | ground_material.gd: palette colour + the one shared rock texture layer 5 ("every rock uses layer 5") | 2 | 11 rocks differ by colour only; no per-rock texture or strata detail |
| Chalk | rock chalk, colour [0.94, 0.94, 0.9] | data/tables/rocks.json id 10 | ground_material.gd: palette colour + the one shared rock texture layer 5 ("every rock uses layer 5") | 2 | 11 rocks differ by colour only; no per-rock texture or strata detail |
| Tuff | rock tuff, colour [0.6, 0.55, 0.48] | data/tables/rocks.json id 11 | ground_material.gd: palette colour + the one shared rock texture layer 5 ("every rock uses layer 5") | 2 | 11 rocks differ by colour only; no per-rock texture or strata detail |

### surficial deposits (8)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| None | surface deposit none | data/tables/surficial_deposits.json id 0 | no separate look found in src/client (unconfirmed: may follow the soil colour) | 0 | no client reference found by grep [unconfirmed] |
| Alluvium | surface deposit alluvium | data/tables/surficial_deposits.json id 1 | no separate look found in src/client (unconfirmed: may follow the soil colour) | 0 | no client reference found by grep [unconfirmed] |
| Gravel | surface deposit gravel | data/tables/surficial_deposits.json id 2 | no separate look found in src/client (unconfirmed: may follow the soil colour) | 0 | no client reference found by grep [unconfirmed] |
| Sand | surface deposit sand | data/tables/surficial_deposits.json id 3 | no separate look found in src/client (unconfirmed: may follow the soil colour) | 0 | no client reference found by grep [unconfirmed] |
| Silt | surface deposit silt | data/tables/surficial_deposits.json id 4 | no separate look found in src/client (unconfirmed: may follow the soil colour) | 0 | no client reference found by grep [unconfirmed] |
| Clay | surface deposit clay | data/tables/surficial_deposits.json id 5 | no separate look found in src/client (unconfirmed: may follow the soil colour) | 0 | no client reference found by grep [unconfirmed] |
| Lake sediment | surface deposit lake_sediment | data/tables/surficial_deposits.json id 6 | no separate look found in src/client (unconfirmed: may follow the soil colour) | 0 | no client reference found by grep [unconfirmed] |
| Peat | surface deposit peat | data/tables/surficial_deposits.json id 7 | no separate look found in src/client (unconfirmed: may follow the soil colour) | 0 | no client reference found by grep [unconfirmed] |

### ores and mineral resources (32)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| None | resource none (none) | data/tables/resources.json id 0 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [not visible] |
| Coal | resource coal (fuel) | data/tables/resources.json id 1 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Iron | resource iron (metal) | data/tables/resources.json id 2 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Copper | resource copper (metal) | data/tables/resources.json id 3 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Tin | resource tin (metal) | data/tables/resources.json id 4 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Lead | resource lead (metal) | data/tables/resources.json id 5 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Zinc | resource zinc (metal) | data/tables/resources.json id 6 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Nickel | resource nickel (metal) | data/tables/resources.json id 7 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Silver | resource silver (precious) | data/tables/resources.json id 8 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Gold | resource gold (precious) | data/tables/resources.json id 9 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Salt | resource salt (industrial) | data/tables/resources.json id 10 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Sulfur | resource sulfur (industrial) | data/tables/resources.json id 11 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Clay | resource clay (industrial) | data/tables/resources.json id 12 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Gypsum | resource gypsum (industrial) | data/tables/resources.json id 13 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Graphite | resource graphite (industrial) | data/tables/resources.json id 14 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Gemstone | resource gemstone (gem) | data/tables/resources.json id 15 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Peat | resource peat (surface) | data/tables/resources.json id 16 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Diamond | resource diamond (gem) | data/tables/resources.json id 17 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Ruby | resource ruby (gem) | data/tables/resources.json id 18 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Sapphire | resource sapphire (gem) | data/tables/resources.json id 19 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Emerald | resource emerald (gem) | data/tables/resources.json id 20 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Topaz | resource topaz (gem) | data/tables/resources.json id 21 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Aquamarine | resource aquamarine (gem) | data/tables/resources.json id 22 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Amethyst | resource amethyst (gem) | data/tables/resources.json id 23 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Agate | resource agate (gem) | data/tables/resources.json id 24 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Garnet | resource garnet (gem) | data/tables/resources.json id 25 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Opal | resource opal (gem) | data/tables/resources.json id 26 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Flint | resource flint (industrial) | data/tables/resources.json id 27 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Alum | resource alum (industrial) | data/tables/resources.json id 28 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Bitumen | resource bitumen (industrial) | data/tables/resources.json id 29 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Bog iron | resource bog_iron (metal) | data/tables/resources.json id 30 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |
| Saltpeter | resource saltpeter (industrial) | data/tables/resources.json id 31 | no ore/mineral model or texture found (only an item-table or geology meaning) | 0 | grep of src/client and ground_material.gd found no visual for resources [unconfirmed] |

### biomes (placement only) (19)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Ocean | biome ocean | data/tables/biomes.json id 0 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Beach | biome beach | data/tables/biomes.json id 1 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Hot desert | biome hot_desert | data/tables/biomes.json id 2 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Dry scrub | biome dry_scrub | data/tables/biomes.json id 3 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Savanna | biome savanna | data/tables/biomes.json id 4 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Tropical forest | biome tropical_forest | data/tables/biomes.json id 5 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Mangrove | biome mangrove | data/tables/biomes.json id 6 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Temperate grassland | biome temperate_grassland | data/tables/biomes.json id 7 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Temperate forest | biome temperate_forest | data/tables/biomes.json id 8 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Mixed forest | biome mixed_forest | data/tables/biomes.json id 9 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Marsh | biome marsh | data/tables/biomes.json id 10 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Heath | biome heath | data/tables/biomes.json id 11 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Boreal forest | biome boreal_forest | data/tables/biomes.json id 12 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Tundra | biome tundra | data/tables/biomes.json id 13 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Alpine meadow | biome alpine_meadow | data/tables/biomes.json id 14 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Bare rock | biome bare_rock | data/tables/biomes.json id 15 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Snowfield | biome snowfield | data/tables/biomes.json id 16 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Glacier | biome glacier | data/tables/biomes.json id 17 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |
| Volcanic waste | biome volcanic_waste | data/tables/biomes.json id 18 | no look of its own: biome only drives which flora/soil are placed | 0 | not a visible object [not visible] |

### geology features (placement only) (7)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Granite intrusion | geological feature intrusion | data/tables/feature_types.json id 0 | terrain shape only; no model | 0 | worldgen concept; no client asset [not visible] |
| Fault | geological feature fault | data/tables/feature_types.json id 1 | terrain shape only; no model | 0 | worldgen concept; no client asset [not visible] |
| Sedimentary basin | geological feature basin | data/tables/feature_types.json id 2 | terrain shape only; no model | 0 | worldgen concept; no client asset [not visible] |
| Fold belt | geological feature fold_belt | data/tables/feature_types.json id 3 | terrain shape only; no model | 0 | worldgen concept; no client asset [not visible] |
| Volcanic vent | geological feature volcanic_vent | data/tables/feature_types.json id 4 | terrain shape only; no model | 0 | worldgen concept; no client asset [not visible] |
| Volcanic pipe | geological feature volcanic_pipe | data/tables/feature_types.json id 5 | terrain shape only; no model | 0 | worldgen concept; no client asset [not visible] |
| Salt dome | geological feature salt_dome | data/tables/feature_types.json id 6 | terrain shape only; no model | 0 | worldgen concept; no client asset [not visible] |

### geology provinces (placement only) (4)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Granite province | province granite | data/tables/province_kinds.json id 0 | terrain shape only; no model | 0 | worldgen concept; no client asset [not visible] |
| Sedimentary basin province | province basin | data/tables/province_kinds.json id 1 | terrain shape only; no model | 0 | worldgen concept; no client asset [not visible] |
| Fold belt province | province fold_belt | data/tables/province_kinds.json id 2 | terrain shape only; no model | 0 | worldgen concept; no client asset [not visible] |
| Volcanic province | province volcanic | data/tables/province_kinds.json id 3 | terrain shape only; no model | 0 | worldgen concept; no client asset [not visible] |

### site types (landmarks, ruins, caves) (10)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Cave system | site type cave_system | data/tables/site_types.json id 0 | no client model found (grep of src/client for ruin/shipwreck/labyrinth/landmark found nothing) | 0 | site rows exist in the table; nothing draws them [unconfirmed] |
| Abandoned mineshaft | site type mineshaft | data/tables/site_types.json id 1 | no client model found (grep of src/client for ruin/shipwreck/labyrinth/landmark found nothing) | 0 | site rows exist in the table; nothing draws them [unconfirmed] |
| Labyrinth | site type labyrinth | data/tables/site_types.json id 2 | no client model found (grep of src/client for ruin/shipwreck/labyrinth/landmark found nothing) | 0 | site rows exist in the table; nothing draws them [unconfirmed] |
| Dormant lair | site type dormant_lair | data/tables/site_types.json id 3 | no client model found (grep of src/client for ruin/shipwreck/labyrinth/landmark found nothing) | 0 | site rows exist in the table; nothing draws them [unconfirmed] |
| Landmark | site type landmark | data/tables/site_types.json id 4 | no client model found (grep of src/client for ruin/shipwreck/labyrinth/landmark found nothing) | 0 | site rows exist in the table; nothing draws them [unconfirmed] |
| Natural harbor | site type harbor | data/tables/site_types.json id 5 | no client model found (grep of src/client for ruin/shipwreck/labyrinth/landmark found nothing) | 0 | site rows exist in the table; nothing draws them [unconfirmed] |
| Town site | site type town_site | data/tables/site_types.json id 6 | no client model found (grep of src/client for ruin/shipwreck/labyrinth/landmark found nothing) | 0 | site rows exist in the table; nothing draws them [unconfirmed] |
| Ruin | site type ruin | data/tables/site_types.json id 7 | no client model found (grep of src/client for ruin/shipwreck/labyrinth/landmark found nothing) | 0 | site rows exist in the table; nothing draws them [unconfirmed] |
| Shipwreck | site type shipwreck | data/tables/site_types.json id 8 | no client model found (grep of src/client for ruin/shipwreck/labyrinth/landmark found nothing) | 0 | site rows exist in the table; nothing draws them [unconfirmed] |
| Spawn point | site type spawn_point | data/tables/site_types.json id 9 | no client model found (grep of src/client for ruin/shipwreck/labyrinth/landmark found nothing) | 0 | site rows exist in the table; nothing draws them [unconfirmed] |

## 9 Water, sky, weather and light

24 entries. Stages: 2 x stage 0, 12 x stage 2, 10 x stage 3.


### water, sky, weather, light (18)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Sea | The ocean plane 12 km square | scenes/terrain_client/terrain_client.gd _make_environment; src/client/water_material.gd | PlaneMesh + one water shader (depth-based colour, reflection, ripples, storm murk, ice uniform) | 3 | ART_DIRECTION.md sections 15, 30, 50: clear-water pass, storm water, ice look |
| Rivers, lakes, ponds, brooks | Water sheets on the 8 m water grid | src/flora/flora_view.gd _draw_water; water_material.gd | built in code, same water shader as the sea | 3 | ART_DIRECTION.md sections 15, 40; owner 2026-10-19 asked for one look for all water |
| Waterfalls (ribbon) | Narrow ribbon along each steep drop plus a splash quad | src/worldgen/runtime/water_falls.gd; flora_view._draw_falls | built in code (one mesh per chunk) | 3 | owner reports 2026-10-20 (builds 232, 280): rewritten to columns |
| Waterfall curtain and base | Curtain look, wet dark rock and moss at the foot | ART_DIRECTION.md sections 23, 29; ground_material.gd set_falls | shader work on ground and falls | 3 | sections 23, 29 |
| Waterfall mist | Soft white spray cards at the foot | src/client/fall_mist.gd | built in code, GPUParticles3D alpha quads, 64/96/128/160 by quality | 2 | section 21 header comment; look-only |
| Fall ferns | Ferns on the banks around a fall | src/client/fall_growth.gd | built in code, fern cards (fern.png) | 2 | ART_DIRECTION.md section 25 |
| Ice on still water | Frost rim, patches, full sheet | water_material.gd ice uniform; flora_view._draw_ice; src/shared/ice.gd | shader state on the water | 3 | ART_DIRECTION.md section 50 |
| Ocean ice floes | Flat white slabs on the sea in cold weather | src/client/ocean_ice.gd; src/shared/ice_floes.gd | built in code with an ice shader: snow-dusted white top, blue shadow patches, glassy blue-green sides, cracks | 2 | the header comment still says plain white slab but ICE_SHADER implements the look; not seen in game |
| Sky dome, sun, moon, stars | Sky shader with sun disc, blue moon, stars, horizon haze | src/client/sky_clouds.gd (shader), src/client/day_cycle.gd | built in code, one sky shader | 3 | ART_DIRECTION.md sections 6, 50; sun path from latitude |
| Clouds | Drifting puffy clouds and high streaks | src/client/sky_clouds.gd | shader clouds on a layer 2 km up | 3 | owner 2026-10-19 asked for clouds; header comment |
| Sun light, fog, haze, tone mapping | Directional sun with shadows, sky ambient, fog, time-of-day colour | terrain_client._make_environment; weather_look.gd; look_settings.gd | Environment + DirectionalLight3D settings | 3 | ART_DIRECTION.md sections 2.1, 4, 6 |
| Rain streaks | Rain particles around the camera | src/client/weather_look.gd _make_rain | GPUParticles3D | 2 | ART_DIRECTION.md section 17, 30 |
| Snowfall and snow cover | Snowflakes and white level ground | weather_look.gd _make_snow; ground shader 'snow' uniform | GPUParticles3D + ground shader | 2 | section 17 |
| Lightning bolt and sky flash | Jagged ribbon bolt from cloud base, sky flash | weather_look.gd _make_bolt | built in code (ArrayMesh ribbon) | 2 | header comment; bolt from Medium up |
| Storm darkening and wet ground | Darker sky/sea and glossy wet ground in rain | weather_look.gd; ground_material.gd | shader uniforms | 3 | ART_DIRECTION.md section 30 |
| Wind cue specks | Pollen/petals/leaves/dust drifting downwind | src/client/wind_cue.gd | one GPUParticles3D | 3 | ART_DIRECTION.md section 53; rewritten in build 448 after the owner saw specks hover |
| Dripping ceilings | Drops under water-bearing cave ceilings | src/client/drip_view.gd | CPUParticles3D drops + darker wet floor | 2 | Dave 2026-10-23 request; header comment |
| Fish (in water) | Fish schools exist as server records; no fish model or swimming fish found | src/server/server_fish.gd; data/items/fish_schools.json | none: schools are computed records only | 0 | no client drawing found [unconfirmed] |

### water classes (table) (6)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| None | water class none | data/tables/water_classes.json id 0 | none | 0 | no water [not visible] |
| Ocean | water class ocean | data/tables/water_classes.json id 1 | all classes share the one water shader; no separate look found | 2 | table row only; drawn by the shared water material [unconfirmed] |
| Lake | water class lake | data/tables/water_classes.json id 2 | all classes share the one water shader; no separate look found | 2 | table row only; drawn by the shared water material [unconfirmed] |
| River | water class river | data/tables/water_classes.json id 3 | all classes share the one water shader; no separate look found | 2 | table row only; drawn by the shared water material [unconfirmed] |
| Marsh | water class marsh | data/tables/water_classes.json id 4 | all classes share the one water shader; no separate look found | 2 | table row only; drawn by the shared water material [unconfirmed] |
| Estuary | water class estuary | data/tables/water_classes.json id 5 | all classes share the one water shader; no separate look found | 2 | table row only; drawn by the shared water material [unconfirmed] |

## 10 Items: raw materials, wood and crafted parts

101 entries. Stages: 101 x stage 2.


### raw and crafted materials (36)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Plant fibre | Stringy plant fibre that can be twisted into twine or used as tinder. | data/items/items.json item plant_fibre (#3) | BasicLook.mesh_for -> shape "fibre" (data/items/looks.json), colour #c9bb7a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fibre" is 7 lines: a recognisable multi-part shape |
| Twine | Twisted plant fibre, strong enough to bind a tool or weave a chest. | data/items/items.json item twine (#5) | BasicLook.mesh_for -> shape "coil" (data/items/looks.json), colour #b8a46a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "coil" is 5 lines: a recognisable multi-part shape |
| Bark | Bark stripped from a felled trunk. | data/items/items.json item bark (#13) | BasicLook.mesh_for -> shape "bark" (data/items/looks.json), colour #5a4330; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bark" is 7 lines: a recognisable multi-part shape |
| Leaves | A handful of leaves. | data/items/items.json item leaves (#14) | BasicLook.mesh_for -> shape "leaves" (data/items/looks.json), colour #5a8a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "leaves" is 7 lines: a recognisable multi-part shape |
| Seeds | A small bundle of seeds that could be eaten or planted. | data/items/items.json item seed_bundle (#9) | BasicLook.mesh_for -> shape "sack" (data/items/looks.json), colour #a08a52; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "sack" is 7 lines: a recognisable multi-part shape |
| Roots | Roots from the base of a felled tree. | data/items/items.json item tree_roots (#18) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #6a4a2e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Firewood | Split wood that burns long and steady. | data/items/items.json item firewood (#26) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #8a5e36; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Iron ingot | A bar of smelted iron. Placeholder until smelting exists. | data/items/items.json item iron_ingot (#31) | BasicLook.mesh_for -> shape "ingot" (data/items/looks.json), colour #6c6f75; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "ingot" is 5 lines: a recognisable multi-part shape [future] |
| Steel ingot | A bar of steel. Placeholder until smelting exists. | data/items/items.json item steel_ingot (#32) | BasicLook.mesh_for -> shape "ingot" (data/items/looks.json), colour #9aa3ad; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "ingot" is 5 lines: a recognisable multi-part shape [future] |
| Soil | A shovelful of dark earth, dug from the ground. | data/items/items.json item soil (#35) | BasicLook.mesh_for -> shape "clump" (data/items/looks.json), colour #4a3322; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "clump" is 14 lines: a recognisable multi-part shape |
| Clay | A heavy, sticky shovelful of clay. | data/items/items.json item clay (#36) | BasicLook.mesh_for -> shape "clump" (data/items/looks.json), colour #a0603c; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "clump" is 14 lines: a recognisable multi-part shape |
| Sand | A shovelful of sand. | data/items/items.json item sand (#37) | BasicLook.mesh_for -> shape "grit" (data/items/looks.json), colour #d6c18b; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "grit" is 19 lines: a recognisable multi-part shape |
| Gravel | A shovelful of small stones and grit. | data/items/items.json item gravel (#38) | BasicLook.mesh_for -> shape "grit" (data/items/looks.json), colour #8d8a84; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "grit" is 19 lines: a recognisable multi-part shape |
| Hide | A raw animal skin. | data/items/items.json item hide (#43) | BasicLook.mesh_for -> shape "hide" (data/items/looks.json), colour #8a6a4a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "hide" is 10 lines: a recognisable multi-part shape [future] |
| Rope | Twisted twine, strong enough to haul and to lash a frame. | data/items/items.json item rope (#44) | BasicLook.mesh_for -> shape "coil" (data/items/looks.json), colour #a98f52; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "coil" is 5 lines: a recognisable multi-part shape |
| Bone | A cleaned animal bone. | data/items/items.json item bone (#48) | BasicLook.mesh_for -> shape "bone" (data/items/looks.json), colour #b3a98f; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bone" is 6 lines: a recognisable multi-part shape [future] |
| Rotten food | Food that has gone bad. Do not eat it. | data/items/items.json item rotten_food (#55) | BasicLook.mesh_for -> shape "pile" (data/items/looks.json), colour #4f5a2c; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "pile" is 9 lines: a recognisable multi-part shape |
| Sinew | Tough strands from an animal's legs. Strong sewing thread when dry. | data/items/items.json item sinew (#70) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #d0b898; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape [future] |
| Animal fat | White fat for torches, cooking and waterproofing. | data/items/items.json item animal_fat (#71) | BasicLook.mesh_for -> shape "chunk" (data/items/looks.json), colour #f1ead2; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "chunk" is 7 lines: a recognisable multi-part shape [future] |
| Feather | A feather for fletching and stuffing. | data/items/items.json item feather (#72) | BasicLook.mesh_for -> shape "feather" (data/items/looks.json), colour #b9b4a8; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "feather" is 7 lines: a recognisable multi-part shape [future] |
| Stone block | A squared block of stone, 40 by 20 by 20 cm. Heavy, and laid in courses with mortar. | data/items/items.json item cut_stone_block (#208) | BasicLook.mesh_for -> shape "block" (data/items/looks.json), colour #8a8780; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "block" is 7 lines: a recognisable multi-part shape |
| Brick | A fired clay brick, 22 by 10 by 7 cm. Laid in courses with mortar. | data/items/items.json item brick (#209) | BasicLook.mesh_for -> shape "brick" (data/items/looks.json), colour #a8452e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "brick" is 6 lines: a recognisable multi-part shape |
| Mortar | A bucketful of sand and clay paste that binds stone blocks and bricks. | data/items/items.json item mortar (#210) | BasicLook.mesh_for -> shape "pile" (data/items/looks.json), colour #a89c85; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "pile" is 9 lines: a recognisable multi-part shape |
| Rough plank | A plank split from a log: rough, smooth on one side, bark on the other. | data/items/items.json item rough_plank (#226) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #a8875a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape |
| Fine board | A smooth board planed from sawn lumber. For fine woodwork. | data/items/items.json item fine_board (#227) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #d4b57a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape |
| Nails | Iron nails, bought and used by the handful. | data/items/items.json item nails (#228) | BasicLook.mesh_for -> shape "needle" (data/items/looks.json), colour #5e6166; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "needle" is 5 lines: a recognisable multi-part shape |
| Cobblestone | A rounded stone, dressed to lay in a wall or a floor. | data/items/items.json item cobblestone (#229) | BasicLook.mesh_for -> shape "chunk" (data/items/looks.json), colour #8b8982; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "chunk" is 7 lines: a recognisable multi-part shape |
| Stone shingle | A thin flat slab of stone for a roof. | data/items/items.json item stone_shingle (#230) | BasicLook.mesh_for -> shape "chunk" (data/items/looks.json), colour #6d7076; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "chunk" is 7 lines: a recognisable multi-part shape |
| Tar | Thick black tar, boiled down. Seals a flat roof and soaks logs against rot. | data/items/items.json item tar (#231) | BasicLook.mesh_for -> shape "pile" (data/items/looks.json), colour #1c1814; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "pile" is 9 lines: a recognisable multi-part shape |
| Hinges | A pair of iron hinges for a door. | data/items/items.json item hinges (#232) | BasicLook.mesh_for -> shape "ingot" (data/items/looks.json), colour #4f5359; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "ingot" is 5 lines: a recognisable multi-part shape |
| Wooden pin | A hardwood pin or dowel that joins logs and beams without iron. | data/items/items.json item wooden_pin (#233) | BasicLook.mesh_for -> shape "rod" (data/items/looks.json), colour #a88255; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "rod" is 36 lines: a recognisable multi-part shape |
| Wooden block | A short round of log, about 30 cm long. Split it on a chopping block. | data/items/items.json item wooden_block (#234) | BasicLook.mesh_for -> shape "block" (data/items/looks.json), colour #a67c4a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "block" is 7 lines: a recognisable multi-part shape |
| Softwood firewood | Split pine, spruce or fir. It catches fast and burns out quick. | data/items/items.json item firewood_soft (#236) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #9a7a4a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Softwood block | A short round of pine, spruce or fir log, about 30 cm long. Split it on a chopping block. | data/items/items.json item wooden_block_soft (#237) | BasicLook.mesh_for -> shape "block" (data/items/looks.json), colour #b8905a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "block" is 7 lines: a recognisable multi-part shape |
| Saw blades | A pair of iron saw blades for a sawmill frame. | data/items/items.json item saw_blade (#238) | BasicLook.mesh_for -> shape "bar" (data/items/looks.json), colour #8f9296; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bar" is 6 lines: a recognisable multi-part shape [future] |
| Water wheel | A wooden wheel with paddles. It turns where running water pushes it. | data/items/items.json item water_wheel (#239) | BasicLook.mesh_for -> shape "coil" (data/items/looks.json), colour #7a5a36; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "coil" is 5 lines: a recognisable multi-part shape |

### wood: lumber and beams (51)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Lumber | Sawn boards. Needs a saw mill. | data/items/items.json item lumber (#27) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #b98d57; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape |
| Oak lumber | Sawn oak boards. | data/items/items.json item lumber_oak (#101) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #8a6a3d; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [future] |
| Oak beams | Heavy squared oak beams for building. | data/items/items.json item beam_oak (#102) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #8a6a3d; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [future] |
| Beech lumber | Sawn beech boards. | data/items/items.json item lumber_beech (#104) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #b79869; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Beech beams | Heavy squared beech beams for building. | data/items/items.json item beam_beech (#105) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #b79869; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Birch lumber | Sawn birch boards. | data/items/items.json item lumber_birch (#107) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #d9c7a3; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [future] |
| Birch beams | Heavy squared birch beams for building. | data/items/items.json item beam_birch (#108) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #d9c7a3; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [future] |
| Scots pine lumber | Sawn scots pine boards. | data/items/items.json item lumber_scots_pine (#110) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #c99a5b; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [future] |
| Scots pine beams | Heavy squared scots pine beams for building. | data/items/items.json item beam_scots_pine (#111) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #c99a5b; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [future] |
| Spruce lumber | Sawn spruce boards. | data/items/items.json item lumber_spruce (#113) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #d3b583; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [future] |
| Spruce beams | Heavy squared spruce beams for building. | data/items/items.json item beam_spruce (#114) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #d3b583; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [future] |
| Alder lumber | Sawn alder boards. | data/items/items.json item lumber_alder (#116) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #b5733f; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Alder beams | Heavy squared alder beams for building. | data/items/items.json item beam_alder (#117) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #b5733f; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Willow lumber | Sawn willow boards. | data/items/items.json item lumber_willow (#119) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #c9b486; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Willow beams | Heavy squared willow beams for building. | data/items/items.json item beam_willow (#120) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #c9b486; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Coconut palm lumber | Sawn coconut palm boards. | data/items/items.json item lumber_coconut_palm (#122) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #a98a5a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Coconut palm beams | Heavy squared coconut palm beams for building. | data/items/items.json item beam_coconut_palm (#123) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #a98a5a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Tropical hardwood lumber | Sawn tropical hardwood boards. | data/items/items.json item lumber_tropical_hardwood (#125) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #6b3f27; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [future] |
| Tropical hardwood beams | Heavy squared tropical hardwood beams for building. | data/items/items.json item beam_tropical_hardwood (#126) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #6b3f27; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [future] |
| Acacia lumber | Sawn acacia boards. | data/items/items.json item lumber_acacia (#128) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #9a6a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Acacia beams | Heavy squared acacia beams for building. | data/items/items.json item beam_acacia (#129) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #9a6a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Mangrove lumber | Sawn mangrove boards. | data/items/items.json item lumber_mangrove (#131) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #7a4a2c; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Mangrove beams | Heavy squared mangrove beams for building. | data/items/items.json item beam_mangrove (#132) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #7a4a2c; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Rowan lumber | Sawn rowan boards. | data/items/items.json item lumber_rowan (#134) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #c08e63; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Rowan beams | Heavy squared rowan beams for building. | data/items/items.json item beam_rowan (#135) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #c08e63; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Crab apple lumber | Sawn crab apple boards. | data/items/items.json item lumber_wild_apple (#137) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #b47f55; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Crab apple beams | Heavy squared crab apple beams for building. | data/items/items.json item beam_wild_apple (#138) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #b47f55; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Wild pear lumber | Sawn wild pear boards. | data/items/items.json item lumber_wild_pear (#140) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #c4936a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Wild pear beams | Heavy squared wild pear beams for building. | data/items/items.json item beam_wild_pear (#141) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #c4936a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Wild cherry lumber | Sawn wild cherry boards. | data/items/items.json item lumber_wild_cherry (#143) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #a85a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Wild cherry beams | Heavy squared wild cherry beams for building. | data/items/items.json item beam_wild_cherry (#144) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #a85a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Sweet chestnut lumber | Sawn sweet chestnut boards. | data/items/items.json item lumber_sweet_chestnut (#146) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #a67b45; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Sweet chestnut beams | Heavy squared sweet chestnut beams for building. | data/items/items.json item beam_sweet_chestnut (#147) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #a67b45; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Walnut lumber | Sawn walnut boards. | data/items/items.json item lumber_walnut (#149) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #5c3b24; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [future] |
| Walnut beams | Heavy squared walnut beams for building. | data/items/items.json item beam_walnut (#150) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #5c3b24; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [future] |
| Date palm lumber | Sawn date palm boards. | data/items/items.json item lumber_date_palm (#152) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #b39465; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Date palm beams | Heavy squared date palm beams for building. | data/items/items.json item beam_date_palm (#153) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #b39465; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Mirrorbark lumber | Sawn mirrorbark boards. | data/items/items.json item lumber_mirrorbark (#155) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #9fa6a8; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Mirrorbark beams | Heavy squared mirrorbark beams for building. | data/items/items.json item beam_mirrorbark (#156) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #9fa6a8; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Wardpine lumber | Sawn wardpine boards. | data/items/items.json item lumber_wardpine (#158) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #8f7a4f; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Wardpine beams | Heavy squared wardpine beams for building. | data/items/items.json item beam_wardpine (#159) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #8f7a4f; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Hearthwood lumber | Sawn hearthwood boards. | data/items/items.json item lumber_hearthwood (#161) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #a0452b; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Hearthwood beams | Heavy squared hearthwood beams for building. | data/items/items.json item beam_hearthwood (#162) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #a0452b; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Everember lumber | Sawn everember boards. | data/items/items.json item lumber_everember (#164) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #c4683a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Everember beams | Heavy squared everember beams for building. | data/items/items.json item beam_everember (#165) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #c4683a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Witness tree lumber | Sawn witness tree boards. | data/items/items.json item lumber_witness_tree (#167) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #7b6a56; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Witness tree beams | Heavy squared witness tree beams for building. | data/items/items.json item beam_witness_tree (#168) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #7b6a56; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Balsam fir lumber | Sawn balsam fir boards. | data/items/items.json item lumber_balsam_fir (#170) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #cdb78b; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [retired,future] |
| Balsam fir beams | Heavy squared balsam fir beams for building. | data/items/items.json item beam_balsam_fir (#171) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #cdb78b; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [retired,future] |
| Sugar maple lumber | Sawn sugar maple boards. | data/items/items.json item lumber_maple (#173) | BasicLook.mesh_for -> shape "planks" (data/items/looks.json), colour #d0a46f; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "planks" is 9 lines: a recognisable multi-part shape [future] |
| Sugar maple beams | Heavy squared sugar maple beams for building. | data/items/items.json item beam_maple (#174) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #d0a46f; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape [future] |

### requested by Sal (future items, branch sal-items) (14)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Flint | item #279, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #279 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "flint" (used while looks.json still holds the grey chunk) | 2 | new shape: waxy dark nodule with pale rind and chip scars (offline render checked) [future] |
| Pyrite | item #280, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #280 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "pyrite" (used while looks.json still holds the grey chunk) | 2 | new shape: cluster of brass cubes (offline render checked) [future] |
| Obsidian | item #281, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #281 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "obsidian" (used while looks.json still holds the grey chunk) | 2 | new shape: black angular glassy shard (offline render checked) [future] |
| Processed hide | item #282, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #282 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "leather" (used while looks.json still holds the grey chunk) | 2 | shared leather shape, pale colour [future] |
| Leather | item #283, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #283 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "leather" (used while looks.json still holds the grey chunk) | 2 | shared leather shape, brown [future] |
| Fine leather | item #284, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #284 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "leather" (used while looks.json still holds the grey chunk) | 2 | leather shape with thin sheet, lighter colour [future] |
| Heavy leather | item #285, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #285 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "leather" (used while looks.json still holds the grey chunk) | 2 | leather shape with thick slab, dark [future] |
| Rivets | item #286, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #286 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "rivets" (used while looks.json still holds the grey chunk) | 2 | new shape: pile of iron pins with round heads [future] |
| Copper ingot | item #287, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #287 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "ingot" (used while looks.json still holds the grey chunk) | 2 | ingot shape, copper colour [future] |
| Tin ingot | item #288, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #288 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "ingot" (used while looks.json still holds the grey chunk) | 2 | ingot shape, grey [future] |
| Bronze ingot | item #289, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #289 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "ingot" (used while looks.json still holds the grey chunk) | 2 | ingot shape, golden brown [future] |
| Flour | item #290, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #290 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "sack" (used while looks.json still holds the grey chunk) | 2 | sack shape, pale [future] |
| Salt | item #292, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #292 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "grit" (used while looks.json still holds the grey chunk) | 2 | grit pile, white [future] |
| Yeast | item #291, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #291 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "pot" (used while looks.json still holds the grey chunk) | 2 | small pale crock (the pot shape at half size), offline render checked [future] |

## 11 Items: gathered plant parts and foraged goods

174 entries. Stages: 169 x stage 2, 5 x stage 3.


### gathered: nut (7)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Acorns | Oak nuts, bitter raw. Soaked and mashed they make a poor but filling food. | data/items/gathered.json item acorns (#1000) | BasicLook.mesh_for -> shape "nut" (data/items/looks.json), colour #8a6a34; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "nut" is 6 lines: a recognisable multi-part shape |
| Beechnuts | Small three-sided beech nuts in prickly husks. Eaten roasted or pressed for oil. | data/items/gathered.json item beechnuts (#1010) | BasicLook.mesh_for -> shape "nut" (data/items/looks.json), colour #7a5028; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "nut" is 6 lines: a recognisable multi-part shape |
| Chestnuts | Glossy brown nuts in spiny husks. Roasted, they are sweet and starchy. | data/items/gathered.json item chestnuts (#1025) | BasicLook.mesh_for -> shape "nut" (data/items/looks.json), colour #6a3a1c; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "nut" is 6 lines: a recognisable multi-part shape |
| Coconuts | A heavy husked nut with sweet water inside. Crack it open to drink. | data/items/gathered.json item coconuts (#1028) | BasicLook.mesh_for -> shape "nut" (data/items/looks.json), colour #5a3c22; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "nut" is 6 lines: a recognisable multi-part shape |
| Hazelnuts | Round hard-shelled nuts. Crack and eat; they keep well. | data/items/gathered.json item hazelnuts (#1069) | BasicLook.mesh_for -> shape "nut" (data/items/looks.json), colour #b8864a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "nut" is 6 lines: a recognisable multi-part shape |
| Walnut husks | Green-black husks of the walnut. Stain the hands brown; used as dye. | data/items/gathered.json item walnut_husks (#1157) | BasicLook.mesh_for -> shape "nut" (data/items/looks.json), colour #4f7a32; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "nut" is 6 lines: a recognisable multi-part shape |
| Walnuts | Wrinkled walnut kernels in hard shells. Rich and oily; keep well. | data/items/gathered.json item walnuts (#1158) | BasicLook.mesh_for -> shape "nut" (data/items/looks.json), colour #8a6a44; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "nut" is 6 lines: a recognisable multi-part shape |

### gathered: bowl (2)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Aloe gel | Cool clear gel from a split aloe leaf. Soothes burns and sun-reddened skin. | data/items/gathered.json item aloe_gel (#1001) | BasicLook.mesh_for -> shape "bowl" (data/items/looks.json), colour #a8e0a0; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | wooden bowl built from helper shapes (frustum, rim ring, base) with a surface and chunky bits for stews; seen in an offline render: reads as a bowl of food |
| Food | Plain edible things gathered in the wild. Eat to stay on your feet. | data/items/gathered.json item food (#1055) | BasicLook.mesh_for -> shape "bowl" (data/items/looks.json), colour #c9a05a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | wooden bowl built from helper shapes (frustum, rim ring, base) with a surface and chunky bits for stews; seen in an offline render: reads as a bowl of food |

### gathered: chunk (8)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Amadou | Soft felt peeled from a tinder fungus. Dried, it takes a spark and holds an ember. | data/items/gathered.json item amadou (#1002) | BasicLook.mesh_for -> shape "chunk" (data/items/looks.json), colour #a8825a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "chunk" is 7 lines: a recognisable multi-part shape |
| Burrs | Hooked seed heads of burdock that cling to cloth and fur. Pests, and a kind of fastener. | data/items/gathered.json item burrs (#1018) | BasicLook.mesh_for -> shape "chunk" (data/items/looks.json), colour #7a5a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "chunk" is 7 lines: a recognisable multi-part shape |
| Cactus pads | Flat fleshy cactus pads, spines still on. Peeled and cooked they make food and water. | data/items/gathered.json item cactus_pads (#1019) | BasicLook.mesh_for -> shape "chunk" (data/items/looks.json), colour #4f8a4a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "chunk" is 7 lines: a recognisable multi-part shape |
| Charcoal wood | Alder wood fit for burning down to charcoal. Hotter and cleaner than a wood fire. | data/items/gathered.json item charcoal_wood (#1022) | BasicLook.mesh_for -> shape "chunk" (data/items/looks.json), colour #2a2826; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "chunk" is 7 lines: a recognisable multi-part shape |
| Gum | Sticky tree gum, hardened in lumps. Chewed, or used as glue. | data/items/gathered.json item gum (#1062) | BasicLook.mesh_for -> shape "chunk" (data/items/looks.json), colour #c9a05a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "chunk" is 7 lines: a recognisable multi-part shape |
| Resin | Sticky sap from conifers, hardened into amber lumps. Burns hot, seals wood, and sticks things. | data/items/gathered.json item resin (#1115) | BasicLook.mesh_for -> shape "chunk" (data/items/looks.json), colour #c98a2a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "chunk" is 7 lines: a recognisable multi-part shape |
| Tinder fungus | A woody hoof-shaped fungus. Its inner flesh takes a spark. | data/items/gathered.json item tinder_fungus (#1154) | BasicLook.mesh_for -> shape "chunk" (data/items/looks.json), colour #8a7a5a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "chunk" is 7 lines: a recognisable multi-part shape |
| Wardpine resin | Sweet clean resin of the wardpine, believed to keep ill luck away. | data/items/gathered.json item wardpine_resin (#1159) | BasicLook.mesh_for -> shape "chunk" (data/items/looks.json), colour #7a9a5a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "chunk" is 7 lines: a recognisable multi-part shape |

### gathered: root (13)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Angelica roots | A thick aromatic root of angelica. Chewed or steeped as a warming remedy. | data/items/gathered.json item angelica_roots (#1003) | BasicLook.mesh_for -> shape "root" (data/items/looks.json), colour #d8c9a0; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "root" is 10 lines: a recognisable multi-part shape |
| Burdock roots | A long dark taproot, earthy and sweet when cooked. Dug from disturbed ground. | data/items/gathered.json item burdock_roots (#1017) | BasicLook.mesh_for -> shape "root" (data/items/looks.json), colour #6a4a30; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "root" is 10 lines: a recognisable multi-part shape |
| Comfrey roots | A thick black root of comfrey, mucky and slimy inside. Used for poultices; not for eating. | data/items/gathered.json item comfrey_roots (#1030) | BasicLook.mesh_for -> shape "root" (data/items/looks.json), colour #3a2a20; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "root" is 10 lines: a recognisable multi-part shape |
| Dandelion roots | A long pale taproot, bitter. Roasted and ground as a coffee, or boiled. | data/items/gathered.json item dandelion_roots (#1036) | BasicLook.mesh_for -> shape "root" (data/items/looks.json), colour #8a6a48; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "root" is 10 lines: a recognisable multi-part shape |
| Duskmallow roots | Pale roots of duskmallow, slimy when boiled. Soothes a sore throat. | data/items/gathered.json item duskmallow_roots (#1040) | BasicLook.mesh_for -> shape "root" (data/items/looks.json), colour #7a5a8a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "root" is 10 lines: a recognisable multi-part shape |
| Emberroots | Red-brown roots that stay warm to the touch. Said to be good fuel and a hot spice. | data/items/gathered.json item emberroots (#1045) | BasicLook.mesh_for -> shape "root" (data/items/looks.json), colour #d4501e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "root" is 10 lines: a recognisable multi-part shape |
| Heartroots | Red knotted roots shaped like fists. A hardy food and a warming remedy. | data/items/gathered.json item heartroots (#1071) | BasicLook.mesh_for -> shape "root" (data/items/looks.json), colour #b02a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "root" is 10 lines: a recognisable multi-part shape |
| Marrowroots | Fat pale roots as thick as a wrist. Cooked, they are soft and filling. | data/items/gathered.json item marrowroots (#1088) | BasicLook.mesh_for -> shape "root" (data/items/looks.json), colour #e8dcc0; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "root" is 10 lines: a recognisable multi-part shape |
| Sevenyear bulbs | A pale bulb of the sevenyear lily. Said to wait years for its season. | data/items/gathered.json item sevenyear_bulbs (#1128) | BasicLook.mesh_for -> shape "root" (data/items/looks.json), colour #d8b080; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "root" is 10 lines: a recognisable multi-part shape |
| Valerian roots | Strong-smelling pale roots. Steeped to calm the nerves and help sleep. | data/items/gathered.json item valerian_roots (#1156) | BasicLook.mesh_for -> shape "root" (data/items/looks.json), colour #9a7a50; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "root" is 10 lines: a recognisable multi-part shape |
| Wild carrot roots | Thin pale roots of wild carrot, tough but sweet. Cooked or chewed raw. | data/items/gathered.json item wild_carrot_roots (#1164) | BasicLook.mesh_for -> shape "root" (data/items/looks.json), colour #f0e0d0; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "root" is 10 lines: a recognisable multi-part shape |
| Wild garlic bulbs | Small white bulbs with a sharp smell. Flavour any dish. | data/items/gathered.json item wild_garlic_bulbs (#1165) | BasicLook.mesh_for -> shape "root" (data/items/looks.json), colour #efe7d8; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "root" is 10 lines: a recognisable multi-part shape |
| Wolfsbane roots | Dark turnip-like roots of wolfsbane. Poisonous: do not eat. | data/items/gathered.json item wolfsbane_roots (#1173) | BasicLook.mesh_for -> shape "root" (data/items/looks.json), colour #5a4a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "root" is 10 lines: a recognisable multi-part shape |

### gathered: bundle (18)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Angelica stems | Hollow green stems of angelica, sweet and sharp. Eaten fresh or candied. | data/items/gathered.json item angelica_stems (#1004) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #9ab45a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Bedding | Soft dry stuff to lie on. A bed is stuffed with it. | data/items/gathered.json item bedding (#1009) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #c9b46a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Fibre | Tough plant strands. Twisted into twine. | data/items/gathered.json item fibre (#1050) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #c9bb7a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Fodder | Coarse leaves and twigs that animals will eat. No good for people. | data/items/gathered.json item fodder (#1054) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #b8a85a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Hagwillow withies | Springy shoots of the hag willow. Woven into baskets and fences. | data/items/gathered.json item hagwillow_withies (#1064) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #6a5a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Hearthwood logs | Heavy logs of the hearthwood tree, said to burn all night and never spit. | data/items/gathered.json item hearthwood_logs (#1070) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #a0452b; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Honeyspindle pods | Slim pods of the honeyspindle, full of sweet seed. Good to chew. | data/items/gathered.json item honeyspindle_pods (#1077) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #b8a050; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Kindling | Thin dry twigs and shavings that catch quickly. The start of any fire. | data/items/gathered.json item kindling (#1080) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #a8845a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Poles | Long straight shoots cut for fencing and frames. Strong and light. | data/items/gathered.json item poles (#1106) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #8a6a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Reed stems | Long hollow stems of reed. Woven or bundled. | data/items/gathered.json item reed_stems (#1114) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #b8a860; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Riverbraid stems | Long flexible stems of a river plant, easily plaited into rope and baskets. | data/items/gathered.json item riverbraid_stems (#1117) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #6a9a8a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Spines | Long sharp cactus spines. Used as needles and pins. | data/items/gathered.json item spines (#1133) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #6a5a44; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Stormreed stalks | Tough hollow stalks of a reed that sings in a gale. Strong and flexible. | data/items/gathered.json item stormreed_stalks (#1138) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #8a8a6a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Straw | Dry grass stalks. Good for bedding and thatch. | data/items/gathered.json item straw (#1139) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #d8c070; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Tanglewort vines | Long wiry vines that snare ankles. Strong cord when stripped and twisted. | data/items/gathered.json item tanglewort_vines (#1144) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #4f7a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Thatch | Dried grass, reed or bark in bundles. Roofs and walls are made of it. | data/items/gathered.json item thatch (#1146) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #c4a860; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Thorny canes | Long thorny bramble canes. Used for fencing and snares. | data/items/gathered.json item thorny_canes (#1147) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #4a3322; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Withies | Long thin willow shoots. Woven into baskets and hurdles. | data/items/gathered.json item withies (#1170) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #9a8a52; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |

### gathered: flower (24)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Arnica flowers | Bright yellow mountain daisies. Their salve eases bruises; never eat them. | data/items/gathered.json item arnica_flowers (#1005) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #f2b01e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Brinebells | Salt-loving shore flowers that ring like little bells. Chewed, they taste of the sea. | data/items/gathered.json item brinebells (#1016) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #6aa0d8; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Chamomile flowers | Small white daisies with yellow centres. A calming tea. | data/items/gathered.json item chamomile_flowers (#1020) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #f4f1e6; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Dandelion flowers | Bright yellow flower heads. Fried or steeped for tea. | data/items/gathered.json item dandelion_flowers (#1034) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #f7d117; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Duskmallow flowers | Soft violet blooms that open at dusk. Their scent is calming. | data/items/gathered.json item duskmallow_flowers (#1039) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #7a4aa8; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Elderflowers | Creamy lacy flower sprays with a sweet musky smell. Steeped as a cordial. | data/items/gathered.json item elderflowers (#1044) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #f1ecd8; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Feverfew | Small daisy-like flowers with bitter leaves. A headache remedy. | data/items/gathered.json item feverfew (#1049) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #f1efe2; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Frostglass petals | Clear glassy petals of an orchid that grows on the frozen slopes. Brittle and cold to touch. | data/items/gathered.json item frostglass_petals (#1057) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #bfe6f2; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Gloaming star | A pale star-shaped flower that glows faintly at dusk. Picked, it fades by morning. | data/items/gathered.json item gloaming_star (#1058) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #e8e0ff; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Gloomthistle heads | Spiny dark thistle heads. Handle with gloves. | data/items/gathered.json item gloomthistle_heads (#1060) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #6a3a7a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Hawthorn blossom | White spring blossom of the hawthorn, sweet and faintly rank. A mild heart tonic. | data/items/gathered.json item hawthorn_blossom (#1068) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #f7ece8; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Honey flowers | Heather flowers heavy with nectar. Bees love them; so does a good honey. | data/items/gathered.json item honey_flowers (#1075) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #f0c24a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Lavender flowers | Purple flower spikes with a clean scent. Dried they sweeten linen. | data/items/gathered.json item lavender_flowers (#1082) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #8f77c4; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Meadowsweet flowers | Frothy cream flowers smelling of honey and almonds. A mild remedy for aches. | data/items/gathered.json item meadowsweet_flowers (#1089) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #f1e8c6; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Mournbloom petals | Dark petals of the mournbloom, grown over old graves. Not for eating. | data/items/gathered.json item mournbloom_petals (#1095) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #3a2a4a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Nightcrown blooms | Large pale flowers that open only at night. Scent heavy and sweet. | data/items/gathered.json item nightcrown_blooms (#1097) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #3a2e6a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Owlpetals | Round pale petals marked like eyes. Said to help one see in the dark. | data/items/gathered.json item owlpetals (#1099) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #c9b8d8; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Quenchbell heads | Blue bell-shaped flower heads holding a mouthful of sweet water. | data/items/gathered.json item quenchbell_heads (#1111) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #4a7ad0; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Rose petals | Soft pink wild rose petals. Scent a room or steep in water. | data/items/gathered.json item rose_petals (#1119) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #d4476a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Sevenyear blossoms | Rare white lily blooms, they flower once in seven years. Treasured. | data/items/gathered.json item sevenyear_blossoms (#1127) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #e9a3c2; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| St johns wort | Yellow star flowers with dotted leaves. Steeped for a gentle remedy. | data/items/gathered.json item st_johns_wort (#1134) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #f2d11a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Stillwater petals | Pale petals of the stillwater lotus. Float on calm pools. | data/items/gathered.json item stillwater_petals (#1136) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #7ec8d9; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Wispbloom heads | Light seed heads that float away at a breath. Drifts on the wind. | data/items/gathered.json item wispbloom_heads (#1169) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #a8f0e0; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |
| Yarrow | Feathery leaves and flat white flower heads. Packed on a wound to slow bleeding. | data/items/gathered.json item yarrow (#1175) | BasicLook.mesh_for -> shape "flower" (data/items/looks.json), colour #f1efe2; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "flower" is 11 lines: a recognisable multi-part shape |

### gathered: frond (29)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Banana leaves | Broad glossy leaves of the wild banana. Good for wrapping food and shelter roofs. | data/items/gathered.json item banana_leaves (#1006) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #3f8a2a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Belladonna leaves | Dull green leaves of deadly nightshade. Poisonous: a healer's herb at best. | data/items/gathered.json item belladonna_leaves (#1012) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #4a7a30; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Comfrey leaves | Rough hairy leaves of comfrey. Bruised and bound on sprains as a poultice. | data/items/gathered.json item comfrey_leaves (#1029) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #4d7a35; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Dandelion leaves | Bitter toothed leaves. Eaten as a spring salad or boiled. | data/items/gathered.json item dandelion_leaves (#1035) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #5a9a35; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Everember needles | Needles of the everember tree, dark green and resinous. They smoulder rather than burn. | data/items/gathered.json item everember_needles (#1046) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #c4683a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Fiddleheads | Tightly curled young fern fronds. Cooked, they taste green and nutty. | data/items/gathered.json item fiddleheads (#1051) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #6a9a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Foxglove leaves | Soft downy leaves of foxglove. Poisonous: a heart medicine in the right hands. | data/items/gathered.json item foxglove_leaves (#1056) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #4f8a45; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Greens | Mixed wild leaves, nettle and the like. Boiled they are a plain green food. | data/items/gathered.json item greens (#1061) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #4f9a30; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Henbane leaves | Sticky hairy leaves of henbane. Poisonous: do not eat. | data/items/gathered.json item henbane_leaves (#1072) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #6b8a45; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Herbs | A bundle of mixed wild herbs. Flavours food. | data/items/gathered.json item herbs (#1074) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #6a8a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Hushfern fronds | Soft grey fronds that deaden footfalls. Poisonous: do not eat. | data/items/gathered.json item hushfern_fronds (#1078) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #3a7a4a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Marjoram | A sweet herb with oval leaves. Flavours meat and stews. | data/items/gathered.json item marjoram (#1087) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #6f8f4a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Mint | Fresh green leaves with a cool sharp scent. Flavours food and tea. | data/items/gathered.json item mint (#1090) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #4f9a45; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Mugwort | Grey-green leaves with a bitter smell. A hardy herb, steeped or burned. | data/items/gathered.json item mugwort (#1096) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #7a8a6a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Palm fronds | Long woody fronds. Woven into mats and roofs. | data/items/gathered.json item palm_fronds (#1100) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #3f8a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Plantain leaves | Broad ribbed leaves of the common plantain. Chewed and applied to stings and cuts. | data/items/gathered.json item plantain_leaves (#1105) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #4f8f3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Raspberry leaves | Toothed leaves of the raspberry cane. Steeped as a soothing tea. | data/items/gathered.json item raspberry_leaves (#1113) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #5a8a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Rosemary | A woody herb with narrow needle-like leaves and a strong resinous scent. | data/items/gathered.json item rosemary (#1120) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #4a6a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Sage | Soft grey-green leaves with a musky scent. Flavours meat and a remedy for sore throats. | data/items/gathered.json item sage (#1122) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #8a9a7a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Samphire | Crisp salty green shoots of the shore. Eaten fresh, or pickled. | data/items/gathered.json item samphire (#1123) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #5a9a5a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Sorrel leaves | Sharp lemony arrow-shaped leaves. Eaten fresh or cooked into soup. | data/items/gathered.json item sorrel_leaves (#1132) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #6aa03a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Sunsilver leaves | Silvery leaves of a vine that catch the sun. Said to be a good tonic. | data/items/gathered.json item sunsilver_leaves (#1143) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #c4ccd4; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Thyme | A small tough herb with tiny leaves. A fine flavour for meat and fish. | data/items/gathered.json item thyme (#1149) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #6a7a4a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Tideglass fronds | Clear glassy sea fronds found at the tide line. Brittle; dry to a salt crust. | data/items/gathered.json item tideglass_fronds (#1151) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #7ac4c0; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Truthsage leaves | Silver-grey leaves with a clean sharp smell. Said to loosen the tongue. | data/items/gathered.json item truthsage_leaves (#1155) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #8aa07a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Watercress | Peppery green leaves from running water. Eaten raw or in soup. | data/items/gathered.json item watercress (#1162) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #3f8a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Whisperfern fronds | Long fronds that rustle in still air. Said to hear secrets. | data/items/gathered.json item whisperfern_fronds (#1163) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #5a8a6a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Wild garlic leaves | Broad green leaves smelling strongly of garlic. Eaten raw or cooked in spring. | data/items/gathered.json item wild_garlic_leaves (#1166) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #3f8a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |
| Witness leaves | Dark leathery leaves of the old witness tree. Not for eating. | data/items/gathered.json item witness_leaves (#1172) | BasicLook.mesh_for -> shape "frond" (data/items/looks.json), colour #7b8a56; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "frond" is 9 lines: a recognisable multi-part shape |

### gathered: fruit (7)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Bananas | Short sweet wild bananas, full of seeds. Ripe ones are soft and yellow. | data/items/gathered.json item bananas (#1007) | BasicLook.mesh_for -> shape "fruit" (data/items/looks.json), colour #f2d34a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fruit" is 7 lines: a recognisable multi-part shape |
| Cherries | Small dark wild cherries, tart. Eaten fresh, or pitted and cooked. | data/items/gathered.json item cherries (#1023) | BasicLook.mesh_for -> shape "fruit" (data/items/looks.json), colour #a0102a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fruit" is 7 lines: a recognisable multi-part shape |
| Crab apples | Hard sour little apples. Cooked down with honey they are good. | data/items/gathered.json item crab_apples (#1031) | BasicLook.mesh_for -> shape "fruit" (data/items/looks.json), colour #c8a02e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fruit" is 7 lines: a recognisable multi-part shape |
| Dates | Sticky sweet dates from a date palm. They keep well and travel well. | data/items/gathered.json item dates (#1037) | BasicLook.mesh_for -> shape "fruit" (data/items/looks.json), colour #6a3a1e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fruit" is 7 lines: a recognisable multi-part shape |
| Prickly pears | Red-purple fruit of the prickly pear, covered in fine spines. Peel before eating. | data/items/gathered.json item prickly_pears (#1109) | BasicLook.mesh_for -> shape "fruit" (data/items/looks.json), colour #c0402e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fruit" is 7 lines: a recognisable multi-part shape |
| Rose hips | Bright red seed pods of the wild rose. Tart and full of seeds; boiled into syrup. | data/items/gathered.json item rose_hips (#1118) | BasicLook.mesh_for -> shape "fruit" (data/items/looks.json), colour #d4381e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fruit" is 7 lines: a recognisable multi-part shape |
| Wild pears | Small hard pears, gritty and sour. Better cooked. | data/items/gathered.json item wild_pears (#1167) | BasicLook.mesh_for -> shape "fruit" (data/items/looks.json), colour #b8c04a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fruit" is 7 lines: a recognisable multi-part shape |

### gathered: round_berries (15)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Belladonna berries | Shiny black berries of deadly nightshade. Poisonous: do not eat. | data/items/gathered.json item belladonna_berries (#1011) | BasicLook.mesh_for -> shape "round_berries" (data/items/looks.json), colour #1a1020; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "round_berries" is 8 lines: a recognisable multi-part shape |
| Blueberries | Small blue berries from low bushes. Sweet, and they stain the fingers. | data/items/gathered.json item blueberries (#1015) | BasicLook.mesh_for -> shape "round_berries" (data/items/looks.json), colour #27335c; held: same mesh as on the ground, enlarged 1.8x in the palm | 3 | berry item look redone from the owner's close-up photo after "No, looks terrible" (archived handoff); gen_looks.py gives it its own row |
| Cranberries | Tart red berries of the bog. They keep a long time. | data/items/gathered.json item cranberries (#1032) | BasicLook.mesh_for -> shape "round_berries" (data/items/looks.json), colour #b01c2e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "round_berries" is 8 lines: a recognisable multi-part shape |
| Crowberries | Black berries of low moorland shrubs. Watery and mild; better than nothing. | data/items/gathered.json item crowberries (#1033) | BasicLook.mesh_for -> shape "round_berries" (data/items/looks.json), colour #15101c; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "round_berries" is 8 lines: a recognisable multi-part shape |
| Drakethorn berries | Dark red berries on a thorny shrub said to grow where drakes have lain. Handle with care until identified. | data/items/gathered.json item drakethorn_berries (#1038) | BasicLook.mesh_for -> shape "round_berries" (data/items/looks.json), colour #a82a2a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "round_berries" is 8 lines: a recognisable multi-part shape |
| Elderberries | Dark purple berries in drooping clusters. Cooked, they are good; raw they upset the stomach. | data/items/gathered.json item elderberries (#1043) | BasicLook.mesh_for -> shape "round_berries" (data/items/looks.json), colour #2a1a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "round_berries" is 8 lines: a recognisable multi-part shape |
| Haws | Small red berries of the hawthorn, mealy and mild. Cooked into jelly. | data/items/gathered.json item haws (#1067) | BasicLook.mesh_for -> shape "round_berries" (data/items/looks.json), colour #b0221e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "round_berries" is 8 lines: a recognisable multi-part shape |
| Juniper berries | Dark blue aromatic berries. Flavour meats and ferment drinks. | data/items/gathered.json item juniper_berries (#1079) | BasicLook.mesh_for -> shape "round_berries" (data/items/looks.json), colour #3a4a6a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "round_berries" is 8 lines: a recognisable multi-part shape |
| Lingonberries | Small tart red berries. Keep well and cook well. | data/items/gathered.json item lingonberries (#1084) | BasicLook.mesh_for -> shape "round_berries" (data/items/looks.json), colour #c0202a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "round_berries" is 8 lines: a recognisable multi-part shape |
| Rowan berries | Bright orange-red berries in clusters. Bitter raw; fine cooked into jelly. | data/items/gathered.json item rowan_berries (#1121) | BasicLook.mesh_for -> shape "round_berries" (data/items/looks.json), colour #e0481e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "round_berries" is 8 lines: a recognisable multi-part shape |
| Sea buckthorn berries | Bright orange berries on thorny shore bushes. Sour and oily, rich in vitamins. | data/items/gathered.json item sea_buckthorn_berries (#1125) | BasicLook.mesh_for -> shape "round_berries" (data/items/looks.json), colour #f0961e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "round_berries" is 8 lines: a recognisable multi-part shape |
| Sleetberries | Small blue-white berries that ripen after the first frost. Sharp and sweet. | data/items/gathered.json item sleetberries (#1129) | BasicLook.mesh_for -> shape "round_berries" (data/items/looks.json), colour #9ac4e0; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "round_berries" is 8 lines: a recognisable multi-part shape |
| Sloes | Small hard blue-black plums of the blackthorn. Very sour; ripe after frost. | data/items/gathered.json item sloes (#1130) | BasicLook.mesh_for -> shape "round_berries" (data/items/looks.json), colour #2a2c46; held: same mesh as on the ground, enlarged 1.8x in the palm | 3 | berry item look redone from the owner's close-up photo after "No, looks terrible" (archived handoff); gen_looks.py gives it its own row |
| Sunberries | Warm golden berries that grow in full sun. Sweet and juicy. | data/items/gathered.json item sunberries (#1142) | BasicLook.mesh_for -> shape "round_berries" (data/items/looks.json), colour #f2c21e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "round_berries" is 8 lines: a recognisable multi-part shape |
| Tidecrown pearls | Smooth pearly beads that grow on a tidal plant. Pretty and valued. | data/items/gathered.json item tidecrown_pearls (#1150) | BasicLook.mesh_for -> shape "round_berries" (data/items/looks.json), colour #e8f0f4; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "round_berries" is 8 lines: a recognisable multi-part shape |

### gathered: bark (6)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Birch bark | Papery white bark that peels in sheets. Burns even when damp; useful as tinder or for containers. | data/items/gathered.json item birch_bark (#1013) | BasicLook.mesh_for -> shape "bark" (data/items/looks.json), colour #e8dcc0; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bark" is 7 lines: a recognisable multi-part shape |
| Hagwillow bark | Grey twisted bark of the hag willow, bitter. Steeped it eases aches. | data/items/gathered.json item hagwillow_bark (#1063) | BasicLook.mesh_for -> shape "bark" (data/items/looks.json), colour #5a4a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bark" is 7 lines: a recognisable multi-part shape |
| Mirrorbark bark | Smooth silver bark that gleams like a mirror in sunlight. Peels in bright sheets. | data/items/gathered.json item mirrorbark_bark (#1091) | BasicLook.mesh_for -> shape "bark" (data/items/looks.json), colour #9fa6a8; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bark" is 7 lines: a recognisable multi-part shape |
| Tannin bark | Bark rich in tannin. Used for tanning hides. | data/items/gathered.json item tannin_bark (#1145) | BasicLook.mesh_for -> shape "bark" (data/items/looks.json), colour #6a4a2a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bark" is 7 lines: a recognisable multi-part shape |
| Willow bark | Grey-brown bark of willow, bitter. Steeped it eases pain and fever. | data/items/gathered.json item willow_bark (#1168) | BasicLook.mesh_for -> shape "bark" (data/items/looks.json), colour #8a7a52; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bark" is 7 lines: a recognisable multi-part shape |
| Witness bark | Deep-furrowed bark of the witness tree, said to carry old marks and scars. | data/items/gathered.json item witness_bark (#1171) | BasicLook.mesh_for -> shape "bark" (data/items/looks.json), colour #7b6a56; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bark" is 7 lines: a recognisable multi-part shape |

### gathered: berries (4)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Blackberries | Dark juicy brambles berries, sweet when fully black. Eaten fresh or cooked. | data/items/gathered.json item blackberries (#1014) | BasicLook.mesh_for -> shape "berries" (data/items/looks.json), colour #2a1830; held: same mesh as on the ground, enlarged 1.8x in the palm | 3 | berry item look redone from the owner's close-up photo after "No, looks terrible" (archived handoff); gen_looks.py gives it its own row |
| Cloudberries | Amber northern berries on low bogs. Rare, tart and prized. | data/items/gathered.json item cloudberries (#1027) | BasicLook.mesh_for -> shape "berries" (data/items/looks.json), colour #f0a030; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "berries" is 11 lines: a recognisable multi-part shape |
| Raspberries | Soft red berries that crumble when picked. Sweet when fully ripe. | data/items/gathered.json item raspberries (#1112) | BasicLook.mesh_for -> shape "berries" (data/items/looks.json), colour #8e0f1c; held: same mesh as on the ground, enlarged 1.8x in the palm | 3 | berry item look redone from the owner's close-up photo after "No, looks terrible" (archived handoff); gen_looks.py gives it its own row |
| Strawberries | Small sweet red wild strawberries. Better than any garden berry. | data/items/gathered.json item strawberries (#1140) | BasicLook.mesh_for -> shape "berries" (data/items/looks.json), colour #c8202a; held: same mesh as on the ground, enlarged 1.8x in the palm | 3 | berry item look redone from the owner's close-up photo after "No, looks terrible" (archived handoff); gen_looks.py gives it its own row |

### gathered: cap (9)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Chanterelles | Golden funnel-shaped mushrooms with a fruity smell. A good find in the woods. | data/items/gathered.json item chanterelles (#1021) | BasicLook.mesh_for -> shape "cap" (data/items/looks.json), colour #e0a028; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "cap" is 15 lines: a recognisable multi-part shape |
| Cinderfoot caps | Rust-orange mushroom caps with dark gills, found where old fires burned. Not for eating until identified. | data/items/gathered.json item cinderfoot_caps (#1026) | BasicLook.mesh_for -> shape "cap" (data/items/looks.json), colour #8a2a1a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "cap" is 15 lines: a recognisable multi-part shape |
| Fly agaric caps | Bright red caps with white flecks. Poisonous: do not eat. | data/items/gathered.json item fly_agaric_caps (#1053) | BasicLook.mesh_for -> shape "cap" (data/items/looks.json), colour #d02a1e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "cap" is 15 lines: a recognisable multi-part shape |
| Lumencap caps | Pale mushroom caps that glow softly in the dark. Not for eating until identified. | data/items/gathered.json item lumencap_caps (#1086) | BasicLook.mesh_for -> shape "cap" (data/items/looks.json), colour #7ad8c0; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "cap" is 15 lines: a recognisable multi-part shape |
| Mirrorcap caps | Shiny silver-grey mushroom caps. Not for eating until identified. | data/items/gathered.json item mirrorcap_caps (#1093) | BasicLook.mesh_for -> shape "cap" (data/items/looks.json), colour #c4ccd0; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "cap" is 15 lines: a recognisable multi-part shape |
| Morels | Honeycombed brown mushroom caps found in spring. Eaten cooked, never raw. | data/items/gathered.json item morels (#1094) | BasicLook.mesh_for -> shape "cap" (data/items/looks.json), colour #8a6a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "cap" is 15 lines: a recognisable multi-part shape |
| Porcini | Fat brown-capped mushrooms with a thick pale stem. A fine meal. | data/items/gathered.json item porcini (#1107) | BasicLook.mesh_for -> shape "cap" (data/items/looks.json), colour #8a5a34; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "cap" is 15 lines: a recognisable multi-part shape |
| Puffball | A round white mushroom the size of a head. Sliced and fried; spoils in a day. | data/items/gathered.json item puffball (#1110) | BasicLook.mesh_for -> shape "cap" (data/items/looks.json), colour #f0ead8; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "cap" is 15 lines: a recognisable multi-part shape |
| Rimecap caps | Frost-pale mushroom caps that grow on cold north slopes. Not for eating until identified. | data/items/gathered.json item rimecap_caps (#1116) | BasicLook.mesh_for -> shape "cap" (data/items/looks.json), colour #a8d4e4; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "cap" is 15 lines: a recognisable multi-part shape |

### gathered: beams (12)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Cherry wood | Reddish close-grained wood of the wild cherry. Takes a polish; makes fine small work. | data/items/gathered.json item cherry_wood (#1024) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #a85a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape |
| Everember wood | Dense dark wood of the everember, slow to burn and warm to hold. | data/items/gathered.json item everember_wood (#1048) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #c4683a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape |
| Fine wood | Well-grown timber chosen for its grain. Makes quality lumber and furniture. | data/items/gathered.json item fine_wood (#1052) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #b99062; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape |
| Hard wood | Heavy dense wood, slow to cut. Makes strong tool handles and posts. | data/items/gathered.json item hard_wood (#1065) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #7a5230; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape |
| Hardwood | Heavy timber from broadleaf trees such as oak and beech. Strong, and slow to burn. | data/items/gathered.json item hardwood (#1066) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #7a5230; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape |
| Mirrorbark wood | Fine pale wood from the mirrorbark tree. Takes a bright polish. | data/items/gathered.json item mirrorbark_wood (#1092) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #9fa6a8; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape |
| Palm wood | Fibrous trunk wood of palms. Soft to cut, poor for fuel. | data/items/gathered.json item palm_wood (#1101) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #b39465; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape |
| Softwood | Light timber from pine, spruce and fir. Easy to work, fast to burn. | data/items/gathered.json item softwood (#1131) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #d3b583; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape |
| Thorny wood | Hard dark wood of the blackthorn, covered in thorns. Makes tough tool handles. | data/items/gathered.json item thorny_wood (#1148) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #5a3a24; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape |
| Timber | Rough cut trunk wood for building. Squared up it becomes lumber. | data/items/gathered.json item timber (#1152) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #a67c4a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape |
| Wardpine wood | Straight clean wood of the wardpine, light and strongly scented. | data/items/gathered.json item wardpine_wood (#1160) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #8f7a4f; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape |
| Wood | Plain cut branches and trunk wood. Burns, or is worked into tools and frames. | data/items/gathered.json item wood (#1174) | BasicLook.mesh_for -> shape "beams" (data/items/looks.json), colour #a07a4a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "beams" is 8 lines: a recognisable multi-part shape |

### gathered: bottle (9)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Dye | A pot of plant colour pressed from flowers and roots. Stains cloth and wood. | data/items/gathered.json item dye (#1041) | BasicLook.mesh_for -> shape "bottle" (data/items/looks.json), colour #8a2a6a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bottle" is 9 lines: a recognisable multi-part shape |
| Everember sap | A sticky amber sap that smells of warm spice. Burns slowly. | data/items/gathered.json item everember_sap (#1047) | BasicLook.mesh_for -> shape "bottle" (data/items/looks.json), colour #e0602a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bottle" is 9 lines: a recognisable multi-part shape |
| Honeyspindle nectar | A sweet golden nectar drained from honeyspindle flowers. Sweetens any dish. | data/items/gathered.json item honeyspindle_nectar (#1076) | BasicLook.mesh_for -> shape "bottle" (data/items/looks.json), colour #f0c24a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bottle" is 9 lines: a recognisable multi-part shape |
| Lantern dew | Glowing drops collected from the dewlantern plant. Faintly lights a dark corner. | data/items/gathered.json item lantern_dew (#1081) | BasicLook.mesh_for -> shape "bottle" (data/items/looks.json), colour #a8f0e0; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bottle" is 9 lines: a recognisable multi-part shape |
| Oil | A small jar of pressed plant oil. Cooks, lights lamps and keeps leather supple. | data/items/gathered.json item oil (#1098) | BasicLook.mesh_for -> shape "bottle" (data/items/looks.json), colour #c9a82a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bottle" is 9 lines: a recognisable multi-part shape |
| Pilgrims cup pitchers | The cup-shaped leaves of the pilgrim's cup, holding rain. Pick one to drink from. | data/items/gathered.json item pilgrims_cup_pitchers (#1102) | BasicLook.mesh_for -> shape "bottle" (data/items/looks.json), colour #8aa04a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bottle" is 9 lines: a recognisable multi-part shape |
| Pilgrims cup water | Clear rainwater held in a pilgrim's cup leaf. Safe enough to drink. | data/items/gathered.json item pilgrims_cup_water (#1103) | BasicLook.mesh_for -> shape "bottle" (data/items/looks.json), colour #5a9ad4; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bottle" is 9 lines: a recognisable multi-part shape |
| Sap | Sweet watery sap tapped from a tree. Boils down to syrup. | data/items/gathered.json item sap (#1124) | BasicLook.mesh_for -> shape "bottle" (data/items/looks.json), colour #c9a05a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bottle" is 9 lines: a recognisable multi-part shape |
| Water | Plain water, gathered in a container. Drink it or cook with it. | data/items/gathered.json item water (#1161) | BasicLook.mesh_for -> shape "bottle" (data/items/looks.json), colour #5a9ad4; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bottle" is 9 lines: a recognisable multi-part shape |

### gathered: pile (7)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Echo moss | Springy grey-green moss that seems to muffle sound around it. Grows in damp hollows. | data/items/gathered.json item echo_moss (#1042) | BasicLook.mesh_for -> shape "pile" (data/items/looks.json), colour #6a8a8a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "pile" is 9 lines: a recognisable multi-part shape |
| Gloomthistle down | Dark grey thistle fluff, soft and light. Fills pillows and burns quick. | data/items/gathered.json item gloomthistle_down (#1059) | BasicLook.mesh_for -> shape "pile" (data/items/looks.json), colour #cfc8d8; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "pile" is 9 lines: a recognisable multi-part shape |
| Pine tar | Thick black tar boiled from pine. Seals roofs and soaks wood against rot. | data/items/gathered.json item pine_tar (#1104) | BasicLook.mesh_for -> shape "pile" (data/items/looks.json), colour #2a2018; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "pile" is 9 lines: a recognisable multi-part shape |
| Potash | Grey ash of salt-bush, rich in lye. Used for soap and glass. | data/items/gathered.json item potash (#1108) | BasicLook.mesh_for -> shape "pile" (data/items/looks.json), colour #c8c4b8; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "pile" is 9 lines: a recognisable multi-part shape |
| Staunchmoss | Soft spongy moss that stops bleeding when packed on a wound. | data/items/gathered.json item staunchmoss (#1135) | BasicLook.mesh_for -> shape "pile" (data/items/looks.json), colour #4f7a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "pile" is 9 lines: a recognisable multi-part shape |
| Stuffing | Soft fluff for filling a bed or a pack. | data/items/gathered.json item stuffing (#1141) | BasicLook.mesh_for -> shape "pile" (data/items/looks.json), colour #e8e0d0; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "pile" is 9 lines: a recognisable multi-part shape |
| Tinder | Fine dry stuff that takes a spark. | data/items/gathered.json item tinder (#1153) | BasicLook.mesh_for -> shape "pile" (data/items/looks.json), colour #a89878; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "pile" is 9 lines: a recognisable multi-part shape |

### gathered: grit (4)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Henbane seeds | Tiny grey seeds from a henbane pod. Poisonous: do not eat. | data/items/gathered.json item henbane_seeds (#1073) | BasicLook.mesh_for -> shape "grit" (data/items/looks.json), colour #4a3a2a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "grit" is 19 lines: a recognisable multi-part shape |
| Linseed | Small shiny brown flax seeds, rich in oil. Eaten or pressed. | data/items/gathered.json item linseed (#1085) | BasicLook.mesh_for -> shape "grit" (data/items/looks.json), colour #7a4a2a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "grit" is 19 lines: a recognisable multi-part shape |
| Seeds | A handful of plant seeds. Eaten, or sown in a patch. | data/items/gathered.json item seeds (#1126) | BasicLook.mesh_for -> shape "grit" (data/items/looks.json), colour #c9b57a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "grit" is 19 lines: a recognisable multi-part shape |
| Stillwater seeds | Round seeds of the stillwater lotus. Eaten roasted; keep well. | data/items/gathered.json item stillwater_seeds (#1137) | BasicLook.mesh_for -> shape "grit" (data/items/looks.json), colour #7ec8d9; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "grit" is 19 lines: a recognisable multi-part shape |

## 12 Items: food, drink and medicine

37 entries. Stages: 37 x stage 2.


### food and drink (35)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Campfire Stew | A bowl of chunky vegetable soup, simmered over a fire. | data/items/items.json item roast_forage (#15) | BasicLook.mesh_for -> shape "stew" (data/items/looks.json), colour #b5793a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | wooden bowl built from helper shapes (frustum, rim ring, base) with a surface and chunky bits for stews; seen in an offline render: reads as a bowl of food |
| Energy bar | Nuts, dried fruit and herbs pressed into a cake. Quick energy that wears on your fitness. | data/items/items.json item energy_bar (#51) | BasicLook.mesh_for -> shape "bar" (data/items/looks.json), colour #c9a15b; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bar" is 6 lines: a recognisable multi-part shape |
| Herbal tea | Mint leaves steeped and drunk. A small lift of energy. | data/items/items.json item herbal_tea (#52) | BasicLook.mesh_for -> shape "bottle" (data/items/looks.json), colour #b6e61a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bottle" is 9 lines: a recognisable multi-part shape |
| Magic tonic | A shimmering draught. A great lift of energy. | data/items/items.json item magic_tonic (#53) | BasicLook.mesh_for -> shape "bottle" (data/items/looks.json), colour #9b30ff; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bottle" is 9 lines: a recognisable multi-part shape [future] |
| Medicine | A bitter remedy that settles a sick stomach. Placeholder until healers and herb cures exist. | data/items/items.json item medicine (#56) | BasicLook.mesh_for -> shape "bottle" (data/items/looks.json), colour #e01e1e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bottle" is 9 lines: a recognisable multi-part shape [future] |
| Stomach tea | A folk remedy: mint and chamomile steeped for a sick stomach. Settles vomiting and the runs. | data/items/items.json item stomach_tea (#57) | BasicLook.mesh_for -> shape "bottle" (data/items/looks.json), colour #18d0d0; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bottle" is 9 lines: a recognisable multi-part shape |
| Chamomile tea | A folk remedy: chamomile flowers steeped in water. Calms the stomach and helps you sleep. | data/items/items.json item chamomile_tea (#58) | BasicLook.mesh_for -> shape "bottle" (data/items/looks.json), colour #ffd800; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bottle" is 9 lines: a recognisable multi-part shape |
| Willow bark tea | A folk remedy: bitter willow bark steeped for pain and fever. It also eases a sick stomach a little. | data/items/items.json item willow_bark_tea (#59) | BasicLook.mesh_for -> shape "bottle" (data/items/looks.json), colour #8a4b1e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bottle" is 9 lines: a recognisable multi-part shape |
| Raw meat | Fresh meat. Cook it before you eat it, and do not keep it long. | data/items/items.json item raw_meat (#68) | BasicLook.mesh_for -> shape "meat" (data/items/looks.json), colour #a8403a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "meat" is 8 lines: a recognisable multi-part shape [future] |
| Roast Meat | Meat cooked over a fire. Filling, and it keeps a couple of days. | data/items/items.json item roast_meat (#69) | BasicLook.mesh_for -> shape "joint" (data/items/looks.json), colour #6e3a1c; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "joint" is 8 lines: a recognisable multi-part shape [future] |
| Trout | A cold-water fish from fast streams. Cook it before you eat it. | data/items/items.json item trout (#76) | BasicLook.mesh_for -> shape "fish" (data/items/looks.json), colour #8a9a7a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fish" is 10 lines: a recognisable multi-part shape [future] |
| Perch | A common fish of ponds and lakes. Cook it before you eat it. | data/items/items.json item perch (#77) | BasicLook.mesh_for -> shape "fish" (data/items/looks.json), colour #6f8a4a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fish" is 10 lines: a recognisable multi-part shape [future] |
| Carp | A heavy fish of still ponds. Cook it before you eat it. | data/items/items.json item carp (#78) | BasicLook.mesh_for -> shape "fish" (data/items/looks.json), colour #a09060; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fish" is 10 lines: a recognisable multi-part shape [future] |
| Pike | A long hunting fish of lakes. Cook it before you eat it. | data/items/items.json item pike (#79) | BasicLook.mesh_for -> shape "fish" (data/items/looks.json), colour #5a7a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fish" is 10 lines: a recognisable multi-part shape [future] |
| Roast Fish | Fish cooked over a fire. Filling, and it keeps a day or two. | data/items/items.json item roast_fish (#80) | BasicLook.mesh_for -> shape "fish" (data/items/looks.json), colour #a8703a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fish" is 10 lines: a recognisable multi-part shape [future] |
| Berry compote | Sweet stewed berries. Light, quick energy. | data/items/items.json item berry_compote (#175) | BasicLook.mesh_for -> shape "stew" (data/items/looks.json), colour #9a1f3f; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | wooden bowl built from helper shapes (frustum, rim ring, base) with a surface and chunky bits for stews; seen in an offline render: reads as a bowl of food |
| Nut paste | Ground hazelnuts and honey. Keeps well. | data/items/items.json item nut_paste (#176) | BasicLook.mesh_for -> shape "mound" (data/items/looks.json), colour #b08a55; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | wooden bowl built from helper shapes (frustum, rim ring, base) with a surface and chunky bits for stews; seen in an offline render: reads as a bowl of food |
| Roast Roots | Roots baked in the embers. Plain and filling. | data/items/items.json item roast_roots (#177) | BasicLook.mesh_for -> shape "bundle" (data/items/looks.json), colour #ff9f1c; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "bundle" is 10 lines: a recognisable multi-part shape |
| Acorn mash | Leached acorns boiled to a mash. Famine food. | data/items/items.json item acorn_mash (#178) | BasicLook.mesh_for -> shape "mound" (data/items/looks.json), colour #8a6a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | wooden bowl built from helper shapes (frustum, rim ring, base) with a surface and chunky bits for stews; seen in an offline render: reads as a bowl of food |
| Baked apples | Crab apples baked sweet in the ashes. | data/items/items.json item baked_apples (#179) | BasicLook.mesh_for -> shape "fruit" (data/items/looks.json), colour #ff5a36; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fruit" is 7 lines: a recognisable multi-part shape |
| Mushroom skewer | Mushrooms and wild garlic grilled on a stick. | data/items/items.json item mushroom_skewer (#180) | BasicLook.mesh_for -> shape "skewer" (data/items/looks.json), colour #f5e6ff; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "skewer" is 5 lines: a recognisable multi-part shape |
| Herb fish | Trout roasted with thyme and sea greens. | data/items/items.json item herb_fish (#181) | BasicLook.mesh_for -> shape "fish" (data/items/looks.json), colour #9a7a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fish" is 10 lines: a recognisable multi-part shape |
| Garlic meat | Meat roasted with wild garlic and rosemary. | data/items/items.json item garlic_meat (#182) | BasicLook.mesh_for -> shape "joint" (data/items/looks.json), colour #6a3c20; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "joint" is 8 lines: a recognisable multi-part shape |
| Chestnut cakes | Flat cakes of chestnut, honey and linseed. Good travelling food. | data/items/items.json item chestnut_cakes (#183) | BasicLook.mesh_for -> shape "loaf" (data/items/looks.json), colour #5d3a1a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "loaf" is 7 lines: a recognisable multi-part shape |
| Fruit leather | Dried fruit pressed flat. Keeps for a long journey. | data/items/items.json item fruit_leather (#184) | BasicLook.mesh_for -> shape "cloth" (data/items/looks.json), colour #00a8a8; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "cloth" is 7 lines: a recognisable multi-part shape |
| Smoked fish | Pike smoked over juniper. Lasts for weeks. | data/items/items.json item smoked_fish (#185) | BasicLook.mesh_for -> shape "fish" (data/items/looks.json), colour #6e4a2a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "fish" is 10 lines: a recognisable multi-part shape |
| Hunter's stew | A thick meat and root stew. Warms you through. | data/items/items.json item hunters_stew (#186) | BasicLook.mesh_for -> shape "stew" (data/items/looks.json), colour #6b3a1e; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | wooden bowl built from helper shapes (frustum, rim ring, base) with a surface and chunky bits for stews; seen in an offline render: reads as a bowl of food |
| Forager's stew | Greens, roots and mushrooms in one pot. | data/items/items.json item forager_stew (#187) | BasicLook.mesh_for -> shape "stew" (data/items/looks.json), colour #7a9a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | wooden bowl built from helper shapes (frustum, rim ring, base) with a surface and chunky bits for stews; seen in an offline render: reads as a bowl of food |
| Fish stew | Perch, cress and root in a sage broth. | data/items/items.json item fish_stew (#188) | BasicLook.mesh_for -> shape "stew" (data/items/looks.json), colour #e8c870; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | wooden bowl built from helper shapes (frustum, rim ring, base) with a surface and chunky bits for stews; seen in an offline render: reads as a bowl of food |
| Trail bread | Dense seed and nut loaves. Barely spoils. | data/items/items.json item trail_bread (#189) | BasicLook.mesh_for -> shape "loaf" (data/items/looks.json), colour #e8b96a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "loaf" is 7 lines: a recognisable multi-part shape |
| Hearty pottage | A rich pot of seeds, roots, herbs and fat. Fills and warms. | data/items/items.json item hearty_pottage (#190) | BasicLook.mesh_for -> shape "stew" (data/items/looks.json), colour #d9a640; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | wooden bowl built from helper shapes (frustum, rim ring, base) with a surface and chunky bits for stews; seen in an offline render: reads as a bowl of food |
| Roast Beast | Spiced, fat-basted roast. The best meal a campfire makes. | data/items/items.json item feast_roast (#191) | BasicLook.mesh_for -> shape "joint" (data/items/looks.json), colour #62301a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "joint" is 8 lines: a recognisable multi-part shape |
| Flatbread | A flat cake baked on the hot clay. Plain and filling. | data/items/items.json item flatbread (#273) | BasicLook.mesh_for -> shape "loaf" (data/items/looks.json), colour #d9b87a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "loaf" is 7 lines: a recognisable multi-part shape |
| Honey loaf | A sweet loaf baked in the oven. Keeps well. | data/items/items.json item honey_loaf (#274) | BasicLook.mesh_for -> shape "loaf" (data/items/looks.json), colour #c98a3c; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "loaf" is 7 lines: a recognisable multi-part shape |
| Rosemary joint | Meat roasted whole in the oven with herbs. | data/items/items.json item roast_joint (#275) | BasicLook.mesh_for -> shape "chunk" (data/items/looks.json), colour #8a4a2a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "chunk" is 7 lines: a recognisable multi-part shape |

### medicine (2)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Herb poultice | Crushed herb leaves for a wound. | data/items/items.json item poultice (#16) | BasicLook.mesh_for -> shape "mound" (data/items/looks.json), colour #4f7a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | wooden bowl built from helper shapes (frustum, rim ring, base) with a surface and chunky bits for stews; seen in an offline render: reads as a bowl of food |
| Herb bandage | Leaves and fibre wrapped to bind a wound. | data/items/items.json item bandage (#17) | BasicLook.mesh_for -> shape "coil" (data/items/looks.json), colour #f4f4f4; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "coil" is 5 lines: a recognisable multi-part shape |

## 13 Items: tools, weapons and ammunition

41 entries. Stages: 1 x stage 0, 16 x stage 2, 24 x stage 3.


### tools (28)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Stone axe | A sharpened stone bound to a handle. Fells trees, breaks rock and cuts wood. | data/items/items.json item stone_axe (#6) | BasicLook.mesh_for -> shape "axe" (data/items/looks.json), colour #7d7a74; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "axe" is 19 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me |
| Stone knife | A sharp stone flake on a handle. Cuts bark, gum and sap. | data/items/items.json item stone_knife (#11) | BasicLook.mesh_for -> shape "knife" (data/items/looks.json), colour #8a8680; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "knife" is 16 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me |
| Basic torch | A stick wrapped in fibre that burns for a while and lights your way. | data/items/items.json item torch (#12) | BasicLook.mesh_for -> shape "torch" (data/items/looks.json), colour #e08a2a; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "torch" is 10 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me |
| Wooden spade | A sharpened wooden blade on a handle. Digs roots and bulbs. | data/items/items.json item wooden_spade (#19) | BasicLook.mesh_for -> shape "spade" (data/items/looks.json), colour #8a6a3a; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "spade" is 51 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me |
| Iron pickaxe | An iron head on a hardwood handle. One blow breaks one stone off a boulder. | data/items/items.json item iron_pickaxe (#33) | BasicLook.mesh_for -> shape "pick" (data/items/looks.json), colour #6c6f75; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "pick" is 44 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me [future] |
| Steel pickaxe | A steel head on a hardwood handle. One blow breaks one stone off a boulder, and it lasts longest. | data/items/items.json item steel_pickaxe (#34) | BasicLook.mesh_for -> shape "pick" (data/items/looks.json), colour #9aa3ad; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "pick" is 44 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me [future] |
| Stone spade | A wooden spade shod with a flat stone blade. Digs deeper than bare wood and lasts longer. | data/items/items.json item stone_spade (#45) | BasicLook.mesh_for -> shape "spade" (data/items/looks.json), colour #7d7a74; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "spade" is 51 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me |
| Iron spade | A spade with an iron blade. | data/items/items.json item iron_spade (#46) | BasicLook.mesh_for -> shape "spade" (data/items/looks.json), colour #6c6f75; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "spade" is 51 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me [future] |
| Steel spade | A spade with a steel blade. | data/items/items.json item steel_spade (#47) | BasicLook.mesh_for -> shape "spade" (data/items/looks.json), colour #9aa3ad; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "spade" is 51 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me [future] |
| Sewing needle | A needle carved from bone. For sewing hide and cloth. | data/items/items.json item sewing_needle (#49) | BasicLook.mesh_for -> shape "needle" (data/items/looks.json), colour #c8c8cc; held: tool/weapon model in held_item.gd | 2 | BasicLook shape "needle" is 5 lines: a recognisable multi-part shape [future] |
| Fishing rod | A stick with a line and a hook. Hold it and click at the water, then click again when something bites. | data/items/items.json item fishing_rod (#75) | BasicLook.mesh_for -> shape "rod" (data/items/looks.json), colour #9a9a9e; held: tool/weapon model in held_item.gd | 2 | BasicLook shape "rod" is 36 lines: a recognisable multi-part shape |
| Shore net | A weighted twine net. Hold the left button at the water's edge for about 20 seconds. | data/items/items.json item shore_net (#260) | BasicLook.mesh_for -> shape "cloth" (data/items/looks.json), colour #a89a78; held: tool/weapon model in held_item.gd | 2 | BasicLook shape "cloth" is 7 lines: a recognisable multi-part shape |
| Medium wooden spade | Medium spade: moves 4 pieces of ground at a time. | data/items/items.json item wooden_spade_medium (#213) | BasicLook.mesh_for -> shape "spade" (data/items/looks.json), colour #8a6a3a; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "spade" is 51 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me |
| Large wooden spade | Large spade: moves 8 pieces of ground at a time. | data/items/items.json item wooden_spade_large (#214) | BasicLook.mesh_for -> shape "spade" (data/items/looks.json), colour #8a6a3a; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "spade" is 51 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me |
| Medium stone spade | Medium spade: moves 4 pieces of ground at a time. | data/items/items.json item stone_spade_medium (#215) | BasicLook.mesh_for -> shape "spade" (data/items/looks.json), colour #7d7a74; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "spade" is 51 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me |
| Large stone spade | Large spade: moves 8 pieces of ground at a time. | data/items/items.json item stone_spade_large (#216) | BasicLook.mesh_for -> shape "spade" (data/items/looks.json), colour #7d7a74; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "spade" is 51 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me |
| Medium iron spade | Medium spade: moves 4 pieces of ground at a time. | data/items/items.json item iron_spade_medium (#217) | BasicLook.mesh_for -> shape "spade" (data/items/looks.json), colour #6c6f75; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "spade" is 51 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me [future] |
| Large iron spade | Large spade: moves 8 pieces of ground at a time. | data/items/items.json item iron_spade_large (#218) | BasicLook.mesh_for -> shape "spade" (data/items/looks.json), colour #6c6f75; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "spade" is 51 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me [future] |
| Medium steel spade | Medium spade: moves 4 pieces of ground at a time. | data/items/items.json item steel_spade_medium (#219) | BasicLook.mesh_for -> shape "spade" (data/items/looks.json), colour #9aa3ad; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "spade" is 51 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me [future] |
| Large steel spade | Large spade: moves 8 pieces of ground at a time. | data/items/items.json item steel_spade_large (#220) | BasicLook.mesh_for -> shape "spade" (data/items/looks.json), colour #9aa3ad; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "spade" is 51 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me [future] |
| Wooden hoe | A flat blade lashed to a long handle. Paths the ground and smooths it. | data/items/items.json item wooden_hoe (#221) | BasicLook.mesh_for -> shape "hoe" (data/items/looks.json), colour #8a6a3a; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "hoe" is 45 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me |
| Stone hoe | A hoe with a flat stone blade. Lasts longer than bare wood. | data/items/items.json item stone_hoe (#222) | BasicLook.mesh_for -> shape "hoe" (data/items/looks.json), colour #7d7a74; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "hoe" is 45 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me |
| Iron hoe | A hoe with an iron blade. | data/items/items.json item iron_hoe (#223) | BasicLook.mesh_for -> shape "hoe" (data/items/looks.json), colour #6c6f75; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "hoe" is 45 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me [future] |
| Steel hoe | A hoe with a steel blade. | data/items/items.json item steel_hoe (#224) | BasicLook.mesh_for -> shape "hoe" (data/items/looks.json), colour #9aa3ad; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "hoe" is 45 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me [future] |
| Wooden hammer | A wooden head on a stick. The weakest hammer; it wears out fast. Nails and building still to come. | data/items/items.json item wooden_hammer (#247) | BasicLook.mesh_for -> shape "hammer" (data/items/looks.json), colour #8a6a3a; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "hammer" is 24 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me |
| Stone hammer | A hafted stone hammer. It does nothing yet: nails and finishing work are still to come. | data/items/items.json item stone_hammer (#244) | BasicLook.mesh_for -> shape "hammer" (data/items/looks.json), colour #7d7a74; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "hammer" is 24 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me |
| Hand saw | A bow saw. Keep it on the hotbar to saw a log into 2 lumber by hand, slower than a mill. | data/items/items.json item hand_saw (#245) | BasicLook.mesh_for -> shape "saw" (data/items/looks.json), colour #8a8d93; held: tool/weapon model in held_item.gd | 3 | BasicLook shape "saw" is 19 lines of mesh code with its own review rounds (archived Kathleen tool-pass/weak-looks/held-pose plans; pickaxe "locked, Dave: excellent"); not seen rendered by me |
| Stone adze | A hafted stone blade with a curved edge. It does nothing yet: smoothing beams is still to come. | data/items/items.json item stone_adze (#246) | none | 0 | retired row with no looks.json entry; nothing drawn [retired] |

### weapons (3)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Stone spear | A stone point bound to a long shaft, for jabbing and throwing. | data/items/items.json item spear (#7) | BasicLook.mesh_for -> shape "shaft" (data/items/looks.json), colour #b8bcc4; held: tool/weapon model in held_item.gd | 2 | BasicLook shape "shaft" is 21 lines: a recognisable multi-part shape |
| Wooden spear | A sharpened stick, for jabbing and throwing. | data/items/items.json item wooden_spear (#10) | BasicLook.mesh_for -> shape "shaft" (data/items/looks.json), colour #d8b070; held: tool/weapon model in held_item.gd | 2 | BasicLook shape "shaft" is 21 lines: a recognisable multi-part shape |
| Wooden bow | A bow of bent wood and twine. It needs arrows. | data/items/items.json item wooden_bow (#269) | BasicLook.mesh_for -> shape "bow" (data/items/looks.json), colour #a8804a; held: tool/weapon model in held_item.gd | 2 | BasicLook shape "bow" is 21 lines: a recognisable multi-part shape |

### ammunition (2)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Wooden arrow | A straight stick with a fire-hardened tip and feather fletching. | data/items/items.json item wooden_arrow (#270) | BasicLook.mesh_for -> shape "arrow" (data/items/looks.json), colour #d8b070; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "arrow" is 18 lines: a recognisable multi-part shape |
| Stone arrow | An arrow tipped with a flaked stone point. | data/items/items.json item stone_arrow (#271) | BasicLook.mesh_for -> shape "arrow" (data/items/looks.json), colour #b8bcc4; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "arrow" is 18 lines: a recognisable multi-part shape |

### requested by Sal (future items, branch sal-items) (8)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Wooden club | item #300, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #300 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "club" (used while looks.json still holds the grey chunk) | 2 | new shape: tapered hardwood club with wrapped grip (offline render checked) [future] |
| Hide scraper | item #293, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #293 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "scraper" (used while looks.json still holds the grey chunk) | 2 | new shape: wrapped handle with a wide flint blade; held turn added (offline render checked) [future] |
| Steel striker | item #294, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #294 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "striker" (used while looks.json still holds the grey chunk) | 2 | new shape: curved dark steel strip (offline render checked) [future] |
| Javelin | item #295, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #295 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "shaft" (used while looks.json still holds the grey chunk) | 2 | the spear shaft at 0.85 size with an iron head (offline render checked) [future] |
| Obsidian knife | item #296, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #296 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "knife" (used while looks.json still holds the grey chunk) | 2 | the stone-knife shape with a black glass blade (offline render checked) [future] |
| Stone pickaxe | item #297, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #297 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "pick" (used while looks.json still holds the grey chunk) | 2 | the pickaxe shape with a matt stone head, no metal sheen (offline render checked) [future] |
| Sickle | item #298, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #298 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "sickle" (used while looks.json still holds the grey chunk) | 2 | new shape: curved blade with pale flint teeth on a grip (offline render checked) [future] |
| Scythe | item #299, flagged future | ITEM_ART_REQUESTS.md on branch sal-items; item #299 (not in this branch's items.json) | BasicLook.ART_OVERRIDES -> shape "scythe" (used while looks.json still holds the grey chunk) | 2 | new shape: tall haft with grips and a long curved blade (offline render checked) [future] |

## 14 Items: containers, coins, clothing and gear

18 entries. Stages: 18 x stage 2.


### containers (4)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Wooden bowl | A bowl hollowed from a bolt of wood. Carries a little water. | data/items/items.json item wooden_bowl (#39) | BasicLook.mesh_for -> shape "bowl" (data/items/looks.json), colour #9a6b38; held: plain drum (held_item._make_container_model) | 2 | wooden bowl built from helper shapes (frustum, rim ring, base) with a surface and chunky bits for stews; seen in an offline render: reads as a bowl of food |
| Clay pot | A fired pot of clay. Holds three litres of water. | data/items/items.json item clay_pot (#40) | BasicLook.mesh_for -> shape "pot" (data/items/looks.json), colour #ff7f11; held: plain drum (held_item._make_container_model) | 2 | BasicLook shape "pot" is 8 lines: a recognisable multi-part shape |
| Bucket | A wooden bucket bound with cord. Holds eight litres of water. | data/items/items.json item bucket (#41) | BasicLook.mesh_for -> shape "bucket" (data/items/looks.json), colour #b88a50; held: plain drum (held_item._make_container_model) | 2 | BasicLook shape "bucket" is 13 lines: a recognisable multi-part shape |
| Waterskin | A skin bag sewn shut. Holds a day's drink and little weight. | data/items/items.json item waterskin (#42) | BasicLook.mesh_for -> shape "skin" (data/items/looks.json), colour #a0743f; held: plain drum (held_item._make_container_model) | 2 | BasicLook shape "skin" is 9 lines: a recognisable multi-part shape [future] |

### worn clothing and gear (as item) (10)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Backpack | A hide pack with straps. Worn on the back, it lets you carry more. | data/items/items.json item backpack (#50) | BasicLook.mesh_for -> shape "backpack" (data/items/looks.json), colour #8a6a4a; held: same mesh as on the ground, enlarged 1.8x in the palm; also worn (worn.json) | 2 | BasicLook shape "backpack" is 10 lines: a recognisable multi-part shape |
| Grass skirt | Woven grass hung from the waist. Barely warm, and it rots quickly. | data/items/items.json item grass_skirt (#60) | BasicLook.mesh_for -> shape "cloth" (data/items/looks.json), colour #8aa04a; held: same mesh as on the ground, enlarged 1.8x in the palm; also worn (worn.json) | 2 | BasicLook shape "cloth" is 7 lines: a recognisable multi-part shape |
| Grass cloak | A cloak of woven grass over the shoulders. Keeps a little wind off. | data/items/items.json item grass_cloak (#61) | BasicLook.mesh_for -> shape "cloth" (data/items/looks.json), colour #7a9a45; held: same mesh as on the ground, enlarged 1.8x in the palm; also worn (worn.json) | 2 | BasicLook shape "cloth" is 7 lines: a recognisable multi-part shape |
| Fibre sandals | Soles of twisted fibre tied to the foot. | data/items/items.json item fibre_sandals (#62) | BasicLook.mesh_for -> shape "cloth" (data/items/looks.json), colour #b8a468; held: same mesh as on the ground, enlarged 1.8x in the palm; also worn (worn.json) | 2 | BasicLook shape "cloth" is 7 lines: a recognisable multi-part shape |
| Hide cloak | A wrapped animal hide. Warm, and it sheds rain. | data/items/items.json item hide_cloak (#63) | BasicLook.mesh_for -> shape "cloth" (data/items/looks.json), colour #7a5a3c; held: same mesh as on the ground, enlarged 1.8x in the palm; also worn (worn.json) | 2 | BasicLook shape "cloth" is 7 lines: a recognisable multi-part shape |
| Hide boots | Hide wrapped and stitched around the foot. | data/items/items.json item hide_boots (#64) | BasicLook.mesh_for -> shape "cloth" (data/items/looks.json), colour #6a4a30; held: same mesh as on the ground, enlarged 1.8x in the palm; also worn (worn.json) | 2 | BasicLook shape "cloth" is 7 lines: a recognisable multi-part shape |
| Hide hood | A close hood of hide with the hair turned in. | data/items/items.json item hide_hood (#65) | BasicLook.mesh_for -> shape "cloth" (data/items/looks.json), colour #7a5a3c; held: same mesh as on the ground, enlarged 1.8x in the palm; also worn (worn.json) | 2 | BasicLook shape "cloth" is 7 lines: a recognisable multi-part shape |
| Hide mittens | Stitched hide mittens. | data/items/items.json item hide_mittens (#66) | BasicLook.mesh_for -> shape "cloth" (data/items/looks.json), colour #6a4a30; held: same mesh as on the ground, enlarged 1.8x in the palm; also worn (worn.json) | 2 | BasicLook shape "cloth" is 7 lines: a recognisable multi-part shape |
| Hide leggings | Hide tied around each leg. | data/items/items.json item hide_leggings (#67) | BasicLook.mesh_for -> shape "cloth" (data/items/looks.json), colour #7a5a3c; held: same mesh as on the ground, enlarged 1.8x in the palm; also worn (worn.json) | 2 | BasicLook shape "cloth" is 7 lines: a recognisable multi-part shape |
| Quiver | A hide tube worn on the back. Holds 40 arrows. | data/items/items.json item quiver (#272) | BasicLook.mesh_for -> shape "quiver" (data/items/looks.json), colour #6b4c31; held: same mesh as on the ground, enlarged 1.8x in the palm; also worn (worn.json) | 2 | BasicLook shape "quiver" is 14 lines: a recognisable multi-part shape |

### coins (4)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Copper coin | A small copper coin. The smallest money there is. | data/items/items.json item coin_copper (#96) | BasicLook.mesh_for -> shape "coin" (data/items/looks.json), colour #b0653a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "coin" is 7 lines: a recognisable multi-part shape [future] |
| Bronze coin | A bronze coin, worth ten copper. | data/items/items.json item coin_bronze (#97) | BasicLook.mesh_for -> shape "coin" (data/items/looks.json), colour #9c7a3a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "coin" is 7 lines: a recognisable multi-part shape [future] |
| Silver coin | A silver coin, worth ten bronze. | data/items/items.json item coin_silver (#98) | BasicLook.mesh_for -> shape "coin" (data/items/looks.json), colour #c4c8cc; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "coin" is 7 lines: a recognisable multi-part shape [future] |
| Gold coin | A gold coin, worth ten silver. | data/items/items.json item coin_gold (#99) | BasicLook.mesh_for -> shape "coin" (data/items/looks.json), colour #e0b83a; held: same mesh as on the ground, enlarged 1.8x in the palm | 2 | BasicLook shape "coin" is 7 lines: a recognisable multi-part shape [future] |

## 15 Items: placeable kits

35 entries. Stages: 33 x stage 2, 2 x stage 3.


### kits and placeables (35)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Campfire | Stones and sticks ready to lay a fire where you stand. | data/items/items.json item campfire_kit (#8) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #6a4a2a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Small shelter | Sticks, leaves and twine for a small shelter with a roof. | data/items/items.json item lean_to_kit (#20) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #6a8a3a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Woven chest | Sticks and twine woven into a storage chest, ready to set down. | data/items/items.json item chest_kit (#22) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #9a7a45; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Chopping block | Retired: the chopping block itself is now the carried item (Dave 2026-10-22). | data/items/items.json item chopping_block_kit (#24) | inventory_view._mesh_for -> BuildingLook.block_mesh; held: kit bundle (held_item._make_kit_model) | 3 | the carried block uses the placed model (BuildingLook.block_mesh, ART_DIRECTION.md section 52) [retired] |
| Chopping block | A heavy log set on end. Set it down and split logs into firewood on it. | data/items/items.json item chopping_block (#25) | inventory_view._mesh_for -> BuildingLook.block_mesh; held: kit bundle (held_item._make_kit_model) | 3 | the carried block uses the placed model (BuildingLook.block_mesh, ART_DIRECTION.md section 52) |
| Plank chest | Boards and twine for a stronger storage chest, ready to set down. | data/items/items.json item plank_chest_kit (#28) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #a07a45; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Camp bench | Lashed sticks and a flat top: a work table for tools, packs and sewing. Set it down where you camp. | data/items/items.json item workbench_kit (#73) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #8a6a3a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Tool rack | Pegs and a crossbar to hang tools and stretch hides. Set it beside a camp bench. | data/items/items.json item tool_rack_kit (#81) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #7a5a35; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Wooden vice | Two jaws of hardwood that hold work still. Set it beside a camp bench. | data/items/items.json item vice_kit (#83) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #7a5a35; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Log workbench | A heavy log bench with its own rack and vice, ready to set down. | data/items/items.json item log_workbench_kit (#85) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #6a4a2a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Basic Forge | A clay and rough stone dome forge under a log roof, ready to raise. | data/items/items.json item stone_forge_kit (#87) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #7d7a74; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Medium Forge | A dressed stone forge with a stepped hood and iron straps, ready to raise. | data/items/items.json item blacksmithy_kit (#89) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #6c6f75; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Large Forge | A big arched forge with a riveted iron frame, ready to raise. | data/items/items.json item large_forge_kit (#92) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #5c5f65; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Master Forge | An ornate black iron and gold forge set with red gems, ready to raise. | data/items/items.json item master_forge_kit (#94) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #44474d; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Wall section | A plank wall, two metres wide. Set pieces edge to edge to build a house. | data/items/items.json item wall_section_kit (#192) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #9a7a45; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Floor section | A plank floor, two metres square. Set pieces edge to edge to build a house. | data/items/items.json item floor_section_kit (#194) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #a98350; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Roof section | A plank roof on four posts, to set over walls and floors. | data/items/items.json item roof_section_kit (#196) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #6a4a2a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Foundation | A stone and clay slab, four metres square. Walls and floors snap onto it. | data/items/items.json item foundation_section_kit (#198) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #7d7a74; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Doorway | A plank wall with a gap you can walk through, one metre wide and two high. | data/items/items.json item doorway_section_kit (#200) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #8a6a3a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Window wall | A plank wall with an opening at chest height to see through. | data/items/items.json item window_section_kit (#202) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #8a6a3a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Timber prop | A log stood on end to hold up a low roof of earth. Short reach, quick to wear. | data/items/items.json item timber_prop_kit (#204) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #7a5a35; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Timber set | A post and cap frame that braces a tunnel. Longer reach and slower to wear. | data/items/items.json item timber_set_kit (#206) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #8a6a3a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Ladder | A wooden ladder, 2.4 m tall. Set it against a wall or an edge and climb. | data/items/items.json item ladder_kit (#211) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #9a7a45; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Sawmill | A saw frame on a tall foundation, driven by a water wheel in running water. | data/items/items.json item saw_mill_kit (#240) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #8a6a3a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Woodworking table | A heavy table with vices and clamps for fine woodwork. Set it down in a workshop. | data/items/items.json item woodworking_table_kit (#242) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #7a5430; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Rock pile | A heap of 45 stones. Set it down to store rock; pick it up to carry it. | data/items/items.json item rock_pile (#235) | BasicLook.mesh_for -> shape "pile" (data/items/looks.json), colour #7d7a74; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "pile" is 9 lines: a recognisable multi-part shape |
| Rough bed | A heap of thatch bound with twine and stakes. Set it down under a roof. | data/items/items.json item rough_bed_kit (#250) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #c9bb7a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Thatch wall | Bundled thatch on a frame of sticks. Set it up to close in a shelter. | data/items/items.json item thatch_wall_kit (#252) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #b8a46a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Campfire pot | A pot on sticks and a chain. Hang it on a small fire to cook stews. The fire stays at firewood. | data/items/items.json item campfire_pot_kit (#254) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #4a3a2a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Clay hearth | Stones and clay built into a low hearth with a spit. Cooks better than an open fire. | data/items/items.json item clay_hearth_kit (#256) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #9a6a4a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Thatch floor | A mat of thatch on stakes. The first foundation: walls and roofs stand on it. | data/items/items.json item thatch_floor_kit (#261) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #b8a46a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Thatch roof | Bundled thatch on a frame of sticks. Set it up over your walls. | data/items/items.json item thatch_roof_kit (#263) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #c9bb7a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Thatch doorway | A thatch wall with a gap and a hanging door. Set it up in your wall. | data/items/items.json item thatch_doorway_kit (#265) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #a88d5a; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Oven | A brick oven, built with a hammer next to a clay hearth. | data/items/items.json item oven_kit (#268) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #8a5a42; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |
| Snare | A loop of twine on a bent stick. Set it on a worn animal path. | data/items/items.json item snare (#276) | BasicLook.mesh_for -> shape "kit" (data/items/looks.json), colour #8a7040; held: kit bundle (held_item._make_kit_model) | 2 | BasicLook shape "kit" (32 lines) with a lid emblem per station (weak-looks batch) |

## 16 Placed structures: shelter, storage, fires and traps

13 entries. Stages: 6 x stage 2, 7 x stage 3.


### shelter, storage, fires, traps (13)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Lean to | structure state 5 | data/items/structures.json lean_to (state 5, look "lean_to") | built in code via building_look.gd | 3 | building_look.gd leanto(): forked poles, ridge, rafters, leaf cards, ~900-1500 triangles (ART_DIRECTION.md section 52) |
| Chest | structure state 6 | data/items/structures.json chest (state 6, look "chest") | built in code via building_look.gd chest() | 3 | woven wicker chest ~400 triangles (section 52) |
| Chopping block | structure state 7 | data/items/structures.json chopping_block (state 7, look "chopping_block") | built in code via building_look.gd block() | 3 | wobbly bark block ~300 triangles (section 52); held model also built |
| Plank chest | structure state 6 | data/items/structures.json plank_chest (state 6, look "chest") | built in code via building_look.gd chest() | 3 | same woven chest model as chest (no plank look of its own) |
| Remains | structure state 11 | data/items/structures.json remains (state 11, look "remains") | built in code via building_look.gd remains() | 2 | redrawn: slumped pack, bones, ribs and a rag, four age stages (offline render checked) |
| Carcass | structure state 19 | data/items/structures.json carcass (state 19, look "carcass") | built in code via carcass_look.gd | 2 | species carcass, see creatures |
| Campfire pot | structure state 38 | data/items/structures.json campfire_pot (state 38, look "tripod_pot") | built in code via piece_look.gd tripod_pot() | 2 | piece_look.tripod_pot: tripod, pot, chain |
| Clay hearth | structure state 39 | data/items/structures.json clay_hearth (state 39, look "clay_hearth") | built in code via piece_look.gd clay_hearth() | 2 | piece_look.clay_hearth |
| Snare trap | structure state 46 | data/items/structures.json snare_trap (state 46, look "snare_trap") | built in code via piece_look.gd snare_trap() | 2 | piece_look.snare_trap redrawn: peg, bent arm, wire loop ring, stake (offline render checked) |
| Oven | structure state 45 | data/items/structures.json oven (state 45, look "oven") | built in code via piece_look.gd oven() | 2 | piece_look.oven (stone dome) |
| Campfire (lit, cold, loaded; states 1, 8, 9) | campfire structure | src/shared/structure_look.gd CAMPFIRE_STATES; data/items/structures.json campfire | built in code: building_look.fire(lit, loaded, tier 2): irregular stones, ash, charred logs, flame shader, coals | 3 | section 52 and 'Forge fire' commit; tier flames |
| Survival fire (state 40) | campfire structure | src/shared/structure_look.gd CAMPFIRE_STATES; data/items/structures.json campfire | built in code: building_look.fire(tier 1) | 3 | same builder, small flame |
| Bonfire (state 41) | campfire structure | src/shared/structure_look.gd CAMPFIRE_STATES; data/items/structures.json campfire | built in code: building_look.fire(tier 3) | 3 | same builder, big flame |

## 17 Placed structures: building pieces

30 entries. Stages: 30 x stage 2.


### building pieces (16)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Wall section | structure state 22, material wood | data/items/structures.json wall_section (state 22, look "wall") | built in code via look_table.gd LOOKS[wall] -> piece_look.gd | 2 | textured box slabs (board texture / thatch), no tiers; the six-tier looks in art/BUILDING_TIERS_LOOKS.md are design pictures only and not built |
| Floor section | structure state 23, material wood | data/items/structures.json floor_section (state 23, look "ceiling") | built in code via look_table.gd LOOKS[ceiling] -> piece_look.gd | 2 | textured box slabs (board texture / thatch), no tiers; the six-tier looks in art/BUILDING_TIERS_LOOKS.md are design pictures only and not built |
| Roof section | structure state 24, material wood | data/items/structures.json roof_section (state 24, look "roof") | built in code via look_table.gd LOOKS[roof] -> piece_look.gd | 2 | textured box slabs (board texture / thatch), no tiers; the six-tier looks in art/BUILDING_TIERS_LOOKS.md are design pictures only and not built |
| Foundation section | structure state 25, material wood | data/items/structures.json foundation_section (state 25, look "foundation") | built in code via look_table.gd LOOKS[foundation] -> piece_look.gd | 2 | stone-block rim slab with a packed-earth top, 4 x 4 x 0.3 m: reads as a plinth |
| Doorway section | structure state 26, material wood | data/items/structures.json doorway_section (state 26, look "door_shut") | built in code via look_table.gd LOOKS[door_shut] -> piece_look.gd | 2 | textured box slabs (board texture / thatch), no tiers; the six-tier looks in art/BUILDING_TIERS_LOOKS.md are design pictures only and not built |
| Window section | structure state 27, material wood | data/items/structures.json window_section (state 27, look "window_wall") | built in code via look_table.gd LOOKS[window_wall] -> piece_look.gd | 2 | textured box slabs (board texture / thatch), no tiers; the six-tier looks in art/BUILDING_TIERS_LOOKS.md are design pictures only and not built |
| Door open | structure state 28, material wood | data/items/structures.json door_open (state 28, look "door_open") | built in code via look_table.gd LOOKS[door_open] -> piece_look.gd | 2 | textured box slabs (board texture / thatch), no tiers; the six-tier looks in art/BUILDING_TIERS_LOOKS.md are design pictures only and not built |
| Timber prop | structure state 29 | data/items/structures.json timber_prop (state 29, look "prop") | built in code via look_table.gd LOOKS[prop] -> piece_look.gd | 2 | plain timber posts/rails/rungs: reads as what it is, no texture detail beyond the board material |
| Timber set | structure state 30 | data/items/structures.json timber_set (state 30, look "set") | built in code via look_table.gd LOOKS[set] -> piece_look.gd | 2 | plain timber posts/rails/rungs: reads as what it is, no texture detail beyond the board material |
| Ladder | structure state 31 | data/items/structures.json ladder (state 31, look "ladder") | built in code via look_table.gd LOOKS[ladder] -> piece_look.gd | 2 | plain timber posts/rails/rungs: reads as what it is, no texture detail beyond the board material |
| Path patch | structure state 32 | data/items/structures.json path_patch (state 32, look "path") | built in code via look_table.gd LOOKS[path] -> piece_look.gd | 2 | packed-earth patch with a raised trodden middle and edge stones (offline-checked only) |
| Thatch wall | structure state 37, material thatch | data/items/structures.json thatch_wall (state 37, look "thatch_wall") | built in code via look_table.gd LOOKS[thatch_wall] -> piece_look.gd | 2 | textured box slabs (board texture / thatch), no tiers; the six-tier looks in art/BUILDING_TIERS_LOOKS.md are design pictures only and not built |
| Thatch floor | structure state 42, material thatch | data/items/structures.json thatch_floor (state 42, look "thatch_floor") | built in code via look_table.gd LOOKS[thatch_floor] -> piece_look.gd | 2 | textured box slabs (board texture / thatch), no tiers; the six-tier looks in art/BUILDING_TIERS_LOOKS.md are design pictures only and not built |
| Thatch roof | structure state 43, material thatch | data/items/structures.json thatch_roof (state 43, look "thatch_roof") | built in code via look_table.gd LOOKS[thatch_roof] -> piece_look.gd | 2 | textured box slabs (board texture / thatch), no tiers; the six-tier looks in art/BUILDING_TIERS_LOOKS.md are design pictures only and not built |
| Thatch doorway | structure state 44, material thatch | data/items/structures.json thatch_doorway (state 44, look "thatch_doorway") | built in code via look_table.gd LOOKS[thatch_doorway] -> piece_look.gd | 2 | textured box slabs (board texture / thatch), no tiers; the six-tier looks in art/BUILDING_TIERS_LOOKS.md are design pictures only and not built |
| Rock pile | structure state 33 | data/items/structures.json rock_pile (state 33, look "rock_pile") | built in code via look_table.gd LOOKS[rock_pile] -> piece_look.gd | 2 | heap of twelve faceted RockLook stones (offline render checked) |

### pieces built but not used by any structure row (12)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Brace long | look name brace_long | src/client/look_table.gd LOOKS[brace_long] | built in code via piece_look.gd | 2 | built in piece_look.gd and listed in look_table.gd but no structures.json row uses it yet [unused] |
| Brace mid | look name brace_mid | src/client/look_table.gd LOOKS[brace_mid] | built in code via piece_look.gd | 2 | built in piece_look.gd and listed in look_table.gd but no structures.json row uses it yet [unused] |
| Brace short | look name brace_short | src/client/look_table.gd LOOKS[brace_short] | built in code via piece_look.gd | 2 | built in piece_look.gd and listed in look_table.gd but no structures.json row uses it yet [unused] |
| Door basic | look name door_basic | src/client/look_table.gd LOOKS[door_basic] | built in code via piece_look.gd | 2 | built in piece_look.gd and listed in look_table.gd but no structures.json row uses it yet [unused] |
| Door double | look name door_double | src/client/look_table.gd LOOKS[door_double] | built in code via piece_look.gd | 2 | built in piece_look.gd and listed in look_table.gd but no structures.json row uses it yet [unused] |
| Door plank | look name door_plank | src/client/look_table.gd LOOKS[door_plank] | built in code via piece_look.gd | 2 | built in piece_look.gd and listed in look_table.gd but no structures.json row uses it yet [unused] |
| Door steel | look name door_steel | src/client/look_table.gd LOOKS[door_steel] | built in code via piece_look.gd | 2 | built in piece_look.gd and listed in look_table.gd but no structures.json row uses it yet [unused] |
| Door wrought | look name door_wrought | src/client/look_table.gd LOOKS[door_wrought] | built in code via piece_look.gd | 2 | built in piece_look.gd and listed in look_table.gd but no structures.json row uses it yet [unused] |
| Flat roof | look name flat_roof | src/client/look_table.gd LOOKS[flat_roof] | built in code via piece_look.gd | 2 | built in piece_look.gd and listed in look_table.gd but no structures.json row uses it yet [unused] |
| Floor | look name floor | src/client/look_table.gd LOOKS[floor] | built in code via piece_look.gd | 2 | built in piece_look.gd and listed in look_table.gd but no structures.json row uses it yet [unused] |
| Log wall | look name log_wall | src/client/look_table.gd LOOKS[log_wall] | built in code via piece_look.gd | 2 | built in piece_look.gd and listed in look_table.gd but no structures.json row uses it yet [unused] |
| Water wheel | look name water_wheel | src/client/look_table.gd LOOKS[water_wheel] | built in code via piece_look.gd | 2 | built in piece_look.gd and listed in look_table.gd but no structures.json row uses it yet [unused] |

### placement ghost (2)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Placement ghost and campfire ring | see-through version of the placed model, and a green/yellow ring for campfires | held_item._ghost_clean, _update_blueprint | same model drawn with one see-through material | 2 | functional |
| Grade stakes | Stakes marking a graded road line | src/client/held_item.gd (_stakes) | built in code (_make_stake): wooden post, sharpened foot, red-orange flag | 2 | redrawn from a plain white 1 m cylinder; compiled, not seen in game |

## 18 Stations and furniture

13 entries. Stages: 9 x stage 2, 4 x stage 3.


### stations and furniture (13)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Workbench | structure state 13, tier small | data/items/structures.json workbench (state 13, look "workbench") | built in code via building_look.gd camp_bench() | 2 | BuildingLook.camp_bench (27 lines of mesh) |
| Tool rack | structure state 14 | data/items/structures.json tool_rack (state 14, look "tool_rack") | built in code via building_look.gd tool_rack() | 2 | redrawn: split-log posts, rails, pegs, hanging axe, mallet and saw (offline render checked) |
| Vice | structure state 15 | data/items/structures.json vice (state 15, look "vice") | built in code via building_look.gd vice() | 2 | redrawn: stump bench with jaws, screw and cross handle (offline render checked) |
| Log workbench | structure state 16, tier medium | data/items/structures.json log_workbench (state 16, look "log_workbench") | built in code via building_look.gd log_bench() | 2 | BuildingLook.log_bench: hewn top on trestles, peg rack, vice |
| Saw mill | structure state 34, tier large | data/items/structures.json saw_mill (state 34, look "saw_mill") | built in code via piece_look.gd saw_mill() | 2 | piece_look.saw_mill with water wheel |
| Woodworking table | structure state 35, tier small | data/items/structures.json woodworking_table (state 35, look "woodworking_table") | built in code via piece_look.gd woodworking_table() | 2 | piece_look.woodworking_table |
| Stone forge | structure state 17, tier large | data/items/structures.json stone_forge (state 17, look "stone_forge") | imported model: assets/stations/forge_basic.glb (+5 png) | 3 | Dave's imported forge_basic.glb (falls back to BuildingLook.stone_forge); owner-made, quality not judged by me |
| Blacksmithy | structure state 18, tier epic | data/items/structures.json blacksmithy (state 18, look "blacksmithy") | imported model: assets/stations/forge_medium.glb (+5 png) | 3 | Dave's imported forge_medium.glb (falls back to BuildingLook.masonry_forge) |
| Large forge | structure state 20, tier epic | data/items/structures.json large_forge (state 20, look "big_forge") | imported model: assets/stations/forge_large.glb (+5 png) | 3 | Dave's imported forge_large.glb (falls back to scaled masonry forge) |
| Master forge | structure state 21, tier epic | data/items/structures.json master_forge (state 21, look "big_forge") | imported model: assets/stations/forge_master.glb (+6 png) | 3 | Dave's imported forge_master.glb (falls back to scaled masonry forge) |
| Rough bed | structure state 36 | data/items/structures.json rough_bed (state 36, look "rough_bed") | built in code via piece_look.gd rough_bed() | 2 | piece_look.rough_bed: frame, straw, hide |
| NPC chair | Chair at a chair marker for sitting NPCs | src/client/building_look.gd chair(); used in npc_view.gd line 175 | built in code | 2 | small primitive build |
| NPC bed | Bed at a bed marker for sleeping NPCs | src/client/building_look.gd bed(); npc_view.gd line 179 | built in code | 2 | small primitive build |

## 19 Creatures, animals and NPCs

20 entries. Stages: 4 x stage 0, 10 x stage 2, 6 x stage 3.


### live animals (7)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Rabbit | animal species 1 | data/animals/animals.json (rabbit); src/client/animal_view.gd | built in code, animal_view._make_rabbit | 2 | was 'a simple low-poly rabbit until Art makes a real one' (header); got batch-A details (nostrils, marks); hops |
| Deer | animal species 2 | data/animals/animals.json (deer); src/client/animal_view.gd | built in code, animal_view._make_deer -> _make_quad | 3 | goal 2 batch A (comment): shared four-legged build, tan coat, pale belly/rump, stag antlers on every second one |
| Wolf | animal species 3 | data/animals/animals.json (wolf); src/client/animal_view.gd | built in code, animal_view._make_wolf, animated by _animate_wolf | 3 | own build written to the owner's spec 2026-10-21 (comment) with sneak/trot/gallop/head/tail animation |
| Moose | animal species 4 | data/animals/animals.json (moose); src/client/animal_view.gd | built in code, animal_view._make_moose -> _make_quad | 2 | scaled shared four-legged build with hump, socks, antlers on bulls |
| Fox | animal species 5 | data/animals/animals.json (fox); src/client/animal_view.gd | built in code, animal_view._make_fox -> _make_quad | 2 | shared quad build, bushy tail; the doc lists steal/sneak animations wanted |
| Duck flock | animal species 6 | data/animals/animals.json (duck); src/client/animal_view.gd | built in code, animal_view._make_flock | 2 | 6 to 13 birds spread over the record; doc wants separate goose model, takeoff animation |
| Horse | animal species 7 | data/animals/animals.json (horse); src/client/animal_view.gd | built in code, animal_view._make_horse -> _make_quad | 2 | coat from id, mane and long tail; foals and harness not built (ANIMAL_ART_NEEDS.md) |

### carcasses lying on the ground (7)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Rabbit carcass | dead animal on its side (~300-390 triangles) | data/animals/carcass.json rabbit; src/client/carcass_look.gd | built in code, ellipsoid body + legs + head, per-species row | 3 | goal 2 batch A (header); species row drives size, coat, antlers/beak |
| Deer carcass | dead animal on its side (~300-390 triangles) | data/animals/carcass.json deer; src/client/carcass_look.gd | built in code, ellipsoid body + legs + head, per-species row | 3 | goal 2 batch A (header); species row drives size, coat, antlers/beak |
| Wolf carcass | dead animal on its side (~300-390 triangles) | data/animals/carcass.json wolf; src/client/carcass_look.gd | built in code, ellipsoid body + legs + head, per-species row | 3 | goal 2 batch A (header); species row drives size, coat, antlers/beak |
| Moose carcass | dead animal on its side (~300-390 triangles) | data/animals/carcass.json moose; src/client/carcass_look.gd | built in code, ellipsoid body + legs + head, per-species row | 2 | goal 2 batch A (header); species row drives size, coat, antlers/beak |
| Fox carcass | dead animal on its side (~300-390 triangles) | data/animals/carcass.json fox; src/client/carcass_look.gd | built in code, ellipsoid body + legs + head, per-species row | 3 | goal 2 batch A (header); species row drives size, coat, antlers/beak |
| Duck carcass | dead animal on its side (~300-390 triangles) | data/animals/carcass.json duck; src/client/carcass_look.gd | built in code, ellipsoid body + legs + head, per-species row | 2 | goal 2 batch A (header); species row drives size, coat, antlers/beak |
| Horse carcass | dead animal on its side (~300-390 triangles) | data/animals/carcass.json horse; src/client/carcass_look.gd | built in code, ellipsoid body + legs + head, per-species row | 2 | goal 2 batch A (header); species row drives size, coat, antlers/beak |

### animals with data but no model (4)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Grouse | appears only as a carcass drop row (data/items/carcass.json); no live animal row | data/items/carcass.json species grouse | no live model; carcass_look falls back to the deer body | 0 | no animals.json row, no animal_view builder [unconfirmed] |
| Boar | appears only as a carcass drop row (data/items/carcass.json); no live animal row | data/items/carcass.json species boar | no live model; carcass_look falls back to the deer body | 0 | no animals.json row, no animal_view builder [unconfirmed] |
| Bear | only a creature sound kind (creature_sounds.gd); server_big_game.gd comment lists boar and bear as next | src/client/creature_sounds.gd | none | 0 | no animal row or model [unconfirmed] |
| Fish (swimming) | fish items and schools exist; nothing swims | data/items/fish_schools.json | none | 0 | no client mesh [unconfirmed] |

### NPCs (2)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Hob (merchant) | Shopkeeper NPC | data/npcs/npcs.json roster, outfits.json merchant | ragdoll_body + dress(coat, trousers, shoes) + worn hide_boots and backpack (npc_view._make_body) | 2 | same featureless ragdoll as the player, colour variation only [pending character restyle] |
| Edda (guard) | Guard NPC | data/npcs/npcs.json roster, outfits.json guard | ragdoll_body + dress + worn hide_boots, hide_leggings, hide_hood | 2 | same featureless ragdoll as the player [pending character restyle] |

## 20 Player avatar and worn clothing

17 entries. Stages: 3 x stage 1, 12 x stage 2, 2 x stage 3.


### body (3)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Player body (third person) | 17-bone ragdoll-style character, ~1.86 m, 3.2k triangles | src/client/ragdoll_body.gd; assets/character/README.md | built in code (skinned mesh, 10 animations) | 2 | owner decision 2026-10-21: "no features"; no face, hair or clothing detail beyond dress() [pending character restyle] |
| First-person arms and hands | chest + two arms, 7 bones | src/client/ragdoll_body.gd Ragdoll.new(true) | built in code | 2 | same body; skin colour only [pending character restyle] |
| Fist / bare hand ball | small skin ball at the hand mount | held_item._make_fist | built in code | 1 | single flattened sphere [pending character restyle] |

### worn items (10)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Hide cloak | worn cloak, layer 2 | data/items/worn.json hide_cloak; src/client/worn_look.gd | built in code, builder "cloak" on named bones (hung by worn_sync) | 2 | goal 1f: low-poly boxes/spheres/cylinders under ~150 triangles; not seen rendered [pending character restyle] |
| Grass cloak | worn cloak, layer 2 | data/items/worn.json grass_cloak; src/client/worn_look.gd | built in code, builder "cloak" on named bones (hung by worn_sync) | 2 | goal 1f: low-poly boxes/spheres/cylinders under ~150 triangles; not seen rendered [pending character restyle] |
| Hide hood | worn hood, layer 2 | data/items/worn.json hide_hood; src/client/worn_look.gd | built in code, builder "hood" on named bones (hung by worn_sync) | 2 | goal 1f: low-poly boxes/spheres/cylinders under ~150 triangles; not seen rendered [pending character restyle] |
| Hide boots | worn boots, layer 1 | data/items/worn.json hide_boots; src/client/worn_look.gd | built in code, builder "boots" on named bones (hung by worn_sync) | 2 | goal 1f: low-poly boxes/spheres/cylinders under ~150 triangles; not seen rendered [pending character restyle] |
| Hide leggings | worn leggings, layer 1 | data/items/worn.json hide_leggings; src/client/worn_look.gd | built in code, builder "leggings" on named bones (hung by worn_sync) | 2 | goal 1f: low-poly boxes/spheres/cylinders under ~150 triangles; not seen rendered [pending character restyle] |
| Hide mittens | worn mittens, layer 1 | data/items/worn.json hide_mittens; src/client/worn_look.gd | built in code, builder "mittens" on named bones (hung by worn_sync) | 2 | goal 1f: low-poly boxes/spheres/cylinders under ~150 triangles; not seen rendered [pending character restyle] |
| Grass skirt | worn skirt, layer 1 | data/items/worn.json grass_skirt; src/client/worn_look.gd | built in code, builder "skirt" on named bones (hung by worn_sync) | 2 | goal 1f: low-poly boxes/spheres/cylinders under ~150 triangles; not seen rendered [pending character restyle] |
| Fibre sandals | worn sandals, layer 1 | data/items/worn.json fibre_sandals; src/client/worn_look.gd | built in code, builder "sandals" on named bones (hung by worn_sync) | 2 | goal 1f: low-poly boxes/spheres/cylinders under ~150 triangles; not seen rendered [pending character restyle] |
| Backpack | worn pack, layer 3 | data/items/worn.json backpack; src/client/worn_look.gd | built in code, builder "pack" on named bones (hung by worn_sync) | 2 | goal 1f: low-poly boxes/spheres/cylinders under ~150 triangles; not seen rendered [pending character restyle] |
| Quiver | worn pack, layer 3 | data/items/worn.json quiver; src/client/worn_look.gd | built in code, builder "pack" on named bones (hung by worn_sync) | 2 | goal 1f: low-poly boxes/spheres/cylinders under ~150 triangles; not seen rendered [pending character restyle] |

### held offhand (2)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Torch (held) | torch with light and flame rig | held_item._make_torch_model; flame_up.gd | built in code | 3 | torch review (flame_up.gd comment) |
| Shield (held) | wooden disc with an iron boss | held_item._make_shield_model (line 1261) | built in code | 1 | code comment: "placeholder until art supplies one"; no shield item row exists in items.json [no item row] |

### held (2)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Held spear/axe/knife/other tool models | see tools in category 13 | held_item._make_spear_model etc. | built in code (or BasicLook mesh turned to the held pose) | 3 | tool passes (category 13) [pending character restyle] |
| Shoulder log | large log across the shoulder | held_item.set_shoulder | plain cylinder | 1 | single cylinder [pending character restyle] |

## 21 Particles and effects

10 entries. Stages: 1 x stage 0, 1 x stage 1, 5 x stage 2, 3 x stage 3.


### effects (10)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Campfire flame and coals | flame/coal shader meshes | building_look.gd FLAME_SHADER, _flames(), _coals() | unshaded additive shader on cone meshes | 3 | section 52, 'Forge fire' commit |
| Smoke plume | smoke above fires/forges | building_look._smoke_plume (GPUParticles3D) | GPUParticles3D | 2 | station hooks commit 482 |
| Forge fire and light hooks | fire and smoke empties read from Dave's glb | building_look.add_hooks | particles + light | 2 | ART_DIRECTION.md 'Station meshes from Dave' |
| Quake dust | falling dust and camera shake | src/client/quake_view.gd | CPUParticles3D box emitter | 2 | header; collapse switched off server-side |
| Faint vignette | narrow, blur, fade to black | src/client/faint_effect.gd | screen shader | 2 | owner 2026-10-20 |
| Cave-in skull | grey skull and crossbones drawn on death | src/client/cavein_death.gd _draw_skull | drawn with Control draw calls | 1 | header: "v1 ... drawn skull; Kathleen's art ... drop in"; skull PNG still wanted (archived handoff) |
| Glowing groves (witness tree, everember) | emissive leaves/veins and one soft OmniLight per 24 m of glowing grove | src/flora/flora_view.gd (leaf and ember shaders, GLOW_CELL_M) | shader emission plus OmniLight3D | 3 | built for the fantasy trees; ART_DIRECTION.md does not review it; not seen rendered |
| Far-tree impostors | two crossed quads showing a baked front/side view of each species | src/flora/tree_impostor.gd; ART_DIRECTION.md section 16 | rendered at startup from the live models | 3 | section 16, 19, 20, 36 |
| NPC name labels | name text above an NPC | src/client/npc_view.gd line 183 (Label3D) | Label3D | 2 | functional |
| Rain splashes | sound only; no visual | src/client/rain_splashes.gd | no mesh found (sound detail) | 0 | header describes sounds only [not visible] |

## 22 UI icons, HUD pictures and design pictures

21 entries. Stages: 1 x stage 0, 1 x stage 1, 19 x stage 2.


### icons (files) (1)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| brain_icon.png | inspection-mode symbol | assets/ui/brain_icon.png | imported PNG | 2 | only UI image file in assets |

### icons (drawn) (2)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Thirst drop, oxygen bubble, cover house | status symbols | src/client/status_icons.gd drop_texture/bubble_texture/house_texture | drawn in code | 2 | owner 2026-10-20 list; simple glyphs |
| Coin icons (copper, bronze, silver, gold) | filled circles in the coin colour | src/client/inventory_view.gd coin_icon (line 1093) | drawn in code | 1 | flat circle |

### HUD (4)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Hotbar strip | ten slots along the bottom | src/client/hotbar_strip.gd | Control nodes (text, no item pictures) | 2 | header comment |
| Vitals HUD, heart, bars | health/hunger/thirst/exertion | inventory_view._build_vitals_hud; character_screen.gd | Control drawing | 2 | functional |
| Server link bars | five signal bars | src/client/link_bars.gd | drawn | 2 | functional |
| Horizon look-angle ruler | ruler with ticks | src/client/horizon_indicator.gd | drawn | 2 | functional |

### item pictures (1)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| Per-item inventory icons | none found: inventory lists use text, items are only seen as 3D looks | src/client/inventory_view.gd | none | 0 | grep for icon in inventory_view/hotbar_strip finds only coins and status icons [unconfirmed] |

### design pictures (not in game) (13)

| Name | What | Where | How made | Stage | Evidence / flags |
|---|---|---|---|---|---|
| tiers_all.png | building tier design picture | art/tiers/tiers_all.png | reference image (Kathleen, 2026-10-22/23) | 2 | design art for the six building tiers (art/BUILDING_TIERS_LOOKS.md); the in-game pieces do not match it yet [not in game] |
| tiers_braces.png | building tier design picture | art/tiers/tiers_braces.png | reference image (Kathleen, 2026-10-22/23) | 2 | design art for the six building tiers (art/BUILDING_TIERS_LOOKS.md); the in-game pieces do not match it yet [not in game] |
| tiers_ceilings.png | building tier design picture | art/tiers/tiers_ceilings.png | reference image (Kathleen, 2026-10-22/23) | 2 | design art for the six building tiers (art/BUILDING_TIERS_LOOKS.md); the in-game pieces do not match it yet [not in game] |
| tiers_doors.png | building tier design picture | art/tiers/tiers_doors.png | reference image (Kathleen, 2026-10-22/23) | 2 | design art for the six building tiers (art/BUILDING_TIERS_LOOKS.md); the in-game pieces do not match it yet [not in game] |
| tiers_flat_roof.png | building tier design picture | art/tiers/tiers_flat_roof.png | reference image (Kathleen, 2026-10-22/23) | 2 | design art for the six building tiers (art/BUILDING_TIERS_LOOKS.md); the in-game pieces do not match it yet [not in game] |
| tiers_floor_frames.png | building tier design picture | art/tiers/tiers_floor_frames.png | reference image (Kathleen, 2026-10-22/23) | 2 | design art for the six building tiers (art/BUILDING_TIERS_LOOKS.md); the in-game pieces do not match it yet [not in game] |
| tiers_floors.png | building tier design picture | art/tiers/tiers_floors.png | reference image (Kathleen, 2026-10-22/23) | 2 | design art for the six building tiers (art/BUILDING_TIERS_LOOKS.md); the in-game pieces do not match it yet [not in game] |
| tiers_log_corner.png | building tier design picture | art/tiers/tiers_log_corner.png | reference image (Kathleen, 2026-10-22/23) | 2 | design art for the six building tiers (art/BUILDING_TIERS_LOOKS.md); the in-game pieces do not match it yet [not in game] |
| tiers_plan.png | building tier design picture | art/tiers/tiers_plan.png | reference image (Kathleen, 2026-10-22/23) | 2 | design art for the six building tiers (art/BUILDING_TIERS_LOOKS.md); the in-game pieces do not match it yet [not in game] |
| tiers_roof_pieces.png | building tier design picture | art/tiers/tiers_roof_pieces.png | reference image (Kathleen, 2026-10-22/23) | 2 | design art for the six building tiers (art/BUILDING_TIERS_LOOKS.md); the in-game pieces do not match it yet [not in game] |
| tiers_roofs.png | building tier design picture | art/tiers/tiers_roofs.png | reference image (Kathleen, 2026-10-22/23) | 2 | design art for the six building tiers (art/BUILDING_TIERS_LOOKS.md); the in-game pieces do not match it yet [not in game] |
| tiers_walls.png | building tier design picture | art/tiers/tiers_walls.png | reference image (Kathleen, 2026-10-22/23) | 2 | design art for the six building tiers (art/BUILDING_TIERS_LOOKS.md); the in-game pieces do not match it yet [not in game] |
| Collection_Preview.png | contact sheet of the 12 natural pickup models | assets/natural_pickups/Collection_Preview.png | reference image | 2 | supplied with the pickup models [not in game] |

## Passes and searches

I made **6 passes**, each by a different route; the last two found nothing new that has a visible presence (the fifth added the NPC name label, glow lights and far-tree impostors).

1. **Directory route:** listed `art/`, `assets/` (files other than audio), `scenes/`, `data/` and the markdown files (ART_DIRECTION.md, DESIGN_IDEAS.md, design/, docs/, docs/mirror, docs/archive). Result: 16 glb files (12 natural pickups, 4 forges); image files: 5 grass, 6 ground, 12 tree, 1 UI, 1 pickup contact sheet, 21 forge textures, 12 design pictures in `art/tiers`; 5 `.tscn` scenes (they hold only scripts, no meshes); no `.gdshader`, `.tres` or `.res` files (all shaders are inline in `.gd`). The forge texture PNGs belong to their glb and are not counted separately.
2. **Table route:** walked every row of `data/tables/*.json` (flora 128, rocks 12, soils 17, surficial deposits 8, water classes 6, resources 32, biomes 19, feature types 7, site types 10, province kinds 4) and `data/items/items.json` (273), `gathered.json` (174), `looks.json` (377), `worn.json` (10), `structures.json` (37), `data/animals/*.json`, `data/npcs/*.json`.
3. **Code route (creation calls):** grepped `src`, `scenes` and `tools` for BoxMesh, SphereMesh, CapsuleMesh, CylinderMesh, PlaneMesh, QuadMesh, ArrayMesh, SurfaceTool, GPUParticles3D, CPUParticles3D, Sprite3D, Label3D, MultiMesh, ShaderMaterial, StandardMaterial3D; this found 44 files with visual code (about 27 in `src/client`, `src/flora`, `scenes`; the rest are debug and test tools). Read the builder lists of `tree_builder.gd`, `building_look.gd`, `piece_look.gd`, `basic_look.gd` (per-shape line counts), `held_item.gd`, `animal_view.gd`, `inventory_view.gd`.
4. **Cross-check route:** looks.json ids against items.json + gathered.json (all 377 match; 70 item rows have no looks.json entry: structure rows, species logs, stone/stick/driftwood/log, a few kits); flora rows against the look dictionaries in `tree_builder.gd` (SHRUB_LOOKS 5, GROUND_LOOKS 5, WILDFLOWER_LOOKS 39, HERB_LOOKS 5, CANE_SHRUBS 16, FERN_LOOKS 5, REED_LOOKS 6, GRASS_LOOKS 5, MUSHROOM_LOOKS 10: every flora row has a look except those listed in the gaps); structures.json looks against `look_table.gd` and the dispatcher in `inventory_view._model_for_state`.
5. **Path and name route:** grepped for `res://art` and `res://assets` references (nothing refers to `art/`; `assets/tree_meshes` and `user://tree_meshes` are optional override folders that do not exist), for creature names in data and code (bear, boar, grouse, goose, cart, boat, cow, sheep, chicken, dog: only bear/boar/grouse appear, as sound or carcass rows), and for Label3D, Sprite3D, Decal, Line2D, OmniLight3D (found the NPC name label and the glow lights, now added), plus the archived Kathleen plans and ANIMAL_ART_NEEDS.md for names I had not matched.
6. **Final sweep:** searched code and data for designed-but-absent things (temple, shrine, altar, wagon, cart, boat, bridge, fence, windmill, scarecrow, tombstone, signpost, barrel, crate): none has a model, structure row or table row (the only hits are comments and one barrel-head detail on a tool). Compared my counts to ART_DIRECTION.md section 46 (25 tree species, 22 shrub species: this file has 25 tree rows and 22 rows of kind shrub) and to the table sizes; nothing new.

## Gaps and uncertainties

* **No art critiques exist in the repo.** `art/CRITIQUES/`, `art/MODEL_INVENTORY.md`, `art/MODEL_PLAN.md`, `art/GOAL2_RANKING.md`, `art/REFERENCE_PHOTOS.md` and `art/reference/` are named in the archived Kathleen documents but have no file and no git history here. Stage 3 therefore rests on code comments and archived plans, not on seen critiques; **I did not see any render**, so every stage is a code-reading estimate.
* **No stage 4.** Nothing in the repo claims polish; the closest are the tools (owner called the pickaxe "excellent") and the owner-made forge glbs.
* **Without a model of their own** (flora): no flora tree is at stage 1 any more (tropical hardwood, acacia, mangrove and the three palms got builders in the stage-1 trees pass, unrendered); the generic `Mushrooms` row now has its own look.
* **Table rows with no visible presence found:** ores/mineral resources (31), surficial deposits (7), site types (10: cave, mineshaft, labyrinth, lair, landmark, harbor, town site, ruin, shipwreck, spawn point), fish, bear, boar, grouse as live animals. Marked `unconfirmed` because I only grepped `src/client`.
* **Design-only art that is not built:** the six building tiers (art/BUILDING_TIERS_LOOKS.md, art/tiers/*.png) are pictures; the pieces in game are board-textured boxes plus thatch; `log_wall`, `flat_roof`, doors and braces exist as builders but no structure row uses them.
* **Placeholders in code:** shield (no item row), shoulder log cylinder, felled trunk cylinders, remains boxes, tool rack and vice boxes, coin circles, ocean ice slabs, cave-in skull drawing.
* **Items drawn from a fallback or a 3-4 line shape (stage 1):** most foods, wood products, bundles and bottles; the tool shapes are the only item group at stage 3.
* Counts of `future` item rows use the key literally; the repo does not define it beyond the flag.
* Quality of the imported glb forges and natural pickups could not be judged from files alone.
