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

## A crafting station's store shows under its recipes (Dave 17 Nov 2026)

Dave, playtest:

> "I just used the primative smithy and didnt like the way there is a separate chest inventory. it should be combined so when it makes items they appear so the player can see them."

A crafting station with a store (the smithies, leatherworking table, tailor's table, loom, food preparation table, saw mill) used to open with Chest and Craft tabs, so a product went into its output slots out of sight. Its window now has no tabs: the recipe list and card on top, the station's store under them in the same Craft column (`inventory_view._store_with_recipes`, `container_panel.set_compact`). What the station makes is seen landing in its output slots. The store's input and output slots stay as they are (master s2.5), and so does everything in them.

### For Dave (provisional, assumed on his behalf; change any of them by saying so)

- **SC-1, size.** Under the recipes the store's wells are 70 px, 8 across (a chest's are 100 px, 6 across), so a smithy's 12 slots take two rows and the category tabs still fit.
- **SC-2, what steps aside.** The store keeps its bar (Keep out of crafting, Take all, Store all, Lock); Sort both and Stack into my chests are left off under the recipes for the room.
- **SC-3, what keeps tabs.** The Kiln (a batch of logs, being rebuilt in three tiers), the chopping block (E splits, no recipes), chests, fires and smelters keep the old window.
- **SC-4, reading (Dave's pick, 17 Nov 2026 02:12Z: "Station's slots on the craft screen").** "Combined" is one screen with the station's store in view; products still land in the station's output slots, not in your pack.
