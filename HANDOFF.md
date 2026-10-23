# NOW (Guru, 16:30 UTC 23 Oct; older top block archived in docs/archive/HANDOFF_TOPBLOCK_2026-10-23_0435.md)
HEAD = build 749 on claude/generator-v2 (protocol 73, TERRAIN_VERSION 25; 26 only with the island bake). Merge guard CI runs on generator-v2. Dave: GitHub Desktop Fetch origin, Pull, close the game fully first.
RULES: BP-T44 QA page is Dave's to-do list, nobody is stuck; BP-T46 team tests first; BP-T47 post QA cards yourself with tools/qa_post.py and a recommendation; BP-T48 only new websites need Dave's permission; BP-T49 ground tests: drop, look down, step back about 1 m (tech/TEST_RECIPE.md has the plan template: owner drafts, Guru reviews, then MikeW runs). Player bot DECLINED by Dave.
DAILY HANDOFF + RESET every day 8:00 AM Atlantic (11:00 UTC until 1 Nov, then 12:00 UTC): tech/DAILY_HANDOFF.md. Day log: tech/DAY_LOG.md. Merge with tools/merge_branch.sh <branch> (stops on conflict).
DAVE'S LATEST ANSWERS: lake flicker fixed; island shape plan approved (tech/ISLAND_SHAPE_PLAN.md); items roll when walked over: YES (built, 724); wood chain, rock piles, cave-in death built; moose call: NOT an elk bugle, find a real moose grunt; raspberry/bramble looked terrible: redo from his photos (art/REFERENCE_PHOTOS.md); dirt weighs 0.1 kg.
OPEN WORK: (1) Island shape (Sonny, branch claude/sonny-island-shape, HELD): spawn zone fixed at 44a28318, MikeW rebakes 1 tile (3,4) and checks spawn/showroom (dry, flat); then one batched 9-tile bake (tile copy outside repo first, QA card "press Clear blocks"). (2) Test rig steps (Steve + MikeW): add dig, look-down, step-back, expectation check; plans T-DIG/T-DROP/T-PILE/T-CHOP in TEST_RECIPE.md. (3) 20-stone pile draws nothing in the rig (Steve). (4) Kathleen: flora redo from photos, animal sounds, moose. (5) Sal: tree species data (wood_species.json is in), blueprint build. (6) Guru: untrack old crash_reports (warn Dave), inbox files, finish WATER_OPTIONS_RESEARCH.md, id claims.
SOUND DROP-IN: Dave's own creature recordings (fox, deer, moose) go in as described in assets/audio/SOUND_DROP_IN.md.
NOT MERGED ON PURPOSE: kathleen-materials/shovel/spades (superseded), steve-warning-699, project-thread-sp0ppw, sonny-island-shape (until the bake check passes).
QA CARDS on Dave's page: only Kathleen's sound/flora cards (wolf, fox, deer-horse, bear, flora pictures).
MikeW: local_check on 733 (expect warnings 233), animal sound test, island 1-tile rebake, backup after Dave stops.

# Project handoff (rewritten 2026-10-22 by the Technical Director; short on purpose)

Read this first. About 10 KB. All older detail is kept, unchanged, in `docs/archive/HANDOFF_FULL_2026-10-22.md` (index at the bottom of this file). Rules and decisions live in the project files `tech/` folder (`/mnt/project-files/tech/`): **BEST_PRACTICES.md (read first, daily), PROCESS.md, DECISIONS.md, JOBS.md, BUILD_LOG.md, TEST_QUEUE.md**.

## What this is
A multiplayer medieval survival and town-building game ("Dynasty, a life well lived"): Godot 4.7.2 (custom build with Voxel Tools 1.7 compiled in), GDScript plus a C++ water core, built for weak hardware (minimum 1050-class GPU, 8 GB RAM, SATA SSD, 30 fps). Owner: David Sullivan (Dave; voice user, wants SHORT reports). Repo `DSul3791/DynastyALWL`. Work ONLY on branch `claude/generator-v2`; never touch `main` (Dave merges).

## Current state (2026-10-23 night)
- Development is ACTIVE. Latest build 693, protocol 72, TERRAIN_VERSION 25 baked. Terrain B drainage code is merged but OFF (rules drainage_mode false); the first real bake needs Dave's go; no tiles committed.
- Dave tests only at night after the backup (BP-T40); test lines for tonight are in tech/TEST_CARDS_TONIGHT.md; cards are test, picture and Yes/No with a Notes or Why-not box (BP-T36 to T40). Every plan goes to Dave as one Yes/No card per line (BP-T39).
- Live in the test world: tunnel collapse ON (admin switch and cave-in time 2 to 20 min in Esc > Settings, man-made spaces only), braces as spheres of influence, blueprint building NOT built yet (design in items/BLUEPRINT_BUILD_DESIGN.md plus DECISIONS 2026-10-23), twine (ex cordage), spades take shovelfuls from the pack, hoes, ladders, tier designs are drawings only.
- Runtime-only changes need no re-bake; server-side builds need the game closed fully so the server restarts.
- Tomorrow's first 3 jobs: 1. Sal: blueprint build system (mallet, ghosts, foundations, pillars, load limit) once Dave answers the cost-table cards. 2. MikeW and Sonny: 1-tile BAKE-1 test of Terrain B in the second clone; Steve: Esc menu tidy after Dave's 9 answers, then snapping rules with Sal. 3. Kathleen: build the tier looks in the game from Sal's piece ids after Dave answers the round-3 cards.

## Team (2026-10-22, Dave approved)
Coordinator (routing, moderator every 30 min, Dave's reports); Technical Director + Guru (docs, approvals, build numbers, JOBS/DECISIONS/PROCESS, question page, BEST_PRACTICES daily check); Sonny (World: ground, tunnels, bracing, water); Sal_Crafts (was Radar: items, crafting, NPCs, animals, buildings); Steve_ProblemSolver (Systems, was Tyler_002: server, network, HUD, movement, performance, saves); Kathleen_ArtisticDirector (was Kathleen_ArtisticDirector: art, animation, sound); MikeW_LocalAgent (runs on Dave's PC on demand: warnings, headless tests, GPU/visual checks). Workers run on demand from the queue. Details: `tech/TEAM_PROPOSAL.md`, `tech/PROCESS.md`.

## Working rules (pointers; the full text is in tech/)
- Before anything NEW, find its entry in `tech/BEST_PRACTICES.md`; none = ask the Technical Director and take another job meanwhile.
- Zero new GDScript warnings; typed code; no `@warning_ignore` without a reason.
- Server and client talk only through `src/stream/terrain_net.gd`; shared code in `src/shared`.
- Every input change updates `CONTROLS.md` and passes `python3 tools/check_controls.py`.
- Questions for Dave: pickable answers only, in `questions/QUESTIONS.md` (format `questions/README.md`), answers in `questions/ANSWERS.md`. Test asks go to `tech/TEST_QUEUE.md`. Never wait for Dave: park the job and take the next.
- Before pushing: `git pull --rebase origin claude/generator-v2`, conflict-marker grep empty, headless load of touched files, controls check, build number = max(origin BUILD, last BUILD_LOG line) + 1 with the BUILD_LOG line in the same commit. Never commit crash reports, editor logs, temp DLLs or .tile files.
- Confidence rule: technical details decide yourself; thinly discussed design = one short question with your recommended answer.
- Dave's style: SUCCINCT. Test reports "Test done: X pass, Y fail", one line per failure; simple fix = steps, big fix = say so; end posts with "Still waiting on:".
- Performance routine after client/server/streaming/flora/water changes (details in the archive, section "Performance routine").

## Where things are

| File | What it holds |
|---|---|
| `CONTROLS.md` | The player controls, now and planned. Update it when a control changes |
| `DESIGN_IDEAS.md` | The whole game design (16 sections), every decision tagged [Decided] / [Proposed] / [Idea] / [Open]. The permanent home for ideas to raise in design discussions and fold in when they fit; "(brainstorm)" marks ideas from the owner's ChatGPT sessions |
| `DESIGN_REJECTED.md` | Ideas the owner rejected (log them here automatically) |
| `DESIGN_PRINCIPLES.md` | Underlying philosophy (safe, kind, generous; do it yourself or hire it out; nobody is forced to build a town) |
| `GENERATOR_V2_PLAN.md` | Step-by-step plan for the world generator, with progress notes per step |
| `WORLD_FORMAT_SPEC.md` | Permanent file formats (tile file, Section 4b rivers and edge matching) |
| `src/worldgen/` | The generator code; tools in `src/worldgen/tools/` |
| `questions/` | Question page for Dave (QUESTIONS.md, ANSWERS.md, qa.html) |
| `data/` | JSON tables (items, network, tunnels, flora, soils, rocks, tile rules) |
| `src/` | admin, builder, client, debug, flora, server, shared, stream, water, worldgen |
| `tools/` | check scripts (check_warnings.sh, check_controls.py, items_check.py, bots.sh, ...) |
| `docs/archive/` | old handoff text, kept verbatim |

## Commands

Use the Linux engine build described under Setup below (`godot` here means that binary).

On Dave's PC (threads running locally via Remote Control, project folder `C:\GodotProjects\DynastyALWL`), `godot` means the editor executable `C:\GodotInstaller\godot.windows.editor.x86_64.exe`. Use it for headless runs and tests, e.g. `& "C:\GodotInstaller\godot.windows.editor.x86_64.exe" --headless --path . --script res://src/worldgen/tools/test_worldgen.gd`. Proven there (2026-10-22): `--script` runs work (validate_items.gd takes about 2 s, 0 errors); the voxel classes and water_core load headless; a bare `--headless --path .` (no `--script`) starts the game launcher and a terrain server, so never use it. The `.sh` tools run through Git bash (`C:\Program Files\Git\bin\bash.exe`) with a `godot` shim on PATH: `printf '#!/bin/sh\nexec "C:/GodotInstaller/godot.windows.editor.x86_64.exe" "$@"\n' > /tmp/gbin/godot; chmod +x /tmp/gbin/godot; PATH=/tmp/gbin:$PATH bash tools/check_warnings.sh` (about 20 s). `gh` is installed and logged in as DSul3791, so PRs can be opened from the PC. Never commit `crash_reports/`, tiles or the `~libwatercore` temp dll.

```
godot --headless --path . --script res://src/worldgen/tools/test_worldgen.gd        # tests (about 6 min, run in background)
godot --headless --path . --script res://src/worldgen/tools/bake_tiles.gd -- "--tiles=3,4;3,3"   # bake tiles to worlds/base_world/tiles/
godot --headless --path . --script res://src/worldgen/tools/edge_match.gd           # compare neighboring tiles
godot --headless --path . --script res://src/worldgen/tools/validate_items.gd        # item data validator (ids, numbers, unreachable recipes); also run test_inventory.gd and test_server_items.gd
godot --headless --path . --script res://src/worldgen/tools/build_tile.gd -- --tile=3,4          # preview pngs in plan/
godot --headless --path . --script res://src/worldgen/tools/terrain_bench.gd -- --tile=3,4      # runtime generator speed and cross-sections
godot --headless --path . --script res://src/worldgen/tools/flora_map.gd -- --tile=3,4         # top-down flora picture around the spawn
godot --path . res://scenes/terrain_preview/terrain_preview.tscn                              # walk the tile (needs a baked tile)
godot --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --port=24600     # terrain server
godot --path . res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1           # client (headless check: add --frames=6000 [--dig] [--cut]; --frames=12000 --walk checks landing, walking and tree collisions)
godot --path . -- --role=play                                                                  # host and play: starts a server in the background and joins it (the default role, so pressing Play in the editor does the same)
```

Baked tiles for the inner starters and their neighbors (36 files) are in `/mnt/project-files/tiles/base_world/`; copy them into `worlds/base_world/tiles/` at the start of a session. Tile files are git-ignored except the starter tile `worlds/base_world/tiles/tile_3_4.tile` (about 9 MB, committed so every session has it; recommit it only after a rebake that changes it). The starter tile is (3,4). Bake time is 25 to 70 s per tile (plus about 25 s setup).


## Setup a new session needs
- Cloud engine: unpack `/mnt/project-files/engine/godot-4.7.2-voxel1.7-linux-headless.xz` with `xz -dc file > godot && chmod +x godot`.
- Dave's PC: editor `C:\GodotInstaller\godot.windows.editor.x86_64.exe`, project `C:\GodotProjects\DynastyALWL`; headless via `--script` only (a bare launch starts the game server). Ffmpeg is missing there (sound tools only).
- Baked tiles: `/mnt/project-files/tiles/base_world/` into `worlds/base_world/tiles/`. Git ignores tiles except `tile_3_4.tile`.
- Python 3 for the check tools. No GitHub CLI in the cloud: use the GitHub tools.

## Gotchas (short)
- Headless scripts: use `preload` consts instead of `class_name` globals.
- Run bakes and the test suite in the background and poll (a foreground run over about 10 minutes is killed).
- Commit a new script's `.uid`. Re-read shader edits: a failed compile draws flat grey.
- World is 21x21 tiles (-10..10), wraps both ways; starter tile (3,4); tiles are 1,921 samples at 8 m with an 80 sample margin.
- In the cloud engine a headless load prints no warnings; the warning count comes from the local `tools/check_warnings.sh` run.

## Index of the archive (`docs/archive/HANDOFF_FULL_2026-10-22.md`, line numbers of that file)
- 1-26: first task, what this is, file table. 27-77: working rules and dated owner decisions (fall columns and water volume, flow x10, river mouths, and more).
- 78-88: generator status (steps 2 to 16). 89-110: commands. 111-131: reading big files, working with David, setup.
- 133-146: gotchas, open design items. 148-169: performance routine, ground loading speed.
- 171-180: "Water and terrain: start here" (outgoing water thread, 2026-10-20). 181-235: water state, open problems, HUD, quality tiers, stances, oxygen, tile-border water, cold generation speed.


## Parked for tomorrow after the backup (Guru 01:55 UTC 23 Oct)
- Merge claude/sal-rock-pile (RESTART, local_check PASS per Sal), not in head 695. Next-night test line: "Please test: craft a rock pile from 45 stones, set it down, press E. Look for: 45 stones back in the pack; hold E instead and you carry the pile."
- Ask Kathleen for the rock pile and wagon-load looks.
- Merge Sal hoe-hold test line already posted tonight (hoe-hold card).
- Merge claude/kathleen-wet (RUNTIME, wet-tunnel sounds, nothing calls them yet) with the other held branches; not in head 695.
- Merge claude/steve-esc-test (headless Esc test only, no game code).
- Merge claude/steve-drip (undersea drip detection, RESTART, protocol 73: Guru protocol-bump check first); not in head 695. Ask Steve for its next-night test line.
- steve-drip next-night test: "Please test: dig a tunnel in rock off the beach and go under the sea until the ceiling is within about 4 m of the water above, or under a lake or river. Look for: drips falling from the ceiling, a dark wet patch on the floor under each, nothing collecting, no drips once you are more than 4 m under the water."

## Parked 02:15 UTC 23 Oct (Dave: no more work tonight)
- Head = build 695 (MikeW recheck and Dave's pull/"starts and plays" still pending; then backup).
- Tomorrow first: (1) sweep answers newer than 02:00 UTC (12 tests, esc-character-2, far-water-2, river-mouth-dam, loose-fill-slope, lake-min-size, beach-loud, item-recipes-2) into DECISIONS.md and relay per thread; (2) merge held branches after backup: sal-rock-pile, kathleen-wet, steve-esc-test, steve-drip (protocol 73 check); (3) Sal blueprint build system; MikeW+Sonny BAKE-1 test.
- QA page is v9 (self-reloads). Dave closes and reopens the tab once.
- Off-hand items (Dave 02:50): hotbar select puts torch/shield in left hand, select again stows it, hold B to block. B is unused (checked). Card offhand-items posted. If Yes: Steve input and slot, Sal off-hand flag on items, Kathleen pose.
- P1 BUG (Dave 02:54): mined soil and rocks too heavy to hold drop out but float in the air. Fix: they fall to the ground, stay pick-up/movable, roll a little when walked over. Owner Steve (drop physics, server_items.gd); sal-rock-pile does not touch drop physics (checked), so no overlap. Test card for Dave after the fix: "dig soil/rock too heavy to hold, look for it landing on the ground and rolling when walked over".
- Ground piles (Dave 02:56): merge same-kind loose items within ~1 m into one counted pile (MAX_DROPPED_NEAR 64 in server_items.gd). Card ground-piles posted. If Yes: Steve merge/split rules, Sal counts, Kathleen looks; ties to sal-rock-pile.
- P1 FIRST TOMORROW (Dave 02:56): too many loose items on the ground (limit 64 within 12 m, server_items.gd MAX_DROPPED_NEAR) and he cannot empty his inventory. Steve: admin "clear dropped items" button in Esc > Admin and/or raise the limit in the test world; do this BEFORE the ground-piles design. No existing clear-items command found.
- ROCK PILE design (Dave 02:59): drop rocks in one place = merge; <=5 look like one rock, >5 a generated pyramid pile from the count (rows 1,3,5,7...), almost no limit. Steve merge/split, Sal counts/pickup, Kathleen generated look; see DECISIONS 03:00. Do it AFTER the P1 clear-items fix.
- Rock pile full design: tech/items/ROCK_PILE_DESIGN.md (Guru 03:10 UTC); 6 cards rockpile-* posted. Build after P1 clear-items.
- Steve bug (cave-in timer, tunnel_watch.gd grace_ms line 170/tick 272): changing cave-in time does not update running windows; fix = set_cave_in_s rewrites running cells grace_ms, keep opened, min 90 s warning ahead; RESTART, no protocol change; Steve adds test on a steve branch. Approved by Guru (technical).
- Cave-in death sequence (Dave 03:13): design tech/CAVE_IN_DEATH_DESIGN.md; 5 cards cavein-death-* posted. Steve sequence controller, Kathleen skull art + audio + placeholder stings; voice later via Kokoro (subtitle text now).
- Water surface flickering textures at the lake (Dave 03:20, grey shapes are the water, not boulders): Sonny checks the shader and water draw, Steve the sim updates. Card lake-chunks-pic asks for an F3 picture.
- Head ponds (Sonny 03:22): stamped round head ponds retire in favour of terrain B basins at the next bake; card head-ponds-retire; first natural result needs a look from Kathleen and Dave. Needs 1-tile BAKE-1 test first.
- BP-T42 safe place wording (Dave 03:32): Sal sweeps flora.json "womens_health" (line 1877) and all item/plant/recipe text tomorrow; one line to Dave. Raspberry bush look + berries to Kathleen (Dave pictures in chat).
- BP-T43 after hours: Dave asks only, branches only, Guru merges; head 695 stays while Dave plays.
- Lake flicker (Sonny hypothesis): cards lake-hide-water (Ctrl+Shift+W) and lake-low-quality (F2 Low) posted. Branch claude/sal-safe-text (data only, raspberry womens_health -> soothing) held for next build.
- MERGE PLAN (Dave 03:35): when Dave says he is done playing: merge ready branches in this order, local_check after each, protocol check: 1 sal-safe-text (data), 2 kathleen-wet, 3 steve-esc-test, 4 sal-rock-pile (RESTART), 5 steve-drip (protocol 73), 6 any new ones; then MikeW recheck + fresh backup. Then tell Dave the new build number.
- Add to merge list: claude/steve-cave-in-setting (RESTART, cave-in timer fix, test added). Next-night test: "Please test: dig a cave, set the timer to 2 minutes. Look for: rumbling starts after the quiet part and the fall about 2 minutes later (or 90 s after the change if already past)."
- Add to merge list: claude/kathleen-torch-rain (RUNTIME, sound only; no local_check run by Kathleen, run it). Next-night tests: "Please test: hold a torch in a cave. Look for: quiet soft crackle, no loud echo." and "Please test: stand in open rain, then under a roof. Look for: no sharp clack in the open, clacky rain only under the roof."
- Add to merge list: claude/sal-admin-craft (admin free crafting, ON by default, RESTART; local_check PASS per Sal) THEN Steve admin-mode switch branch (name to come). Test line: "Please test: as an admin open the crafting list and craft an iron pickaxe or a forge recipe with an empty pack. Look for: crafting with no ingredients; with the Admin switch off the normal rules return."
- sal-admin-craft also has: press E on a recipe in the crafting menu to craft one (no key clash per Sal). Test line: "Please test: open the crafting menu, select a recipe you can afford and press E. Look for: one item crafted."
- Wood chain (Dave 03:51): log + axe -> wooden blocks (0.3 m) -> chopping block -> split firewood -> pile from 5 (rock pile mechanism). Sal fixes chopping block recipe (needs wooden block); Guru turns Sal numbers into a card.
- Merge list: claude/sal-wooden-blocks (RESTART, local_check RESTART PASS per Sal): chopping block needs a wooden block; log 4 blocks, shoulder log 12 blocks, 1 block = 1 firewood; shoulder log is one extra slot; wagon inventories need Steve later. Cards blocks-from-log, blocks-from-shoulder-log, firewood-from-block, axe-wear-chop posted.
- Tree species uses (Dave 03:57): draft tech/items/TREE_SPECIES_USES_DRAFT.md, cards species-uses-1..4; Sal builds later.
- Merge list: claude/kathleen-log-carry (RUNTIME, 1 line: shoulder log 0.45 m forward). Test card ready for the build after merge: "Please test: pick up a log onto your shoulder. Look for: it is centred front to back on the shoulder, not too far back." Log looks by species (Treename_Logs) wait on Sal item ids: Sal sends ids to Kathleen via Guru.
- Merge list: claude/sal-tree-logs (on top of sal-wooden-blocks: merge that first). Cards logs-per-tree, small-tree-work, log-names posted. Kathleen has log ids for trunk looks.
- Merge list ORDER: sal-wooden-blocks, sal-tree-logs, THEN kathleen-log-looks (includes log-carry fix; kathleen-log-carry can be skipped). No Godot run for log-looks: MikeW local_check. Test lines for the build after merge: "Please test: cut an oak, then a birch. Look for: logs on the ground and on the shoulder: oak grey-brown, birch pale white-grey, centred over the shoulder." and P "Please take a picture of an oak log and a birch log on the ground at your spawn x 53301, z 68427." Card "Do logs look like their tree now?" (recommend Yes).
- Rename (Dave 04:03): Clear saved ground -> Clear blocks (local block copy). Steve renames the label and adds admin "Reset all terrain edits" (server side). 9-tile bake: Dave presses Clear blocks only.
- TOMORROW (Guru): untrack crash_reports/ (git rm --cached, add crash_reports/ and telemetry_server_*.log to .gitignore) so nobody re-commits them. Note: on Dave pull, files removed from the repo disappear from his working folder too (they are only logs); tell him first.
- Sweep 4 (04:25): Dave YES to rock piles (all six), cave-in death (slow, fade, skull, cave-in only), off-hand items, head ponds retire, spade raise, vsync, fire sound. NO: beach run too loud (walk slightly, run much), voice: use TTS to make real lines, lake flicker is the water texture itself (not depth, not ground), cave-in timer retest after 698/699. See DECISIONS 04:25.
- (LIFTED 04:40: evidence copy exists at E:\Software\godotDev\DynastyALWL_Evidence\2026-10-23_dry_river\; digs.dat has no edits within 30 m of the dry spot) DO NOT RESET TERRAIN EDITS YET (Dave's dry river channel x 51605-51610, z 69289-69364 is evidence): MikeW copies digs.dat and the water folder to a dated folder; only after Guru confirms the copy exists may Dave press Esc > Admin > Reset all terrain edits. Card reset-edits-test says so.
- UNMERGED BRANCHES (left on purpose, 04:40): kathleen-spades, kathleen-materials, kathleen-shovel (superseded), steve-warning-699 (duplicate), project-thread-sp0ppw (old). Everything else is in head 701.
- BACKUP: tonight (22/23 Oct) already done per Dave; no further backup requested after later merges unless Dave asks. MikeW: first job tomorrow is only the build 701 recheck.

## BAKE SCHEDULE (Guru owns; BP-T31 amended 2026-10-23; nobody bakes alone)
- Rule: full tile rebuilds need no permission from Dave. One bake for everyone who needs it; occasional; tile copy outside the repo first; MikeW runs it on Dave's PC; never commit tiles; Sonny re-settles water after; then a QA card tells Dave: 1. Fetch origin and Pull. 2. Esc > Advanced > Clear blocks. 3. Close the game fully, start it.
- Queue (who wants a full rebuild, why): (1) Sonny: terrain B drainage ON + stamped head ponds retired (card head-ponds-retire answered Yes) , waits on the 1-tile BAKE-1 test with MikeW first. (2) any other thread: ask the Guru.
- Next slot: after BAKE-1 test result and Kathleen/Dave look at the first natural basin result; not before.
- Done so far: tiles b1fb0c9, TERRAIN_VERSION 25 (22:55 UTC 22 Oct).
- OVERNIGHT SELF-TESTS (Dave 05:00): tech/OVERNIGHT_TESTS.md; results one line each in tech/OVERNIGHT_RESULTS.md; when done everyone STOPS; Guru posts one Finished card.
- Sweep 5 (11:35 UTC 23 Oct): see DECISIONS. Sal: 2 firewood per block, ONE log item (shoulder log = pack symbol, 12 blocks), species class/hits/burn per tech/items/TREE_SPECIES_USES_V1.md. MikeW: t16 shoulder log centring with the look rig (Dave is away). Guru: slimming docs = archive, never delete; build merge guard + id claims + inbox files.
- Kathleen flora audit v1 (11:17 UTC): art/FLORA_AUDIT.md: 127 plants: 21 own model, 23 plausible generic, 83 probably wrong (about 50 real plants + 33 fantasy). Plan: real plants first (berry bushes), one simple accurate model per group, one Yes/No picture card each (she posts via tools/qa_post.py, BP-T47). MikeW: rig renders of raspberry, bramble, nettle, wild rose as they stand now.
