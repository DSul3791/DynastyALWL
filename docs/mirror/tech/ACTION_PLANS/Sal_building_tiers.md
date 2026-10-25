# Action plan: the six building tiers (Sal, branch claude/sal-building-tiers)

Dave 17:32: a basic, a plank, a fine wood, a log, a cobblestone and a mason wall are different things with their own models and rules. This plan is the tiers table (design/BUILDING_TIERS_TABLE.md, every tier x slot with item numbers, recipe or blueprint, model name) and the order to fill it. Built as phases on one branch; each phase can be gated alone. Label RESTART (data and look stubs; one possible small placement change, below).

## What exists, what is missing (build 822)
Exists: Fine wood (the six generic pieces, items 192-203), Basic without a window (thatch, 252-266). Missing: Plank, Log, Cobblestone, Mason (all six slots each), the Basic window, and the large and mason foundations. The table has 25 NEW pieces, which is 50 items (a kit and a placed piece each), 29 world states, 7 recipes and 18 blueprints.

## Phases (the order in BUILDING_TIERS_PLAN section 4, as Tyler listed)
0. Display names only: the generic pieces become "Fine wood wall, doorway, window wall, floor, roof, foundation" (ids and numbers kept). The thatch four by hand is the already-queued sal-hand-crafts branch (3c5dde01); I do not touch it.
1. Plank tier (by hand) and the Basic window (by hand): 14 items, recipes 180-186. Rough plank (226) is the material; it stays.
2. Log tier and Cobblestone tier (hammer blueprints 17-28) with the large 6 x 6 foundation.
3. Mason tier (blueprints 29-34) with the mason 8 x 8 foundation. Pillars, roof slopes 45/65, hip and valley stay out of this plan (Dave's plan puts them with Mason; I will bring them as their own plan).
Fine wood and lower are made by hand and placed; Log and up need a hammer in the hand bar and take their materials from the pack when placed (build 1 rules, takedown gives them back). Row hammer tier: Log 1, Cobblestone 2, Mason 2 (stone hammer), tunable in blueprints.json.

## Numbers I need reserved (the old Sal block 267-299 is spent)
Items 350-399 (50), recipes 180-186 (inside my block), blueprints 17-34, world states 47-75. Items 300-349 are Steve's and Kathleen's, so I use 350 up.

## Decisions I made, shout if wrong
- Ids: thatch_window, plank_*, loghouse_* (not log_*, which is the species logs and the log workbench), cobble_*, mason_*.
- Fine wood stays on lumber and twine for now. Dave's plan says nails replace the twine, but nails need a forge and iron, which would put the first plank house behind the forge. Say so if you want nails in the fine wood recipe now.
- Costs are the ones in BUILDING_TIERS_PLAN section 2, unchanged; the log and mason pieces are heavy (a mason wall is about 200 kg) so they are built where you stand from the pack.

## Placement check before I build (the one possible code change)
The foundation snap anchors (structures.json "anchors") are written for the 4 x 4 slab. If PlacementRules.snap reads any footprint from data, the 6 x 6 and 8 x 8 foundations are data only; if it assumes 4 x 4 I add the size to the snap code (a few lines). I check this at the start of phase 2 and tell you before building.

## Looks
Each new row needs a PieceLook builder (names in the table). I stub each with the nearest existing builder (wall, floor, roof, door) in the tier colour so the game runs, and Kathleen draws the real ones tier by tier after each phase. Names go to her through the Moderator now.

## Tests (David3)
validate_items 0 errors; test_blueprints cases per phase (cost taken, refusal, takedown refund, tier piece on a foundation of the right size); test_server_items recipes 180-186 by hand; test_craft_menu (next recipe 187); duplicate sweep; local_check 227.

## Ask
GO on the phases and the number reservation, one reply. Phase 0 and 1 start the moment you say GO.
