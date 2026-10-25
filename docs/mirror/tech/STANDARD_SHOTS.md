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
