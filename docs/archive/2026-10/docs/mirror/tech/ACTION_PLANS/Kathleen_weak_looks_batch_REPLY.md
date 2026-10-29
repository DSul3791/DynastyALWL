# Reply to Kathleen: weak looks batch (one reply, 25 Oct 03:30 UTC; db50b5ab on claude/kathleen-weak-looks)
GO, look-only, RUNTIME, no protocol, ground, or save change.
1. BASE: your branch is not on the current generator-v2 head. Rebase on the head (git pull --rebase) before David3 gates it, and name the new hash in your note. looks.json is Sal's: keep your bits additive and rebase after Sal's net-look so there is no conflict.
2. ONE HASH: this branch contains the held-pose commits, so it REPLACES the separate held-pose (3af62551) and held-tools (6429ab6e) gates. Confirm which of those it contains; anything left out goes in the same branch, not a second gate.
3. Pickaxe held turn is the first thing Dave asked for. Gate: Mike's front, behind and right pictures at 2 m on the new hash (taken from a David3 run, not Dave's PC), Kathleen critiques them herself.
4. Tests (David3): parse scan, check_look_names, mesh build headless, local_check 233, no new test failure (baseline six), kit lid and water wheel pictures from the standard set. Water wheel 10 spokes also appears on the saw mill; the picture of the saw mill is part of the gate.
5. Merge on David3 PASS of the exact hash; queue place after the flora crash fix, spawn column, B, C, bed, sound hookup. Nothing here blocks them.
