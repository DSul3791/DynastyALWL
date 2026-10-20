# Dynasty — natural pickup props

12 original procedural meshes for Godot 4.x. All are actual 3D geometry, not images or billboard sprites.

## Contents
- `models/*.glb` — 12 independent, game-importable models (three smooth stones, three rough stones, three woodland sticks, three beach driftwood pieces).
- `previews/*.png` — independently rendered previews of the actual GLB models.
- `Collection_Preview.png` — contact sheet for the full set.
- `All_Props_Overview.glb` — optional side-by-side 3D preview scene, NOT intended as one in-game pickup.
- `model_manifest.json` — dimensions in meters, vertex counts, and triangle counts.

## Godot import
1. Unzip into `res://assets/natural_pickups/` or any directory in your Godot project.
2. Let Godot import the `.glb` files. Drag an individual `.glb` into a 3D scene or instantiate it as a packed scene.
3. Units are **meters**, axes are **Y up**, resting contact is at **Y=0**; center X/Z is near the visual center.
4. The mesh has **embedded vertex colors** (glTF `COLOR_0`), not external PNG textures. Imported glTF materials should honor vertex colors automatically. For custom ShaderMaterials, multiply albedo by `COLOR.rgb`.
5. For interactable pickups, wrap each model in an `Area3D` and a simple `CollisionShape3D`, e.g. a sphere for stones or a capsule for sticks. Do not use trimesh collision on hundreds of pickup props.
6. For many non-interactive scattered copies, use `MultiMeshInstance3D` with an appropriate material. Keep actual collectible items as independent `Node3D`/`Area3D` instances as needed for per-item state.

## Asset intent
- Stones: large-fist scale (~10–15 cm largest dimension). Rounded river stones and sharp broken chunks are intentionally different silhouettes.
- Sticks: naturally curved fallen brown bark sticks, ~40–60 cm long. No leaves.
- Driftwood: grey/bleached salt-weathered and mostly barkless, ~40–65 cm long.
- Surface shading is lightweight, based on vertex colors. PBR texture atlases or photogrammetry are not included; these are efficient original procedural props suitable for prototyping and further art iteration.
- Imported model triangle counts are recorded in the manifest. Consider lower LODs/instance culling for thousands of visible pickups.

## Licensing
Created for the requesting user's project. No third-party meshes or photographs incorporated.
