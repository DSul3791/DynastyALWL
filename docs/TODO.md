# Dynasty to-do list

**Reviewed 21 Nov 2026 against dev `53fb11a9`, and updated 22 Nov 2026 for the work merged overnight (dev `5be6b7bf`),** on Dave's request: "review our to do list and see what we have already done, what is no longer relevant and what still needs to be done."

This file is the one home for work that is **not built yet**. Other records keep their own jobs:

- [BugsList_Current.md](../BugsList_Current.md): Dave's play-test problems and requests. An entry stays there until Dave has played the fix, then moves to [BugsList_Fixed.md](../BugsList_Fixed.md).
- [Design_Ideas_Approved.md](../Design_Ideas_Approved.md): approved designs. This file only says whether they are built.
- The coordinator's Library logs (`/mnt/project-files/coordinator-log/`): the play-test notes and the day's merge log.

When a piece below gets a thread, write the thread name next to it. When it merges, delete the line here and record it in the BugsList entry or the design's built record.

**Who decides.** Dave, 21 Nov 2026 20:31Z: "make sure all agents ask you if they have questions for me. You are to answer them using what I would call common sense. Do not guess at the answers look up on the internet how other people are doing it and make an informed decision. record all decisions." Design questions therefore go to the coordinator, with a recommendation. Only these stay Dave's own: **assets** he makes (models, recordings), **main**, **live saves**, **world wipes** and the **robbery switch**. Lines marked **Dave: asset** or **Dave only** wait for him. Lines marked **Decision** go to the coordinator, who records each ruling (the coordinator's decision log in `/mnt/project-files/coordinator-log/`); CONSTITUTION.md stays the authority for how decisions are made.

## 1. Already done

Checked against the code and dev history, not against the lists' own tick marks.

- **BugsList_Current.md entries 1 to 127.** Every PR named in an entry's status is in dev's history. A sample was read in the code: pumps retired (#1388; records kept retired and locked, as designed), dune grass gives Plant fibre (#1421 set), Wicker basket on the knife, Steel nails, the log line writer (#1437). They are all still **not yet played**, so they stay in BugsList_Current.md until Dave plays them.
- **Tyler's queue** (docs/TYLER_NEXT_TASKS.md): 1 the ground scatter is capped by time (`SCATTER_TICK_MAX_MS`, server_items.gd); 2 `test_cover_async.gd` exists; 3 `ACT_ADMIN_ENERGY` is in PROTOCOL.md and `test_admin_check.gd`. The camp bench/drink server test and `tools/mutation_check.sh` exist.
- **Jason's sound queue** (docs/handoff/JASON_NEXT_TASKS.md): 4 lying down and getting up, and 5 being hit, have sounds (death and respawn sounds not checked) (`bed_lie`, `bed_rise` in terrain_client.gd; `player_hurt` through `hurt_event`, inventory_view.gd); 13 and 15 the credits check and loudness report tools exist (the credits themselves are still open, piece 10a); 20 to 23 already hooked in code (fire tiers, pickup, crouch steps, swim and drink); 6 and 7 bow and fishing cues exist (`data/sound/batch3_slots.json`, `slot_sounds.gd`).
- **Kathleen's art queue**: B1 cut logs have the bark look (`log_look.gd`).
- **Terrain and water backlog** (docs/TERRAIN_WATER_BACKLOG.md): 2 the near-water fix branch is merged and gone; 4 the new water is the only water (the old-water switch is gone from the code); 6 closed 5 Nov by protocol 85.
- **Stray branches the coordinator listed** are all fully in dev (`git merge-base --is-ancestor`; `claude/station-window-combined` by patch id, as 886523fe): `claude/project-thread-gdplep-buglist`, `claude/station-window-combined`, `claude/project-thread-2c1rn3-buglist`, `claude/project-thread-4ry8if-buglist`, `claude/project-thread-b2q2hj-docs`, `-ln57vt-docs`, `-5vocu1-docs`, `-8ix81s`, `-8ix81s-docs`, `-85m6x3-takes`, `-85m6x3-docs`. Deleting them loses nothing. Not deleted here.

### Merged overnight, 21 to 22 Nov (not yet played)
- Saves after big events (#1473); tool tier colours, Body A/B labels, hidden fruit trees (#1474); every placeholder look (#1492 to #1499, #1507); first-sight names and off-thread log lines (#1491); bog field timing (#1486).
- Also merged: ore plan and resource landscape (#1469, #1500, #1502), goals (#1495, #1498, #1501), animals (#1464, #1467, #1471, #1480), game trails, the Simple snare, the sun clock with moose and elk ranges, and fox rounds (#1484, #1497, #1504, #1509), Primitive kiln and smithy coals (#1461, #1487, #1488), the goblins' own cave (#1456), meteorites and Iron chunk (#1457), unloaded-tile reads (#1503), test plans for dev (#1489).

## 2. No longer relevant

- **The old team's own queues**, written 1 to 15 Nov for roles that no longer exist (Tyler, Kathleen, Jason, MikeW, Sonny, Dino): docs/TYLER_NEXT_TASKS.md, docs/KATHLEEN_NEXT_TASKS.md, docs/FLORA_NEXT_TASKS.md, docs/handoff/JASON_NEXT_TASKS.md, docs/TERRAIN_WATER_BACKLOG.md, GUIDE_TASKS.md, art/ART_TASKS.md. Work is now handed out by the coordinator, one thread per piece. Their open items that still matter are copied into section 3 (mostly pieces 10a and 12a); the rest is listed here. Each file now carries a banner saying so; their text is kept as history.
  - Anything about **kits** (Dino round 1, Kathleen B2 "ten kits"): there are no kits (Dave's ruling; hidden kit records go after main, section 3 piece 9).
  - Tyler's "delta pass not run" and test-slot plans of 1 Nov: superseded by Lane A and Lane B and the main gate.
  - Sonny's bake-set proposal (8, 9) and old branch list: the terrain has moved on to TERRAIN_VERSION 79 and the starter cache; `terrain-bake-set` and `water-flow-channel` remain as old branches only.
  - Jason 1, 8 to 11, 14, 16 to 19: written against code that has since been replaced (old body, old water, old QA page, branches gone). The sound items still open are in section 3 pieces 10a and 12a.
  - Kathleen A1 to A3, Round C: QA cards for 1 Nov looks. The open look work is the placeholder list (piece 5).
- **PROJECT_ROADMAP.md**: the release checklist of the earlier volumetric generator (its own header says so). Its one open line ("script/static checks ... before delivery") is now the main gate.
- **Pump items anywhere** (wooden and iron hand pumps, deep-well pump): Dave retired all pumps on 20 Nov (BugsList 95).
- **Medium curtains hair**: Dave dropped it.

## 3. Still to do

Grouped so that each piece can be one thread. Order is a suggestion (section 4). Already running elsewhere and **not repeated here**: world resource distribution, goal list and recipe check, natural animal movement and behaviour. The pieces held for the second merge on 21 Nov (#1455, #1456, #1457, #1459, #1460, #1461 and the Primitive smithy model) are all in dev now.

### Piece 1. Lag leftovers (BugsList 108, still open part)
- **Gate Z result (not BugsList 108; delete this line once Dave decides):** the cold first-join freeze grew from 24.0 s to 25.2 s. This is the same freeze as BugsList 93, measured by the gate's A5 rule: the longest FREEZE, median of 3 cold windowed Play runs, limit 24.85 s (set from main's 23.96 s). Dave, 21 Nov 2026, on that freeze: "thats not a problem. its expected on the first load" and "we should have a message that is clear that tells people that." (the message is built, PR #1405). The second main merge waits on Dave's choice: accept, or fix and re-gate.
- First-sight shader builds on d3d12 (0.5 to 0.9 s a new thing). **Decided, D-TODO-1** (coordinator, 21 Nov): keep d3d12 and warm up the materials near the spawn once, behind the "preparing graphics" note (BugsList 93). Step 1 is in dev: the FREEZE and HITCH lines name what is first shown in a slow frame, and log lines are written off the main thread (#1491). Still to do: the warm-up itself.
- Single physics steps of 44 to 51 ms; clock and weather at 31 to 37 ms.
- Server pauses in cheap code while the PC loads new ground tiles (thread counts).
- Done: the server's periodic checks and the position report no longer read a ground tile on the tick (#1503). Check whether any other server call still waits for an unloaded tile.
- ~~The bog iron field scan is untimed~~ Done: bog field builds are timed apart from the sync scan (#1486).
- Lighter character meshes for the lower quality settings (Kathleen's handoff, never started): measure first whether the bodies cost anything.

### Piece 2. Saves and crashes
- A crash can lose up to about a minute: the world saves every 30 s while something changed (`SAVE_EVERY_S`), and a save can wait about 1.2 s for the previous one (BugsList 108). Goals, coins and counters are in the same window (design/PLAYER_GOALS_REWARDS_AUDIT.md GA-55).
- The log writer may lose the last lines on a hard crash (gate review risk).
- **Decided, D-TODO-2:** keep the 30 s timer and also save soon after big events. Done in dev: a finished building, a trade, a station craft, sleep and a disconnect each start a save (#1473). Still open: the log writer's last lines on a hard crash.

### Piece 3. Body B and hair finishing (BugsList 90, 94; Body 2 is now Body B, Body 1 is Body A)
- First-person arms are Body 1's (no parts file for Body 2, docs/CHARACTER_SYSTEM.md). Try cutting her arms from her own model first; **Dave: asset** only if that cannot look right.
- Her feet may slide (walk and run retimed on Body 1); grip and shoulder log offset fitted to Body 1; sleep pose 8 cm lower; her own walk and run stand up to 11 cm high on the toes.
- Done, **D-TODO-3:** the bodies are labelled "Body A" and "Body B" with a short look note; BM-1 stands (no gender labels) (#1474).
- Light hair colours do not show: the hair is a dark painted texture tinted by at most 3x (`HAIR_TINT_MAX`, dynasty_body.gd), so blond and grey stay dark. Fix: tint a lightened, greyed copy of the hair texture instead.
- Crew cut sits like a cap band because Meshy painted it onto the head (BugsList 94). **Dave: asset**: a re-export of the crew cut without the head.
- Facial hair: no models yet. **Dave: asset**.
- Delete the old drawn hair styles in body_generator.gd (after main, Dave's cut-off).

### Piece 4. Tool tier colours and icons
- Done, **D-TODO-4:** every metal tool draws its metal in its tier's colour: copper red-orange, bronze dull gold-brown, iron dark grey, steel light cool grey (#1474). Not yet played.

### Piece 5. Placeholder looks
- Done: all 132 grey items now have their own look, in groups 5a to 5f (#1492, #1493, #1494, #1496, #1499), with fixes from the first Lane A pictures (#1507). Only `kindling_duplicate` stays in data/items/look_placeholders.json, for its number. Not yet played.

### Piece 6. Settlement size table
- **Decided, D-TODO-5** (a coordinator pick for Dave, under his 21 Nov questions rule; not Dave's own approval; corrected 22 Nov): the proposed city size table in Design_Ideas_Unapproved.md ("The settlement ladder") is adopted as written: hamlet 10 to 100, village 100 to 400, town 400 to 1,500, city 1,500 to 5,000, grand city 5,000 to 15,000, with radii 300, 450, 675, 1,000 and 1,500 m. Real medieval sizes were the sanity check (most towns well under 2,000 people; only the largest cities over 10,000). Still to do: record it in the design with its status, for Dave's review (piece 8).

### Piece 7. Bandit toll and robbery (BugsList 82, 83)
- Built and switched off. **Dave only** (robbery switch).

### Piece 8. Review the provisional picks
- D-TODO-1 to 7 (21 and 22 Nov) are coordinator picks made for Dave under his questions rule, not his own approvals; they are listed here with the other overnight picks for his review.
- The "Assumed on Dave's behalf" lists in BugsList_Current.md (several entries, and the list at the end) and the picks in the coordinator's AWAY ORDER log. Under Dave's 21 Nov rule the coordinator confirms or changes each one and records it. One docs-only thread.

### Piece 9. After-main list (coordinator, 21 Nov)
- River barrel; water at the cooking stations.
- Delete every kit record: **held, not an overnight job** (coordinator, 22 Nov). There are 191 `*_kit` records, 186 of them retired, across items.json, looks.json, encyclopedia.json, structures.json, recipes.json, blueprints.json and weights.json, plus code in basic_look.gd, held_item.gd and server_items.gd and about 12 tests. Saves may hold kit items, and item numbers are kept, never reused. It needs a plan (what an old kit item becomes, whether the numbers stay reserved) and Dave's say. Do not delete or renumber them before then. The irrigation thread has the sizes.
- Data CSVs import as keep: PR #1515.
- `.gdignore` for `art/`; rig tag display names; the freeze diagnostics PR.
- Release note: old smithies keep their fuel in slot 0 ("no fuel" otherwise).
- Bog silting against tunnels (BI-4 says no refill under 1 m; check it with a real tunnel).
- The gate thread's part 3 notes.

### Piece 10a. Sound and audio licences (before any release)
- assets/audio/CREDITS.csv has 7 rows marked TODO: Dave's footsteps, frog, tree-frog, fish-splash and crow recordings, origin unknown. **Dave only**: say where each came from, or they are replaced.
- Confirm the Kokoro voice-pack terms (anyone can check this).
- Jason 24: `validate_pack.py` reports about 500 UNREFERENCED files (generated folders not in the manifest's slot list).
- Jason 12: tree wind heard as rain in clear weather on 1 Nov; the code side is done, only a listen is left (one sound-log run at spawn).

### Piece 10. Release and server tools (split status)
- Real client and server exports (needs export templates on the build PC), the updater, QA forms. Docker has its own thread and goes after promotion.

### Piece 11. Approved designs not built yet (Design_Ideas_Approved.md)
Large systems; each needs a plan thread before code. Nothing for aging, estate debts or succession is in the code; death and rescue is partly there (src/client/rescue.gd, death_screen.gd).
- 11a Aging and lifespan.
- 11b Children and family growth (childhood, teaching, adoption).
- 11c Succession order, final-child fallback and the successor's estate debts.
- 11d Death and rescue: compare the approved record with what is built and list the gaps.

### Piece 12. Smaller gaps from the old queues
- Sound: 20 clips peak over the loudness limit (`assets/audio/loudness_report.py --check`; Dave's rule: creatures near -14 peak). **Decided, D-TODO-6:** no background music for now; later only as an option that is off by default.
- Fauna data gaps: passed to the animal thread on 21 Nov. Rabbits now keep loose groups (#1471); animals rest, follow the sun and keep their ranges (#1467, #1504).
- **Decided, D-TODO-7:** fig, olive and pomegranate stay as possible warm-coast trees (models still needed); mango, orange and lemon are hidden, keeping their numbers (#1474). Still open: fruit by month rather than by season.

### Piece 12a. Other leftovers from the old queues
Small; give them to a related thread rather than a thread of their own.
- Looks (Kathleen; her apple smoothing was edited and photographed offline on 1 Nov, so check only that it shows in game): a fire look pass (Dave: flames small and pale; smoke, sparks, torch flicker); crowns closer to real trees and orchard close-ups; firewood and kindling looks; thatch seen from behind; ground textures. Her two questions to Dave, the torch hand (`hand_mount_l`) and wiring `Crouch_Pull_and_Throw`, go to the coordinator. Building materials: data/items/structures.json has 184 `material` entries now, so check only whether any piece still lacks one.
- Flora and fauna (MikeW): `flora_wet_check.gd` still counts plants on wet cells and is in no gate; Sal's spawn-plan species are not wired; few animals show at noon (low day chances); flowers only at the forest edge, not the open meadow; wild rose drop (petals only, or hips); a client check of orchard picking.
- Tests (Tyler): the `items_check.py` client entry for camp bench and drink; the bot budget of 70; the creator preview lighting look; a numeric check of the erosion model (only if numpy is available, as Tyler noted).
- Sound (Jason 2, 3): stone, brick and thatch building pieces use their own place sounds; the shovel scoop says stone or soil from the server's answer.

### Piece 13. Housekeeping (lists only; nothing is deleted without permission)
- The stray branches in section 1, all in dev. The repository has 1,260 branches in all; a thread with delete permission can remove the fully merged ones.
- Old Lane A clones `testlane_a4` and `testlane_a6` on Dave's PC (E:\Software\godotDev). **Dave only**: delete them, or allow Lane A to.

## 4. Suggested order

Pieces 4 and 5 are done; the decisions in pieces 1, 2, 3, 6 and 12 are made (D-TODO-1 to 7).

1. Piece 8, provisional picks (docs only; clears questions before more code builds on them).
2. Piece 1, the rest of the lag (the shader warm-up first), and the rest of piece 2.
3. Piece 9, the after-main list (small, already agreed).
4. Piece 3, Body B and hair (ask Dave for the crew cut file at the start).
5. Piece 12 and 12a (smaller gaps, handed to related threads), and piece 6 (write the approved size table into the design).
6. Piece 10a, audio licences, before any release build.
7. Piece 10, release tools, once Docker is through.
8. Piece 11, the large approved systems, one plan thread each, after the above.
