## rv-lfs | Tile files in git (BP-C108): the whole repo is only 142 MB and tiles were committed once, so is Git LFS worth the bother now? Tiles are made on your PC; the cloud gets them from git only when it needs a server run or test.
Git LFS is a "locker" for big files; GitHub's free locker has 10 GiB of space and 10 GiB of downloads a month, and stops working for the month if exceeded.
- Keep tiles in git as now, look again after 3 more bakes or at 500 MB (recommended)
- Use LFS now, forward-only, cloud skips downloading tiles
- Take tiles out of git and copy them by hand
- Decide later
