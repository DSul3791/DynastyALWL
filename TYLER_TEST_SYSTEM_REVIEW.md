# Test and gate system review (Tyler, 30 Oct 2026)

Branch `claude/tyler-gates-fee5f7`. Timings are measured on this PC (12 threads, Godot 4.7.2, 6 jobs unless stated) with the whole 109-test set run twice (the first run was in a fresh worktree with no import cache, which exposed bug 1 below). Nothing was merged into main.

## Decisions (30 Oct 2026, Tyler; Dave asked me to decide the open options)

| Option | Decision | Done in | What we lose |
|---|---|---|---|
| A. Slow world and water tests | **Superseded by the second pass below:** Dave does not want a nightly schedule. The big tests are now release tests (by hand, `tools/release_check.sh`; per change only when baked data changes) and small fast tests cover the code | see second pass | A drainage or water fault the small tests cannot see (see the mutation table) waits for the next baked-data change or a release check |
| B. `test_animals` limit | **Only the 150-animals-all-near check goes from 2 ms to 3 ms.** The 20-player 2 ms budget check is untouched. The PC known-failure list is empty again | commit "Option B" | 50 percent more slack on that one stress check |
| C. Gate-tool edits | **Edits to `test_lanes.json`, `run_tests.sh`, `run_one_test.sh`, `tests_for_diff.py` and the selftest run the lane check and the selftest (1 min), no game tests** | d9d7e43b | A lane edit that wrongly moves a game test is caught by the next real change or the nightly run |
| D. `.import` line endings | **`*.import text eol=lf` in `.gitattributes`** | 20823bce | Nothing; see the correction in section 3 |
| Linux-only paths | `ship.sh`, `next_build.sh`, `watch_answers.sh`, `balance_sheet.py` made path-independent | a19ed7b4 | Nothing. `look_rig.sh` already had a Windows branch; I was wrong to list it |

**Measured effect of A and C (selector on the last 30 DailyDev commits, CPU seconds, from this PC's per-test times):** 24,767 before any of my changes, 14,826 now (minus 40 percent). Eight commits (tool-only or python-only edits such as f4c88438 and 9cfea081) drop from about 1,185 to 62 s; 8411eca1 drops from 1,196 to 698 s. The other world-generator commits (6f6dc18e, 4a3e9e62, 066a4e7d, 9a110cc1 and similar) still run most of the slow lane, because those files really are loaded by `test_worldgen`, `test_head_pond_fill` and `test_water_soak`. The saving is real but smaller than the 6 minutes per commit I first suggested.

**Final full run: see the second pass below (the earlier 108 pass, 0 fail, 394 s run was before the small tests and lane changes).**

## Second pass (30 Oct 2026): no nightly; small fast tests instead of the big ones where they can match

Dave's constraints: no scheduled "nightly" run (we work day and night); prefer small, fast, custom tests with the same fidelity; first check each old test still suits the NEW system (ground first, natural rivers, lakes from the fill, rain-fed lateral inflow, erosion delta, climate classification); keep the big tests as a manual before-a-release command. The nightly decision above (option A) is **superseded by this section**: `nightly_slow.sh` is now `tools/release_check.sh`, run by hand, with no schedule.

### What the new system is, in the repo today
Natural rivers are built (`drainage_natural.gd`) but **switched off** in `worlds/base_world/plan/tile_rules.json` (`water.drainage.natural.enabled` false). The committed tiles are therefore still the old system's: predetermined rivers from `river_network.gd`, head ponds, rule-carved channels (`drainage_channels.gd`), carved lake basins. Turning natural on needs the slow1 erosion delta and a re-bake of the nine tiles (GENERATOR_NOTES.md, 30 Oct). So the big tests describe what ships now, and the small tests below describe the new system. Both are needed until the switch; after it, the "old system" rows below are archived.

### Relevance of each old test to the new system

| Test | What it checked in the old system | Does that still exist? | Still the right thing? | Verdict |
|---|---|---|---|---|
| test_water_soak (400 s) | Water hub on the 9 real tiles: at most 4 live, under 1.2 GB, a tile put to sleep is saved with its volume | Hub unchanged, and central to the living world (server water, overlay saves) | Yes. The measured peak was 956 of 1228 MB (78 percent): little room | **Keep as release test.** Cap, sleep and save are now also covered by `test_water_hub_small`; the memory bound is only measurable at full size |
| test_head_pond_fill (224 s) | Each spring sits in a baked 2 to 8 m head pond that then fills to 80 percent (build 623: spring landed in a lower basin) | Natural rivers have **no head ponds**; springs now come from river heads plus rain-fed lateral inflow. 8411eca1 had to stop lateral springs inside ponds just to keep this test green | Only for the old baked tiles | **Release test while natural is off; archive when natural is switched on** and the tiles are re-baked. New-system replacement: `test_water_small` |
| test_drainage_flow (50 s) | (a) mass balance of fill + flow; (b) fill/flow channels agree with today's baked rivers; (c) rule-carved channels: 20 bends, outer bank 1.3x inner bank, known dry rises | (a) shared by old and natural. (b) and (c) are the old rule carving, which natural replaces (`test_drainage_natural` checks bends and sinuosity for the new one) | (a) yes, (b) and (c) old behaviour | (a) **moved to `test_drainage_small`**; the rest **release test, archive when natural is on** |
| test_tile_lakes (80 s) | `drainage_channels._carve_basins`: every tile with land and rivers gets a carved lake, bowls inside their tile and block | Lakes now come from the fill (closed hollows, spill outlet) once natural is on; the carved-basin rule goes away | Old behaviour | **Release test; archive when natural is on.** New-system replacement: lake checks in `test_drainage_small` |
| test_worldgen (350 s) | The whole generator on tile 3,4: seeds, settings, matrix, sketch, plan, height, **tile water (predetermined rivers, starter river, bay head)**, climate, geology, sites, runtime terrain, flora, tile file | Pipeline sections are current. The river and tile-water sections describe the old network | Mostly yes; the river sections change with natural | **Keep (closure-selected).** No small stand-in exists: height 56 s, water 122 s, geology 46 s are real-size bakes. Rewrite the tile-water section when natural is on |
| test_drainage_fill (5 s) | Depressions become lakes, outlet at the lowest rim | Natural starts from the same fill | Yes | Keep (fast) |
| test_gen_core (5 s) | C++ GenCore gives the same bytes as the GDScript flood and route | Shared by both systems | Yes | Keep (fast) |
| test_river_ore (12 s) | A tile with land and rivers gets river ore | Rivers differ in natural mode, rule is the same | Yes | Keep (fast) |
| test_river_surface (3 s) | River surface on the baked tile 3,4 and its settled water file | Pins old baked data | Data pin | Keep; re-pin after the re-bake |
| test_slot_sounds (2 s) | Sound slots | Unrelated to the world | Yes | Was in the slow list by mistake: now a normal fast test |
| test_water_settle_rules | Feeder size follows drainage area, a head is the top water cell | Heads still place springs; lateral inflow added | Yes | Keep |
| test_water_sim (47 s, both cores) | Water sim rules, C++ core and GDScript fallback | Unchanged | Yes | Keep; the GDScript leg doubles the time and could be dropped if the fallback is retired |
| test_scree | A report, no check | | | Archived earlier |

### New behaviour that had no test, and what now covers it

| New behaviour | Test | Status |
|---|---|---|
| Natural rivers on a made-up island (determinism, reach the sea, bends, ground untouched far away) | `test_drainage_natural` (existing, by the other session) | Covered |
| Fill, flow, lakes from the fill (mass, drains to the sea, lake at lowest rim with an outlet) | `test_drainage_small` (new, 0.3 s) | Covered |
| Live water on natural channels from dry; rain-fed lateral inflow; no water created | `test_water_small` (new, 3.4 s) | Covered. Thresholds are a ratchet under today's measured values (56 percent of river cells wet, 77 percent of those joined to the sea, 21 percent of lake cells wet at 10,800 s): they catch breakage, they are not a quality target |
| Hub live set, sleep and save | `test_water_hub_small` (new, 4.6 s) | Covered (memory bound excepted) |
| Erosion delta loading and sampling by world position | `test_erosion_delta_small` (new, 1 s) | Covered: grid values, outside is 0, frames sharing an edge agree exactly, sea untouched, summit crowns |
| Climate classification at altitude (glacier, snow, tree line, `pick_biome`) | none apart from the real tile inside `test_worldgen` | **Missing**: a pure test of `pick_biome` over a grid of (temperature, wetness, height, slope) |
| Farmland, bog, swamp classified from the result | `test_land_type` (existing) covers the classifier; the slow ecology tick of the vision does not exist yet | Missing when the tick is built |
| Python erosion model (`lem.py`, `rock.py`, `climate.py`, `meander.py`) | none | **Missing**: a small check of determinism, mass conserved, summit holds, no stream on rain-0 land |
| Edge agreement of the nine natural-river tiles | `edge_match.gd` is a tool that reported 0 hard failures; not a test | **Missing** as a data test after the re-bake |
| Natural rivers: live water on real channels (spread report) | a report, no assertion | Missing: turn the 3-hour wet-share numbers into a ratchet test on the re-baked tile |

### Mutation checks: break the code on purpose, see who notices

Each row: one line of code changed in a throw-away git worktree (`tools/mutation_check.sh`), the small and the big test both run on it. Times are wall time on a PC that was running eight of these at once, so the big ones are inflated several times. **Caveat found afterwards:** the tree these were cut from already fails four tests (see the final run below), including `test_drainage_flow` and `test_head_pond_fill`, so for those two a plain FAIL proves nothing; the table counts a big test as catching a fault only when it fails with a message the unmutated tree does not give.

| # | Fault put in | Small test | Big test |
|---|---|---|---|
| m1 | Hub live-tile cap 4 raised to 6 | `test_water_hub_small` **FAIL (caught)** | `test_water_soak` **PASS (missed)**: the memory trim dropped tiles, so the cap itself was never exercised |
| m2 | Water save format: centimetres written as decimetres | `test_water_hub_small` **FAIL** | `test_water_soak` **FAIL** |
| m3 | A sleeping tile is not saved | `test_water_hub_small` **FAIL** | `test_water_soak` **FAIL** |
| m4 | Spring placed on the lowest head first (the build 623 bug) | `test_water_small` **PASS (missed)** | `test_head_pond_fill` **FAIL (caught)**: a second spring stays empty (0.1 m of 1.0 m) on top of the one that already fails in the unmutated tree |
| m5 | Every spring one tenth strength | `test_water_small` **FAIL** | `test_head_pond_fill` **PASS (missed)**: the test scales what it needs to what each spring can deliver, and drops springs under 0.2 m3/s, so weak springs excuse themselves |
| m6 | Flow loses 10 percent at every step | `test_drainage_small` **FAIL** (mass balance) | `test_drainage_flow` **FAIL (caught)**: mass balance, 2 of 216 km2 leave (the unmutated tree already fails a different line of this test) |
| m7 | Lake level 0.5 m too high | `test_drainage_small` **FAIL** | `test_drainage_flow` fails, but with the same message as the unmutated tree (8761 rises): **no new detection, missed**; `test_tile_lakes` **PASS (missed)** |
| m8 | Lake bowls may touch the tile edge (carve rule removed) | `test_drainage_small` PASS (does not cover the old carve rule) | `test_tile_lakes` **PASS (missed)**: not proven to catch it either |
| e1 | Erosion delta: grid edge test broken | `test_erosion_delta_small` **FAIL** | none exists |
| e2 | Erosion delta: crown subtracted the wrong way | `test_erosion_delta_small` **FAIL** | none exists |
| e3 | Erosion delta: grid origin shifted 3 m | `test_erosion_delta_small` **FAIL** | none exists |

Reading it plainly:
- **Same or better fidelity:** drainage mass balance and lake level (m6, m7), hub cap (m1: the small test is stronger), save format and no-save (m2, m3), and spring strength (m5: the small test is stronger). The erosion delta is new coverage.
- **The small tests cannot match:** the build-623 class (m4): a spring landing in the wrong baked pond needs the real heads and ponds of the old baked tile. Natural rivers have no head ponds, so this class disappears with the switch; until then `test_head_pond_fill` stays as a release test and runs whenever baked tiles change.
- **Nobody proven:** m8. `test_tile_lakes` did not notice a removed carve guard, so I cannot claim it protects what its header says. It stays as a release test only because it costs nothing per commit.
- **What this does not show:** a handful of faults is a sample, not a proof. Each pair was chosen to match the big test's stated purpose.

### What changed in the lanes

| Before today | Now |
|---|---|
| Slow lane of 9 tests started by any change under `src/worldgen` or `src/water` | Slow lane is 5 tests (the 4 cheap ones are fast again). Four of them (`head_pond_fill`, `water_soak`, `drainage_flow`, `tile_lakes`) are **release tests**: picked only when baked tiles, water data or plan files change, when the test itself changes, or with `--full` |
| No tests for drainage/water code but the big ones | A path rule selects `test_drainage_small`, `test_water_small`, `test_water_hub_small`, `test_drainage_natural`, `test_drainage_fill` for `tile_drainage.gd`, `drainage_*.gd`, `src/water/**`, water data |
| `nightly_slow.sh`; `ship.sh` ran every test | `tools/release_check.sh`, by hand, no schedule. `ship.sh` runs the tests its own diff selects (`SKIP_TESTS=1` skips) |
| `test_worldgen` selected by closure | Unchanged: no honest small replacement. It still costs about 6 min on a generator change |

**Per-commit cost, last 30 DailyDev commits (CPU seconds, from this PC's per-test times; small tests at their measured 1 to 6 s):** 24,946 CPU s with the selector as it was this morning, 13,306 now (minus 47 percent). Tool-only and python-only commits: about 1,185 s to 62 s. Water-only code commits such as 8411eca1: 1,213 s to 92 s (the big head-pond test no longer runs for them; that commit was a fix for exactly that test, so whether the small tests would have caught the same fault is not proven). Commits that edit the generator pipeline (6f6dc18e, 9cfea081, 4dcb040c): about 1,260 to 1,470 s to about 500 s, because `test_worldgen` (350 s) still runs for them.

**Final full run after all changes (`tools/release_check.sh`, 6 jobs):** **109 pass, 4 fail, 1,087 s wall** (113 tests, 6 jobs; 3,762 CPU s). The four failures are not new: they also fail on `DailyDev_20261029` itself (checked in a clean worktree of that branch, before any of my changes): `test_drainage_fill` ("every lake has an outlet"), `test_river_surface` (cross-sections worse than the baseline: median 0.32 m, 90th 0.82 m), `test_drainage_flow` (bed rises downstream: 8,761 rises, known up to 18) and `test_head_pond_fill` (the spring at sample 1765872 fills 3.1 of 4.0 m). Probable cause, not verified: `tile_rules.json`, `world.json` and `sketch_rules.json` on the daily branch changed (taller range, rolling ground, lakes over the eroded ground) while the committed tiles are still the old bake; GENERATOR_NOTES says a re-bake is pending. All four are old-system data tests, so they are the ones that need re-pinning or archiving when the natural rivers are switched on. The new small tests all pass (drainage 1.4 s, erosion delta 0.7 s, water 4.3 s, hub 5.8 s). Slowest: `test_tile_lakes` 1,073 s (80 s on 30 Oct before the daily branch was merged in; not investigated), `test_head_pond_fill` 804 s, `test_drainage_flow` 603 s, `test_water_soak` 494 s, `test_worldgen` 427 s.

### Sources and confidence

| Topic | Source | What it says | Confidence |
|---|---|---|---|
| Test selection per commit, full run nightly | [Martin Fowler, The Rise of Test Impact Analysis](https://martinfowler.com/articles/rise-test-impact-analysis.html) | A common setup is a smaller suite per commit plus a nightly job that runs everything; the cost is delayed bad news | High for the article; the fit to a 108-test Godot project is my judgment |
| Selection can miss; keep a full run | [regression-suite-selector write-up](https://tessl.io/registry/testland/regression-suite-selector), [Datadog on its test selection](https://www.datadoghq.com/blog/streamline-ci-testing-with-datadog-intelligent-test-runner.md), [minware on test impact analysis](https://www.minware.com/guide/best-practices/test-impact-analysis) | Run everything on the default branch as a failsafe; unmappable changes (config, tooling) should fall back to more tests; nightly failures that PR runs missed show selection gaps | Medium: vendor and blog sources |
| Tiered suites | [archman.dev CI integration guide](https://archman.dev/docs/testing-strategy/test-automation/ci-integration) | Fast checks per commit, slower ones nightly or pre-release | Low to medium: secondary source, its minute figures are rough |
| Godot and line endings | [Godot docs, Version control systems](https://docs.godotengine.org/en/4.4/tutorials/best_practices/version_control_systems.html) | Git for Windows defaults to `core.autocrlf=true`, which marks files modified because of CRLF; Godot recommends `autocrlf=input` or LF through `.gitattributes`; ignore `.godot/` | High (official). It says nothing specific about `.import` files |
| `*.import text eol=lf` | [community .gitattributes example](https://github.com/Teslacrashed/godot-tooling/blob/trunk/.gitattributes) | Uses exactly that line | Low as a source; my own test is the evidence: after the change 73 phantom modifications were gone |
| gitattributes mechanics | [git gitattributes manual](https://manpages.ubuntu.com/manpages/jammy/man5/gitattributes.5.html) | `eol` implies `text`; existing CRLF paths may look dirty until re-added | High (official) |
| Shell portability | [Bash FAQ 062 on temporary files](https://mywiki.wooledge.org/BashFAQ/062?action=raw), [Unix SE thread on tmp dirs across platforms](https://wiki.neonvagabond.xyz/content/unix.stackexchange.com_en_all_2024-05/questions/174817/finding-the-correct-tmp-dir-on-multiple-platforms) | Prefer `mktemp`; honour `TMPDIR`; do not hardcode `/tmp` | Medium. The search did not confirm `mktemp` ships in Git bash; I tested it here and it works |

## Summary

| # | Finding | Size | Status |
|---|---|---|---|
| 1 | A test that does not compile leaves Godot idle; the runner waited the full limit (4 slow tests x 1500 s). A fresh checkout also failed 12 tests with misleading errors until `godot --import` ran | 25 min lost per broken run | **Fixed** (stops after about 2 s; imports once) |
| 2 | The slow lane (9 tests, 1123 CPU s, about 6 to 7 min wall) starts for every change under `src/worldgen/` or `src/water/`, including offline tool scripts; 13 of the 19 non-doc commits among the last 30 on DailyDev paid it | 6 to 7 min per commit | **Fixed** (A) |
| 3 | `test_animals` fails on this PC every time (2.0 to 2.4 ms against a 2 ms limit); plain `run_tests.sh` ended in "1 fail" on any run that picked it | noise | **Fixed** (known failures from `tech/TEST_BASELINE_PC.md` are reported, not counted) |
| 4 | `test_water_steady` could never fail (always exited 0); `test_scree` has no check at all and writes to `/tmp` | 2 false-safe tests | **Fixed** / **archived** |
| 5 | CI merge guard only ran on pushes to `claude/generator-v2` (retired); pull requests still ran | no push guard on main | **Fixed** |
| 6 | The suite is lean: median 1.9 s per test, 83 of 109 under 3 s. Five tests are 94 percent of the time | n/a | Do not prune small tests (saves about 2 s each) |
| 7 | Changing any gate tool file (`test_lanes.json`, `run_tests.sh`, `tests_for_diff.py`) selected all 96 fast tests | about 4 min wall | **Fixed** (C) |
| 8 | Linux paths: `ship.sh`, `next_build.sh`, `watch_answers.sh`, `balance_sheet.py`; four tools nothing references | housekeeping | Paths **fixed**; unreferenced tools reported |
| 9 | After any Godot import, 73 tracked `.import` files show as modified with no content change (Godot writes LF, `autocrlf` expects CRLF); 6 more differ for real (texture format) | noise | **Fixed** (D) |

## 1. How it works today (one page)

**Choosing tests.** `python3 tools/tests_for_diff.py <base> <head>` prints one JSON line: class (docs, data, code, bake), the fast, timing and slow tests, picture files and checks. Docs-only diffs (`*.md`, `docs/`, `tech/`, `proposed_removals/`) select nothing. Otherwise a test is chosen when its file closure (preload, load, `res://` strings, `class_name` use, directories) contains a changed path. On top of that: an "always" set of 10 item and save tests, an item group for `data/items/**`, path rules (looks, sounds, protocol) and extra inputs (baked tiles, water data, addons). An unknown path or a gate-tool file selects all fast tests. The slow lane (9 tests) is added when the diff matches `slow_triggers` (`src/worldgen/**`, `src/water/**`, water data, addons, worlds) or the class is `bake`. Lists live in `tools/test_lanes.json` (30 names, all valid).

**Running them.** `tools/run_tests.sh --plan plan.json` (or `--fast a b --timing x --slow z`) runs N jobs at a time (default 4), slow first, each in its own data dir (`run_one_test.sh`). Timing tests (animals, npcs, bed, fish_schools) and 1 test that writes a fixed file run one at a time at the end, with one logged retry. A test fails on a non-zero exit, a timeout (300 s fast, 1500 s slow), or output containing `SCRIPT ERROR`, `Parse Error` or a line starting `FAIL `. It ends with `Test done: N pass, M fail`.

**Around it.** `tools/local_check.sh` (38 s here): addons load, 3 big scripts parse, item validator, change class RUNTIME/RESTART/BAKE against the label, warnings against `tools/warning_baseline.txt`. `parse_scan.py` 1 s. `merge_check.py` 5 s (markers, JSON, item numbers, action ids, build number, `.uid` files). CI (`.github/workflows/merge_check.yml`) runs `merge_check.py` on pull requests and pushes. `gate_pc.sh` builds a trial merge in a warm worktree and runs all of the above. `ship.sh` merges a tested hash, bumps the build and opens a PR through `pr_merge.sh`. `selftest_gate_tools.sh` (16 checks, 53 s with a fake Godot) tests the selector and runner. The old Linux-box gate scripts (`gate.sh`, `gate_queue.sh`, `gate_nightly.sh`) are archived in `proposed_removals/`. RULES.md says: use `tests_for_diff.py` and `run_tests.sh`.

**Measured on this PC (all 109 tests, 6 jobs, warm import):** 417 s wall, 1466 CPU s, 108 pass and `test_animals` fails (known).

| group | tests | CPU seconds |
|---|---|---|
| test_water_soak | 1 | 399 |
| test_worldgen | 1 | 347 |
| test_head_pond_fill | 1 | 224 |
| test_tile_lakes, test_drainage_flow | 2 | 130 |
| the other 4 "slow" tests (river_ore 12, river_surface 3, gen_core 5, slot_sounds 2) | 4 | 23 |
| test_generation_speed, test_water_sim, test_server_items, test_warmth | 4 | 139 |
| the other 96 tests | 96 | about 190 |

The 10 "always" tests cost 62 CPU s (about 15 s wall). A typical code diff runs 10 to 15 tests in 19 s (measured, f4c88438). A diff that hits the slow lane ran 24 tests in 364 s (measured, 8411eca1, 4 jobs).

## 2. Where it can shrink

**The fast lane is already small.** 100 tests take 343 CPU s, about 1.5 min wall in parallel. Almost every test is Godot start-up (about 1.5 s) plus a few checks. Deleting a small test saves about 2 s, and I did not find real duplicates:

- The four new-player tests (`new_player`, `new_player_day`, `first_hour`, `first_town`) overlap in setup but check different steps (open recipes, first-day order, first hour, town loop). Merging them is a design job for Sal, not a clean-up.
- The water family (`water_steady`, `still_water`, `water_steps`, `water_flow`, `water_grid_flow`, `water_falls`, `water_hub`, `water_settle_rules`, `water_sim`) each test one function. Keep.
- I could not rank tests by "never fails": history is squashed (every test file has 1 to 3 commits since 20 Oct), so git cannot show it.
- Cheap cleanup candidates, none done: the 4 small tests in the `slow` list (`river_ore`, `river_surface`, `gen_core`, `slot_sounds`: 2 to 12 s) could move to fast and would then be chosen by closure only; `FLAKY_TESTS.md` still says `test_slot_sounds` takes over 5 minutes (it takes 2 s).

**The slow lane is where the time is.** Of the 19 non-doc commits among the last 30 on DailyDev, 10 are class `bake`, 1 is `data` and 2 are code that hit the water trigger. Each of those 13 paid 1190 to 1456 CPU s (6 to 7 min wall). That is the world-generator work itself (drainage, rivers, erosion). The slow lane runs the whole 9 each time, though many of those tests only read baked tile data. Smaller default (option A below): per commit, run only the tests whose closure the diff touches plus the always set; run the full slow lane once a day and before anything goes to main. On the 30-commit sample this changes only `8411eca1` (3 slow tests instead of 9, 698 CPU s instead of 1196), because the `bake` class forces all 9 in the other cases. The `bake` rule is the lever, not the closure scan.

What you lose with A: a regression in water or world generation can sit up to a day before the slow lane sees it (the audit's Dave-approved safeguard was "nightly and after each shipped build"; `gate_nightly.sh` is archived and no cron ran). What you keep: closure tests run on every commit.

## 3. Bugs and issues

Selector, run on 30 real commits of DailyDev (not the old Linux-era commits):
- Over-selecting: `src/worldgen/tools/*.gd` (offline report and export scripts) matched `src/worldgen/**` and started 9 slow tests, e.g. f4c88438 (`export_tile_maps.gd` plus python): 1250 CPU s for a change that no test loads. Python files under `tools/` selected the 10-test always set. **Fixed**: those now select what loads them or nothing (f4c88438: 1250 to 62 CPU s; 9b447e76 now docs-class).
- Over-selecting, not fixed: editing `test_lanes.json`, `run_tests.sh`, `run_one_test.sh`, `tests_for_diff.py`, `warning_baseline.txt` or `project.godot` selects all 96 fast tests (9cfea081: 95 tests). For the tool files, the right check is `tests_for_diff.py --check-lanes` plus `selftest_gate_tools.sh` (about 1 min), not 96 game tests.
- Under-selecting: none found. `--check-lanes` shows 0 missing names. No test reads a file in `proposed_removals/`, and no test references a missing `res://` file except `test_inner_voice_settings`, which deliberately loads `does_not_exist.json`.
- Precedence quirk (harmless): the `timing` line in `select()` mixes `or` and `and` without brackets; `always` holds no timing tests, so the result is the same.

Runner:
- A test that fails to compile hung to its limit (bug 1). **Fixed**: after the fix a broken test stops in 2.7 s (checked with a throw-away test file, removed again).
- A fresh worktree or clone has no `.godot` cache; 12 tests failed with `Identifier not found: WorldSettings` or `GenCore is not loaded`. **Fixed**: `run_tests.sh` imports once. `gate_pc.sh` already did.
- Fail detection looks for a line that starts `FAIL `. `test_dam_backup`, `test_land_type` and `test_slot_sounds` print `FAIL: ...` but also exit 1, so they are caught. `test_water_steady` and `test_scree` were not (item 4). **Fixed / archived**; `test_water_steady`'s check is unchanged, it now just reports it through the exit code.
- `test_animals`: 2.0 to 2.4 ms against 2 ms. On this PC it passes only when the PC is quiet. The baseline says 2.006 ms; I measured 2.42 ms under 6 jobs and 2.3 ms alone with a retry, so the margin is drifting. Option B.
- Timing test list: `test_fish_schools` is still a timing test though `FLAKY_TESTS.md` says it was fixed. Keep until `flake_finder.sh` gives 20 clean runs (not run, about 10 min).

Platform and dead scripts:
- Linux paths on this Windows PC: `ship.sh` (`BUILD_LOG_DIR=/mnt/project-files/tech`, skipped if the folder is missing, so it still runs), `next_build.sh`, `watch_answers.sh`, `balance_sheet.py` (`/mnt/project-files/...`), `bots.sh` and `hole_stress.sh` (`/tmp`), `test_scree` (`/tmp`, now archived). `python3` and `timeout` resolve in Git bash here.
- `ship.sh` carried another session's `Claude-Session:` trailer in every commit message. **Fixed**. It also writes `/tmp/ship_lc.txt`; now honours `TMPDIR`.
- Nothing references: `tools/merge_check.sh` (wrapper for `merge_check.py`), `pause_for_backup.sh`, `rebuild_starter_cache.sh`, `selftest_gate_tools.sh` (used by hand only). Not removed: move them to `proposed_removals/` on Dave's OK.
- `merge_check.yml` named a branch that was retired (**fixed**). Its `fetch-depth: 0` clone is the only CI cost.
- Docs: `GATE_FIX_PLAN.md` and `GATE_BEFORE_AFTER.md` describe `gate.sh`, `gate_queue.sh` and a nightly job that are archived or never ran. `docs/mirror/tech/TEST_BASELINE.md` says "generator-v2". Left as history.
- Git line endings (correction): the repo stores `.import` files as LF, the checkout is CRLF (`autocrlf=true`), and Godot rewrites them as LF. After an import git listed 79 as modified; ignoring line endings only 6 differ for real (`assets/stations/forge_*_N.png.import`: Godot picks the plain texture format here instead of the VRAM-compressed one stored in the repo). The other 73 were phantom changes, and `*.import text eol=lf` removed them. The 6 real differences are platform import settings and will reappear after each import; not changed.

## 4. Recommendations, in order of value

| # | Change | Value | Effort | Risk | Status |
|---|---|---|---|---|---|
| 1 | Stop broken tests at once; import in a fresh checkout | high (25 min) | small | none | done |
| 2 | Offline tool scripts do not start the slow lane | high (6 min per tool edit) | small | low | done |
| 3 | Option A: per-commit slow lane = closure only; full slow lane daily and before main | very high (6 min on about half the commits) | small (one rule in `test_lanes.json`; a nightly job) | a day's delay on world regressions | **done** |
| 4 | Known-failure list in `run_tests.sh` | medium | small | none | done |
| 5 | `test_water_steady` exit code; archive `test_scree` | low | small | none | done |
| 6 | CI trigger fixed | low | small | none | done |
| 7 | Option C: gate-tool edits run `--check-lanes` and the selftest, not 96 tests | medium (4 min per tool edit) | small | a lane edit could skip a test | **done** |
| 8 | Option B: `test_animals` limit | low | small | changes what the test checks | **done** |
| 9 | Option D: `.import` line endings | low | small | line-ending churn either way | **done** |
| 10 | Archive 3 unreferenced tool scripts; fix Linux paths in `next_build.sh`, `watch_answers.sh` | low | small | low | later |

## 5. What I changed (one commit each, none touches main or deletes anything)

| commit | change | before / after |
|---|---|---|
| 38c060d2 | `slow_exclude` and `offline_globs` in `test_lanes.json` plus selector support, 3 selftest cases | f4c88438: 9 slow + 10 always (1250 CPU s, about 6 min) to 10 always (19 s measured) |
| 6d49e076 | `ship.sh`: stale trailer removed, `TMPDIR` honoured | n/a |
| 5efda448 | `run_one_test.sh` early stop; `run_tests.sh` one-time import | broken slow test: 1500 s to 2.7 s; fresh worktree: 12 false fails to 0 |
| 22ff7e56 | `run_tests.sh` reads known failures | plain run with the animals failure: "1 fail" to "0 fail" plus a KNOWN line |
| 801dd57c | `test_water_steady` exits 1 when its check fails | check unchanged |
| 74053066 | `test_scree` moved to `proposed_removals/src/worldgen/tools/` (+ `REMOVALS.md` row) | 109 to 108 tests, 10 s less |
| 49b465ca | CI guard runs on pushes to main | n/a |

Verified after the changes: `selftest_gate_tools.sh` 16 pass, 0 fail; `tests_for_diff.py --check-lanes` 0 missing; `local_check.sh` PASS (38 s); `parse_scan` 0 problems; `merge_check` all clear. Not re-run after the changes: the full 109-test run (the second full run, 108/1, was before the last two edits).

## 6. Options as first written (superseded by the Decisions section)

**A. How often should the heavy world and water tests (about 6 min) run?** (1) Every commit that touches world or water code, as today. (2) Recommended: per commit only the tests that touch the changed files; the full set once a day and before anything goes to main. (3) Only when asked and before main. Lose with 2: a world or water break can hide until the daily run.

**B. `test_animals` fails on this PC at 2.0 to 2.4 ms (limit 2 ms).** (1) Keep the limit, list it as a known failure (done). (2) Recommended: raise the limit to 3 ms so it can fail again for real. (3) Drop the test. Lose with 2: 50 percent more slack before it reports a slow animal loop.

**C. When only gate tooling changes (the lists, the runner, the selector), run what?** (1) All 96 fast tests (today). (2) Recommended: the lane check and the selftest (1 min). Lose: a lane edit that wrongly moves a test is caught by the next real change instead.

**D. Godot's `.import` files change line endings on every import.** (1) Leave as is. (2) Recommended: mark `*.import` as LF-only in `.gitattributes`. Lose: one commit that rewrites 85 small files.

## 31 Oct night: the four known-red tests, merge watch, bot and world-alive tool

### The four tests that are red on the daily branch (decision: "known until re-bake")
They are listed in `tools/known_red.txt`; `tools/merge_day.sh` reports them as KNOWN, not NEW, so a red that is really new is not hidden among them. They are red because the committed tiles are the old bake and these tests read the baked tile 3,4 (GENERATOR_NOTES: "tests run before a re-bake test the OLD terrain"). Natural rivers stay off by default until the re-bake, so each test is judged against what the NEW system keeps:

| test | what it checks | new system | decision | covered meanwhile by |
|---|---|---|---|---|
| test_head_pond_fill | a spring lands in a head pond and the pond fills (build 623) | natural rivers have no head ponds | ARCHIVE when natural rivers are switched on (move to proposed_removals/ then); keep as known red until then | test_water_small (dry start fills, no stranded wet stretch) |
| test_drainage_flow | runoff gathers into rivers and agrees with the rule-based rivers, channel shape | channels are replaced by drainage_natural.gd | ARCHIVE after the re-bake; the mass-balance part is already in test_drainage_small | test_drainage_small, test_drainage_natural |
| test_drainage_fill | depressions become lakes, outlet at the lowest rim, on the baked tile | lakes from the fill are the new lake system | RE-PIN after the re-bake (keep the test, refresh its numbers on the new tile) | test_drainage_small (made-up bowl) |
| test_river_surface | river surface flat across, shore is the zero contour, on the baked tile and its settled water file | still true of natural rivers (cross-section numbers will change with meanders) | RE-PIN after the re-bake; loosen the cross-section limit only with a recorded reason | none for real tiles; test_water_small checks the settler only |

Rule for whoever re-bakes: after the bake, delete the line of each re-pinned test from `tools/known_red.txt` in the same commit; a test archived goes to `proposed_removals/` with a row in REMOVALS.md.

### New tools
- `tools/merge_day.sh branch...`: dry-run merge of several branches into a scratch tree from the daily branch (pair conflicts, sequential merge, tests against main, items_check, one-page result). Hourly results: MERGE_WATCH.md.
- `src/worldgen/tools/test_playability_bot.gd` (always lane, 1.2 s): the first hour by recipe name, stops at the first step that cannot be done and says which. Mutation checks in the section below.
- `tools/world_alive.sh` with TARGETS.md and WORLD_ALIVE_LOG.md: flora per hectare by layer, nominal animals per km2, water and rivers per biome on the nine centre tiles.

### Playability bot mutation checks (31 Oct, tools/mutation_check.sh, small tests only)
| mutation | test_playability_bot | test_first_hour |
|---|---|---|
| fire_is_lit always false (server_items.gd) | FAIL, "BOT STOPPED at step 7 (fire): ... could not be lit" | FAIL |
| every recipe gives 0 (recipe_table.gd) | FAIL at the first craft step | FAIL |
| every recipe needs the station saw_mill (recipe_table.gd) | FAIL, names the station | FAIL |
Honest note: both tests catch the same faults; the bot adds a message that names the step and the reason, finds recipes by name instead of number, and a gather budget (60 sticks, 40 stones, 90 fibre, 20 leaves by hand for axe + fire + lean-to; today the plan asks 15 / 4 / 21 / 6). The data-file mutations I first tried (twine and axe costs in recipes.json) could not be applied: the file is multi-line JSON and mutation_check.sh takes one-line text only.
