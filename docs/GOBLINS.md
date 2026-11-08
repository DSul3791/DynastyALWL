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
- The roll is bell-shaped (as built). **Not saved with the goblin (decided by Dave, 8 Nov 2026):** it comes from the animal id, so it is always the same.

## Behaviour (Dave, 7 Nov 2026)
- **Groups:** when goblins spawn there are **2 to 5** of them together.
- **Den:** they spawn in a **river-side cave** (caves exist only at river starts, inland; see DESIGN_IDEAS 4.4 and the caves doc).
- **Night only:** they come out at night to **forage for berries**, to **sneak around**, and to **steal anything they can that is not protected by light** (campfire, torch or lamp light). By day they stay in the den.
- **Watchers:** they often sneak to the very edge of a campfire's light, staying in the shadows, and **watch people**.
- **Skittish:** they keep away from people and light, but **fight if backed into a corner or threatened in their den**.
- **Decided by Dave (8 Nov 2026), see "Decisions, 8 Nov 2026" below:** how much they steal, where it goes, and whether they drop it when killed. A fight uses the den and defend numbers in `animals.json` with the animal levels rule.
- Fits the temperament system (skittish, with a threat range that makes them fight) and the animal levels rule (level set by distance from town, not placement). See `docs/knowledge/animal-behaviour.md`.

## Built so far (first step, 7 Nov 2026; not yet run in Godot)
- **Species 16, "goblin"** (15 is the donkey) in `data/animals/animals.json`, drawn from `data/animals/models.json` (row goblin, two `variants`: Skritch and Rukz, picked by animal id, clips mapped by role per model).
- **Height:** the client sizes each goblin by its mesh height to `height_m` 1.1 plus a bell-shaped roll (mean of three even rolls) of up to `height_variation_m` 0.5 either way, seeded from the animal id. One rule, no per-goblin scales.
- **Spawning (`server_animals.gd` `_top_up_lair`):** a group of 2 to 5 at a spring cave mouth near a player, in the tile the player stands in; one group per mouth; never at a mouth with a bear within 120 m. Made at any hour.
- **Day and night:** by day they bed down at the mouth (the existing rest rule from their `active` row), at night they range up to 70 m round it. They keep out of fire, torch and lamp light (the existing keep-off rule), stop and watch a player they notice from 60 m (alert), run at 30 m, and fight if cornered or threatened at the den (the bear's defend code, small numbers).
- **Not built yet:** sleeping inside the cave (the server has no cave floor height, so the den is the mouth); foraging berries; sneaking to the edge of firelight on purpose; stealing; fighting bears (no animal-versus-animal fighting exists); goblin carcass; goblin calls and a footstep sound of their own (the `goblin_step` slot borrows the wolf's).
- **To check on the PC:** that the .glb files import (the editor makes their .import files first), which way they face (yaw 180 is a guess), that the height comes out near 1.1 m, the clips play, and that groups appear at a cave mouth at night.

## The den and respawn (Dave, 7 Nov 2026) - supersedes "at the cave mouth" above
- **Den:** a **premade goblin den** at the **back of one of the side tunnels (branches) of any spring cave**. *(Agreed 7 Nov, via the coordinator: Dave has said every cave may be inhabited, and the watershed rebuild makes spring caves rare, so the den is also at the dry dead end of a karst cave or lava tube; never in a sea cave or rock shelter. See docs/water/stage_e_readers_design.md Q1, `tile_terrain_data.gd` GOBLIN_DEN_CAVES.)* It looks like a little goblin den: **bones, sticks and thatch strewn on the floor**, and a **small campfire** in it.
- **Spawning:** goblins spawn **like every other creature** (the normal top-up around players), not on a special schedule.
- **Respawn:** if a group is killed for any reason, a **new group may eventually respawn**, depending on whether there are **patrols or buildings** in the area. Exact rules not decided (Dave: "not sure what the rules are"); needs a card when built.
- **What it needs before it can be built:** (1) the cave generator (`tile_sites.gd`) marks a goblin den on a branch den (`dens` rows with where "branch" already exist) and the cave dressing (`cave_dressing.gd`, Sonny/Kathleen/Kathreen) adds the bones, sticks, thatch and a campfire; (2) the server learns the cave floor height, so goblins can stand in the den instead of on the hill above it (today's first step puts the group at the cave mouth for that reason); (3) the respawn rule. The campfire gives goblins light, which fits "they keep out of light" only if their own den fire is exempt.
- The mouth spawn built so far is a stand-in until (1) and (2) exist; it is one function (`_top_up_lair`) and the den point source is the only part that changes.
- **Dave, 7 Nov 2026 03:25:** use a **dry offshoot of the spring-cave tunnels we already make** (the side branches that hold dens), not a new kind of cave. No new tunnel generator is needed, only marking one dry branch den as the goblin den and dressing it.

## Idea: roaming bands (Dave, 7 Nov 2026, "might also add")
- Roaming bands of goblins that **slink around at night, migrating around the islands**. By day they find **bushes to sleep under, or caves to hide in**. Not decided; separate from the den groups. Build only after the den groups work.

## Den build, stage A (7 Nov 2026; not yet run in Godot)
Design (from Dave's spec above): a goblin den is the dry end of a side branch of a spring cave we already make, with bones, sticks and thatch on the floor and a small campfire. No new tunnel generator and no bake change.
- **Which caves:** `TileTerrainData._load_caves` picks, in `GOBLIN_DEN_PERCENT` (60) of spring caves that have a branch den, the last branch den as the goblin den. The pick is from a hash of the cave's id, so the server and every client agree and no tile needs rebaking. Constants at the top of the file.
- **Dressing:** the den is added to `cave_bones` as kind 3 (small fire) and 5 piles of kind 2 (litter: gnawed bones, crossed sticks, thatch) round it. They travel in the existing cave dressing message (no protocol change) and `cave_dressing.gd` draws them (`goblin_litter`, `goblin_fire`). The fire is a visual only for now: no light and no heat, because a real fire would be a server structure; whether goblins' own fire counts as light is undecided.
- **Spawning:** goblin groups now come out of the mouths of caves that have a goblin den (`goblin_den_mouths`, used by `lair_mouths`), no longer every spring cave. They still stand at the cave mouth, not in the den, until the server knows the cave floor height.
- **Still open:** goblins living inside the den (needs cave floor height and a way for the server to walk them through the 100 m tunnel), respawn rules, a real fire with light.

## Respawn rule (decided by the build, 7 Nov 2026, Dave: "pick a sensible one")
- A cave mouth that has made a goblin group and then finds it gone (killed, or the player walked far enough that it was dropped) waits `lair.respawn_s` (1800 s, 30 real minutes of server time) before it makes another, then a new group of 2 to 5 comes at the next top-up when a player is within range. A mouth that never made one makes its first at once.
- It does not respawn while `lair_guarded(x, z)` says patrols or buildings hold the area (the hook is in `server_animals.gd`; nothing answers it yet because no server query for "buildings near a point" exists, so today it is always false). Wire it to the first building-near query that exists.
- Change the wait in `data/animals/animals.json` (goblin, lair, respawn_s). Not tested in Godot.

## Den fire look (7 Nov 2026, after Dave's cave screenshot; not yet run in Godot)
- Dave saw a light on the floor and no fire: the den fire was a lit stone ring with a bright orange block, no flame. It now has a real look: a ring of stones round a teepee of five charred logs on dull embers, and a **flame** of five cone tongues (a tall yellow-white core and four orange ones leaning out) drawn with a glowing material (`cave_dressing.gd` `goblin_flame`, `flame_material`). Its light flickers (`_process`).
- Still to improve later: the litter shapes (bones, sticks, thatch), a smoke wisp, a crackle sound, and a real fire structure that goblins treat as their own light.

## Decisions, 8 Nov 2026 (Dave: "I agree to all recommendations")
- **Stealing:** one small item at a time, only from what no fire, torch or lamp lights.
- **Stolen things** go into a pile in the band's den, where a player can find them and take them back.
- **A killed goblin** drops what it is carrying.
- **Height:** not saved; it comes from the animal id.
- **Foraging:** goblins eat at berry bushes without stripping them, for now.
- **Respawn:** no new group while a lit building or a player camp with a fire sits within 100 m of the cave mouth. This is what `lair_guarded` answers once it is wired.
- **Friendship:** yes, slowly, by gifts left outside the firelight over many nights: that band stops stealing from that player, leaves small gifts back and whistles when a bear or wolves come near. They never enter light or follow anyone. Design: `docs/design/goblin_ally_design.md`.
- **Build order (coordinator):** den life (`docs/design/goblin_den_life_design.md`), then stealing and the den pile, then friendship.
