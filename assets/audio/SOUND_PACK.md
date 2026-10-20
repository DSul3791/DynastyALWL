# Sound pack manifest

Written by `assets/audio/make_manifest.py` (run it after adding sounds; edit its SLOTS table when a slot is added). **94 slots: 17 recorded, 73 generated placeholders, 4 empty.**

Drop a recording as `assets/audio/recorded/<folder>/<name>.ogg` (or `<name>_0.ogg`, `<name>_1.ogg` for variants; WAV works too). The game uses the recording and ignores the generated sound. Priority 1 means a real recording would improve the game the most; 5 means done. Licence and source of every recording go in `README.md` (section on supplied recordings).

## Sounds to supply, most wanted first

| Priority | Slot | State | Variants | Where it plays | What to supply |
|---|---|---|---|---|---|
| 1 | `bird_chirp` | generated | 3 | ambient_life.gd: meadow, water-edge and forest, the most frequent call | 3 to 5 short sparrow-like chirps, 0.5 s |
| 1 | `cricket_chirp` | generated | 3 | ambient_life.gd: meadow and water edge at dusk and night, summer and autumn | 2 to 3 cricket chirps runs, 2 s (one species) |
| 1 | `rain_heavy` | generated | 1 | weather_sounds.gd: heavy rain and storm loop | A heavy downpour loop, seamless |
| 1 | `rain_light` | generated | 1 | weather_sounds.gd: drizzle and light rain loop | A light rain on open ground loop, seamless |
| 1 | `thunder` | generated | 3 | weather_sounds.gd: a mid-distance thunder roll | 2 to 3 rolling thunder claps, 5 to 9 s |
| 1 | `water_brook` | generated | 1 | water_sounds.gd: a fast shallow stream, positional loop | A babbling brook loop, seamless |
| 1 | `water_river` | generated | 1 | water_sounds.gd: a wide slow river, positional loop | A broad river flow loop, seamless |
| 1 | `wind_gust` | generated | 1 | sound_stage.gd: the swelling gust layer on top of the bed | A leaf-and-grass rustling wind loop with soft swells, seamless |
| 1 | `wind_low` | generated | 1 | sound_stage.gd: the steady wind bed, louder with height and open ground, softer in trees | A calm open-field wind loop, 20 s or more, seamless, no gusts (low rumble layer) |
| 2 | `bear_roar` | generated | 2 | creature_sounds.gd: a bear's roar (threat), the danger cue | 2 to 3 bear roars, 1 to 2 s |
| 2 | `bird_trill` | generated | 3 | ambient_life.gd: meadow bird, by day | 2 to 3 trilling songs, about 1 s |
| 2 | `bird_whistle` | generated | 3 | ambient_life.gd: forest bird, by day | 2 to 4 clear songbird whistles, 1 to 2 s |
| 2 | `cave_drip` | generated | 5 | cave_sounds.gd: water drops in caves and tunnels | 3 to 6 single water drips in a stone room, 1 to 2 s each |
| 2 | `dig_rock` | generated | 3 | dig_sounds.gd: breaking rock | 3 pickaxe on rock or rock breaking sounds |
| 2 | `dig_soil` | generated | 3 | dig_sounds.gd: digging dirt and humus | 3 spade or shovel scoops into earth |
| 2 | `gear_chain` | generated | 3 | gear_sounds.gd: mail jingling on a step | 3 chainmail jingles, 0.4 s |
| 2 | `gear_plate` | generated | 3 | gear_sounds.gd: plate armour clanking on a step | 3 plate armour clanks, 0.4 s |
| 2 | `hit_axe_wood` | generated | 3 | hit_sounds.gd: an axe blow on wood (felling, chopping) | 3 axe chops into a log or tree |
| 2 | `hit_hammer_wood` | generated | 3 | hit_sounds.gd: a hammer blow on wood (building) | 3 hammer knocks on timber, or nails driven |
| 2 | `hit_pick_stone` | generated | 3 | hit_sounds.gd: a pickaxe blow on rock (mining) | 3 pickaxe strikes on rock |
| 2 | `owl_hoot` | generated | 3 | ambient_life.gd: forest at night | 2 to 3 owl hoots (tawny or barred), 2 to 3 s |
| 2 | `rain_leaves` | generated | 1 | weather_sounds.gd: rain pattering on leaves under trees | Rain on forest canopy loop, seamless |
| 2 | `swim_splash_big` | generated | 3 | swim_sounds.gd: a jump or fall into water (4 m/s and up) | 3 big splashes of a person falling in, 1 to 2 s |
| 2 | `swim_splash_small` | generated | 3 | swim_sounds.gd: the body enters water slowly (under 4 m/s) | 3 small body-into-water splashes, 0.5 to 1 s |
| 2 | `thunder_far` | generated | 3 | weather_sounds.gd: a far strike (over 1800 m): a low grumble | 2 to 3 distant low rumbles, 8 to 12 s |
| 2 | `thunder_near` | generated | 3 | weather_sounds.gd: a close strike (under 500 m): sharp crack and thud | 2 to 3 close, sharp thunder cracks, 2 to 4 s |
| 2 | `town_fire` | generated | 1 | town_sounds.gd: a hearth or forge fire (loop) | A seamless crackling fire loop |
| 2 | `town_hammering` | generated | 1 | town_sounds.gd: a smith or builder working nearby (loop) | A seamless loop of hammer on anvil, 8 to 15 s |
| 2 | `water_fall` | generated | 1 | water_sounds.gd: a waterfall roar | A waterfall loop, seamless |
| 2 | `water_pond` | generated | 1 | water_sounds.gd: gentle lapping at a pond shore | A calm lake shore lapping loop, seamless |
| 2 | `wind_storm` | generated | 1 | weather_sounds.gd: gale howl in storms and blizzards | A howling gale loop, seamless |
| 2 | `wolf_howl` | generated | 2 | creature_sounds.gd: a wolf's howl (idle), far away at night | 2 to 3 long wolf howls, 3 to 6 s, single wolf and a pack |
| 3 | `bear_growl` | generated | 2 | creature_sounds.gd: a bear's growl (idle, alert) | 2 to 3 low bear growls, 1 to 2 s |
| 3 | `bed_forest` | empty | 0 | ambient_life.gd (optional bed): a quiet forest background that fades in with forest cover | A quiet forest background loop, 30 s or more, no clear single calls |
| 3 | `bed_highland` | empty | 0 | ambient_life.gd (optional bed): highland wind and space | A thin high-altitude background loop |
| 3 | `bed_meadow` | empty | 0 | ambient_life.gd (optional bed): a meadow background | A meadow background loop (insects, distant birds), seamless |
| 3 | `bed_water` | empty | 0 | ambient_life.gd (optional bed): a water-edge background | A quiet marsh or lake edge background loop |
| 3 | `bird_feebee` | generated | 3 | ambient_life.gd: forest bird, by day | 2 chickadee-style two-note calls |
| 3 | `deer_grunt` | generated | 2 | creature_sounds.gd: a deer's low grunt (idle) | 2 to 3 low deer grunts or contact calls, 0.3 to 0.8 s |
| 3 | `deer_snort` | generated | 2 | creature_sounds.gd: a deer's alarm snort (alert, threat) | 2 to 3 deer alarm snorts, 0.3 s |
| 3 | `dig_clay` | generated | 3 | dig_sounds.gd: digging clay, mud and peat | 3 wet sticky digs |
| 3 | `dig_gravel` | generated | 3 | dig_sounds.gd: digging gravel | 3 gravel shovelling sounds |
| 3 | `dig_ore` | generated | 3 | dig_sounds.gd: digging out ore (metal clink on rock) | 3 pick on ore sounds |
| 3 | `dig_sand` | generated | 3 | dig_sounds.gd: digging sand and snow | 3 sand shovelling sounds |
| 3 | `dig_water` | generated | 3 | dig_sounds.gd: water pouring into a new hole | 3 water splashing into a pit |
| 3 | `fox_bark` | generated | 2 | creature_sounds.gd: a fox's bark (idle, alert), a night sound | 2 to 3 red fox barks, 1 to 3 per clip |
| 3 | `fox_scream` | generated | 2 | creature_sounds.gd: a vixen's scream (threat), a night sound | 2 to 3 red fox screams, about 1 s |
| 3 | `gear_cloth` | generated | 3 | gear_sounds.gd: clothes rustling on a step | 3 soft cloth rustles, 0.2 s, from walking in a tunic or cloak |
| 3 | `gear_iron` | generated | 3 | gear_sounds.gd: iron-shod boots clanging on a step | 3 iron boot clangs, 0.4 s |
| 3 | `gear_leather` | generated | 3 | gear_sounds.gd: leather armour or straps creaking on a step | 3 leather creaks, 0.3 s |
| 3 | `hawk_screech` | generated | 3 | ambient_life.gd: highland, by day | 2 to 3 hawk screeches |
| 3 | `hit_hammer_stone` | generated | 3 | hit_sounds.gd: a hammer blow on stone (chiselling, smithing) | 3 hammer clanks on stone |
| 3 | `hit_pick_soil` | generated | 3 | hit_sounds.gd: a pickaxe blow on soil | 3 pick strikes into hard earth |
| 3 | `hit_spade_soil` | generated | 3 | hit_sounds.gd: a spade strike into soil | 3 spade thuds into earth |
| 3 | `rain_drip` | generated | 4 | weather_sounds.gd: a drop falling from a leaf near you, under trees in rain | 3 to 4 single drops falling from leaves onto leaves or ground, 0.3 s |
| 3 | `rain_water` | generated | 1 | weather_sounds.gd: rain falling on ponds and rivers near the player | Rain on a lake surface loop, seamless |
| 3 | `swim_dive` | generated | 3 | swim_sounds.gd: the head goes under | 3 bubbling gulps of going under, 1 s |
| 3 | `swim_stroke` | generated | 3 | swim_sounds.gd: an arm stroke while swimming, one every 0.6 to 1.4 s | 3 breaststroke or crawl arm pulls through water, 0.5 s |
| 3 | `swim_surface` | generated | 3 | swim_sounds.gd: the head comes out of the water | 3 breaths and running water on surfacing, 1 s |
| 3 | `swim_under` | generated | 1 | swim_sounds.gd: the hum of being underwater (loop while the eyes are under) | A muffled underwater ambience loop, seamless |
| 3 | `town_bell` | generated | 3 | town_sounds.gd: a tower bell tolling the hour or on call (ring_bell) | 2 to 3 bell strikes with a long ring, 4 to 6 s each |
| 3 | `town_crowd` | generated | 1 | town_sounds.gd: a busy square murmur (loop) | A seamless crowd murmur loop, no clear words |
| 3 | `wolf_growl` | generated | 2 | creature_sounds.gd: a wolf's growl (alert, threat) | 2 to 3 wolf growls and snarls, 1 to 2 s |
| 3 | `woodpecker` | generated | 3 | ambient_life.gd: forest, by day | 2 to 3 woodpecker drumming runs, about 1 s |
| 4 | `frog_croak` | recorded | 6 | ambient_life.gd: ponds and rivers, spring to autumn, more at night and in rain | have: Dave's frogs (mostly small trillers); a deep bullfrog croak is still missing |
| 4 | `gear_hobnail` | generated | 3 | gear_sounds.gd: hobnailed boots clicking on a step (loud on stone, dull on soft ground) | 3 hobnail boot clicks, 0.1 s |
| 4 | `hit_axe_soil` | generated | 3 | hit_sounds.gd: an axe blow on soil | 3 axe thuds into earth |
| 4 | `hit_axe_stone` | generated | 3 | hit_sounds.gd: an axe blow on stone | 3 axe strikes on rock |
| 4 | `hit_hammer_soil` | generated | 3 | hit_sounds.gd: a hammer blow on soil (driving stakes) | 3 mallet thumps into earth |
| 4 | `hit_pick_wood` | generated | 3 | hit_sounds.gd: a pickaxe blow on wood | 3 pick strikes into wood |
| 4 | `hit_spade_stone` | generated | 3 | hit_sounds.gd: a spade scraping on stone | 3 spade scrapes on stone |
| 4 | `hit_spade_wood` | generated | 3 | hit_sounds.gd: a spade strike on wood | 3 spade knocks and scrapes on wood |
| 4 | `rabbit_squeak` | generated | 2 | creature_sounds.gd: a rabbit's distress squeal (threat) | 2 to 3 short rabbit squeals |
| 4 | `rabbit_thump` | generated | 2 | creature_sounds.gd: a rabbit's warning foot thump (idle, alert) | 2 to 3 rabbit hind-foot thumps, a double knock |
| 4 | `ui_click` | generated | 2 | ui_sounds.gd: every menu button pressed | 2 to 3 very soft, short interface ticks |
| 4 | `ui_off` | generated | 2 | ui_sounds.gd: a toggle switched off | 2 short falling two-note cues, quiet |
| 4 | `ui_on` | generated | 2 | ui_sounds.gd: a toggle switched on (inspection mode) | 2 short rising two-note cues, quiet |
| 4 | `ui_quality` | generated | 2 | ui_sounds.gd: the quality tier changed (F2 or the menu) | 2 soft settled chimes, 0.5 s |
| 5 | `crow_alarm` | recorded | 3 | ambient_life.gd: alarm(at): a crow scolds when the player runs through crow country, and the danger warning hook | have: Dave's angry crow |
| 5 | `crow_caw` | recorded | 7 | ambient_life.gd: forest and highland, by day | have: Dave's crow calls |
| 5 | `fish_splash` | recorded | 3 | ambient_life.gd: a fish jumps at the water edge, rare | have: Dave's fish jumping clip, played whole |
| 5 | `tree_frog_peep` | recorded | 6 | ambient_life.gd: water edge and forest, spring to autumn | have: Dave's frogs (short peeps) |
| 5 | `wing_flap` | recorded | 5 | ambient_life.gd: flush(at): a bird bursts out of cover and flies off | have: Dave's wing flaps |

## Footsteps (recorded left and right, `step_<ground>_<left|right>_N`)

| Slot | State | Files | Ground |
|---|---|---|---|
| `step_grass` | recorded | 6 | short grass ground |
| `step_grass_tall` | recorded | 6 | tall grass |
| `step_bushes` | recorded | 6 | walking through shrubs |
| `step_dirt` | recorded | 6 | soil, forest soil, clay, stony ground |
| `step_leaves` | recorded | 6 | leaf litter on forest humus |
| `step_mud` | recorded | 6 | mud, peat, wet ground, soaked ground in rain |
| `step_sand` | recorded | 6 | sand, beach, salt flat, ash |
| `step_snow` | recorded | 6 | snow |
| `step_stone` | recorded | 6 | rock, outcrops, ore, ice |
| `step_gravel` | recorded | 6 | gravel, soft rock |
| `step_water` | recorded | 6 | wading in water |
