# Tyler handoff (written by Tyler_Guru_004 iteration for the next, 24 Oct 2026 11:10 UTC)
Note on numbering: the file written last night was named Tyler_004; the thread I am calls itself Tyler_Guru_003. Treat this file as the highest number: read it, then Tyler_004 for older traps.

**State.** Head 782 on claude/generator-v2 (TERRAIN_VERSION 36 baked). 775 to 782 merged tonight (see HANDOFF.md NOW block and tech/BUILD_LOG.md). Dave: working all night, then pulls 783 when Mike's v31 table passes.

**Next 3 jobs.** 1. Merge 783: sonny-outlets 418df97b + claude/mike-bake-v31 after its island table (BP-T54): tech/BAKE_31_MERGE.md; take Mike's tiles and water wholesale on conflict and verify blobs; Dave's steps are in the plan (HUD "ground v41"). 2. Gate lists 6 and 7 (tech/MERGE_CHECK_NEXT3.md): merge on Mike's or the laptop's PASS, tested ids only. 3. 20:00 ADT audit tech/AUDITS/AUDIT_2026-10-24.md scoring the 7 efficiency targets of tech/DAILY_HANDOFF.md (merge-check batch per hour, allow rules, smoke test, card checklist, test recipe, ready queues, relay hygiene).

**Waiting on.** Mike: v31 bake, island table, gate 6 and 7 tests. Steve: biome lookup (protocol 76), final sound hookup tests. Sal: protocol 75 (uproot/replant). Sonny: seam/gully terrain candidate (rides in the single rebake). Dave: the laptop (dxdiag spec check, tech/LAPTOP_SETUP.md).

**Traps and lessons.** Merge the tested commit id, not the branch name (Sal pushed after Mike's gate). Never commit a merge with conflict markers: verify `git diff --name-only --diff-filter=U` is empty and grep for <<<<<<< before committing (I once committed one locally, caught before the push). Rebased copies of a commit conflict with the original: merge the original id Mike tested. Mike's tile branches conflict with head in tiles and water: take theirs for worlds/base_world/tiles and water only, verify all 18 blobs equal. island_checks.json: keep head's (Sal's newer) copy. Version stamps: a tile file carries no TERRAIN_VERSION; mixed stamps are fine. Protocol: next free number at merge time. Client says "ground vNN" from the server: a stale number means an old server process.

**How to run checks (cloud).** python3 tools/parse_scan.py, tools/merge_check.py, check_controls.py, check_look_names.py, sound_check.py, item_master.py --check; Godot checks run on Mike's PC or the laptop. Clone: /tmp/claude-0/w/DynastyALWL; docs master /mnt/project-files/tech/, mirror docs/mirror/tech/.

**Open plans.** None unanswered. Built without a reply: Kathleen_ground_items, Sal_cost_table_open, Steve_sunny_button (answer only if they matter).

**Pad.** Pad steps 8 (dates and sources on 10 best practices), 10 (refill JOBS.md queues), 11 (weekly best-practice verification), 12 (audit) are open; pad file /mnt/project-files/goalpads/WhatamIDoingtoReachMyGoal_Tyler.txt, mirror docs/mirror/goalpads/.
