# Steve_002 handoff (Technical Director), written 2026-10-22 night (Dave stopped for the night ~05:35 UTC)
Read Steve_001_HANDOFF.md first for role and traps; this adds what changed. You are Steve_003.
## Changes since Steve_001
- DEV STOP lifted 03:51; Dave's FOCUS RULE (end of tech/JOBS.md): present only: crashes/stalls, movement/physics, water flow, tunnels, friend-session play loop. Far items parked (scale beyond friends, load-exertion, flood damage, armour, voice, banking).
- Ownership (JOBS.md, PROCESS.md): Willy = ONLY the ground and its shape; Tyler = everything unassigned, now writes code; Mandy art/sound; Sonny water; Radar items/NPC.
- PROCESS.md RULE 2: no test requests to Dave in chat; threads add lines to tech/TEST_QUEUE.md; you build ONE grouped test card in questions/QUESTIONS.md (options A saw/responded, B already answered, C all fine, D problem). Current card: test-626 (title says build 639, update it). Build-number rule: higher of BUILD constant and last log line, plus 1, in the same push. Push often fails when branch is busy: pull --rebase and retry, and CHECK the push worked.
- Question page qa.html: title "Questions & Tasks for Dave", notes lines under a question are shown.
## Decisions made (all in tech/DECISIONS.md, 01:45 to 05:55)
Scale plan gaps folded in (section 13 of SCALE_PLAN); compaction approved (build 614, kill switch settled_ground in data/network.json); load-adaptive exertion approved in principle but PARKED; flood plan A to C approved (runtime), E waits; plunge pool south spill = option B carve (bundle, TERRAIN_VERSION 26); frozen worldgen warning cleanup = NO (Dave); bracing design approved for steps 1 and 2 only, collapse (lethal) needs second approval and a test card, windows in real minutes, no surprise death (90 s warning), offline players pending question collapse-offline.
## Open
- NEXT BAKE bundle OPEN (JOBS.md): carved south chute (B) + pond-outlet carve limit; owner Sonny; gate: 882 tests, edge match, scratch hash tiles 3,3 3,4 4,4, Willy hillshade, TERRAIN_VERSION 26, no .tile/.water in the commit; you name the commit after rechecking generator diffs.
- Questions on page: test-626 (collapse-offline was answered, see DECISIONS 05:45). Answers land in questions/ANSWERS.md; act on them (remove from TEST_QUEUE, turn D answers into jobs).
- Review pending: Sonny's runtime pond fix is in (6c56706, 623), reviewed by reading only. Tyler's tunnel warning (protocol 68) is wired but silent until bracing timers exist.
- Threads' ids change on restart; Willy_002 had no live thread when I looked; messages to threads go through the coordinator.
