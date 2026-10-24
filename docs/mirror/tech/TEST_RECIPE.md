# Test recipe (rewritten 23 Oct 23:25 UTC after Dave: "Mike is very inefficient at testing ... one labelled row, one picture, bang done ... dig tests that seem to do nothing ... simple, straightforward and groupable")
Applies to MikeW, Steve's rig, every thread asking for a test. Old long version: tech/TEST_RECIPE_ARCHIVE_2026-10-23.md (ground-test detail still valid there).

## The five rules
1. **One row, one picture.** Everything of one KIND that Dave or the team must look at goes in ONE labelled row at one place (like the items row: spawn showroom, Esc > Admin, or rig `--flora a,b,c,d,e`), all the same size/scale, labels under each. One picture of the whole row (plus ONE close-up view if detail matters, via `--views`). Never one picture per bush, shovel or herb. Cards crop frames out of that one picture.
2. **Groupable or it is not requested.** A test request is accepted only if it can run in the same engine start as the others: same rig, same world, no setup unique to it. Anything that needs its own start joins the nightly list, not the hourly batch.
3. **A test must be able to FAIL.** Every step ends in a number or a yes/no read from the state line or a count (items near spot, inventory, height above ground, build number), not "looks fine". A step that cannot fail (a dig with nothing measured) is deleted.
4. **One pass/fail line per test**, in the report: `T-xxx PASS` or `T-xxx FAIL step N: expected X, saw Y (picture file, build)`. Report format for the whole batch: `Test done: 7 pass, 1 fail` then the failing lines only.
5. **One request per hour, one run.** All threads' needs go in one list; Mike runs them in one launch sequence, closes the game, reports once. Never one start per picture; never in parallel with Dave playing.

## Row kinds (one picture each)
- PLANTS: `look_rig.sh --flora raspberry,bramble,wild_rose,blackthorn,blueberry,nettle,... --views "wide:8:-8:1.5;close:4:-15:1.0" --nograss` (fruit season set by the item, flowers off-season as a second row only if the season rule is under test).
- ITEMS/TOOLS: the spawn showroom rows (data/items/showroom.json), one row per category (shovels, axes, hoes, ...), first person picture along the row.
- ALWAYS PLAYABLE (smoke): `look_rig.sh --frametime 20 --quality 0` (F2 Low, 20 s after warm-up): ONE line "shot runner: frametime ... p95 .. ms (OK/FAIL over 33 ms)". Mike reports that one number per build.
- BUILD PIECES: `look_rig.sh --pieces foundation_section,wall_section,doorway_section,window_section,door_open,floor_section,roof_section --views "wide:9:-8:1.5;close:4:-10:1.2"` (names = data/items/structures.json keys; built by the game's own ghost_model; spacing from sizes; `--pieces-yaw 180` shows the backs; the "shot runner: piece" lines give each size, FAIL empty = draws nothing).
- GROUND BEHAVIOUR (dig, drop, pile, chop): ONE script T-GROUND below, not four tests.
- LOOKS BEFORE/AFTER: same row, same camera, two pictures from two builds in one image pair.

## T-GROUND (replaces T-DIG, T-DROP, T-PILE; one start, three lines)
Setup: flat spot, `--nograss`, shovel in hand, stone:25, dirt count 0, first person. Camera: pitch -50, 1 m back from the spot after each action.
1. DIG x3 (look down 15, click, step): measure from the state line, then PASS only if dirt blobs/held dirt exist and every dropped soil item is within 0.3 m of the ground after 3 s. (T-DIG)
2. DROP 1 stone: PASS only if count near spot = 1 and it lies 0.8-1.2 m ahead. (T-DROP)
3. DROP 5, +1, +14 stones at the same spot: PASS only if counts read 5 loose, then 1 pile of 6, then 1 pile of 20. (T-PILE)
ONE picture after step 3 from above-behind showing hole line and pile; the step lines carry the verdict. If a state line cannot give the number, the test is not ready: Steve adds the number, no run.
Deleted as proving nothing: stand-alone "dig then look" runs with no measure, repeat digs at several spots, per-item drop pictures, the old step-by-step T-DIG (5 digs, picture only).
T-CHOP (Sal) stays separate but joins the same batch: log -> 4 blocks count, block at chopping block -> 2 firewood count, one picture.

## Request template (every thread uses this; copy into the batch list)
```
REQUEST <thread> <date>   build/branch: <x>   label: RUNTIME|RESTART|BAKE
KIND     plants-row | items-row | pieces-row | ground | ui | sound-ear
LIST     the items in the ROW, comma separated (one picture)  /  the T-id to run
PASS IF  one measurable line per item (count, height, text, visible in picture)
VIEWS    default wide + close (only add views you need)
NEEDS    anything not in the rig (otherwise empty; if non-empty, ask Steve first)
```
Tyler/coordinator merge all REQUESTs into one batch file, one run, one report. A request missing PASS IF is sent back before it reaches Mike.

## Ground detail kept from the old recipe
Look down 45-60 degrees; step back 1 m or less; drop real items 1 m ahead; state the expectation before the run; if a step fails, stop and report step, expected, seen, picture, build.
