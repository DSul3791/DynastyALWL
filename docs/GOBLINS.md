# Goblins

Goblins made by Dave in Meshy on 7 Nov 2026: **Skritch Ragtooth** and **Rukz the Scavenger**.

## Models

| | Skritch Ragtooth | Rukz the Scavenger |
|---|---|---|
| File | `Goblin_Skritch_Ragtooth.glb` | `Goblin_Rukz_The_Scavenger.glb` |
| Size | 38.3 MB | 43.0 MB |
| Real height | about 1.06 m | about 1.10 m |
| Triangles | 41k | 41k |
| Skeleton | 24-bone Mixamo-style | 24-bone Mixamo-style |
| Clips | 19 | 20 |
| Textures | 21 MB colour + 10 MB metallic-roughness | 23 MB colour + 10 MB metallic-roughness |
| Target path | `assets/creatures/goblin_skritch/` | `assets/creatures/goblin_rukz/` |

- Both .glb files are committed at full size (under GitHub's 100 MB file limit; about 81 MB added to the repo in total, so every clone carries it). Dave made them himself, so committing is allowed.
- **Textures are NOT shrunk** (Dave, 7 Nov 2026). The full-size originals are the ultra tier and stay as they are. Textures get smaller only as part of LOD, on lower graphics settings (import mipmaps / mipmap bias / Godot's own downgrading), never by replacing the source files.
- Skritch clips: Alert, BeHit_FlyUp, Block1, Cautious_Crouch_Walk_Forward, Collect_Object, Combat_Stance, Dead, Idle_02, Knock_Down, Right_Hand_Sword_Slash, Roll_Dodge, Running, Sit_Cross_Legged_on_Floor, Sleep_Normally, Sneaky_Walk, Stand_Dodge, Stand_and_Drink, Thrust_Slash, Walking.
- Rukz clips: Running, Walking, Alert, Attack, Cautious_Crouch_Walk_Forward, Collect_Object, Dead, Hit_Reaction, Idle_02, Idle_5, Roll_Dodge, Sit_Cross_Legged_on_Floor, Sleep_Normally, Sneaky_Walk, Stand_Dodge, Stand_and_Drink, Sword_Judgment, Sword_Parry, Thrust_Slash, falling_down.
- The two models share a skeleton but not clip names, so code must map clips by role (idle, walk, run, attack, hit, dead) per model, not by name.
- Not yet tried in Godot (check facing direction, clip loops, texture look).

## Quality tiers (Dave, 7 Nov 2026)
- The goblins are the **ultra-quality** models (about 40k triangles). Every goblin is made once at this quality.
- Lower graphics settings use **Godot's own downgrading**, not separate hand-made models.
- What Godot gives us on these .glb files (from the Godot 4 docs, to be confirmed on the PC):
  - **Mesh LODs:** the scene importer has Meshes > Generate LODs (on by default). It builds simplified versions of the mesh at import with a mesh simplifier, and Godot switches between them by how big the goblin is on screen. The project setting `rendering/mesh_lod/lod_change/threshold_pixels` sets how early it switches (higher = switches sooner, cheaper) and a node's `lod_bias` tunes one object. A graphics-quality option can change that threshold, so low settings use cheaper meshes without any extra files.
  - **Textures:** import with VRAM compression and mipmaps so far-away goblins read smaller mips. A lower-res texture tier would come from a mipmap bias or a downsized import, not a second texture file.
  - **Open check (PC):** confirm that the LODs are actually generated and used on a skinned, animated mesh, since LOD support on skinned meshes has had limits. If not, fall back to Godot's mesh simplification at import or a single reduced copy made by the build, still not by hand.
  - Distant goblins can also cut animation cost (fewer bone updates) as a separate systemic setting.

## Height rule (Dave, 7 Nov 2026)
- Goblins are about **1.1 m** tall (`base_height_m`). Skritch and Rukz are both sized to this.
- Every goblin gets its own random height change each time it spawns: up to **0.5 m shorter or 0.5 m taller** (`height_variation_m`), so 0.6 m to 1.6 m.
- Systemic: scale = (base_height_m + roll) / model_height_m, uniform, from the data in `data/creatures/goblins.json`. No per-goblin hand scales. Same approach as `length_m` for animals.
- Open: whether the roll is flat or bell-shaped, and whether it is saved with the goblin. Not decided; ask Dave if it matters.
