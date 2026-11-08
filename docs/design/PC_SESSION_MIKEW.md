# PC session run sheet: the animal life layer (MikeW, 8 Nov 2026)

For whoever runs it on Dave's PC (MikeW or Dino), word for word. **About 92 minutes in one sitting**, counted honestly: import 3, head sheets 6, lynx 2, stills 3, the 58 motion strips about 49 (Godot starts about 25 s per line; m44 takes 2 minutes), looking at the pictures about 10, the three gates about 25, PRs 5. The core hour is steps 0 to 3, m1 to m18 and the gates (about 55 minutes); m19 to m58 can follow in the same sitting or the next. Every command runs from `C:/GodotProjects/DynastyALWL_gate` in Git Bash. `GE` is the editor; `O` is the picture folder.

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

## 1. Head sheets for eye placement (6 min)
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

## 4. Moving frames (about 49 min: 58 lines, about 45 s each)
One line per strip: the flag it proves (the strip turns it on by itself), the command, what to look at in `$O/<out>/motion_<kind>_<state>.png`, and pass or fail. m1 to m18 come first (the always-on looks and the older flags); m19 to m58 are the newer flags and follow in the same sitting.
```bash
M="timeout 300 $GE --path . --script res://tools/creature_motion.gd --"
$M --kinds=dog --state=0 --out=$O/motion > $O/m1.log 2>&1   # m1 [none] look: dog tail and chest. PASS: tail swings between frames, chest rises. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=cat,lynx --state=3 --out=$O/motion > $O/m2.log 2>&1   # m2 [none] look: cat and lynx tails and ears. PASS: tail tip flicks, ears turn. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=horse,cow --state=0 --season=summer --out=$O/motion > $O/m3.log 2>&1   # m3 [none] look: tails. PASS: tails swish against flies. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer --state=0 --count=6 --approach --out=$O/motion > $O/m4.log 2>&1   # m4 [none] look: the six deer as the camera nears. PASS: they face roughly one way; one looks up, then the rest (`look_left` above 0 in m4.log). FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=wolf --state=3 --approach --out=$O/motion > $O/m5.log 2>&1   # m5 [none] look: wolf head and ears. PASS: head follows the camera, ears forward. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,dog,horse --state=0 --hour=2 --out=$O/motion_sleep > $O/m6.log 2>&1   # m6 [none] look: sleeping animals. PASS: deer and dog lie, horse dozes head low; `asleep true` in m6.log. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=beaver,moose --state=0 --water=0.6 --speed=1 --out=$O/motion > $O/m7.log 2>&1   # m7 [none] look: swimmers. PASS: swim clip plays in the water. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,wolf --state=0 --torch --hour=23 --cam=8 --out=$O/motion_night > $O/m8.log 2>&1   # m8 [none] look: eyes in torchlight (#596 shine). PASS: deer pale green, wolf yellow-green. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=rabbit,kangaroo --state=0 --speed=3 --out=$O/motion > $O/m9.log 2>&1   # m9 [none] look: hops. PASS: body rises and lands each bound. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=black_bear --state=16 --out=$O/motion > $O/m10.log 2>&1   # m10 [none] look: black bear head. PASS: head low, jaw open (jaw-pop). FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=horse,deer --state=2 --speed=8 --fx --every=0.1 --out=$O/motion_fx > $O/m11.log 2>&1   # m11 [footfall_fx] look: feet. PASS: brown puffs at the running hooves. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,wolf --state=0 --speed=1.5 --season=winter --prints --frames=4 --every=1 --out=$O/motion_prints > $O/m12.log 2>&1   # m12 [prints_fx] look: snow behind them. PASS: a line of hoof and paw prints. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,horse,cow --state=0 --ik --cam=4 --out=$O/motion_ik > $O/m13.log 2>&1   # m13 [foot_ik] look: right-hand feet. PASS: stand 15 cm higher than the left, body not tipped. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer --state=2 --speed=6 --water=0.3 --fx --every=0.1 --out=$O/motion_splash > $O/m14.log 2>&1   # m14 [footfall_fx] look: feet in water. PASS: droplets at each step. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=wolf --state=6 --speed=1 --stalk --out=$O/motion_stalk > $O/m15.log 2>&1   # m15 [stalk_fx] look: the wolf. PASS: low, head level, tail still, slow steps. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=fox,lynx --state=7 --speed=4 --stalk --every=0.1 --out=$O/motion_pounce > $O/m16.log 2>&1   # m16 [stalk_fx] look: fox and lynx. PASS: leave the ground in an arc. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=horse,dog --state=0 --wind=0.9 --out=$O/motion_wind > $O/m17.log 2>&1   # m17 [none (wind)] look: tails and ears. PASS: tails swing, ears lie back a little. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=goose,pheasant,duck --state=15 --frames=8 --every=0.3 --out=$O/motion_flight > $O/m18.log 2>&1   # m18 [none] look: birds. PASS: take off, then flap and glide in turns. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,fox,wolf --state=0 --season=winter --coats --frames=2 --out=$O/motion_coat_winter > $O/m19.log 2>&1   # m19 [season_coats] look: coat colour. PASS: compare with m20. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,fox,wolf --state=0 --season=summer --coats --frames=2 --out=$O/motion_coat_summer > $O/m20.log 2>&1   # m20 [season_coats] look: coat colour. PASS: winter deer greyer, winter fox and wolf paler than here. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=fox,wolf,bear --state=0 --wind=1 --ruffle --frames=6 --every=0.15 --out=$O/motion_ruffle > $O/m21.log 2>&1   # m21 [coat_ruffle] look: fur. PASS: fur moves between frames; no shader error in m21.log. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=horse,dog --state=8 --dust --frames=4 --every=1 --out=$O/motion_dust > $O/m22.log 2>&1   # m22 [coat_dust] look: coats while rolling. PASS: turn dusty. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,horse,cow --state=0 --speed=1.5 --young=2 --age=3 --season=spring --every=0.15 --out=$O/motion_young > $O/m23.log 2>&1   # m23 [young_gait] look: the young. PASS: smaller, quick short steps, sway side to side. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,dog --state=2 --speed=1 --wlife --water=1.2 --every=0.15 --out=$O/motion_swim > $O/m24.log 2>&1   # m24 [water_life] look: swimmers. PASS: ride low, only back and head above water, legs paddle. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,horse --state=0 --bank --frames=4 --every=0.5 --out=$O/motion_drink > $O/m25.log 2>&1   # m25 [water_life] look: the muzzle. PASS: head down, rings on the water. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,horse,wolf --state=20 --frames=2 --out=$O/motion_hunch > $O/m26.log 2>&1   # m26 [none (state 20)] look: heads. PASS: held low, ears back. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=dog,lion,horse,boar --state=0 --idles --frames=8 --every=0.5 --out=$O/motion_idles > $O/m27.log 2>&1   # m27 [idle_variety] look: each animal. PASS: starts one idle (scratch, groom, shake, paw); no `idle clip ... not in the file` in m27.log. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=crow,pheasant --state=15 --speed=6 --turn=0.8 --roll --frames=8 --every=0.25 --out=$O/motion_bank > $O/m28.log 2>&1   # m28 [flight_bank] look: birds turning. PASS: lean into the turn; the crow rolls once. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=horse,cow --state=0 --season=summer --storm --out=$O/motion_storm > $O/m29.log 2>&1   # m29 [none (storm_ahead)] look: tails. PASS: still (compare m3). FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=fox,raccoon --state=13 --speed=1 --stalk --out=$O/motion_sneak > $O/m30.log 2>&1   # m30 [stalk_fx] look: fox and raccoon. PASS: creep low. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=bear,boar,dog --state=10 --frames=3 --out=$O/motion_warn > $O/m31.log 2>&1   # m31 [none] look: heads and ears. PASS: bear and boar head low, ears flat; dog barking clip. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=bear,moose --state=11 --speed=8 --every=0.1 --out=$O/motion_charge > $O/m32.log 2>&1   # m32 [none] look: the charge. PASS: run clip at speed. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=pheasant,goose --state=17 --frames=3 --out=$O/motion_glide > $O/m33.log 2>&1   # m33 [none (state 17)] look: wings. PASS: held out in a glide. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=bear,horse --state=10 --foe --frames=3 --out=$O/motion_foe > $O/m34.log 2>&1   # m34 [look_at_foe] look: heads. PASS: turned to their left, not to the camera. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,horse --state=0 --young=2 --age=20 --season=spring --follow --frames=6 --every=1 --out=$O/motion_mother > $O/m35.log 2>&1   # m35 [young_follow] look: the young. PASS: turn to the mother; one moves in under her flank. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,wolf,cat,bear,horse --state=3 --torch --shine --hour=23 --cam=15 --frames=2 --out=$O/motion_shine > $O/m36.log 2>&1   # m36 [eye_shine] look: eyes at 15 m. PASS: two points of the species' colour per animal. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,wolf,cat,bear,horse --state=3 --shine --moon --hour=23 --cam=4 --frames=2 --out=$O/motion_moon > $O/m37.log 2>&1   # m37 [eye_shine] look: eyes by full moon. PASS: faint points close in. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,wolf --state=0 --speed=1.5 --sign=mud --frames=4 --every=1 --out=$O/motion_sign_walk > $O/m38.log 2>&1   # m38 [animal_sign] look: the mud. PASS: prints alternate left and right, one per step (about 0.7 m for the deer). FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,wolf,rabbit --state=2 --speed=8 --sign=sand --frames=4 --every=0.5 --out=$O/motion_sign_run > $O/m39.log 2>&1   # m39 [animal_sign] look: the sand. PASS: groups of four prints with long gaps (the rabbit: a Y). FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer --state=0 --sign=stone --frames=2 --every=1 --out=$O/motion_sign_hard > $O/m40.log 2>&1   # m40 [animal_sign] look: the stone. PASS: no prints. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,horse --state=0 --wx=gale --frames=3 --every=1 --out=$O/motion_wx_gale > $O/m41.log 2>&1   # m41 [weather_looks] look: rumps. PASS: turned toward downwind (+X) over the frames. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer --state=0 --count=6 --wx=cold --frames=4 --every=1 --out=$O/motion_wx_cold > $O/m42.log 2>&1   # m42 [weather_looks] look: the herd. PASS: closer than m4, heads low, steam puffs at the muzzles. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=dog,wolf --state=0 --wx=stoprain --frames=6 --every=0.3 --out=$O/motion_wx_shake > $O/m43.log 2>&1   # m43 [weather_looks] look: bodies after 2 s. PASS: a 1 s shiver and a spray of drops. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,dog --state=0 --hour=2 --wx=snowbed --frames=3 --every=40 --out=$O/motion_wx_snow > $O/m44.log 2>&1   # m44 [weather_looks] look: coats of the sleeping animals. PASS: whiter frame by frame. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer --state=0 --speed=1.5 --hit=hip --frames=8 --every=0.25 --out=$O/motion_hit_hip > $O/m45.log 2>&1   # m45 [hunt_feedback] look: the deer after 2 s. PASS: a jolt, then the hind end low and swinging each stride. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,boar --state=0 --hit=head --frames=6 --every=0.1 --out=$O/motion_hit_head > $O/m46.log 2>&1   # m46 [hunt_feedback] look: the first animal at 2 s. PASS: its head and front toss up and back. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer --state=0 --hit=chest --kill --frames=6 --every=0.3 --out=$O/motion_kill > $O/m47.log 2>&1   # m47 [hunt_feedback] look: the deer after 3 s. PASS: it goes down onto its side and lies still, not vanishing. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=deer,horse --state=20 --cover --frames=4 --every=0.5 --out=$O/motion_cover > $O/m48.log 2>&1   # m48 [cover_still] look: both animals. PASS: heads low, ears back, barely moving between frames. FAIL: anything else, or SCRIPT ERROR in the log
$M --kinds=crow --state=15 --birdrig --posed --frames=8 --every=0.06 --cam=3 --out=$O/motion_posed_wings > $O/m49.log 2>&1   # m49 [bird_rig] look: the crow's wings. PASS: both wings beat up and down together between frames, mirrored, and `posed flight: wing bones` names six bones in m49.log. FAIL: one wing only, wings through the body, or `no wing bones found`
$M --kinds=alligator --state=1 --speed=1 --water=1 --swimrig --posed --cam=6 --frames=8 --every=0.15 --out=$O/motion_posed_swim > $O/m50.log 2>&1   # m50 [swim_rig] look: the alligator's body and tail. PASS: a wave runs from the shoulders to the tail tip, growing toward the tail, and `posed swim: spine` lists the chain in m50.log. FAIL: a stiff body, a bend at one bone only, or `no spine chain found`
$M --kinds=deer,horse --state=0 --wx=windrain --windlooks --frames=4 --every=1 --cam=6 --out=$O/motion_wind_rump > $O/m51.log 2>&1   # m51 [wind_looks] look: which way the bodies face. PASS: both turn their rumps toward +X, toward the camera (the downwind side), over the frames, heads low. FAIL: no turn, a turn into the wind, or SCRIPT ERROR in the log
$M --kinds=deer,wolf --state=3 --count=4 --torch --shine --hour=19.5 --fog=120 --cam=15 --frames=3 --every=0.5 --out=$O/motion_fog > $O/m52.log 2>&1   # m52 [fog_looks] look: the eyes and the herd at dusk in 120 m fog. PASS: two points of eye shine though it is only dusk, the animals closer together than in m4, the far ones paler with the fog. FAIL: no shine, or SCRIPT ERROR in the log
$M --kinds=deer,horse --state=3 --wx=breeze --windlooks --frames=4 --every=1 --cam=6 --out=$O/motion_wind_alert > $O/m53.log 2>&1   # m53 [wind_looks] look: which way the alert animals face. PASS: both turn toward -X, away from the camera (upwind), up to 45 degrees. FAIL: no turn, a turn toward the camera, or SCRIPT ERROR in the log
$M --kinds=deer --state=0 --count=3 --hour=7 --wx=cold --cave=5.5 --frames=4 --every=1 --cam=6 --out=$O/motion_cave_air > $O/m54.log 2>&1   # m54 [cave_air] look: the muzzles. PASS: no steam puffs (the cave's 5.5 C wins over the sky's -12; compare m42, which steams). FAIL: steam, or SCRIPT ERROR in the log
$M --kinds=deer --state=0 --bank --drink --sign=mud --frames=8 --every=1.5 --cam=5 --out=$O/motion_drink2 > $O/m55.log 2>&1; $M --kinds=crow --state=0 --water=0.05 --wlife --drink --frames=8 --every=0.5 --cam=3 --out=$O/motion_bathe >> $O/m55.log 2>&1   # m55 [drink_looks] look: the deer's head and the ground; the crow. PASS: the deer's head comes up in at least one frame and a trampled patch lies at its feet; the crow beats its wings with splashes. FAIL: no lift, no patch, no bathe, or SCRIPT ERROR in the log
$M --kinds=deer,wolf --state=0 --speed=1.2 --water=0.01 --wlife --ice --season=winter --frames=10 --every=0.25 --cam=6 --out=$O/motion_ice > $O/m56.log 2>&1; $M --kinds=deer --state=0 --season=winter --wx=snowbed --ice --frames=3 --every=40 --cam=5 --out=$O/motion_snow_still >> $O/m56.log 2>&1   # m56 [ice_looks] look: the deer and the wolf on the ice; the still deer in snow. PASS: the deer lurches sideways in some frames and the wolf never does; the still deer whitens frame by frame. FAIL: either slips the same, no whitening, or SCRIPT ERROR in the log
$M --kinds=deer,dog,crow --state=0 --thunder=2 --frames=8 --every=0.2 --cam=6 --out=$O/motion_thunder > $O/m57.log 2>&1   # m57 [storm_looks] look: the frames after 2 s. PASS: the crow hops up flapping, the deer jolts, the dog drops low and stays low for a few seconds. FAIL: no reaction, or SCRIPT ERROR in the log
$M --kinds=deer,horse,cow --state=21 --poselib --frames=2 --cam=6 --out=$O/motion_pose_drink > $O/m58.log 2>&1; $M --kinds=deer,horse,cow --state=19 --poselib --frames=2 --cam=6 --out=$O/motion_pose_lie >> $O/m58.log 2>&1   # m58 [pose_lib] look: heads in 21, legs in 19. PASS: in 21 the heads are down toward the ground; in 19 the deer's, horse's and cow's legs fold (the cow may bend the wrong way: then its row needs pose_axis); `pose library:` lines in m58.log. FAIL: no change from the graze clip, or SCRIPT ERROR in the log
grep -h "saved\|SCRIPT ERROR" $O/m*.log
```

## 5. Gates (about 25 min, in order)
```bash
for b in eyeshine wet-look eye-placement; do
  h=$(git rev-parse origin/claude/mikew-$b)
  bash tools/gate_pc.sh $h --lane fast 2>&1 | grep -E "CONFLICT|FAIL|warnings|LOCAL CHECK|Test done|NEW fail|CHECKS:"
done
```
Pass: `CHECKS: pass` for each. For the cost check, play once with `--life-layer-off` and once without in the same spot and compare the frame probe (PERF_BUDGET.md). On a `CONFLICT`, main has moved: merge `origin/main` into that branch first (MikeW).

## 6. PRs (5 min), in this order, only after their gate passed
1. Eye shine (`claude/mikew-eyeshine`, already open as #596: `gh pr ready 596`).
2. Wet look (`claude/mikew-wet-look`, new PR).
3. Animal life layer (`claude/mikew-eye-placement`), as the stacked PRs 3 to 10 in "PR split" below; every new look behind its own flag, off. MIKEW_BRANCH_SUMMARY.md is the one-page view.

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

**Server files:** none on this branch any more. Herd groups moved to #666 on Steve's stack with his review fixes, and its server code, data, test and HERD_GROUPS.md were removed from this branch (consolidation, 8 Nov 2026), so this branch is client only.

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
7. **Herd groups (server, flag off):** #666 on Steve's stack, gated by David4 with Steve's PRs; not part of this chain.
8. **Life layer E, flight part 2, backing, wiring:** d16abcf5f, f34903104, aef1d008f and this review's fix commit. m28 to m34.
9. **Life layer F, after the review:** young size by age and the mother (m35), new-model templates with bat swarm and sea blow, voices by state, and night eye shine v2 (`eye_shine`: torch and moon by the retroreflection angle, far-off eye dots; m36, m37).
10. **Life layer G, animal sign:** `animal_sign` (tracks on soft ground by stride and gait, droppings, browse and beds, a 400-decal pool with Jamie's soak lifetimes; m38 to m40). Herd groups is #666 on Steve's stack, not in this chain; the old herd groups commit 1528fa6f9 is undone on this branch (consolidation), so no client PR carries server code.
11. **Life layer H, weather looks:** `weather_looks` (shake-off after rain, tail to the wind in gales, cold huddle with heads low, steam breath below 5 C, snow on backs; m41 to m44) and `cover_still` (state 20 in cover held still; m48).
12. **Life layer I, hunting feedback:** `hunt_feedback` (hit reactions by zone, a dragged hind leg after a hip hit, a wounded limp past half health, a death fall along the slope; m45 to m47).
13. **Life layer J, posed birds:** `bird_rig` (wingbeat, glide hold, perch fold and landing flare from the wing bones, for the Meshy eagle, raven, owl and bat; m49 with the crow as a stand-in).
14. **Life layer K, posed swimmers:** `swim_rig` (the whale's and dolphin's tail beat, flipper strokes and porpoise pitch from their spines; m50 with the alligator as a stand-in).
15. **Life layer L, wind direction:** `wind_looks` (rump to wind and rain, deer grazing into the wind, windward fur, breath downwind, birds into the wind; m51).
16. **Life layer M, fog:** `fog_looks` (eye shine sooner and to a third of the visibility, steam into the mist, herds closer; m52).
17. **Life layer N, prevailing wind:** `wind_looks` with Jamie's 57 S wind (from WNW without a direction, feather ruffle, alert animals facing into the wind; m53).
18. **Life layer O, cave air:** `cave_air` (the cave's year-mean air under rock for every weather look, steam by it, coat drying rates from warmth.json; m54).
19. **Life layer P, drinking:** `drink_looks` (sips with the head lifted to look round, a churned bank at used spots, birds bathing; m55).
20. **Life layer Q, ice and snow:** `ice_looks` (careful steps and slips on ice, snow on still backs melting by the air, deeper snow prints; m56).
21. **Life layer R, thunder:** `storm_looks` (birds startle, herds flinch and bunch with ears flat, dogs cower, storm wind tails to it; m57).
22. **Life layer S, pose library:** `pose_lib` (alert, sit, lie, hunch, drink and sleep posed from the rig's own bones where a model has no clip, Steve's state numbers; m58).
