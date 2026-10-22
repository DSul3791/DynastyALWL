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
