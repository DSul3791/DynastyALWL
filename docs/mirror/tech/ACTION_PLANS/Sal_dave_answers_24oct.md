# Sal: plan updates from Dave's QA answers (19:23 UTC 24 Oct; plans only, build after the devstop)

## 1. Tools ladder (cards hammer-adze-recipe, metal-ladder; earlier axe/spear message)
- **Adze removed from the game.** Retire stone_adze (item 246, recipe 158; number kept, "retired": true), remove "adze" from design_names.json (names and aliases). Item master: 29 missing becomes 28 once hoe, hammer and saw are covered.
- **Hammer ladder (same job, better durability):**
  1. Wooden hammer: wooden block (head) + stick (handle) + twine. Weakest, poor durability (about 1,500 uses).
  2. Stone hammer (exists, item 244, recipe 156): stone + stick + twine (today 2 stone + stick + twine; becomes 1 stone). Durability 4,350.
  3. Copper, bronze, iron, steel hammers: ingot + stick (or wooden handle) + twine; made at the forge once those metals exist.
  The hammer still has no use until nails and the blueprint maker (below) give it one; the blueprint maker is the first use.
- **Stone axe 1 stone + 1 stick + 5 twine** (first tool), **wooden spear 1 stick, keeps 1 stone**, **stone spear = wooden spear + 5 twine, keeps the same stone** (Dave 15:34).
- **No stone pick.** The stone axe breaks rock: slowly, and it wears out fast. Data only: drops.json tool_wear per_use axe rock raised from 1 to 5, and the stone-from-outcrop yield per blow stays low. Next steps up: copper axe (needs copper), maybe a copper pick, then bronze, then iron (the iron and steel pickaxes already exist as future items). The early-game flow row "stone pick" is dropped.
- Copper and tin: Sonny's placement note (nuggets near running water, found at mountain bases, outcrops that show a vein upslope). Not mine; needed for the copper rungs.
- Code and data: recipes.json (axe, spear, hammers), items.json (wooden_hammer new number, adze retired), design_names.json, drops.json tool_wear, item_master, tests that craft an axe or spear (test_server_items, hotbar tests), shops.json and showroom.json references. Label RESTART.

## 2. Building: pieces, not rooms; grand blueprints; blueprint maker (cards thatch-screen-first-room, direct-on-blueprint)
- No pre-made room or screen wall. The first shelter is built from single pieces (thatch tier wall pieces etc.). The thatch screen idea is dropped.
- **Blueprint maker:** right click the hammer, choose "Blueprint maker", then use the hammer on a building or structure: everything connected to the piece you hit is saved as one blueprint, the game asks for a name, and it appears as a kit you can place anywhere (a "grand blueprint"). Placing it shows a ghost of all pieces (same placement code as a foundation: scroll turns, Shift + scroll raises), costs the sum of the pieces' materials, builds as a blueprint.
- Data: a saved blueprint is a list of pieces with offsets and yaws relative to an anchor piece, stored per player (blueprints.json server side), plus an item "saved_blueprint" with a name. Needs: a connected-pieces search (snap neighbours, foundation joins already exist), a name box, the hammer menu, a multi-piece ghost, a cap on pieces per blueprint (suggest 200) and an ownership check (only your own or public build can be copied; admin can copy anything).
- **Taking down a blueprint returns 100 percent** of its materials (a piece still in blueprint state, a placed grand blueprint, a bridge blueprint). Finished pieces keep today's return unless Dave says otherwise.
- Cards "build-both-ways" (direct piece and blueprint, same cost, direct foundation first) is YES: build order is direct foundation, then blueprint maker.

## 3. Bridges
Section 7 of art/BUILDING_TIERS_PLAN.md is updated: poles 5 m long from the bottom of the bridge floor, ramps go down to that height (no 40 m cap), blueprints return 100 percent when taken down.

## 4. Fire, thatch, rough bed, cooking, shore net (Yes)
- Fire tiers plan: approved as written, plus cooking on the survival fire and rain-sensitive lighting (see the plan header).
- Thatch plan: approved (thatching grass in all grassy areas, bark thatch).
- Rough bed (thatch + 4 sticks + 2 twine under any roof, half food and water use asleep, never auto-wakes) and cooking stations (tripod pot first, then clay hearth and oven) are YES; recipes are queued below.
- Shore net (20 twine + 4 stones) first fishing item is YES.

## Code work queued for Sal (in this order; all after the devstop)
1. Tools batch 2: axe/spear recipes, wooden hammer, retire adze, stone hammer recipe, axe rock wear (data, RESTART).
2. Thatch sources (flora.json, drops.json, trunk code, flora VERSION 5).
3. Fire tiers (cooking.json tiers, server fire counters, warmth/wolf radius, client light and flame, cooking on survival fire, rain lighting).
4. Stack caps (u16, unstackable flag) and auto pickup P (both approved earlier).
5. Rough bed item and cooking tripod kit recipes (items; the bed rules and lie-down animation belong to the early-game thread).
6. Shore net item.
7. Direct foundation first, then blueprint maker (needs Tyler's plan answer once, hammer menu, multi-piece ghost), then bridge blueprints.
