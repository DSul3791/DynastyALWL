# Art direction thread handoff (written 2026-10-21 13:10Z)

## Who and where
- Thread "Art direction" owns how the world LOOKS (trees, flora, grass looks, pebbles, boulder look, character model, water shader look, sky, sun/moon, weather look, ice look, buildings look, wind cue). Game: DynastyALWL (Godot 4.7.2 Forward+, GDScript). Repo DSul3791/DynastyALWL, work ONLY on branch `claude/generator-v2` (Dave merges; never push main). Read HANDOFF.md and ART_DIRECTION.md (sections 1-53) first.
- Other sessions: coordinator session_01Q56PMTBrWt1QNcAeKECxYY (talks to Dave), Technical direction (TD) session_0111SmjyMaTAj3PtyQqHboYJ (build numbers, approvals, tech/JOBS.md), Items session_01V6Btc8oMTBkLDXxtZpyY7v, Ground session_0176JkvTJrKJQ7GEdQ44pAsw. Message them with mcp__claude-code-remote__send_message. Only `mcp__hearthbot__*` (reply, update_status, no_reply_needed) reach Dave/the user; end every turn with one.
- Dave is a voice user: short plain replies, no em-dashes, every reply to him ends with "Still waiting on:" (list). Dave plays on his own PC (RTX 2060 SUPER; close the editor before pulling). Cloud has no GPU, cannot bake; Dave bakes tiles himself (never touch tile data).

## Working rules
- Pre-push: `git pull --rebase --autostash`; `git grep -nE '^(<<<<<<<|=======|>>>>>>>)' -- '*.gd' '*.md'` empty; headless `--check-only` of every changed script with the engine at `/tmp/claude-0/-home-claude-dynastyalwl/7f7077c8-f498-5a03-8a2b-de465516ce29/scratchpad/eng/godot` (re-download Godot 4.7.2 if the scratchpad is gone); `python3 tools/check_controls.py`; grass changes also tools/check_grass_density.py and check_grass_bands.py; flight check `/tmp/gtest.sh <quality> <port> <label>` (log /tmp/fx/c.log; may need recreating). Push: `git push -q origin HEAD:claude/generator-v2`. Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` and `Claude-Session: <your session url>`. No model names in repo artifacts. New key/mouse inputs must update CONTROLS.md.
- BUILD: `const BUILD` in scenes/terrain_client/terrain_client.gd; set it on every push. Numbers come from TD (tech/BUILD_LOG.md). If you hold none, take next free above upstream head and tell TD the commit id. Upstream often moves: resolve a BUILD conflict by keeping your number.
- Cloud state costs at Low and High. GPU table is Ctrl+Shift+G or Esc > Advanced (NEVER say F8). Dave often screenshots an older build: check the HUD build number before treating something as a regression.
- Lavapipe still-render harness: Xvfb :99 (`setsid nohup Xvfb :99 -screen 0 1280x720x24 &`; it dies between turns, restart it), clean project `scratchpad/fallproj` (day_look.gd [HOUR STORM WEST DOY OUT], ice_look.gd, bl_look.gd buildings, wc_look.gd wind cue; copy the script under test into fallproj). Run background jobs with `(setsid nohup bash script >/dev/null 2>&1 < /dev/null &)`; kill by exact PID, never `pkill -f` with a pattern matching your own command (exit 144). Never overwrite scratchpad/proj src wholesale.

## Dave's art decisions (his wording where it matters)
- Reference brook photo wins; near-photoreal; low sun golden; trees procedural MultiMesh per species from his 8-panel photos; wardpine mountain only; hardwood crowns cover top 3/4; canopy suppresses understory.
- Grass: real meadow ~0.9 m, ~98% cover; draw distance Ultra 160 m, High 120, Medium 80, Low 40. Pebbles pure decoration, vanish when voxel dug. Scenery boulders OFF (363); server boulders are real objects.
- Buildings/items: "slightly stylised" heroic look; plain item names; first-person arms (ragdoll right side is +X since build 354).
- Performance: min machine GTX/RTX 1050-class, 30 fps; quality Low..Ultra. Idle work should be near zero.
- Ice: pond/lake ice always holds; ocean ice = floating floes.
- Sounds are ON HOLD (not mine).

## Built by me this stretch (all on claude/generator-v2)
- 353 idle grass work; 354 ragdoll sides fix; 355 (+fix 1daef85) GPU probe per-piece script line; 363 scenery boulders off.
- 386 day cycle (src/client/day_cycle.gd; weather_look.gd; sky_clouds.gd stars; water_material.gd daylight + ice look; ocean_ice floe shader): real sun/moon path from game clock, palettes, stars, water follows. Sky updates throttled (1 s sun, 4 s sky) because cubemap redraw may hitch at dusk (Dave to check). Stills: /mnt/project-files/art/day_cycle_sheet.png, ice_pond_sheet.png.
- 387 flora draw merge (1438998): Low flora nodes 543 -> 197. 
- 388 buildings look (34c8a7d): src/client/building_look.gd (lean-to, chopping block, woven chest, campfire with shader flames, same OmniLight3D "Light" child); inventory_view.gd `_make_*` only delegate. Stills art/buildings_look.png, buildings_look_night.png. ART_DIRECTION.md section 52.
- 396 wind cue (67f5e30): `wind_dir` added to src/shared/weather.gd (radians, direction = (cos, sin) on (x, z), TD approved, tested in test_weather.gd); src/client/wind_cue.gd one GPUParticles3D, off at Low, 160/260/400 at Medium/High/Ultra, none at sea (eye y < 2.5 m), rain, snow or underwater; owned by weather_look.gd. Section 53. TD asked to list wind_dir in tech docs.

## In flight
Nothing half-built; everything above is pushed. Unverified on a real GPU: day cycle (dusk hitch every 4 s, night brightness), ice look, flora merge visuals (far trees look alike, shrub edge pop), buildings look, wind cue visibility, ragdoll, river mouth, boulders/pebbles.

## Queue (order; tech/JOBS.md has the master list)
1. Job 12: before/after renders for steps 3-6 plus the waterfall base into /mnt/project-files/art/ (software renderer; there are no saved "before" captures, so render current state and, where needed, old commits via git worktree).
2. Job 13: storm sky at four times of day vs server weather (largely covered by day_cycle_sheet.png; run storm renders with day_look.gd STORM=1 and report done).
3. First-person arms polish with Items' held tool node (TD wants this next; Dave reports no problem so far, so only if off).
4. Re-check the 33 ms script-time hunt when Dave's per-piece table (build 355+) arrives: name the top three pieces, tell TD, fix worst first, report CPU script ms before/after in one line.
5. Review pond/fall shading once River start pushes; optional cross-chunk 2x2 flora merge; grass merge belongs to Ground (c6ab4d6; do not make big edits to grass_view.gd _build/_free_cell_nodes/update).
6. Owed notices: Sounds (`faint.blackout`), Items (exertion should call `faint.set_state`).
- Fill-ins from JOBS.md: Low-tier cost table per step in ART_DIRECTION.md; asset budget table (triangles per tree per LOD, textures, alpha overdraw) with TD.

## Waiting on Dave
- Ultra table on build 355+ standing still (same spot; also meadow and under a crown) showing the per-piece script line; lake-shore check (x 53318 z 68473); "Measure this machine" at High (and from a 1050-class PC if possible).
- Feedback on 386 (night brightness, dusk hitch), 387 (far tree variety, shrub edge pop), 388 (buildings), 396 (can he tell wind direction; too faint/many).

## Build numbers held
397 and 398 (TD log: "Art holds 396, 397, 398"; 396 used). Next unused for Art: 397.

## Gotchas
- visibility_range uses AABB centre distance, so wide merged MultiMesh groups break distance cutoffs.
- Sky PROCESS_MODE_QUALITY redraws the cubemap on parameter change: keep updates throttled.
- Flora plan keys [species, part x, part z, variant, tier]; chunk 256 m; far tier variant = 0.
- Godot front faces are clockwise: building_look.gd `_tri` picks normals from an interior point so winding cannot be wrong.
- Dave bakes from a chosen commit: do not change tile data; tree/flora/grass/ice/digging changes need no re-bake.
