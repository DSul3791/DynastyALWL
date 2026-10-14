# Design Review (2026-10-14)

A read-through of every design document: `DESIGN_IDEAS.md` (1,341 lines), `WORLD_FORMAT_SPEC.md`, `GENERATOR_V2_PLAN.md`, and the four older files (`README.md`, `GENERATION_GUIDE.md`, `PROJECT_ROADMAP.md`, `CHANGES_THIS_PASS.md`). The spec was also checked against the generator code where the two make the same claim.

Line numbers refer to the files as they stood before this review. Nothing has been changed yet; this file is the only addition.

Status tags in `DESIGN_IDEAS.md`: 316 Decided, 296 Proposed, 82 Idea, 69 Open, 1 Superseded.

## A. Check before step 13 (these affect the permanent tile file)

1. **The spec says tile edges are always the standard ocean value, which is no longer true.** `WORLD_FORMAT_SPEC.md` line 46 ("every tile edge converges to this depth") and line 111 ("the outer ring always holds the standard ocean edge values, so neighboring tiles agree automatically") describe the old design. Section 5b of the same file (line 164) says that rule was dropped on 2026-10-13: neighbors now agree because they read the same world elevation map in world coordinates, and islands may cross tile borders. The step 13 reader and writer must treat edge samples as ordinary data. Fix: rewrite those two lines.

2. **The spec's global ID includes the tile revision, and the code's IDs do not.** Spec line 148: "A global ID is (tile x, tile z, tile revision, local ID)". The code writes IDs as `x,z#local` (for example `3,4#101`). If revision were part of identity, replacing or re-encoding a tile would orphan every record NPC miners hold against its ore bodies. Fix: identity is tile x, tile z and local ID; the revision stays only as a cache marker. Also note IDs are unique within a list (provinces use 0 to 15, features cell×100+n, sites from 8001, placers from 9001), not across lists. The spec should say so.

3. **Size arithmetic error.** Spec line 127 says "about 13 bytes per sample, about 48 MB". The map table adds up to 14 bytes (2+2+1+1+1+1+1+1+1+1+2), and 1,921 × 1,921 = 3,690,241 samples, so about 52 MB before compression.

4. **Question 41 (which geology features a tile stores) is the one real "confirm before keeping tiles" item.** It was marked to be confirmed at step 13. What the tile would store, from the current code: province cells with layer stack and fold settings; features (intrusions, faults, vents and pipes, salt domes); ore bodies with the vein, lens, pipe, layer, halo, scatter and placer shapes; cave skeletons, dens, dormant lairs, the harbor, and starter spawn and town block. What is not stored and is worked out later: surface rock, flint pebbles, bog iron, saltpeter, fertility changes. Everything designed in this session (towns, spirit, rubble, mail, adoption) lives on the server and needs nothing here. One possible exception is PvP zones, which should be a world-level map in `world.json`, never per tile.

5. **Two known generator gaps affect stored data.** The note in `GENERATOR_V2_PLAN.md` says detail and climate noise are not yet seamless across the world wrap, so tiles at x or z = ±10 will not match their neighbors on the far side (provinces already do). Rivers also end at tile edges. Neither matters for the starter tile (3,4). Both should be fixed before tiles on the world's outer rows and columns are kept.

## B. Contradictions inside `DESIGN_IDEAS.md`

| # | Where | Problem | Suggested fix |
|---|---|---|---|
| 1 | Lines 116 and 117 | Two Decided final sizes: "18 by 18 or 20 by 20" and "21 by 21" | Remove 116 |
| 2 | Lines 361 and 362 | Line 361 still says the center island has "jungle flanks". Line 362 says it is a desert. `WORLD_FORMAT_SPEC.md` line 69 repeats "jungle flanks" | Edit both |
| 3 | Lines 174, 256, 270, 1335 | Flora placement is Decided to be runtime. The what-lives-where table, island pipeline step 8, and Section 16 item 5 still say flora lists are baked | Edit all three |
| 4 | Lines 236 and 113 | Decided: grow the map by adding a row or column. Elsewhere the world is the full 21 by 21 from day one with placeholder ocean tiles | Mark 4.7 as superseded, keep for reference |
| 5 | Lines 472 and 474 | Receivership is "a week or two (in game time)" in one line and "real time" in the next. 474 is the later decision | Fix 472 |
| 6 | Lines 447 to 449, 453, 627 | Offline aging is Decided slower, an Idea to use the server clock for everyone, and Open. See D1 | Decide, then clean up |
| 7 | Lines 750, 751, 754 | Reputation fades "over about a week" but timing is "in-game days", and seven in-game days is seven real hours at 60-minute days | Pick real days or change the wording |
| 8 | Lines 882, 884, 888, 903 | Hostile takeover is Decided to depend on "guards" (882, 884) and Proposed to depend on "established" (888, 903). The two are not the same | Make "established" the Decided rule |
| 9 | Lines 508 to 513, 560 | Heir section still has "equal split" and "the will decides who you become or who owns it". Section 6.7 decided the whole dynasty goes to one successor | Rewrite 6.2 |
| 10 | Lines 651, 666, 866 | "Town block" is described as a founding building such as the town hall (651, 666), and as a small office at the centre with a circle of influence (866) | One definition in Section 2 |
| 11 | Lines 899 and 905 | Line 905 says the mail role's name is "to be chosen". Line 915 names it | Delete the stale phrase |
| 12 | Line 895 vs 82 | A stale ledger that still shows a town you lost is deliberate, but the Legibility principle says to show the real state | Add a line saying why this is an exception |
| 13 | Lines 3 and 12 | Header says nothing is implemented. The revision history stops at Version 6 (2026-10-12), before about two weeks of decisions | Update both |

## C. Duplicated or tangled text

- **Starter towns** are described three times: lines 110 (Idea), 134 (Idea) and 135 (Decided), plus 652 to 653.
- **Section 8.12** mixes two topics. The town spirit and weather rules, plus a leftover editorial line ("Checked: this has not been in the design before") and a "(new idea)" heading, sit next to the server-owned town sale rules (836 to 840) that belong with 8.13 and 8.14. Lines 823 and 827 are the same decision (one Proposed, one Decided), and so are 832 and 834.
- **Section 8.13** bullets are out of order: deletion, rubble, roads and the town block are interleaved, and the "flag for deletion" bullets appear before and after the rubble definitions.
- **Section 8.15** says how word travels three times (lines 899, 904 and 905 to 907).
- **Section 13.8** keeps the older subscription ideas (lines 1169 to 1177), which line 1168 already says are superseded, and states paid duress blocks three times (6.1 line 467, 13.8 lines 1167 and 1181).
- **Section 6.1** states the real-money cautions twice (lines 489 and 490).
- **Terrain delivery** is an open question twice (line 274 and 4.10 lines 323 to 326), and the x-ray question (line 317) is already answered by the streaming recommendation (line 323).
- **Danger tiers**: line 354 and line 375 say the same thing about the inner and outer starters.
- **Section order**: 6.9 appears before 6.8; Section 15 puts question 63 before 59; line 756 is a stray bullet about businesses sitting in the land section.
- **Crucibles** are a Decided bullet at the top of Section 5 (line 382). They belong with the resource table in 4.9.

## D. Not fleshed out enough

1. **The aging clock is still open, and the new family design depends on it.** At 70 years in one real year, one year of age is 5.2 real days. A child reaches 10 after about 52 days and 15 after about 78 days (line 625). The family rules now say a child is a cost until 10 to 12, the player chooses to have children together with the spouse, and a successor can be a child. The document does not say how long a pregnancy is, how many children a couple can have, whether the clock runs while the player is offline, or how the heir "11 months of real time left" figure (line 510) holds up. Of everything here, this decision most blocks the dynasty design.
2. **There is no rule for real-time timers when the server is down.** Receivership, duress months, the 2 and 4 hour takeover windows and standing offers are in real time, but Section 7.6 says the server's clock advances only while the server runs. We need one rule, for example: windows pause during outages.
3. **Time units are mixed.** Reputation uses game days, spirit decay real days, duress real months, game days are 60 minutes only as a proposal (line 637, still Open). A small table of "which system uses which clock" would remove most confusion.
4. **Town block, circle of influence and spacing.** The circle's radius is never given. Outposts have "a much smaller radius" (line 800), roads inside the circle belong to the town (1081), overlapping blocks are Open (1084), and 8.1 proposes 3 km and 2 km spacing. These need one answer.
5. **"Established" town.** Guards, a well, a temple and "probably walls" are listed, but not how many guards, how strong, or how a town gains or loses the status. Combat rules in the "gray area" before that are not described, and PvP appears in 9.0, 8.15 and question 57 with no single rule.
6. **Flagging a town for deletion depends on administrators voting.** There is no trigger, deadline or fallback if nobody votes. The decay stages, how long each lasts and what a deleted town's records become are Open.
7. **Town spirit has no numbers beyond "about 10" and "about 1".** Missing: scale, floor values per feature, weather reach, how it combines with crop yield and with NPC mood. NPC spirit/mood is not defined in 8.8, which says "to be fleshed out when the first NPC is designed".
8. **Merging dynasties.** Duress merges (line 559) are Proposed. Not covered: what happens to the absorbed dynasty's members, children, debts and its reputation.
9. **Duress for towns.** Line 836 says a town works "like duress", but the actual rule is spirit decay and money, not the yield-penalty percentages used for dynasties. Say which.
10. **Weekly-rhythm tension.** A bare town block can be lost after a 2 hour window. That conflicts with the principle "never punish a weekly rhythm" (line 89) and with "safe, kind, generous". The earlier proposals (urgent alert, long windows for towns with a manager) are Proposed only.
11. **Rubble storage.** "A chunk" and "counted materials" are not tied together: how big a rubble chunk is, what happens to a pile when the tile's voxels are regenerated, and how counts are stored in the server's living layer.
12. **Wizard tower limits, mail costs and enchanted-pigeon speed** are all Open (lines 917 to 918).
13. **Mine rules** (11.2): the abandonment time is "three or six months", but dynasties revert to NPC at about ten months (line 465), so the mine's timeline can end before or after the owner's.

## E. Open questions that have been answered

These remain in Section 15 or in the text as Open even though a later decision settles them.

- Q9 and line 1035 (ore finite or renewing): settled by the three resource kinds (lines 394 to 398). Line 1034 (how NPC miners dig) is partly settled since stable ore body IDs exist.
- Q21, Q22, lines 673, 1065, 1066 (ruins, failing towns, bandit strongholds): settled by 8.12 to 8.14 (ruins stay as rubble, towns can recover through spirit, aid and sale, displaced NPCs become bandits).
- Q36 (will and successor): settled by the single successor rule in 6.7.
- Q39, Q40 (map growth, final height): the world is 21 by 21 with placeholder ocean tiles.
- Q54 is worded as a question but says "Settled".
- Section 14 (Current code status) is from 2026-10-11 and is wrong throughout: it says there is no climate, soil, lair or structure code and that deposit IDs are unchecked, lists the old rock and resource set (still showing gemstone and nickel), and gives the old 10 by 10 tile size.
- Section 16 (Candidate work) has steps 3 to 6 done and still says flora lists are baked.

## F. Other documents

- `README.md`, `GENERATION_GUIDE.md`, `PROJECT_ROADMAP.md` and `CHANGES_THIS_PASS.md` describe the old generator: 10 by 10 region tiles (10,240 m) and a shared world-bottom ocean edge. They are accurate for the old code, which stays until plan step 19, but a new reader would take them as current. Suggestion: add a one-line "old generator, retired at step 19" note at the top of each.
- `WORLD_FORMAT_SPEC.md`: line 3 says nothing is implemented; Section 6 is a superseded randomizer block of about 65 lines; Sections 7 and 8 still refer to the randomizer and the matrix; line 164 says the tile matrix is "still to be rebuilt" but Section 6b already describes the derived tile plan.
- `GENERATOR_V2_PLAN.md`: the "Next" line in the progress log is a chain of "formerly" phrases that is hard to read, and step 7 and step 5 text still describe the matrix randomizer and the -2,000 m shared edge.

## G. What I suggest

1. **Fix the mechanical items now** (no design decisions needed): A1 to A3, B1 to B5, B11, B13, the stale openings and headers in C and F, the Section 14 and 16 rewrites, and the answered questions in E. It is documentation only.
2. **You decide, one at a time:** D1 (the aging clock), D2 and D3 (timer rules), D4 (town block and circle of influence), D5 (what "established" means), and B7 and B8.
3. **Then step 13**, with A1, A2 and A4 settled first so the tile file's permanent parts are right.
