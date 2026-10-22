## rv-big-files | Three code files are huge (server_items 5,000 lines, inventory_view 3,800, terrain_client 5,200), so every edit costs a lot of reading. Split them? Research: the context window is the scarce resource. BP-C03.
Done one file at a time as a Systems job, with the existing tests as the safety net. This is a big fix.
- Yes, one at a time, after restart (recommended)
- Only add the rule "new logic goes in new files"
- Keep as is
- Decide later

## rv-local-first | Run every build, test and warning check on your PC by default through one command (tools/local_check.sh), cloud threads only edit and review? Research: a check the agent can run is the best quality lever. BP-C83, BP-C80.
- Yes (recommended)
- Only warnings and long tests
- Keep as is (cloud for small runs)
- Decide later

## rv-warning-baseline | Commit the current warning list (233) as a baseline file so reports show only NEW warnings? BP-C01.
- Yes (recommended)
- Keep as is
- Decide later

## rv-bp-digest | Everyone reads the 80-entry best practices every day (costly; research says long instruction files get ignored). Replace with a 15-line digest per role plus the changelog lines? BP-T25.
- Yes, role digests (recommended)
- Keep reading the whole document
- Decide later

## rv-shared-files | Threads need one-line changes in other threads' files (piece looks, sounds, client wiring). Allow one-line data hooks in another thread's file if announced in BUILD_LOG? BP-C10, BP-T22.
- Yes (recommended)
- No, always ask the owner first
- Decide later

## rv-waiting-line | Your rule: every post ends "Still waiting on:". Threads often have nothing to wait for. Keep it always (writing "nothing") or only when something is pending? BP-T10.
- Only when something is pending (recommended)
- Always, even "nothing"
- Decide later

## rv-lfs | Git LFS for the tile files: GitHub's free plan gives 10 GiB storage and 10 GiB bandwidth a month, and LFS stops working for the month if exceeded. Tiles are about 81 MB, so storage is fine, but repeated cloud pulls could use the bandwidth. How do we go ahead? BP-C108.
- Go ahead, forward-only, cloud threads skip downloading tiles (recommended)
- Skip LFS, keep tiles out of git with a download step
- Keep tiles in git as now
- Decide later
