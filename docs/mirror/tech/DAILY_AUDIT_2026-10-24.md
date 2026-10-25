# Daily audit, 24 Oct 2026 (Tyler). Dave's order: what we did wrong, what we do better. Honest, with owners.
Day in one line: builds 788 to 791 merged, all on a David3/Mike PASS id; but Dave lost time to a join hang, empty QA cards, loud sounds, no way back to spawn and a pit in the terrain, and several things were found by Dave, not by us.

## What went wrong and the fix
| # | What happened | Cost to Dave | Fix (BP) | Owner |
|---|---|---|---|---|
| 1 | Fresh clone never found ground (BUG-001); no gate tested a fresh join | He restarted by hand, said "not acceptable" | Fresh-clone join test is a David3 gate for every build that touches ground/stream (BP-T57) | David3 (run), Tyler (gate list) |
| 2 | Threads did not post QA cards; the page was empty or lacked a count; Dave had to say so twice | Dave could not answer, work waited | At every merge I check that each branch's QA card exists on the page and the count line moves; missing card = branch not merged (BP-T58) | Tyler |
| 3 | I reported a sign-in fix as pushed when the commit had failed (git identity) | Wrong status, one wasted round | Never report "pushed" without the printed remote hash (BP-T59) | Tyler |
| 4 | Server box took four tries (scripts not on the branch, 8 GB memory OOM, a vacuous main-push test, quoting) | Dave ran extra commands | Box changes ship with a self-test that must FAIL on a deliberate break, plus memory measured before sizing (BP-T60) | Tyler, David3 |
| 5 | Recipe/item numbers clashed across branches (hammer 160/161, bed 160/162, shore net 160/163, tripod 163/165); branches built on stale heads (batch 2 "in 789" but not in head) | Rework by Sal and Steve, my trial merges | Every plan states its BASE hash; numbers are reserved in tech/NUMBER_RESERVATIONS.md before coding (BP-T61) | Sal, Steve, Tyler (file) |
| 6 | I fixed other people's small errors while bundling (description length, iterator name, next_number) | None, but hides the owner's lesson | Run merge_check + validate on a trial merge BEFORE handing to David3 and send the owner the failures (BP-T62) | Tyler |
| 7 | Terrain pit/cliff/pond reached Dave after several bakes (v30 to v41); causes found only on his report, then the erosion carve supersedes | Many bakes wasted; Dave saw ugly terrain | A pit/cliff scan (max depth, max step, pond width at springs) is part of island_checks and a PASS gate before any tiles go to Dave (BP-T63) | Sonny, Mike, David3 |
| 8 | Sound complaint (wind like surf) took 4 branches before the real cause (bus mapping) was found | Dave heard wrong sound for hours | Sound complaints: diagnose first with the F3 loudest-voice lines, one diagnosis note, then one branch (BP-T64) | Steve, Kathleen |
| 9 | Dave flew far from spawn with no way back; sliders and spawn return were asked for AFTER he was stuck | He was blocked | Every build note lists "how do I get out of trouble" for the new features (go-spawn, New player, Clear blocks); admin escape tools come before new gameplay (BP-T65) | Tyler, Steve |
| 10 | Dave's PC is a single point for Windows tests, hand views and bakes; hold at 20:07 froze Mike | Waiting on Dave to finish playing | Move everything possible to David3 (bakes overflow after byte-compare with Mike, hand views via box renders); Mike keeps only "feel" tests (BP-T66) | Tyler, David3 |
| 11 | Many docs for one fact (handoffs, pads, plans in two places); context loss risk | Coordinator and I re-asked each other | One driver per phase (PLAYABILITY_PREP.md); handoff file lists only open items and ids (template in HANDOFF_Tyler_2026-10-24_2340.md) | Tyler |
| 12 | Research asked by Dave was done from page summaries, some timings missing | Risk of wrong claim | Research notes mark "verified" vs "background" (done in both notes) and name a single first step | Tyler |

## What went well (keep)
- Every merge was a PASS id; two cloud checks (parse_scan, merge_check, local_check) caught items next_number and description length before Dave saw them.
- One-answer plan rule held: every plan got one reply; no ping-pong.
- David3 box now runs tests/pictures and Mike is no longer the only gate.

## Open risks for tomorrow (watch)
793 is one big bake plus a 33 MB delta (one TERRAIN_VERSION bump); water R1 settler v7 rides with it; campfire pot + fire tiers coupling; weight audit awaits Dave's four cards.

## Routine
This audit is part of the daily handoff (20:00 ADT): copy the table, tick the items fixed, add new ones. BP-T57 to T66 are in tech/BEST_PRACTICES.md.
