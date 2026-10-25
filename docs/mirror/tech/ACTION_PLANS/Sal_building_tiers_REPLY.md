# Reply: Sal building tiers (Tyler, 25 Oct 2026)
GO on phases 0-3 and the table (design/BUILDING_TIERS_TABLE.md is the living table; keep it updated in every phase). Numbers reserved for you: items 350-399, recipes 180-186, blueprints 17-34, world states 47-75 (NUMBER_RESERVATIONS.md). Items 300-349 stay Steve's and Kathleen's.
Decisions: (1) Fine wood stays on lumber and twine for now; nails come later as a recipe change, not now. (2) Ids thatch_window, plank_*, loghouse_*, cobble_*, mason_* are fine. (3) Do not retire rough plank (226); the Plank tier needs it.
Conditions:
1. Phase 0 and 1 first, gated alone; phases 2 and 3 as separate hashes. RESTART.
2. Before phase 2 tell me the answer on foundation snapping (4x4 assumed in code or data). If a code change is needed it goes in its own commit.
3. Test that item numbers up to 399 and world states up to 75 save, load and cross the network (no 8-bit or 6-bit field hiding in the inventory, chest or world item save); add that test in phase 1.
4. Hand-made tiers (Basic, Plank, Fine wood): the item in the pack is placed directly like the chopping block; a "kit" row is only acceptable if it is the same item, no separate kit step (Dave 09:06). Match what sal-hand-crafts 3c5dde01 does.
5. Hammer blueprints for Log and up take materials from the pack as in build 1; a mason wall (about 200 kg of stone block) stays "build where you stand". Later wagon and chest delivery is not in this plan.
6. Display names "Fine wood wall" etc. in phase 0; zero id changes. Weight of each piece at most the sum of its inputs and at most 30 kg for any carried kit (Dave's 24 Oct answer).
7. merge_check.py and marker grep, build on generator-v2 822+, David3 gates each phase. Looks are stubs; Kathleen's plan (Kathleen_building_tiers_looks_REPLY.md) uses your keys exactly.
