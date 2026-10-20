# Sound pack manifest

Written by `assets/audio/make_manifest.py` (run it after adding sounds; edit its SLOTS table when a slot is added). **208 slots: 18 recorded, 181 generated placeholders, 9 empty.**

Drop a recording as `assets/audio/recorded/<folder>/<name>.ogg` (or `<name>_0.ogg`, `<name>_1.ogg` for variants; WAV works too). The game uses the recording and ignores the generated sound. Priority 1 means a real recording would improve the game the most; 5 means done. Licence and source of every recording go in `README.md` (section on supplied recordings).

## Sounds to supply, most wanted first

| Priority | Slot | State | Variants | Where it plays | What to supply |
|---|---|---|---|---|---|
| 1 | `bird_chirp` | generated | 3 | ambient_life.gd: meadow, water-edge and forest, the most frequent call | 3 to 5 short sparrow-like chirps, 0.5 s |
| 1 | `cricket_chirp` | generated | 3 | ambient_life.gd: meadow and water edge at dusk and night, summer and autumn | 2 to 3 cricket chirps runs, 2 s (one species) |
| 1 | `item_swap` | generated | 3 | item_sounds.gd: items moved between slots | 3 short slide and tap cues |
| 1 | `lake_lap` | generated | 3 | water_sounds.gd: a soft lap on a still lake or pond shore (random one-shots, no loop) | 3 soft water laps like a slowed, softened fish splash, 2 to 3 s; or a real recording of a lake lapping |
| 1 | `rain_heavy` | generated | 1 | weather_sounds.gd: heavy rain and storm loop | A heavy downpour loop, seamless |
| 1 | `rain_light` | generated | 1 | weather_sounds.gd: drizzle and light rain loop | A light rain on open ground loop, seamless |
| 1 | `thunder` | generated | 3 | weather_sounds.gd: a mid-distance thunder roll | 2 to 3 rolling thunder claps, 5 to 9 s |
| 1 | `tree_crash` | generated | 3 | tree_sounds.gd: the tree hits the ground (1.5 s after it starts to fall) | 3 big tree crashes: snapping branches and a deep thud, 2 to 3 s |
| 1 | `water_brook` | recorded | 1 | water_sounds.gd: a fast shallow stream, positional loop | A babbling brook loop, seamless |
| 1 | `water_river` | generated | 1 | water_sounds.gd: a wide slow river, positional loop | A broad river flow loop, seamless |
| 1 | `wind_gust` | generated | 1 | sound_stage.gd: the swelling gust layer on top of the bed | A leaf-and-grass rustling wind loop with soft swells, seamless |
| 1 | `wind_low` | generated | 1 | sound_stage.gd: the steady wind bed, louder with height and open ground, softer in trees | A calm open-field wind loop, 20 s or more, seamless, no gusts (low rumble layer) |
| 2 | `bear_roar` | generated | 2 | creature_sounds.gd: a bear's roar (threat), the danger cue | 2 to 3 bear roars, 1 to 2 s |
| 2 | `bird_trill` | generated | 3 | ambient_life.gd: meadow bird, by day | 2 to 3 trilling songs, about 1 s |
| 2 | `bird_whistle` | generated | 3 | ambient_life.gd: forest bird, by day | 2 to 4 clear songbird whistles, 1 to 2 s |
| 2 | `breath_gasp` | generated | 3 | breath_sounds.gd: ragged hard breathing at severe exertion | 3 hard gasping breaths of an exhausted runner, 0.7 s |
| 2 | `breath_heave` | generated | 3 | breath_sounds.gd: the great chest heave when over-exerted (exertion over 1) | 3 huge, loud chest-heaving breaths of someone at their limit, 1.3 s |
| 2 | `breath_in` | generated | 3 | breath_sounds.gd: breathing in, from moderate exertion | 3 soft breaths in through the mouth, 0.8 s |
| 2 | `breath_out` | generated | 3 | breath_sounds.gd: breathing out | 3 soft breaths out, 0.9 s |
| 2 | `cave_drip` | generated | 5 | cave_sounds.gd: water drops in caves and tunnels | 3 to 6 single water drips in a stone room, 1 to 2 s each |
| 2 | `chop_split` | generated | 3 | workshop_sounds.gd: a log split into firewood at the chopping block (heard when a log is traded for firewood beside a block) | 3 recordings of an axe splitting a log on a block, 0.8 s |
| 2 | `container_put` | generated | 2 | placed_sounds.gd: something put into a chest | 2 short wood clacks with a little rustle |
| 2 | `container_take` | generated | 2 | placed_sounds.gd: something taken out of a chest | 2 short rustles and a wood clack |
| 2 | `cook_sizzle` | generated | 2 | fire_sounds.gd cook(): food laid on the embers (heard when a roast appears in the bag at a fire) | 2 to 3 recordings of meat or food sizzling on embers, 3 s |
| 2 | `craft_done` | generated | 3 | item_sounds.gd: a craft finished | 3 wooden knock and small chime cues |
| 2 | `dig_rock` | generated | 3 | dig_sounds.gd: breaking rock | 3 pickaxe on rock or rock breaking sounds |
| 2 | `dig_soil` | generated | 3 | dig_sounds.gd: digging dirt and humus | 3 spade or shovel scoops into earth |
| 2 | `fire_fuel` | generated | 2 | fire_sounds.gd fuel(): a stick or log laid on a fire (V key) | 2 recordings of wood put on a fire with a flare of crackles, 1 s |
| 2 | `fire_large` | generated | 1 | fire_sounds.gd: a big fire (loop) | a bonfire loop with roar, crackle and pops, 10 to 15 s |
| 2 | `fire_light` | generated | 3 | fire_sounds.gd: a fire catches (one-shot) | 3 fire-lighting sounds: strike and soft whoomph, 1 to 2 s |
| 2 | `fire_out` | generated | 3 | fire_sounds.gd: a fire put out (one-shot) | 3 water or rain extinguishing a fire, hiss and steam, 2 to 3 s |
| 2 | `fire_rain` | generated | 1 | fire_sounds.gd: rain falling on an open fire (loop, only when raining) | rain sizzling on a campfire, 10 s loop |
| 2 | `fire_small` | generated | 1 | fire_sounds.gd: a small fire or embers (loop; crossfades with fire_large by size) | a quiet campfire loop, soft crackle, 10 to 15 s |
| 2 | `flame_torch` | generated | 1 | flame_sounds.gd: the torch in the hand (loop, louder when running and in wind) | a held torch burning, close to the ear, 10 s loop |
| 2 | `gear_chain` | generated | 3 | gear_sounds.gd: mail jingling on a step | 3 chainmail jingles, 0.4 s |
| 2 | `gear_plate` | generated | 3 | gear_sounds.gd: plate armour clanking on a step | 3 plate armour clanks, 0.4 s |
| 2 | `hit_axe_wood` | generated | 3 | hit_sounds.gd: an axe blow on wood (felling, chopping) | 3 axe chops into a log or tree |
| 2 | `hit_hammer_wood` | generated | 3 | hit_sounds.gd: a hammer blow on wood (building) | 3 hammer knocks on timber, or nails driven |
| 2 | `hit_pick_stone` | generated | 3 | hit_sounds.gd: a pickaxe blow on rock (mining) | 3 pickaxe strikes on rock |
| 2 | `insect_bed` | generated | 2 | insect_bed.gd: quiet summer insect chirring over meadows and water on warm days (loop) | a 15 to 30 s seamless loop of many small insects, nothing rhythmic |
| 2 | `interior_rain_roof` | generated | 1 | interior_sounds.gd: rain on a roof heard from inside (loop) | Rain on a wooden or thatched roof from inside, seamless |
| 2 | `inv_close` | generated | 3 | item_sounds.gd: the inventory closed | 3 leather pouch flaps closing |
| 2 | `inv_open` | generated | 3 | item_sounds.gd: the inventory opened (I) | 3 leather pouch or satchel flaps opening |
| 2 | `item_drop` | generated | 3 | item_sounds.gd: stacks in the inventory shrank (dropped) | 3 dull thuds of setting an item down |
| 2 | `item_pickup` | generated | 3 | item_sounds.gd: stacks in the inventory grew (picked up, harvested) | 3 soft scoop and rustle cues of picking something up |
| 2 | `owl_hoot` | generated | 3 | ambient_life.gd: forest at night | 2 to 3 owl hoots (tawny or barred), 2 to 3 s |
| 2 | `pick_pluck` | generated | 3 | harvest_sounds.gd: a berry, fruit or nut picked | 3 recordings of plucking a berry or nut from its stalk, 0.3 s |
| 2 | `pick_pull` | generated | 3 | harvest_sounds.gd: a root or bulb pulled from the soil | 3 recordings of pulling a root or carrot out of soil, 0.6 s |
| 2 | `pick_snap` | generated | 3 | harvest_sounds.gd: a stalk, reed, fibre plant or twig snapped | 3 recordings of snapping a green stalk or reed, 0.3 s |
| 2 | `pick_snip` | generated | 3 | harvest_sounds.gd: a herb, leaf or flower nipped off | 3 recordings of snipping a leaf or herb stem, 0.3 s |
| 2 | `pick_twist` | generated | 3 | harvest_sounds.gd: a mushroom twisted off | 3 recordings of twisting a mushroom off its base, 0.4 s |
| 2 | `place_chest` | generated | 2 | placed_sounds.gd: a chest set down | 2 to 3 recordings of a heavy wooden box put on the ground |
| 2 | `place_leanto` | generated | 2 | placed_sounds.gd: a lean-to set up (hook place("leanto"); also heard from a world row of item id lean_to) | 2 to 3 recordings of planting poles and laying brush, 1 s |
| 2 | `rain_leaves` | generated | 1 | weather_sounds.gd: rain pattering on leaves under trees | Rain on forest canopy loop, seamless |
| 2 | `rain_roof` | generated | 1 | weather_sounds.gd: rain pattering on a roof overhead (a lean-to), boards or thatch | Rain on a wooden roof from underneath, loop, seamless |
| 2 | `spear_hit_flesh` | generated | 3 | spear_sounds.gd: a spear hitting flesh | 3 wet heavy thumps of a spear hitting an animal or body |
| 2 | `spear_hit_wood` | generated | 3 | spear_sounds.gd: a spear sticking into wood (the shaft quivers) | 3 spear thunks into a tree or board with shaft vibration |
| 2 | `swim_splash_big` | generated | 3 | swim_sounds.gd: a jump or fall into water (4 m/s and up) | 3 big splashes of a person falling in, 1 to 2 s |
| 2 | `swim_splash_small` | generated | 3 | swim_sounds.gd: the body enters water slowly (under 4 m/s) | 3 small body-into-water splashes, 0.5 to 1 s |
| 2 | `thunder_far` | generated | 3 | weather_sounds.gd: a far strike (over 1800 m): a low grumble | 2 to 3 distant low rumbles, 8 to 12 s |
| 2 | `thunder_near` | generated | 3 | weather_sounds.gd: a close strike (under 500 m): sharp crack and thud | 2 to 3 close, sharp thunder cracks, 2 to 4 s |
| 2 | `tool_break` | generated | 2 | placed_sounds.gd: a tool breaks with the last of its wear | 2 to 3 sharp wood or stone cracks with splinters |
| 2 | `town_fire` | generated | 1 | town_sounds.gd: a hearth or forge fire (loop) | A seamless crackling fire loop |
| 2 | `town_hammering` | generated | 1 | town_sounds.gd: a smith or builder working nearby (loop) | A seamless loop of hammer on anvil, 8 to 15 s |
| 2 | `tree_creak` | generated | 3 | tree_sounds.gd: a felled tree groans as it starts to go (when its trunk appears) | 3 tree trunk creaks and groans before falling, 1 to 2 s |
| 2 | `treewind_bare` | generated | 1 | tree_wind.gd: wind in bare winter branches, creaks (loop) | A seamless loop of wind in bare branches with soft creaks |
| 2 | `treewind_dry` | generated | 1 | tree_wind.gd: wind in dry autumn leaves (loop) | A seamless loop of wind in dry crackling leaves |
| 2 | `treewind_leaves` | generated | 1 | tree_wind.gd: wind in summer and spring leaves (loop) | A seamless loop of wind in green broadleaf trees, 20 s or more |
| 2 | `treewind_pine` | generated | 1 | tree_wind.gd: wind through conifers, a soft needle hiss (loop, level follows wind and conifer count) | A seamless loop of wind in pines, 20 s or more, steady, no gusts |
| 2 | `water_fall` | generated | 1 | water_sounds.gd: a waterfall roar | A waterfall loop, seamless |
| 2 | `water_fall_base` | generated | 1 | water_sounds.gd: the close spray and churn where a fall lands (within 60 m) | A close waterfall base loop: hiss and splash, steady, seamless, no bubbles |
| 2 | `water_pond` | generated | 1 | water_sounds.gd: gentle lapping at a pond shore | A calm lake shore lapping loop, seamless |
| 2 | `wind_storm` | generated | 1 | weather_sounds.gd: gale howl in storms and blizzards | A howling gale loop, seamless |
| 2 | `wolf_howl` | generated | 2 | creature_sounds.gd: a wolf's howl (idle), far away at night | 2 to 3 long wolf howls, 3 to 6 s, single wolf and a pack |
| 3 | `bear_growl` | generated | 2 | creature_sounds.gd: a bear's growl (idle, alert) | 2 to 3 low bear growls, 1 to 2 s |
| 3 | `bed_forest` | empty | 0 | ambient_life.gd (optional bed): a quiet forest background that fades in with forest cover | A quiet forest background loop, 30 s or more, no clear single calls |
| 3 | `bed_highland` | empty | 0 | ambient_life.gd (optional bed): highland wind and space | A thin high-altitude background loop |
| 3 | `bed_meadow` | empty | 0 | ambient_life.gd (optional bed): a meadow background | A meadow background loop (insects, distant birds), seamless |
| 3 | `bed_water` | empty | 0 | ambient_life.gd (optional bed): a water-edge background | A quiet marsh or lake edge background loop |
| 3 | `bird_feebee` | generated | 3 | ambient_life.gd: forest bird, by day | 2 chickadee-style two-note calls |
| 3 | `chest_close` | generated | 2 | interior_sounds.gd: a chest closes (object) | 2 to 3 chest lid thuds |
| 3 | `chest_open` | generated | 2 | interior_sounds.gd: a chest opens (object) | 2 to 3 wooden chest lid opens with a creak |
| 3 | `chop_thock` | generated | 3 | workshop_sounds.gd chop(at, false): an axe stroke on the block that does not split | 3 recordings of an axe biting wood, 0.3 s |
| 3 | `craft_bind` | generated | 2 | item_sounds.gd: crafting work sound (binding with cord: spear, torch), plays for the length of the craft | 2 to 3 recordings of tying cord around a pole, 4 s |
| 3 | `craft_carve` | generated | 2 | item_sounds.gd: crafting work sound (scraping a point on wood: wooden spear), plays for the length of the craft | 2 to 3 recordings of scraping wood with a stone, 4 s |
| 3 | `craft_knap` | generated | 2 | item_sounds.gd: crafting work sound (chipping stone: stone axe, knife), plays for the length of the craft | 2 to 3 recordings of knapping flint, stone on stone, 4 s |
| 3 | `craft_pound` | generated | 2 | item_sounds.gd: crafting work sound (pounding leaves: poultices), plays for the length of the craft | 2 to 3 recordings of pounding leaves with a stone, 4 s |
| 3 | `craft_stack` | generated | 2 | item_sounds.gd: crafting work sound (laying sticks and stones: campfire), plays for the length of the craft | 2 to 3 recordings of stacking sticks and stones, 4 s |
| 3 | `craft_twine` | generated | 2 | item_sounds.gd: crafting work sound (twisting fibre into cord), plays for the length of the craft | 2 to 3 recordings of twisting plant fibre or rope, 4 s |
| 3 | `craft_wrap` | generated | 2 | item_sounds.gd: crafting work sound (wrapping a bandage), plays for the length of the craft | 2 to 3 recordings of wrapping a cloth or leaf bandage, 4 s |
| 3 | `deer_grunt` | generated | 2 | creature_sounds.gd: a deer's low grunt (idle) | 2 to 3 low deer grunts or contact calls, 0.3 to 0.8 s |
| 3 | `deer_snort` | generated | 2 | creature_sounds.gd: a deer's alarm snort (alert, threat) | 2 to 3 deer alarm snorts, 0.3 s |
| 3 | `dig_clay` | generated | 3 | dig_sounds.gd: digging clay, mud and peat | 3 wet sticky digs |
| 3 | `dig_gravel` | generated | 3 | dig_sounds.gd: digging gravel | 3 gravel shovelling sounds |
| 3 | `dig_ore` | generated | 3 | dig_sounds.gd: digging out ore (metal clink on rock) | 3 pick on ore sounds |
| 3 | `dig_sand` | generated | 3 | dig_sounds.gd: digging sand and snow | 3 sand shovelling sounds |
| 3 | `dig_water` | generated | 3 | dig_sounds.gd: water pouring into a new hole | 3 water splashing into a pit |
| 3 | `door_close` | generated | 2 | interior_sounds.gd: a door closes (object) | 2 to 3 wooden door closes with a thud and latch |
| 3 | `door_open` | generated | 2 | interior_sounds.gd: a door opens (object) | 2 to 3 wooden door opens with latch and hinge creak |
| 3 | `drink_gulp` | generated | 2 | item_sounds.gd eat("drink"): two swallows | 2 recordings of drinking and swallowing, 1 s |
| 3 | `eat_crunch` | generated | 3 | item_sounds.gd eat(): a crisp bite and chews (roast, nuts, roots) | 2 to 3 recordings of biting and chewing something crisp, 1 s |
| 3 | `eat_soft` | generated | 3 | item_sounds.gd eat(): soft chewing (berries, greens) | 2 to 3 recordings of chewing something soft, 1 s |
| 3 | `flame_lantern` | generated | 1 | flame_sounds.gd: a lantern in the hand (quiet loop) | a lantern flame behind glass, 10 s loop |
| 3 | `fox_bark` | generated | 2 | creature_sounds.gd: a fox's bark (idle, alert), a night sound | 2 to 3 red fox barks, 1 to 3 per clip |
| 3 | `fox_scream` | generated | 2 | creature_sounds.gd: a vixen's scream (threat), a night sound | 2 to 3 red fox screams, about 1 s |
| 3 | `gear_cloth` | generated | 3 | gear_sounds.gd: clothes rustling on a step | 3 soft cloth rustles, 0.2 s, from walking in a tunic or cloak |
| 3 | `gear_iron` | generated | 3 | gear_sounds.gd: iron-shod boots clanging on a step | 3 iron boot clangs, 0.4 s |
| 3 | `gear_leather` | generated | 3 | gear_sounds.gd: leather armour or straps creaking on a step | 3 leather creaks, 0.3 s |
| 3 | `hawk_screech` | generated | 3 | ambient_life.gd: highland, by day | 2 to 3 hawk screeches |
| 3 | `heal_bandage` | generated | 2 | item_sounds.gd eat(): a bandage applied | 2 recordings of wrapping a cloth bandage, 1 s |
| 3 | `heal_poultice` | generated | 2 | item_sounds.gd eat(): a poultice applied (Items eat_event, confirmed by the server) | 2 recordings of pressing a wet leaf pack onto skin, 0.8 s |
| 3 | `heartbeat` | generated | 3 | breath_sounds.gd: the player's own heartbeat when exerted (lub-dub) | 3 heartbeat lub-dubs, 0.4 s, no room tone |
| 3 | `hit_hammer_stone` | generated | 3 | hit_sounds.gd: a hammer blow on stone (chiselling, smithing) | 3 hammer clanks on stone |
| 3 | `hit_pick_soil` | generated | 3 | hit_sounds.gd: a pickaxe blow on soil | 3 pick strikes into hard earth |
| 3 | `hit_spade_soil` | generated | 3 | hit_sounds.gd: a spade strike into soil | 3 spade thuds into earth |
| 3 | `hit_swing` | generated | 3 | hit_sounds.gd: a tool swung through the air, hit or miss | 3 tool whooshes, 0.5 s |
| 3 | `item_reject` | generated | 3 | item_sounds.gd: an action was refused (too far, no tool, pack full), a soft double knock | a soft refusal knock, 0.2 s |
| 3 | `land_hard` | generated | 3 | landing_sounds.gd: landing from 5 m and more, heavy impact, gear rattle and a grunt | 3 hard landings, 0.9 s |
| 3 | `land_thud` | generated | 3 | landing_sounds.gd: landing from 2.5 to 5 m, body weight and a breath knocked out | 3 landing thuds, 0.5 s |
| 3 | `pickup_placed` | generated | 2 | placed_sounds.gd: a placed thing picked up again | 2 recordings of dragging and lifting a wooden thing |
| 3 | `place_thump` | generated | 2 | placed_sounds.gd: any other thing set on the ground | 2 short dull thumps on soil |
| 3 | `plank_drop` | generated | 2 | workshop_sounds.gd plank_drop(at): a sawn plank landing on its stack (hook until the saw mill exists) | 2 recordings of a plank dropped on a plank stack, 0.5 s |
| 3 | `plant_rustle_leaves` | generated | 2 | harvest_sounds.gd: leaves and shrub shaking when picked | 2 recordings of shaking a leafy plant, 1 s |
| 3 | `plant_rustle_reeds` | generated | 2 | harvest_sounds.gd: reeds and grass swishing when picked | 2 recordings of shaking reeds or tall grass, 1 s |
| 3 | `rain_drip` | generated | 4 | weather_sounds.gd: a drop falling from a leaf near you, under trees in rain | 3 to 4 single drops falling from leaves onto leaves or ground, 0.3 s |
| 3 | `rain_litter` | generated | 1 | weather_sounds.gd: rain on forest leaf litter in the open | Rain on dry leaf litter loop, seamless |
| 3 | `rain_mud` | generated | 1 | weather_sounds.gd: rain on mud and soaked soil | Rain on mud loop, seamless |
| 3 | `rain_snow` | generated | 1 | weather_sounds.gd: rain falling on lying snow (very quiet) | Rain on snow loop, soft, seamless |
| 3 | `rain_splash_dirt` | generated | 3 | rain_splashes.gd: a single rain drop landing on bare soil near the player (open sky only) | A single raindrop landing on bare soil, close, 3 or 4 different drops |
| 3 | `rain_splash_grass` | generated | 3 | rain_splashes.gd: a single rain drop landing on grass near the player (open sky only) | A single raindrop landing on grass, close, 3 or 4 different drops |
| 3 | `rain_splash_gravel` | generated | 3 | rain_splashes.gd: a single rain drop landing on gravel near the player (open sky only) | A single raindrop landing on gravel, close, 3 or 4 different drops |
| 3 | `rain_splash_litter` | generated | 3 | rain_splashes.gd: a single rain drop landing on fallen leaves near the player (open sky only) | A single raindrop landing on fallen leaves, close, 3 or 4 different drops |
| 3 | `rain_splash_mud` | generated | 3 | rain_splashes.gd: a single rain drop landing on mud near the player (open sky only) | A single raindrop landing on mud, close, 3 or 4 different drops |
| 3 | `rain_splash_sand` | generated | 3 | rain_splashes.gd: a single rain drop landing on sand near the player (open sky only) | A single raindrop landing on sand, close, 3 or 4 different drops |
| 3 | `rain_splash_stone` | generated | 3 | rain_splashes.gd: a single rain drop landing on stone near the player (open sky only) | A single raindrop landing on stone, close, 3 or 4 different drops |
| 3 | `rain_splash_water` | generated | 3 | rain_splashes.gd: a single rain drop landing on water near the player (open sky only) | A single raindrop landing on water, close, 3 or 4 different drops |
| 3 | `rain_stone` | generated | 1 | weather_sounds.gd: rain on stone, rock, slab, plank or path ground under the player (open sky) | Rain on bare rock or flagstones loop, seamless |
| 3 | `rain_water` | generated | 1 | weather_sounds.gd: rain falling on ponds and rivers near the player | Rain on a lake surface loop, seamless |
| 3 | `saw_mill` | generated | 1 | workshop_sounds.gd set_saws: a running saw mill (hook until it exists, loop) | A seamless loop of a saw mill running, blade rasp and frame, 10 s or more |
| 3 | `spear_flight` | generated | 3 | spear_sounds.gd: a thrown spear whistling through the air (moves along the path) | 3 thin air whistles of a spear in flight, 1 to 2 s |
| 3 | `spear_hit_soil` | generated | 3 | spear_sounds.gd: a spear sticking into earth | 3 spear thuds into dirt |
| 3 | `spear_hit_stone` | generated | 3 | spear_sounds.gd: a spear striking stone | 3 spear tips hitting rock, clack and scrape |
| 3 | `spear_jab` | generated | 3 | spear_sounds.gd: a spear thrust through the air | 3 spear thrust whooshes, 0.3 s |
| 3 | `spear_throw` | generated | 3 | spear_sounds.gd: the heave and release of a thrown spear | 3 spear throw whooshes with effort, 0.7 s |
| 3 | `stance_crouch` | generated | 3 | stance_sounds.gd: cloth rustle crouching down | 3 soft cloth rustles of crouching down, 0.45 s |
| 3 | `stance_lie` | generated | 3 | stance_sounds.gd: lying down on the ground | 3 lying-down slides and thuds, 1 s |
| 3 | `stance_rise` | generated | 3 | stance_sounds.gd: getting up | 3 getting-up rustles, 0.7 s |
| 3 | `stance_sit` | generated | 3 | stance_sounds.gd: sitting down, rustle and a soft weight | 3 sitting-down rustles with a soft thud, 0.7 s |
| 3 | `stomach_growl` | generated | 2 | item_sounds.gd watch_vitals(): a hungry stomach, every 50 to 110 s at 15 percent hunger or less (twice as often when starving) | 2 recordings of a stomach growling, 1.5 s |
| 3 | `stump_chips` | generated | 3 | tree_sounds.gd: wood chips and a last crack as the stump is left | 3 wood chip sprays and cracks, 0.5 s |
| 3 | `swim_dive` | generated | 3 | swim_sounds.gd: the head goes under | 3 bubbling gulps of going under, 1 s |
| 3 | `swim_stroke` | generated | 3 | swim_sounds.gd: an arm stroke while swimming, one every 0.6 to 1.4 s | 3 breaststroke or crawl arm pulls through water, 0.5 s |
| 3 | `swim_surface` | generated | 3 | swim_sounds.gd: the head comes out of the water | 3 breaths and running water on surfacing, 1 s |
| 3 | `swim_under` | generated | 1 | swim_sounds.gd: the hum of being underwater (loop while the eyes are under) | A muffled underwater ambience loop, seamless |
| 3 | `tool_repair` | generated | 2 | placed_sounds.gd: a tool mended (about 2 s) | 2 recordings of scraping, tapping and binding a tool, 2 s |
| 3 | `tool_warn` | generated | 2 | placed_sounds.gd: a worn tool complaining before it breaks (under 20 percent condition) | 3 small dry cracks and creaks of a tool at its limit, 0.4 s |
| 3 | `town_bell` | generated | 3 | town_sounds.gd: a tower bell tolling the hour or on call (ring_bell) | 2 to 3 bell strikes with a long ring, 4 to 6 s each |
| 3 | `town_crowd` | generated | 1 | town_sounds.gd: a busy square murmur (loop) | A seamless crowd murmur loop, no clear words |
| 3 | `tree_leaves` | generated | 3 | tree_sounds.gd: the crown rushing down through the air | 3 branches and leaves rushing as a tree falls, about 1 s |
| 3 | `wing_grain` | recorded | 3 | make_wings.py: single flaps cut from Dave's recording; the take-offs are built from them (not played directly) | have: Dave's recording |
| 3 | `wolf_growl` | generated | 2 | creature_sounds.gd: a wolf's growl (alert, threat) | 2 to 3 wolf growls and snarls, 1 to 2 s |
| 3 | `woodpecker` | generated | 3 | ambient_life.gd: forest, by day | 2 to 3 woodpecker drumming runs, about 1 s |
| 4 | `cloth_walk` | generated | 4 | step_fx.gd: soft clothes rustle under every step | 4 soft cloth swishes, 0.25 s |
| 4 | `craft_start` | generated | 3 | item_sounds.gd: a craft begins | 3 soft two-part clicks of setting materials down, 0.15 s |
| 4 | `door_knock` | generated | 2 | interior_sounds.gd: knocking on a door (object) | 2 to 3 triple knocks on wood |
| 4 | `frog_croak` | recorded | 6 | ambient_life.gd: ponds and rivers, spring to autumn, more at night and in rain | have: Dave's frogs (mostly small trillers); a deep bullfrog croak is still missing |
| 4 | `furniture_drag` | generated | 2 | interior_sounds.gd: furniture dragged on a floor (object) | 2 to 3 wooden furniture scrapes, 1 s |
| 4 | `gear_hobnail` | generated | 3 | gear_sounds.gd: hobnailed boots clicking on a step (loud on stone, dull on soft ground) | 3 hobnail boot clicks, 0.1 s |
| 4 | `hit_axe_soil` | generated | 3 | hit_sounds.gd: an axe blow on soil | 3 axe thuds into earth |
| 4 | `hit_axe_stone` | generated | 3 | hit_sounds.gd: an axe blow on stone | 3 axe strikes on rock |
| 4 | `hit_hammer_soil` | generated | 3 | hit_sounds.gd: a hammer blow on soil (driving stakes) | 3 mallet thumps into earth |
| 4 | `hit_pick_wood` | generated | 3 | hit_sounds.gd: a pickaxe blow on wood | 3 pick strikes into wood |
| 4 | `hit_spade_stone` | generated | 3 | hit_sounds.gd: a spade scraping on stone | 3 spade scrapes on stone |
| 4 | `hit_spade_wood` | generated | 3 | hit_sounds.gd: a spade strike on wood | 3 spade knocks and scrapes on wood |
| 4 | `hotbar_tick` | generated | 3 | item_sounds.gd: a hotbar slot chosen (number keys) | 3 short quiet dry wooden ticks, 0.07 s |
| 4 | `interior_creak` | generated | 2 | interior_sounds.gd: timbers creaking now and then inside | 2 to 3 wood creaks, 0.5 to 1 s |
| 4 | `interior_room` | generated | 1 | interior_sounds.gd: the room tone while inside a building (loop) | A quiet indoor room tone loop, seamless |
| 4 | `rabbit_squeak` | generated | 2 | creature_sounds.gd: a rabbit's distress squeal (threat) | 2 to 3 short rabbit squeals |
| 4 | `rabbit_thump` | generated | 2 | creature_sounds.gd: a rabbit's warning foot thump (idle, alert) | 2 to 3 rabbit hind-foot thumps, a double knock |
| 4 | `stance_settle` | generated | 3 | stance_sounds.gd: a tiny shift while sitting or lying | 3 tiny cloth shifts, 0.3 s |
| 4 | `ui_click` | generated | 2 | ui_sounds.gd: every menu button pressed | 2 to 3 very soft, short interface ticks |
| 4 | `ui_off` | generated | 2 | ui_sounds.gd: a toggle switched off | 2 short falling two-note cues, quiet |
| 4 | `ui_on` | generated | 2 | ui_sounds.gd: a toggle switched on (inspection mode) | 2 short rising two-note cues, quiet |
| 4 | `ui_quality` | generated | 2 | ui_sounds.gd: the quality tier changed (F2 or the menu) | 2 soft settled chimes, 0.5 s |
| 4 | `wet_squelch` | generated | 4 | step_fx.gd: wet shoes squelch under steps for 20 s after wading | 4 short wet squelches, 0.22 s |
| 4 | `wing_large` | generated | 4 | ambient_life.gd: flush(at, delay, 'large'): a crow or hawk takes off, 3 to 4 heavy flaps a second | made from Dave's wing flap recording (make_wings.py) |
| 4 | `wing_medium` | generated | 4 | ambient_life.gd: flush(at, delay, 'medium'): a pigeon or thrush bursts out, 5 to 7 flaps a second | made from Dave's wing flap recording (make_wings.py); a real pigeon take-off wins |
| 4 | `wing_small` | generated | 4 | ambient_life.gd: flush(at, delay, 'small'): a finch bursts out of cover, 9 to 12 quick flaps | made from Dave's wing flap recording (make_wings.py); a real finch or sparrow take-off wins |
| 5 | `crow_alarm` | recorded | 3 | ambient_life.gd: alarm(at): a crow scolds when the player runs through crow country, and the danger warning hook | have: Dave's angry crow |
| 5 | `crow_caw` | recorded | 7 | ambient_life.gd: forest and highland, by day | have: Dave's crow calls |
| 5 | `fish_splash` | recorded | 3 | ambient_life.gd: a fish jumps at the water edge, rare | have: Dave's fish jumping clip, played whole |
| 5 | `tree_frog_peep` | recorded | 6 | ambient_life.gd: water edge and forest, spring to autumn | have: Dave's frogs (short peeps) |

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
| `step_plank` | empty | 0 | built wooden floor (sound.set_floor, generated placeholder in floors/) |
| `step_slab` | empty | 0 | built stone slab floor |
| `step_carpet` | empty | 0 | built carpeted floor |
| `step_thatch` | empty | 0 | built thatch floor |
| `step_path` | empty | 0 | gravel path laid by builders |
