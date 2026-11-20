# Character and creature meshes: the checklist

**Status: Dave's rule, 20 Nov 2026.** It is a tip he passed on from Google and asked to keep ("can we put this somewhere so we remember to use it"). It covers every character and creature mesh, so go through this list whenever one is added or re-imported. The reason: several animated characters round a campfire with dynamic lights (the Ragtooth camp has three goblins and a fire, Edda and Hob's camp has two) must not cause frame hiccups.

## Checklist
1. **Shadow casting On, not Double-Sided.** Every `MeshInstance3D` of a closed character mesh casts shadows with `cast_shadow = SHADOW_CASTING_SETTING_ON`, which is Godot's default. Never use `SHADOW_CASTING_SETTING_DOUBLE_SIDED`: it renders the shadow twice and gains nothing on a closed body. Small parts may still be turned Off, as `animal_view.gd` already does.
2. **Textures VRAM Compressed.** The albedo, normal and roughness (or metallic-roughness) textures import with **VRAM Compressed**, with mipmaps, so that five characters with 2K or 4K textures do not fill GPU memory.
   - For a .glb that embeds its textures, this is set in the .glb's own import settings: either embed them as Basis Universal, or extract them and give each extracted texture compress mode VRAM Compressed.
   - Commit the resulting `.import` files so every machine imports the mesh the same way.
   - The source files are not shrunk (see [Goblins](../GOBLINS.md), quality tiers).

## Where the shipped meshes stand (checked 20 Nov 2026 on dev, not yet in Godot)
| Mesh | Shadow casting | Textures | .import committed |
|---|---|---|---|
| `assets/creatures/goblin_skritch/Goblin_Skritch_Ragtooth.glb` | On (Godot default; nothing in the code sets Double-Sided). Its glTF material is marked doubleSided, which turns off back-face culling. This is not the shadow setting. | 2 embedded 4096x4096 PNGs: colour and metallic-roughness. No normal map. | No |
| `assets/creatures/goblin_rukz/Goblin_Rukz_The_Scavenger.glb` | Same as Skritch | Same as Skritch | No |

**Open (PC):** the two goblins have no committed .import file, so compression depends on how each machine imports them.
- Import them once in the editor on Dave's PC, check that the textures come out VRAM Compressed and that the look is unchanged, then commit the two .glb.import files.
- Whether to clear the glTF doubleSided flag (one-sided faces) is a look decision, to be made only after seeing the meshes on screen.
