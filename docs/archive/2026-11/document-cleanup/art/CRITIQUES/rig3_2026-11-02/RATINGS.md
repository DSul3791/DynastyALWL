# Ratings of the rig3 batch (Kathleen, 3 Nov 2026)
Pictures on branch `claude/pics-rig3-20261102`. Scale 1 to 5 (4 = reads as the real thing at 10 m).

| Picture | Rating | Note | Next |
|---|---|---|---|
| fell_before / fell_falling | 3 | The trunk falls and lies with bark that reads as bark. Seen end-on from the stump, so the length and the cut end are not checked. | One side-on shot: 4 m to the side of the lying trunk, agl 1.6, pitch -10. |
| apples | 2 | The crowns are dark walls of leaves down to about 2 m. Each leaf card reads as hand-sized at 5 m, and the apples (two red dots) are hidden inside. | Look fix in tree_builder.gd (with Kathreen): smaller leaf cards on apple trees, a lighter underside, and fruit hung on the outer shell of the crown. Then reshoot. |
| orchard_wide | none | The camera is inside foliage again. | Waiting on the 68556 rerun. If that is also in leaves, use agl 14, pitch -20 from the same spot. |
| ground_grass30m | 3 | The meadow and orchard edge read well. The grass hides the ground completely, so #57 can't be judged here. | - |
| ground_nograss | none | A flat pale wash with no terrain drawn. This is a rig problem, not the look. | Retry with grass on and the camera pitched down at a path or gravel patch (spawn path, agl 1.6, pitch -35). |
| firewood_kindling | none | The sheet ran on main, where firewood is still the old "bundle" at size 1.6. PR #60's split billets are not in it. | Reshoot the item sheet from branch `claude/kathleen-wood-looks-20261102` (now merged with main). |
| seal_sheet | 3 | The blotches now sit on the skin (fixed). The hind flippers still read as two flat discs. | Later: one tapered fan per flipper, not a squashed ball. |
| gull_sheet | 3.5 | A clear herring gull standing: grey back, black tips, yellow bill, pink legs. | Take-off: `--animal=gull_flock --fly` (added in this branch). |
| trout_close | 2 | The spots stood up like studs and floated off the body near the ends. The tail was a square box. | Fixed in this branch: spots pressed flat onto the skin, red spots with pale rings on the flanks, a forked tail. Reshoot `--animal=trout --height=0.4 --pitch=-10`. |
