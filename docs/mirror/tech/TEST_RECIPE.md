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
