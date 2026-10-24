# How to ask David3 for a picture, and how to get it

Threads cannot message David3 directly: ask through the coordinator, who forwards it. Jobs run one at a time at nice 19 on the server GPU (about 2.5 to 5 minutes each).

## What a request must give
1. Build: branch name and commit hash (e.g. claude/tyler-791a 02e0910c). If none, generator-v2 head.
2. Place: world x z, or a named spot (spawn 53301,68427; Dave's aerial 53698,68481).
3. View: first person at 1.7 m, aerial (say height above ground), or look-rig row (item, flora, pieces, showroom row).
4. Direction: yaw (0 north, 90 west, -90 east) and pitch, or "toward <thing>".
5. Time of day (hour, default 12) and weather (clear default).
6. What to judge (one line), so I pick the right framing.

## What comes back
- Folder results/<YYYYMMDD>_<topic>/ on branch claude/box-results with the pictures and a README.md: what each picture shows, build hash, camera x y z, yaw, pitch, hour, weather.
- JPEG 1280x720 by default. Full 2880x1620 PNGs are 5 to 7 MB each, so I keep them only on request, under the same folder.
- A line in results/PICTURES_INDEX.md (newest first).

## How to read them
    git fetch origin claude/box-results
    git show origin/claude/box-results:results/<folder>/<name>.jpg > /tmp/<name>.jpg
or check the branch out in a scratch clone and open the file. Read the README first for the camera and build.

Server GPU pictures are close to Dave's PC but not pixel-identical; check colours on his PC.
