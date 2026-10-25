# Crafting stations rule (Dave 25 Oct 02:50, standing)
"We only use benches to make weapons and tools, and we use cooking pots and those kind of benches for cooking." And (02:49): thatch pieces and similar are "made in your hand, not made on the bench."
1. **Benches (camp bench, workbench) make WEAPONS and TOOLS only.**
2. **Cooking uses cooking stations** (campfire, campfire pot, later oven/hearth), never the bench.
3. **Everything else is made BY HAND** in the player's own crafting menu: building pieces and kits (thatch floor/wall/roof/doorway, section kits, ladders, chests), clothing (hide cloak, boots, leggings, backpack), furniture and station kits themselves (including the camp bench kit), materials.
4. **The first bench itself is a hand craft** (a station can never be required to make the first station).
5. **PROCESSING STATIONS** (sawmill, stone forge, blacksmithy, woodworking table, vice, tool rack) turn materials into materials or parts; their recipes (lumber, beams, nails, hinges, saw blade, fine board, smelting) stay at them (Dave 25 Oct 02:56). **The station KITS themselves are made at the log workbench** ("a workbench of some sort"), not by hand. Chain: hand -> log workbench -> processing stations.
## Open edge cases (Sal's audit lists them; Tyler recommends; Dave decides on ONE QA card)
- **Machines that process materials** (sawmill, forge, brick and tar at the campfire): DECIDED (Dave 25 Oct 02:56): they are processing stations, material recipes stay there; the station kits are made at the log workbench (rule 5).
- **STILL OPEN with Dave:** the five material recipes Sal made by hand (rough plank, cut stone block, cobblestone, stone shingle, wooden pin): by hand, or at a processing station? The early-game list says "No planks (sawmill only)".
- **Stone tools** (stone hammer, spade, hoe, adze) are tools, so the bench is correct by rule 1; the wooden hammer, tools whose recipe is wood + twine only are by hand (first hour).
## Audit
Sal audits all live recipes (125) against these rules: every recipe gets one class (tool/weapon at bench, cooking at a cooking station, by hand, processing station). The audit table goes to design/RECIPE_STATION_AUDIT.md; changes ship as ONE data branch (recipes.json only, no number changes), gated by validate_items, the dup sweep, test_server_items, test_first_hour, and a test per class ("by hand" recipes craft with no station; bench recipes refuse without one).

## UPDATE 25 Oct 02:57 UTC (Dave): NO KITS, BLUEPRINTS ON THE HAMMER
Thatch pieces, building section kits and processing-station kits are not kit items. They are blueprints on the hammer, "just like the bridge". Sal writes one plan (item/recipe numbers stay, old saves load). Supersedes the kit parts above. Sal crafting gate (sal-thatch-floor-hand) is HELD until that plan is answered.

UPDATE 25 Oct 03:00 UTC (Dave): FIRST TIER IS NEVER A BLUEPRINT. Thatch four, rough bed, campfire, campfire pot, chests, first bench stay hand-crafted items. Blueprints on the hammer are for later tiers only.
