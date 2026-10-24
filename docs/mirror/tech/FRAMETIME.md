# Frame times per build (Mike appends one row per build; Steve reads it as the engine-health number)
Run: `tools/look_rig.sh --frametime 20 --quality 0` (also `--quality 1`, `2`, `3` once a day). Pass line applies to Low: p95 under 33 ms and no frame over 100 ms. WARN when p99 is over 50 ms. A rise of more than 10 percent versus the last build is a named regression, sent to the owner of the newest merge.

| build / commit | tier | avg ms | p95 | p99 | max | over 50 ms | over 100 ms | machine (GPU, driver, window) | verdict |
|---|---|---|---|---|---|---|---|---|---|
