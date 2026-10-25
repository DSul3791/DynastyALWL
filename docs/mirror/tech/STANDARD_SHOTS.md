# LOOK REVIEW LOOP and standard shots (Dave 25 Oct 00:16: Kathleen reviews what David3 tests so she can make it look more realistic)
Owner of the loop: Tyler (spec, gate, daily handoff). Pictures: David3. Review: Kathleen. Starts with the 792 test run.

## The loop (every build)
1. **David3 takes the standard set automatically** as part of the build test (job `shots`, after the tests pass; a picture failure never fails the build gate, it is reported). Same spots, same camera, same times of day, every build, so pictures can be compared build to build.
2. **Publish + index** to claude/box-results: results/<build>/<shot_id>.jpg plus one line each in results/PICTURES_INDEX.md: build number, commit id, shot id, place (x z), time of day, renderer (nvidia/lavapipe), date. A short README in the build folder lists what changed in the build.
3. **Kathleen reviews each batch** and writes art/CRITIQUES/<build>.md: per picture one line: what looks wrong or flat, why (material, lighting, scale, repetition, colour), severity (1 minor, 2 noticeable, 3 breaks the look), a suggestion, and the owner (Kathleen, Steve, Sal, Sonny).
4. **Critiques become tasks**: each severity 2-3 line is posted to the coordinator once as a task (owner, branch, pictures to compare); the next batch must show before/after of the fixed ones. Kathleen's roadmap is art/PHOTOREAL_ROADMAP.md and PHOTOREAL_RESEARCH_24OCT.md (first step: terrain material pass).
5. **Daily handoff:** the 20:00 ADT handoff lists last review date, open critiques by owner, and the three worst pictures.

## STANDARD SET v1 (8 shots, fixed; extend only by a line here)
| id | Place | Time | What it shows |
|---|---|---|---|
| S01_spawn | spawn pad x53301 z68427 (or the new pin once the bake lands), eye height, facing the sea | noon | ground, grass, first impression |
| S02_spawn_dusk | same | dusk | light, shadows, fog |
| S03_river | one river reach with bank and gravel (coordinates in the shot file) | noon | water, banks, flow, wet edge |
| S04_forest | one broadleaf forest interior | noon | trees, ground cover, light shafts |
| S05_conifer | one foothills conifer stand | morning | needles, rock, snow line if any |
| S06_meadow | farmland slope (valley under 10 degrees) | noon | grass, flowers, repetition |
| S07_shelter | thatch shelter built (scripted placement) with a fire lit | dusk | pieces, fire light, interior |
| S08_hands | held tools hand view (hammer, axe, torch, net) | noon | held items, arms |
Optional per build: S09_coast, S10_cave mouth, S11_aerial island. Frame: 1920x1080, jpg quality 85, depth of field off, UI off, fixed seeds for random scatter.
Budget: one server start per batch (not per shot), about 25 to 40 min on the 1050 Ti box, run after the build tests; a quick set (S01, S03, S04, S07) of about 12 min runs on every merge candidate.

## Who does what / when
- David3: add the `shots` job and shot file (tools/docker/shots.txt with coordinates), publish script, index line format. Build: first complete batch with the 792 run (spawn and hands first: S01, S02, S08).
- Kathleen: first review of the 792 batch and the first critiques file; also the before/after for the terrain material pass.
- Tyler: keeps this spec, adds the line to the daily handoff, checks at every merge that the batch exists and the index line is there (BP-T68).
- Coordinator: relays critiques to owners, one task each.
