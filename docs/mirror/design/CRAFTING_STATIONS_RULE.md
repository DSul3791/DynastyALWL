# Crafting stations rule (Dave 25 Oct 02:50, standing)
"We only use benches to make weapons and tools, and we use cooking pots and those kind of benches for cooking." And (02:49): thatch pieces and similar are "made in your hand, not made on the bench."
1. **Benches (camp bench, workbench) make WEAPONS and TOOLS only.**
2. **Cooking uses cooking stations** (campfire, campfire pot, later oven/hearth), never the bench.
3. **Everything else is made BY HAND** in the player's own crafting menu: building pieces and kits (thatch floor/wall/roof/doorway, section kits, ladders, chests), clothing (hide cloak, boots, leggings, backpack), furniture and station kits themselves (including the camp bench kit), materials.
4. **The bench itself is a hand craft** (a station can never be required to make the first station).
## Open edge cases (Sal's audit lists them; Tyler recommends; Dave decides on ONE QA card)
- **Machines that process materials** (sawmill: lumber and beams; forge: nails, hinges, saw blade, smelting; brick and tar at the campfire): they are not benches and not hand work. Recommendation: keep them as PROCESSING stations for materials that physically need a machine or heat, kept separate from benches, so rule 1 and 3 hold for everything a player makes with their hands; the stations themselves (kits) are hand-made.
- **Stone tools** (stone hammer, spade, hoe, adze) are tools, so the bench is correct by rule 1; the wooden hammer, tools whose recipe is wood + twine only are by hand (first hour).
## Audit
Sal audits all live recipes (125) against these rules: every recipe gets one class (tool/weapon at bench, cooking at a cooking station, by hand, processing station). The audit table goes to design/RECIPE_STATION_AUDIT.md; changes ship as ONE data branch (recipes.json only, no number changes), gated by validate_items, the dup sweep, test_server_items, test_first_hour, and a test per class ("by hand" recipes craft with no station; bench recipes refuse without one).
