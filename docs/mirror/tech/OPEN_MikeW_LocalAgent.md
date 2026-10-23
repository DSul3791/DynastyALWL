# Open items: MikeW_LocalAgent (BP-T30). Updated 2026-10-22 17:25.

| # | Opened | Item (what) | Why / source | Next step | Pri | Status |
|---|---|---|---|---|---|---|
| 1 | 10-22 | Nightly backup on "goodnight" (tools/nightly_backup.py), cull DRY-RUN for 14 nights | BP-C110 | Run after Dave's pull test and Tyler's go; report one line | P2 | OPEN (night 0 done 10-22 12:46: 1,544 MB, 2 min 22 s) |
| 2 | 10-22 | Local check on the final head when Tyler says it is final | wrap-up 10-23 | Run local_check + headless load, one line | P1 | OPEN |
| 3 | 10-22 | 2-tile bake timing with --threads=4 in the test clone | Dave standing OK, coordinator | Next free window; game closed, never committed | P3 | OPEN (1-tile done: setup 79 s, tile 188 s) |
| 4 | 10-22 | First timing of the 882 tests and Python checks on Windows | CONCERNS_RESOLUTIONS | Run when Dave is not playing | P3 | OPEN |
| 5 | 10-22 | BAKE-1 test bakes from TEST_QUEUE lines, 2 h apart | BP-T31 | Wait for a BAKE-1 line | P3 | OPEN |

DONE 10-22: local_check.sh, godot shim, bake guard, look-runtime exemption (all merged); renders for looks v1 to v6, foods, creatures, materials, chopping block; checks of builds 647 to 688.

## Noticed but not done
- Headless runs cannot test hoe smoothing, spade Raise, collapse warning visuals, ladder feel or sounds: sent to Tyler as test lines.
- `addons/water_core/bin/~libwatercore...dll` shows as deleted in Dave's folder (temp file, never commit).

## Asked of others
- none open
