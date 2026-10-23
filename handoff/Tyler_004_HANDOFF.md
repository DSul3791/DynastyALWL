# Tyler handoff (written by Tyler_Guru_003 for the next iteration, 23 Oct 2026 23:10 UTC)

**State.** Head on claude/generator-v2 is build 770 plus JOBS/doc commits (v26 tiles and drainage_mode true in; TERRAIN_VERSION 26). Dave plays from his pulled folder (last confirmed 764). Merged today 747-770 (see BUILD_LOG). Nothing merges to Dave's folder while he plays: Mike pulls after local_check.

**Merge queue (all wait for ONE MikeW batch PASS; list is the top block of tech/JOBS.md "Mike 1"):** steve-sunny-button (RUNTIME), steve-water-flow-at 66470d2 (RESTART), sal-sawmill-rules (includes water-flow, merge with/after it), kathleen-patches-now f0d9b56 (flora.json, RESTART), steve-berry-picking (protocol 74, RESTART), sal-harvest (data), steve-sound-3d (RUNTIME), then Sonny's sonny-flora-patches when pushed (bump flora layout VERSION to 2). Never merge: sal-ceiling-names, kathleen-patches (old), sonny-valleys before its bake. Use tools/merge_branch.sh, merge_check, check_controls; never commit on UU. Bump build.gd NUMBER, BUILD_LOG (both copies), HANDOFF line 2.

**Gates before Dave pulls:** local_check baseline 233, parse check, test_server_items, check_controls, T-BERRIES, bramble before/after, frame time Ctrl+Shift+G on F2 Low <33 ms. Then post Dave's pull steps, numbered: close game fully, GitHub Desktop Fetch origin, Pull, start game.

**Open for Dave on QA page:** copy-tiles-by-hand, push-tiles-by-hand, mike-settings-all-2, harvest-counts, shrub-*-4 cards, blackthorn-real-size, sound-duck-vetted; ear card for sound-3d after merge. Check ANSWERS/DECISIONS before posting any card (BP-T51); picture cards need the file pushed and under 1 MB with a bare "Image:" line.

**v27 bake bundle:** sonny-valleys 1d309611 + coast fix + settler clamp, TERRAIN_VERSION 27, drainage_mode true. Only after Dave OKs the v26 world; then Sonny re-settles, Dave presses Clear blocks.

**Rules to keep in mind:** BP-T50 (action plan to Tyler before any job), T44-T51, safe-place rule, floor = foundation (no floor item), quote Dave in Atlantic time. Message limit to coordinator is 20/hour; use thread posts when limited. Ready queues for every thread are in JOBS.md; refill daily. 8 AM ADT routine must re-arm itself.

**Traps learned:** CI cannot run Godot, so duplicate names broke the client (builds 750-753); check_dupe_names.py and the parse check now guard it. Do not claim a branch merged until git log shows it. Daily wrap: DAY_LOG line, DECISIONS sweep of ANSWERS.
