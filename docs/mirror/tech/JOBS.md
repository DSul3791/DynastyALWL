# READY QUEUES (Tyler, 23 Oct 22:55 UTC; Dave: "nobody should ever need to be idle"; this block overrides everything below)
Rule: when your current job finishes, or waits on Dave, Mike's batch or another thread, take the NEXT line here without asking. Tell Tyler only when you START a job that needs a branch (BP-T50 action plan), Tyler's GO is already given for lines marked GO. Tyler refills this block every day and at every merge.

## Steve (queue 7)
1. GO: finish berry picking (steve-berry-picking) review fixes after Mike's batch; then step 2-4 of harvest naming.
2. GO: steve-sound-3d (directional sound) ear test notes for Dave's card.
3. DONE (steve-water-flow-at pushed, merges after Mike PASS): next take line 4.
4. GO: wet tunnel sounds by ear (rig + Dave's ear card).
5. Dry river test: live dump in Dave's world (needs v26 tiles loaded; Mike runs it, you read the dump).
6. Shrub LOD / carpet (after berry branch merges).
7. Cave-in timer retest (collapse default 5 min, setting 2-20 min).

## Sonny (queue 6)
1. GO: claude/sonny-flora-patches (patch placer, shared 1-3x scale per patch, tight spacing, flora layout VERSION 2).
2. Re-settle water after v26 tiles (Dave presses Clear blocks first).
3. Valleys check on claude/sonny-valleys, v27 bake bundle prepared (no bake until Dave OKs v26).
4. flora_map.gd: headless --import check (not broken, just verify).
5. Island shape plan next step (ISLAND_SHAPE_PLAN.md) docs only.
6. Edge match + 6-spot screenshot set after any generator change.

## Sal (queue 7)
0. FIRST JOB 24 Oct (Dave 23:51): showroom rows at spawn STAY but become REAL items (pick up, use, inspect/ID). Sal leads ONE combined action plan with Kathleen's Kathleen_ground_items.md; Tyler reviews once and gives GO with best practices (BP-T52).
1. GO: sal-harvest (yield_scale clamp 400, elder base 130) after Mike's batch.
2. Blueprint 1c.
3. Uproot/replant (protocol 75 after Steve's 74 merges).
4. Sawmill chain step 2: call is items.water_flow_runs.call(a, b) (steve-water-flow-at, merges after Mike PASS; branch from head after merge).
5. T-plans: T-WALLVAR, T-HOEGRADE, T-SPECIES tests written up for Mike's batch.
6. Cost table remaining items, one line per card.
7. Hoe/shovel feel notes after Dave's 764 test.

## Kathleen (queue 7)
1. NOW: claude/kathleen-patches-now (f0d9b56, flora.json only, RESTART) goes in Mike's batch; claude/kathleen-bramble already in head (769).
2. GO: mid-distance shrub LOD in tree_builder (push the branch, not yet on the remote).
3. Reeds and ferns finish, herb look checks (white flowers off-season for blackbramble/apple).
4. Skull PNG and death voice (Dave to record or approve placeholder).
5. Shrub pictures after final head (ONE labelled picture via Mike, BATCH RULE).
6. Log wall notches, doors, ceiling/flat tarred roof looks, brace looks (older list below).
7. Herb patch data once Sonny's placer is in.

## Mike (queue 6)
1. ONE batch now (exact list and order in tech/MERGE_CHECK_TONIGHT.md; kathleen-patches-now is replaced by sonny-flora-patches): pull head 770 + steve-sunny-button (flip at night/rain and back) + sal-sawmill-rules (includes water-flow branch; run test_placement_rules, 4 new checks; in game place a lifted foundation beside a stream, then the sawmill kit with the wheel over moving water) + steve-water-flow-at (66470d2, RESTART; run godot --headless --path . --script res://src/worldgen/tools/test_water_flow.gd, expect 0 failures, time one runs() call) + kathleen-patches-now + steve-berry-picking + sal-harvest + steve-sound-3d, local_check (baseline 233), parse, test_server_items, check_controls, T-BERRIES, prompt picture, herbs/mushrooms/shrub rows, bramble before/after, Ctrl+Shift+G frame time on F2 Low <33 ms. Report PASS/FAIL list.
2. Dry-river live dump (Esc > Admin > Dump water here, 60 s, x 51609 z 69364).
3. Sonny valleys check (TERRAIN_VERSION 27 bundle) after Dave sees v26.
4. Sal BATCH_Sal_001.
5. ONE labelled shrub picture (--flora raspberry,bramble,wild_rose,blackthorn,blueberry --views "wide:8:-8:1.5;close:4:-15:1.0" --nograss).
6. 9 pm ADT backup; 8 AM ADT handoff + reset. Stop one-at-a-time renders.

## Tyler (me)
Merge queue after Mike's PASS: sal-sawmill-rules (with or right after steve-water-flow-at), steve-water-flow-at (RESTART), steve-sunny-button (GO given, RUNTIME), kathleen-patches-now, steve-berry-picking, sal-harvest, steve-sound-3d, sonny-flora-patches. Then post Dave's pull steps (close game fully). v27 bundle only after Dave OKs v26.

# CURRENT TOP JOBS (Guru, 2026-10-23 00:10; this block overrides the older lists below)
- Steve: 1. Turn the tunnel collapse ON in Dave's test world (his YES) with the cave-in duration as a SETTING (2 to 20 min); 2. support spheres of influence (radius 5 / 7.5 / 10 m at full health, halves at half health, overlap covers an area; degrade slowly when unmaintained); 3. blueprint snapping and load rules with Sal (wide snap, 3 spaces, load limit like Valheim); 4. then other players' worn-clothing sync (protocol bump), characters.json write batching, join-window glue.
- Sal: rework the blueprint design to Dave's answers (DECISIONS 2026-10-23 00:10 items e to k), twine rename everywhere (no migration), brace blueprints in 3 sizes, ceiling and flat tarred roof, chopping block 18 kg, then the cost table list for Dave one line per card.
- Kathleen: log wall notches (copy a real log cabin), doors (no bottom edge, handles not knobs, steel handle, no black band), ceiling and flat tarred roof looks, brace looks.
- Sonny: ground rework (hydrology) continues; no bake without Dave's go.
- MikeW: local_check on 681-683 and later; render checks; nightly backup on goodnight.

# Job queues (Technical direction, 2026-10-20)

Rule (Dave): threads never wait for him. Finish a job, ask Technical direction for the next build number when you start a job (cross-session message, session `cse_0111SmjyMaTAj3PtyQqHboYJ`), take the next job in your queue, stop only when you need Dave. If you need him, send the coordinator ONE question with 2 to 4 short options and a recommended one, then take the next job that does not depend on the answer. Items marked **ASK** are thinly discussed design (confidence rule): ask first. Everything else is well covered: just do it. Approval: big changes only (PROCESS.md). Every job: run the performance routine, state the cost at Low, keep Dave's rules (server/client/admin separation, Dave bakes tiles, no tile bakes in the cloud, minimum 1050-class machine).

## Water and terrain
1. Finish the open re-bake bundle (ore cap 91, brook depth 94, pond spring flow 95, outlet fix) and hand Dave the bake steps once.
2. Send the real flow speed to clients and smooth between water updates (water review item 4 and 6; client work is shared with Art, tell them).
3. Save terrain edits and water across restarts: check that dig edits survive a restart and a re-bake (Technical direction contract; approval needed for store changes).
4. Water across tile borders, so a river leaves tile 3,4 and continues (water review item 3).
5. Fine 1 m water patches around players and edits (ditches, small dams) once item 3 is done (approval: architecture).
6. Rain closes the water loop and rivers swell after rain. Weather is decided (DESIGN_IDEAS 4.2: zone + season + town-spirit modifier, placeholder constant). Build the server weather state with those three inputs, then rain feeding the water sim and river swell.
7. Underwater look and shoreline: with Art direction (they own the shader, you own the water depth data).
8. Smooth pushed-up pond edges and the remaining hand-made features (8 starter bays, everember grove) into generator rules.
9. Ore outcrop look and follow-the-vein groundwork (after 91).
Fill-ins: run the edge match and test suite after each generator change; sample a 6-spot terrain screenshot set per bake; check brook slope on all 9 tiles; keep HANDOFF.md water section current.

## Art direction
1. Ground textures (done in 84): tune on Dave's feedback, check Low (512 px, no height blend).
2. Grass that covers the ground (ART_DIRECTION step 3): denser alpha-to-coverage clumps, ground tint matched, radius and density per tier.
3. Tree crowns (step 4): leaf-cluster cards, bent normals, crown AO, back-light, bark normals, and the rounded tree base Dave reported. Impostors for far trees: the LOD format needs Technical direction approval before models are final (joint job with Ground loading item 6).
4. Clear water shader (step 5): bed visible, depth tint, reflection, foam; Low = sky reflection and tint only.
5. Rock and small details (step 6): moss, pebbles, sticks, boulder meshes near the player (forest floor objects: fallen branches and leaf litter first, Dave 2026-10-20; reeds, driftwood and pebbles after).
6. Slope and elevation flora look (job 90): keep Dave's alpine rules.
6a. Sun, sky and lighting follow the game clock (`game_clock` on the client, hour and season; day length by season in DESIGN_IDEAS 7.5): sunrise and sunset, moonlight, no pitch black. Quality-tiered.
6b. Weather look (Dave 2026-10-20: rain needs clouds, bigger storms darker clouds, biggest storms thick dark clouds plus lightning; never rain under a clear sky): rain, snow, storm sky and fog from the server weather state, quality-tiered (Low: fewer particles, no volumetrics); start after Water item 6 gives the weather state.
7. Character and building look: slightly stylised heroic (Dave, 2026-10-20); Q2 is answered, no need to ask.
8. Rock and small details part 2: pebbles and gravel at stream banks, boulder meshes, moss on rocks and north sides of trunks, reeds at pond edges, driftwood on shores; MultiMesh, tiered, Low none or small.
9. Asset budget table (triangles per tree per LOD, texture sizes, alpha overdraw, MultiMesh cards per tier) in ART_DIRECTION.md with measured numbers; send to Technical direction.
10. Look of what Items builds: lean-to, storage chest, woven chest, chopping block, campfire kit, held tools and items (stone axe, spear, torch); slightly stylised, shared meshes, no per-frame cost; coordinate mesh hooks with Items through me.
11. Wind direction cue (Dave's future idea): drifting pollen, leaves and dust that show wind direction, none at sea; cards near the player only, off at Low; cost stated.
12. Before and after renders for steps 3 to 6 plus the waterfall base (headless captures with the software renderer) saved in /mnt/project-files/art/ for Dave.
13. Cloud and storm sky pass with Dave's rules (rain needs clouds, bigger storms darker, lightning at the biggest) checked against the server weather state at four times of day.
Fill-ins: before and after renders per step; Low-tier cost table per step in ART_DIRECTION.md; asset budget table (triangles per tree per LOD, texture sizes, alpha overdraw) with Technical direction.

## Basic world sounds
**ON HOLD (Dave, 2026-10-21 01:24): finish the sound job that is running (89 wind in structures), then STOP. Every other Sounds job below (74, 85, 90, 91 and any later ones, including the Sounds part of pond ice) is ON HOLD until Dave lifts it: sound is ahead of development. No refills, no new numbers beyond the running job. Sounds may only fix bugs Dave reports.**
1. Nature ambience layer (job 93) and wind floor (92).
2. Water sounds: brook, river, pond shore, waterfall, positional, max 4 at once; uses the existing water depth lookups.
3. Day, night and season changes of the ambience (crickets at night, birds at dawn, quiet winter).
4. Weather sounds: wind strength, rain on leaves and water, thunder (follow the server weather state once Water item 6 exists; hooks first).
5. Tier audio budget in code: cap simultaneous sounds (Low 24, Mid 48, High 96), short sounds in RAM, long beds streamed, total loaded under 150 MB at Low; HUD readout of voices.
6. Footstep polish for the new grounds (ore, mud, outcrops) and a sound volume mixer (wind, ambience, steps) in Esc > Settings.
7. Dig sounds by material (build 110).
8. Cave and tunnel reverb plus dripping under rock.
9. Thunder with distance delay from the weather storm value (lightning flash timing with Art).
10. Cheap occlusion: muffling behind hills and inside dense forest.
11. Water loops tuned by real flow speed and depth (flow velocity is in the water chunk since build 101; brook babble vs river roar vs pond lap).
12. Valley and ridge wind: wind loop pitch and level by terrain shelter and altitude, tied to the weather wind value.
13. Sound pack manifest: a file listing every sound slot (name, where used, generated or recorded, what Dave could supply) so Dave can see which recordings are still needed.
14. Hit, tool and impact sound slots (axe on wood, pick on rock, hammer): basic set only (axe, pick, hammer, spade on wood, stone, soil); Q5 answered, no need to ask.
15. Town placeholders (bell, hammering, fire crackle, crowd murmur) as client hooks driven by a position and a kind, no town system needed yet.
16. Swimming and diving sounds: splash on entering water by speed, strokes, surfacing breath, underwater ambience (muffle exists).
17. Wet and snowy ground: footsteps change after rain and in snow from the weather state (puddle splash, snow crunch), plus rain dripping under trees.
18. Interface sounds: menu clicks, inspection-mode toggle cue, quality change, quiet and optional.
19. Creature calls by zone (birds, deer, rabbit, fox, wolf, bear; Q6 answered (b)); build the hook (kind, position, distance) meanwhile.
20. Wiring for Art: play thunder from Art's lightning flash event once it exists (they call `sound.weather.lightning(at, distance_m)`).
21. Music: none for now (Dave, 2026-10-20); skip.
Fill-ins: replace generated sounds with recordings when Dave supplies packs; loudness pass per surface.
55. Waterfall base sound to match Art's spray and wet-rock look (build 236): close hiss and splash bed under falls, level by drop height and flow; shares Water's fall columns; cost at Low stated.
56. Stance and cloth sounds: crouch, sit and lie rustle, getting up, settling; hooks on client.stance.changed; body sounds quieter while crouching (footsteps softer); no new loops.
57. Exertion audio gaps: check the full chain normal, over-exerted, fainting, fainted, waking against Items' strain states (breath loudness, recovery while sitting or lying); add a scenario to tools/sound_check.py.
58. Controls audio: UI sounds for inventory open/close, craft, drop, hotbar select, chest open; short, quiet, one shared bus; a mute rule when the inventory is open for world sounds? (ask: no, keep world sounds running).
59. Stream recording swap when Dave supplies water_brook.ogg: run assets/audio/swap_recording.py, loop-point check, level match, update CREDITS.csv (waiting on Dave, do not block on it).
60. Audio memory and voice budget re-audit at Low after jobs 55 to 59 (voices at spawn at night and in rain, decoded memory vs the 150 MB cap); send numbers.
61. Gaps pass: list every action in CONTROLS.md and Items' ACT kinds without a sound and add to tech/ a table (action, sound, status); fill the cheap ones.
63. Structure and tool sounds: place and take down lean-to, chest, campfire kit, chopping block; tool wear warning and tool break cue; hooks on Items' events, ask Items via me for any missing event.
64. Voice priority at the 24-voice cap: never shed the player's own footsteps, breath, heartbeat or UI; shed far ambience first; add a scenario that fills the cap and asserts the protected sounds still play.
65. Sound emitter API for server-side entities (animals now, NPCs and carts later): a small data call (id, position, kind, state) the client turns into voices with the same cap and distance rules; design note first in sound/, send to Technical direction before building.
66. Season and clock check: day/night, season and weather cross-fades (birds, insects, frogs, wind) across a full 24-hour and four-season sweep headless; no silent gaps, no pops; report a table.
67. Mixer pass: per-bus loudness table (weather, water, fire, steps, creatures, UI), safe maximum so nothing clips on a 55 inch TV speaker setup, and the sound volume row in Esc > Settings extended if Dave wants buses (ask via me first; CONTROLS.md if a key changes).
68. Fall damage and landing sounds once Items provides the hook (see Items job 62); until then, landing thud by fall height only.
69. Wet shoes: squelch steps after leaving a river or pond, drying over about 20 s (Sounds' pick, cheap, heard every minute).
70. Cloth rustle that scales with walking speed (walk, jog, run, crouch), one-shots tied to steps, no loop.
71. Missed axe, pick and spear swings (whoosh with no hit), tied to the held item swing.
72. Quiet summer day insect/grass-cricket bed: one loop at most, not under cover in rain, seasons and clock from the sweep; cost at Low stated; check voice cap.
73. Rejected-action cue once Items job 62 gives the reject event; until it exists, build the call point only.
74. Distant town murmur and dog bark through the emitter API (emitters.gd town loops); test with fake events; wait for real town entities before wiring.
75. Rain on roofs interior pass: under a lean-to or tree crown rain patters on the roof overhead and the open-air rain bed drops, using Cover.at; fires under cover keep their crackle; cost at Low stated.
76. Per-surface loudness re-balance against the real ground (grass, sand, gravel, mud, rock, snow, wood floor, water edge) with a table of dB per surface and gait; Dave tweaks from a data file.
77. Night ambience pass: owl, night insects, distant wolves by season and weather, using existing emitters or creature hooks; check the voice cap at night in storm.
78. Update sound/RECORDINGS_WANTED.md with what Dave's stream recording taught (EQ, level) and the next five recordings that would most improve the game, ordered by how often a player hears them.
79. swap_recording.py water preset (brook EQ and level) so Dave's raw files just work, with a before/after level table.
80. sound_check scenario that plays every sound slot once and flags clipping, silence and wrong loudness.
81. Cave and tunnel reverb by enclosure (cheap bus effect, off or lighter at Low), cost stated.
82. Distance low-pass for far thunder and waterfalls (and far fires), by distance and cover; one filter per bus, not per voice.
83. Rain splash per ground surface (stone, grass, sand, water) near the player, one-shots, budget-checked.
84. Door/chest/structure open and close sounds when Items has those events (call points first).
85. Bell and town-spirit weather cues via emitters once a town entity exists (waits with 74).
86. HUD sound debug: per-bus meters on F3 Debug details (debug_hud.add_line), cost only while shown.
87. Voice cap audit at High and Ultra tiers in the worst scene (storm, night, fires, creatures, town), with the numbers.
88. Snow footstep and ice crack sounds plus frozen pond sounds, by season and ground state.
89. Wind in structures: whistle through a lean-to or cave mouth, level by wind and enclosure; cost stated.
90. Batch recording swap helper: a zip of Dave's files in, the swap_recording presets applied, level table out.
91. Tune pass on Dave's feedback once he has heard builds 267, 279, 289, 291, 295 (needs his ears; the coordinator will ask).
92. Bird and insect variety by season and hour: species tables, no repeats within a minute, quiet hours; sweep report.
93. Footstep surface coverage audit: every ground material and floor has steps for each gait; table of gaps and fills.
94. Listening checklist for Dave (sound/LISTEN_CHECKLIST.md): lake, brook, wing flaps, wet shoes, night ambience, cave echo, rain drops, falls, each with where to stand and what is right or wrong; the coordinator gives it to him.

## Ground loading and performance
1. Run the performance routine on the current branch (flight check plus frame probe) and report numbers; this is a standing job after every other thread's push.
2. Hunt the 100 ms worst-frame spikes Dave saw while ground was loading (first jitter-test screenshot); find the main-thread piece with Probe.
3. Cold-ground generation speed: server background builder around players, bullseye prebuild, block link (TCP) fallback tests.
4. Client cache on slow disks: batch writes off the main thread, read-ahead; test with a throttled disk.
5. HUD: add VRAM and draw calls (draw calls exist), a memory breakdown; first real-machine measurement script for Dave's 1050-class test (steps for him).
6. Tree levels of detail in the flora view: joint with Art direction item 3, format approved by Technical direction.
7. Collision cost: colliders near player only, generation and cleanup inside the streaming benchmark (Stage 6).
Fill-ins: quality preset (F2) numbers per tier in ARCHITECTURE_BUDGET.md; check each quality tier loads under its cache limit.

## Technical direction (me)
0. Done (build 105): shared game clock, `src/shared/game_clock.gd`, server-owned, sent in the welcome, HUD shows game time. Next for Art: sun, sky and lighting read `game_clock.hour()` and `season()` (client `game_clock`). Next for Water: weather state reads the clock and a spirit modifier.
1. Save and identity contract doc: terrain edits, flora removals, water, trunk and sapling records; checkpoint and recovery order; generator versioning rule.
2. Confirm player edits survive a re-bake and `TERRAIN_VERSION` bump (with Water item 3).
3. Flora and harvesting thread brief: stable ids, per-tree state (trunk, sapling, growth), server lazy growth, trunk rot after 168 game days, dig-under-trees support check. Propose creating the thread once Art fixes tree models.
4. Exclusion masks for roads, buildings and cleared areas in the flora placer (needed before towns).
5. Asset budget table into ARCHITECTURE_BUDGET.md; per-biome validation camera spots.
6. Recheck float precision in the next playtest (slow walking, small objects).
Fill-ins: review each thread's pushes for architecture drift; keep BUILD_LOG.md and DECISIONS.md current.

## Questions for Dave (pickable)
- **Q1 Rain and weather pattern: ANSWERED by Dave 2026-10-20.** Zone north to south, seasons everywhere, dry zones dry, polar snow, town spirit modifies local weather (high: sun and gentle night rain; low: storms, blizzards, multi-day rain). See DESIGN_IDEAS 4.2.
- **Q2 Character style: ANSWERED by Dave 2026-10-20: slightly stylised heroic.** Art direction may start character and building looks in that style.
- **Q3 Music: ANSWERED by Dave 2026-10-20: no music for now.** Sounds skips item 7.
- **Q4 Forest floor objects: ANSWERED by Dave 2026-10-20: fallen branches and leaf litter first**, then reeds, driftwood and pebbles later.
- **Q5 Tool and hit sounds: ANSWERED by Dave 2026-10-20: basic set** (axe, pick, hammer, spade on wood, stone and soil).

## Items and crafting (thread started 2026-10-20, session cse_01V6Btc8oMTBkLDXxtZpyY7v)
Ask Technical direction for a build number as each job starts. Items 1, 2 and any save or network change need approval first (send what, why, files, cost at Low).
1. Design note first (short): item ids, stacks, inventory slots, where inventory lives (server owns, client shows), save file; send to Technical direction for approval before code.
2. Item and inventory system (server-owned, minimal HUD, pick up, drop).
3. Harvest and drop: stone, sticks, plant fibre, branches from forest floor objects; shared with tree-fall later (stable ids, drop tables).
4. Hand-craft recipes (two ingredients, no station, few seconds), recipe data in a file.
5. Stone axe (also the pick, no stone pickaxe); hook Sounds tool-hit slots.
6. Campfire: place with blueprint (yellow in open, green under cover, needs the cover query, Q8 answered: simple canopy-diameter yes/no), light, burn time, rain puts out open fires.
7. Spear: jab on attack keys, hold right click to aim, left click throws, release returns to normal (see CONTROLS.md).
Queue refill (2026-10-20; jobs 1-7 done; ask me for a number as each starts):
8. Design note for tree felling state: standing, felled trunk, stump, sapling; stable tree ids; extends flora_removed; save format and any protocol data. **Send to Technical direction for approval before code.** Rules already decided by Dave (DESIGN_IDEAS section 5): felled trunks stay on the ground to be processed with tools, trees always cut with tools; felled trunks rot after a real week (168 game days at 24:1); nothing respawns while trunks lie on the ground; respawn only as saplings near a standing tree of the same type, growing over a few game days.
9. Chop a tree with the stone axe (hits by trunk size), tree falls, becomes a trunk object with hit sounds hooks.
10. Process a trunk with the axe into logs, branches, bark, leaves, seeds (drop table).
11. Trunk rot timer (real week), sapling respawn rule near same-type trees, lazy growth (computed on load, no per-frame work).
12. Stone from rock: axe used as the pick on rock outcrops gives stone; **no ground digging yet** (digging under trees is a later Technical-direction job).
13. Hand gathering: berries, herbs, roots, mushrooms, nuts, fibre with known drops, skill placeholders only.
14. More hand recipes from DESIGN_IDEAS 5.3: stone knife, cordage, torch, poultice; recipes in data file.
15. Inventory polish: stack split, tooltips with inspection-mode truth/unknown, hotbar persistence.
16. Campfire follow-ups: cooking placeholder (roast berries/meat), fuel items, light radius cost check at Low.
Second refill (2026-10-20; jobs 1-16 done):
17. Item data validator script (items.json, drops.json, recipes: unknown ids, orphan items, unreachable recipes), run in the headless check.
18. Persistence tests: server restart, corrupt file fallback, caps (world items, trunks, saplings) with a stress run of 1000 items; report numbers.
19. Poultice and bandage from herbs as hand recipes (effect is a placeholder until health exists), plus plant identification hooks with inspection mode (identify before use).
20. Held light cost: torch and lantern lights, at most 1 own shadowless light at Low, nearby fires capped at 3 (already), numbers at Low.
21. Drop table audit: every flora species and rock outcrop has a sensible drop and a gathering tool or hand rule; write the table into a doc for Dave.
22. **ASK Q9 (building start):** what is the first buildable? (a) lean-to shelter that counts as cover plus a storage chest (recommended: gives roofs to Cover.at); (b) storage chest and sleeping roll only; (c) wait for the building design. Send to the coordinator for Dave; meanwhile do 17 to 21.
23. **ASK Q10 (tool wear):** do tools wear out? (a) yes, slowly, repair with materials; (b) no wear for now, revisit with the economy (recommended); (c) break on a hard hit only. Coordinator asks Dave.
Third refill (2026-10-20; jobs through chopping block done; ask me for a number as each starts):
24. Server item tick: run per active chunk at 4 Hz (it was 1.5 ms at 1300 records), report before and after.
25. Placement framework as data: one table for structure kinds (footprint, caps per chunk, kit item, reach, ghost colours, roof or not) so a new structure is a data row, not new code; migrate campfire, lean-to, chest, woven chest, chopping block; no behaviour change, tests pass.
26. PROTOCOL.md in the repo: every message and ACT kind with its number, fields, direction and the protocol version that added it (head is 17), kept current from now on; Technical direction reviews it.
27. Regression script for items (like tools/sound_check.py): tool gating, wear and repair, chest put/take, placement caps, felling to firewood, save and reload; runs headless in the check.
28. Plank chest recipe stub and a sawn-lumber item placeholder (no saw mill yet), data only, validator passes.
29. Inventory screen tuning from Dave's feedback and a controller-friendly layout check (tab order, key hints); client only, built when opened.
30. **ASK Q11 (carrying limits):** how should carrying work? (a) slot limit only, no weight (recommended for now); (b) slots plus a weight limit that slows you; (c) big items (logs, stone) must be carried in hands one at a time. Coordinator asks Dave; meanwhile do 24 to 29.
Rules: first three crafts are stone axe, spear, campfire (DESIGN_IDEAS 5.3). Stats and skills are placeholders until skills exist.

**Flora cost plan (priority, Dave's GPU is 20 ms with flora 11.3 ms; see tech/RENDER_AUDIT.md "Flora cost plan"):** Art direction takes steps 2 to 6 next, ahead of the slope look job; Ground adds the split probe rows (step 1) now. Both ask me for numbers.

### Items and crafting: refill 4 (2026-10-20, after job 62 pushed as 303)
63. Persistence drills for every item file (inventories, world_items, tree_states, chests, vitals, craft_queues): kill the server mid-write, corrupt each file, check .bad fallback and no item duplication or loss; add to the regression script.
64. Multi-player stress: 20 simulated players with queues, fires, chests and walking; report server tick ms, memory and message rate; list anything that scales badly.
65. Digging under trees to fell them (decided, not built): design note first (what is dug, tool, time, what falls, what it does to saved ground and the block store), send to Technical direction before building.
66. Sapling growth and trunk rot as lazy catch-up on load, tested over 7 game days of offline time with a counter of work done (no per-frame cost).
67. **ASK Dave (thirst):** is there thirst and drinking from streams and ponds? (a) yes, simple thirst bar, drink at the water edge, no sickness yet (recommended); (b) no thirst for now; (c) thirst plus dirty-water sickness later. Sent as a card by the coordinator; work on 63 to 66 meanwhile.
68. Sleep and rest design note: sleeping lowers strain faster, where you can sleep (lean-to, ground), safety; note only, send to Technical direction.
69. Placement ghost for every structure from the placement table: yellow in the open, green under cover, red if blocked, one shared ghost mesh path (Items' own idea).
70. Skill-gated gathering hooks: each gather action asks a skill function (placeholder returns 1.0) so skills can later change yield and speed; data table of action to skill.
71. Driftwood placement once Water has a bank query (ask via me when the query exists); until then data only.

### Items and crafting: refill 5 (2026-10-21, no Dave decision needed)
72. Recipe graph checker: every item is either gatherable, craftable from gatherables, or marked future; no cycles; report orphans and dead ends; add to the validator.
73. Container rules as data: slots and weight limit per chest type, who may open (owner or town later, data only), transfer (T) edge cases (full, stacks, split); tests.
74. Tool wear and repair tuning table: uses before break per tool and material, repair cost; one sheet in items/ for Dave to read, values in data not code.
75. Item name and tooltip audit: plain names (no verbs), every item has weight, value and one-line description; fix gaps.
76. Placement ghost follow-ups from job 69 and a per-structure footprint table shared with Sounds and Water (cover roof API).
77. **Luck trait (Dave 2026-10-21, design now, effects wait for his answer):** a character trait fixed at creation like the innate skills, not trained; stored server-side with the character (character save record, bump its save version, old characters get a neutral value); one server function `Luck.roll_bias(character, kind)` that all server random rolls (drops, finds, tool wear, rare events) call, returning a neutral value until Dave decides what luck affects; character-creation field and protocol cost stated before any push. Design note to Technical direction first; no effect code until Dave answers the coordinator's card (chance rolls recommended).
Items 65 and 68 notes: Technical direction reviews them next and replies; no code before approval.

### Pond ice (found 2026-10-21: only a sound flag exists)
Sounds job 88 reacts to `weather.ice_cover`, a client-side timer in weather_sounds.gd (cold air <= -2 C for 15 min). There is NO ice in the world: no visual, no walkable surface, no server state, no melt. Jobs, in order: (1) design note (Technical direction): server-owned `ice_cover` per still-water body from the weather temperature, freeze and melt rates, thickness, still ponds only (running rivers do not freeze, maybe edge ice later), what a player can do (DAVE 2026-10-21: pond and lake ice ALWAYS holds, no falling through; OCEAN ice breaks into floating chunks with open water between them that you can fall into, swim, or climb onto: needs a chunk model and the water thread, design note covers it, built after pond ice), water thread behaviour under ice (flow continues, surface locked); protocol cost; Walk/fall rule decided (above). (2) server state and walkable collider (Water and terrain). (3) ice look (Art direction). (4) Sounds switches from the client timer to the server value. Until built, the ice sounds play over open water: keep them, but they must not be described as ice in the game.

### Items and crafting: refill 6 (2026-10-21, near current development only; sounds, ice, waterfalls are other threads)
78. First-hour script (headless): a new character gathers, hand-crafts a stone axe, fells a tree, makes a campfire, drinks, builds a lean-to and chest; asserts each step and the vitals curve (hunger, thirst, exertion). Part of items_check.
79. Balance sheet for Dave (items/BALANCE.md): hunger, thirst, exertion, tool wear, craft times and carry weight in one table with plain-language reading ("a full day of work needs about X"), values from data files only; flags anything that looks too harsh or too easy.
80. Luck numbers sheet: what +10 and -10 luck do to gather yield, tree drops and tool wear in plain numbers, plus the counter of what luck touched; for Dave to approve the 0.03 strength.
81. Death and respawn design note (what happens to the pack, vitals, body weight and placed things); note only to Technical direction, questions for Dave as one card.
82. Inventory screen audit at 4K TV 1080p fonts and keys (Split S, Drop D, Use E, Repair R, Transfer T): every label, tooltip and sort option readable and listed in CONTROLS.md; fix gaps.
83. Hunting and animals prerequisites note: what the item side needs (hides, meat, bone, spear/bow damage hooks, corpse loot through Luck), no code.

### Assigned 2026-10-21 04:40 (Dave: nobody waits for another agent)
- **Ground loading (Slow ground build):** (1) spade digging, client side: dig action with the spade, voxel edit, GrassView.ground_changed, pebbles/grass vanish, dig sounds hook exists; design note first for how edits are saved (server owns them, must survive restart and re-bake; save format needs Technical direction OK). (2) 1050-class performance pass using the script-time-by-piece row from Dave's table (Low tier fast paths, per-frame work when idle).
- **River start (water work):** (1) pond/lake ice and ocean ice design note (JOBS "Pond ice"; Dave: pond ice always holds, ocean ice floats in chunks with open water between); (2) saved ground edits on the server side (edits survive re-bake, tile borders), design note with the Ground thread's dig notes. Numbers from Technical direction.
- **Art direction:** after the 33 ms script hunt, jobs 11 to 13 in the Art queue; first-person arms with Items' held tool attach point.
- **Items and crafting:** boulders (protocol 27), then jobs 78 to 83.

### Items and crafting: refill 7 (2026-10-21 04:55)
Designs APPROVED by Technical direction now (Dave chose the features; conditions: PROTOCOL.md entry same push, versioned saves with neutral defaults, luck function for any roll, cost at Low stated): items/DIG_UNDER_TREES_DESIGN.md and items/SLEEP_DESIGN.md.
84. Dig yields and fill source: a spade dig gives soil, clay, sand or stones into the pack by the material at the hole (data table, through Luck, weight counted); filling consumes soil/stone from the pack. Ground's ACT_DIG (build 364) and River start's fill op call it.
85. Dig under trees to fell them, built to your approved design (after 84).
86. Sleep and rest build to your approved design; put the two small sleep questions to Dave as one card when this job starts.
87. Skills and attributes list (design note + card for Dave): Fitness, Luck, the first innate and trained skills (building-material trades), what each changes, inspection mode hooks.
88. Water containers design note (waterskin, clay pot, bucket): carry water, drink from a container, weight, fits thirst (protocol 24).
### Art direction: unblocked work (no Dave data needed)
First-person arms with Items' held tool attach point; job 10 buildings look (lean-to, chest, campfire, chopping block, boulders in the style of the art direction); jobs 12 and 13 from the Art queue; keep CPU script hunt open for Dave's per-piece table.

### River start (water work): refill (2026-10-21 05:08)
1. Swimming physics (client controller + server validation): buoyancy and swim speed by depth, exertion cost while swimming (feeds Items' strain and Fitness), climb out/mantle rule at banks and floe edges, no stuck states under floes; cost at Low. Sounds already has swim sounds (hold).
2. Drowning and breath hold: DESIGN NOTE only plus one card for Dave (how long can you hold breath, damage rate, can you recover); unblocks falling into the sea.
3. Saved ground edits step 2 and 3 per the approved note: water replay of digs and dams at start, flora/items cleanup, fill op (protocol pre-approved, extend Ground's digs.dat to DIGS2 and keep reading DIGS1).
4. Tile-border water: water continues across tile borders (design note first).
5. Water thread cost report at 10x and 20x on a Low-class budget (capped at half a core): confirm the cap holds with ice and digs in play.

### Items and crafting: refill 8 (2026-10-21 05:20)
89. Water containers build (waterskin, clay pot, bucket) from your approved note: fill at water, drink from container, weight; recipes through the recipe graph checker.
90. Next-tier recipes sweep (data only, through the checker): cordage and rope, stone pickaxe and the spade tiers, wooden bucket, simple backpack (slots), sewing needle from bone; each with tool wear and luck-aware yields.
91. Food spoilage design note (food rots, cooking and drying/smoking preserve, chest vs open air, weight loss); note plus one card for Dave.
92. Clothing and warmth design note (cold exposure by zone and weather from Weather.temp_c, wet, wind, shelter and fire; what clothes do; ties to ice zones); note plus one card for Dave.
93. Persistence drills refreshed: add characters.json, digs.dat (Ground), boulders and containers to the drill script; kill-mid-write for each.
94. Inventory and Tab screen audit after all new items: fonts at 4K TV 1080p, keys in CONTROLS.md, tooltips for every new item.
6. Tile-border water, staged per the approved note (A first): border check script, flux export/import as neighbour springs, one round-robin water thread, neighbour sim_levels to clients. Conditions in DECISIONS.md (memory cap, at most 3 tiles active, LRU unload).
7. fill_rock_column per layer (JOBS Water and terrain: 2x cold generation, byte-identical output proven by a hash-compare test); no re-bake.
8. Water at the starter bays and digs: confirm hand-made bays and dug ditches behave (refill, stay) after the DIGS2 replay.

## Reserve (fill-in jobs any thread can take when its queue is short, tell Technical direction)
- Water and terrain: edge-match report for all 9 tiles; terrain screenshot set per bake; tile border checks after the bake.
- Art direction: Low-tier cost table per step; before and after renders per step; ART_DIRECTION.md section update; 6-spot camera set per biome (shared with Technical direction).
- Ground loading and performance: run the performance routine on each new build; keep the numbers table in ARCHITECTURE_BUDGET.md current; test the F2 tiers against their cache limits.
- Sounds: re-balance loudness per surface after each new ground; check headless sound probe numbers.
- Technical direction: review each push for architecture drift; keep the logs.

- **Lightning gameplay (not built, reserve):** strikes that start fires and injure or kill players and creatures; needs the health and fire systems. **Q7 ANSWERED (Dave, 2026-10-20): players: nuisance, not a killer; NPCs: usually hurt, very small chance of death.** (old options:) (a) rare and mostly scary, minor injury and small fires; (b) serious injury, death only if unlucky (recommended); (c) deadly and common in low-spirit storms.
- **Cover query (NOW a queued job for Water and terrain, spec in tech/COVER_QUERY.md; Dave 2026-10-20: rain soaks ground except under canopies):** a shared `cover_at(position)` returning canopy/roof cover 0..1 for rain, sun, sound and building placement; client-side, no network. Fire pit blueprint colours (yellow open, green covered) and rain putting out open fires wait for the building and fire systems. **Q8 ANSWERED (Dave, 2026-10-20): keep it simple; under a canopy (canopy diameter footprint) counts as covered, any tree type, size or season, one fixed mild value.**
- **Crafting start (Dave 2026-10-20, no thread running yet):** first crafts are stone axe (also the pick; no stone pickaxe), spear, campfire. Prerequisites in order: 1) item and inventory; 2) harvest and drop (stone, sticks, fibre, wood; same system the tree-fall design needs); 3) hand-craft recipes (two ingredients); 4) fire; 5) tool use and spear throw. Proposed owner: one new "Items and crafting" thread (items, inventory, recipes), with fire inside it; Sounds already has axe/pick hit slots. Needs Technical approval for save format and network messages.

## Queue health (2026-10-20, 16:50)
Water and terrain: 8 items left (plenty). Art direction: 5 items plus 6a, 6b (plenty). Sounds: refilled to item 15. Ground loading: 6 items left (plenty). Technical direction: 6 items (plenty); flora and harvesting thread brief is waiting on Art's tree models.
- **Q6 Creature calls.** (a) Birds and small game only (deer, rabbit, fox) for now. (b) Those plus predators (wolf, bear). (c) Wait until creatures are designed. Recommended: (a). **ANSWERED (Dave, 2026-10-20): (b) birds and small game plus wolf and bear.**
- **Sounds queue, second refill (2026-10-20):** 25) spear sounds: jab whoosh, throw release, flight whistle, hit on wood/stone/soil/flesh, stick in ground (Items build 140); 26) item sounds: pick up, drop, inventory open/close, hotbar swap, craft complete per recipe type; 27) fire sounds: campfire crackle loop by size, lit/put-out, rain hiss on open fires (hook now, Items builds the fire in 143); 28) audio settings: master, effects, ambient, interface volume sliders saved with the other settings; 29) loudness pass per surface and a probe table at Medium and High; 30) sound pack validator script: lists missing, oversized or unreferenced files against the manifest. Ask me for a number as each starts. Jobs 20 and the Cover.at swap run when their inputs land.
- **Sounds queue, third refill (2026-10-20; jobs 20 to 30 and Cover.at swap done):** 31) tree felling sounds: creak warning, crash, trunk thud, chip hits on stump (hooks for Items job 9, build 156); 32) exertion: breathing and heartbeat tied to an exertion value only (Dave's rule: not fear or pain yet), quiet, tier-capped, hook takes exertion 0..1; 33) torch and lantern flame loops (Items torch, build 157); 34) crafting sounds per recipe type: knife cut, cordage twist, firestarting, stone knapping; 35) footstep surfaces for built floors (plank, stone slab, carpet, thatch, gravel path), hooks only until building exists; 36) when Water build 154 lands: waterfall roar from fall columns and switch swim and water sounds to WaterVolume (ask me for a number then); 37) distant-sound pass: far thunder and falls low-passed and delayed by distance (speed of sound scaled so it feels right, cap at a few seconds). Ask me for a number as each starts.
- **Sounds queue, fourth refill (2026-10-20; all earlier jobs done):** 38) building and storage sounds for Items' lean-to and chest (place, pick up, chest open/close, put/take item), tool break and repair sounds (Items builds 185 to 187); 39) cooking sizzle for roast forage and rain-on-fire already hooked: check cooking pot/eat sounds; 40) wind in trees by species and season (pine hiss, leaf rustle in summer and autumn, bare-branch creak in winter), using Cover.at and the flora list near the player, throttled; 41) sound credits and licence file: every shipped sound has source and licence in a table, validator checks it; 42) headless sound regression scenarios (rain walk, storm, fire, swim, felling) with expected voice counts, run in the check script; 44) plant harvest and pick sounds (berry pluck, herb snip, root pull, mushroom twist) and flora rustle when picked, matching Items' harvest prompt (build 193); 45) chopping block and saw mill sounds (hooks until built); 46) rain on different ground (leaf litter, stone, mud, snow, water surface, roofs) using the surface under the player; 47) recording-wanted list for Dave: a short doc of the 15 sounds that matter most to replace with real recordings, with length, how to record, and file naming; 43) placeholder swap kit: a script that replaces a generated sound by a supplied recording (trim, normalise, loudness) so Dave's recordings drop in. Ask me for a number as each starts.
- **Sounds queue, fifth refill (2026-10-20):** 48) wire fire lighting and loading sounds to Items' real events once build 216 lands; 49) "what is that sound?" list in the Debug details HUD (active voices with name, distance, level, via the debug_hud registry) so Dave can name a sound when he complains; 50) SOUND_NOTES.md: a log of every Dave complaint about sound and the build that fixed it, kept current; 51) snowfall hush (ambient dampening and snow-muffled steps while it snows, from the weather state); 52) memory audit at Low: total loaded MB against the 150 MB cap, unload unused, report; 53) merge distant fires and falls into one voice each beyond a distance. Ask me for a number as each starts.
- **Sounds reserve (after 20):** 22) mixer preset per quality tier (voice caps 24/48/96, per ARCHITECTURE_BUDGET section 9); 23) footsteps for armour and clothing layers (hooks only until items exist); 24) interior ambience and door/chest/furniture slots (hooks until building exists).

## Water and terrain: new job (from Ground job 3 findings, 2026-10-20)
Cold generation speed: of the generate cost, 61% is the column loop and 80% of that is _fill_rock_column (per column, 2 fill_area calls per layer plus soil and clay). Fill rock per layer across the whole block when neighbouring columns share province and boundary depth. Output must stay byte identical (add a hash-compare test over several tiles). Expect about 2x on cold blocks. No runtime cost at Low. Ask Technical direction for a build number when you start.

## Items and crafting: from Sounds gaps table (tech/SOUND_GAPS.md, 2026-10-20)
62. A server reject event (action refused: too far, no tool, full pack) so the client can play a cue, and a fall damage hook when vitals handle falls. Small protocol field if needed: bundle it with your next protocol bump and ask me for a number.

## Items request 2026-10-21T03:34:08Z (message quota used up)
Items asks OK for PROTOCOL 26: vitals() gains fitness (7th field, -10..10, characters.json beside luck, data/items/fitness.json). Dave asked for the Fitness attribute. Planned single push, build 343: hotbar 1-0 + strip + drag, Use equips, over-exerted 10 percent slower, carry bar, weights.json audit, Tab in CONTROLS.md. Items pushes on its own once this is answered here or via the coordinator.

## Note to Art from Items (2026-10-21T03:50:25Z)
Arms wired (3b437ce): held_item.gd adds Ragdoll.new(true) as camera child 'Arms' and parents tools to hand_mount_l, because in the rig 'left' is +X which appears on the viewer's right (facing -Z, +X is the character's right), so left and right look swapped: please check the naming. Boulders: Dave's card is open; keep your scenery until he picks.

## Items request 2026-10-21T04:24:52Z: OK for PROTOCOL 27 (boulders)
Dave picked boulders: a pick breaks them into stones (1 blow per stone iron/steel, stone axe 3), yield from the boulder's volume. Needs protocol 27: world-item row state 10 (boulder; count = stones left, extra {radius, yaw, total}) and ACT_HIT with b = HIT_BOULDER (-1000000) for a blow on boulder id a. Old clients would draw state 10 as a chopping block. Server-owned, saved in world_items.json "boulders" (same version), data in data/items/boulders.json, tests in test_server_items and the eat client check. Also adds placeholder future items iron_pickaxe/steel_pickaxe/iron_ingot/steel_ingot with locked forge recipes (validator seeds future materials as obtainable). Ready to push as soon as approved. Art: server boulders now draw (solid, collider); set GrassView SCENERY_BOULDERS to false when you see them in game so they do not double.

### Note from Items and crafting (2026-10-21 12:55)
- strainrun client check (tools/items_check.py --only strainrun) fails on origin/claude/generator-v2 without my changes: the body ran only 23 m (needs 150 to 400) and strain barely rises. Looks like a movement regression between builds 375 and 378 (swimming/ice). Please assign. My message quota is spent for the day.
- Pushed: 382 next-tier recipes, 383 persistence drills (+ digs.dat torn-header fix), 384 fitness training. Next: Energy (Dave's master pool: 3 game days of normal play, 8 game hours of rest, supplements cost fitness) as protocol 32.

## Thread names (Dave 2026-10-21): Steve = Technical Director; Mandy = Arts Director (Art direction); Willy = Grounds Keeper (Slow ground build); Sonny = Water Works (River start); Radar = Items and Crafting. Use these names in JOBS.md and messages.

## Tyler findings routed (Steve, 2026-10-21 13:25; source tyler/FINDINGS.md)
- Sonny (Water Works): (a) brook bank zigzag, sheet edge from smooth distance-to-centreline; channel carve changes tiles (announce to Steve first), bands/sheet edge do not. (b) Fall shape in generator: plunge pool (0.3-0.5x fall height, cap 4 m), boulder apron reusing boulders, slight back-cut with bed lines, uneven cascade step heights/spacing (0.5x-2x) and lips uneven by tens of cm. TILE-CHANGING: bundle (a)+(b) generator changes into ONE push before Dave's bake, announce first. (c) Nappe throw (ballistic 2-3 polyline points) and ribbon fraying into 3-5 sub-streams at normal flow, one thick sheet at 20x (water_falls.gd). Client only. State verts/draws at Low.
- Mandy (Arts): (d) waterfall reference stills (face-on, side-on, lip top, plunge pool at pond B x 53431 z 69368 and the 10-step cascade, normal and 20x) into art/ for Tyler; do first. (e) Landing foam ring + GPU-particle mist plume (about 64 at Low, one draw, scaled by fall height x flow), replace the flat mist cards in fall_mist.gd; wet rock band up the face beside the sheet. Client only.
- Bake: stays at 1be1f5f until Sonny announces (a)/(b); then Dave is re-told.
- Tyler report 2 routed (Steve, 13:35): Sonny (generator, tile-changing, ONE push with the bank/fall changes): M2 irregular ledges (log-normal bed thickness, dip 1-5 deg, sloped bench tops, gullies); M1 mountain erosion as a PROTOTYPE first: hillshade of tile (3,4) mountains to check drainage, then thermal + coarse hydraulic pass masked to mountain rock above the river/pond zones (rivers, ponds, spawn, hand-made features, tile edges must not move; edge-match + test suite must pass). Included in the bake only if the hillshade shows it helps and the guards pass. Mandy: S1 horizon haze/aerial perspective tied to sky colour (client, one fog term, state Low cost), S3 storm/night ambient floor, S2 horizon cloud fade, M3 rock look; leaf cards (soft cards, outward normals) LATER; mountain still (midday + low sun, plus hillshade from Sonny) for Tyler.

## STANDING RULE (Dave 2026-10-21): before a new kind of job, read tyler/BEST_PRACTICES.md and FINDINGS.md; if not covered, ask Tyler for a few lines of best practice (see PROCESS.md). Do other work meanwhile; never idle.
- DAVE 2026-10-21 13:58: the big waterfall must be ONE clean chute all the way down, not steps. Supersedes the stepped-cascade/uneven-step item for the big fall (Sonny's single tile-changing push; Dave bakes once). Cliff-face rippled banding seen in his screenshot goes to Mandy (rock look/banding). Steve to review Sonny's plan and name the bake commit.
- DAVE 2026-10-21 14:00 (supersedes the waterfall routing above): Dave and Willy are reworking the underlying terrain for waterfalls. Sonny's tile-changing generator push (chute, terraces, ledges, M1 erosion, plunge pool, bank carve) is ON HOLD until Dave says they are done; no waterfall work by Sonny. BAKE ON HOLD. Sonny now: why do lakes look like moving water with peaks in them? Test spring rate back at 1x first (it was upped to 10x), then ask Tyler for normal flow rates for small, medium and large rivers to look real; report. Mandy's client-only fall look work (foam, mist) is not terrain and may continue.

### Radar refill 9 (Steve, 2026-10-21 14:10; sent via file, Steve's message quota was spent)
Skills system APPROVED (Dave chose the design: innate+trained base, ~20% practice feeds, decay floor 20%, 80/20 specific/parent, first skills Strength, Memory, Foraging, Woodcutting, Mining, Digging, Crafting, Jumping; inspection mode hooks; DESIGN_IDEAS 5.4). Conditions: PROTOCOL.md entry in the same push (protocol 37), skills saved versioned in the character record with a neutral default for old characters, every yield/speed change through the Luck/skill functions (job 70 hooks), cost at Low stated, read tyler/BEST_PRACTICES.md first. Numbers: 412, 413 (spare), 414, 415. Any thinly discussed numbers (how fast skills train) go to Dave as ONE card via the coordinator with a recommended option; build with sane data-file values meanwhile.
Then: Energy follow-ups checked against warmth and sleep, persistence drills refreshed for remains/warmth/spoilage/skills, balance sheet update (items/BALANCE.md) for spoilage, warmth, energy.

### Radar refill 10 (Steve, 2026-10-21 14:20; via file, send quota spent)
Order: (1) medicine and herbal cures recipe set (closes the sickness loop; data through the recipe checker; Tyler best-practice check first for herbal/remedy realism); (2) death marker with countdown to remains expiry (client display, no new design); (3) placeables in the first-person hand (ghost/held model hook shared with Mandy); (4) hide items (waterskin, backpack, slots) as data; (5) ASK Dave one card via the coordinator: spawn at the last shelter slept in (a) yes, (b) always at the starter town, (c) choose at respawn; recommended (a); build nothing until answered. Numbers 415 to 418. Protocol bumps pre-approved per the standing rules (PROTOCOL.md same push, versioned saves with neutral default, cost at Low).

### Radar refill 11 (coordinator for Steve, 2026-10-21 14:37)
(1) remains cap per player; (2) cooking and food prep (campfire cooking, cooked lasts longer and warms); (3) clothing and equipment section with warmth + backpack slots_bonus (protocol and save bump); (4) hunting prerequisites as design plus data; (5) tool durability and repair pass. Tyler best-practice check before each new kind of job.

### Radar refill 12 (coordinator for Steve, 2026-10-21 14:52)
(1) save-migration test across protocols 34-40; (2) end-to-end survival balance pass in BALANCE.md; (3) inspection mode check for new items, clothing, remains, kits; (4) first skills each have a real practice hook; (5) next unbuilt item from DESIGN_IDEAS (stations, fishing or shelter, fewest animal dependencies); Tyler best practices before (5).

## Refill (Steve, 2026-10-21 15:20; all send to Steve before starting something with a protocol bump)
- Radar: fishing, ice holes, stations done. Next: (1) persistence drills for energy, fishing stock, stations, worn clothing, remains cap; (2) BALANCE.md update for fishing and stations; (3) 20-player stress run with all new systems (server tick ms, memory, messages per second, anything that scales badly; budget from tech/STRESS notes); (4) list remains world-item row state in PROTOCOL.md; (5) station tier design note (forge, kiln, tannery: what each gates, levels) plus ONE card for Dave if thinly covered; (6) cloud client check timeouts (texttest, chest): shorten the checks so they pass in the cloud. Ask Tyler for best practice before each new kind of job.
- Sonny: (1) lake surface (peaks and moving look; 1x spring rate test; Tyler's flow rates for small, medium, large rivers), report numbers and stills; (2) with Willy: prepare the merged generator push (see DECISIONS 15:20) as a branch-local change, DO NOT push until Dave's current bake is done; (3) WATER_COST_REPORT with lakes, ice, digs and spear-fishing depth hook; (4) DIGS2 water replay and bays/digs check if not done.
- Willy: the merged generator push with Sonny (terrain side: chute, plunge pool, uneven beds, erosion masks, hillshade stills); then memory audit, 1050-class draw-call work.
- Tyler: (1) river flow rates (small, medium, large) for Sonny; (2) erosion parameters (thermal talus angle, droplet counts, masks, cliff preservation) for Willy and Sonny; (3) lake surface realism; (4) then rocks and mountains, skies, plants as planned; review Radar's new systems for realism.
- Mandy: haze, strata fade done; next: reference stills (falls, mountain), cliff banding check on head, soft leaf cards later, sound fixes only if Dave reports.

## PUSH FREEZE (Dave 2026-10-21 16:04): Dave is baking. NOBODY pushes to claude/generator-v2 until Dave confirms he has baked and pushed the tiles (the coordinator will release it). Work locally, queue pushes, keep claiming build numbers in BUILD_LOG.md.

## PUSH FREEZE LIFTED (16:36). Dave's wind cue feedback (Mandy, client): debris moves a few metres then hovers like fireflies. Wanted: specks drift across the frame in the wind direction and out again (continuous flow, respawn upwind), slight random direction jitter, amount scales with wind strength, none at calm, a light breeze only enough to read the direction. Tyler: best practice for wind particles. Performance next step: see DECISIONS 16:45 (Mandy trees/tree shadows at Ultra; Willy idle-step engine time and Low).

## NPC voices (Dave 2026-10-21 16:48): Radar: items/NPC_DESIGN.md after Tyler's best practices; guardrails in DECISIONS.md 17:00; send to Steve for review before code. Static classic dialogue first, provider switch, unwell fallback behaviour (back to bed/chair).
- Tyler: read the actual licence files for the TTS candidates (Kokoro, Piper voices) and record the result before any voice ships; owner of the TTS engine choice is Mandy (sounds) with Radar (NPC lines).

## Skills web (Dave 2026-10-21 17:04): Radar writes items/SKILLS_WEB_DESIGN.md after Tyler's best practices; guardrails in DECISIONS.md 17:20; send to Steve for review before code. Order after NPC step A (the rabbit moves behind skills web design review only if Dave prefers).

## Refill 17:45 (Steve)
- Radar: (1) NPC step B (static provider, dialogue data, validator, screen; move the old admin dig RPC to server_admin check); (2) skills web steps A and B with the hours table for Dave; (3) NPC step C (router, unwell fallback, forced-outage test); (4) rabbit (animals step A damage/carcass + B) reusing the shared steering; (5) 20-player stress after each. Ask Tyler first on new kinds of job.
- Sonny: final edge match + full suite on 7840ba9 (keep local); pond B fall water missing in settled render; lake surface check; then WATER_COST_REPORT, DIGS2 water replay if still open; prepare settle_water for after the bake.
- Willy: ground straight under a high flying player loads first within about 3 s of stopping (Dave); memory-creep recheck at Low; then loading stalls.
- Mandy: GPU cuts (trees, shadows) continue with before/after tables at Low and Ultra; stills for Tyler (pond B, mountain); leaf cards later; rock look; sounds only on Dave's reports.
- Tyler: licence check for TTS; review Radar's NPC and skills systems for realism; mountains, skies, plants.

## Next bake bundle (Steve 18:05): Willy builds the bake-geometry parts of Tyler's FINDINGS Report 9 B (scree apron geometry, bed-line relief) LOCALLY on top of Sonny's held 7840ba9; nothing pushes until the bundle is complete, with before/after hillshade and numbers, and Dave says go; then ONE bake. Order: Willy first finishes the ground-under-you loading fix. Mandy does the runtime material parts (tree line, snow line, bed-line banding colour, scree material) and Tyler's Report 11 sky items, no bake.
- Tyler (queue): plants and flora realism report (species look, placement density, seasons, understory) after Mandy's stills; review the rabbit and NPC behaviour designs for realism when pushed; judge post-bake stills of falls and mountains.
- Mandy: character animation LOD + clips for other players/NPCs (DECISIONS 18:10); river-mouth shader part with Sonny. Sonny: river mouth Part A (runtime). Part B waits for Dave.
- Sonny: BUNDLE = 7840ba9 + river mouth Part B + (if a generator cause) the river-diminishing fix; investigate Dave's "water evaporates before the ocean" (sink at sea boundary, thinning, surface fade) first, report cause to Steve. Willy joins with the mountain extras. Single bake commit named by Steve.

## PUSH HOLD (Dave 2026-10-21 19:08): Dave is installing his forge meshes and pushing to claude/generator-v2 himself. NOBODY pushes or rebases on that branch until the coordinator says clear. Work and commit locally; after Dave's push, fetch and rebase before pushing.

## PUSH HOLD LIFTED (Dave 2026-10-21 19:13): meshes pushed; fetch, rebase and push again. Willy pushes the one-push bake bundle next (see DECISIONS 20:15).
- Sonny (URGENT, Dave waiting): push the channel-pinch generator fix on top of claude/generator-v2 (2f2253e), generator code and data only, no .tile; send Steve (via the coordinator or this file) the commit, suite, edge match, time/size numbers; TERRAIN_VERSION 24. Then the bake commit is named.

## BAKE FREEZE (Dave 2026-10-21 20:21; Steve 21:10): Dave will not bake while anyone works on something that forces another bake. NOTHING queued in this file needs a bake now: the old tile-changing entries above (waterfall chute/steps, bed-line relief, estuary Part B, Tyler mountain extras, erosion) are DONE or dropped (bed lines = Mandy's colour banding). No thread changes src/worldgen/tile, terrain_layout.gd, tile_rules.json or TERRAIN_VERSION until Dave says he has baked and pushed. Anything new that would change tiles goes to Steve first and waits for the NEXT bake. Checked: since 87be29e the branch (head fd0cfce) has no generator-affecting change, so any head after 87be29e bakes the same tiles.
- Willy 20:55 (set aside, waiting on Dave): lake/hillside slab hunt. Builds 519-521 are in; need Dave to play on 521 and send any ZEROED BLOCK line or Dump. Meanwhile Willy does runtime-only work (loading stalls, memory-creep recheck at Low). Nothing touching tiles or generator until Dave bakes.

## STANDING RULE (Dave 2026-10-21 20:52): never stop waiting for Dave. If you are blocked on him, set the current task aside and move on to the next one, as long as it does not hinge on the previous one. Record the set-aside job here under "Set aside, waiting on Dave" with exactly what you need from him, and come back when he answers. Do this as often as needed to stay busy. Never touch anyone else's code or files while doing so; if the next job crosses another thread's files, tell Steve instead.

## Set aside, waiting on Dave (thread, job, what is needed)

## Moves awaiting Steve (Dave 2026-10-21 20:54: Steve approves every "set aside and move on")
How to log: one line: `thread | set-aside job | what it needs from Dave | new job | files it will touch | status`. Steve answers in the status field with APPROVED or DENIED plus one line why. Proceed only on APPROVED.
FAST PATH (pre-approved, no entry needed beyond the "Set aside" line): the new job is already in your own queue in this file AND touches only files your thread owns (map below).
FILE OWNERSHIP (who may edit what; anything else needs Steve):
- Mandy (Arts): src/client look and view files (flora, tree, grass_view, sky, weather look, water_material.gd and fall_mist.gd shaders, character/ragdoll, npc_view and animal_view looks, building/forge looks), assets/, art/, sound code and data, ART_DIRECTION.md.
- Willy (Grounds Keeper), NARROWED by Dave 2026-10-22: ONLY the ground and how it is shaped: ground loading, terrain generation under src/worldgen/tile (terrain side), worldgen tests, ground cache. Everything else Willy used to own moves to Tyler.
- Sonny (Water Works): water sim and water generation (tile_water.gd, water_*.gd, ice, swim, oxygen, settle_water), water rules in tile_rules.json, digs water replay, WATER_COST_REPORT.md.
- Radar (Items and Crafting): src/stream/server_items*, server_npcs/animals/dialogue/admin, data/items, data/npcs, data/animals, data/stations, inventory_view.gd and item/NPC/animal screens, items/*.md.
- Tyler (Problem Solver), WIDENED by Dave 2026-10-22: owns everything not specifically assigned to another thread, and now writes code (claude/generator-v2 only, zero warnings, builds logged in BUILD_LOG.md): server stalls, networking and block line, crash hunt and telemetry/crash tools, HUD and UI plumbing, connection window and signal bars, client settings/quality/camera, performance, movement, threading, the SCALE_PLAN implementation, RENDER_AUDIT.md, tools/check_warnings.sh, tyler/ docs.
- Steve: tech/ docs, PROTOCOL.md header review, build numbers.
SHARED (append-small-edit only, fetch and rebase first, never reformat): terrain_net.gd, terrain_server.gd, terrain_client.gd, PROTOCOL.md entries, CONTROLS.md, tools/items_check.py, BUILD_LOG.md.
Hard no without Steve: any tile-changing file (src/worldgen/tile/*, terrain_layout.gd, tile_rules.json) while the bake freeze is on; any protocol change (needs the PROTOCOL.md entry).
(entries below)
- 21:00 Steve review of moves made so far today (Sonny, Radar, Willy): none were logged here; I know of none that crossed lines. From now on log them here.
- 21:06 Sonny | post-bake re-settle and river test set (job 4) | Dave's bake of 87be29e | jobs 2 (ice) then 3 (refill timing numbers), both in my queue | own water/ice files + scratch | FAST PATH
- 21:15 Steve: WATER_NINE_TILES_PLAN APPROVED (A+B, one thread), conditions in DECISIONS.md 21:15. Sonny builds it after Dave's bake; until then prepare locally in water files only (src/water/*), no generator changes.

## RULE (Dave 22:54): questions for Dave go in questions/QUESTIONS.md on claude/generator-v2 (format in questions/README.md): multiple choice (or a short text answer only if truly needed); NO look-at or test tasks there, those stay in chat. Answers appear in questions/ANSWERS.md; read them there.
## BAKE DONE (22:55): tiles b1fb0c9, TERRAIN_VERSION 25. Sonny: re-settle water now (tile_3_4 first, then the nine-tile files), push separately; then Dave runs Clear blocks. Generator freeze stays: new tile-changing work waits for the next bake and goes to Steve first.
- Warning cleanup (Dave 23:39): every thread cleans its own files in one build, rules in PROCESS.md "zero warnings". Willy builds the warning-count check (plain headless load prints no warnings in this engine; see PROCESS.md note). Steve cleans shared/, protocol and build tooling after the check exists.

### Radar refill 11 (Steve, 2026-10-21 23:45; ordered by value for the first playable town; all in Radar's files; protocol bumps pre-approved per standing rules; ask Tyler before each new kind of job; check the "Moves awaiting Steve" rules)
1. First-town loop script (headless, extends first_hour): new character arrives at the spawn, talks to an NPC, trades, crafts at the camp bench, cooks, sleeps, gets warmth, trains one skill; asserts each step and prints the vitals curve; fix whatever breaks. (Proves the town is playable end to end.)
2. NPC daily routines and more NPCs: fill schedules (market, work, eat, sleep, shelter in rain) for the starter town cast (shopkeeper, smith, healer, guard, farmer, child, elder), bark pools per role/time, quests as small authored trees using reputation (info lines until quests exist); validator passes; 20-player stress with the full cast.
3. Trader stock and restock: each trader's stock list by role, restock timer in game days, price drift by supply, coins cap per trader, theft/steal protection already in; stress and persistence drills.
4. Tool durability and repair loop: wear tuning table for Dave (hours per tool), repair at bench with materials, broken-tool states, NPC smith repairs for coins; BALANCE.md update.
5. Cooking and food variety: recipes for 15 to 20 dishes from foraged/hunted/farmed items (stew, bread dough placeholder, smoked/dried food, teas), buffs small and honest (warmth, energy), spoilage by dish; recipe graph checker passes.
6. Player building basics: placement framework for 3 to 5 more structures (fence, storage shed, simple hut walls and roof as cover via the roof API, door), caps per chunk, saves versioned; look hooks for Mandy; no town-system yet.
7. Armour and defence groundwork for boar/bear: armour slots already in clothing; add damage reduction data, durability, weight; hits through the damage hook; tests.
8. Clothing and warmth polish: wet clothes dry over time, layering, hat/gloves effects, a warmth table by zone/season for Dave.
9. Persistence drills and 20-player stress refreshed for coins, trade, horses, flocks, trails, wood, carry; report server ms per tick and memory.
10. Warning cleanup of your own files in ONE build (PROCESS.md zero-warnings rule).

## DEV STOP (Dave 2026-10-22 00:42): all development stops until we find why the game crashes. Push nothing new, start no new jobs. Willy leads the hunt; ideas go to Willy. Work docs only if it helps the hunt.
Steve's ideas for the hunt: (1) the Godot log of the crashed run (user://logs/godot.log, rotates per run: keep the one from the crash) and crash_reports/ (builds 564+); (2) "server left, quit code 1" means the embedded server stopped or the connection dropped: look for ENet peer timeout after a main-thread freeze (any freeze longer than the timeout drops the client; builds 573+ lengthen it) and for a script error that kills the server thread; (3) the editor's embedded Game tab: a debugger break, a script reload by an external file change (git pull while open) or an editor-side error closes the game window; run the exported/standalone game (not the Game tab) to separate engine from editor; (4) Windows Event Viewer (Application log) for a GPU driver TDR (Display driver stopped responding), and memory use near the crash; (5) bisect by build with the flags: trunk_strip off, ground_check off, trails off.

## RULE (Dave 2026-10-22, permanent, also at the top of PROCESS.md): every question for Dave goes ONLY in questions/QUESTIONS.md on claude/generator-v2 (format questions/README.md), then report "Question added: <title>" to the coordinator. Never ask Dave in chat or elsewhere.

## OWNERSHIP CHANGE (Dave 2026-10-22, Steve_002): Willy owns ONLY the ground and how it is shaped. Anything not specifically assigned to Mandy, Sonny or Radar goes to Tyler, who now writes code. The crash hunt and scale plan steps move to Tyler_002. Willy_002 hands any open crash/telemetry/network work to Tyler.
- 03:50 Steve_002: Tyler_002 may edit src ground_ops.gd and server_block_store.gd (Willy's) for GROUND_COMPACTION (DECISIONS 03:50). Willy_002: read that diff before touching these two files; do not revert it.

## DEV STOP LIFTED (Dave 2026-10-22 03:51, relayed by the coordinator; Steve_002 04:10). All threads resume their queues. Rules: ownership per FILE OWNERSHIP above (Willy = ground only; Tyler = everything unassigned, writes code); build numbers per PROCESS.md rule; zero warnings; protocol bumps under the standing approvals. TYLER's standing direction from Dave: keep things moving, balanced and efficient, in SCALE_PLAN order (step 0 measure, then step 1 contain, then 2 to 4), compaction, grass rim and horizon ruler pushes first. Steve reviews each Tyler push as it lands (crash safety, thread safety, queues).

## FOCUS RULE (Dave 2026-10-22 03:53; Steve_002 04:25): focus on the PRESENT. We are getting ready to PLAY in the world: movement, physics, water flow, how tunnels work (digging, support, stalls), stability of the server for a friend session. Nobody works on far-future items yet.
PRIORITY ORDER for every thread (items outside your area go to the owner):
1. Anything that crashes, stalls or freezes the game or server (Tyler).
2. Movement and physics: step-over, slopes, swimming, falling, landing, ground under you loading (Tyler with Willy for ground).
3. Water flow as played: rivers, lakes, falls, swimming, digging into water, the chute bake bundle (Sonny).
4. Tunnels: dig, fill, grass/flora over holes, ground edits saved, compaction, cave lighting and sound (Tyler, Willy, Mandy).
5. Playable loop for a friend session: items, survival, craft, the starter town basics (Radar), look and sound fixes Dave hears wrong (Mandy).
PARKED (do not start, keep the notes): scale beyond a friend session (SCALE_PLAN steps 2 to 5, bots at 300+), load-adaptive exertion (section 13 of SCALE_PLAN), flood damage to crops/buildings (step E) and flood warnings beyond what Sonny needs to test water, armour and boar/bear, voice/TTS, banking, leaf cards, GPU cuts beyond Dave's table. Allowed exceptions: SCALE_PLAN steps 0 and 1 only as far as they protect a 10 to 20 player friend session from stalls (limiter, join guard).

- Radar_002 note: the headless client test quickkeys (tools/items_check.py --only quickkeys) fails now and then under CPU load with "no match" and passes on a rerun; needs stabilising (longer waits or waiting for the inventory sync instead of fixed timers).
- 04:30 Steve_002: Dave's answers (DECISIONS 04:30): NO warning edits to frozen worldgen files until the next bake (Willy: drop that job, keep to own non-frozen files). Tunnel bracing: 30 real min grace, collapse always lethal inside; a tunnel-collapse DESIGN NOTE (warning, zone, offline player case) is the next tunnels job, owner Tyler with Willy's ground files, to Steve for approval before code.

## NEXT JOB PER THREAD (Steve_002, 2026-10-22 04:50; keep current; the moderator reads this)
- Tyler: pushes compaction (ground_compaction.patch), grass rim, horizon ruler; then tunnel stability/stalls, movement and physics; then SCALE_PLAN steps 0 to 1 limited to friend-session protection. Next after that: tunnel-collapse design note.
- Willy: ground only: ground loading, ground under you, settle time; drop frozen-file warnings job; review Tyler's compaction diff of ground_ops.gd / server_block_store.gd.
- Sonny: held chute branch for the next bake (tests, edge match, scratch hash, TERRAIN_VERSION 26); flood steps A to C only after that and only runtime; water flow as played, digging into water.
- Mandy: look and sound fixes Dave hears wrong, tunnel look (grass over holes done 607), cave light/sound; no far items.
- Radar: friend-session loop (first-town script, NPC routines basics, trader stock, tool repair); drop message done 608; placement API only when asked.
- Steve: reviews, test cards, build numbers, bake naming.

## NEXT BAKE BUNDLE (Steve_002 04:50; bundle OPEN, not yet named; owners add items here before it is named)
1. Carved chute down the 300 m fall (Sonny; Dave said yes 01:04). See NEXT_BAKE_WATER_BUNDLE.md item 1.
2. Pond-outlet carve limit (Sonny, found 04:40, v25 regression): the 24 m minimum river width carve cut a deep basin at the pond outlet, so the live spring sits in that basin instead of the real head pond (east bowl, surface 427 m). Fix: limit the carve below the pond sill so the pond keeps its own outlet level. Runtime workaround (spring moved to each head pond's middle) is pushed separately, no bake, and stays until the bake.
Needs for both: TERRAIN_VERSION 26 held branch, 882-test suite, edge-match numbers, Willy's hillshade review, scratch bake hash on tiles 3,3 / 3,4 / 4,4, no .tile/.water in the bundle commit. Owner of the bundle commit: Sonny.

## NEXT JOB PER THREAD, refreshed 05:40 (Steve_002)
- Tyler: (1) push compaction after tests; (2) send EXCAVATION_BRACING_GROUND_DESIGN.md to Steve for approval (tunnel warning exists as protocol 68, timers off); (3) rock/void rescue loop guard (cooldown + settled check); (4) movement and physics; (5) friend-session limiter/join guard only.
- Willy: pit-wall panels at x 53320 z 68418 (F2 Low test on the card), water-draw squares / brown squares near spawn (Ctrl+Shift+W toggle in 628 helps tell mesh from water), ground settle time; review Tyler's ground_ops diff when it lands.
- Sonny: held bake branch: chute (option B south fall, DECISIONS 05:25) + pond-outlet carve limit, TERRAIN_VERSION 26; back pond fill check (on the card); flood steps A to C after that.
- Mandy: tunnel warning sounds wired (634/635); foundation look done (630); next: fixes for sounds Dave hears wrong from the card, cave/tunnel light, then foundation snapping polish and look of wall/floor/roof.
- Radar: foundation snapping polish and building basics (ghost done 637), then friend-session loop and NPC basics; no armour, banking or far items.
- Steve: test card test-626 (build 639), bake bundle gate, bracing design review.

## NIGHT STOP (Dave 2026-10-22 05:35): everyone parked. Resume when Dave returns. First jobs on return: read answers on the page (test-626, collapse-offline), then the NEXT JOB PER THREAD list above (05:40).
- 05:45 Steve_002: Dave answered collapse-offline (DECISIONS 05:45): clean logout vs disconnect; disconnect = respawn at nearest rest/shelter; deliberate logout in a collapsing tunnel = death. First job tomorrow for Tyler (logout message, left flag, 2 min reconnect grace) and Radar (nearest rest/shelter lookup); Willy_002 collapse step 3 reads the flag.

## RESUMED (Dave "go", 2026-10-22 13:34). Rule 3 in PROCESS.md: local builds and tests run on Dave's PC via the "Local build and test" thread; cloud only for cheaper work. The question page checklist (11 Yes/No items in build order) is live: owners queue new items in TEST_QUEUE.md and Steve adds them in build order. NEXT JOB PER THREAD list (05:40) and DECISIONS 05:45 (logout vs disconnect) stand. PR #2 into main is open and waits on Dave: nobody pushes to main.

## TEAM CHANGE (Dave 2026-10-22 14:18, Guru/Technical Director): Steve and Willy are RETIRED. Technical Director (Tyler_Guru_SenDev) = everything Steve did. Steve_ProblemSolver = Systems, the renamed Tyler_002 (Dave 14:32). MikeW_LocalAgent = the renamed MichealW_Local_agent (Dave 14:33). Kathleen_ArtisticDirector = the renamed Mandy (Dave 14:33; older lines saying Mandy mean her). Sonny = World (Willy's ground, tunnels, bracing, quake RPC, worldgen tests PLUS water). Workers run on demand from queues; moderator check every 30 minutes. Where FILE OWNERSHIP above says Steve read Technical Director, Willy read Sonny. Ownership table: PROCESS.md "Who owns what".

NAME (Dave 2026-10-22 15:15): Radar is now Sal_Crafts; older lines saying Radar mean Sal_Crafts.

## MikeW: nightly backup (Dave idea 2026-10-22, now P0 per Dave 15:33; APPROVED by Dave 15:35 as written; MikeW starts: step 2 of the rollout in tech/BACKUP_PLAN.md). Spec: BEST_PRACTICES BP-C110. First: feasibility check (size of folder + server_data, E: drive present, zip tool, time), then one manual run, then "goodnight" trigger.
