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
| Rump to the wind in rain | 12:00 | wind 0.5 toward +X, rain 0.6 (`--wx=windrain`) | deer, horse | `$M --kinds=deer,horse --state=0 --wx=windrain --windlooks --cam=6 --frames=4 --every=1 --out=$O/wind_rump` | rumps turning toward +X (the camera's left in this view), heads low; camera (6, 1.8, 0), yaw 90, pitch -11.3 |
| Deer grazing into a breeze | 12:00 | wind 0.3 toward +X (`--wx=breeze`) | deer herd of 3 | `$M --kinds=deer --state=0 --count=3 --wx=breeze --windlooks --cam=8 --frames=4 --every=1 --out=$O/wind_graze` | noses turning toward -X (upwind, the camera's right), up to 45 degrees; camera (8, 1.8, 0), pitch -8.5 |
| Windward fur | 12:00 | wind 0.9 toward +X | fox, bear | `$M --kinds=fox,bear --state=0 --wind=0.9 --wx=gale --ruffle --windlooks --cam=3 --frames=6 --every=0.15 --out=$O/wind_fur` | the fur on the -X side (facing the wind) moving more than the +X side; camera (3, 1.8, 0), pitch -21.8 |

All of them are also in the run sheet (m19 to m48); these are the ones to keep as reference pictures. Send the strips to MikeW;
nothing else is needed from the sitting for them.

## In the live game (optional, after the strips)
The flags can be turned on for a normal session from the command line: `--life=eye_shine,animal_sign,weather_looks,hunt_feedback`
(any of the flag names in LIFE_LAYER_WIRING.md), and `--life-air=-12` forces the air cold for the steam and the cold huddle. A
live picture needs a wild animal in view, so it is a walk, not a set-up shot: the starter valley at about x 53296, z 68080 (Steve's
fog spot) has deer in the forest edge in the morning.

The tool's world has no coast: its water is a flat sheet over the ground plane, so these are the posed bodies only. A live coast
picture of whales or dolphins waits for Steve's sea species (SEA_MAMMALS.md); until then there is nothing to point a camera at.
