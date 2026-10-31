# Flint, obsidian, ore and coal sources: data decisions and code spec (Sal, 2026-10-31; F-02, F-05)

Data already in place: items Flint 279, Pyrite 280, Obsidian 281, Copper ore 301, Tin ore 302, Iron ore 303, Coal 304; smelting recipes 190 to 193 (forge level 1, steel at 2). **No world source gives any of them.** Code session to build, in this order (each step unlocks real recipes):

1. **Flint (unblocks hide scraper, javelin, sickle, so leather).** In `data/items/boulders.json` boulders yield stone only. Add: each stone that comes off a boulder has a 4% chance (rises near water banks, 8%) to be a **flint nodule** instead. Reads in the boulder code (src/stream/*boulder*). Also flint on riverbed banks (`ground_scatter.bank`): 6% of bank stones.
2. **Coal:** a rock outcrop or exposed cliff in hills (slope above 0.5, bare_rock or alpine) gives 1 coal per pick blow; stone pick or better. Surface seams only, no digging.
3. **Copper, tin, iron ore:** pickable outcrops, one ore item per blow with a stone pick (copper, tin) and an iron pick (iron needs a tier above the pick that mined it, so: copper and tin with a stone pick, iron with a bronze pick or better, to give the ladder a reason). Rarity: copper common in hills, tin rare, iron common deeper. The terrain table `data/tables/resources.json` already lists the minerals.
4. **Obsidian:** only on volcanic_waste biome and lava-glass outcrops.
5. **Pyrite:** with ore outcrops, 5%.

## Lumber without iron (F-05, data done)
Stone wedge (item 353, recipe: 2 stone + stick, by hand) + a log at a workbench gives 2 Lumber (recipe "Rough planks"). The hand saw and sawmill stay as the faster route. So wooden building (sections, chests, ladders) is reachable without any metal, as soon as the player has a workbench and a wedge.

## Hand saw alternatives
None added beyond the wedge. The saw blade still needs the forge chain.
