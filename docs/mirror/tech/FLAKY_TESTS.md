# Flaky tests (BP-T82). Data from David3, 25 Oct 2026
| test | symptom | alone | owner | status |
|---|---|---|---|---|
| test_animals | timing limit 2 ms exceeded under load (2.5, 3.8, 3.4 ms), 3 times | 0 failures each time | Steve | serial lane, one logged retry |
| test_npcs | timing limit 1 ms exceeded (1.4 ms) once | 0.46 ms | Steve | serial lane, one logged retry |
| test_bed | 2 flakes in full runs; hardened in 9da17707 (look the bed up afresh) | 0 failures | Steve | serial lane, one logged retry until Steve's 20-run flake finder is clean |
| test_fish_schools | steady 1.75 ms against a 1 ms limit until Steve changed lookups | fixed | Steve | normal lane |
| test_slot_sounds | more than 5 minutes alone | n/a | Steve | slow lane |
Rule: add a row when a test fails once in a full run and passes alone. Steve's flake finder (each timing test 20 times under 6-way load) replaces these anecdotes with numbers.
