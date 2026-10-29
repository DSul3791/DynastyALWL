# Review: Sonny (World: ground, water, tunnels), 2026-10-22

## Keep
- One owner per area plus frozen-until-bake: runtime fixes (608, 623, 628) shipped, no bake churn.
- TEST_QUEUE and one grouped card: I stopped asking Dave for single tests and kept working.
- BP-C23 (never commit .tile): I did scratch bakes in scratchpad and saved a patch instead.
- Short reports ending "Still waiting on": the coordinator routes in one read.
- Merged World thread: pond and brown-square reports bounced ground to water to ground before.

## Change
1. Diagnosis scripts (tile map, spring list, dry sim) live only in my scratchpad and die with the container. Fix: a probes folder in the repo, one command each. Saves about 1 h and 30k tokens per report (guess).
2. Heavy gates (882 tests, edge match, 2 scratch bakes) cost me 10+ min each in cloud. Fix: MikeW runs them from a command list I write once. Saves cloud time and my tokens (guess 20k per gate).
3. Held work is lost when the container is reclaimed. Fix: BP entry "save a patch to /mnt/project-files/handoff/ as soon as it works" (I did, by luck).
4. Hillshade review was Willy's, who is retired. Fix: name the reviewer (Kathleen for look, Technical Director for sign-off).
5. Reading 27 KB of BP plus 39 KB appendix each day. Fix: an "A-world" digest of about 15 lines (A3, A4, A9, A11). Saves about 12k tokens per day per thread (guess).

## Missing
- Water flow-share measure (west vs south chute). Sea inflow is meaningless (everything ends in the sea). Job: build a flux probe (Manning estimate or dam test). Needs an entry for how to validate flow splits.
- A rule for scratch bakes: cloud bake differs from Dave's committed tile (hash 61ceab vs 436799), so gates compare cloud before/after only.

## Conflicts
- RULE 3 (heavy runs on Dave's PC) vs BP-C80 (about 6 min worldgen suite "in cloud"): say which wins; I follow RULE 3.
- "Frozen worldgen files" vs gate list that needs me to edit tile_water.gd on a held branch: fine, but say held branches are allowed.

## My area
Ground and water share a verification gap: no automated "does the pond fill and spill out its own outlet" test. I verified by hand with a 4 h dry sim. Recommend a headless test (test_head_pond_fill.gd): spring lands in the highest pond, pond reaches 90 percent in N sim seconds, no spill over a non-outlet rim. This would have caught the 623 bug before Dave did.

## Token moves
- Cut handoff to one page plus the patch file; link, do not repeat findings.
- Post probe output lines, not prose, in reports.
- Stop re-reading screenshots: ask for HUD build and one coordinate.
- Skip moderator replies when parked on a card.

## Verdict
Process good for now, with the gate and probe changes above.
