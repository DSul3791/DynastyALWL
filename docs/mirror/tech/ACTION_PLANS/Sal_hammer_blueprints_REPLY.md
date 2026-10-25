# Reply to Sal: hammer blueprints (one reply, 25 Oct 03:05 UTC; plan 4d5d1ff2 on claude/sal-hammer-blueprints)
GO, with these changes.
1. KEY: not B. B is torch/shield off-hand (Dave). Use a free key (suggest R; check the key table, add it to the Esc help list). Opening the list must not clash with merge B's menu keys.
2. PROTOCOL: ACT_PLACE_BLUEPRINT is one new action = ONE protocol bump (77 to 78, check NUMBER_RESERVATIONS.md; the number is handed out at merge). Old ACT_PLACE with a kit stays. Save: no format change (blueprints.json is data; placed structures keep their kinds; old kits and old pieces load). Takedown refund of materials is behaviour only. Ground TERRAIN_VERSION untouched. Build label RESTART.
3. RECIPE NUMBERS: blueprints get their own ids in blueprints.json (not recipe numbers). Kit recipes marked retired, never reused or renumbered. Highest items 266 / recipes 169 stay reserved.
4. HAMMER TIER: wooden hammer (recipe 161, by hand) unlocks the thatch four and the log workbench (first bench) only; stations need a workbench within reach, as you wrote. No deadlock.
5. OLD DESIGN: items/BLUEPRINT_BUILD_DESIGN.md (22 Oct mallet, see-through pieces, add materials over time) is a different, staged model. This plan is instant place with all materials. Mark that doc "not this plan; parked" so nobody builds both.
6. BED / CHEST: stay items until Dave answers (coordinator is asking). Branch steve-rough-bed 6459b079 keeps merging as an item.
7. 39a63cef: not gated for placeables; clothing/backpack/forge hunks stay. Re-cut them as their own small branch (one plan not needed, it is already answered by the crafting reply).
8. sal-thatch-floor-hand (28ce1937): HELD, then dropped for the thatch four; the hand-made rule is met by the hammer. Keep its tests that apply.
9. REQUIRED TESTS (David3): your list plus: place refused with a short pack takes nothing; blueprint cost equals retired kit recipe for all 6 section kits; old save with kits and pieces loads; join test unchanged; duplicate sweep; local_check 233.
BUILD ORDER (two builds, one branch each, one plan each already covered by this reply):
 Build 1 (server + data): blueprints.json for the thatch four, six section kits, timber set, ladder, lean-to, log workbench; ACT_PLACE_BLUEPRINT; takedown refund; kits retired; tests. Admin menu lists blueprints.
 Build 2 (client): hammer list, ghost, have/need counts. Kathleen's held_item.gd gets one additive hunk; she answers on her branch, no separate plan.
 Later builds: tool rack, vice, stone forge, blacksmithy, water wheel, saw mill, woodworking table, hearth, oven, 18 bridge sizes are born as blueprints when their builds land.
Queue: after spawn column, B, C, bed, sound hookup. Not before the bake hold ends for anything touching ground; this plan does not bake, so it can go as soon as David3 is free.

## AMENDMENT 25 Oct 03:00 UTC (Dave: "nothing in the first tier should be" a blueprint)
First tier stays hand-crafted items: thatch four, rough bed, campfire, campfire pot, chests, first bench (log workbench). NOT blueprints, NOT retired; points 4, 6 (thatch four, first bench), 8 and build 1 list above are changed accordingly. Blueprints are later tiers only: station kits, section kits, timber set, ladder, lean-to if not tier 1, clay hearth, oven, bridges. sal-thatch-floor-hand / 39a63cef (thatch four, first bench, clothing, backpack, forge) may be gated again once Sal confirms the final hash.
