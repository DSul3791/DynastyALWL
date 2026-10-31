# First-hour fauna: state of the existing models (2026-10-30, Kathleen)

Source of the list and sizes: Sal's ANIMAL_SPEC.md and data/animals/fauna_proposal.json (origin/sal-items). Pictures: offline four-view renders of the models in src/client/animal_view.gd through tools/animal_sheet.gd (no game light; the real game needs the rig, which is unreliable after the daily merge, see ITEM notes). Rating 0 none, 1 primitive, 2 basic but recognisable, 3 reviewed and improved. "Next" is the improvement queue.

| Species | Picture | Critique | Rating | Next to improve |
|---|---|---|---|---|
| Rabbit (live) | rabbit_round1_before.png | an egg body with a round head, two straight sticks for ears and a white ball tail: reads as a rabbit only by ears and tail; no haunch (the rounded hindquarters are the rabbit silhouette), head too round and no muzzle, ears should be long ovals | 2 | big rounded haunch, smaller forebody, long oval ears, pointed muzzle with pale chin, tail a small tuft |
| Fox (live) | fox_round1_before.png | body as two blobs split by a white band, neck made of a chain of beads, tail a huge flat wedge, ears thin black sticks, legs thin tubes, face a grey box: weak, severity 3 | 2 | one smooth body, neck as a tapered tube, a bushy tapered tail with white tip, triangular ears, sharper muzzle with white cheeks, dark socks |
| Deer (live) | deer_round1_before.png | antlers carry it; neck is a bead chain, head a dark box, body two blobs, legs thin: reads as a deer from the side | 2 | smooth neck, wedge head with pale muzzle and eye ring, ears as leaf shapes, a deeper chest, pale rump patch bigger |
| Boar (no spawn row yet) | - | not modelled | 0 | stocky wedge body, high shoulder, big head with tusks 0.2 m, bristle ridge along the back |
| Songbird, frog, trout | - | not modelled | 0 | small bodies with simple hop / swim / perch hooks |

The three live models share one builder (`_make_quad`) whose node names (Rig, Head, Tail, Leg_*, Ear_*) the animation code uses: improving shapes inside those nodes keeps animation unchanged, so fixes help every four-legged animal at once (neck and head first).

## Rounds 2 to 4: shared four-legged builder (deer, fox, horse, moose), offline

| Round | Picture | Change | Result |
|---|---|---|---|
| 2 | fox_round2.png, deer_round2.png | the bead-chain neck became five overlapping, thinning segments; a jaw ball so the head tapers; ears as leaf-shaped ovals | neck now reads as one tapering neck; ears better |
| 3 | fox_round3.png, deer_round3.png | muzzle a tapered ball with a dark nose instead of a box; fox brush shorter, thickest in the middle with a white tip; fox and deer lose the pale belly ball that showed as a white band mid-body; deer neck 0.5 to 0.42 | fox: one smooth body, white muzzle, brush with white tip: reads as a fox (3). deer: tapered muzzle and nose, reads as a deer (3) |
| 4 | deer_fox_rabbit_round4.png | check of all three side by side | consistent style; rabbit still the old model |

New ratings (offline, no game light, not yet seen in the real game): fox 3, deer 3, rabbit 2 (unchanged: needs haunch, long ears, muzzle). Horse and moose use the same builder and inherit the neck, head and ear changes unchecked: look at them next. Remaining flaws seen: legs still thin straight boxes, bodies two joined blobs, fox ears thin and dark. test_animals: 1 failure, the known 150-animal server timing check (3.4 ms against 3 ms on this loaded machine), unrelated to shapes.
