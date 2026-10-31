# Merge watch

Hourly dry runs of the working branches merged into the daily branch (tools/merge_day.sh via tools/merge_watch.sh), newest last. A new signature means the conflict list or the red tests changed.

## 2026-10-31 04:49Z signature 9264b5cb4c9c
base origin/DailyDev_20261029 72feac47, main origin/main
- claude/tyler-gates-fee5f7 2cf903b0 (5 commits ahead of base)
- sonny-character 039a74b7 (2 commits ahead of base)
- kathleen-art 09300174 (6 commits ahead of base)
- claude/sal-items-c65419 b9e765e8 (2 commits ahead of base)
- claude/flora-density 0eb03c21 (0 commits ahead of base)
- claude/dazzling-elbakyan-e46f22 712924f0 (4 commits ahead of base)
- claude/sonny-character-67aca3 6f6dc18e (0 commits ahead of base)
- not found (skipped): claude/kathleen-art-36b4ac

#### 1. Pairs that would conflict
- kathleen-art x claude/dazzling-elbakyan-e46f22:
    PLAYTHROUGH_FINDINGS.md
- claude/sal-items-c65419 x claude/dazzling-elbakyan-e46f22:
    PLAYTHROUGH_FINDINGS.md

#### 2. Sequential merge into the daily branch
- claude/tyler-gates-fee5f7: merged cleanly
- sonny-character: merged cleanly
- kathleen-art: merged cleanly
- claude/sal-items-c65419: merged cleanly
- claude/flora-density: merged cleanly
- claude/dazzling-elbakyan-e46f22: CONFLICT in:
    PLAYTHROUGH_FINDINGS.md   (also changed by: the base after the branch split)
- claude/sonny-character-67aca3: merged cleanly
result 111337b2, merged: claude/tyler-gates-fee5f7 sonny-character kathleen-art claude/sal-items-c65419 claude/flora-density claude/sonny-character-67aca3

#### 3. Tests
plan: bake 88 fast 3 timing 5 slow
slowest: test_water_soak 615.0s  test_worldgen 575.9s  test_head_pond_fill 529.4s  test_tile_lakes 98.3s  test_generation_speed 80.6s  
wall time 631 s, seconds per test in /c/GodotProjects/mw_out/run2/tests/seconds.txt
Test done: 98 pass, 0 fail
no new red test

#### 4. items_check
FAIL: 

RESULT: RED (3 problem(s))

## 2026-10-31 06:14Z signature c592a69070ba
base origin/DailyDev_20261029 bac8c6b1, main origin/main
- claude/tyler-gates-fee5f7 65bb8fdf (4 commits ahead of base)
- sonny-character 179cbb34 (1 commits ahead of base)
- kathleen-art ff1083e6 (3 commits ahead of base)
- claude/sal-items-c65419 b7ef599d (0 commits ahead of base)
- claude/flora-density 0eb03c21 (0 commits ahead of base)
- claude/dazzling-elbakyan-e46f22 3501f427 (0 commits ahead of base)
- claude/sonny-character-67aca3 6f6dc18e (0 commits ahead of base)
- not found (skipped): claude/kathleen-art-36b4ac

#### 1. Pairs that would conflict
none

#### 2. Sequential merge into the daily branch
- claude/tyler-gates-fee5f7: merged cleanly
- sonny-character: merged cleanly
- kathleen-art: merged cleanly
- claude/sal-items-c65419: merged cleanly
- claude/flora-density: merged cleanly
- claude/dazzling-elbakyan-e46f22: merged cleanly
- claude/sonny-character-67aca3: merged cleanly
result a90378cc, merged: claude/tyler-gates-fee5f7 sonny-character kathleen-art claude/sal-items-c65419 claude/flora-density claude/dazzling-elbakyan-e46f22 claude/sonny-character-67aca3

#### 3. Tests
plan: bake 113 fast 4 timing 5 slow
slowest: test_water_soak 666.5s  test_head_pond_fill 606.3s  test_worldgen 593.9s  test_tile_lakes 160.1s  test_drainage_flow 66.7s  
wall time 733 s, seconds per test in /tmp/tmp.pmDgxH8vay/tests/seconds.txt
Test done: 121 pass, 3 fail
NEW RED: test_new_player_day test_playability_bot test_npcs
    test_new_player_day: FAIL step 3: a stone knife is made by hand FAIL step 4: a wooden spear is made by hand 
    test_playability_bot: 
    test_npcs: FAIL 60 NPCs cost under 1 ms a tick (1.172) 

#### 4. items_check
FAIL: luck_rolls       FAIL  luck check: FAIL luck check: FAIL 

RESULT: RED (2 problem(s))
