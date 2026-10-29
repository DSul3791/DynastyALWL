# Mandy_001 handoff (Arts Director) -> Mandy_002

## Role and rules
- Project "Dynasty a life well lived", game DynastyALWL (Godot 4.7.2, GDScript), repo dsul3791/dynastyalwl.
- I own how the world looks and sounds: trees, flora, grass, character/NPC/animal look and animation, first-person arms, water look, sky, weather look, buildings/stations look, SOUNDS and VOICE (Kokoro TTS, never Chatterbox, never espeak-ng).
- Work ONLY on branch claude/generator-v2 (Dave merges). Never bake/commit tile files; never touch generator, TERRAIN_VERSION or world data.
- Dave uses voice: short plain replies, no em-dashes, every post to Dave ends with "Still waiting on:". Only mcp__hearthbot__ tools reach people; end every turn with one. Reach other threads only via message_coordinator.
- Claim a build: append a line to /mnt/project-files/tech/BUILD_LOG.md and set `const BUILD` in scenes/terrain_client/terrain_client.gd (~line 70). Re-check both right before pushing (clashes are frequent). Last build mine: 586.
- Before every push: pull --rebase --autostash, headless client load, `tools/check_warnings.sh --changed` (needs `godot` on PATH). New code must give ZERO GDScript warnings.
- Commit trailers: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_014FFQ9y2Dt37Km9PV91zeGS`. Push: `git push -q origin HEAD:claude/generator-v2`. Never `pkill -f`/`pgrep -f`.
- Pickable-answer questions for Dave go in questions/QUESTIONS.md (format questions/README.md), answers in questions/ANSWERS.md; report "Question added: <title>". No tasks in that file.
- Dave: "don't chase ghosts" (random crash analysis waits for Willy's crash reports). DEV STOP is in effect (01:08 UTC) until the crash is found: start no new jobs.
- Ownership: Radar owns inventory_view.gd, data/items, server_*, data/stations. Willy owns ground, HUD, settings, crash report. Sonny owns water sim and water_falls.gd. Steve = Technical Director. Shared files: small appends only; ask via coordinator before touching others' files.

- RULE (Dave, 01:23): every pickable-answer question for Dave goes ONLY in questions/QUESTIONS.md on claude/generator-v2 (format questions/README.md), then report "Question added: <title>". Never ask Dave anywhere else.

## Done (latest pushed state: build 586, commit 8d21691)
- Sleep shares the faint visuals (544); felled-log grass flattening (550, 554, 557); grass trails with game-trail blocks and Tracking multiplier (551, 561); first-person arms and chop rebuilt (556); shoulder log carry (559); audio audit, Esc>Advanced test switches (src/client/test_switches.gd), warning cleanup (574); wolf model and gaits (579); warning cleanup of all my files (586).
- Art stills in /mnt/project-files/art/ (chop_top_555, carry_559, wolf_poses_575, river/lip stills, fall_list_577.txt).

## In progress
- Live fall re-shoot on build 584 for Sonny (server NOT --settled-water, 5 minute wait): script $S/run/fall_live.sh (scratchpad, likely gone). It died without producing shots. NOT finished. To redo later: start server `gv --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --port=24611 --store=DIR --quit-after=2400`, wait ~5 min, then `shot.sh 3 200 60 "warm:53640,12,69337,90,-10,10,clear;river_above:53640,12,69337,90,-15,10,clear;lip_above:53600,30,69300,90,-25,10,clear;lip_front:53540,20,69130,-90,25,10,clear"` (shot field name:x,agl,z,yaw,pitch,hour[,weather]; first shot is warm-up; Xvfb :99 dies, restart with setsid nohup). Post stills plus fall list to /mnt/project-files/art/ and tell Sonny.

## Open queue (order)
1. Animal art per items/ANIMAL_ART_NEEDS.md: horse (wild and tamed), moose, fox, duck. Wolf growl/howl clips and limp animation (`items.limp_share`).
2. Bed-line banding and scree on layered rock: shaders exist in ground_material.gd; render a cliff face on the new tiles and change only if wrong.
3. Verify game-trail drawing once Radar's server trails exist; shoulder-log species length (not sent by server).
4. Tyler Reports 22 (skies), 23 (tall fall look); tree jobs; live AI NPC speech (text is always the trigger, voice generated per client); blood-trail look; NPC micro-idles; inner voice wiring; hammer swing.
5. Sounds are on HOLD except fixes Dave hears wrong, NPC voice, wolf sounds, faint/sleep heartbeat, tool thump.

## Decisions and why
- Chop: wrist cock and flick, impact at 0.35 s of 0.55 s, hit stop 45 ms, only a thump at impact (Dave removed the whoosh). Left hand never moves unless it holds tool/shield/torch. Hands hang below screen bottom; held item independent of camera.
- Trails: grass takes 5 real minutes to rise; animals/NPCs leave trails (12 nearest); Tracking skill lengthens visibility on own client.
- Felled log: grass flat under and 0.3 m beside, soft edge, none inside the log (data/look/placed_clearing.json).
- Only one large log carried at a time, on the shoulder.

## Traps
- Python line splices once deleted ~1,770 lines of terrain_client.gd; use exact-match edits and check `git diff --stat`.
- Renaming a shadowed local replaces every occurrence in a file; check each use (tree_builder `lean` bit me).
- Shot images are 2880x1620; shot server must use --settled-water only for quick stills, live flow needs minutes.
- Unconfirmed on screen (stills only): chop timing, first-person carry log, log grass. Dave owes looks at builds 556, 559, 561.
- This engine build prints no warnings without --debug.

## Dave is waiting on
- Nothing from me except the crash investigation (Willy). Dev stop in force.
