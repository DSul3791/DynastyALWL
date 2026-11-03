# Dino round 5 (3 Nov 2026, paper review on main): early-game text the player reads

No game data changed; owners below. `tools/text_vs_recipe.py` reports 0 mismatches (it checks numbers, not controls or names).

## A. Hints (data/items/hints.json)
| Hint | Text today | Problem | Fix | Owner |
|---|---|---|---|---|
| fuel, roast | "Press E at the fire to add sticks or wood." / "Hold E at the fire to roast..." | Wrong since #32 (E puts a burning fire out). Fixed in Sal's **PR #53, open and unmerged since 2 Nov** | merge #53 | Dave / moderator |
| bars | "Press Tab to see Health, Food, Water, Warmth and Energy." | The bar is Temperature since #113 | "...Water, Temperature and Energy." | Sal |
| cold | "Warmth low: stand near a fire or put on hide clothes." (trigger warmth_under_70) | Same rename; the bar now shows degrees, so "under 70" means nothing to the player | "You are cold: stand near a fire or put on hide clothes." | Sal |

## B. Starter goals (data/items/starter_goals.json, read by server_items.gd)
| Goal | Problem | Fix | Owner |
|---|---|---|---|
| berries | hint says "Roast meat at the fire" (hold-E roasting is gone) | "...Put raw meat in the fire with F; cook plants in a pot." | Sal |
| workbench | title "Build a workbench" and hint "make a Workbench", but the recipe and item are named **Camp bench**; a player typing "workbench" in the craft search may not find it | say "Camp bench" in title and hint | Sal |
| fish | done when the pack holds trout, perch, carp or pike. Pond and lake fish are covered, but a player fishing the sea (herring, mackerel, smelt, cod) or a brook in autumn (salmon) or summer (eel) never completes it | count any fish item, or add those species | Sal |
| shelter, bed, spear, knife | match data (32 sticks, 8 leaves, 4 twine; bedding or thatch; wooden spear 1 stick then 2 twine; knife 2 stones 1 stick) | none | |

## C. Guides
Checklist refreshed for main in the same PR (new-since list for everything merged 2 Nov, known-broken by bug number, Temperature bar, the fell line Dave chose). Tutorial step 10 uses Dave's line.
