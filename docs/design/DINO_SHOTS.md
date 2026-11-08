# Pictures for Dino in MikeW's PC slot (8 Nov 2026)

Voices cannot be photographed; these are the looks that can. Every picture is taken with the motion tool
(`tools/creature_motion.gd`), not the in-world shot runner, for a reason that matters: the runner's `--shot-animals` places static
models that are not in the animal view's live list, so none of the life layer's per-frame looks (eye shine v2, steam, wet, tracks,
hit reactions) run on them. The motion tool drives the real animal view with fake rows, weather and light, frame by frame.

From `C:/GodotProjects/DynastyALWL_gate` in Git Bash, after the branch checkout and model import of the run sheet (step 0):
```bash
GE=/c/GodotInstaller/godot.windows.editor.x86_64.exe
O=/e/Software/godotDev/dino_shots
M="timeout 300 $GE --path . --script res://tools/creature_motion.gd --"
```

## The camera, exactly
The tool's world is a flat 80 m ground plane at y 0. The first animal stands at x -2.5, z 0 (a second and third at x 0 and 2.5),
facing +Z. The camera is at **(cam, 1.8, 0)** looking at **(0, 0.6, 0)**: **yaw 90** (facing -X, the shot runner's convention),
**pitch -atan(1.2 / cam)** (cam 4 m: -16.7; cam 8: -8.5; cam 15: -4.6), **fov 50** (the game's own is 75). With `--speed` the
camera and focus move along +Z with the animals. Pictures are 480 by 480 px, one strip per kind in `$O/<out>/motion_<kind>_<state>.png`.

## The pictures
| Picture | Hour | Weather or light | Animals | Command | Look for |
|---|---|---|---|---|---|
| Eye shine by torch | 23:00 | night sky, a torch 0.3 m under the camera | deer, wolf, cat, bear, horse | `$M --kinds=deer,wolf,cat,bear,horse --state=3 --torch --shine --hour=23 --cam=15 --frames=2 --out=$O/eyes_torch` | two points of the species' colour per animal at 15 m (camera (15, 1.8, 0), pitch -4.6) |
| Eye shine by moon | 23:00 | full moon behind the camera, no torch | the same | `$M --kinds=deer,wolf,cat,bear,horse --state=3 --shine --moon --hour=23 --cam=4 --frames=2 --out=$O/eyes_moon` | faint points close in (camera (4, 1.8, 0), pitch -16.7) |
| Steam breath, cold morning | 07:00 | -12 C (`--wx=cold`) | deer herd of 6 | `$M --kinds=deer --state=0 --count=6 --hour=7 --wx=cold --cam=6 --frames=4 --every=1 --out=$O/steam` | white puffs at the muzzles, the herd closer, heads low (camera (6, 1.8, 0), pitch -11.3) |
| Wet look in rain | 12:00 | swimming in 0.6 m of water | beaver, moose | `$M --kinds=beaver,moose --state=0 --water=0.6 --speed=1 --cam=6 --out=$O/wet` | darker, glossier coats (only on `claude/mikew-wet-look`: check that branch out first for this one) |
| Tracks in mud, walking | 12:00 | mud | deer, wolf | `$M --kinds=deer,wolf --state=0 --speed=1.5 --sign=mud --cam=6 --frames=4 --every=1 --out=$O/tracks_mud` | prints one step apart, left and right |
| Tracks in snow, running | 12:00 | lying snow | deer, wolf, rabbit | `$M --kinds=deer,wolf,rabbit --state=2 --speed=8 --sign=snow --season=winter --cam=8 --frames=4 --every=0.5 --out=$O/tracks_snow` | groups of four with long gaps; the rabbit's Y (camera (8, 1.8, 0), pitch -8.5) |
| Hit in the hip | 12:00 | clear | deer, walking | `$M --kinds=deer --state=0 --speed=1.5 --hit=hip --cam=6 --frames=8 --every=0.25 --out=$O/hit_hip` | a jolt at 2 s, then the hind end low and swinging |
| Hit in the head | 12:00 | clear | deer, standing | `$M --kinds=deer --state=0 --hit=head --cam=4 --frames=6 --every=0.1 --out=$O/hit_head` | the head and front tossed up at 2 s |
| The death fall | 12:00 | clear | deer | `$M --kinds=deer --state=0 --hit=chest --kill --cam=6 --frames=6 --every=0.3 --out=$O/fall` | down onto its side from 3 s, lying still |
| Sheltering in cover | 12:00 | (state 20 sent) | deer, horse | `$M --kinds=deer,horse --state=20 --cover --cam=6 --frames=4 --every=0.5 --out=$O/cover` | heads low, ears back, barely moving |
| Posed wings, flapping (stand-in) | 12:00 | clear | crow, its wings posed from its bones | `$M --kinds=crow --state=15 --birdrig --posed --cam=3 --frames=8 --every=0.06 --out=$O/wings_flap` | both wings up and down, mirrored, over 8 frames at 0.06 s (about one beat at 4 Hz); camera (3, 1.8, 0), pitch -21.8 |
| Posed wings, gliding (stand-in) | 12:00 | clear | crow | `$M --kinds=crow --state=17 --birdrig --posed --cam=3 --frames=2 --out=$O/wings_glide` | wings held out level, hands swept back; camera (3, 1.8, 0), pitch -21.8 |
| Posed wings, perched (stand-in) | 12:00 | clear | crow | `$M --kinds=crow --state=0 --birdrig --posed --cam=3 --frames=2 --out=$O/wings_perch` | wings folded to the body |
| Posed wings, the Meshy birds | 12:00 | clear | golden_eagle, raven, owl, bat (once Dave's models and rows are in) | `$M --kinds=raven --state=15 --birdrig --cam=4 --frames=8 --every=0.07 --out=$O/wings_raven` (the same for each) | the same three checks per bird; a wrong axis or sign shows at once (row `wing_axis`, `wing_swing_deg`); camera (4, 1.8, 0), pitch -16.7 |
| Posed swim, stand-in | 12:00 | 1 m of water over the tool's ground plane (the coast stand-in) | alligator, posed from its spine | `$M --kinds=alligator --state=1 --speed=1 --water=1 --swimrig --posed --cam=6 --frames=8 --every=0.15 --out=$O/swim_standin` | the wave growing from shoulders to tail tip; camera (6, 1.8, 0), pitch -11.3 |
| Posed whale, cruising | 12:00 | 4 m of water | whale (once Dave's model and row are in) | `$M --kinds=whale --state=1 --speed=2 --water=4 --swimrig --cam=30 --frames=8 --every=0.5 --out=$O/swim_whale` | the flukes rising and falling once every 4 s, the chest nearly still; camera (30, 1.8, 0), pitch -2.3 |
| Posed dolphin, hurrying | 12:00 | 3 m of water | dolphin | `$M --kinds=dolphin --state=2 --speed=6 --water=3 --swimrig --cam=12 --frames=8 --every=0.08 --out=$O/swim_dolphin` | about 2.5 beats a second, the wave growing to the flukes, the flippers stroking; camera (12, 1.8, 0), pitch -5.7 |
| Dolphin porpoising | 12:00 | 3 m of water | dolphin | `$M --kinds=dolphin --state=2 --speed=8 --water=3 --swimrig --cam=15 --frames=8 --every=0.15 --out=$O/swim_porpoise` | the body leaving the water in low arcs, nose up rising, nose down falling; camera (15, 1.8, 0), pitch -4.6 |
| Rump to the wind in rain | 12:00 | wind 0.5 toward +X, rain 0.6 (`--wx=windrain`) | deer, horse | `$M --kinds=deer,horse --state=0 --wx=windrain --windlooks --cam=6 --frames=4 --every=1 --out=$O/wind_rump` | rumps turning toward +X, that is toward the camera, heads low; camera (6, 1.8, 0), yaw 90, pitch -11.3 |
| Deer grazing into a breeze | 12:00 | wind 0.3 toward +X (`--wx=breeze`) | deer herd of 3 | `$M --kinds=deer --state=0 --count=3 --wx=breeze --windlooks --cam=8 --frames=4 --every=1 --out=$O/wind_graze` | noses turning toward -X, away from the camera (upwind), up to 45 degrees; camera (8, 1.8, 0), pitch -8.5 |
| Windward fur | 12:00 | wind 0.9 toward +X | fox, bear | `$M --kinds=fox,bear --state=0 --wind=0.9 --wx=gale --ruffle --windlooks --cam=3 --frames=6 --every=0.15 --out=$O/wind_fur` | the fur on the -X side (facing the wind) moving more than the +X side; camera (3, 1.8, 0), pitch -21.8 |
| Eyes at dusk in fog | 19:30 | fog, 120 m visibility (`--fog=120`: scene fog density 0.025), a torch at the camera | deer, wolf (4 animals) | `$M --kinds=deer,wolf --state=3 --count=4 --torch --shine --hour=19.5 --fog=120 --cam=15 --frames=3 --every=0.5 --out=$O/fog_eyes` | eye shine already at dusk, the far animals paler; camera (15, 1.8, 0), yaw 90, pitch -4.6 |
| Herd in thick fog | 08:00 | fog, 60 m visibility | deer herd of 6 | `$M --kinds=deer --state=0 --count=6 --hour=8 --fog=60 --cam=10 --frames=2 --out=$O/fog_herd` | the herd closer than in clear air (compare m4), fading at the back; camera (10, 1.8, 0), pitch -6.8 |
| Breath into the mist | 07:00 | mist 0.8 (`--fog=400`), -12 C (`--wx=cold`) | deer | `$M --kinds=deer --state=0 --hour=7 --fog=400 --wx=cold --cam=5 --frames=4 --every=1 --out=$O/fog_breath` | fainter puffs that linger; camera (5, 1.8, 0), pitch -13.5 |
| Alert, facing into the wind | 12:00 | wind 0.3 toward +X (`--wx=breeze`) | deer, horse | `$M --kinds=deer,horse --state=3 --wx=breeze --windlooks --cam=6 --frames=4 --every=1 --out=$O/wind_alert` | heads and bodies turning toward -X, away from the camera (upwind); camera (6, 1.8, 0), yaw 90, pitch -11.3 |
| Feathers in the wind | 12:00 | wind 0.9 toward +X | crow, goose | `$M --kinds=crow,goose --state=0 --wind=0.9 --wx=gale --ruffle --windlooks --cam=2.5 --frames=6 --every=0.15 --out=$O/wind_feathers` | feathers lifting on the -X side (the side the wind meets); camera (2.5, 1.8, 0), pitch -25.6 |
| Take-off into the wind | 12:00 | wind 0.5 toward +X (`--wx=windrain`) | goose | `$M --kinds=goose --state=15 --wx=windrain --windlooks --cam=8 --frames=6 --every=0.15 --out=$O/wind_takeoff` | the goose turning toward -X (into the wind) while its take-off clip plays; camera (8, 1.8, 0), pitch -8.5 |
| Cave air: no steam deep in | 07:00 | outside -12 C (`--wx=cold`), under rock 5.5 C (`--cave=5.5`) | deer (3) | `$M --kinds=deer --state=0 --count=3 --hour=7 --wx=cold --cave=5.5 --cam=6 --frames=4 --every=1 --out=$O/cave_nosteam` | no breath puffs (compare the cold-morning steam shot); camera (6, 1.8, 0), yaw 90, pitch -11.3 |
| Cave mouth, live (after the strips) | 07:00 on a cold morning | the world's own | whatever is at the mouth | `--shots="cave_mouth:56520,1.7,72360,0,-10,7" --life=cave_air,weather_looks` on a normal client run (shot runner: x 56520, 1.7 m above the ground, z 72360, yaw 0 (facing north), pitch -10, hour 7) | an animal outside the mouth steams, one inside does not; the shot runner's own `--shot-animals` are static and show none of this, so it needs a live animal there |
| Drinking at a bank | 12:00 | water from 0.6 m ahead (`--bank`), mud | deer | `$M --kinds=deer --state=0 --bank --drink --sign=mud --cam=5 --frames=8 --every=1.5 --out=$O/drink_bank` | head down, lifted in some frames; a trampled patch at the feet; camera (5, 1.8, 0), yaw 90, pitch -13.5 |
| A bird bathing | 12:00 | 5 cm of water (`--water=0.05 --wlife`) | crow | `$M --kinds=crow --state=0 --water=0.05 --wlife --drink --cam=3 --frames=8 --every=0.5 --out=$O/drink_bathe` | wing bursts with splashes; camera (3, 1.8, 0), pitch -21.8 |
| Spring at the cave 8002 mouth, live | 06:00 (dawn) | the world's own | whatever comes to drink | `--shots="spring_8002:56520,1.7,72360,180,-12,6" --life=water_life,drink_looks,animal_sign` (x 56520, 1.7 m above the ground near 533 m, z 72360, yaw 180 facing south out of the mouth, pitch -12, hour 6) | an animal at the spring's water: sips and head lifts, a churned patch; needs a live animal there (Steve's dawn walk to water, request 1) |
| A pool, live | 19:00 (dusk) | the world's own | whatever comes to drink | `--shots="pool:63584,1.7,80024,0,-8,19" --life=water_life,drink_looks,animal_sign` (the basin pond at x 63584, z 80024 from the bake log, radius 36 m; yaw 0 facing north, pitch -8, hour 19) | animals at the edge drinking; birds bathing in the margin |
| On the ice | 12:00, winter | frozen water at the surface (`--water=0.01 --wlife --ice`) | deer, wolf, walking | `$M --kinds=deer,wolf --state=0 --speed=1.2 --water=0.01 --wlife --ice --season=winter --cam=6 --frames=10 --every=0.25 --out=$O/ice_walk` | the deer slipping sideways now and then, the wolf steady; camera (6, 1.8, 0), yaw 90, pitch -11.3 |
| Snow on a still back | 02:00, winter | snow falling (`--wx=snowbed`) | deer, standing | `$M --kinds=deer --state=0 --season=winter --wx=snowbed --ice --cam=5 --frames=3 --every=40 --out=$O/ice_snowback` | the coat whiter frame by frame over 2 minutes; camera (5, 1.8, 0), pitch -13.5 |
| The basin pond frozen, live | 10:00 on a frosty winter day | the world's own (the pond frozen: Kathleen's frozen water look) | whatever crosses or skirts it | `--shots="pond_ice:63584,3,80060,0,-15,10" --life=ice_looks,weather_looks,animal_sign` (x 63584, 3 m above the ground, z 80060 on the pond's south side, yaw 0 facing north (-Z) toward the centre at z 80024, pitch -15, hour 10) | tracks on the snow at the edge, a wolf on the ice, deer going round; needs live animals and a winter world |
| A clap of thunder | 12:00 | a clap 2 s in (`--thunder=2`) | deer, dog, crow | `$M --kinds=deer,dog,crow --state=0 --thunder=2 --cam=6 --frames=8 --every=0.2 --out=$O/thunder` | the crow hopping up flapping, the deer jolting, the dog low; camera (6, 1.8, 0), yaw 90, pitch -11.3 |
| Storm wind | 12:00 | storm wind 0.9 toward +X (`--wx=gale`) | deer, horse | `$M --kinds=deer,horse --state=0 --wx=gale --windlooks --cam=6 --frames=4 --every=1 --out=$O/storm_wind` | rumps toward +X (toward the camera), heads low; camera (6, 1.8, 0), pitch -11.3 |
| Pose library: drinking (21) | 12:00 | clear | deer, horse, cow | `$M --kinds=deer,horse,cow --state=21 --poselib --cam=6 --frames=2 --out=$O/pose_drink` | heads down toward the ground; camera (6, 1.8, 0), yaw 90, pitch -11.3 |
| Pose library: lying (19) | 12:00 | clear | deer, horse, cow | `$M --kinds=deer,horse,cow --state=19 --poselib --cam=6 --frames=2 --out=$O/pose_lie` | legs folded under the body (a wrong-way bend on the cow means its row needs `pose_axis`) |
| Pose library: hunch (20) | 12:00 | clear | goat, elk | `$M --kinds=goat,elk --state=20 --poselib --cam=6 --frames=2 --out=$O/pose_hunch` | heads low on rigs with no hunch pose of their own |
| A deer down on the ice | 12:00, winter | bare ice at the surface (`--water=0.01 --wlife --ice`) | deer, running | `$M --kinds=deer --state=2 --speed=7 --water=0.01 --wlife --ice --poselib --season=winter --cam=8 --frames=12 --every=0.3 --out=$O/ice_fall` | down splayed on all fours in some frames (Jamie #736); camera (8, 1.8, 0), yaw 90, pitch -8.5 |
| Breath at rest and panting | 07:00 | -12 C (`--wx=cold`) | deer (3 at rest), then one running | `$M --kinds=deer --state=0 --count=3 --hour=7 --wx=cold --breath --cam=6 --frames=4 --every=1.5 --out=$O/breath_rest` and `$M --kinds=deer --state=2 --speed=7 --hour=7 --wx=cold --breath --cam=8 --frames=6 --every=0.5 --out=$O/breath_pant` | slow puffs at rest, quick ones running; camera (6 or 8, 1.8, 0), yaw 90, pitch -11.3 or -8.5 |
| Steam off a wet body | 07:00 | -12 C, 0.6 m of water | deer swimming | `$M --kinds=deer --state=1 --speed=1 --water=0.6 --wlife --hour=7 --wx=cold --breath --cam=6 --frames=4 --every=1 --out=$O/body_steam` | thin wisps rising off the back; camera (6, 1.8, 0), pitch -11.3 |
| The open brook below the cave 8002 spring, live | 07:00 on a frosty morning | the world's own | deer at the water (Steve #734), water birds at the edge (#737) | `--shots="spring_brook:56520,1.7,72400,180,-14,7" --life=breath_looks,drink_looks,water_life,wind_looks` (x 56520, 1.7 m up, z 72400 just below the mouth at 72360, yaw 180 facing south downstream, pitch -14, hour 7) | breath puffs over the drinkers, the spring's own steam (Kathleen); needs the live animals |

All of them are also in the run sheet (m19 to m48); these are the ones to keep as reference pictures. Send the strips to MikeW;
nothing else is needed from the sitting for them.

## In the live game (optional, after the strips)
The flags can be turned on for a normal session from the command line: `--life=eye_shine,animal_sign,weather_looks,hunt_feedback`
(any of the flag names in LIFE_LAYER_WIRING.md), and `--life-air=-12` forces the air cold for the steam and the cold huddle. A
live picture needs a wild animal in view, so it is a walk, not a set-up shot: the starter valley at about x 53296, z 68080 (Steve's
fog spot) has deer in the forest edge in the morning.

The tool's world has no coast: its water is a flat sheet over the ground plane, so these are the posed bodies only. A live coast
picture of whales or dolphins waits for Steve's sea species (SEA_MAMMALS.md); until then there is nothing to point a camera at.

## MikeW's PC slot in one go (pr03 to pr23)

The run sheet (PC_SESSION_MIKEW.md) step 4 runs every strip in this order; each line here is what Dino should see. pr13 (the cost pass)
has no strip: it is the gate run with and without `--life-layer-off`. The reference pictures above are the subset to keep.

**pr03 always-on looks**
- m1 [none] dog tail and chest: tail swings between frames, chest rises.
- m2 [none] cat and lynx tails and ears: tail tip flicks, ears turn.
- m3 [none] tails: tails swish against flies.
- m4 [none] the six deer as the camera nears: they face roughly one way; one looks up, then the rest (`look_left` above 0 in m4.log).
- m5 [none] wolf head and ears: head follows the camera, ears forward.
- m6 [none] sleeping animals: deer and dog lie, horse dozes head low; `asleep true` in m6.log.
- m7 [none] swimmers: swim clip plays in the water.
- m8 [none] eyes in torchlight (#596 shine): deer pale green, wolf yellow-green.
- m9 [none] hops: body rises and lands each bound.
- m10 [none] black bear head: head low, jaw open (jaw-pop).

**pr04 footfall and feet**
- m11 [footfall_fx] feet: brown puffs at the running hooves.
- m12 [prints_fx] snow behind them: a line of hoof and paw prints.
- m13 [foot_ik] right-hand feet: stand 15 cm higher than the left, body not tipped.
- m14 [footfall_fx] feet in water: droplets at each step.

**pr05 predators and flight**
- m15 [stalk_fx] the wolf: low, head level, tail still, slow steps.
- m16 [stalk_fx] fox and lynx: leave the ground in an arc.
- m17 [none (wind)] tails and ears: tails swing, ears lie back a little.
- m18 [none] birds: take off, then flap and glide in turns.

**pr06 coats, young, water, idles**
- m19 [season_coats] coat colour: compare with m20.
- m20 [season_coats] coat colour: winter deer greyer, winter fox and wolf paler than here.
- m21 [coat_ruffle] fur: fur moves between frames; no shader error in m21.log.
- m22 [coat_dust] coats while rolling: turn dusty.
- m23 [young_gait] the young: smaller, quick short steps, sway side to side.
- m24 [water_life] swimmers: ride low, only back and head above water, legs paddle.
- m25 [water_life] the muzzle: head down, rings on the water.
- m26 [none (state 20)] heads: held low, ears back.
- m27 [idle_variety] each animal: starts one idle (scratch, groom, shake, paw); no `idle clip ... not in the file` in m27.log.

**pr08 flight part 2, foe, wiring**
- m28 [flight_bank] birds turning: lean into the turn; the crow rolls once.
- m29 [none (storm_ahead)] tails: still (compare m3).
- m30 [stalk_fx] fox and raccoon: creep low.
- m31 [none] heads and ears: bear and boar head low, ears flat; dog barking clip.
- m32 [none] the charge: run clip at speed.
- m33 [none (state 17)] wings: held out in a glide.
- m34 [look_at_foe] heads: turned to their left, not to the camera.

**pr09 young part 2, voices, eye shine**
- m35 [young_follow] the young: turn to the mother; one moves in under her flank.
- m36 [eye_shine] eyes at 15 m: two points of the species' colour per animal.
- m37 [eye_shine] eyes by full moon: faint points close in.

**pr10 animal sign**
- m38 [animal_sign] the mud: prints alternate left and right, one per step (about 0.7 m for the deer).
- m39 [animal_sign] the sand: groups of four prints with long gaps (the rabbit: a Y).
- m40 [animal_sign] the stone: no prints.

**pr11 weather looks**
- m41 [weather_looks] rumps: turned toward downwind (+X) over the frames.
- m42 [weather_looks] the herd: closer than m4, heads low, steam puffs at the muzzles.
- m43 [weather_looks] bodies after 2 s: a 1 s shiver and a spray of drops.
- m44 [weather_looks] coats of the sleeping animals: whiter frame by frame.

**pr12 hunting feedback**
- m45 [hunt_feedback] the deer after 2 s: a jolt, then the hind end low and swinging each stride.
- m46 [hunt_feedback] the first animal at 2 s: its head and front toss up and back.
- m47 [hunt_feedback] the deer after 3 s: it goes down onto its side and lies still, not vanishing.

**pr14 cover still (and the track fixes in m38, m39)**
- m48 [cover_still] both animals: heads low, ears back, barely moving between frames.

**pr15 posed birds**
- m49 [bird_rig] the crow's wings: both wings beat up and down together between frames, mirrored, and `posed flight: wing bones` names six bones in m49.log.

**pr16 posed swimmers**
- m50 [swim_rig] the alligator's body and tail: a wave runs from the shoulders to the tail tip, growing toward the tail, and `posed swim: spine` lists the chain in m50.log.

**pr17 wind direction**
- m51 [wind_looks] which way the bodies face: both turn their rumps toward +X, toward the camera (the downwind side), over the frames, heads low.

**pr18 fog**
- m52 [fog_looks] the eyes and the herd at dusk in 120 m fog: two points of eye shine though it is only dusk, the animals closer together than in m4, the far ones paler with the fog.

**pr19 prevailing wind**
- m53 [wind_looks] which way the alert animals face: both turn toward -X, away from the camera (upwind), up to 45 degrees.

**pr20 cave air**
- m54 [cave_air] the muzzles: no steam puffs (the cave's 5.5 C wins over the sky's -12; compare m42, which steams).

**pr21 drinking**
- m55 [drink_looks] the deer's head and the ground; the crow: the deer's head comes up in at least one frame and a trampled patch lies at its feet; the crow beats its wings with splashes.

**pr22 ice and snow**
- m56 [ice_looks] the deer and the wolf on the ice; the still deer in snow: the deer lurches sideways in some frames and the wolf never does; the still deer whitens frame by frame.

**pr23 thunder**
- m57 [storm_looks] the frames after 2 s: the crow hops up flapping, the deer jolts, the dog drops low and stays low for a few seconds.

**pr24 pose library**
- m58 [pose_lib] heads in 21, legs in 19: in 21 the heads are down toward the ground; in 19 the legs fold (the cow may need `pose_axis`).
- m59 [pose_lib, ice_looks] the running deer on bare ice: down splayed on all fours in some frames, up again in others.

**pr25 breath and steam**
- m60 [breath_looks] the muzzles and backs: slow puffs at rest, quick puffs running, wisps rising off the back of the deer in the water.

Then step 5 (the gates) and step 6 (the PRs, opened in the summary page's order).
