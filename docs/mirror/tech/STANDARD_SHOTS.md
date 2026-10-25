# LOOK REVIEW LOOP and standard shots (Dave 25 Oct 00:16: Kathleen reviews what David3 tests so she can make it look more realistic)
Owner of the loop: Tyler (spec, gate, daily handoff). Pictures: David3. Review: Kathleen. Starts with the 792 test run.

## The loop (every build)
1. **David3 takes the standard set automatically** as part of the build test (job `shots`, after the tests pass; a picture failure never fails the build gate, it is reported). Same spots, same camera, same times of day, every build, so pictures can be compared build to build.
2. **Publish + index** to claude/box-results: results/<build>/<shot_id>.jpg plus one line each in results/PICTURES_INDEX.md: build number, commit id, shot id, place (x z), time of day, renderer (nvidia/lavapipe), date. A short README in the build folder lists what changed in the build.
3. **Kathleen reviews each batch** and writes art/CRITIQUES/<build>.md: per picture one line: what looks wrong or flat, why (material, lighting, scale, repetition, colour), severity (1 minor, 2 noticeable, 3 breaks the look), a suggestion, and the owner (Kathleen, Steve, Sal, Sonny).
4. **Critiques become tasks**: each severity 2-3 line is posted to the coordinator once as a task (owner, branch, pictures to compare); the next batch must show before/after of the fixed ones. Kathleen's roadmap is art/PHOTOREAL_ROADMAP.md and PHOTOREAL_RESEARCH_24OCT.md (first step: terrain material pass).
5. **Daily handoff:** the 20:00 ADT handoff lists last review date, open critiques by owner, and the three worst pictures.

## STANDARD SET v3 (Dave 25 Oct 01:26: "only take 3 shots and rotate left 90 degrees after each shot")
Unit = a SPOT (position, height, hour, weather). Each spot gets THREE pictures: view a at the spot's start yaw, view b after turning LEFT 90 degrees, view c after turning left another 90 (yaw, yaw+90, yaw+180; left = counter-clockwise seen from above, +90 in Godot rotation.y; David3 checks on the first batch that b shows what was left of a). JPEG 1280x720, UI off, depth of field off, fixed scatter seeds. Ids: K01a, K01b, K01c, K02a ...
**Two kinds of spot (Dave 25 Oct 01:42: turning the body also turns the camera with the character, so a shot of the character got the same view every time):**
- **PANORAMA spot** (first person, look outward): the view turns in place left 90 degrees after each shot. K01, K02, K07, K08, K09, K10.
- **SUBJECT spot** (the picture is of a thing: a tree, shrub, ground items, a placed piece, or the character in third person): the thing stays put and the CAMERA ORBITS it, 90 degrees around per shot at the same distance and height, always looking at the subject (a, b = 90 degrees, c = 180 degrees around). K03, K04, K05, K06, K11, K12, K13, and any third-person shot of the character. Turning the body is never used for these: it would swing the view away from the subject, or (third person) turn the camera with the character.
- **Tools K14 to K19:** one picture each, first person, no turn.

Kathleen reads a spot's three pictures together as one place ("front, left, behind-left") and writes ONE critique line per spot, naming the view letters; she may add a line for one view.
| spot | Where | Camera | Time | Start yaw |
|---|---|---|---|---|
| K01 | spawn meadow | eye 1.7 m | noon | east (a=E, b=N, c=W) |
| K02 | spawn meadow | eye 1.7 m | dusk | east |
| K03 | ground close-up, stone + stick + plant centred (SUBJECT: orbit) | 0.35 m, pitch -45 | sun | east |
| K04 | same, in shade | 0.35 m, pitch -45 | shade | east |
| K05 | conifer stand, 2 m from one tree | eye 1.7 m | noon | toward the tree |
| K06 | shrub and fern | 1.5 m | noon | toward the shrub |
| K07 | autumn forest aerial over the bowl | ~130 m up | noon | east |
| K08 | forest edge | eye 1.7 m | noon | into the forest |
| K09 | river bank | eye 1.7 m | noon | across the river |
| K10 | pond edge | eye 1.7 m | noon | across the pond |
| K11 | wall piece (placed) | 3 m | noon | at the piece |
| K12 | bed (placed) | 3 m | noon | at the piece |
| K13 | hearth (placed) | 3 m | noon | at the piece |
| K14-K19 | held tools first person against plain sky: axe, pickaxe, hoe, spade, knife, spear | first person | noon | ONE picture each, no rotation (the view is the hand) |
Total full set: 13 spots x 3 = 39 pictures + 6 tools = 45. Spots K11-K13 need the 792 content: until it lands they are skipped ("n/a" in README).
Optional per build: shelter with a lit fire at dusk, coast, cave mouth, island aerial (each 3 views).
QUICK SET on every merge candidate: K01, K03, K05, K09 (12 pictures) + K14 (1) = 13 pictures.
TIME ESTIMATE (replaces the old 40 to 60 min): per spot one teleport + ground ready + 10 s, then three shots with two 90 degree turns and about 2 s render settle after each turn, so a spot costs only about 20 s more than the single shot did; full set 19 positions (13 spots + 6 tools) = about 30 to 50 minutes on the 1050 Ti box (measured value to be printed in the first README); quick set about 10 to 14 minutes. One server start per batch.
shots.txt columns: id, view_count (3, or 1 for tools), x, z, eye_or_alt, yaw_deg (start), pitch_deg, hour, weather. Turn rule is in the script, not in the file.
Duplicate rule (above) applies per picture across the whole batch: the three views of one spot must differ from each other too (yaw read-back differs by 90 degrees between views, else the batch fails).

## Who does what / when
- David3: add the `shots` job and shot file (tools/docker/shots.txt with coordinates), publish script, index line format. Build: first complete batch with the 792 run (spawn and hands first: S01, S02, S08).
- Kathleen: first review of the 792 batch and the first critiques file; also the before/after for the terrain material pass.
- Tyler: keeps this spec, adds the line to the daily handoff, checks at every merge that the batch exists and the index line is there (BP-T68).
- Coordinator: relays critiques to owners, one task each.

## RULES FOR EVERY SHOT (Dave 25 Oct 01:22: "he is shooting pictures but he isn't rotating the camera, so they are all the same picture")
1. **Each shot sets its OWN pose**: position (x, y or eye height, z) AND yaw AND pitch, written per row in tools/docker/shots.txt (columns: id, x, z, eye_or_alt, yaw_deg, pitch_deg, hour, weather). A shot without its own yaw/pitch is a script error, not a default. The README prints the pose actually used (read back from the game, not from the file) for every picture.
2. **Duplicate check fails the batch.** After the batch, compute a checksum of every JPEG (and a small-thumbnail perceptual hash, 16x16 greyscale) and compare all pairs: any two identical checksums fail the batch; two pictures with a perceptual difference under 2 percent also fail it, EXCEPT the pairs that are meant to differ only by time of day or shade (K01 vs K03, K02 vs K04, K05 vs K06), which must still differ by at least 5 percent mean brightness. The result line prints "pictures: N of N, duplicates: 0".
3. **Camera must have settled**: each shot waits for the pose read-back to match the requested pose (within 0.05 m, 0.5 degrees) before capture, with a maximum wait; a mismatch is reported, never silently shot.
4. **Failure policy**: duplicates or pose mismatches fail the PICTURE batch (reported as a problem on the test result) but not the build gate (BP-T68 unchanged), and the batch is not indexed as reviewed for Kathleen until it passes.

## Wait time (Dave 25 Oct 01:24: "just wait for the ground and then 10 seconds") - replaces the earlier wait policy
Rule for every picture script (David3's box script tools/docker/shot.sh and its batch runner, Mike's look_rig.sh): shoot 10 SECONDS after the camera has LANDED: ground ready (waiting_for_ground == false) AND the camera at ground + eye height within 0.5 m of the requested height (one number everywhere: 0.5 m) (read back; a first "ground under" line is not enough: one short-wait picture was taken at 64.7 m). If it never lands within the maximum, the picture is marked FAILED (not just "ground not ready") and the batch reports it. Nothing else is a fixed wait.
- shot.sh values: SETTLE=10 (seconds after ground ready), WAIT = maximum time to wait for ground ready (60; raise per run only with a reason in the README).
- If ground is not ready at WAIT, shoot anyway and mark the picture "ground not ready" in the README (Kathleen does not critique it, and the duplicate check treats it as a problem).
- The server start: replace the fixed `sleep 30` in shot.sh by polling the server log for its listening line (maximum 30 s), so a fast start saves time.
- Check that --shot-wait is the maximum for ground and --shot-settle is the extra seconds after it in the client (David3 reads src/ for the flags and states the semantics in the README of the script); if the client counts the settle from the start instead of from ground ready, fix the client side in the same change (client flag only, RUNTIME).
- Poses and duplicate rules above still apply. Log the measured time per shot so we see the saving.
