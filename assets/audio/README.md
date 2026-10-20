# Sounds

The `.ogg` files here are made in code by `make_sounds.py` (placeholders). Real
recordings go in `recorded/` under the same names, and the game uses them
instead of the generated ones. `make_sounds.py` never touches `recorded/`.

## Names the game looks for

Each sound is `name_0`, `name_1`, `name_2` ... (any count; the game picks a
different one each time) or a single `name`. `.ogg` or `.wav` both work.
Footsteps can also come as `name_left_N` and `name_right_N`: the game then
alternates feet. Missing ones fall back to the generated sound (bushes and
tall grass fall back to grass).

Build 52 uses the owner's own recordings (Dynasty_Footsteps_Left_Right.zip) for
`step_grass`, `step_grass_tall`, `step_bushes`, `step_sand`, `step_stone` and
`step_gravel` (rocky). Still generated: dirt, leaves, mud, snow, water.

| Name | What it is |
|---|---|
| `step_grass` | one footstep on grass |
| `step_dirt` | on bare earth or a path |
| `step_sand` | on sand or a beach |
| `step_gravel` | on gravel or stony ground |
| `step_stone` | on bare rock |
| `step_leaves` | on dry leaf litter (forest floor) |
| `step_grass_tall`, `step_bushes` | in meadow patches, and walking through a shrub |
| `step_mud` | on wet ground or mud (also the waterline) |
| `step_snow` | on snow |
| `step_water` | one step in shallow water (ankle to knee deep) |
| `grass_brush`, `grass_brush_tall` | legs brushing through grass, short and tall |
| `wind_low`, `wind_gust` | wind loops: a soft background breeze, and airy leaves-and-grass gusts |

Each footstep file should hold ONE step (about 0.2 to 0.5 s), trimmed tight at
the start, with no long silence. Wind files should be long loops (30 s or
more) that loop cleanly.

## Where to get free recordings (CC0, no credit needed)

1. **Kenney "Impact Sounds"** (kenney.nl/assets/impact-sounds, CC0): the pack has
   `footstep_grass_000` to `004`, `footstep_concrete_000` to `004` and
   `footstep_snow_000` to `004`. Copy and rename them to
   `recorded/step_grass_0.ogg` ... `step_grass_4.ogg`, `recorded/step_stone_0.ogg`
   ... and `recorded/step_snow_0.ogg` ....
2. **Freesound** (freesound.org, free account): search, then tick the license
   filter "Creative Commons 0". Good searches: "footstep gravel", "footsteps
   sand", "footsteps mud", "footsteps leaves", "footsteps dirt path",
   "walking shallow water", "walking through tall grass", "gentle breeze
   loop". Many files hold a whole walk; cut single steps out with Audacity
   (free) and export each as its own file.

Keep the loudness of each set roughly even; the game sets each surface's
overall level in `src/client/sound_stage.gd` (`SURFACE_DB`).
