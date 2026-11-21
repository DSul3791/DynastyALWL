# Dead-end materials: made but used by nothing (Sal, 2 Nov 2026)

**Status 5 Nov 2026 (MikeW): done.** All seven proposed materials are now used: hinges (plank chest), wooden pins (stool, chair), rough plank (ladder), leather strap (leather jerkin, gambeson), fine leather (leather cap), tar (water wheel) and hide glue (plank shield, #146). The item validator lists none of them as dead ends; item notes fixed in #369. Soap and compost still wait for a game rule.

`tools/item_master.py` lists 18 materials that no recipe uses. Arrows, firewood, driftwood, roots, gravel and rotten food are used by the game rules, not by recipes, so they are fine. These nine can be crafted but lead nowhere, so making them is wasted effort.

| Material | Made from | Proposed use (add 1 to 2 to an existing recipe) |
|---|---|---|
| Hinges | 1 iron ingot at the forge | Plank chest kit, doorway kits from plank tier up |
| Wooden pin | 1 lumber at the workbench | Table, chair, bench and stool kits (pegged joints) |
| Rough plank | 1 log at the workbench | Lowest plank tier: plank floor, ladder |
| Tar | 5 pine tar at the campfire | Water wheel and bridges (waterproofing) |
| Hide glue | 1 hide in the pot | Bows and the plank shield |
| Leather strap | 1 leather by hand | Backpack, tool rack, quiver |
| Fine leather | leather and animal fat in the pot | Hide boots and hood upgrade (warmer) |
| Soap | tallow and potash in the pot | Needs a rule (cleanliness, sickness); Steve |
| Compost | 3 plant fibre by hand | Needs a rule (faster crop growth); Steve |

Recommendation: add the first seven as small extra ingredients. This is data only, about an hour of work, and makes every one of them worth crafting. Soap and compost wait for a game rule. Asked on QA card `sal-dead-end-materials`.
