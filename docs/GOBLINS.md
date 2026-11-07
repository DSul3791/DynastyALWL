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

## Behaviour (Dave, 7 Nov 2026)
- **Groups:** when goblins spawn there are **2 to 5** of them together.
- **Den:** they spawn in a **river-side cave** (caves exist only at river starts, inland; see DESIGN_IDEAS 4.4 and the caves doc).
- **Night only:** they come out at night to **forage for berries**, to **sneak around**, and to **steal anything they can that is not protected by light** (campfire, torch or lamp light). By day they stay in the den.
- **Watchers:** they often sneak to the very edge of a campfire's light, staying in the shadows, and **watch people**.
- **Skittish:** they keep away from people and light, but **fight if backed into a corner or threatened in their den**.
- Not decided: how much they can steal and where it goes (hoard in the den?), what a fight does (levels, damage), and whether they drop what they stole when killed. Ask Dave before building those.
- Fits the temperament system (skittish, with a threat range that makes them fight) and the animal levels rule (level set by distance from town, not placement). See `docs/knowledge/animal-behaviour.md`.

## Built so far (first step, 7 Nov 2026; not yet run in Godot)
- **Species 15, "goblin"** in `data/animals/animals.json`, drawn from `data/animals/models.json` (row goblin, two `variants`: Skritch and Rukz, picked by animal id, clips mapped by role per model).
- **Height:** the client sizes each goblin by its mesh height to `height_m` 1.1 plus a bell-shaped roll (mean of three even rolls) of up to `height_variation_m` 0.5 either way, seeded from the animal id. One rule, no per-goblin scales.
- **Spawning (`server_animals.gd` `_top_up_lair`):** a group of 2 to 5 at a spring cave mouth near a player, in the tile the player stands in; one group per mouth; never at a mouth with a bear within 120 m. Made at any hour.
- **Day and night:** by day they bed down at the mouth (the existing rest rule from their `active` row), at night they range up to 70 m round it. They keep out of fire, torch and lamp light (the existing keep-off rule), stop and watch a player they notice from 60 m (alert), run at 30 m, and fight if cornered or threatened at the den (the bear's defend code, small numbers).
- **Not built yet:** sleeping inside the cave (the server has no cave floor height, so the den is the mouth); foraging berries; sneaking to the edge of firelight on purpose; stealing; fighting bears (no animal-versus-animal fighting exists); goblin carcass; goblin calls and a footstep sound of their own (the `goblin_step` slot borrows the wolf's).
- **To check on the PC:** that the .glb files import (the editor makes their .import files first), which way they face (yaw 180 is a guess), that the height comes out near 1.1 m, the clips play, and that groups appear at a cave mouth at night.
