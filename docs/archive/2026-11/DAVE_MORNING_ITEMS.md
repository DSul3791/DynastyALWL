# Dave's morning: five things to look at in game in the item area (Sal)

1. **Names and descriptions.** Open the inventory and hover the new items (wool and fur clothes, fish, crops, dishes): do the names read right (Steamed Shellfish, Seal Steak, Basic Oven) and do the one-line descriptions say something true? The full list is data/items/encyclopedia.json.
2. **Hints and goals.** Play the first ten minutes with hints.json and starter_goals.json in mind: are the 26 hint lines the right words, and is the reward (about 70 copper in total) the right size? Nothing shows them yet, so read them in the files.
3. **Prices.** Check Hob's stall against ECONOMY_PLAN.md: cooking stew should no longer be a profit engine (stews are 11 to 16 copper each now), kits and the bucket no longer lose money. Try selling a handful of dishes.
4. **Pace of the first hour.** Time yourself from spawn to a lit fire, a shelter and a workbench (now 20 sticks, 6 twine, 4 stones, 60 s). The paper estimate says it is probably too fast (CRAFT_PACING.md, FIRST_WEEK_WALK.md); tell me the minutes and I will tune quantities.
5. **Crops and the shore.** Farming still has no player-facing code, but the data is ready (14 crops, 4 to 30 hours to ripen, summer sowing). Tell me if grow times feel right and which crop list you want first; fish, shellfish and seaweed wait on the water-gathering action.
