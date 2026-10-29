# Building tiers: what Dave decided, what the game has (Tyler, 25 Oct 17:50 UTC)
Prompted by Dave 17:32: "a wooden wall, a basic wall, a cobblestone wall and a mason wall are all different things, with their own models and own rules, same for foundations: basic, wood, fine wood, cobblestone, mason. Go back through the design docs; everybody is forgetting them." Sources: art/BUILDING_TIERS_PLAN.md (chk-tiers YES 20:56 on 22 Oct), items/BLUEPRINT_BUILD_DESIGN.md (rework 00:05 section wins), tech/DECISIONS.md entries 22 Oct 20:30, 21:10, 22:35, 22:55, 23:00, and CRAFTING_STATIONS_RULE.md (09:06 addendum: fine wood or lower made by hand and placed; higher tiers by hammer blueprint).

## The decided design (all approved by Dave, never withdrawn)
- Six tiers, each its own real build with its own models: 1 Basic (thatch, twine, sticks; wall 0.1 m; no foundation, stakes in the ground), 2 Plank (rough planks, 0.1 m), 3 Fine wood (lumber and nails, 0.15 m), 4 Log (0.4 m), 5 Cobblestone (cobblestones and mortar, 0.5 m), 6 Mason (big carved blocks, 0.6 m).
- Every tier has the same five slots on the 2 m grid (wall 2.4 m high): wall, doorway, window wall (an open hole), floor, roof. Roofs: thatch, lap board and stone shingle slopes at 45 and 65 degrees (slope, hip, valley); flat roof is wood and tar.
- Foundations differ by size: standard (small), large (6 x 6 m, for log and cobblestone), mason (8 x 8 m with a deep stone skirt). Tier 1 sits on bare ground. Pillars per tier. Mixing tiers on one foundation is allowed.
- Tier comes from the hotbar piece (Basic wall, Plank wall, ...); the wheel turns the variant. Fine wood and lower you make by hand and place; log and above come from a hammer blueprint.

## What is in the game now (build 822)
- Basic (thatch): thatch wall, floor, roof, doorway (items 252-265). No window, no foundation rule check, no 45/65 slope variants.
- Fine wood: ONE generic set called "Wall section, Floor section, Roof section, Foundation, Doorway, Window wall" (lumber and twine; foundation 8 stone, 2 clay). It is the fine wood tier but is not named that way.
- Plank, Log, Cobblestone, Mason: NOT in the game (no pieces, no models, no recipes). Large and mason foundations: not in the game. Pillars, roof slopes 45/65, hip, valley: not in the game.
- Materials the tiers need: rough plank (226), nails, cobblestone (229), stone shingle (230), brick, mortar, stone block: all exist as items, which is why Dave said keep cobblestone and shingle.

## Consequences for the item trim
1. Do NOT retire rough plank (226): it is the Plank tier's material. My C proposal to fold it into lumber was wrong; it is withdrawn.
2. Trim G ("one wall for every material") is rejected as Dave says. The generic wall/floor/roof section pieces are the FINE WOOD tier and should be renamed and labelled so.
3. The thatch pieces stay separate (Basic tier).

## What is needed (one action plan from Sal, then Kathleen looks)
1. Rename the generic pieces to the fine wood tier names (display names only, ids kept).
2. Plan the missing tiers in the approved order from BUILDING_TIERS_PLAN section 4: Plank, then Basic completion (window, slopes), then Log and Cobblestone with the large foundation, then Mason with the mason foundation, pillars and the 45/65 roofs.
3. Per Dave's 09:06 rule: Basic, Plank, Fine wood pieces made by hand and placed; Log, Cobblestone, Mason and large foundations by hammer blueprint.
4. A table of every tier x slot with item number, recipe or blueprint, model name and owner so nobody forgets it again. This audit is the start of it.
