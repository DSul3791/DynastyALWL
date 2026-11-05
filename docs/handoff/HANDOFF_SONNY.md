# Handoff: Sonny (terrain and Dynasty water), 1 Nov 2026

> **CURRENT FLOW (fact check, 5 Nov 2026; supersedes the branch and merge lines below):** there is no daily branch: `DailyDev_20261029` was merged into `main` (PR #11, `a8c4d545`) and deleted on 1 Nov, so "the daily" below means `main`. Each agent cuts a new branch from `origin/main` each day and opens one pull request per job into `main`; agents never merge themselves. Tyler merges when CI is green and `tools/run_tests.sh` passes on the merged result. "Never merge to main" below means "never merge it yourself", not "never open a PR". Commit heads, test counts and "in the daily" claims below are as of the date in the title; `git log origin/main` and CI are the truth now. Priorities and job owners: `/mnt/project-files/BACKLOG.md`.

> **ROLE CHANGE (Dave, 1 Nov 2026): Sonny is the terrain and water agent only.** The unfinished character items (side-on stance, creator preview opening on the back, character pictures) are Kathleen's (look); the character system is Steve's. Edited by Jamie with Sonny's OK.

## My role
Since 31 Oct: owner of the NEW water system, "Dynasty water", on branch `dynasty-water` (worktree `C:\GodotProjects\DynastyALWL\.claude\worktrees\dynasty-water`). Code only in `src/water2/`, plus two tiny edits outside it. The old water (`src/water/`) is untouched. Moderator is "More Dynasty"; Dave decides. Earlier character work (branch `sonny-character`, creator pictures db105d36) is handed over; its details are in that branch's history and were not re-audited.

## Done and pushed on `dynasty-water`
- Core sim `src/water2/water_field.gd`: local inertial shallow water (Bates, Horritt, Fewtrell 2010) on the 8 m grid, per-face flow, Manning friction, 16x16 sleeping blocks, springs, sinks, held levels (sea), rain, channel mask, `hold_steady()` for rivers.
- Traits `water_kinds.json` / `water_traits.gd` (colour, clarity, density, viscosity, roughness, flow rate, film, turbulence and wave speed as look-only, harm). Rules `water_rules.gd` (wade, swim, drown, sweep) as pure functions, NOT wired to the player.
- Real tile window `water_window.gd` and swap hub `water_hub2.gd` (same API as the old hub). One 128x128 cell (1 km) window of starter tile (3,4) is simulated; the rest keeps the baked levels. Behind `--water2` on the server: server log prints `water2: tile (3, 4) window 128 x 128 ...` (seen 1 Nov).
- Render texture module `water_flow_texture.gd` (not used by the game yet).
- Merges: the daily was merged in at b802ed25 and again at 27517559 (clean). Latest water commits: 5853ef75 (task list, spot probe), status doc results commit before it.
- Docs: `docs/DYNASTY_WATER_DESIGN.md`, `docs/DYNASTY_WATER_HISTORY.md` (stage log, numbers; the 31 Oct status doc is archived in `docs/archive/2026-11/DYNASTY_WATER_STATUS.md`), `docs/DYNASTY_WATER_TASKS.md`, `docs/WATER_OWN_SYSTEM_PROPOSAL.md`.
- Tests that PASSED on 31 Oct (0 failures): `test_water_field`, `test_water_flow_texture`, `test_water_window`, `test_water_hub2`. Cost probe: 101-116 ms per simulated second for the 1 km window (about 10 percent of a core on the 50 percent duty thread).

## Not finished (exact next steps)
1. **Water2 as the default (Dave's decision 1 Nov): APPLIED in the daily (checked by Jamie in code: `terrain_server.gd` picks `WaterHub2Script` unless `--water-old`; `scenes/launcher.gd` passes `--water-old`; `src/water2/water_choice.gd` exists). What is left is running its tests (see `docs/TERRAIN_WATER_BACKLOG.md`).** Original note: the change was WRITTEN BUT NOT RUN and I parked it so no unrun code sits on the branch: `docs/handoff/water_default_flip.patch` (apply with `git apply docs/handoff/water_default_flip.patch`). It: makes `terrain_server.gd` use the new hub unless `--water-old` is given; adds `src/water2/water_choice.gd` (setting `[water] old` in `user://input_settings.cfg`); makes `scenes/launcher.gd` pass `--water-old` to the server it starts when the setting is on; adds an "Old water (next Play)" switch to Esc > Settings > Gameplay in `src/client/game_menu.gd`. Next: apply, run a headless parse/start of the menu and server, check the switch saves and the launcher passes the flag, check `look_rig --server-arg --water-old` still gives the old water, then commit.
2. **Lake cost and river drain (Dave: must not slow a play-test, rivers must not vanish in the first 30 minutes).** `probe_water_cost.gd` shows all 64 blocks always awake because the held rivers keep moving, so lake sleep is not the issue, steady river flow is. `src/water2/probe_drain.gd` (written, unrun; the job was queued behind full Godot slots) prints drawn cells, volume kept and awake blocks at 1, 3, 10 and 30 simulated minutes. Earlier measurement: about 12 percent of baked wet cells stop being drawn in 180 s. Likely cheap fix: in `publish_levels` (water_hub2.gd) draw the baked level when a baked wet channel cell has drained below the draw threshold (a marked shortcut), and cap simulated cells or stop stepping blocks whose change is under a threshold. Measure with the probe before and after.
3. **Real-game picture.** The first picture put the camera under the ground (a walking shot with agl 12 fell through), the second was open sea (ground -49 at 54728,75530). Use `src/water2/probe_pick_spot.gd` (unrun) to find a river or lake cell above sea level in the window, then `tools/look_rig.sh --cam first --at X,Z --agl 50 --yaw ... --pitch -25 --wait 90 --settle 20 --out DIR --server-arg --water2` (agl over 40 flies, no collision). Needs `godot --headless --path . --import` once per new worktree.
4. **Stage e/f:** protocol flow channel so the sim's flow and depth reach the shader (today the game recomputes flow from levels only); windows that follow players; digs and fills reaching the field; swim/drown rules wired to the player; shader patch in `src/client/water_material.gd` (six lines, plan in the status doc, not applied); lava and swamp look wrong through the game shader.
5. Slow tests not yet run on this branch: `test_worldgen`, `test_water_soak`, `test_spawn_dry`, `test_first_hour`.

## Tests and how
Voxel build only: `/c/GodotInstaller/godot.windows.editor.x86_64.exe --headless --path . --script res://src/water2/<test>.gd`. Always through `tools/godot_slot.sh` (max 3 heavy Godot jobs on the PC; other sessions often hold all three, so jobs queue). Files: `test_water_field.gd`, `test_water_flow_texture.gd`, `test_water_window.gd`, `test_water_hub2.gd`, probes `probe_water_cost.gd`, `probe_drain.gd`, `probe_pick_spot.gd`. Demo pictures: `demo_water_field.gd`.

## Open bugs and risks
Held-river drain (above); the sim's flow does not reach the real game's shader; rain scale is a guess and only wets channel cells; windows do not follow players; digs and fills do not reach the field; no long-run (hour) drift check; PONYTAIL `shortcut:` comments in the code mark every known cut. The unrun code to distrust first: the `_rest` edge-face fix (tests passed after it), the flip patch, the two probes.

## Read first
`docs/PONYTAIL_RULES.md`, `docs/DYNASTY_WATER_HISTORY.md`, `docs/DYNASTY_WATER_DESIGN.md`, `src/water2/water_hub2.gd`, `src/water2/water_field.gd`, `tools/godot_slot.sh`.

## Decisions Dave made (do not re-open)
Own new water system built stage by stage; baked tiles and the water shader look stay as the swap boundary; flow speed and waves are separate settings; PONYTAIL rules; the new water becomes the default with the old behind `--water-old` and an in-game switch (1 Nov); no baked tile is committed without Dave's go; pictures for Dave go on the QA page, one card per picture (worktree `C:/GodotProjects/DynastyALWL_qa`, branch qa); do not `git add` `worlds/base_world/water_archive/` or `scratch_world_*`; commit messages end with the Co-Authored-By line; never kill Godot by name; never merge into main.

## Skipped or not verified
Everything under "Not finished". The default flip has never been executed. No in-game water2 picture exists that shows a river or lake. Research citations other than Bates 2010 are from memory.

## Next tasks I would have done
(a) apply and verify the flip; (b) drain fix and measure; (c) real-game before/after pictures on the QA page; (d) protocol flow channel plus shader patch; (e) windows following players with shared seams; (f) a one-hour held-river soak test; (g) wire `water_rules.gd` into the existing swim code.

## Late results (1 Nov, after the handoff)
- `probe_pick_spot.gd` ran: 101 sampled wet cells above sea level, deepest 9.3 m of lake. Its printed world x/z are WRONG (it built the tile data by hand, so `td.x0`/`z0` are 0: real world x = 54272 + (origin.x + i) * 8, z = 74752 + (origin.y + j) * 8, origin 1024,1664). Fix by reading the tile origin before use.
- `probe_drain.gd` partial (60 s and 180 s): 98.6 percent of baked wet cells still drawn (2595 of 2633), but 113 cells are under half their baked depth (worst loss 2.2 m) and the volume reads 140 percent of the start (held rivers add more than they lose), 64 of 64 blocks awake. So the "12 percent vanish" is not seen in this probe; the 10 and 30 minute rows had not printed when I stopped.

## Also read
`docs/DYNASTY_WATER_HISTORY.md` (why and how, problems, numbers) and `docs/handoff/SCOPE_SONNY.md` (scope, priorities, finish line). Update to the drain item above: the 10 and 30 minute rows later came back the same, 98.6 percent drawn, so no drain fix is needed.

## Run state when stopped (1 Nov, Dave's stop order)
With the flip patch applied: `test_water_field`, `test_water_flow_texture`, `test_water_window`, `test_water_hub2`, `test_spawn_dry`, `test_first_hour` all PASSED (0 failures). `test_water_soak` was killed at the stop order, not finished: re-run it. The patch is still NOT committed (launcher and menu changes never started in a real game); apply it with `git apply docs/handoff/water_default_flip.patch`, then check the menu and launcher start, run `test_water_soak`, then commit.
