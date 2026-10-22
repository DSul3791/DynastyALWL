## rv-lfs | Git LFS for the tile files: GitHub's free plan gives 10 GiB storage and 10 GiB bandwidth a month, and LFS stops working for the month if exceeded. Tiles are about 81 MB, so storage is fine, but repeated cloud pulls could use the bandwidth. How do we go ahead? BP-C108.
- Go ahead, forward-only, cloud threads skip downloading tiles (recommended)
- Skip LFS, keep tiles out of git with a download step
- Keep tiles in git as now
- Decide later
