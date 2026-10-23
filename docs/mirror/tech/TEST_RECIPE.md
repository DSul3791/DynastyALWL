# Test recipe for rig and in-game tests (Dave 15:40 and 15:58, 23 Oct; BP-T49)
Applies to MikeW's look rig, Steve's rig steps, any thread's own check.

## Ground test (dirt, drops, piles, rubble, plants)
1. Do the real action: dig with the shovel (look down about 15 degrees, click, step one step, repeat) or drop the item (a real drop, not a placed object).
2. If the thing must lie on the ground, DROP it (dug dirt too), at about 1 m in front of the player, not 2.2 m.
3. Look down: pitch about -45 to -60 degrees so the spot fills the middle of the picture.
4. Step back a very short distance, about 1 m or less (never walk forward past it, never 2.5 m).
5. Take the picture from there (first person, then one third-person from 1.5 m if the item is small).
6. Say before the run what you expect to see ("5 dirt blobs in a small heap in a dug hole, 1 m ahead") and check it after. If it is not there, STOP and report: step, expected, seen, picture, build number. Do not skip ahead.
7. Attach the picture and the one-line result to the report: "pass" or "fail: what".

## Hand and look tests
First person plus a close-up at 1.5 m or less (--dist under 2 aims at the hand). Always give the item count.

## Reporting
Short: "Test done: N pass, N fail" and one line per failure. Anything needing Dave's eyes or feel goes on QA as a TEST card with the attached picture.

# Review of the current rig steps (from tools/look_rig.sh usage and shot_runner flags; Steve to confirm each in code)
Ill-thought-out or missing, owner Steve (rig code), MikeW (runs and reports):
1. **No dig step.** The rig can give and drop but cannot dig, so the floating-soil test could not run. Needed: --dig N (shovel in hand, look down 15 degrees, click, step, repeat N times) then look back at the spot.
2. **Drop distance 2.2 m ahead** (--ground and --drop): too far for small blobs. Change the default to about 1 m, and add --drop-dist.
3. **Default camera pitch 0 (level):** a dropped item at your feet is out of frame. Ground steps must set pitch -45 to -60 and a short step back (about 1 m). Add --look-down with that default for any --ground, --drop or --dig run.
4. **No step back after dropping or digging:** the camera stays at the player's spot, so the item sits under or behind the view. Add --back M (default 1).
5. **No expectation check:** the rig takes pictures but states nothing. Add --expect "text" (written into the report with the picture and the state line), plus a state dump (inventory, position, count of items near the spot) so pass or fail is not by eye only.
6. **Piles:** a drop of 20 stones needs a pile check that the world item exists (count nearby) because the earlier rig run drew nothing (20-stone live drop bug open with Steve).
7. **One shot per 25-37 s startup:** several steps cost several full launches. Allow a step list in one launch (dig, drop, look, back, snap) to save time and to keep the same world state.
8. **Chop:** no chop step. Add --chop (axe in hand, log on the ground, check blocks created) only if Steve judges it cheap; the first goals are dig then drop then pile.
Order: 1, 3, 4, 2 first (the dig-drop-look-back recipe), then 5, then 7, then 6 and 8.

---
# Test plan template (Dave 15:58: "the instructions need to be better planned")
Flow: the OWNER thread drafts a plan from this template, Guru reviews it for steps that hide the thing being checked, only then MikeW runs it. No plan, no run. Plans live in tech/TEST_PLANS/<id>.md (copy below).

```
TEST <id> <name>            build: <n>        owner: <thread>
GOAL        one sentence: what must be true
SETUP       world/spot (x z), items given, time of day, grass hidden?, camera mode
ACTIONS     numbered, in order, one action each (key or rig flag), including DROP, LOOK DOWN (pitch), STEP BACK (metres)
PICTURES    for each picture: when it is taken, camera (first/third, distance, pitch), and what MUST be visible in it
EXPECT      per action: the observable result (counts, text, state line values)
PASS        exact wording: all EXPECT true and every PICTURE shows its MUST-be-visible item
FAIL        wording: first EXPECT that is false, step number, expected vs seen, picture, build number; stop there
```
Guru review checklist: (1) does any step move the camera away from the thing? (2) is the picture taken from within about 1.5 m, looking down for ground items? (3) is every MUST-be-visible item large enough to see (bigger than a few pixels)? (4) does each action have an EXPECT? (5) is it repeatable from the same start? (6) does setup avoid Dave's world (own store, test clone)? (7) is the grass hidden when checking soil or small drops?

# Plans for the queue (drafts by Guru to start owners off; owner confirms details against the rig/code)
## T-DIG (owner Steve; floating soil, build 711+)
GOAL: soil from a dig lies in the hole or on the ground, never in the air.
SETUP: spawn area, flat ground, --nograss, test character with shovel in hand and a full pack (30 slots filled with stone), first person.
ACTIONS: 1 look down 15 degrees. 2 click (dig) once. 3 step forward one step. 4 repeat 2-3 for five digs. 5 stop; look down 45 degrees. 6 step back 1 m. 7 take picture P1. 8 turn 180, step back 1 m more, look down 30, take P2.
PICTURES: P1 the dug line of holes from above-behind; MUST show holes and any soil blobs resting on the ground or in holes. P2 the same line from the far side; MUST show no blob in the air.
EXPECT: after step 2 the pack count did not change (pack full, so the soil drops); the state line lists dropped soil items within 1 m of the dig; none has height above ground over 0.3 m after 3 s.
PASS/FAIL: pass if blobs rest within 0.3 m of the ground and are visible in P1; fail naming the dig number where a blob floats.

## T-DROP (owner Steve, drop plus roll, build 724+)
GOAL: a dropped item lands about 1 m ahead, is visible, and nudges only a little if walked over.
SETUP: flat ground, --nograss, test character holding 1 stone and 1 dirt, first person.
ACTIONS: 1 face north, drop 1 stone (real drop). 2 look down 50 degrees. 3 step back 1 m. 4 picture P1. 5 walk forward over the stone slowly. 6 look back down, step back 1 m, picture P2.
PICTURES: P1 MUST show the stone alone on the ground at the centre. P2 MUST show the stone and its new position.
EXPECT: stone count near the spot is 1 (state line); after the walk it moved less than 0.8 m.
PASS/FAIL: pass if P1 and P2 each show the stone and the move is under 0.8 m.

## T-PILE (owner Steve, rock pile merge, build 715+; open: a 20-stone live drop drew nothing)
GOAL: dropping 20 stones makes one heap that is drawn and merges at the right counts.
SETUP: as T-DROP, give stone:20.
ACTIONS: 1 drop 5 stones one at a time at the same spot (1 m ahead). 2 look down 50, step back 1 m, picture P1. 3 drop 1 more (6 total). 4 picture P2 from the same place. 5 drop 14 more (20 total). 6 picture P3.
PICTURES: P1 MUST show 5 loose stones close together. P2 MUST show one small pyramid heap. P3 MUST show one compact heap bigger than P2.
EXPECT: state line world items near spot: 5 loose, then 1 pile of 6, then 1 pile of 20.
PASS/FAIL: pass if counts and pictures match; the known 20-stone case fails at step 6 if nothing is drawn: report with the state line.

## T-CHOP (owner Sal; log to blocks to firewood, build 705+)
GOAL: a log on the ground chops into 4 wooden blocks (12 from the shoulder log); a block at the chopping block gives 2 firewood.
SETUP: flat ground, --nograss, axe in hand, one log on the ground 1 m ahead, a chopping block placed 2 m to the right, first person.
ACTIONS: 1 look down 40 degrees at the log. 2 chop (click) until the log is gone. 3 look down, step back 1 m, picture P1. 4 pick up one block (E). 5 step to the chopping block, equip the block, use at the block. 6 look down, step back 1 m, picture P2.
PICTURES: P1 MUST show wooden blocks on the ground where the log was. P2 MUST show firewood on or beside the chopping block.
EXPECT: after step 2 four wooden_block world items near the spot; after step 5 firewood count 2 (inventory or ground).
PASS/FAIL: pass if counts match and both pictures show the items.
