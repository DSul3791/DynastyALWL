# Animals look review, round 1 (Kathreen, 2 Nov 2026) - read-only, from existing critiques

Source: `data/animals/animals.json` (13 species) against `art/CRITIQUES/fauna_2026-10-30/CRITIQUE.md` (Kathleen's offline four-view ratings, 0 none .. 3 reads clearly). No new pictures yet: ratings below are hers, not mine, and none is seen in the real game at 10 and 30 m.

| # | Species | Model | Rating (offline) | Note |
|---|---|---|---|---|
| 1 | rabbit | `_make_rabbit` | 3 | to reach 4: fur tone variation, ear inner white, feet merged |
| 2 | deer | `_make_deer` | 3 | legs thin boxes, two-blob body |
| 3 | wolf | `_make_wolf` | NOT RATED | no picture in any critique |
| 4 | moose | `_make_moose` | NOT RATED | shares the quad builder, "look at them next" (never done) |
| 5 | fox | `_make_fox` | 3 | ears thin and dark |
| 6 | duck | `_make_flock` | NOT RATED | no picture |
| 7 | horse | `_make_horse` | NOT RATED | shares the quad builder, never looked at |
| 8 | boar | `_make_boar` | 2-3 | slab body, box legs, bristle ridge barely shows |
| 9 | songbirds | `_make_songbird` | 3 | robin; flight pose missing |
| 10 | frog | `_make_frog` | 3 | webbed feet, spots missing |
| 11 | grouse | `_make_grouse` | 3 | barring missing |
| 12 | seal | `_make_seal` | 2 | blotches hover above the skin, small flippers |
| 13 | seabird | `_make_seabird` | 3 | flight pose missing |
| - | trout (fish, not in animals.json) | `_make_fish` | 2 | spots read as studs, plain box tail |

## Findings
1. Four of the 13 live species (wolf, moose, duck, horse) have never been pictured or rated. The wolf is the animal players meet at night, so it is the first to picture.
2. Weakest three by existing rating: seal (2), boar (2-3), trout (2). Fix order proposed: seal blotches and flippers, boar back ridge and legs, trout spots and tail. Needs a picture after each edit, so waits for a Godot run.
3. `KIND_OF_SPECIES` in `src/client/animal_view.gd` lists only species 1-7. Boar, songbirds, frog, grouse, seal and seabird are missing, so `state_changed` (voices, steps) never fires for them. That is a sound wiring gap (Jason/Steve), not a look; flagged here only.
4. Nothing was seen in the real game; every rating is offline, without game light.

## Needed from a Godot run
`tools/animal_sheet.gd` (or `animal_gallery.gd`) for wolf, moose, duck, horse into `art/CRITIQUES/animals_review_2026-11-02/`, plus one in-game shot each at 10 m and 30 m for wolf and deer. Then I rate and fix the weakest three.
