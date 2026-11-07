# Creature integration progress (MikeW)

Dave, 7 Nov 2026: integrate the bought, rigged animal and creature models into the game; progress is counted in finished, working creatures.

## The pipeline (reuse it for every creature)
1. **Install**: `python tools/install_animal_models.py --pack "<pack folder>" [--kinds=elk]` copies each row's `pack` folder from `data/animals/models.json` into the scene's folder (never committed). It skips `.blend` files: with one beside the `.fbx`, the headless import writes no `.import` at all.
2. **Import**: `godot --headless --path . --import`.
3. **Check**: `godot --path . --script res://tools/creature_check.gd -- --kinds=elk --out=<folder>` (needs a window). It builds the creature with the game's own animal view and writes `<kind>.png` (rest pose plus every role clip, side view on a 1 m grid) and `report.txt` (file, drawn or code body, length, the clip for each role, how tall it stands in each, the view's notes).
4. **Fix** in the model row (clip names per role, materials, length) or, when a whole class of file is wrong, in `src/client/animal_view.gd` once for all creatures.
5. **Game data** (new species only): the donkey's recipe in `design/ANIMALS_BATCHES.md`.

What the animal view already does for every model (do not rebuild): size from the skeleton or the skinned mesh, feet on the ground, skin binds rebuilt when they disagree, clip positions rescaled to the skeleton's units, clips that lay the body flat refused (and the next clip for the role tried), clip travel (root motion) taken out with walk and run played at the clip's own travel speed, textures by material name, fur cards cut out.

## Done means
1. Installed and imported. 2. Drawn from the model, right length, facing its travel, feet on the ground. 3. Every role it uses (graze, alert, walk, run; warn and charge for fighters) plays a standing, fitting clip. 4. No clip carries the body away. 5. Server row, spawn biomes, carcass, sign, season and step sound in place, animal tests green. 6. Seen in the live game (shot runner or Dave).

## Summary (7 Nov 2026): done in the model check 35 species (36 models with the calf); in progress: none; waiting for the live-game check: all 35; blocked: none.

## Status (7 Nov 2026, creature check pictures in E:/Software/godotDev/creature_check)
| Creature | Species | 1-5 | 6 live game | Notes |
|---|---|---|---|---|
| Brown bear | 14 | done | waiting | Run and Sprint carried the body 6 to 10 m/s ahead: travel now taken out |
| Deer | 2 | done | waiting | |
| Moose | 4 | done | waiting | |
| Duck (flock) | 6 | done | waiting | Was a code flock; now each flock is 6 to 13 duck models that swim, look up and fly (flock_of) |
| Wild boar | 8 | done | waiting | |
| Wolf | 3 | done | waiting | Idle is a howl: alert and recover now Idle_Breathing |
| Fox | 5 | done | waiting | |
| Rabbit | 1 | done | waiting | |
| Horse | 7 | done | waiting | Walk and gallop travel taken out; no graze clip, an idle stands in |
| Donkey | 15 | done | waiting | |
| Goblin (Skritch, Rukz) | 16 | done | waiting | Was drawn about 85 times too big (skinned box read through the wrong node): fixed |
| Lynx | 17 | done | waiting | Its idle is a low, stalking stance; a taller idle is polish |
| Black bear | 18 | done | waiting | |
| Elk | 19 | done | waiting | Vanished while walking (a second Walk clip shrinks the rig to 1%): walk is Walk_2, graze is Idle |
| Bighorn sheep | 20 | done | waiting | Its Idle_Breathing lies down: alert stands in Idle |
| Mountain goat | 21 | done | waiting | |
| Beaver | 22 | done | waiting | Grazes sitting up (Idle_2); does not swim |
| Chamois | 23 | done | waiting | Idle_3 grazes, Alert stands |
| Mink | 24 | done | waiting | No looping walk or run in the file: its start clips loop instead; alert stands up |
| Raccoon | 25 | done | waiting | "dead run" was being picked as its run: death and hit clips are never picked by role words now |
| Rat | 26 | done | waiting | Grazes sitting up |
| Crow | 27 | done | waiting | Imported with wings spread: sized and grounded by its Walk pose (size_clip); feathers reach twice past its bones |
| Pheasant | 28 | done | waiting | Walks on the ground, does not fly yet |
| Goose | 29 | done | waiting | Walks on the ground, does not fly or swim yet |
| Cow (and calf) | 30 | done | waiting | Farm: not spawned wild until the farm system places it. Its young are drawn from the calf model (young_model) |
| Goat | 31 | done | waiting | Farm. Was invisible: its texture's alpha is not a cut-out (material entry "opaque") |
| Chicken (hen, rooster) | 32 | done | waiting | Farm. Two looks of one species, each with its own clips |
| Cat | 33 | done | waiting | Farm. Grazes sitting |
| Dog (labrador, bloodhound) | 34 | done | waiting | Farm. Two looks; the bloodhound has no bark clip |
| Puma | 36 | done | waiting | Imported crouched: sized by its standing pose; roars when it warns |
| Pronghorn | 37 | done | waiting | Same rig as the elk (walk is Walk_2); fastest runner on the island |
| Wild ox (pack buffalo) | 35 | done | waiting | Wild, grassland herds, stands its ground |

New species are added with `python tools/add_species.py <spec.json>` (specs for batch 2 in E:/Software/godotDev/specs on the PC); `--clips` on the creature check lists a file's clips.

## Next
- Farm animals need the farm and town system to place them (design to come).
- Birds fly and geese swim: later, needs flight and swimming on the server.
- Live-game check (point 6) for every creature, once 538, 540 and this batch are merged and the models are on Dave's PC (through Dino).
- Left in the pack, wrong world for the island: see design/ANIMALS_BATCHES.md.
## Blocked: none.
