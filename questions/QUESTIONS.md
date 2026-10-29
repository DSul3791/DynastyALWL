













## gates-a | Gates A: fast lane and slow lane
Note: Every branch gets the quick checks and the 106 fast tests in parallel (about 2 minutes). The 3 slow tests (worldgen, water soak, head pond) and pictures run only when the branch touches terrain, water or looks, and once a day on the main branch. Today one gate takes 13 to 18 minutes; this makes most take 2 to 5. Full report: design/GATE_AUDIT.md.
Note: Recommendation: Yes
[check]

## gates-b | Gates B: one result per final version, test the merged result
Note: Owners say 'final' once and stop changing a branch in the queue (work in progress goes on a separate branch). The gate runs on the branch merged with the current main branch, so conflicts show before the PASS. Today one branch was re-tested 5 times and 4 of 18 merges hit conflicts the gate could not see. Full report: design/GATE_AUDIT.md.
Note: Recommendation: Yes
[check]

## gates-c | Gates C: batch small branches, fewer builds
Note: When 3 or more small branches are ready they go into one test run and one build every 1 to 2 hours; if it fails we split them. You pull once instead of 18 times a day. Full report: design/GATE_AUDIT.md.
Note: Recommendation: Yes
[check]

## gates-d | Gates D: timing tests retry once; Mike's PC for Windows-only jobs
Note: Tests that flake under load (animals, npcs, bed) run alone at the end with one automatic retry. Mike's PC keeps first start, feel, play and Windows pictures, plus overflow gates; data-only branches go through the box fast lane. Full report: design/GATE_AUDIT.md.
Note: Recommendation: Yes
[check]

## gates-e | Gates E: ship script and less noise
Note: Tyler gets a script that does merge, checks, build number, logs, push and verify in about 1 minute instead of 5 and cannot silently fail. Drop the duplicate number sweeps and the item master warning from gate output. Keeps QA card before merge and the CI guard. Full report: design/GATE_AUDIT.md.
Note: Recommendation: Yes
[check]

## gates-f | Gates F: warm test folders instead of a fresh import each gate
Note: Each gate starts in a new folder, so Godot imports everything again: 2 to 5 minutes of a 15 minute gate. Keep a few warm folders and just switch them to the hash being tested; once a week one run in a fresh folder to prove the results match. Full report: design/GATE_AUDIT.md section 8.
Note: Recommendation: Yes
[check]
