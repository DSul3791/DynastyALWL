# Bald head reference: fitting note

**For us and later AI processing, not an input to Meshy.** Made 20 Nov 2026 for Dave's hairstyle-for-Meshy request. These are bald reference renders, not hairstyle references. Nothing in the game, the character system or the model was changed.

## The images (this folder)
| File | View |
|---|---|
| `head_front.png` | Front: camera in front, looking at the face |
| `head_left.png` | Left side: the character's own left (he faces the viewer's left) |
| `head_back.png` | Back |
| `head_front_three_quarter_left.png` | Front three-quarter: 45 degrees between front and the character's left |

All four: 2048 x 2048 px, orthographic, the same scale and the same frame. Plain light-grey background (RGB 212, 212, 212), even light (the texture colour times 0.72 to 1.0, brightest where the surface faces the camera, so the shape reads without shadows), no interface, labels or accessories. Rendered at 4096 px and downsampled.

- Frame: model height 1.285 m to 1.885 m (0.60 m tall and 0.60 m wide), centred on the head bone's x and z, so **1 m = 3413.3 px**.
- Crown at pixel row 632, chin at row 1332, head bone origin at row 1172; the head bone's x is column 1024 in the front and back views. About 18 cm of space above the crown and about 21 cm beside the head on the right-ear side and 23 cm on the left.
- The head is upright as modelled: the pose is the bind (rest) pose, not rotated or straightened.

## The model
- **File:** `assets/character/Humanoid/Dynasty_Base_Male.glb` (Body 1, the only player body; `src/client/character/body_models.gd`). The parts file `Dynasty_Base_Male_Parts_Split.glb` is the first-person arms, not used here.
- **Settings:** the default character. The creator's default genome (`body_generator.gd make_genome("average")`) has every body and face slider at 0 (and bust set to none, which this body does not use), which gives every bone scale 1.0 (`dynasty_proportions.gd`), no width or face blend shapes (`dynasty_body.gd _set_widths` keeps the plain mesh) and no skin tint (the default skin is the painted skin). The mesh has no blend shapes of its own, so its only expression is the neutral one rendered here.
- **Pose:** bind (rest) pose, arms out. No animation is applied.
- **Scale and orientation:** mesh coordinates are metres, feet at y = 0, crown at y = 1.700 m. +Y up. The file faces **+Z**, and the character's left is **+X**. The skeleton is in centimetres under the root node `target_character` at scale 0.01. In the game, `dynasty_body.gd` turns the model 180 degrees (`_model.rotation.y = PI`) so it faces Godot's -Z.
- **Head bone:** `mixamorig_Head` in Godot (`mixamorig:Head` in the glb; Godot turns the colon into an underscore; `dynasty_body.gd` uses the prefix `mixamorig_`). Rest position in model space (0.0037, 1.5416, 0.0116) m, at the top of the neck. Its axes are tilted relative to the model: its +Y points (0.079, 0.982, 0.173), about 10 degrees forward and 4.5 degrees to the side, so hair fitted to the bone must use the bone's rest transform, not assume the bone is level. The child `mixamorig_HeadTop_End` is at (0.0148, 1.6799, 0.0360). The parent is `mixamorig_Neck`. `headfront` is an extra joint at (0.0037, 1.5416, 0.1146).

## Head measurements (metres)
| Measure | Value | From | To |
|---|---|---|---|
| Height, chin to crown | **0.205** | chin y 1.4947 | crown y 1.7000 |
| Width, including ears | **0.160** | x -0.0833 (right ear) | x +0.0762 (left ear) |
| Width of the skull above the ears | 0.145 | at y 1.615 and above | |
| Depth, including nose | **0.206** | back of skull z -0.0946 | nose tip z +0.1119 |
| Depth of the skull above the nose | 0.191 | at y 1.60 and above, brow to back | |

The right ear stands about 7 mm further out than the left; the mesh is not perfectly symmetric.

## How the measurements were taken
Read directly from the glb's vertex positions (bind pose, model space, metres) by `make_reference.py`; Godot was not run. Only vertices above y = 1.45 m are used, so the hands and body are left out. The **chin** is the lowest vertex on the front midline (within 12 mm of the head bone's x, and with z above 0.07 m in model space, about 6 cm in front of the bone). The **crown** is the highest vertex of the mesh. **Width** and **depth** are the full x and z extents of every vertex at or above the chin; the neck below the chin is narrower than the head, so it does not affect them. Skull-only width and depth use only vertices at or above the stated heights. These are bounding extents of the mesh surface, not anatomical landmark distances.

## How the images were made
`make_reference.py` (this folder) reads the glb, reads the colour texture embedded in it, and draws the bind-pose mesh with a small software rasteriser (orthographic, depth-buffered, both faces drawn because the material is double sided). It writes nothing except the four PNGs. To make them again: `python3 art/references/hair_bald_head_2026-11-20/make_reference.py` (numpy and Pillow, about 30 s). The images were not rendered in Godot, so they show the painted texture under flat light, not the game's lighting or shading.

Godot ignores this folder (`.gdignore`), so the PNGs are never imported into the game.
