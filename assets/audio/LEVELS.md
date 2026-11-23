# Heard levels (make with `python3 assets/audio/level_pass.py --md`)

dB at the ears in a reference scene: clip RMS + play level + distance falloff (see the script's notes). Buses at 0 dB.

| kind | sound | heard dB |
|---|---|---|
| local | a volcano vent bed 5 m away | -23.5 |
| local | a pond bed 5 m away | -26.5 |
| work | another player's axe on wood at 10 m | -27.1 |
| animal call | wolf warning (wolf_growl) at 40 m | -28.5 |
| weather | heavy rain (allowed to drown things) | -29.5 |
| weather | steady rain in the open (rain 0.5; allowed to drown things) | -30.9 |
| weather | drizzle in the open (rain 0.25) | -36.9 |
| animal step | wolf step at 20 m | -37.0 |
| animal step | fox step at 20 m | -37.4 |
| own run | own step, running on dry leaves (loud on purpose) | -37.7 |
| work | another player's axe on wood at 30 m | -38.3 |
| animal call | moose warning (moose_snort) at 40 m | -38.9 |
| everyday | bed_forest_winter bed (temperate_forest/boreal_forest/grassland/woodland, day_and_night), full | -39.0 |
| animal call | bear warning (bear_growl) at 40 m | -40.0 |
| everyday | bed_desert_wind bed (desert/dry_scrub, day_and_night), full | -40.5 |
| animal step | deer step at 20 m | -40.5 |
| animal step | moose step at 20 m | -40.9 |
| animal call | deer warning (deer_snort) at 40 m | -41.2 |
| everyday | bed_crickets bed (grassland/woodland/temperate_forest, night), full | -42.4 |
| everyday | own step, walking on dry leaves | -49.7 |
| everyday | summer insects, full | -50.1 |
| everyday | wind, strong (strength 1) | -52.8 |
| everyday | own step, walking on gravel | -53.2 |
| everyday | wind, a light breeze (strength 0.3) | -57.9 |
| everyday | own step, walking on grass | -58.4 |
| everyday | bed_night bed (any_except_desert_polar, night), full | -59.8 |

Loudest everyday sound: bed_forest_winter bed (temperate_forest/boreal_forest/grassland/woodland, day_and_night), full, -39.0 dB. Margins (animal minus that; the check allows down to -3): wolf step at 20 m +2.1, deer step at 20 m -1.4, moose step at 20 m -1.8, fox step at 20 m +1.7, wolf warning (wolf_growl) at 40 m +10.6, bear warning (bear_growl) at 40 m -1.0, deer warning (deer_snort) at 40 m -2.2, moose warning (moose_snort) at 40 m +0.1.

Drowned (more than 3 dB under the loudest everyday sound): none

Sources: steps: data/sound/step_levels.json (surface_db, gait_db); animal steps: src/client/slot_sounds.gd play: volume 0 dB at strength 1, CREATURE_STEP_UNIT_M and CREATURE_STEP_REACH_M, max_db 3 (Godot default); calls: src/client/creature_sounds.gd KINDS db, unit and reach (max_distance = reach x 1.2); max_db = db + NEAR_RISE_DB (max NEAR_MAX_DB); blows: src/client/hit_sounds.gd BASE_DB, unit 8 m, reach 120 m; wind: src/client/sound_stage.gd wind_low: WIND_LIFT_DB + 0.8 x (0.0035 + 0.006 x strength); rain: src/client/weather_sounds.gd LOOP_DB; insects: src/client/insect_bed.gd BED_DB at full level; beds: data/sound/batch2_slots.json weather_bed and time_bed slots that are on (status filled), src/client/ambience_slots.gd BED_TRIM_DB at full level
