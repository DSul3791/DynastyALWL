# Dino: what each bug means for the first-hour guide, and how Dave confirms each fix (2 Nov 2026, paper review on main 5d44ae0; no Godot run)

Bug numbers are from `docs/BUGS_FOUND_IN_PLAY.md`. I do not fix; owners are in its triage table. Each row says which guide step the bug touches and the exact check that proves the fix.

| # | Bug | Guide step it hits | Check Dave runs after the fix (windowed) |
|---|---|---|---|
| 1 | Fire timer does not update after adding wood | 10 (feed the fire) | Inspect a lit fire: note burn time. Add 1 firewood (F, then close the store). Time should rise by about 20 min; add 1 log: about 3 h more (capped at 18 h). |
| 2 | Cannot pick up chopping block | 8 and the wood chain | Place a chopping block, hold E at it: it comes back to the pack. |
| 3 | Firewood pile beside block does not grow | 8 | Split 1, then 5, then 10 blocks at the chopping block: the pile beside it visibly gets bigger each time. |
| 4 | First-person arms | all hand steps | Hold stone axe, spear, campfire kit: both arms in frame, hand on the handle, no arm through the camera. |
| 5 | Tree takes 20+ hits | 8 | See table below. After the fix: a thin tree (radius 0.5 m) takes about 10 blows. |
| 6 | 2 s lock-up per cut of a fallen tree | 8 | Cut a felled trunk into logs: no freeze; F3 worst frame stays under about 100 ms. |
| 7 | Constant lag | all | F3 overlay at spawn: average frame and worst frame; quality Ultra vs Low. Tyler profiles first. |
| 8 | 3+ firewood does not make a medium fire | 10 | Put 3 firewood in the fire's store (F), close it, light it with E: label says medium; light radius 7 m (twice the small fire's 3.5). |
| 9 | Only one log fits in the campfire | 10 | Put 2, then 3 logs on one fire: all go in; label says large (14 m). The old 6-log limit is gone (#32). |
| 10 | No jump animation | 1 (walk, run) | Space while standing and while running: a jump pose plays, not a float. |

## Bug 5: blows to fell a standing tree, from data
Rule (server_items.gd about line 3695, drops.json "felling"): blows = ceil( clamp( round(2 + 16.5 x trunk radius in m), 3, 22 ) / fell skill factor ). A new character has factor about 1.0; the floor is 0.8 (skills.json system.min_factor), so a clumsy novice takes up to 25 percent more.

| Trunk radius | Blows at factor 1.0 | At 0.8 | At 0.5 |
|---|---|---|---|
| 0.2 m | 5 | 7 | 10 |
| 0.4 m | 9 | 12 | 18 |
| 0.5 m | 10 | 13 | 20 |
| 0.8 m | 15 | 19 | 30 |
| 1.0 m | 18 | 23 | 36 |
| 1.2 m or more | 22 (cap) | 28 | 44 |

So "about 10 hits" is a 0.5 m radius trunk (1 m across), not a sapling, and 20+ hits means a trunk 0.9 m radius or thicker for a novice (or a thick one at any skill). The guides say "about 10 blows for a thin tree" (checklist step 8): that is only true for radius about 0.5 m or less. Suggested for Sal: confirm Dave's beech radius (F3 or inspect), and decide whether tree_per_trunk_m (16.5) or the 22 cap should drop. Suggested wording for the checklist until then: "10 blows for a 1 m trunk, fewer for a thin one, up to 20 or more for a giant".

## Guide wording to change when a fix lands
- Bug 3 and 2: add a line to the wood chain in the tutorial ("pick the block up again with hold E").
- Bug 8 and 9: PLAYTHROUGH_GUIDE step 4 under "Feed it" is already right (3+ firewood medium, 3+ logs large); only confirm after Steve's fix.
- Bug 10: nothing in the text; add "jump (space)" to the walk step only after the animation exists.

## Updates for main d4bd4a8 (2 Nov, read from the code and commit messages)
- **#49 settles my worry on bug 11:** the auto-split now also drops sticks, leaves, bark or thatch, seeds and the root ball. Check in a windowed client: fell one tree, wait 3 s, count what lies there.
- **#32 changes how fires are fed (bugs 1, 8, 9):** F opens the fire's store (30 slots, no stack limit); the wood in it is what burns; E lights or puts out; hold E on an unlit fire picks it up; no hold-E cooking. Run the checks for bugs 1, 8 and 9 this way: F, add 3 firewood, close; light with E; label medium, light radius 7 m. F, add 2 then 3 logs: all stay in; label large (14 m) after closing.
- **#30 (bugs 2 and 3):** hold E picks up the chopping block (tap splits); the pile beside it grows with the count (placeholder mound look).
