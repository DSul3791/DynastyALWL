# Bake 28 (island foothills/canyons/volcano) merge plan (Tyler, 24 Oct 03:20 UTC)
Code: origin/claude/sonny-foothills (b05415dc, TERRAIN_VERSION 28, flora layout VERSION 3). Trial-merged on head 773: clean, merge_check clear, parse_scan 0 problems on 362 files.
Order of work:
1. Mike bakes 9 tiles in the SECOND clone from sonny-foothills (Sonny's one-tile test bake picture/table first if not done), settles water, commits tiles + .water on claude/mike-bake-v28 and pushes (BP-T53). Never into Dave's folder.
2. Gate before I merge (my GO conditions): Sal's island_checks table printed and ALL rows PASS (spawn gate, walkability, rivers to the sea, 9-border seam, relief/peaks). A FAIL row blocks the merge and goes back to Sonny with the numbers.
3. I merge sonny-foothills + mike-bake-v28 as ONE build (775 or next free), plus steve-river-settle (rebased) only if its .water files are in the same bake commit; otherwise the settle runs after.
4. Standard checks on the merged head: merge_check, parse_scan, local_check 233 (Mike on the second clone), tile count 9 + water files 9.
Dave's pull steps (post when the build is ready):
1. Close the game fully.
2. GitHub Desktop: Fetch origin, then Pull.
3. Start the game.
4. Esc > Admin > Reset all terrain edits.
5. Esc > Admin > Clear blocks (reload from the server).
6. Walk from spawn and look around; tell me what you see. Note: the ground has changed, so buildings, digs and pieces from earlier tests will not match the new terrain (test world).
