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
