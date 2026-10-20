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

## Licences of supplied recordings (build 199)

`assets/audio/CREDITS.csv` is the table: one row per supplied recording or family (`pattern` is a glob under `recorded/`), with author, source, licence (CC0, CC-BY-4.0, CC-BY-3.0, public-domain, own, or TODO), the attribution text to show players, a link and the date added. `python3 assets/audio/make_credits.py` writes `CREDITS.md` from it. `validate_pack.py` fails a recording that no row covers (UNCREDITED), an unknown licence, or a CC-BY row without attribution text; a licence still TODO is a warning, and an error with `--strict` (run that before release).
Dave's supplied recordings (footsteps, frogs, fish splash, crow calls, angry crow, wing flaps) came from Pixabay, a page labelled "free sounds" (Dave, 2026-10-20): the 7 rows say Pixabay-Content-License (royalty-free, no attribution required). That licence is not CC0 or CC-BY and does not allow redistributing the sounds as a standalone pack, so they are fine inside the game but must not be shipped as separate files. Still TODO: the page URL of each sound, and verifying the Pixabay terms before release. Add a row whenever a recording is added. The generated placeholders are made by the make_*.py scripts and carry no third-party material.

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

## Interior sounds (build 141)
`interior_sounds.gd`, made by `make_interior.py` into `assets/audio/interior/`; recordings in `recorded/interior/` win. Loops: `interior_room`, `interior_rain_roof`. One-shots (`_N` variants): `interior_creak`, `door_open`, `door_close`, `door_knock`, `chest_open`, `chest_close`, `furniture_drag`. Hooks only until buildings exist.

## Water: river and brook character (owner, 2026-10-20)
The river loop sounded like ocean surf (a wide low rumble and a broad wash). `make_water.py` now builds brook and river from many small bubbles and trickles with only a faint wash and no rumble (river under 3 percent of its energy below 300 Hz, was 42 percent); the river is quieter in the game (-17 dB at the source) and only rapids (a steep reach) and fast current make it louder. The most useful recording from Dave is a gentle stream or small river burbling over stones, 20 s or more, seamless, with no waterfall or big rapids in it.

## Spear sounds (build 144)
`spear_sounds.gd`, made by `make_spear.py` into `assets/audio/spear/`; recordings in `recorded/spear/` win. Names (`_N` variants): `spear_jab`, `spear_throw`, `spear_flight` (moved along the path), `spear_hit_wood`, `spear_hit_stone`, `spear_hit_soil`, `spear_hit_flesh`. Hooks only until a weapon system exists.

## Item sounds (build 148)
`item_sounds.gd`, made by `make_items.py` into `assets/audio/items/`; recordings in `recorded/items/` win. It watches the inventory (no hooks in Items' code): `item_pickup_N` when stacks grow, `item_drop_N` when they shrink, `item_swap_N` when slots are rearranged, `inv_open_N` and `inv_close_N` with the I panel, `craft_done_N` when a craft finishes. Quiet, on the Interface bus. Several changes in one moment play one cue (60 ms gap).

## Fire sounds (build 149)
`fire_sounds.gd`, made by `make_fire.py` into `assets/audio/fire/`; recordings in `recorded/fire/` win. Hook: `sound.fire.set_fires([{id, at, size 0..1, lit, open}])` (size crossfades `fire_small` and `fire_large`; `lit` turning on plays `fire_light_N`, off plays `fire_out_N`; `open` true adds the `fire_rain` sizzle while it rains), plus `light(at)` and `put_out(at)`. Nearest 3/5/8 fires by tier play, none past 35 m. The rain sizzle is sparse snaps, no steady hiss bed. Esc > Settings "Sound test: fire", `--fire` headless.

## Volume sliders (build 151)
Esc > Settings has four sliders: Master, Effects (Foley bus: steps, tools, items, fire, town), Ambient (Wind, Nature, Weather buses) and Interface. They replace the old stepped "Sound volume" button; the Wind, Nature and Steps step buttons stay as fine tuning and multiply with them. Saved in `user://sound_settings.cfg` (`[levels]`), applied at start. `sound.set_level(name, 0..1)`; `--levels` headless sets, prints bus levels and resets.

## Loudness pass and probe table (build 153)
`python3 assets/audio/loudness_report.py [--md]` lists the active RMS and peak of every sound slot (recorded wins), flags files more than 8 dB from their group median, and shows footsteps as heard (file RMS + `SURFACE_DB`) and nature calls as played (file RMS + `EVENTS` db); `--md` writes `assets/audio/LOUDNESS.md`. Findings: the recorded steps are all normalised to about -18.5 dB, so the surface hierarchy comes only from `SURFACE_DB` (grass -33, leaves -25 heard: kept, it is deliberate; Dave to judge by ear). The generated owl hoot and woodpecker were the odd ones among the nature calls (owl 10 dB hot, woodpecker 6 dB quiet): owl -8 to -13 dB, woodpecker -8 to -5 dB. Dave's recorded frog, fish, crow and wing clips were not touched without his ears.

Sound probe (headless, 4000 frames, storm at 06:00, `--nature-fast`, walking; sound.update only, no audio device):

| tier | avg ms | worst ms | sounds playing (peak) | loaded MB |
|---|---|---|---|---|
| Low | 0.29 | 6.8 | 15/24 (15) | 3.2/150 |
| Medium | 0.30 | 5.9 | 15/48 (15) | 3.2/300 |
| High | 0.31 | 7.7 | 13/96 (16) | 3.2/600 |

Averages are flat across tiers; the worst frame is a one-off spike (first load of files) in each. Cave rays and hill occlusion were not exercised (flat walk).

## Sound pack validator (build 159)
`python3 assets/audio/validate_pack.py [--strict]` checks the folders against `make_manifest.py`: MISSING slots (no recording and no generated sound), OVERSIZED files (warning over 400 KB, error over 2500 KB, error when `recorded/` passes 40 MB), UNREFERENCED files (a name no slot or footstep uses, usually a typo), UNPAIRED left/right footsteps and a STALE `sound_manifest.json`. Exit 1 on errors; `--strict` also fails on warnings. Run it before committing sounds. Today: 0 errors, 5 warnings (the four optional ambient beds are not built; `wind_low` is 455 KB, a long loop).

## Water: third rework (owner, 2026-10-20)
Dave: the bubbly loops (build 145) sounded like "a witches caldron and a horse brush sweeping". The bubbles read as boiling and the repeating wash pulse as a brush swish. `make_water.py` now makes only steady, smooth, broadband flowing noise with gentle band-passes, no bubble layer and no periodic swell (a random drift under 5 percent, never repeating), 24 s loops of circular noise (no seam): brook thin and bright (centroid 3.7 kHz) with about 3 sparse small drips per loop, river fuller (2.8 kHz, 2 percent under 300 Hz), pond a soft hush with a few irregular laps, fall a smooth wide rush. Levels dropped 5 to 6 dB at the source (river -22, brook -15, pond -17, fall -14). **Best fix: a real recording.** Replace `water_brook` with a gentle stream over stones, 20 s or more, no waterfall, no voices, ideally seamless, saved as `assets/audio/recorded/water/water_brook.ogg` (variants `water_brook_1.ogg`...); a slow broad river as `water_river.ogg`, a calm shore as `water_pond.ogg` and a waterfall as `water_fall.ogg` in the same folder. The game uses them automatically.

## Tree felling sounds (build 171)
`tree_sounds.gd`, made by `make_trees.py` into `assets/audio/trees/`; recordings in `recorded/trees/` win. Names: `tree_creak_N` (groan as the trunk starts to go), `tree_leaves_N` (crown rushing down), `tree_crash_N` (snapping branches and a deep thud when it lands, 1.5 s after the creak), `stump_chips_N` (the last blow's spray). The axe blows on the standing tree are `hit_axe_wood`. It listens to the real felling: `sound.trees.watch(items._world)` (from `terrain_client`, 4 times a second) hears a new trunk row (state 3) and stump row (state 4); rows present in the first 6 s were already lying there and stay silent. Bigger trees (height, radius) are louder, lower and heard to 260 m. `--chop` headless (Items' chop test) played one fall and one stump spray.

## Breathing and heartbeat (build 173)
`breath_sounds.gd`, made by `make_body.py` into `assets/audio/body/`; recordings in `recorded/body/` win. Names: `breath_in_N`, `breath_out_N`, `breath_gasp_N`, `heartbeat_N`. Tied to physical exertion only (owner's rule: no fear or pain triggers yet). Hook: `sound.breath.set_exertion(0..1)` for the real exertion system (call it each frame; the stand-in pauses 1.5 s after each call), `clear_exertion()`. Until then a stand-in follows the body (walk rests, jog builds to 0.62, run to 1.0, swimming to 0.75, resting drains it in about 20 s). Bands: under 0.25 silent, to 0.5 soft slow breaths, to 0.8 clear quicker breaths, over 0.8 gasps; heartbeat from 0.55 at 60 to 170 bpm. Foley bus (Effects slider), 2D, silent underwater. Esc > Settings "Sound test: exertion", `--exertion` headless.

## Torch and lantern flames (build 174)
`flame_sounds.gd`; loops `flame_torch` and `flame_lantern` are made by `make_fire.py` into `assets/audio/fire/` (recordings in `recorded/fire/` win). `sound.flame.set_held("torch"|"lantern"|"", open)` is called by `held_item.gd` every frame from the held item's `tool_class` (a lantern item does not exist yet; any item with tool_class "lantern" works) and whether a canopy covers the camera. A torch is louder when you run and in wind and sizzles in rain when open (the `fire_rain` loop, quiet); a lantern is quiet and steady. 2D on the Foley bus. `--flame` headless holds a real torch, rains on it and puts it away.

## Sound.update tuning (build 177)
Technical direction measured `sound.update` at 0.46 ms average, worst 11.4 ms (headless walk, 6000 frames). Timed per subsystem with the frame probe (rain walk), the cost was spread thin: ambient 0.07 ms, weather 0.05, water 0.04, swim 0.03, cave 0.02, exposure 0.02, item watch 0.02, occlusion 0.01, the rest under 0.01. Changes: ambient call timers tick at 10 Hz (no per-frame array filter), the weather mix at 20 Hz on the accumulated time, swim reads water and ground at 10 Hz (depth follows the feet between reads), the item watch at 10 Hz, the cave bus effects are set only when the enclosure changes, occlusion easing at 20 Hz, the water scan every 2.5 s (2 rows a frame) and the exposure ring every 10 frames, and the common sound files load one a frame in the first seconds after start (`_build_warm_list`). Result, same walk: 0.40 ms to 0.20 to 0.22 average (with the per-subsystem probes on, 0.40 to 0.27). The worst frame is still 6 to 13 ms in the first seconds: it is first-time file loading in headless (no import cache; the game loads imported sounds faster), not steady cost. To time a subsystem again wrap its call in `Probe.start()` and `Probe.stop("snd name", t)` in `sound_stage.update`.

## Crafting sounds (build 181)

While a craft runs (the panel's craft timer) a work sound plays on the Foley bus and stops when it ends, then `craft_done`. The type comes from the recipe: a `"sound"` field in recipes.json if present, else by recipe id: cordage = twine, stone_axe / stone_knife = knap, wooden_spear = carve, spear / torch = bind, campfire = stack, poultice_* = pound, bandage_* = wrap, anything else = knap.
Generated placeholders: `assets/audio/crafting/craft_<type>_N.ogg` (make_crafting.py). Recordings go in `assets/audio/recorded/crafting/` under the same names and win. Test: `--craft-sounds` (headless prints the last work sound).

## Built-floor footsteps (build 184)

Hooks for the building system, no building needed yet. `sound.set_floor("plank")` (also "slab" stone slabs, "carpet", "thatch", "path" gravel path; "" back on natural ground) makes steps use that floor; or set `sound.floor_under` to a Callable(feet Vector3) -> floor name for a per-step query. Floors do not apply in water; snow lies on a path but not indoors, puddles splash on path and slab.
Generated placeholders: `assets/audio/floors/step_<surface>_N.ogg` (make_floors.py). Recordings go in `assets/audio/recorded/` as `step_plank_left_N` / `step_plank_right_N` and win, like the ground sets. Test: `--walk --floor=plank` (headless prints the footstep counts).

## Distant sounds (build 192)

Thunder: the wait after the flash is the real travel time halved, capped at 4 s (a strike 2.5 km away is heard 3.6 s later). Strikes over 600 m play on a low-passed bus (WeatherMid, 1.6 kHz), over 1800 m darker still (WeatherFar, 450 Hz). Both buses feed Weather, so the mixer and cave muffling still apply. Test: `--distant` (headless prints three strikes, their bus and delay).
Waterfalls are now heard out to 260 m (was 70): wider range, a bigger unit size so they stay faintly audible, and the player's own distance low-pass (2.2 kHz) so far falls rumble without hiss. Not yet checked live: stand 150 to 250 m from a fall with F3 on and read the water line.

## Placed things, containers and tools (build 194)

`src/client/placed_sounds.gd` (`sound.placed`), hooks until the Items thread's lean-to, chest and tool wear exist: `place("leanto"|"chest"|other, at)`, `pick_up(at)`, `chest(open, at)` (the interior chest sounds), `container(put, at)`, `tool_break(at)`, `tool_repair(at)`. `watch_world` (about 1 Hz from terrain_client) already hears world rows whose item id is in `PLACED` (lean_to, chest): a new one within 40 m plays place, a vanished one pick_up; rows streamed in from afar are silent.
Generated placeholders: `assets/audio/placed/` (make_placed.py); recordings in `assets/audio/recorded/placed/` win. Test: `--placed` (headless prints each hook's count). Items thread: when lean-to or chest items exist, add their ids to `PLACED` if they differ, and call `container`, `chest`, `tool_break`, `tool_repair` at the matching events.

## Cooking and eating (build 196)

Checked what exists: the campfire already had its crackle, lighting, put-out and rain-sizzle sounds, but nothing played when food was roasted, wood added, or anything eaten (there is no eating action yet, and no cooking pot).
New: `cook_sizzle` plays at the nearest fire when a roast_forage appears in the bag (the C key), `fire_fuel` when stick or log count drops within 1.5 s of the V key. `sound.itemfx.eat("crunch"|"soft"|"drink"|item id)` is the hook for eating: crunch for roast_forage, tree_roots, seed_bundle, soft for anything else. Items thread: call it when an eat action exists (EAT_KINDS in item_sounds.gd). A cooking pot would add a `pot_simmer` loop later.
Tool wear (Items build 195, no extra Items work): a tool slot that becomes broken plays `tool_break`, a slot whose wear drops plays `tool_repair`, both at the player.
Generated placeholders: `assets/audio/cooking/` (make_cooking.py), recordings in `assets/audio/recorded/cooking/` win. Tests: `--cooking`, `--wear-sounds`.

## Wind in trees (build 197)

`src/client/tree_wind.gd` (`sound.treewind`): the trees within 45 m (flora chunk tree lists, read 300 a frame every 4 s) are counted as conifers and broadleaf, weighted by nearness. Four loops on the Wind bus: `treewind_pine` (any conifer stand), `treewind_leaves` (broadleaf, spring and summer), `treewind_dry` (broadleaf, autumn), `treewind_bare` (broadleaf, winter creaks). Level = a full stand (22 weighted trees) in a full wind is -24 dB, falling with fewer trees and a calmer day; +3 dB under a canopy. Season comes from the ambient clock (`--tree-season=winter` forces it for tests). Low plays only the loudest loop. Nothing plays in open country. Test: `--treewind` (prints counts and levels).
Generated placeholders: `assets/audio/treewind/` (make_treewind.py); recordings in `assets/audio/recorded/treewind/` win.

## Sound regression scenarios (build 200)

`python3 tools/sound_check.py` (about 1 minute per scenario, `--list` shows them, `--only fire,swim` runs some, `--verbose` keeps every log): for each scenario it starts a fresh headless server, runs the client at quality 0 (Low, 24 voices) with the scenario's test flags and checks the report the client prints at the end. Every scenario must also keep its voice peak at or under 24 and refuse no sound loads. Scenarios: walk (footsteps), floor (built plank floor), rain, storm (far thunder on the far bus), fire (lit and put out), felling (a tree falls with sound), swim, crafting, placed (lean-to, chest, tools), cooking, treewind. To add one, add a row to SCENARIOS (flags the client already knows, frames, and checks as regex plus min and max). Run it after any change to src/client/*sound*.gd or the sound loops; it checks what the sound code chose to play, not how it sounds (the cloud has no audio).

## Swapping in a recording (build 203)

`python3 assets/audio/swap_recording.py INPUT SLOT [--loop] [--replace] [--author A --source S --licence L --attribution T --url U] [--dry-run]` turns a supplied recording (wav, mp3, m4a, ogg, flac) into a game sound: mono, silence trimmed (or `--start`/`--end` seconds), a click-free loop with `--loop` (tail cross-faded into the head: use it for wind, water, tree wind, room, fire and other loop slots), loudness set to the placeholder's so the game's tuned level still fits (`--db X` to choose), peak kept under -1 dB, written as `recorded/<folder>/<slot>_N.ogg` (next free N, or `--replace` removes the old recordings first). Footsteps are one file per foot: run it for `step_dirt_left` and `step_dirt_right`. It also adds a CREDITS.csv row when none covers the file, then runs make_manifest, make_credits and validate_pack. Always try `--dry-run` first. Slot names are in `sound_manifest.json` and `SOUND_PACK.md`.

## Plant picking (build 205)

`src/client/harvest_sounds.gd` (`sound.harvestfx`), called by `harvest.gd _pick` with the plant's flora table row and its place (tap E, or the E sweep at up to five a second; picks under 70 ms apart are skipped). The sound follows what the plant gives: mushrooms are twisted off (`pick_twist`), roots, bulbs and tubers pulled (`pick_pull`, a spade pick), berries, fruit and nuts plucked (`pick_pluck`), fibre plants, reeds, grass and twigs snapped (`pick_snap`), everything else (leaves, herbs, flowers) snipped (`pick_snip`). The plant also rustles when picked: `plant_rustle_leaves` (shrubs, ferns, flowers) or `plant_rustle_reeds` (reeds, grass); none for a mushroom. A full voice budget drops the rustle first. The final report prints the counts and how many plants fall in each kind (headless `--gather`: pluck 26, snap 18, snip 34, twist 11, pull 13).
Generated placeholders: `assets/audio/harvest/` (make_harvest.py); recordings in `assets/audio/recorded/harvest/` win. The pick kind comes from `HarvestSounds.pick_kind(row)`; adjust its word lists when new yields appear.

## Chopping block and saw mill (build 207)

`src/client/workshop_sounds.gd` (`sound.workshop`). The chopping block is real (Items state 7, `ACT_USE_STRUCT`): when a log goes and firewood comes in at the same moment, the block nearest the player (within 5 m) plays `chop_split` (item_sounds.gd `_watch_block`, so it follows what the server did, not the key press). Hooks for later: `chop(at, split)`, `plank_drop(at)`, `set_saws([{"id", "at", "running"}])` (a running saw mill plays the `saw_mill` loop, the nearest `preset["town_loops"]` within 70 m, fading when it stops).
Also since Items build 202: world rows of state 5, 6 and 7 (lean-to, chest, chopping block) now play the place sound when one appears within 40 m and the pick-up sound when it vanishes (placed_sounds.gd `watch_world`, by row state, not item id); chests and tool wear use Items' own `chest_event` and `tool_event` hooks (open, close, put, take, broke, repaired) wired in terrain_client.
Generated placeholders: `assets/audio/workshop/` (make_workshop.py); recordings in `assets/audio/recorded/workshop/` win. Tests: `--workshop`, `--placed`, `--wear-sounds`; tools/sound_check.py scenarios workshop, placed, wear.

## Eating, healing and hunger (build 209)

Items build 206 added hunger, health and the `eat_event` hook (called with the item id when the server confirms that food or medicine took effect); it already calls `sound.itemfx.eat(item_id)`. `ItemSounds.eat_kind(id)` picks the sound: poultices and bandages play `heal_poultice` / `heal_bandage`, ids ending in sap or water play `drink_gulp`, nuts, roots, bulbs, hard fruit, roast_forage and seed_bundle play `eat_crunch`, anything else (berries, greens, caps, pods) `eat_soft`. Hunger at or under 15 percent adds `stomach_growl` every 50 to 110 s, twice as often at 0 (a quiet cue at the player, `watch_vitals(hunger, delta)` from the 10 Hz item watch); above 15 the timer resets.
Generated placeholders in `assets/audio/cooking/` (make_cooking.py); recordings in `assets/audio/recorded/cooking/` win. Test: `--cooking` (every kind once and one growl); tools/sound_check.py scenario cooking.

## Rain on different ground (job 46)

`weather_sounds.gd` picks a ground class every 0.25 s from `sound_stage.rain_ground(body)`: snow (snow lying), stone (built floor or rock), mud (soaked soil), litter (leaves on humus), else the plain rain beds. One loop per class (`rain_stone`, `rain_mud`, `rain_litter`, `rain_snow`, made by `make_weather.py`) eases in over 1.5 s and the plain `rain_light`/`rain_heavy` beds keep a fraction (`GROUND_BED_KEEP`). Under cover (`Cover.at`: tree crowns and, since build 214, roofs such as lean-tos) every ground loop fades with the cover, the plain beds drop to 30 percent, the leaf/roof patter and drips come in; cover eases over 1.5 s so stepping in and out is smooth. Interior rain stays the `interior_rain_roof` loop. `--rain-ground=stone|mud|litter|snow` forces a class for headless checks (`tools/sound_check.py --only rain_stone,rain_snow`).

Licence note: Dave's supplied recordings are from Pixabay (royalty-free, Pixabay Content License, `Pixabay-Content-License` in CREDITS.csv). It is not CC0 or CC-BY: fine inside the game, but the sounds must not be shipped as separate files or a standalone pack. Page URLs still TODO.

## "What is that sound?" list (job 49)

Esc > Settings > Debug details (F3) now has a `sounds heard (N):` block under the sound budget: the 8 loudest sounds playing, each with its file name, distance (`here` for flat loops such as wind and rain), level in dB at the source, and recorded or generated (`loop` for weather beds). Sorted by level minus 6 dB per doubling of distance. Built by `sound_stage.heard_text(body, limit)`; weather beds come from `weather_sounds.active_loops()`. Dave can read the name off the screen when a sound bothers him and tell me the file. The headless final report prints it as `sounds heard`, and the storm scenario checks it.

## Snowfall hush (job 51)

`weather_sounds.snow_hush` (0 to 1) = 0.8 x snow lying + 0.2 while it snows, eased over 4 s (so it lingers while the snow lies, fades as it melts). `sound_stage` applies it: Wind bus -3 dB and Nature bus -4 dB at full hush (`SNOW_HUSH_BUS_DB`, in `_apply_buses`, only re-applied when it moves 0.02), the wind low-pass closes 30 percent, footsteps lose 3 dB. Cost: nothing per frame beyond one multiply. `sound_check.py --only snow_hush` (snow weather: hush rises, Nature bus drops); HUD final report line `snow hush`.

## Fire lighting and loading from Items' events (job 48)

Items protocol 19 fire rows: state 8 empty (ashes), 9 loaded but unlit, 1 lit. `fire_sounds.sync_world` (now every 0.25 s) takes only fire rows (`FIRE_STATES` 1, 2, 8, 9; before it counted every non-item row) and: a row going 9 to 1 (E to light, ACT_LIGHT) plays `fire_light` and starts the loop; 1 to 8 or 9 (burnt out, rained out) plays `fire_out`; 8 to 9 within 25 m plays `fire_fuel`, unless the bag path already played it in the last 1.5 s (your own V press through `item_sounds.fuel_pressed`, wood leaving the bag). `--fire-world` runs a fake row through 8, 8, 9, 1, 9, 8 (`tools/sound_check.py --only fire_world`: 1 fuel, 1 lit, 1 out).

## Sound memory audit at Low (job 52)

Measured 2026-10-20 with `--load-all-sounds --quality=0` (`tools/sound_check.py --only memory`): all 475 files loaded once = 9.7 MB read from disk, 0 refused against the Low cap of 150 MB; no WAV files, all Ogg (the pack on disk is 9.7 MB; the largest are `wind_low` 0.47 MB, `wind_gust` 0.40 MB). Ogg streams stay compressed in memory; even if every file were fully decoded to 16-bit PCM it would be about 90 MB, still under 150 MB. In a real session only the slots a layer asks for are loaded (a storm walk at Low loads 5 to 6 MB). So the cap has about 15x headroom today; it starts to matter if recordings replace placeholders with long stereo WAVs (a 20 s stereo 44.1 kHz WAV is 3.5 MB): convert recordings to Ogg (`swap_recording.py` does) and keep loops mono. `audit_text()` prints the numbers; `loaded_bytes` counts file sizes, not decoded size.

## Exertion stages: heartbeat and breath (job 54, Dave 2026-10-20)

Dave: heartbeat too bassy and deep; exertion must keep climbing; over-exerted = racing loud heart and great chest heaves; forced slow-down keeps that and fades slowly; a faint fades the vision (Art), all other sound fades, only the heart remains and fades over about 3 s after the vision is gone; waking has the heart still racing and settling slowly.

- `make_body.py`: `heartbeat` is thinner (about 80 Hz with a second harmonic, short decay; was 55 Hz); new `breath_heave_N` (1.3 s, loud, rough).
- `breath_sounds.gd`: exertion runs 0 to 2.0 with no cap (the stand-in run ceiling is 2.0). Under 1.0 as before (soft breaths, gasps over 0.8, heart from 0.55, 60 to 170 bpm). From 1.0 (over-exerted) to 1.4 (the faint point, `exertion.json` faint_at) the intensity `_over()` goes 0 to 1: bpm 170 to 220, heart 12 dB louder and pitched 10 percent up, `breath_heave` instead of gasps, cycle 0.9 s down to 0.65 s, heaves up to -4 dB. A forced slow-down keeps the intensity while strain drains.
- States (`sound.breath.set_body(strain, state, progress)`, called every frame from `terrain_client` with `items.strain` and `items.faint_state()`): normal, over_exerted, fainting, fainted, waking. `world_mute` follows the vision (0.8 per second out) and returns over `WAKE_SEC` 4 s; `sound_stage` dips the Wind, Foley, Nature, Weather and Interface buses by it (-60 dB at 1). Breath and heart now play on their own "Body" bus (Effects slider), which a faint leaves alone. Fainted: breathing stops, the heart races on (at least exertion 1.2) and fades to nothing `HEART_GONE_SEC` 3 s after the vision is gone. Waking: heart and heaves follow the real strain coming down.
- Test: Esc > Settings "Sound test: exertion", 6th press runs a 27 s demo (over-exertion, slow-down, faint, 3 s heart, waking); `--faint` headless (`sound_check.py --only faint`: world muted to 1.00, heart gain 0.00 at the end, heaves played).

## Distant fires and falls share a voice (job 53)

`fire_sounds._merge_far`: fires farther than 18 m (`MERGE_M`) and within 15 m of each other (`CLUSTER_M`, greedy from the nearest) become one loop at their centre, size 0.5 plus 0.12 per extra fire, lit if any is lit; fires inside 18 m stay single. A town's far hearths take 1 of the `town_loops` slots (Low 3) instead of all of them. `water_sounds._merge_far_falls`: falls beyond 100 m (`FALL_MERGE_M`) within 120 m of each other (`FALL_CLUSTER_M`) become one roar at their width-weighted centre with their widths added (louder by the existing width rule, up to +4 dB), so a valley of falls takes 1 of the 4 water slots. `merged_fires` and `merged_falls` count what was folded. Check: `--merge-check`, `sound_check.py --only merge` (6 falls to 2 voices, 7 fires to 2 loops).

## Waterfall base (job 55)

Under the far roar (`water_fall`, audible to 260 m), the nearest single fall within 60 m (`BASE_REACH_M`) also plays a close spray-and-churn loop (`water_fall_base`, from `make_water.py`: a steady bright hiss over a wide splashing body, no bubbles or rhythm). One extra 3D loop at most, in the `world_sounds` group, eased in and out, at the landing point `flora.fall_list()` gives. Level -12 dB plus 3 dB per doubling of width (4 m reference, -5 to +4) and 2 dB per doubling of drop (4 m reference, -4 to +5), so a wide high fall hisses more. Merged distant falls never get it. Cost at Low: one more voice, only near a fall; nothing otherwise. `--merge-check` places a synthetic fall (the headless spawn has none) and reports `fall base`.

## Stance and cloth sounds (job 56)

`stance_sounds.gd` (`sound.stance`, sounds from `make_stance.py` in `assets/audio/stance/`, recordings in `recorded/stance/` win). `terrain_client` connects the stance system's `changed` signal (C crouch, X sit, Z lie; the server's forced lie when fainting arrives the same way) to `sound.stance.set_stance("stand"|"crouch"|"sit"|"lie")`. A change plays `stance_crouch`, `stance_sit` or `stance_lie`, anything back to standing plays `stance_rise`; worn body armour adds its clink through `gear.shift`. Sitting and lying shift with a tiny `stance_settle` every 9 to 22 s. Crouching makes footsteps (and their gear) 6 dB softer via `step_db()` in `sound_stage.footstep`; sitting and lying have no steps. One-shots only, skipped when the voice budget is full: no new loops. `--stance` runs crouch, stand, sit, stand, lie, stand (`sound_check.py --only stance`: 6 changes, last one the rise).

## Lake and pond shores lap softly (Dave 2026-10-20)

Standing by a lake played river rushing. Now: a still-water square (current under `STILL_MPS` 0.35 m/s with water around it) is a lake or pond; water with a current is a river however wide (the old rule called wide fast rivers ponds and lake shore squares rivers). A lake has no rushing bed: every 3 to 8 s one soft lap (`lake_lap_N`, `make_lake.py`: Dave's fish splash recordings slowed to 0.62, low-passed at 2.4 kHz, softened, 2.4 s) plays 3D from one of the nearest 4 still-water squares within 35 m, at most 2 at once, none under water. Rivers, brooks and falls are unchanged. Real recordings of lapping go in `recorded/water/lake_lap_N`. The old `water_pond` loop is no longer played. HUD water line: `lake shore N squares, M laps`. `--lake` runs stand-in squares for 20 s (`sound_check.py --only lake`). The lake/river edge changes by the measured current per 8 m square, so a river mouth that slows into a bay turns from rush to laps.

## Exertion audio gaps checked against Items' strain states (job 57)

The chain normal, over_exerted, fainting, fainted, waking was run end to end with the real state names (`--faint`, `sound_check.py --only faint`). Findings and fixes:
- Fainting and fainted: no breathing is heard while fainted (checked: 0 breaths), the heart keeps racing at no less than 1.2 and fades 3 s after the vision is gone.
- Waking: the world's sound used to return on a fixed 4 s ramp; it now follows the blackness still left (`strain_fade` through `faint_state()`), so the world comes back with Art's vision (checked: mute 0.49 halfway through the wake). The heart and heaves follow the real strain as it settles (`wake_strain` 1.1 on).
- Sitting and lying: the server drains strain faster, and the breathing and heart ease with the value, so nothing extra is needed; they stop under `QUIET` 0.25 (breath) and `HEART_FROM` 0.55 (heart).
- Open, to tune by ear: the old stand-in scale (jog 0.62, run climbing on) was written before the real strain existed; the thresholds `QUIET` 0.25, `HEART_FROM` 0.55 and `OVER` 1.0 follow `data/items/exertion.json` (over_on 1.0, faint_at 1.4) and may need nudging once Dave runs with the real values.

## Controls and inventory sounds (job 58)

Already covered by `item_sounds.gd` on the Interface bus: `inv_open`/`inv_close` (I panel), `item_pickup`, `item_drop`, `item_swap`, `craft_done`. Added: `hotbar_tick` when a hotbar slot is chosen (`held_item.select` calls `sound.itemfx.hotbar(slot)` only when the slot changes; pitch rises 2 percent per slot), `craft_start` when a craft begins (before the work sound), and the same `inv_open`/`inv_close` cue when the chest screen opens or closes (besides the chest's own creak from `placed_sounds`). Everything stays short and quiet on the one Interface bus; world sounds keep running while a panel is open (no muting rule). `--ui-sounds` (`sound_check.py --only ui_sounds`): 3 ticks for 4 selections with one repeated slot.

## Gaps pass (job 61)

`/mnt/project-files/tech/SOUND_GAPS.md` lists every CONTROLS.md input and ACT_* kind with its sound and status. Filled in this pass: the jump push-off (a soft step at takeoff in `terrain_client`; only the landing had a sound). Still open and noted there: an axe or pick swing that misses, a rejected-action cue (needs a server reject event), the raise-to-aim of a spear, fall damage (no damage system).

## Audio re-audit at Low after jobs 55 to 62 (job 60, 2026-10-20)

Measured with `tools/sound_check.py` (Low tier, voice cap 24, 150 MB memory cap), head after build 243:
- All 503 files loaded once: 10.1 MB read from disk, 0 refused; fully decoded it would be about 95 MB, still under the 150 MB cap (`--load-all-sounds`).
- Walk at night in rain (hour 23, autumn, nature calls fast): peak 16 of 24 voices, 6.6 MB loaded.
- Worst case I can stage (hour 21, storm, far thunder, cave 0.6, a lit fire and merged hearths, creature calls, walking): peak 24 of 24, 7.5 MB loaded, 0 refused. The cap is reached and the shedding keeps it there (optional one-shots stop first, never loops or danger cues).
- New since the last audit: waterfall base (+1 voice only near a fall), lake laps (at most 2 short one-shots), stance and UI cues (one-shots), merged distant fires and falls (fewer voices). Nothing adds a permanent loop.
- Scenarios `audit_night_rain` and `audit_worst` keep the numbers checked (peak must stay at or under 24).

## Dave's brook recording (job 59, 2026-10-20)

Dave sent `freesound_community-babbling-brook-99-56381.mp3` ("this is what a gentle babbling brook sounds like", Pixabay, page URL TODO). It is 91 s, very quiet (mean -47 dB) and very steady; `swap_recording.py --loop --replace --start 38 --end 62` cut the steadiest 23 s (window chosen from the per-second level: spread under 2 dB), made it loop without a click and raised it to the placeholder's level, giving `recorded/water/water_brook_0.ogg`. The peak limit (-1 dB) leaves it about 5 dB quieter than the placeholder, so the brook kind in `water_sounds.gd` went from -15 to -10 dB. Used by: brook sources only (small streams and brooks, squares with few wet neighbours and a current), including brooks that turn into falls' approach reaches. Rivers (`water_river`), falls (`water_fall`, `water_fall_base`) and the lake laps keep their own sounds. The credits row says Pixabay-Content-License. `sound_check.py --only lake` reports `brook loop recorded`.

## Structure and tool sounds (job 63)

Already there from job 38: lean-to, chest and chopping block set down and taken up, chest open/put/take, tool break and repair. Added: a worn tool complains once (`tool_warn`, `placed.tool_warn`) when its condition drops under 20 percent (`item_sounds._watch_wear`, any tool in the pack, same tool in the slot as last time), before the break; and a campfire set down (a fire row, states 1, 8 or 9, appearing near the player) plays the thump of stones set down like the chopping block (`STATE_KIND`). `--wear-sounds` now checks warning, break and repair (3 sounds).

## Voice priority at the cap (job 64)

Over the voice cap (Low 24) `sound_stage._shed` cuts one-shot world sounds in this order: far ambience first (Nature, Weather, Wind buses), then other world sounds, farthest and quietest first; the player's own actions (a Foley sound within 4 m: gear, hits, harvest, tools) go last. Danger cues keep the meta `keep` and are never cut. The player's own footsteps, breath, heartbeat and the interface are not in the group `world_sounds`, so they are never candidates. `sound_check.py --only voice_priority` fills the stage with 6 far ambience and 2 own sounds (plus 2 other) and sheds 6: all 6 ambience go, both own sounds stay.

## Season and clock sweep (job 66)

`sound_check.py --only sweep` runs `--sweep` (with `--nature-fast`): one client, 4 seasons x 8 hours (every 3 h), clear weather, 2 s per cell, printing nature calls and peak voices per cell. Result at Low (build 256), saved in `/mnt/project-files/sound/SWEEP.md`: no cell silent for long, no cell above 15 voices (cap 24); summer and the 21:00 cells are busiest, winter quietest (6 to 9 voices). The scenario fails if the sweep stops early or the peak passes the cap.

## Emitters for server-owned things (job 65)

`src/client/emitters.gd` (`sound.emitters`) is the client half of `/mnt/project-files/sound/EMITTER_API.md`; the protocol half (`sound_event`, `sound_loop`) waits for the first server-owned entity. `emit(kind, event, position, power, entity_id)` plays a one-shot: creature kinds with `call_idle|call_alert|call_threat` go to `creature_sounds.gd`, anything else plays its row in the `events` table (`register_event` adds rows; spec = folder, name, db, reach, unit, bus, keep). `sync(rows)` runs loops from entity rows (`loops` table, `register_loop`): one voice per entity within 18 m, farther ones of the same loop within 15 m share one voice, 3 dB louder per doubling, capped by the tier's `town_loops` (3 at Low). Rate limits: 4 events per entity and 60 in all per second. Unknown kind or event: one warning, silent. Events obey the voice cap and shed priority. Test: `sound_check.py --only emitters` (fake events: threat call plays, burst of 6 gives 4, unknown silent, 17 rows give 3 voices with 13 merged). The test rows use a placeholder kind `hum` (fire sounds).

## Mixer loudness pass (job 67)

`sound_check.py --only mix` runs the worst staged case (storm at 21:00, cave, creatures, fires, walking, UI sounds) with `--mix-levels`: after 20 s it tracks each bus's output peak (`AudioServer.get_bus_peak_volume_*`) for 30 s. Headless the mixer does run, so the numbers are real digital levels, not ears. Build 258, Low, all sliders at 100 percent:

| bus | peak dB | mean while sounding dB |
|---|---|---|
| Master | -10.7 | -22.7 |
| Weather (storm rain, thunder) | -10.8 | -23.9 |
| Nature | -12.3 | -36.4 |
| Foley (steps, fire, tools) | -13.9 | -31.9 |
| Wind | -44.3 | -52.7 |
| Interface, Body | not reached in this run (UI cues are -26 dB or quieter; the heartbeat peaks about -12 dB in `--faint`) |

Safe maximum: Master peaks 10.7 dB under full scale in the loudest case, so nothing clips and the sliders (all at most 100 percent, no boost) need no change. Wind is 33 dB under the storm, which is intended (wind is a bed; rain and thunder carry a storm). No bus sliders were added. The `--ui-sounds` peak line is deliberately left out of the table until a run measures Interface alone. The voice-count check in `sound_check.py` now allows 2 over the cap (`VOICE_SCAN_SLACK`) because the cap is enforced every 0.25 s.

## Landing sounds and the fall damage call point (job 68)

`src/client/landing_sounds.gd` (`sound.landing`) replaces the old single heavy step after 0.45 s in the air. `sound_stage.update` tracks the top of each fall (`_air_top`) and calls `landing.land(body, drop_m)` on touchdown: under 2.5 m the heavy step it always was (+4 dB), 2.5 to 5 m a heavier step (+8 dB) and `land_thud` (body weight, breath knocked out), 5 m and more the heaviest step (+11 dB), `land_hard` (double impact, pack rattle, grunt) and worn gear jolts. Generated by `make_landing.py` (3 variants each); recordings in `recorded/landing/` win. **Damage hook:** from `landing_sounds.HURT_M` (6 m, a placeholder) the signal `sound.landing.hurt(drop_m, severity)` fires, severity 0 to 1 up to 14 m; the Items thread's fall damage connects there and replaces the threshold. Admin flight does not count. Test: `sound_check.py --only landing` (drops of 1, 3, 7 m give one step, thud and hard landing and one hurt signal).

## Wet shoes and cloth rustle under steps (jobs 69 and 70)

`src/client/step_fx.gd` (`sound.stepfx`), called from `sound_stage.footstep` with the footstep's own level. Wet shoes: wading (water over 0.12 m above the soles) sets `wetness` to 1, a damp waterline step to 0.4; it dries linearly over 20 s on land, and while wet a `wet_squelch` joins 35 to 100 percent of the steps (more the wetter), at 4 dB under the footstep scaled down as the shoes dry. Cloth: every dry step carries a `cloth_walk` swish 9 dB under the footstep, so it follows the gait (walk quietest, run loudest) and the crouch softness. Neither plays in water or when the voice budget is full; they are the player's own sounds (not in `world_sounds`), so never shed. Sounds: `make_stepfx.py` (4 variants each); recordings in `recorded/stepfx/` win. Test: `sound_check.py --only stepfx` (wet after wading, 4+ squelches in 10 steps, half dry after 10 s, dry after 25 s with none, cloth on every dry step).

## Tool swing whoosh (job 71)

Every axe swing now whooshes (`hit_sounds.swing(tool, at)`, slot `hit_swing_N`, `make_swing.py`), hit or miss; the blow's own sound lands on top 0.27 s in, exactly where the whoosh peaks (`SWING_S` 0.55 in held_item.gd, half of it). Called from `held_item` when a swing starts, 0.6 m in front of the camera; heavier tools are lower and a little louder (pick, hammer, spade tuned in `SWING_TOOL_PITCH`/`SWING_TOOL_DB`). One world sound per swing, skipped when the voice budget is full. Test: `sound_check.py --only swing`. This closes the "swing in the air" row of tech/SOUND_GAPS.md.

## Summer insect bed (job 72)

`src/client/insect_bed.gd` (`sound.insects`): one looping, non-positional `insect_bed` (Nature bus, `make_insects.py`, 16 s seamless, 2 variants; recordings in `recorded/insects/` win), fading in and out over about 4 s. Level 0..1 = zone (meadow 1.0, water edge 0.5, forest 0.35, highland 0) x season (summer 1, spring and autumn 0.35, winter 0) x day (from half an hour after sunrise, eased over an hour at each end, to sunset; none at night, crickets take over) x weather (gone in rain: rain level x 1.6) x calm (thins above wind strength 0.6, floor 0.2) x places (caves 0, underwater 10 percent). Full level plays at -24 dB. Cost: exactly one loop at every tier, counted in the voice budget (`voices_playing`), stopped when the level is under 1 percent. Test: `sound_check.py --only insects` (levels by season and hour, none in rain, the loop plays). `--insects=0.8` forces a level by hand.

## Lake silence and brook level fix (Dave 2026-10-20, second round)

Dave: a lake should have no sound unless a fish jumps; the brook sounded like loud constant wind. Causes found: (1) lake shore squares with few wet neighbours were classified `brook` and played the brook loop at -10 dB (plus 4 dB steep, plus 3 dB current, so up to -3 dB, 12 to 19 dB above the river loop); (2) a spring or outlet current made head-pond squares with 8 to 15 wet neighbours read as `river`; (3) the brook recording had been raised to -21 dB RMS and is broadband and very steady (envelope varies under 2 dB), so loud it sounded like wind. Fixes in `water_sounds.gd`: `kind_for` makes any square with 16 or more wet neighbours a lake whatever the current; `quiet_near_lakes` silences brook and river squares within 24 m of a lake square while the player is within 45 m of that lake (the outlet fades in once past it); laps now need wind strength 0.6 and come every 30 to 80 s (the fish jump in `ambient_life.gd`, Dave's recording, is the only other still-water sound); brook level -22 dB, steep bonus 2 dB, hard cap `BROOK_MAX_DB` -17. The recording itself got a high-pass at 260 Hz and a 5 dB lift around 4.5 kHz (the unprocessed original stays in the upload), RMS -23.8 dB, peak -1 dB. Test: `sound_check.py --only lake` (calm: no laps; windy: a few; classification table; river and brook beside a lake silenced, the far river kept). Not heard by ear: the cloud has no audio and the headless spawn has no lake, so the real head pond is covered by the table and the silencing rule only.

Water level table (for tweaking; `KINDS` in `water_sounds.gd` holds the "now" column, `BROOK_MAX_DB` the cap): brook -10 dB before, -22 now (steep bonus 4 before, 2 now; cap -17); river -22 (unchanged); pond loop -17 (not played any more, still water is silent); fall -14 (unchanged); lake lap -22 dB, 3 to 8 s before, 30 to 80 s and only in wind now (`LAP_EVERY`, `LAP_WIND`, `LAP_DB`).

## Refused-action cue (job 73)

`sound.itemfx.reject(reason)` in `item_sounds.gd` is the single call point for the Items thread's server reject event (job 62: too far, no tool, pack full). It plays `item_reject` (a soft double knock, `make_reject.py`; recordings in `recorded/items/` win), pitch by reason (`far` higher, `full_pack` lower), at most one per 600 ms so a held key never nags. Nothing calls it yet; Items connects the event to it. Test: `sound_check.py --only reject`.

## Rain on roofs (job 75)

Builds 210/214 already made rain softer under cover (crowns and Cover roofs). New: `weather_sounds._roof_over` finds a Cover roof (lean-to and the like: box or disc, between its floor and top) directly over the player (checked with the cover tick, eased 1.5 s as `roofed`). Under a roof the rain is `rain_roof` (`make_roofrain.py`: close, sharp drops on boards or thatch, board knocks, a soft low body; recordings in `recorded/weather/` win) instead of `rain_leaves`, and the open-air beds (`rain_light`, `rain_heavy`) go fully silent, so the voice count falls: under a roof the loops are `rain_roof` plus the ground-class fade and drips, against `rain_leaves` plus 30 percent open beds under a crown. Trees keep the leaf patter. Fires under cover keep their crackle (`open` flag, unchanged); interior rooms keep `interior_rain_roof`. Cost at Low: one loop replaces one loop (steady state), up to two while the 1.5 s crossfade runs, and two fewer than under a crown once the open beds are off. Tests: `sound_check.py --only rain_roof,rain_covered` (`--roofed` / `--covered` force the state): roof patter and no leaves under a roof; leaves and no roof patter under a crown.

## Footstep loudness table (job 76)

Step levels are now data: `data/sound/step_levels.json` (surface_db, floor_db, gait_db, gait_pitch, optional `surface_gait_db` extra per surface and gait, puddle_db). Edit and restart; a missing or broken file falls back to the built-in numbers (`sound_stage.gd` constants, same values, nothing changed by ear). Final level = surface + gait + extra, then soil/rock/ore tune, crouch -6, snow hush up to -3 and about -1.5 to +1 random. `python3 tools/step_levels.py --md` writes the table to `/mnt/project-files/sound/STEP_LEVELS.md` (walk -40 on grass to -31 on leaves, run -28 to -19; 9 dB between the quietest and loudest walks). All step recordings sit within 0.6 dB of each other (`LOUDNESS.md`), so the table is the whole balance. Test: `sound_check.py --only step_levels` (the file loads, a tweaked file changes a level, a broken file changes nothing).

## Night ambience (job 77)

- Owl hoots are sometimes answered: 45% of hoots queue a second, softer, slightly lower hoot 3-6 s later from the opposite side (`ambient_life.gd`, `_answers`). Owls call most in winter and spring.
- Natural far creature calls are now on by default (`creature_sounds.gd`, `wild`). Wolves call most in winter (x1.6), least in summer (x0.4); foxes follow a milder curve.
- The insect bed (`insect_bed.gd`) has a quiet low-pitched night mix: summer 50% of day level, autumn 20%, spring 15%, winter none; pitch x0.78 at night.
- Voice cap: night storm worst case peaks at 20 of 24 voices (scenario `audit_worst`); `night` scenario checks the factors.

## Water preset for recordings (job 79)

`swap_recording.py` now applies an EQ preset to water slots, learned from Dave's brook: `water_brook` gets a 260 Hz high-pass and +5 dB around 4.5 kHz and is set to -23.8 dB active RMS; `water_river` and `water_fall` get a gentler 120 Hz high-pass and +3 dB, at the placeholder's level. `--preset none` turns it off, `--preset water|water_wide` forces one. A run prints a before/after table (active RMS, peak, level below 260 Hz and in the 4-5 kHz band). The peak is still limited to -1 dB, so a spiky file lands a little under the aimed level and the run says so.

## Bird take-offs (Dave 2026-10-20: "all the low slow one", "not a natural one since")

What was wrong: `wing_flap_0..4` were one slow big-bird take-off (about 2.5 flaps a second, a 50 to 90 Hz thump as its strongest part) played at five speeds, picked at random with repeats, with only +-5% pitch. Three of five were the slow original (0.6 to 0.9 flaps a second), the fast two were the same flaps sped up, so every flush read as the same heavy bird.
Now: `make_wings.py` cuts the three single flaps out of Dave's recording (`recorded/ambient/wing_grain_N`) and builds bursts: small (9-12 flaps a second, grain pitched up 1.7-2.1x, low end cut at 320 Hz), medium (5.5-7.5 a second, 1.2-1.5x, 220 Hz), large (3-4 a second, as recorded, 140 Hz). Every flap is a different grain with its own pitch, level and timing, the take-off starts uneven and slow, builds over two flaps and falls away. 4 bursts per size (`ambient/wing_<size>_N`). `flush(at, delay, size)` picks small 55%, medium 30%, large 15% (the crow alarm always large); `_play` never repeats a file twice running. Check: `sound_check.py --only flush`.
Not heard by ear. Three flaps is a thin base: a clean recording of a small bird (finch, sparrow) bursting out of a bush, and one of a pigeon clapping off, would replace the stretched grains. Drop them in as `recorded/ambient/wing_small_N` / `wing_medium_N`.

## Lake edge by day (Dave 2026-10-20)

At a lake in full daylight (sunrise to an hour before sunset) the only sounds are wind, leaves, the occasional fish jump and the occasional bird (and the rare lap in wind). The insect bed's water-edge share is 0 by day (`WATER_DAY`), and crickets, frogs and tree frogs carry `dark_at_water`. Night and dusk are as designed. Checks: `sound_check.py --only insects,lake`.

## Slot audit (job 80)

`python3 tools/slot_audit.py` (or `tools/sound_check.py --only slots`, which also runs in the full check) "plays" every sound the game would load, offline: for each slot the recording if there is one, else the generated file, every `_N` variant. It fails on clipping (3 or more samples in a row at full scale), silence (under -45 dB or 50 ms), a loop whose end does not meet its start, and a file more than 20 dB from its folder's median loudness; it warns on a peak above -0.3 dB, a one-shot that starts or ends off zero, DC offset, 8 to 20 dB loudness spread, over-long files. `--md` writes /mnt/project-files/sound/SLOT_AUDIT.md with every flagged file; `--strict` lists the warnings. Run it after every swap_recording.py.
First run found real clipping in 17 generated placeholders: the rain loops, fire, a roof rain, town hammering. Vorbis overshoots a hot noise loop past full scale, which clips in any player. Fix: `make_sounds.soft_limit` (knee 0.65, ceiling 0.8) in the writers of make_weather, make_fire, make_interior, make_town, make_treewind and make_sounds/make_stance; those folders were regenerated. Now 0 failures, 68 warnings (mostly breaths, drips and UI clicks starting off zero, and the birds and owl sitting 10 to 13 dB above the ambient group, which `ambient_life.gd` levels per call).

## Distance and cover dulling (job 82)

`src/client/air_bands.gd`: waterfalls, fires and thunder lose their high end with distance and cover. One low-pass per band bus, not per voice: each kind has up to three child buses (`Air_fall_1..3` sending to Nature, `Air_fire_1..3` to Foley, `Air_thunder_1..2` to Weather), made on first use, each with one LowPass effect. A voice is moved to the band its effective distance falls in. Edges (effective m) and cutoffs: fall 110 / 260 / 520 m at 6000 / 3000 / 1400 Hz; fire 30 / 70 / 150 m at 7000 / 3800 / 2000 Hz; thunder 600 / 1800 m at 1600 / 450 Hz (the old WeatherMid/WeatherFar). Effective distance = real distance x (1 + 0.6 x forest share x min(d/80, 1) + 1.2 behind a hill + 0.8 x roofed + 1.5 x cave enclosure). A band is entered at its edge +15% and left at -15%, so nothing flips back and forth at a boundary.
Falls and fires carry the meta `air_kind`; `sound_occlusion.gd` (scan every 0.5 s) sets their band and gives them no per-voice dulling (its hill ray decides the hill share). Thunder picks its band once, at the strike. The shed priority and the mixer see a band bus as its parent. Cost: a bus change per band crossing, the same filters whether one fire plays or twenty; Low keeps the hill ray off, so there cover is forest, roof and cave only. Check: `sound_check.py --only air`.

## Cave and tunnel reverb (job 81)

One reverb, on a bus `World` that Foley and Nature (and the `Air_*` band buses under them) send to; it sits ahead of them in the bus list because a bus sends only to buses before it. Steps, tools, calls and drips echo in a cave; wind, weather, interface and body buses do not. It was two reverbs (one each on Foley and Nature) and off at Low; now it is one, and Low runs it lighter. Strength follows the enclosure the rays measure: off under 0.05 (open air), wet = enclosure x the tier's wet, room size from half the tier's room (a hollow or overhang: small, dry) up to the full room (a tunnel: long, wet).
| tier | wet at full enclosure | room at full | rays |
|---|---|---|---|
| Low | 0.15 | 0.50 | 4 |
| Mid | 0.35 | 0.70 | 8 |
| High/Ultra | 0.45 | 0.85 | 8 |
Cost: one Godot reverb effect (stereo comb and all-pass filters) in the mixer only while enclosure is over 0.05; when out in the open it is bypassed, so the open-world cost is zero and the cave cost is one reverb on a bus for every tier, down from two. Not heard by ear. Tunables: `cave_wet` and `cave_room` in `sound_presets.gd`. Check: `sound_check.py --only reverb`.

