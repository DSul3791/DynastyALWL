# LOOK REVIEW LOOP and standard shots (Dave 25 Oct 00:16: Kathleen reviews what David3 tests so she can make it look more realistic)
Owner of the loop: Tyler (spec, gate, daily handoff). Pictures: David3. Review: Kathleen. Starts with the 792 test run.

## The loop (every build)
1. **David3 takes the standard set automatically** as part of the build test (job `shots`, after the tests pass; a picture failure never fails the build gate, it is reported). Same spots, same camera, same times of day, every build, so pictures can be compared build to build.
2. **Publish + index** to claude/box-results: results/<build>/<shot_id>.jpg plus one line each in results/PICTURES_INDEX.md: build number, commit id, shot id, place (x z), time of day, renderer (nvidia/lavapipe), date. A short README in the build folder lists what changed in the build.
3. **Kathleen reviews each batch** and writes art/CRITIQUES/<build>.md: per picture one line: what looks wrong or flat, why (material, lighting, scale, repetition, colour), severity (1 minor, 2 noticeable, 3 breaks the look), a suggestion, and the owner (Kathleen, Steve, Sal, Sonny).
4. **Critiques become tasks**: each severity 2-3 line is posted to the coordinator once as a task (owner, branch, pictures to compare); the next batch must show before/after of the fixed ones. Kathleen's roadmap is art/PHOTOREAL_ROADMAP.md and PHOTOREAL_RESEARCH_24OCT.md (first step: terrain material pass).
5. **Daily handoff:** the 20:00 ADT handoff lists last review date, open critiques by owner, and the three worst pictures.

## STANDARD SET v2 (Kathleen's set, 25 Oct 00:17; replaces v1). JPEG 1280x720, UI off, depth of field off, fixed scatter seeds
README per batch: build number, commit id, hash, hour, weather, renderer, and the FRAME TIME in ms from the probe for every shot. Same spots and framing every build so before/after compares cleanly; coordinates live in tools/docker/shots.txt (David3 writes them from Kathleen's spots; any change to a spot = a new line in this file).
| id | Shot | Camera | Time |
|---|---|---|---|
| K01 | spawn meadow, looking east | eye 1.7 m | noon |
| K02 | spawn meadow, looking west | eye 1.7 m | noon |
| K03 | spawn meadow, east | eye 1.7 m | dusk |
| K04 | spawn meadow, west | eye 1.7 m | dusk |
| K05 | ground close-up, stone + stick + plant centred | 0.35 m, pitch -45 | sun |
| K06 | same, in shade | 0.35 m, pitch -45 | shade |
| K07 | conifer stand, one tree | 2 m from the tree | noon |
| K08 | shrub and fern | 1.5 m | noon |
| K09 | autumn forest aerial over the bowl | ~130 m up | noon |
| K10 | forest edge, eye-height view | 1.7 m | noon |
| K11 | river bank | 1.7 m | noon |
| K12 | pond edge | 1.7 m | noon |
| K13-K18 | held tools first person against plain sky: axe, pickaxe, hoe, spade, knife, spear | first person | noon |
| K19-K21 | one placed piece each: wall, bed, hearth | 3 m | noon |
Optional per build (my v1 extras, not required): shelter with a lit fire at dusk, coast, cave mouth, island aerial.
Budget: 21 shots in one server start: about 40 to 60 minutes on the 1050 Ti box. A QUICK SET of 6 runs on every merge candidate (K01, K03, K05, K07, K11, K13); the FULL set runs once per merged build and nightly. Pieces K19-K21 need the 792 content (wall, bed, hearth), so until 792 lands they are skipped and marked "n/a" in the README.

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

## Wait time in tools/docker/shot.sh (Dave wants faster tests)
Decision: FOLLOW David3's shorter wait (120 s to 60 s and 30 s to its new value), committed to the repo's shot.sh so repo and box agree. Condition: the fixed time is only a MAXIMUM. The script polls the client log for the ground-ready line (HUD "ground vNN" known, watchdog quiet) and shoots as soon as it appears; if not ready at the maximum it shoots anyway and marks the picture "ground not ready" in the README so Kathleen does not critique an unloaded view. The earlier thin dark sheet in the bowl render happened at long waits, so waiting longer is not the cure; the ready line is.
