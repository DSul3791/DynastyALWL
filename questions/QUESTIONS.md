## rv-lfs | Tile files in git (BP-C108): all server runs, flight checks and edge-matching run on your PC (your rule), so cloud threads never need tiles. Tiles stay in git as backup and history. Is any extra step needed?
The repo is only 142 MB with tiles committed once. Git LFS (a "locker" with a free 10 GiB cap) is not needed.
- Keep tiles in git as backup, cloud threads simply never use them (recommended)
- Use LFS anyway
- Take tiles out of git and keep them only on your PC
- Decide later
