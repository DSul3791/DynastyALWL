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
