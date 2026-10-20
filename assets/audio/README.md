# Sounds

The wind loops here are made in code by `make_sounds.py` (placeholders; `--placeholders` also writes generated footsteps, no longer used). Real
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
`step_gravel` (rocky), and (second pack, Dynasty_Footsteps_Dirt_Leaves_Mud_Snow_Water.zip)
`step_dirt`, `step_leaves`, `step_mud`, `step_snow` and `step_water`. Every ground has recorded steps now;
only the wind is still generated (no separate grass swish: the recorded steps carry it).

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

## Nature calls (ambient layer)

Placeholders are made by `make_ambient.py` into `ambient/`. Recordings go in
`recorded/ambient/` as `name_0.ogg`, `name_1.ogg` ... (3 to 5 variants each; `.ogg` only;
mono, one call per file, trimmed tight, 0.3 to 3 s). The game prefers them over the
placeholders. What each name is and where it plays:

| Name | Call | Zone |
|---|---|---|
| `bird_whistle` | clear 2 to 4 note songbird whistle (thrush, finch) | forest, meadow, highland |
| `bird_feebee` | two-note "fee-bee" (chickadee, titmouse) | forest |
| `bird_trill` | a rapid trill (sparrow, junco) | meadow, forest |
| `bird_chirp` | short chirps (sparrow, wren) | meadow, water edge, forest |
| `crow_caw` | 2 or 3 caws (crow or raven); owner's recording in `recorded/ambient/` | forest, highland |
| `crow_alarm` | an angry crow scolding: the danger warning (`ambient_life.alarm`); owner's recording | forest, highland |
| `woodpecker` | one drumming burst | forest |
| `owl_hoot` | a barred owl or great horned owl hoot (night only) | forest |
| `hawk_screech` | red-tailed hawk scream | highland |
| `cricket_chirp` | a field cricket or katydid chirp run (sounds at night as well) | meadow, water edge |
| `frog_croak` | a green frog or bullfrog croak (sparse in autumn) | water edge |
| `tree_frog_peep` | spring peeper or gray tree frog peeps | water edge, forest |
| `fish_splash` | a small fish or a frog hitting the water | water edge |
| `bed_forest`, `bed_meadow`, `bed_water`, `bed_highland` | OPTIONAL quiet loops (30 s or longer, seamless, `.ogg`): forest leaf-and-insect hush, meadow insects, a gentle stream, high wind | per zone |

Where to look (CC0 only): Freesound with the license filter "Creative Commons 0", searching the
names above plus "forest ambience", "meadow insects", "stream gentle"; Kenney has none.
Cut a single call from a longer field recording in Audacity and export it as its own file.
Eastern North American species suit the setting (autumn forest, ponds, ridge).

## Water sounds (build 96)

Seamless loops played at the water by `src/client/water_sounds.gd`: `water_brook`, `water_river`,
`water_pond` (lapping at a shore), `water_fall`. Generated by `make_water.py` into `water/`;
recordings saved as `recorded/water/water_<kind>.ogg` (or `_N` variants) win. Loops must wrap cleanly.

## Weather sounds (build 104)

Played by `src/client/weather_sounds.gd`: loops `rain_light`, `rain_heavy`, `rain_leaves`, `rain_water`,
`wind_storm` and one-shot `thunder_N`. Generated by `make_weather.py` into `weather/`; recordings saved as
`recorded/weather/<name>.ogg` (`_N` variants allowed) win. `wing_flap_N` in `recorded/ambient/` is the owner's
bird wings recording, with copies at other speeds.

## Dig sounds (build 110)

`dig_soil`, `dig_clay`, `dig_sand`, `dig_gravel`, `dig_rock`, `dig_ore`, `dig_water` (water pouring into a hole),
3 variants each (`_N`). Generated by `make_dig.py` into `dig/`; recordings in `recorded/dig/` win.

## Licences of supplied recordings (fill in before release)

Supplied by Dave, who confirmed on 2026-10-20 that they came from a free source: the footstep sets
(`recorded/step_*`), the frog calls, fish splash, crow calls, angry crow and bird wing flaps
(`recorded/ambient/frog_croak`, `tree_frog_peep`, `fish_splash`, `crow_caw`, `crow_alarm`, `wing_flap`).
Source site: TODO (Dave). Licence: TODO (Dave; for example CC0 or a free-to-use licence that allows a
commercial game). Attribution needed: TODO. Keep this section in step with every recording added.

## Cave sounds (build 113)

`cave_drip_N` water drops with a short echo tail, played around the player in caves and tunnels
(`cave_sounds.gd`). Generated by `make_cave.py` into `cave/`; recordings in `recorded/cave/` win.

## Where each of Dave's clips comes from (to check by ear)

Times are seconds into the original file.
- `fish_splash_0..2` (from "soundfx_Fish_Jumping_1"): the WHOLE clip, nothing cut (owner 2026-10-20: it is the right fish sound as it is), brought up to a 0.7 peak; 1 and 2 are the same clip played 6 percent faster and slower.
- `frog_croak_0..5` (from "Frog sounds various"): 0 = 16.61-17.10 (low, about 860 Hz), 1 = 56.27-56.87 (low), 2 = 71.93-72.52 (low), 3 = 0.42-1.43 (long trill), 4 = 29.35-29.96, 5 = 53.07-53.93.
- `tree_frog_peep_0..5`: 0 = 39.44-39.77, 1 = 48.56-49.00, 2 = 49.41-49.55, 3 = 55.47-55.66, 4 = 67.16-67.45, 5 = 71.14-71.32 (all short, about 2 kHz).
- The frogs in that file are mostly 2 kHz trillers; there is no deep bullfrog. The sorting was done by pitch and length without listening, so any clip that sounds wrong can be named by its number.
- The HUD `nature:` line now ends with the file last played, e.g. `fish_splash_2 12 m (recorded)`.

## Tool hit sounds (build 123)

`hit_<tool>_<material>_N` for tool axe, pick, hammer, spade and material wood, stone, soil (12 slots, 3 variants each),
played by `hit_sounds.gd`. Generated by `make_hits.py` into `hits/`; recordings in `recorded/hits/` win.
`SOUND_PACK.md` lists every slot and what to supply.

## Town sounds (build 124)

`town_bell_N` (one-shot, long ring), loops `town_hammering`, `town_fire`, `town_crowd`, played by `town_sounds.gd` from
whatever list of sources a town system hands it. Generated by `make_town.py` into `town/`; recordings in `recorded/town/` win.

## Swim sounds (build 127)
`src/client/swim_sounds.gd`, made by `make_swim.py` into `assets/audio/swim/`; recordings in `assets/audio/recorded/swim/` win. Names: `swim_splash_small_N` (slow entry), `swim_splash_big_N` (jump or fall in, 4 m/s and up), `swim_stroke_N` (one arm pull, every 0.6 to 1.4 s), `swim_dive_N` (head goes under), `swim_surface_N` (head comes out), `swim_under` (seamless underwater hum loop). Esc > Settings "Sound test: swimming" plays a scripted swim.

## Weather and animals (build 127)
Frogs: normal in clear, 1.6x in drizzle, 1.2x in rain, silent in storms, snow and blizzards. Birds, crickets and the rest: 0.5 in drizzle, 0.15 in rain, none in a storm. See `KINDS` in `weather_sounds.gd`.

## Wet and snowy ground (build 129)
`weather_sounds.gd` keeps `ground_wet` and `ground_snow` from the weather (the ground soaks in rain, dries slowly; snow settles and melts), and the footsteps read them: snow lying makes loose ground use the snow steps, soaked ground gives mud steps and a puddle splash (`step_water`) on top of grass, stone, gravel and sand. Under trees in rain a leaf drop `rain_drip_N` falls nearby (new slot, generated by `make_weather.py`). The rain loops no longer have a steady hiss bed (it sounded like brushing a horse); they are only drops.

## Interface sounds (build 130)
`ui_sounds.gd`, made by `make_ui.py` into `assets/audio/ui/`; recordings in `recorded/ui/` win. Names: `ui_click_N` (menu buttons), `ui_on_N` and `ui_off_N` (inspection toggle), `ui_quality_N` (quality tier change). Quiet on purpose (about 20 dB under full scale), on their own Interface bus.

## Creature calls (build 132)
`creature_sounds.gd`, made by `make_creatures.py` into `assets/audio/creatures/`; recordings in `recorded/creatures/` win. Names (each with `_N` variants): `deer_grunt`, `deer_snort`, `rabbit_thump`, `rabbit_squeak`, `fox_bark`, `fox_scream`, `wolf_howl`, `wolf_growl`, `bear_growl`, `bear_roar`. Birds use the ambient set (`bird_*`, `crow_alarm`). All of it is placeholder synthesis; real recordings matter most for the wolf howl and the bear (see SOUND_PACK.md).

## Gear sounds (build 138)
`gear_sounds.gd`, made by `make_gear.py` into `assets/audio/gear/`; recordings in `recorded/gear/` win. Names (`_N` variants): `gear_cloth`, `gear_leather`, `gear_chain`, `gear_plate`, `gear_hobnail`, `gear_iron`. They play on top of each footstep for whatever the player wears (hooks only until equipment exists).
