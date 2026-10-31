# Beach props (Kathleen, 2026-10-31; Sonny keeps the ground colours and the foam)
Pebbles and driftwood already existed (grass_view pebble layer, pickable driftwood and stones on banks). Added two look-only shore layers in src/client/grass_view.gd: `shells` (scallop fan, cream/pink/blue-grey, dry strand within 0.7 m of water) and `wrack` (five wavy dark seaweed ribbons, within 0.3 m of the edge). They use the pebble pipeline, so they fade with shore_m and vanish with it.
Round 1: wrack read as starfish (radial ribbons). Round 2: ribbons laid roughly parallel and crossing, thick middle: now a dark kelp tangle. Pictures: round1.png, round2.png (tools/beach_view.gd).
Ratings: shells 3-4 (read clearly as scallops), wrack 3, pebbles unchanged.
Next: a second shell type (a cone or spiral), wrack with round bladders, tint wrack lighter when dry; not seen in the real game (rig busy).
