# The hammer fills a blueprint from all around (Dave, 10 Nov 2026)

Dave's words: "If I have a blueprint down and I have a hammer in my hand in repair mode when I hit the blueprint it should search the area around me for
12 meters. on the ground, in my inventory, in any containers near me including carts or pack animal inventories, crates. anything for materials that this
blue print needs and pull those items and put them in the blueprint." And: "craft from containers is always a mode people love in other games we are
going to build it right in and make it better. it will even pick stuff up from the ground."

## What it does

With the hammer in Repair mode, a left click on a blue blueprint site sends the same message as a repair (`ACT_REPAIR_STRUCT`). The server sees the
site and fills it (`server_items._gather_site`). It is always on: there is no toggle and no flag.

- **Where it looks.** Everything within `site_gather_m` (12 m, `data/items/building_wear.json`) of the builder.
- **Order.** The pack first, then loose items on the ground and the builder's own containers, nearest first.
  - Ground items include the natural sticks and stones.
  - Containers follow the crafting rule (`craft_stock.gd`): the builder's own, not ticked "keep out". A stranger's chest is never used. This is Dave's
    8 Nov rule for crafting stock.
  - A group need such as `log` takes any member of the group.
- **How much.** Only what the site still needs.
- **Feedback.** One HUD line: "Pulled 8 stone - cut block, 4 mortar. Still needed: 4 stone - cut block." With nothing missing, the piece is built:
  "Pulled …. Built." When nothing in reach is needed, the line says so and lists what is missing.
- **Aiming.** A site has no collider, so with nothing under the ray the point 4 m ahead is used to find it.

## Carts and pack animals

The game has none yet. Any container that is a storage structure with an inventory (a `structures.json` row with `slots`) is searched already. A cart or
pack animal built that way later is searched with no change here.

## Tests

`test_build_stock._check_site_gather`:

- a stack 20 m away is not taken, and the line says so;
- the pack goes first, then the 8 m stack and the builder's own chest;
- only the mortar it needs is taken;
- a stranger's chest is untouched;
- the line lists what came and what is still missing;
- a second hit with the rest in reach builds the wall and takes only what was missing.
