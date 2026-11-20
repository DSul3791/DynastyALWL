# Character and creature meshes: the checklist

**Status: Dave's rule, 20 Nov 2026.** It is a tip he passed on from Google and asked to keep ("can we put this somewhere so we remember to use it"). It covers every character and creature mesh, so go through this list whenever one is added or re-imported. The reason: several animated characters round a campfire with dynamic lights (the Ragtooth camp has five goblins and a fire, Edda and Hob's camp has two) must not cause frame hiccups.

## Checklist
1. **Shadow casting On, not Double-Sided.** Every `MeshInstance3D` of a closed character mesh casts shadows with `cast_shadow = SHADOW_CASTING_SETTING_ON`, which is Godot's default. Never use `SHADOW_CASTING_SETTING_DOUBLE_SIDED`: it renders the shadow twice and gains nothing on a closed body. Small parts may still be turned Off, as `animal_view.gd` already does.
2. **Textures VRAM Compressed.** The albedo, normal and roughness (or metallic-roughness) textures import with **VRAM Compressed**, with mipmaps, so that five characters with 2K or 4K textures do not fill GPU memory.
   - For a .glb that embeds its textures, this is set in the .glb's own import settings: either embed them as Basis Universal, or extract them and give each extracted texture compress mode VRAM Compressed.
   - Commit the resulting `.import` files so every machine imports the mesh the same way.
   - The source files are not shrunk (see [Goblins](../GOBLINS.md), quality tiers).

## Where the shipped meshes stand (20 Nov 2026)
| Mesh | Shadow casting | Textures | .import committed |
|---|---|---|---|
| `assets/creatures/goblin_skritch/Goblin_Skritch_Ragtooth.glb` | On (Godot default; nothing in the code sets Double-Sided, `test_goblin_looks` checks it). Its glTF material is marked doubleSided, which turns off back-face culling. This is not the shadow setting. | 2 embedded 4096x4096 PNGs: colour and metallic-roughness. No normal map. Extracted on import (`gltf/embedded_image_handling=1`), each VRAM Compressed (`compress/mode=2`) with mipmaps. | Yes: the .glb.import, both texture .import files (made in the editor on Dave's PC) and the extracted PNGs |
| `assets/creatures/goblin_rukz/Goblin_Rukz_The_Scavenger.glb` | Same as Skritch | Same as Skritch | Yes, same as Skritch |
| `assets/creatures/goblin_vrixa/Goblin_Vrixa_Thornfang.glb` | Same as Skritch (material doubleSided too) | 3 embedded 4096x4096 PNGs: colour, metallic-roughness and a normal map. Extracted and VRAM Compressed like the others, the normal map as a normal map. | Yes: the .glb.import and three texture .import files |
| `assets/creatures/goblin_grikka/Goblin_Grikka_Ragtooth.glb` | Same as Skritch (material doubleSided too) | Same as Vrixa: colour, metallic-roughness and a normal map, 4096x4096 | Yes, same as Vrixa |

- **The extracted PNGs are committed with their .import files** (Dave, project chat 20 Nov 2026 08:20 UTC: "if I want be performance what would you recommmend"; the coordinator recommended committing the PNGs, and Dave answered "yes" at 08:21 UTC. About 146 MB for the four goblins). Godot 4.7's glTF importer (`modules/gltf/gltf_document.cpp`, extract textures) never writes an image whose .png.import already exists: with the image's md5 in it, it takes the PNG on disk as current; without one, it leaves the file alone. So a committed .png.import without its PNG gives no texture at all on a fresh clone (seen on the PC lane, 20 Nov 2026).
- Leaving the .png.import files out does not work either: a fresh import then makes them Lossless, and Godot only switches them to VRAM Compressed when the editor first draws them in 3D (detect_3d), never in a headless import. Embedding as Basis Universal gives no mipmaps.
- For a new mesh: import it once with no texture .import files, set each texture's compress mode to VRAM Compressed (normal maps also Normal Map Enabled, detect_3d off), keep the md5 Godot wrote, and commit the .glb.import, the .png.import files and the PNGs together.
- **Open:** whether to clear the glTF doubleSided flag (one-sided faces) is a look decision, to be made only after seeing the meshes on screen. None of the four goblins has been seen on screen with these settings yet.
