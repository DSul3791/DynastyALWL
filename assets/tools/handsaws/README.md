# Optimized handsaw assets

Prepared at Dave's request, 15 November 2026. Only optimized copies are included; the original Meshy exports are retained by Dave and are not uploaded.

| GLB | Triangles | Source triangles |
|---|---:|---:|
| Handsaw_Copper_Optimized.glb | 4,800 | 338,932 |
| Handsaw_Bronze_Optimized.glb | 4,800 | 179,426 |
| Handsaw_Iron_Optimized.glb | 4,800 | 110,194 |

All files are under the requested hard 5,000-triangle limit. Each is one static mesh primitive/material with embedded 2K PBR textures. Base-color and metallic/roughness texture pixels are preserved; tangent normals were re-baked from the source geometry onto the reduced mesh. No rig, animation or collision mesh was added.

## Verification
- GLB structure/triangle counts inspected after export.
- Exported files successfully reimported into Blender and rendered for visual comparison.
- Uploaded Git blob hashes match the local exported bytes.
- Geometry reduction changes fine teeth, wrapping and surface shading; close-up material/normal-map review remains appropriate, particularly the iron blade's broad surface. These are candidate game assets, not a claim of final in-engine visual acceptance.
- No Godot startup, import, equipped-tool or gameplay tests were run here.

## Integration for Claude
Source dimensions and centered origins were retained (approximately 1.9 m overall). Set sensible final scale, grip attachment and orientation in the project's tool scenes. Bronze should be about 20% longer overall than copper as discussed, rather than using equal-length normalized exports. Verify held and dropped appearances, PBR/normal shading, tooth silhouette, bounds and LODs under Godot lighting. Asset upload alone does not wire these models into item visuals or alter recipes/gameplay.

Dave's latest Copper Saw ingredient decision is 2 Copper Ingots + 1 Stick + 10 Twine, with the shaped stick handle tightly wrapped in twine. This note records the supplied design direction; no official catalog or recipe data is changed by this asset commit.
