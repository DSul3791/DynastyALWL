# Goals and recipes review (21 Nov 2026)

Dave, 21 Nov 2026 20:24Z: "review the goal list to make sure it guides players in the correct direction. check each item to be made to make sure its recipe makes sense. look for things like the other day where something required a chisel that it absolutely shouldn't have. make sure stations and required materials are available for each item at every stage of the goals."

Baseline: dev `53fb11a9`. Static read of the data, not play. Pending PRs read first so their rows are not edited twice: #1460 (nails by use, NT-1), #1455 (river iron), #1457 (meteorites, Iron chunk), #1459/#1461/#1462 (station models, no recipe rows), and the chests thread's D-CHISEL-1 (its own PR after #1460).

## Method

1. Every live goal (`starter_goals.json`, `camp_goals.json`): its target, recipe, tools, station and materials followed all the way down.
2. Every active recipe (427) and blueprint (253 offered) read row by row for sense, with the first metal stage that reaches it: `tools/goal_stage_audit.py` reruns the reach model of `tools/encyclopedia_reach.py` once per stage (stone, copper, bronze, iron, steel) with the later ores taken out of the world, and honours blueprint chisel tiers (the reach model does not).
3. Hints checked against the code that runs them (the knife build list, the talked check, the fishing rod recipe).

## What the goal list did

The live list was 31 goals, all stage `start`: the stone camp (water, fibre, twine, stone tools, fire, lean-to, bed, workbench, spear, knife, fish, Hob) and the camp and winter chain. Nothing pointed a player at charcoal, copper, a smelter, tin, bronze or iron. The 704-row catalog (`PLAYER_GOALS_CATALOG_CORRECTED.csv`) is a stale review draft and stays off.

## Changes in this PR

| Change | Why |
|---|---|
| 18 metal-path goals appended to `starter_goals.json`: charcoal, copper ore, Primitive smelter, copper ingot, Primitive smithy, copper tool, tin ore, bronze ingot, bronze tool, Improved smelter, iron ore, iron ingot, Improved smithy, iron tool, Advanced smelter, steel ingot, Advanced smithy, steel tool | Coordinator decision D-GOAL-1 (under Dave's 21 Nov rule that the coordinator answers design questions). Each goal is reached at its own stage (goal_stage_audit) and after the goals that build its stations (goal_station_audit). Ore hints say where to look (rivers, upstream, wet ground). |
| Fish goal hint: the rod needs a bone hook; the net is 3 rope and 4 stones | The recipe has a Hook; the hint left it out, so a player could not make the rod from it. |
| Drying rack goal hint: "Hold your knife" | The Drying rack is a knife blueprint; the hammer's list does not show it. |
| Story goal hint: Edda only, in the evening | The check counts Edda alone (`npc: edda`); the hint also named Hob. |
| Workbench hint (goal and hints.json): says what it makes | "It unlocks better tools" was wrong: tools are made by hand and at the smithies. |
| Butter and Cheese locked | Milk is a future item with no source; the recipes were offered with an ingredient nobody can get. |
| Stale `needs_code` flags and "read by nothing yet" in the goal files | All four checks run today (audit GA-53). |
| `tools/goal_station_audit.py` tie-break | It picked iron nails at the brick forge over bronze nails at the forge for "Any nails" and reported a false gap. |
| `tools/goal_stage_audit.py`, wired into `tools/merge_check.py` | Keeps every goal reachable with its own stage's metals. |

## Questions answered by the coordinator (21 Nov 2026, under Dave's questions rule)

| # | Row | Problem | Decision |
|---|---|---|---|
| GR-1 | Sawbuck (bp 352) | 16 Bronze nails put a simple sawing stand, used with the Stone - Saw, at bronze. #1460 kept it bronze. | Wooden pins (pegged), so it is a stone-age piece. Follow-up PR stacked on #1466. |
| GR-2 | Palisade gate (bp 71) | 2 Bronze hinges on a log gate; the Rustic - Gate (logs) has none, and Rustic doors have wooden pivots by Dave's door table. | No hinges: 8 logs, 3 twine, 1 rope. Follow-up PR stacked on #1466. |
| GR-3 | Stone - Planter, Trough, Channel, Channel corner, Channel tee | Iron chisel for laid cobblestone and mortar; Sturdy walls of cut blocks need none. | No chisel (laid masonry, not carving). Follow-up PR stacked on #1466, which edits the same test line. |
| GR-4 | Steel armour (Cuirass, Half plate, Helm, Gauntlets, Greaves, Sabatons, Plate harness) | Iron rivets; Dave named steel rivets for fortification. | Keep iron rivets: historically normal; no steel rivet item exists. |
| GR-5 | Steel - Striker (recipe 183) | items.json marks it future, yet it is craftable and nothing needs it to light a fire. | Locked in this PR until a use exists. |

## Depends on the ore layout (final pass)

- Goal hints `copper_ore`, `tin_ore` and `iron_ore` are worded for the ore thread's early layout (draft #1469: iron everywhere from the first hour as loose stones, bog iron and rusty outcrops needing a bronze pick; copper inland, first source about 1.4 km by route from spawn; tin from river finds below sources, first source about 2 km by route below the high mountains). Confirm when it lands; the loose iron stones need #1455.
- Encyclopedia `how_to_get` for Copper ore, Tin ore and Iron ore still say "a boulder over a body with any pick"; copper and tin rocks lie along rivers and are picked by hand or broken with the Stone - Hammer.

## Checked and left as they are

- Metal ladder: copper and bronze tools at the Primitive smithy; the Improved smelter (bronze fittings) is the first that smelts iron, with its bellows worked; iron tools at the Improved smithy (bronze anvil); steel at the Advanced smelter; steel tools at the Advanced smithy. No circle.
- Bog iron is dug with a Wooden - Shovel at the start, but it smelts only in the Improved smelter: iron is seen early and worked after bronze, as the ore plan wants.
- Handcart and Small wagon need iron-banded wheels (iron stage); the Small log sled covers the stone age.
- Building tiers Crude to Engineered need no metal except their doors and gates; Fortified needs iron bands and its doors steel.
- Chisel rows other than GR-3 follow D-CHISEL-1 (joinery, carving and cooperage keep one).

## Coverage and findings by tier

Every active recipe (427) and every offered blueprint (253) was read once in tier order (the first metal stage that reaches it), then read again for the wrong tool: kept tools, chisel tiers, hammer tiers, station levels, nail and hinge metals.

- **Stone (959 items, 207 pieces reached):** hint errors and the milk recipes above; GR-1 Sawbuck, GR-2 Palisade gate and GR-3 stone water pieces (all late for no reason). Noted, left: the Bucket (lumber and twine, by hand) is cooperage like the Barrel but takes no chisel; kept so wells and water carrying stay early. Wooden pins are made at the workbench with no knife.
- **Copper (42 items):** copper tools, nails, pipes, taps and drip heads at the Primitive smithy; the Wooden bowl and Serving platter keep a Copper chisel (carving). Nothing wrong. Every axe tier takes a Leather strap, so a copper axe waits for leather; consistent across tiers, left.
- **Bronze (75 items, 40 pieces):** the nailed and hinged furniture and storage (#1460 sets their metals); the Rustic chair, table and cupboard chisels (D-CHISEL-1, #1466); the Improved smelter and smithy with bronze fittings, which is what gates iron. Nothing else.
- **Iron (119 items, 69 pieces):** iron tools and weapons at the Improved smithy; Fortified pieces need iron bands and a Bronze hammer; Handcart and Small wagon wheels need iron bands. Iron - Saw, iron weapons and iron armour sat at brick forge level 1, the other iron tools at level 2: moved to level 2 like the tools (coordinator ruling, 21 Nov 2026). The Iron band and Iron anvil stay at level 1; no smithy gives level 1 alone, so neither change is felt in play today.
- **Steel (51 items, 19 pieces):** steel tools at the Advanced smithy; steel armour keeps iron rivets (GR-4); Steel - Striker locked (GR-5). Nothing else.
- **Never reached:** only the locked future rows (Bird trap, Fish trap, Wicker - Chest, Compost bin, Cold frame, Wool - Rug, Claw - Necklace, Fish soup, Pickled vegetables, Bonemeal) and now Butter and Cheese.
