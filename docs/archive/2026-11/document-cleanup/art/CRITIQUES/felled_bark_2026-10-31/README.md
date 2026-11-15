# Felled trunk, stump and log bark in the real game (guide: dark smooth pipe), 2026-10-31, Kathleen

Cause: the bark shader and species texture were applied (993aafab), but standing trees get their warm brown from baked vertex colours (`_crown_shading` warms and shades the bark), which a plain felled cylinder lacks. The tint (oak 0.44, 0.40, 0.36) is a warm grey; lit by sky it read cool dark grey, about half as bright as a standing trunk.

Fix: shader uniform `lift` (vec3, default 1) in the flora_view BARK_SHADER; inventory_view `_felled_bark` sets (3.0, 2.0, 1.3), brighter and warmer, and gives softwood species with no tint constant the brown softwood tint.

Pictures (real game, same rig and spot as the guide's picture):
- before/ : fell_resting.png (stump and log block), fell_falling.png (lying trunk)
- after3/ : final fix, fell_resting.png (stump and log block, brown and textured)
- after/, after2/, dbg/ : intermediate steps (lift 2.0, grey; softwood tint; debug run), kept for the record.

Rating 3.5 of 5 for the stump and block. The lying trunk was only re-shot with the intermediate lift (grey), not after the final one; the stump side still looks smooth and the log is a plain block.
