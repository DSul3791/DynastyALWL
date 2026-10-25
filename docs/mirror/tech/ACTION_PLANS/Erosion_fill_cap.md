# Erosion pre-carve: cap the hill-foot fill (BAKE; delta file only, one plan)
Branch claude/erosion-fill-cap from claude/erosion-delta-real 1766b55. Owner: Sonny's finding (25 Oct): the delta near spawn (x53748-53836 z68522-68602) is +49 to +77 m, delta slope up to 1.39 m/m.
Plan, tool change only (tools/erosion_precarve/precarve.py, no Godot code):
1. Soft-cap fill: delta > 0 becomes 12 * tanh(delta / 12) (max +12 m); cuts unchanged.
2. Smooth the delta where its own slope exceeds dslope (0.25 m/m): six passes of a Gaussian blend weighted by the local delta gradient. Params fill_max, dslope in the manifest.
3. Re-run the real heights twice: erosion_delta_v2.bin byte-identical (cmp), new sha256 in the manifest.
Tests: delta stats at spawn box (x53600-53900 z68400-68700): fill range, max delta slope (target under 0.3 m/m); max fill over the island; 8 m summit, river mouths, walkable shares vs run 1766b55 (summit 1246, 18 mouths, 94% under 25 deg below 600 m); parse_scan, local_check unchanged (no GDScript change).
Best-practice question for Tyler: soft cap plus gradient smoothing, or limit the sediment deposition itself (dep_frac, per-step cap) in the model so the fill never forms? I lean to the post-cap because it is cheap and exact; the model change would shift everything.
Label BAKE (delta ships with the final bake; no bake needed to decide).
