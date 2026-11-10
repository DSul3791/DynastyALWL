# What the station can use: lifted and lit in gold (Steve, 10 Nov 2026)

## Dave's ask (playtest, 10 Nov 2026)

- "as you can see I am in a campfire. so it would be cool if it sorted and highlighted campfire stuff l can put in the fire to the top of my inventory. give it all a nice yellow golden glowing line around its box. things like wood or anything that can burn in a fire or food stuffs that we can put in a fire to cook like raw meats or whatever there is."
- "it should work with every station of any type. only the stuff you can use in it go to the top with the yellow outline"

Coordinator ruling:
- Derive the set from the existing fuel and recipe data.
- Sort fuel first, then what the station takes in. The rest keeps its order.
- Put the line's colour and width in a JSON file under data/ui.
- Apply it to every station, and restore the order when the station UI closes.

## When

Only while a station's own window is open (Dave, 10 Nov 2026: "even when I open my inventory and Im not in the campfires inventory the wood is still highlighted which it shouldnt be"). The container on screen must be one of these:
- a fire in any campfire state (lit, laid or cold); or
- a structure from structures.json with a `station`, an `also` list or a `fuel`.

The pack opened on its own, or a plain chest, lights nothing, even beside a fire. A station with no window of its own, such as a workbench, lifts nothing.

When the pack window shuts, nothing is lifted, and the next open recomputes the set. Slots never move: only where their wells sit in the grid changes (pack_grid.arrange_slots), so clicks, the hotbar and the server see the same pack.

## What (src/client/ui/inventory/station_use.gd)

| Group | Items | Source |
|---|---|---|
| 1, FUEL | What it burns | A fire: cooking.json `fuel`. A torch, fireplace or chandelier: its structures.json `fuel`. |
| 2, INPUT | What it takes in | Every ingredient of every recipe made at a station here, with an ingredient group expanded to its members. A station's `also` list counts too, so the clay hearth and the oven also take the campfire's ingredients. A fire also takes the food it cooks, by the server's `_cookable` rule (cooks_into, cookable_suffixes). |

- Anything in both groups (a stick at a fire) is fuel.
- Within each group the player's chosen sort holds, and everything else follows in that same order.
- Nothing is hand-listed.

## The look (item_slot.set_station_glow)

A golden line round the well, with a glow that fades inward. `data/ui/station_highlight.json` holds `colour` (#ffc83a), `line_px` (2), `glow_px` (6) and `glow_alpha` (0.5), scaled by the slot's unit.

## Cost

- The set is cached by the stations present. Finding them reads one world row, the open container.
- The craft list stall (Dave, 10 Nov 2026: opening the menu, a click or D took 2 to 3 s) came from `station_near` and `nearby_logs`. They walked every world row several times per recipe, and each row looked up its structure by walking structures.json. That lookup is now a map. Their answers are kept for the frame, and a world change or a refresh clears them.
- The draw is a few rect outlines per lit well.

## Tests (src/worldgen/tools/test_station_use.gd)

- A fire: sticks, logs and firewood are fuel, raw meat is input; stone, hide and iron ore are not lifted.
- A workbench: stone and hide are lifted, a stick is input not fuel, raw meat is not lifted, and nothing is fuel.
- The clay hearth takes beets and the campfire's raw meat.
- The forge takes iron ore.
- A wall torch lifts only its stick.
- The same set comes back from the cache.
- The cookable rule matches the server's.
- The config is read, and a slot takes and drops the line.
