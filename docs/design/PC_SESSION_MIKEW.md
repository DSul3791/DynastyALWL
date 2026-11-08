# PC session run sheet: the animal life layer (MikeW, 8 Nov 2026)

For whoever runs it on Dave's PC (MikeW or Dino), word for word. About 35 minutes. Every command runs from `C:/GodotProjects/DynastyALWL_gate` in Git Bash. `GE` is the editor; `O` is the picture folder.

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

## 4. Moving frames (12 min)
Each line makes one strip of 6 frames.
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
grep -h "saved\|SCRIPT" $O/m*.log
```
Pass, per strip, by eye: the tail or ears move between frames; sleeping animals lie (deer, dog) or stand head-low (horse) and `asleep true` in the log; the deer herd faces roughly one way and `look_left` above 0 on more than one frame as the camera nears; the beaver and moose show `wet` near 1; eyes glow in the night strip (deer pale green, wolf yellow-green); the rabbit and kangaroo rise and land; the black bear's head is low with the jaw open; brown puffs at the running hooves.

## 5. Gates (15 min, in order)
```bash
for b in eyeshine wet-look eye-placement; do
  h=$(git rev-parse origin/claude/mikew-$b)
  bash tools/gate_pc.sh $h --lane fast 2>&1 | grep -E "CONFLICT|FAIL|warnings|LOCAL CHECK|Test done|NEW fail|CHECKS:"
done
```
Pass: `CHECKS: pass` for each. On a `CONFLICT`, main has moved: merge `origin/main` into that branch first (MikeW).

## 6. PRs, in this order, only after their gate passed
1. Eye shine (`claude/mikew-eyeshine`, already open as #596: `gh pr ready 596`).
2. Wet look (`claude/mikew-wet-look`, new PR).
3. Animal life layer (`claude/mikew-eye-placement`: eye placement, dog clips, tails, ears, breathing, head tracking, posed states, hop, sleep, herds; new PR).

Send each head to the coordinator after the push prints it.
