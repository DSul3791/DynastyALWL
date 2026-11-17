# Crafting list order, and crafting moves you to the station (Dave 10 Nov 2026)

Dave, playtest:

> "if a food is able to be made in your inventory and you have the materials or they are withing 12m of you the recipe should go to the top of the list and all the applicable will be there alphabetically. if you need a station and one is near and working or lit with a fire or whatever it needs its will be lit also but under the hand made stuff."

> "if you select something that needs a station and you are close enough to the station you can teleport to the station by crafting that item from your inventory. it will move you directly infront of the station or off to the side if another player is there accordingly"

The coordinator ruled that this applies to every tab, not only food, and uses the same 12 m reach as blueprint gathering.

## The list

The recipe list (`recipe_list.gd`, ordered by `RecipeFilter.order_groups`) has three groups. Each group is alphabetical by name, ignoring case.

1. **By hand, makeable now.** These recipes need no station, and everything they need is in the pack or within 12 m. That covers your own containers (as before) and loose stacks on the ground, which counted only within 3 m before and now count to 12 m (`CraftStock.LOOSE_STOCK_M`). A recipe whose missing part the stock can make first (the auto-make plan) counts as makeable, as before.
2. **At a station, makeable now.** These need a station that is working within 12 m: a lit fire for the campfire, a pot over a lit fire, a bench, or a forge at the level the recipe needs. The checks are the same as before, only the distance is wider (`station_in_reach`). The materials must be there too. These rows have no "at camp bench" line, and their tooltip says crafting takes you to the station.
3. **The rest,** as before: green if it can be made where you stand (admin mode makes everything green), and dim with "at …" and the missing items otherwise.

Groups 1 and 2 have the golden line round the row: the same colour, line and glow as a pack well at a station (#880, `data/ui/station_highlight.json`), drawn by `InventoryLook.glow_recipe_row`. In admin mode every recipe is free, so every hand recipe is in group 1, and group 2 still shows only the stations that are really near.

## Crafting moves you to the station

You craft a station recipe from the pack (a click, or Craft). The station is working within 12 m but not beside you, and the stock where you stand covers at least one craft (or you are in admin mode). Then the server moves you to the station, and the craft goes on there:

- **The spot:** directly in front of the station, 1.3 m from its centre (`front_m`), facing it. "In front" is the model's front, Godot's +Z, turned by the station's yaw. A fire is round, so you stand on the side you came from, 1.5 m out (`fire_m`).
- **Someone already there:** if another player stands within 0.9 m of that spot (`clear_m`), you go to its left side, then its right, then behind (`side_m` 1.4 m).
- **The server decides.** It sets its own position for you at once, so the station check passes, and tells the client with the new rpc `step_to(position, yaw)` (protocol 103). The client puts the body there and turns it to the station.
- **No move:**
  - when the station is farther than 12 m: the old answer, "That needs a … nearby";
  - when you don't have the materials: the old "missing" answer;
  - when you are already at the station.

All the numbers are in `data/items/station_step.json`.

## A station's own window lists only what it makes (Dave 17 Nov 2026)

Dave, playtest:

> "when you open an inventory other than yours like the workstation or the primative smithy it should only list the crafting recipes for stuff that station makes."

F on a station opens its window: the crafting screen for a station without a store (workbench, carving station, tanning rack), or the store window on its Craft tab (smithies, kiln, leatherworking table, the campfire's window). That window's recipe list now holds only the recipes that station makes (`inventory_view.station_makes`, the view's `_station_screen`). Search, tabs and the three groups above work inside that list. Any other container's window (a chest, a smelter) lists none (SR-2). Your own inventory (I) is unchanged: every recipe you know, in the order above, near a station or not.

### For Dave (provisional, assumed on his behalf; change any of them by saying so)

- **SR-1, levels and stand-ins.** A station lists the recipes it can serve: its own station at its level or lower, add-ons that raise its level (the workbench's tool rack and vice) counted as the server's craft check counts them (the bellows and quenching trough raise nothing), and the stations it stands in for. So a Carpenter's bench (workbench 2) shows level 1 and 2 bench recipes, an Improved smithy (brick forge 2, also forge 1) shows brick forge 1 and 2 and the Primitive smithy's forge recipes, and a clay hearth shows the campfire's. Recipes above its level are not listed.
- **SR-2, plain storage.** A chest, bin, smelter or other store that makes nothing by crafting lists no recipes: its Craft tab is empty. Only your own inventory (I) shows your whole list.
- **SR-3, the campfire's window** lists the campfire recipes, lit or not (an unlit fire's rows are dim, as before). Pot recipes (soups, stews) stay with the pot's own window and your own inventory.
- **SR-4, the Sawbuck** lists Wooden block, the recipe it speeds. The chopping block has no recipes (E splits logs), so its Craft tab is empty.
- **SR-5, your own inventory near a station** still lists everything, station recipes second as above. Dave's ruling named only other inventories.

## A crafting station has one inventory, beside its recipes (Dave 17 Nov 2026)

Dave, playtest:

> "I just used the primative smithy and didnt like the way there is a separate chest inventory. it should be combined so when it makes items they appear so the player can see them."

> "in a station that has an inventory there should only be on inventory not a chest and crafting. it should have unlimited inventory slots starting with 20 and on the left it lists the items you can craft."

He picked "Station's slots on the craft screen" (17 Nov 02:12Z) over products going straight to the pack, and "ship it all at once".

- **One store.** The crafting stations that had input and output slots (Primitive, Improved and Advanced smithy, Master smithy, leatherworking table, tailor's table, loom, food preparation table, saw mill) have one store instead (`structures.json` `"one_store": true`, `"slots": 20`, no `out_slots`). It holds what you put in and what the station makes. A finished craft goes into it (`server_items._out_add`), never to the pack or the ground.
- **Unlimited, from 20.** A new store has 20 slots and grows when full, as the pack does (`Inventory.grows`, 5 at a time, up to the 250 the protocol carries). Empty slots past 20 and past the last thing in it are given back when it is next used (`_store_usable`).
- **Saves.** A store saved with the old input and output slots loads whole: every stack is in the one store, nothing moves or is lost (`test_station_storage`).
- **The window.** No Chest and Craft tabs: the category tabs and recipe list on the left, the station's store on the right over the recipe card (`recipe_list.store_holder`, `container_panel.set_compact`, `inventory_view._store_with_recipes`). What the station makes is seen landing in it.

### For Dave (provisional, assumed on his behalf; change any of them by saying so)

- **SC-1, size.** Beside the recipes the store's wells are 60 px, 5 across, four rows (its first 20 slots) in view; a store grown past 20 scrolls. A chest's are 100 px, 6 across.
- **SC-2, what steps aside.** The store keeps Keep out of crafting, Take all, Store all and Lock (on two lines); Sort both and Stack into my chests are left off for the room (their keys still work).
- **SC-3, what keeps its old store.** The Kiln (a batch of logs into its output, being rebuilt in three tiers), the chopping block (E splits blocks into its output; no recipes), the smelters (fuel hopper, ore input, ingot rack), chests and fires.
- **SC-4, no weight limit.** A station's store has no kilogram limit (it is never carried); the 250-slot protocol limit is the only cap.
- **SC-5, the saw mill** still takes only logs from you; its planks land in the same store.

## Two Craft buttons (Dave 17 Nov 2026)

Dave: "cut the Craft button into two buttons left button says Craft 1, right button says Craft x where x is the number you set above for amount of items to craft." The recipe card's footer (own crafting screen and every station window, `recipe_list.gd`) now has two brass buttons side by side where the one wide Craft button was: **Craft 1** makes one; **Craft x** makes the Make box's number and its words follow the box as it changes. Pin stays below. Left click selects, Shift+click crafts one and E crafts the box's number, as before.

### For Dave (provisional, assumed on his behalf; change any of them by saying so)

- **CB-1, times.** Each button shows its own time: Craft 1 the time for one, Craft x the time for x ("8 s" under a minute, "2:40" from a minute up). Words too long for half the column end in "..." and show whole on hover.
- **CB-2, greyed.** Craft 1 is greyed exactly as the old button was. Craft x is also greyed when the stock in reach covers one but not x. A recipe whose one craft needs logs or parts made first is left to the server, which refuses what is short.
- **CB-3, quantity box** still runs 1 to 20.
