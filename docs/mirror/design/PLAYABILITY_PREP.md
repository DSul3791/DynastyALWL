# Playability prep: shortest path to a playable first hour (Tyler, 24 Oct 2026, 19:45 UTC)
Devstop is on: nothing merges to generator-v2 and no bakes until Dave says go. Everything below is prepared so it lands in a few builds the moment he does. Source: EARLY_GAME_LIST.md steps 1-16 and Dave's QA answers (QA_ANSWERS_24OCT.md). Checked against generator-v2 data files today.
Legend: EXISTS = in the game now. CODE = code on a branch, tested or testable. PLAN = plan answered, no code yet. NEW = nothing yet.

## Steps 1-16: what exists, what is ready, what blocks
| # | Step | State | Blocker / what is needed |
|---|---|---|---|
| 1 | Wake at spawn, empty pack, sticks and stones within 5 m, hints on | PARTLY: spawn extras exist (drops.json spawn_boost: sticks and stones near respawn); hints exist (inner_voice) | NEW: "become a new player" admin switch (Dave said yes). Spawn point itself is chosen last (see 788+ order) |
| 2 | Pick up stone, stick, fibre | EXISTS (E; hold E sweeps) | Auto pickup P: PLAN (default off) |
| 3 | Twine from 3 fibre by hand | EXISTS (recipe twine, plant_fibre) | none |
| 4 | Stone axe first tool (1 stone, 1 stick, 5 twine), log = 4 blocks | EXISTS (recipe stone_axe; wood chain merged) | check recipe cost equals Dave's numbers (Sal) |
| 5 | Fire in three sizes (tiny/campfire/bonfire) | EXISTS as one size (campfire, burn times, rain puts out, light with fibre); sizes by wood: PLAN (Sal_fire_tiers, Dave said yes to three pieces and small cooks) | NEW: fire strength per wood in code, client flame size and light |
| 6 | Sit by the fire under a tree, canopy = rain cover only | EXISTS (rain cover rule); warmth vital exists (warmth.json) | verify cold really bites in R1 (Mike's first-hour test) |
| 7 | Spear (stick + rock), stone spear later | EXISTS (wooden_spear, spear recipes) | recipe costs to match Dave (Sal) |
| 8 | Drink, forage, eat-once, sickness costs food and water only | EXISTS (sickness.json, drops, water); rule "no health loss in R1" | check sickness.json: needs a flag (Sal) |
| 9 | Shore net fishing | NEW: fishing is a server roll on hidden stock (fishing.json, rod exists); shore net item and "stand at a ripple spot, hold E 20 s" PLAN (Dave said yes) | NEW item, recipe (20 twine + 4 stones), action |
| 10 | Lean-to shelter | EXISTS (lean_to structure) | none |
| 11 | Thatch everywhere (grass clump plant in patches; bark from felled trees) | PARTLY: thatch item and weight exist; NEW plant and gather rule (Sal_thatch_sources: PLAN, Dave said yes) | flora VERSION bump, no spawn placement |
| 12 | Pieces not rooms: foundation, wall, roof; blueprints and direct; 100 percent refund; blueprint maker on the hammer | PARTLY: building tiers and blueprint placement exist; PLAN: hammer menu, blueprint maker, grand blueprints, 100 percent refund | hammer rework (see 15); direct-from-hotbar route |
| 13 | Rough bed (10 thatch + 4 sticks + 2 twine) under any roof; lie Z, sleep | PARTLY: sleeping exists (sleep.json: Z hold, covered vs open quality); bed ITEM NEW | rough_bed item and recipe; respawn at own bed (Dave yes) is NEW |
| 14 | Camp bench: handles, better nets, tool kits, no planks | PARTLY: workbench structure and recipe exist | decide which recipes it holds (Sal) |
| 15 | No stone pick; stone axe breaks rock; hammer ladder wood-wood-twine, stone, copper, bronze, iron, steel; NO adze | PARTLY: stone_hammer exists, adze exists | remove adze; hammer recipes and durability tiers; hammer = blueprint menu (Sal_tools) |
| 16 | Cooking: tripod pot, clay hearth, cook on the tiny fire | PARTLY: campfire cooking and dishes exist (cooking.json), clay_pot exists | tripod pot and clay hearth items NEW (Dave said yes to three stations) |

## What blocks a playable first hour today (shortest list)
1. **Join hang (BUG-001)**: fixed and tested on branch (steve-ground-hang 9774c028). Must be first.
2. **New-player switch** so we can time the real first hour (Mike with stopwatch: fire under 15 min, shelter under 90).
3. **Fire sizes + cooking on the tiny fire** (steps 5, 16).
4. **Thatch plant and gather** (step 11), then rough bed (13) and shore net (9).
5. **Hammer/adze rework** (15) because it is also the building menu.
6. **Spawn point** near stone (hard stone 450 m E is the one measured gap), fishable water, fibre. Chosen last, after the world is settled (Dave's rule: nothing is placed because it is near spawn).

## Merge order after Dave says go (tested ids only, one build each, David3 runs tests, Mike plays)
- **788 (safe tools and fix):** steve-ground-hang 9774c028 (BUG-001), david3-rig-only e792d7c5 (Mike PASS in), steve-rig-item 0fe597e5 once Mike passes it. No data change. Dave: Fetch, Pull, play 5 minutes, report the join.
- **789 (R1 core rules, RESTART):** Sal: new-player switch, fire sizes, no stack caps (option A), auto pickup P, stone axe/spear cost check, sickness flag. Needs plans answered (done) and branches pushed (not yet). Dave: Reset terrain edits not needed.
- **790 (R1 building and survival items, RESTART + flora VERSION bump):** thatch plant, thatch wall piece, rough bed, shore net, tripod pot, clay hearth, hammer rework (no adze), blueprint maker, 100 percent refund. Kathleen: evergreen thick belt and dirt pile in the same build (flora VERSION 4 to 5). Dave: Reset terrain edits, Clear blocks.
- **791 (ambience, RUNTIME):** cave air + cave pollen (Steve + cave-light thread).
- **792 (final terrain, BAKE):** one bake by MikeW (David3 as overflow) from sonny-outlets 4f2d2497 plus Dave's terrain notes, then the spawn point is chosen, then tiles and code merge together. Dave: Pull, Reset terrain edits, Clear blocks, walk from spawn.
- If time is short: 788 and 789 alone give a playable fire-and-spear start; 790 gives the shelter hour; 792 can slip.

## Who does what now (devstop: planning and tests only)
- David3 (server box): run every test on each branch the moment it is pushed, take one picture per visible change.
- Mike: stopwatch first-hour test once 789 exists; the Windows checks.
- Sal: push the 789 and 790 branches as soon as the devstop ends (plans are all answered). Steve: cave air. Kathleen: evergreen belt, dirt pile. Sonny: final bake inputs.
- Tyler: one plan answer per branch, then merge by the list above.

## Open for Dave (only these)
1. "Go" to end the devstop. 2. The two unanswered play-test cards (duck sounds, craft the new tools; the second is now partly obsolete because the adze is removed). 3. Spawn point choice later: near the stone outcrop and fishable water (a world-level decision after the bake).

## Inputs still to fold in (update this file, do not write a new plan)
- Sonny's terrain blockers (final bake, 792): not received yet. Known: ore fix 4f2d2497 waits for Dave's terrain notes; hard stone outcrop 450 m E of spawn.
- Sal's spawn counts (sticks, stones, fibre, thatch near the chosen spawn): not received yet; feeds step 1 and the spawn choice.
- David3's smoke test (one run of the first-hour tests plus a spawn picture): selftest, gitcheck and GPU pictures pass; the headless test list and first-hour test result not received yet.
Related files: the list EARLY_GAME_LIST.md (steps), the answers QA_ANSWERS_24OCT.md, the merge queue tech/MERGE_CHECK_NEXT3.md, the principles EARLY_GAME_PRINCIPLES.md.

## OWNERS AND BRANCHES (Dave 19:41: only the list and principles; this table drives the work)
One branch each, one plan answered by me once, build starts when Dave says go. Branch names are proposals; owners push plan files first (already answered where marked A).
| List item | Owner | Branch | Plan |
|---|---|---|---|
| 1 New-player switch, spawn extras, hints on | Steve (server/admin) | steve-new-player | NEW plan needed |
| 1 Spawn point choice (near stone, fishable water, fibre) | Sonny + Sal (counts) | with the final bake | after bake |
| 2 Pick up (E), auto pickup P off by default | Sal | sal-auto-pickup | A |
| 3-4 Twine, stone axe cost check, log = 4 blocks | Sal | sal-r1-recipes | NEW (one small plan with 7, 15) |
| 5 Fire in three sizes, cook on tiny fire | Sal (data) + Steve (server) + Kathleen (flame/light look) | sal-fire-tiers | A (approved by Dave) |
| 6 Warmth under canopy rule check | Steve | with steve-new-player | in its plan |
| 7 Spear (stick + rock), stone spear | Sal | sal-r1-recipes | NEW (same plan) |
| 8 Drink, forage, eat-once, sickness no health in R1 | Steve | steve-new-player | in its plan |
| 9 Shore net, ripple spot, hold E 20 s | Steve (fishing) + Sal (item) | steve-shore-net | NEW |
| 10 Lean-to | exists | none | none |
| 11 Thatch plant in grassy areas, bark thatch | Kathleen (plant, look) + Sal (rule) | sal-thatch-sources | A |
| 12 Pieces, blueprints, direct place, 100 percent refund, blueprint maker, grand blueprints | Sal | sal-building-tiers | A (Dave answers in) |
| 13 Rough bed item, respawn at own bed | Sal (item) + Steve (respawn) | sal-rough-bed | NEW |
| 14 Camp bench recipes | Sal | sal-camp-bench | NEW (small) |
| 15 Hammer ladder, no adze, no stone pick | Sal | sal-tools-batch2 | A (plans updated) |
| 16 Tripod pot, clay hearth, drying rack | Sal (items) + Kathleen (looks) | sal-cooking-stations | NEW |
| 17-20 R2/R3/garden | parked until R1 is playable | | |
| Principles: hints (inner voice panel) | Steve | steve-inner-voice-panel | NEW, after 790 |
| Principles: build colours, physics shown | Sal | in sal-building-tiers | A |
| Principles: first hour timing test | Mike + David3 | no branch (test) | stopwatch plan |
| BUG-001 join hang | Steve | steve-ground-hang 9774c028 | done, tested |
| Tests on every branch | David3 (+ Mike on Windows) | claude/box-results | running |

## PARKED (not on the list; no work until R1 is playable)
Evergreen thick belt and coast fade (Kathleen), dirt pile compact, cave air and pollen (Steve, cave-light), [water and fish were un-parked at 19:42, see the section below], terrain final ideas beyond the bake needed for spawn, volcano. Their plans stay answered; they restart after build 790. Exception: no stack caps stays (weight, small) because stone and thatch stacks matter in the first hour.

## Merge order (replaces the earlier list: parked items moved out)
788 fix + tools (ground-hang, rig-only, rig-item) | 789 steve-new-player + sal-r1-recipes + sal-fire-tiers + sal-auto-pickup + no-stack | 790 thatch + building tiers/blueprints + rough bed + shore net + hammer ladder | 791 cooking stations + camp bench + inner-voice panel | 792 final bake + spawn point | later: parked items.
Chase list for me: (a) 5 NEW plans to answer once each: steve-new-player, sal-r1-recipes, steve-shore-net, sal-rough-bed, sal-camp-bench, sal-cooking-stations; (b) each owner pushes their branch the moment Dave says go (or earlier on their own branch: building on branches is a new branch, which the devstop forbids until Dave says go).

## Folded in from FIRST_HOUR_WALKTHROUGH.md (19:45 UTC)
Two blockers the walkthrough found, now in the plan:
1. **Recipe learn path (BLOCKER, no building possible).** Every wall, floor, roof, foundation and doorway recipe is known=false and craft() refuses unknown recipes. **Owner: Steve** (branch steve-new-player, build 789). Tyler's shortest-path ruling: for R1 every recipe on the list is KNOWN from the start (known=true, set from one data list); no learning system is built now. The "show what's missing" ghost and learn-by-doing come later (principle 3) and are parked. Why: Dave's list never mentions learning recipes, and a learn system is a new design.
2. **No thatch source.** Thatch plan (Sal_thatch_sources) is answered and approved; the clump plant and thatch yield are the first item of build 790. **Owner: Sal (rule) + Kathleen (plant, look).** Until it lands, fibre gives twine only.
Also now in the table (Sal, sal-r1-recipes): stone axe is 1 stone + 1 stick + 5 twine (today 2 stone + stick), wooden spear 1 stick + 1 rock (today 1 stick), stone spear +5 twine and the same rock, hammer wood+wood+twine (no adze), campfire cost lowered (today 20 sticks + 10 stones kit) with the tiny stick fire, light by fibre today and stone striking later. Building recipes must use thatch, twine and sticks (Dave's 20 twine, 50 thatch, 15 sticks), not lumber, so they work without a sawmill. Steve: shore net recipe and "hold E at a ripple spot" action (steve-shore-net).
Updated merge order: 788 fixes/tools | 789 recipes known + new-player switch + recipe costs + fire sizes + P + no stack caps | 790 thatch plant/yield + thatch wall/foundation/roof pieces + rough bed + shore net + hammer ladder | 791 cooking stations + camp bench + inner-voice panel | 792 final bake + spawn point. A first-hour play test by Mike (stopwatch) is the gate after 790.

## WATER AND FISH: UN-PARKED (Dave 19:42: "the water and fish are part of all that")
They stay OUT of the first merges (788-792). They start as plans and branch work now (devstop: plan files only, branches wait for Dave's go) and merge in this order after 792, one build per row, tested ids only, David3 runs the tests, MikeW or David3 runs any bake the water work needs.

### Water order (design/WATER_LAND_TYPES.md section 7 and 10.5; plans in design/WATER_ACTION_PLANS.md)
| Order | Piece | Owner | Branch | Label | Gate |
|---|---|---|---|---|---|
| 1 | R1 land-type signature and admin map | Steve + Sonny | claude/water-r1-landmap (first plan written) | RESTART | map table, no bake |
| 2 | P1 dam test (sim-side set-ground-height, scripted fills in the starter river) | Steve | with R1 | RESTART | measure level upstream |
| 3 | P1b water stability test (time step, outflow limit, scripted 3 m pond breach, mass balance, no NaN) | Steve | water-p1b | tool/test | must pass BEFORE any breach ships |
| 4 | R2 plants by land type (cattail, sedge, sphagnum, marsh marigold, peat item) | Kathleen + Sal | water-r2-plants | flora VERSION bump, RESTART | Dave resets terrain edits |
| 5 | P2 barrier records, load, warning, slow breach (with the dig-never-during-a-settle rule) | Steve | water-p2-barriers | RESTART, protocol number only if needed | breach test |
| 6 | R3 succession (dead/sapling state, chunk refresh, farmland flood timer of about a week) | Steve + Kathleen | water-r3-succession | RESTART, new save field | save-compat test |
| 7 | P3 wash-away (client sweep from water speeds, server damage check, items) then structures | Steve + Kathleen | water-p3-washaway | RESTART | no death at first |
| 8 | P4 bridges: ford, plank bridge, stone bridge with piers (poles 5 m from the deck, ramps down to the same height) | Sal | water-p4-bridges | RESTART | flood ratings |
Dave's yes answers cover all of it (QA_ANSWERS_24OCT.md: window, dam order, dam strength, breach, wash-away, bridges, dead trees, tree speed, farmland timer).

### Fish order (design/FISH_AND_FISHING_PLAN.md section 7)
| Order | Piece | Owner | Branch | Label |
|---|---|---|---|---|
| A | Data: sea and river types, species by depth, school/jump numbers, net/bow/spear factors | Sal | fish-a-data | RESTART |
| B | Water classifier (x,z to brook, river, lake, pond, sea shallow/mid/deep + depth) | Steve (Sonny reviews) | fish-b-classifier | RESTART (reuses R1) |
| C | School module server_fish.gd (placement, drift, stock link, salmon run in autumn) | Steve | fish-c-schools | RESTART |
| G | Shore net, bow and spear water hit, school factor in the roll | Sal + Steve | fish-g-net | RESTART |
| D | Jump event (protocol bump, rate limits) | Steve | fish-d-jump | RESTART + PROTOCOL |
| E | Client splash, ripples, shadows, sounds | Kathleen | fish-e-client | RUNTIME |
| F | Raw fish items and cook/smoke recipes | Sal | fish-f-items | RESTART |
| H | Tests: deterministic placement, never outside water, stock conserved, jump caps, 20-player load | Steve + David3 | in each branch | test |
Order: A, B, C, G first, then D and E, then F, then H throughout. NOTE for the first hour: step 9 (shore net) ships EARLY as the minimal item and action in build 790 using TODAY'S hidden-stock roll (steve-shore-net); the full school system (A, B, C, G) replaces the roll later, so the early game does not wait for water or fish.

### Merge order with water and fish added (after Dave's go)
788 fixes/tools | 789 core rules | 790 thatch, building, bed, minimal shore net, hammer | 791 cooking, bench, voice panel | 792 final bake + spawn | 793 water R1 + P1 dam test + fish A/B | 794 water P1b + fish C/G | 795 water R2 + fish F + fish D/E (needs protocol number) | 796 P2 barriers | 797 R3 succession | 798 P3 wash-away | 799 P4 bridges. Parked still: evergreen belt and coast fade, dirt pile, cave air and pollen (restart after 790).

## Final bake plan (Sonny, 24 Oct 19:44; replaces the 792 line)
Build 792 = ONE bake: branch claude/sonny-final from sonny-outlets 4f2d2497, with ONE TERRAIN_VERSION bump, and ONLY the spawn move (after Sal's spawn search). A clean chute and plunge pool in drainage mode only if Dave wants it. Sonny withdrew the ore clamp and the stepped cascade (Dave's 21 Oct rule: no steps). Hill face stays as it is unless Mike's ground-level render of the baked tiles looks ugly. BP-T53 and BP-T54 apply (bake by MikeW, David3 overflow; tiles via git; island table with the code commit id). Tyler merges code and tiles together on a PASS.
Status 19:55 UTC: build 788 merged (BUG-001 join fix, look_rig Linux). Plans answered: fish A, B, C, G, water Plan 1, steve-new-player (789), steve-shore-net (790). Still to answer when pushed: sal-r1-recipes, sal-rough-bed, sal-camp-bench, sal-cooking-stations.

### Final bake additions (Tyler, 24 Oct 19:58 UTC; Sonny's pond/hole causes) - branch claude/sonny-final
a) river_start 0.15 km2 where slope is over 25 degrees (rivers start lower on steep reaches).
b) inland crest cuts capped at 6 m; 20 m only within about 600 m of the sea.
c) valley freeboard 1.0 m (was 0.4 m) on flat reaches (fall under 2%), plus basin carve at springs (water Plan 1 item 6: 0.5 m below the 3-cell ring).
d) river heads only where slope is under 10 degrees.
Order: Sonny first reads Mike's dump from the 5a5745de bake to see if the wall/pit predate the caps. NO bake until Tyler schedules it. Island table must carry the code commit id (BP-T54).
QA check after bake (David3 headless, Mike picture): pond at x 53840 z 68520 no longer spreads over the flat floor; no 20 m step or 20-25 m 3x3 pit in the crest gorge (max depth scan); every spring passes the catch-basin test; settle test clean; island_checks as before.
e) (Tyler, 24 Oct 20:03 UTC) CAUSE of Dave's pit/cliff: since river_start 0.35 km2 (v30) this stream became a river; farm-valley cut + channel stamp cut a 25+ m trench into a 60-degree hill face. Fix sonny-final 17401b10 (valley cut size shrinks with ground steepness), UNTESTED (no Godot in cloud). Gate: Mike bakes tile (3,4) from 17401b10 in the second clone; Sonny compares the same window; David3 runs the max-depth scan. Only on a clean compare does it join the 792 bake (TERRAIN_VERSION bump once, BP-T54 island table with the code commit id).

## MIKE HOLD (Tyler, 24 Oct 20:08 UTC; Dave is playing on his PC)
Until Dave says done: Mike runs NO tests, renders or bakes. All tests and pictures go to David3 (server box). Merge only on a David3 PASS. WAITING ON MIKE: tile (3,4) bake from sonny-final 17401b10 (item e), Sonny's heads bake, Kathleen piece re-render, Windows look_rig checks, first-hour stopwatch play test (gate after 790; David3 headless test_first_hour stands in for logic, Mike still needed for feel). Mike may still do non-PC help: docs, plans, building/data work other threads ask for.

### Final bake source update (Tyler, 24 Oct 20:33 UTC)
Bake source is now claude/sonny-final 22a9ff02 (UNTESTED), replacing 72d60408 and 17401b10 (item e): forced channel to the sea, freeboard 1.0 m, smaller meander swing, head basins, steep-valley fix. Same gate: Mike bakes only when Dave's PC is free; David3 headless checks first; island table carries the code commit id (BP-T54); one TERRAIN_VERSION bump.
SPAWN (decision for Dave AFTER the bake): Sal found no spot with hard rock within 300 m. Sonny recommends spot 1 = x 53304 z 68464 (37 m from old spawn), stone rule relaxed to 450 m, plus a small bake-time knoll at x 53450 z 68460. Dave picks the spawn after seeing the baked result; QA card then.

### Final bake source correction (Tyler, 24 Oct 20:37 UTC)
claude/sonny-final is now 22585d73 (72d60408 and 22a9ff02 did not parse; restored). Adds _carve_basins (head ponds depth 2-8 m radius 25-120 m; lakes about 2-18 ha on flat reaches, sized by Qs = 0.1 x catchment km2) on top of forced channel to the sea, freeboard 1.0 m, steep-valley fix. Gate in order: David3 parse check; Mike's (3,4) bake (when Dave's PC is free); Sonny reads the tile (pit/cliff window, dead ends, river reaches the sea, basin counts); water thread's basin check. Then the full 792 bake.
Bake source now claude/sonny-final c2eeb8e3 (Tyler 20:42 UTC; supersedes 22585d73); same gates. Water R1 settler v7 merges together with it.

## MERGE ORDER UPDATE (Tyler 24 Oct 22:50 UTC; Dave approved the erosion carve "make it so")
791 = bundle claude/tyler-791a (thatch, unknown-item, bed recipe, shore net, auto pickup, held tools, forest beds, sound guard, wind-surf)
792 = fire tiers + tripod pot (recipe 165) + no-stack caps + weight audit (after Dave's four weight cards)
793 = EROSION CARVE + FINAL BAKE as ONE bake: erosion thread's BAKE plan (tile_baker.gd delta, valley_guides off, nine-tile rebake together) on top of claude/sonny-final c2eeb8e3 (basins, freeboard, spawn move), water R1 settler v7 together; ONE TERRAIN_VERSION bump. Reason: two bakes would mean two bumps and two rebakes of the same nine tiles, and Sonny's pit/cliff fixes act on the same terrain the carve changes.
794 = water P1b + fish C/G (was 794 as 793-799 shifted by one): water order unchanged, each number +1.
Gates for 793: erosion plan answered once on arrival; macro-height raster in git with the run command and seed (byte-identical on two runs, David3); David3 headless checks first; Mike bakes in the second clone when Dave's PC is free; island table with the code commit id (BP-T54); Sonny reads the tiles; Mike ground-level render; merge code + tiles together on PASS.

SPAWN for 793 (Sal, 24 Oct 23:08 UTC): x 53316 z 68476 (flat 4.1 deg, dry, sandstone ~428 m, river 30 m, clay close). Sonny pins it in the merged bake branch; bake gate re-checks flat+dry after the erosion carve. Dave still confirms after the bake (QA card).
