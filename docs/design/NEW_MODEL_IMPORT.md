# New model import: about 10 minutes a model (eagle, raven, owl, bat, whale, dolphin)

For Dave on his PC, one model at a time, in Git Bash from `C:/GodotProjects/DynastyALWL_gate`. The row templates are in
`data/animals/pending_models.json`. MikeW (or any Claude) does steps 4 to 6 from what steps 1 to 3 print, so Dave only needs to run
1 to 3 and say which pictures look wrong.

```bash
GE=/c/GodotInstaller/godot.windows.editor.x86_64.exe
K=raven                     # golden_eagle, raven, owl, bat, whale or dolphin
M=/c/Users/david/Downloads/meshy   # the folder holding one folder per Meshy export
```

## 1. Put the file in place (2 min)
1. Export from Meshy as **FBX, rigged, with animations, textures embedded or beside it**. No .blend.
2. Make `$M/$K/` and put the .fbx and its textures there.
3. Copy it into the game:
```bash
mkdir -p assets/animals/$K && cp "$M/$K"/*.fbx "$M/$K"/*.png assets/animals/$K/ 2>/dev/null
timeout 600 "$GE" --headless --path . --import > /tmp/import_$K.log 2>&1 || timeout 600 "$GE" --headless --path . --import > /tmp/import_$K.log 2>&1
```
Pass: the second line ends without `ERROR` for the .fbx (a first-run crash, exit 139, is retried once).

## 2. List the bones and clips (2 min)
Copy the template row for `$K` from pending_models.json into models.json with only `scene` filled in, then:
```bash
timeout 300 "$GE" --path . --script res://tools/creature_check.gd -- --kinds=$K --clips --out=E:/Software/godotDev/new_$K > /tmp/check_$K.log 2>&1
grep -E "^clip|^bone|NO CLIP|flat|refused" /tmp/check_$K.log | head -80
```
This prints every clip with its length and the bone names. Send the log (or the grep) to MikeW.

## 3. Look at the pictures (3 min)
Open `E:/Software/godotDev/new_$K/$K.png` (one column per role on a 1 m grid) and, after step 5, run the head close-ups:
```bash
timeout 300 "$GE" --path . --script res://tools/creature_check.gd -- --kinds=$K --head --out=E:/Software/godotDev/new_$K > /tmp/head_$K.log 2>&1
```
Say which column looks wrong. The quirks to look for (MODEL_QUIRKS.md):
| What you see | Quirk | Fix (row key) |
|---|---|---|
| The animal is far too big or small on the grid | rest pose not standing, or feathers past the bones | `size_clip`, `length_m` |
| A column shows a flat tube or a squashed body | a clip that lays the rig flat or scales it | the row names another clip; `flat_share` |
| The body slides ahead and snaps back in the strip | clip travel on the root | nothing (taken out by itself) |
| Two clips with the same name in the log | duplicate names | the row names `Name_2` |
| The model is invisible or has black bands | texture alpha that is not a cut-out | material `"opaque": true` |
| No eye highlight in the head close-up | eyes painted on the body | `eye_bones` or `eye_offset` from the head picture |
| A bird or bat stands with wings spread at rest | rest pose not folded | `size_clip` set to the perch or roost clip |
| A fresh copy imports nothing | .blend beside the .fbx | delete the .blend from `assets/animals/$K` |

## 4. Fill the row (MikeW, 1 min)
Every `<...>` from the clip list: roles 0 perch or rest, 3 alert, `walk`/`run` on the ground, 15 flapping, 17 gliding (the
`flight.glide` clip), `takeoff` and `land` once; the eye bones from the head picture; `expect_bones` checked off and removed with
`expect_clips` and `notes`. The raven needs no roll clip: the server's roll event turns the whole bird (`play_roll`).

## 5. Add the species (MikeW, 1 min)
`python tools/add_species.py spec_$K.json` (server row copied from the nearest animal: crow for the raven, pheasant for the owl's
perch, duck flock for the bat colony and the dolphin pod; carcass, sign, step slot and progress row in the same run).

## 6. The proof strip (1 min)
```bash
timeout 300 "$GE" --path . --script res://tools/creature_motion.gd -- --kinds=$K --state=15 --speed=6 --turn=0.8 --frames=8 --every=0.25 --out=E:/Software/godotDev/new_$K > /tmp/motion_$K.log 2>&1
```
For the whale and dolphin use `--state=1 --speed=3 --water=3 --wlife` (they swim on their `swim` clip), and for the bat
`--state=0` to see the roost. Pass: the animal is the right size, faces its way, flaps or swims, and nothing is refused in the log.

## The six, at a glance
| Model | Size | Must have | Game path today | Waiting for |
|---|---|---|---|---|
| Golden eagle | 0.85 m, 2 m wings | perch, flap, glide, take-off, land, strike | flight block (15, 17), bank, look | Steve's soarers (#653 step 2) |
| Raven | 0.62 m | stand, walk, hop, flap, glide, take-off, land | flight block, bank, roll event | the roll event's wire format |
| Owl | 0.4 m | perch, head turn, flap, glide, pounce | flight block, eye shine (pale gold) | night activity row |
| Bat | 9 cm, 28 cm wings | roost hanging, flap, glide, drop, land | flock (colony), `swarm_fx`: boil in flight, hang head down | Steve's cave roost and dusk exit (BAT_RIG.md 2) |
| Whale | 14 m | swim slow and fast, surface idle, blow, dive, breach | swim clip in water, `sea_life`: the blow spout | a sea species row and sea events (SEA_MAMMALS.md) |
| Dolphin | 2.5 m | swim, swim fast, leap, breathe | flock (pod), swim clip, porpoising on the hop arc, `sea_life` blow | a sea species row (SEA_MAMMALS.md) |
