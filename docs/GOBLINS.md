# Goblins

First goblin: **Skritch Ragtooth**, made by Dave in Meshy on 7 Nov 2026.

## Model
- File: `Goblin_Skritch_Ragtooth.glb`, 38.3 MB. Target path `assets/creatures/goblin_skritch/`.
- Not committed yet: the two embedded textures (21 MB colour, 10 MB metallic-roughness) make it too big. Plan: shrink them to 2048 px on the PC, then commit (about 5-8 MB). Dave made it himself, so committing is allowed.
- Real height about 1.06 m. 41k triangles, one skinned mesh, 24-bone Mixamo-style skeleton.
- 19 animation clips: Alert, BeHit_FlyUp, Block1, Cautious_Crouch_Walk_Forward, Collect_Object, Combat_Stance, Dead, Idle_02, Knock_Down, Right_Hand_Sword_Slash, Roll_Dodge, Running, Sit_Cross_Legged_on_Floor, Sleep_Normally, Sneaky_Walk, Stand_Dodge, Stand_and_Drink, Thrust_Slash, Walking.
- Not yet tried in Godot (check facing direction, clip loops, texture look).

## Height rule (Dave, 7 Nov 2026)
- Skritch is about **1.1 m** tall (`base_height_m`).
- Every goblin gets its own random height change each time it spawns: up to **0.5 m shorter or 0.5 m taller** (`height_variation_m`), so 0.6 m to 1.6 m.
- Systemic: scale = (base_height_m + roll) / model_height_m, uniform, from the data in `data/creatures/goblins.json`. No per-goblin hand scales. Same approach as `length_m` for animals.
- Open: whether the roll is flat or bell-shaped, and whether it is saved with the goblin. Not decided; ask Dave if it matters.
