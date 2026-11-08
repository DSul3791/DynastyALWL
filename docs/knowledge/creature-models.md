# Creature models: bought rigged animals in the game

**Last checked:** 2026-11-07 (our own work; no web research yet). **System owner:** MikeW. **Related:** `design/ANIMALS_BATCHES.md` (recipe and batches), `design/CREATURE_PROGRESS.md` (status), `data/animals/models.json`, `src/client/animal_view.gd` (`_make_model`), `tools/install_animal_models.py`, `tools/creature_check.gd`, `tools/add_species.py`.

## Lessons (read these first)

1. **Look at every clip before calling a creature done.** Names lie: the wolf's `Idle` is a howl, the bighorn's `Idle_Breathing` lies down, the elk has two clips called `Walk` (one static, one shrinking the rig to 1%), the raccoon has a clip called `dead run`. `tools/creature_check.gd` draws every role clip side by side; `--clips` lists them all.
2. **Fix a whole class of file once, in the animal view, not per creature.** Root motion, refused clips, skinned sizes and texture alpha are all handled in `animal_view.gd` for every model. A row only names clips, materials and size.
3. **Clips can carry the body (root motion).** In the WildMesh files the travel is on the `RigRoot` node above the skeleton. Left in, the body runs ahead of the animal and snaps back at every loop. The view takes the steady horizontal travel out and plays walk and run at the clip's own travel speed, so feet do not slide.
4. **The imported pose may not be standing.** The crow is imported with its wings spread; sizing by that pose drew it far too big and floating. `size_clip` sizes and grounds a model by a clip's first frame.
5. **Bones are not the skin.** A bird's feathers reach twice past its bones; set its `length_m` to the bone length. A skinned mesh's box must be read through its bind, not its node (the goblins were 85 times too big).
6. **A texture's alpha is not always a cut-out.** The goat's alpha is nearly all zero; drawn as a cut-out it was invisible. Mark that material entry `"opaque": true`.
7. **Never install a `.blend` beside the `.fbx`.** With one there, the headless import writes no `.import` at all. The install tool skips them.
8. **Model files never go in git** (public repo). `/assets/animals/` is ignored; the install tool copies them from the pack on each machine.

## How ours works
- Install: `python tools/install_animal_models.py --pack "<pack>" [--kinds=...]` (row `pack` folder; also each variant's and `young_model`'s own pack).
- Check: `godot --path . --script res://tools/creature_check.gd -- --kinds=elk --out=<dir> [--clips] [--id=N] [--young]` (windowed).
- New species: `python tools/add_species.py spec.json` adds the server row, model row, carcass look and parts, season, sign, step sound, species number, code stand-in and the animal tests' newer-species lists.
- Row keys: `scene`, `pack`, `clips` (role to clip name or list), `materials` (`match`, `albedo`, `opaque`, `hide`), `length_m` or `height_m`, `size_clip`, `bounds`, `variants` (looks picked by id), `young_model` (the young drawn from its own model, at its own size).

## What we tried
| Date | What | PR | Result |
|---|---|---|---|
| 7 Nov | Flat-clip guard (bear tube) | #509 | Worked; now also counts tracks above the skeleton and falls back to the next clip |
| 7 Nov | Root motion taken out, walk and run at clip speed | #538 | Worked (bear, horse, elk) |
| 7 Nov | Skinned mesh box through its bind | #538 | Worked (goblins) |
| 7 Nov | Death, hit, start, end and stop clips never picked by role words | #540, young-model PR | Worked (raccoon, cow) |
| 7 Nov | Size by a clip pose (`size_clip`) | #540 | Worked (crow) |
| 7 Nov | Solid-texture flag (`opaque`) | #542 | Worked (goat) |
| 7 Nov | Young animal drawn from its own model (`young_model`) | young-model PR | Worked in the check (calf) |

## Decided / next
- Farm animals do not spawn wild; they wait for the farm and town system (coordinator, 7 Nov). Horses, donkeys and the wild ox stay wild.
- Birds fly and geese swim: later, needs server work.
- Every creature still needs its live-game check (point 6 in `design/CREATURE_PROGRESS.md`).
