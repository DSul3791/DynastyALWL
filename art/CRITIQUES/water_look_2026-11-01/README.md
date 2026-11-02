# Water look, real game, 1 Nov 2026 (Kathreen), baseline before any change
- sea.png (54728,75530, 12 m up, facing S, water2 default): blue, clear, sun glints and mirrored clouds read well; BUT the swell makes a regular lattice of oval cells (four pure sine waves) that looks computed, no foam or shore in view. Rating 3.5 of 5.
- river.png (53302,68440, facing N): MISSED, the river is a thin strip far ahead (about 50 m, between trees at the top); camera sees grass only. Not rated. Retake from the bank.
Change prepared, NOT run: `water_material.gd` `sea_slope` crest modulation (slow cross-crest amplitude) to break the lattice. After the moderator's go: retake sea.png at the same spot, compare, keep only if better.
Not possible yet: lava/swamp glow (needs an emission uniform and Sonny's kind data), real flow (needs Sonny's flow channel).
