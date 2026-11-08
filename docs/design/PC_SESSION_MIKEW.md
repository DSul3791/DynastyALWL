# PC session run sheet: the animal life layer (MikeW, 8 Nov 2026)

For whoever runs it on Dave's PC (MikeW or Dino), word for word. About 65 minutes in one sitting (Godot starts about 30 s per strip line; 34 lines). m1 to m18 and the gates are the core hour; m19 to m34 are the newer flags and can follow in the same sitting. Every command runs from `C:/GodotProjects/DynastyALWL_gate` in Git Bash. `GE` is the editor; `O` is the picture folder.

```bash
cd /c/GodotProjects/DynastyALWL_gate
GE=/c/GodotInstaller/godot.windows.editor.x86_64.exe
O=/e/Software/godotDev/pc_session_mikew
mkdir -p $O
```

## 0. Branch and import (3 min)
```bash
git fetch -q origin
git checkout -q --detach origin/claude/mikew-eye-placement
python tools/install_animal_models.py --import=$GE
git checkout -q -- assets/character assets/trees 2>/dev/null; rm -f src/sullivan_water/ocean/ocean_mesh.gd.uid
```
Pass: the install prints no `MISSING` and `import attempt 1: exit 0` (or attempt 2).

## 1. Head sheets for eye placement (5 min)
```bash
timeout 600 "$GE" --path . --script res://tools/creature_check.gd -- --head --out=$O/head --kinds=deer,moose,wolf,fox,rabbit,boar,lynx,black_bear,bighorn,mountain_goat,beaver,chamois,mink,raccoon,rat,cow,goat,cat,dog,buffalo,puma,pronghorn,warthog,hyena,wildebeest,lion,leopard,rhino,camel,honey_badger,mammoth,bear > $O/head.log 2>&1
grep -E "^head bones|FAIL" $O/head.log | head -40
```
Proves: where each species' eye or head bones sit. Pass: one `head_<kind>_front.png` and `_three_quarter.png` per kind, red marks on the head. MikeW then sets `eye_bones` / `eye_offset` from them.

## 2. Lynx standing idle (2 min)
```bash
timeout 300 "$GE" --path . --script res://tools/creature_check.gd -- --kinds=lynx --roles=Idle,idle_call_01,idle_shake_01,idle_stretching_01,drinking_set_01,idle_alerted_pose_01_to_idle_pose_01 --out=$O/lynx > $O/lynx.log 2>&1
```
Proves: which clip stands tall. Pass: `$O/lynx/lynx.png`, 7 columns.

## 3. Still checks of new clips (3 min)
```bash
timeout 600 "$GE" --path . --script res://tools/creature_check.gd -- --kinds=dog,alligator,black_bear,rabbit,kangaroo --out=$O/still > $O/still.log 2>&1
grep -E "^==|^role|NO CLIP|flat" $O/still.log
```
Proves: dog sit (18) and lie (19), alligator swim, black bear warn under the jaw-pop pose, rabbit and kangaroo hop clips. Pass: no `NO CLIP` for sit, lie or swim.

## 4. Moving frames (27 min)
Each line makes one strip (6 frames unless it says). If time runs short, m1 to m18 come first: they prove what is already merged-ready; m19 to m27 are the newer flags.
```bash
M="timeout 300 $GE --path . --script res://tools/creature_motion.gd --"
$M --kinds=dog --state=0 --out=$O/motion > $O/m1.log 2>&1                         # tail wag at rest, breathing
$M --kinds=cat,lynx --state=3 --out=$O/motion > $O/m2.log 2>&1                    # tail flick when alert, ears
$M --kinds=horse,cow --state=0 --season=summer --out=$O/motion > $O/m3.log 2>&1   # fly swish
$M --kinds=deer --state=0 --count=6 --approach --out=$O/motion > $O/m4.log 2>&1   # herd facing, one looks up then the rest
$M --kinds=wolf --state=3 --approach --out=$O/motion > $O/m5.log 2>&1             # predator head tracking, ears
$M --kinds=deer,dog,horse --state=0 --hour=2 --out=$O/motion_sleep > $O/m6.log 2>&1  # asleep at night (deer lie, horse dozes)
$M --kinds=beaver,moose --state=0 --water=0.6 --speed=1 --out=$O/motion > $O/m7.log 2>&1  # swim clip and the wet look
$M --kinds=deer,wolf --state=0 --torch --hour=23 --cam=8 --out=$O/motion_night > $O/m8.log 2>&1   # eye shine in torchlight
$M --kinds=rabbit,kangaroo --state=0 --speed=3 --out=$O/motion > $O/m9.log 2>&1   # hop arc
$M --kinds=black_bear --state=16 --out=$O/motion > $O/m10.log 2>&1                # jaw-pop pose
$M --kinds=horse,deer --state=2 --speed=8 --fx --every=0.1 --out=$O/motion_fx > $O/m11.log 2>&1   # dust puffs at running footfalls
$M --kinds=deer,wolf --state=0 --speed=1.5 --season=winter --prints --frames=4 --every=1 --out=$O/motion_prints > $O/m12.log 2>&1   # prints in snow (hoof and paw)
$M --kinds=deer,horse,cow --state=0 --ik --cam=4 --out=$O/motion_ik > $O/m13.log 2>&1   # feet reach a 15 cm step on one side
$M --kinds=deer --state=2 --speed=6 --water=0.3 --fx --every=0.1 --out=$O/motion_splash > $O/m14.log 2>&1   # splashes wading
$M --kinds=wolf --state=6 --speed=1 --stalk --out=$O/motion_stalk > $O/m15.log 2>&1   # wolf stalk crouch, slow steps
$M --kinds=fox,lynx --state=7 --speed=4 --stalk --every=0.1 --out=$O/motion_pounce > $O/m16.log 2>&1   # pounce arc
$M --kinds=horse,dog --state=0 --wind=0.9 --out=$O/motion_wind > $O/m17.log 2>&1   # ears back and tails swinging in a gale
$M --kinds=goose,pheasant,duck --state=15 --frames=8 --every=0.3 --out=$O/motion_flight > $O/m18.log 2>&1   # take-off, flap and glide
$M --kinds=deer,fox,wolf --state=0 --season=winter --coats --frames=2 --out=$O/motion_coat_winter > $O/m19.log 2>&1   # winter coats (compare with the next)
$M --kinds=deer,fox,wolf --state=0 --season=summer --coats --frames=2 --out=$O/motion_coat_summer > $O/m20.log 2>&1   # summer coats
$M --kinds=fox,wolf,bear --state=0 --wind=1 --ruffle --frames=6 --every=0.15 --out=$O/motion_ruffle > $O/m21.log 2>&1   # fur moving in a full wind
$M --kinds=horse,dog --state=8 --dust --frames=4 --every=1 --out=$O/motion_dust > $O/m22.log 2>&1   # coat dusting while rolling
$M --kinds=deer,horse,cow --state=0 --speed=1.5 --young=2 --age=3 --season=spring --every=0.15 --out=$O/motion_young > $O/m23.log 2>&1   # newborns: small, quick steps, swaying
$M --kinds=deer,dog --state=2 --speed=1 --wlife --water=1.2 --every=0.15 --out=$O/motion_swim > $O/m24.log 2>&1   # swimming low, legs paddling
$M --kinds=deer,horse --state=0 --bank --frames=4 --every=0.5 --out=$O/motion_drink > $O/m25.log 2>&1   # drinking at the bank, rings
$M --kinds=deer,horse,wolf --state=20 --frames=2 --out=$O/motion_hunch > $O/m26.log 2>&1   # hunch: head low, ears back
$M --kinds=dog,lion,horse,boar --state=0 --idles --frames=8 --every=0.5 --out=$O/motion_idles > $O/m27.log 2>&1   # idle variety: a scratch, groom, shake or paw
$M --kinds=crow,pheasant --state=15 --speed=6 --turn=0.8 --roll --frames=8 --every=0.25 --out=$O/motion_bank > $O/m28.log 2>&1   # banking into a turn, a roll
$M --kinds=horse,cow --state=0 --season=summer --storm --out=$O/motion_storm > $O/m29.log 2>&1   # storm_ahead: no fly swish (compare m3)
$M --kinds=fox,raccoon --state=13 --speed=1 --stalk --out=$O/motion_sneak > $O/m30.log 2>&1   # sneak (13): low creep
$M --kinds=bear,boar,dog --state=10 --frames=3 --out=$O/motion_warn > $O/m31.log 2>&1   # warn (10): head low, ears flat; the dog barks
$M --kinds=bear,moose --state=11 --speed=8 --every=0.1 --out=$O/motion_charge > $O/m32.log 2>&1   # charge (11)
$M --kinds=pheasant,goose --state=17 --frames=3 --out=$O/motion_glide > $O/m33.log 2>&1   # glide (17): wings held out
$M --kinds=bear,horse --state=10 --foe --frames=3 --out=$O/motion_foe > $O/m34.log 2>&1   # foe position: head turned to the side, not the camera
timeout 120 $GE --headless --path . --script res://src/worldgen/tools/test_herd_groups.gd > $O/herd_groups.log 2>&1; grep -E "^FAIL|failures" $O/herd_groups.log   # server herd groups (seconds): 0 failures
grep -h "saved\|SCRIPT" $O/m*.log
```
Pass, per strip, by eye: the tail or ears move between frames; sleeping animals lie (deer, dog) or stand head-low (horse) and `asleep true` in the log; the deer herd faces roughly one way and `look_left` above 0 on more than one frame as the camera nears; the beaver and moose show `wet` near 1; eyes glow in the night strip (deer pale green, wolf yellow-green); the rabbit and kangaroo rise and land; the black bear's head is low with the jaw open; brown puffs at the running hooves; a line of hoof and paw prints behind the deer and wolf on snow, fading only slowly; the deer's, horse's and cow's right-hand feet stand 15 cm higher than the left without the body tipping; droplets at the wading deer's feet; the stalking wolf low with its head level and tail still; the fox and lynx leave the ground in the pounce strip; the horse's and dog's tails swing and ears lie a little back in the gale; the goose and pheasant take off, then flap and glide in turns; the winter deer is greyer and the winter fox and wolf paler than in summer; the fox's and bear's fur moves between ruffle frames (no shader error in m21.log); the rolling horse turns dusty; the fawn, foal and calf keep pace with short quick steps and sway side to side; the swimming deer and dog ride low with only back and head above the water; rings at the drinking muzzles; the hunched deer, horse and wolf hold their heads low; in the idles strip each animal starts one idle (dog scratch or shake, lion grooming, horse shake, look round or pawing, boar head shake) and no `idle clip ... not in the file` in m27.log; the crow and pheasant lean into the turn and the crow rolls once in the bank strip; the storm horse and cow hold their tails still; the sneaking fox and raccoon creep low; the warning bear and boar drop their heads with ears flat and the dog barks; the charging bear and moose run; the gliding pheasant and goose hold their wings out; in the foe strip the bear and horse look to their left, not at the camera. Every row of LIFE_LAYER_WIRING.md names its strip.

## 5. Gates (15 min, in order)
```bash
for b in eyeshine wet-look eye-placement; do
  h=$(git rev-parse origin/claude/mikew-$b)
  bash tools/gate_pc.sh $h --lane fast 2>&1 | grep -E "CONFLICT|FAIL|warnings|LOCAL CHECK|Test done|NEW fail|CHECKS:"
done
```
Pass: `CHECKS: pass` for each. On a `CONFLICT`, main has moved: merge `origin/main` into that branch first (MikeW).

## 6. PRs (5 min), in this order, only after their gate passed
1. Eye shine (`claude/mikew-eyeshine`, already open as #596: `gh pr ready 596`).
2. Wet look (`claude/mikew-wet-look`, new PR).
3. Animal life layer (`claude/mikew-eye-placement`: eye placement, dog clips, tails, ears, breathing, head tracking, posed states, hop, sleep, herds, footfall, stalk, flight, coats, young, water, hunch, idle variety; new PR; every new look behind its own flag, off).

Send each head to the coordinator after the push prints it.

## Pre-sitting review (MikeW, 8 Nov 2026)

The whole branch was read against #596 (`git diff $(git merge-base HEAD origin/claude/mikew-eyeshine)`: 31 files, about 4,900 lines).

**Flags.** All fourteen client flags default to false (`footfall_fx`, `prints_fx`, `slope_tilt`, `foot_ik`, `stalk_fx`, `season_coats`,
`coat_dust`, `coat_ruffle`, `young_gait`, `water_life`, `idle_variety`, `flight_bank`, `look_at_foe`, plus the tool-only `young_age_days`
and `idle_first_s` at -1). terrain_client sets only callables (torch, conditions, ground, wind, water), never a flag. Server
`groups.enabled` is false in animals.json.

**On without a flag, by design (state- or row-driven, on the merged-ready part):** eye placement, dog clips 10/18/19, tail, ears,
breathing, head tracking, jaw-pop pose, hop arc, sleep, herd facing and spacing, flight part 1 (take-off, flap and glide, bob),
state 17 glide, hunch 20 (only when the server sends 20). These are proved by m1 to m18, m26 and m33.

**Fixed in this review:**
1. Flocks in flight shared one record per flock, and the flight block runs once per bird a frame: air time ran N times fast, only
   the first bird played its take-off, and with `flight_bank` the bank flickered between birds. Each flock bird now keeps its own
   flight record (`flight_b` meta); a single bird still uses its own record, so `play_roll` and `_flap_bob` are unchanged.
2. The reverse walk for an animal backing away ran in every state, so a fleeing animal turning round would have run backward for a
   moment. It now applies only while facing something (states 3, 10, 12: Steve's goblin back-off is ALERT).
3. A row with `idles` built a bone layer (a SkeletonModifier3D running every frame) even with `idle_variety` off, for species that had
   none before (rabbit, cat, cow, goat). The layer and the idle poses are now built only when the flag is on.

**Checked, no change needed:** every clip lookup goes through `_clip_full`, which returns "" and is logged and skipped; every bone list
goes through bone_offsets `setup_*`, which reports missing bones and skips them; Rig and meta reads use `get_node_or_null` /
`get_meta(..., default)`; coat materials are typed checked (ShaderMaterial or StandardMaterial3D); the per-frame work with flags off is
the flag tests themselves plus the backing test (one dot product per model animal).

**Server files touched (separate PR, Steve to review):** `src/stream/server_animals.gd` (herd groups, behind `groups.enabled`: one weather
copy per tick, two guarded call sites), `data/animals/animals.json` (the groups block, `group_drift` and `group_spacing_m` on 13 herd
species), `src/worldgen/tools/test_herd_groups.gd`. The server code is untouched with the flag off apart from `_weather = weather`.

**Known open:** the raven roll event's wire format (Steve); Mandy-style clips for horses' pawing are posed guesses (front-leg waves) until
the strip shows them; the ruffle shader's first compile is on the PC (m21).

## PR split after the gates (for Tyler, in merge order)

The branch is one linear chain (with main merged in), so the client PRs are stacked ranges of it; each later PR's branch is cut at
its last commit and lists the earlier PR as its base. No history is rewritten.

1. **#596 eye shine** (`claude/mikew-eyeshine`), as now.
2. **Wet look** (`claude/mikew-wet-look`), new PR.
3. **Life layer A, the always-on looks:** commits 45cd36d33 to 6c9522c85 (eye placement, dog clips, tail, ears, breathing, head tracking,
   jaw-pop, hop, sleep, client herds, creature_check, creature_motion and this run sheet). Proved by m1 to m10.
4. **Life layer B, footfall and feet (flags):** d0f95093d to d2f0a14aa (puffs, slope pitch, prints, foot reach, splashes). m11 to m14.
5. **Life layer C, predators and birds:** a7165110c to 5924e90fc (stalk and pounce behind `stalk_fx`, wind ears and tails, flight part 1
   on). m15 to m18.
6. **Life layer D, coats, young, water, idles (flags):** 1a5373d83, f9af2f2f1, 308ff3a9f, cd4331724. m19 to m27.
7. **Herd groups (server, flag off):** 1528fa6f9 cherry-picked onto main as its own PR (it touches only the server files above and three
   docs), so Steve can review it apart from the client chain. test_herd_groups.gd in the gate.
8. **Life layer E, flight part 2, backing, wiring:** d16abcf5f, f34903104, aef1d008f and this review's fix commit. m28 to m34.
