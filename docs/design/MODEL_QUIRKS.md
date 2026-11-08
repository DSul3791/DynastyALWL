# Model-file quirks met so far, and what a new model must bring (MikeW, 8 Nov 2026)

A reference for the models Dave makes in Meshy (eagle, raven, owl, bat, a mink and crow replacement) and anything bought later. Every quirk below cost a fix; a new model that avoids them drops in with a row and a creature check.

## What every new model must bring
1. **One rigged mesh, rest pose standing** (four-legged animals on all fours, birds with wings folded, bats folded). A rest pose mid-run, crouched, lying or wings-spread is sized and grounded wrongly (we then need `size_clip`).
2. **Clips that do not travel (in place)**, or travel only on one root node. Both work (travel is taken out and measured), but in-place is simplest.
3. **A looping clip for every role it will play:** graze or idle, alert (head up, standing), walk, run; warn and charge for fighters; swim for swimmers; fly and glide for fliers; sit and lie for companions. Transitions (start, stop, turn, "to") are fine extra, never the only walk or run.
4. **Clip names that say what they are** (`Walk`, `Run`, `Idle_Alert`), no duplicates with the same name, no clips that scale or move the whole rig.
5. **Separate eye surfaces** (an `Eye` material or eye bones), so the eye can carry a highlight and torchlight shine.
6. **Textures whose alpha is either a real cut-out (fur cards) or full**; nothing else stored in alpha.
7. **Named bones for the tail, ears, neck, head, jaw and chest**, so tail motion, ears, breathing, head tracking and posed states can use them. Any naming works; the row maps the names.
8. **No .blend file beside the .fbx** in the install folder (the headless import then writes nothing).

## Quirks met, by kind
| Quirk | Seen in | Fix we built (row key or code) |
|---|---|---|
| Clip travel on the root node (body runs ahead and snaps back) | bear, horse, elk, pronghorn, camel | travel taken out, clip speed measured (`_strip_root_drift`) |
| A clip lays the body flat or shrinks the rig | bear (tube), elk (`Walk` at 1%) | flat-clip guard, next clip tried; `flat_share` for low or bending animals (kangaroo, alligator) |
| Two clips with the same name | elk, pronghorn (`Walk` twice) | row names the right one (`Walk_2`); the guard skips the broken one |
| Clip units differ from the skeleton | bear | positions rescaled (`_fit_clip_units`) |
| Skin binds disagree with the skeleton | some FBX | binds rebuilt (`_fit_skin`) |
| Skinned mesh sized through the wrong node (85× too big) | goblin | skinned box through the bind |
| Rest pose not standing | crow (wings spread), puma, lion, warthog, guineafowl (crouched or mid-run) | `size_clip` |
| Feathers far past the bones | crow | `length_m` set as the bone length |
| Clip names that lie | wolf `Idle` is a howl; bighorn `Idle_Breathing` lies down; raccoon `dead run` | row names the clip; role words skip death, hit, attack, start, end, stop, interact |
| No looping walk or run, only start clips | mink | `clip_loop` (a window of a start clip, ends eased) and a hand-made `gait` fallback |
| No swim clip | beaver, moose | walk stands in; hand-made swim `gait_fallback` |
| No jaw-pop clip | black bear | `state_poses` (a pose built from bones) |
| Hunched pose held by every clip | crow | `bone_offsets` |
| Texture alpha that is not a cut-out (invisible model) | goat, two deer looks | material entry `"opaque": true` |
| Two texture sets on one mesh | camel (a pink leg) | material entries by surface name |
| Eyes painted on the body, no eye surface | 39 of 45 rows | `eye_bones` or `eye_offset` (glossy eyes added) |
| Slow walk clips played fast (feet slide) | fox, deer, wolf, cat walks | clip speed measured from planted feet (#591); hopping animals bound (`hop`) |
| A file with no tail, ear or breathing motion in its idles | most | `tail_motion`, `ear_motion`, `breath` |
| `.blend` beside the `.fbx` | every pack folder | the install tool skips it |
| First headless import crashes (exit 139) | a fresh worktree | the install tool retries the import once |

## The check for a new model
`python tools/install_animal_models.py --kinds=<kind> --import=<godot>` then `godot --path . --script res://tools/creature_check.gd -- --kinds=<kind> --clips` (and `--head` for the eyes): every role column standing and right, length right on the 1 m grid, no notes about refused clips.
