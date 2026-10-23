# Open items: Kathleen_ArtisticDirector (art and sound), updated 2026-10-23 00:45
| What | Why / source | Next step | P | Status |
|---|---|---|---|---|
| Merge claude/kathleen-tools-v6 | wedge axe, wooden bucket, spade, spade sizes, hoe, stone block/brick/mortar looks, tier design docs and pictures (docs and RUNTIME) | Tyler merges; run `python3 tools/gen_looks.py` once and commit looks.json | P1 | waiting on Tyler |
| DO NOT MERGE kathleen-spades, kathleen-materials, kathleen-shovel | superseded by tools-v6 (material skins replaced by tiers) | Tyler may delete them | P1 | obsolete |
| Build the six tiers in PieceLook (walls, floors, roofs, ceilings, doors, pillars, 45/65 roofs with corners, flat tarred roof, braces 1.5/3/5 m) | Dave approved designs: chk-tiers, chk-looks-short; round 3 cards (log notches, doors, ceilings, tar roof, braces, roof pieces, pillars) waiting on Dave | Start after Sal's piece ids/tier field exist; real log cylinders, two-layer plank wall | P1 | designs approved; round-3 answers pending |
| Place sounds place_stone/brick/thatch, soil_load/stone_load | on branch claude/kathleen-materials (not merged) | Re-apply on a new branch after tiers are built (per-tier sounds: thatch, board, log, stone, heavy stone) | P2 | later |
| Held chopping block 30 percent | merged (block-hand) | Dave's tonight test line | P2 | done |
| Collapse warning sounds (quake()) | Dave: collapse lethal | Admin test call so Dave hears stages once | P2 | waiting |
| 1-tile bake look review, look_sheet scene | BP-T31 | Need MikeW screenshots / headed run | P2 | blocked on MikeW |
| Stage one remaining: hood, mittens, back clothing on the body; hoof/step sounds; plant check | MODEL_PLAN | Next batch after tiers | P2 | open |
| Beach sound a little loud | Dave 05:03, steps or waves unclear | Ask via Tyler if still loud | P3 | waiting |
| Tunnel dust particles, animal art, CREDITS rule, audio hash check | earlier lists | later | P3-4 | parked |
Tomorrow's first job: build the tier looks in PieceLook once Sal's ids exist, starting with Fine wood, Plank and Basic.
Update 2026-10-23 02:15: tools-v6 merged (build 695). Wet-tunnel sounds on claude/kathleen-wet (not hooked; needs Sonny/Steve gap_m query); wet looks wait on Dave's answers. Tiers in game wait on Sal's ids. Parked for the night.
FIRST JOB TOMORROW (Dave 02:46): torch sound far too loud; in a cave it echoes and is all he can hear. Make it a quiet soft crackle (like the campfire crackle, no roar), lower the torch loop level a lot, and keep it from dominating cave echo (lower its reverb send). Check make_fire.py torch loop and the torch entry in the sound stage.
TOMORROW'S SOUND JOBS (Dave 03:16, tell Tyler what changes, test card via Tyler):
1. Rain in the open: background part perfect, the loudest clack must go.
2. Keep the current clacky rain sound; save it as rain on a wooden roof (Dave: sounds like rain on a metal roof); rename the file accordingly.
3. DROPPED (Dave 03:17): grass footsteps are fine now; do not change footstep levels.
TOMORROW'S LOOK JOB (Dave 03:32): redo the raspberry bush. In game it is a dark purple leafy ball; it must look like a real raspberry bush (green toothed leaves, arching canes, red berries hanging among them; Dave's photos in the project chat) and the berry item look like the close-up: red bumpy cluster of small drupelets, some unripe yellow-green. Check src/flora/tree_builder.gd or shrub builder and flora.json for the raspberry species, and looks.json berry entry. Then Tyler posts a picture card. RULE (Dave): no labels like "Womens Health" or "Mens Health" anywhere (plants, tools, items, UI); check my text and art notes.
RULE BP-T42 (Dave 03:33): never say anything that might divide people: no "Womens Health"/"Mens Health" or similar labels anywhere, including sound and voice text. Describe the use, not who it is for. Tomorrow: grep my sound/voice names, notes and look text for such wording (data/tables/flora.json has a "womens_health" tag: Sal/Tyler own it, I will tell them).

## Handoff 2026-10-23 04:20 UTC (Dave done for the night)
Branches pushed, all RUNTIME, sound/look only, none run headless (no Godot in cloud; Tyler run local_check):
- claude/kathleen-torch-rain: torch soft crackle (-36 dB, Body bus), open-field rain without loudest clack, old clacky rain kept as rain_woodroof_light/heavy under roofs.
- claude/kathleen-log-carry: shoulder log 0.45 m forward. Merge only via kathleen-log-looks.
- claude/kathleen-log-looks (on top of claude/sal-tree-logs + log-carry): species log bark colours (src/client/log_look.gd).
- claude/kathleen-wet: wet-tunnel sounds, not hooked (needs gap_m from Sonny/Steve).
Not started: raspberry bush and berry redo; rock pile and cave-in skull looks/sounds (no details); wet-tunnel looks; tier pieces in PieceLook.
Tomorrow's first 3 jobs: 1) raspberry bush + berry from Dave's photos, picture card via Tyler; 2) rock pile + cave-in death looks/sounds once cards are answered; 3) bark texture on logs, wet-tunnel looks, tiers in PieceLook.
Tests waiting for Dave: torch in cave, open rain vs roof rain, carried log centred, oak/birch log colours.
Dave's answers added 04:20 UTC (all for tomorrow, in this order after the first 3):
4) Beach (sand) footsteps: walking slightly too loud, running far too loud; run should be only slightly louder than walk. Lower sand run a lot, walk slightly.
5) Cave-in death voice: real speech from an offline TTS (Kokoro or similar), three lines, sad then jokey, "come up with something fun". No text-only placeholder. If the cloud cannot run it, ask Tyler to have MikeW run it on Dave's PC.
6) Skull art and rock pile look as planned; fire sound YES.

## NEW FIRST PRIORITY (Dave 04:26 UTC, ahead of everything above)
Models must be at least simple but accurate representations of the real thing. Many plants look nothing like their name (raspberry bush is one).
Step 1: audit all existing plants, bushes and flora (data/tables/flora.json, src/flora/tree_builder.gd): list name / looks right yes-no / fix needed; tell Tyler; fix the wrong ones using Dave's reference photos; picture cards to Dave as I go (one Yes/No each).
Step 2: then simple accurate models for everything else on my list (items, tools, creatures, pieces).

STANDING RULE BP-T44 (Dave 04:37 UTC): never stuck. If blocked or the wait could be long, move to the next item on my list. If I absolutely need Dave (permission/decision), ask Tyler via the coordinator to post a card on the QA page; a prompt in my thread window is not enough.

SHOWROOM (Dave 04:43 UTC): spawn x 53301 z 68427, grass cleared, rows of items on the ground, behind the Admin mode switch (Steve builds, Sal prepares item rows). Rows I want first: R1 three spade sizes + hoe + axe + bucket; R2 log species (oak, birch, spruce, maple, scots pine, mirrorbark); R3 foods/berries (raspberry and the other flora fruit); R4 chopping block, stone block, brick; later rows: each plant/bush species for the flora audit.

LOOK RIG (Dave 04:45 UTC): MikeW is building a one-command rig (item id, hand, camera angle, output file) that launches the game on Dave's PC, puts the item in hand and photographs it from the front. Use it instead of asking Dave to test hand items (torch, shield, shoulder log, spades). Until it exists use showroom / QA picture cards.

TEAM TESTS (BP-T46, tech/TEAM_TESTS.md): mine with MikeW's look rig: block-hand (chopping block in hand and placed) and axe-bucket (axe and bucket): render, attach two pictures each. Only "looks right to Dave" judgments go to him, with pictures. Ask MikeW via coordinator until I can run the rig.

CLOUD GODOT (23 Oct): Godot 4.7.2 downloads in the cloud: curl -sL -o g.zip https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip (headless only, no rendering). I use /tmp scripts to build tree_builder meshes and plot vertices with PIL (no Godot render). Branches: claude/kathleen-shrubs (raspberry, bramble, wild rose, blackthorn, blueberry, nettle), claude/kathleen-rock-pile (on steve-rock-pile).

PICTURE CARD RULE (Tyler 23 Oct 12:36 UTC): copy the picture into questions/img/ in the repo and add the line "Image: questions/img/<name>.png" to the card, else Dave's page cannot show it.

REFERENCE PHOTOS (Dave 23 Oct): wild blueberry berries in a palm, bush close-up, field: /mnt/project-files/art/reference/ (IMG_4454-4456). Wild blueberry = low dense carpet 0.25-0.5 m, tight clusters of 3-8 dusky-blue berries with dark star crown, small oval leaves green/red/orange. Raspberry reference photos earlier (3) came with Dave's raspberry message (not saved).

RIG BUG (23 Oct 13:43): the look rig's shot_runner.gd passed bare species ids so every rig plant looked like species 0 (a tree); fixed by Steve on claude/steve-flora-draw. Earlier "no fruit/blank nettle" findings from rig renders before that fix are void; re-judge shrubs from new renders. Shrubs branch claude/kathleen-shrubs holds: raspberry, bramble, wild rose (Dave's photos), blackthorn, wild blueberry (low carpet, photos), nettle (photos), berry item looks, FLORA_DEBUG env debug line. Next: low berries (lingonberry, cranberry, cloudberry, strawberry, crowberry), then herbs and flowers by audit order.

## HANDOFF 2026-10-23 17:10 UTC (Dave's day-end reset; Kathleen_ArtisticDirector)
### Branches (all pushed; Tyler merges; nothing is merged by me)
- claude/kathleen-shrubs (572bfea0): raspberry (upright cane clump 1.5-2.5 m, prickles, flowers, red+yellow berries), bramble (long arching thorny canes), wild rose, blackthorn (dense twiggy dome, spines, sloes, spring blossom needs the game to pass season), wild blueberry, nettle, low berries (wild_strawberry, lingonberry, cranberry, cloudberry, crowberry via _ground_berry), 18 wild flowers/herbs via _wildflower (daisy/umbel/spike/bell). data/tables/flora.json changed = RESTART label. Vertex budget (Steve): near <=4000, far <=800; all checked with /tmp scripts (lost; recreate: Godot 4.7.2 download, headless script that builds each species via TreeBuilder.build and counts vertices). Berry item looks in basic_look.gd/gen_looks.py ("berries", "round_berries").
- claude/kathleen-wolf-howl (47ef6de7 + credits commit 9ff1e9f4): recorded/creatures installed: wolf_howl_0/1 (Pixabay), bear_growl_0/1 (Pixabay), horse_whinny_0/1 (Pixabay), all 12 dB quieter (peak -14 dB) after Dave said too loud; fox_bark_0/1, fox_scream_0, moose_grunt_0/1, moose_bellow_0/1, deer_grunt_0/1 (Dave's own homemade recordings, cut from the uploads saved in art/dave_sources/); synthetic moose grunt reshaped (placeholder); tools/clip_check.py (noise/SNR/clipping check, trim, --first-event, --max-s); SOUND_DROP_IN.md (where/how to add recordings); credits rows; questions/audio compare clips.
- claude/kathleen-dirt-blob (faec876f): soil/clay = lumpy earth clump with crumbs, sand = grainy patch, gravel = stone heap (basic_look shapes "clump" and "grit"; looks.json regenerated). Dave called the old dome "a fancy pastry". MikeW to check in rig (look down, 1 m back).
- Older, check state with Tyler: claude/kathleen-torch-rain, kathleen-log-carry, kathleen-log-looks (on sal-tree-logs), kathleen-wet (not hooked), kathleen-rock-pile (pile_look.gd on steve-rock-pile), kathleen-wood-looks, kathleen-raspberry (superseded by shrubs). Obsolete, may be deleted: spades, materials, shovel.
### Dave's decisions today
- Wolf call: "perfect, the real one" (Pixabay clip A). Wolf/bear/horse great but too loud (fixed -12 dB). Fox/deer/moose recordings from Pixabay/elk were wrong; Dave supplied his own (homemade) and said use them. Elk bugle as moose: No. Real moose: low cow moan / nasal long call, not a short strained grunt (notes art/MOOSE_CALLS.md).
- Plants: Dave's photos/descriptions for blueberry, nettle, wild rose, blackthorn, raspberry are the reference (art/REFERENCE_PHOTOS.md, art/reference/). His "No, looks terrible" on the cane berries led to the rebuilds. Dirt looked like a fancy pastry: fixed. Old QA cards for rose/blackthorn, nettle/blueberry and wolf compare were removed at his request.
- Dave's test rule: when checking things on the ground, look down / step back and look down; never walk away from what is checked.
### Open items, in order
1. MikeW's clean rig renders (no grass, one plant per picture, 3 m, tilted down) of raspberry, bramble, blackthorn, wild rose, blueberry, nettle, low berries, wildflowers (rows: chamomile, dandelion, wild carrot, lavender, foxglove): judge them against the photos, fix what is off (blackthorn last render was too sparse before the latest rework; raspberry leaf undersides pale and berry calyx cap not done), then post ONE picture card per plant with qa_post.py (image in questions/img/, "Image:" line, recommendation).
2. Still generic plants: ferns (fern, comfrey, burdock, mugwort, belladonna, henbane, staunchmoss, hushfern, whisperfern, echo_moss), mushrooms (all), reeds/grasses, aloe, sorrel, watercress, wild_thyme, wild_sage, plantain, samphire, tanglewort, and the fantasy plants. Compare each to the real thing, simple accurate models.
3. Remaining synthetic creature calls: deer snort, moose snort, wolf growl, bear roar, horse snort, rabbit thump/squeak, duck quack (tone sketches; Dave prefers real recordings). Real moose cow moan/long call for the idle call wanted.
4. Cave-in skull PNG replaces _draw_skull in cavein_death.gd (Steve's branch claude/steve-cavein-death); two stings; cave-in death voice via offline TTS (MikeW/Kokoro on Dave's PC).
5. Beach sand footsteps (run a lot lower, walk slightly); torch crackle check; open-field rain recheck; wet-tunnel hook; tiers in PieceLook (waits on Sal's ids); bark texture on logs; BP-T42 check of the flora.json "womens_health" tag (Sal/Tyler own it).
6. Spring blossom state only shows when the game passes season to TreeBuilder.build (flora_view passes "" today): ask Steve.
### How to work
Run python3 tools/qa_post.py from the repo dir. Run tools/check_warnings.sh --changed (zero new warnings). Commits end with the Co-Authored-By and Claude-Session lines. Offline stills: download Godot 4.7.2 (github godot-builds, 4.7.2-stable) and use xvfb-run with --rendering-driver opengl3; leaf textures do not show offline (leaf cards look like plain squares), so only shapes can be judged. I cannot listen to audio: judge by levels, Dave judges by ear.
