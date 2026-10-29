# Action plan: metal surface for tool heads (Kathleen, to Tyler, BP-T52)
Branch: claude/kathleen-weak-looks (after gate b055e79b lineage; pickaxe shape locked at 0adac7c6).
Ask: Dave wants the pickaxe head a metallic charcoal. Look meshes (src/client/basic_look.gd) use one vertex-colour material, roughness 1.0, so no sheen is possible.
Change: a part may carry a fourth entry `metal`; `mesh()` builds one extra surface for the metal parts with a second shared material (metallic 0.8, roughness 0.4, vertex colour albedo). Geometry unchanged, so silhouettes are identical. Only the pickaxe head is flagged at first; other tools can opt in later.
Cost at Low: one extra draw call per pickaxe (2 surfaces instead of 1), no new textures, no shader, no new triangles. Pickaxes are only drawn held or lying near the player, so at most a handful of extra calls.
Readers of surface 0: none for looks. held_item.gd (lines 348, 1301) and inventory_view.gd (2334) use the whole Mesh (aabb, MeshInstance3D); the pickup glow in inventory_view.gd loops over every surface. My test src/worldgen/tools/test_pick_axes.gd reads surface 0 and will be changed to read all surfaces.
Risk: low. Rollback is dropping the flag. Needs: Tyler OK.
