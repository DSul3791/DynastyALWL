# Critique: stage-1 trees, seen in the real game (2026-10-30, Kathleen)

Pictures taken with `tools/look_rig.sh --flora <species> --summer` at the spawn point (53301, 68427), 12:00 clear, in the real client with real light, shadows, bark and leaf textures. Stills here are 1500 px JPEG copies of the 2880x1620 originals. Severity: 1 minor, 2 should fix, 3 must fix.

| Species | Picture | Flaw | Sev | Action |
|---|---|---|---|---|
| Acacia | acacia_v1_mid.jpg | limbs climbed steeply like a vase, crown was round puffs, not a flat umbrella | 2 | fixed: fork higher, limbs near level, flat canopy layer (acacia_v2_mid.jpg) |
| Acacia | acacia_v2_mid.jpg | the canopy is still made of ball-shaped leaf clumps, so the umbrella reads lumpy; leaves are bigger than real acacia's feathery leaflets | 1 | open: needs a flat-clump variant of `_clump` or a feathery leaf card |
| Mangrove | mangrove_v1_mid.jpg | stilt roots like thin spider legs; crown a ball on a long thin stalk | 2 | fixed: stouter trunk, 16-20 shorter roots, lower crown (mangrove_v2_mid.jpg) |
| Mangrove | mangrove_v2_mid.jpg | roots are still dark and straight-sided; real prop roots curve and fork | 1 | open: add forking and curve |
| Wild banana | banana_v2_mid.jpg | reads as a banana plant (stout stem, big leaf rosette); bunch is tiny and hidden | 1 | open: bigger hanging bunch |
| Coconut, date palm | palms_far.jpg, palms_mid.jpg | read as palms; fronds look thin and pale at a distance, the two crowns overlap in a tight row | 1 | open: fatter frond cards, darker tint |
| Row of three | row_v0_overlap.jpg | the rig row is too tight for the tall trees (tropical hardwood trunk fills the frame) | n/a | use one species per run |
| Tropical hardwood | hardwood_v2_far.jpg | reads as a tall rainforest tree (slim bole, high dark crown); the bark spots look like leopard blotches on such a tall trunk; buttress roots barely show at this scale; the crown is mostly above the frame | 1 | trunk slimmed to 0.7 x listed width (done). open: finer bark texture for tall trunks, bigger buttress fins |

Source of the method: the in-repo rig (`tools/look_rig.sh`) and the offline preview scripts I wrote in the session scratchpad (Godot SubViewport, vertex colours, leaf textures, no game tint) which were used for the first-pass shape checks only.
