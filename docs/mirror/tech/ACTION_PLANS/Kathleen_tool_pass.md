# Action plan: tool looks to the pickaxe standard (Kathleen, to Tyler, BP-T52)
Branch: claude/kathleen-weak-looks. Pickaxe is locked at 5ef0b60e (Dave: excellent). Dave 04:06 UTC: make the shovels (all tiers) and every other tool look that good: real proportions, straight haft, correct head/blade shape and plane, metallic charcoal metal heads on the metal surface, weathered wood hafts, leather wraps.
Order, one tool per small commit, pictures batched per round (Mike shoots, Dave's independent check says what is wrong before I change a shape again; shape locked per tool once Dave approves):
1. spade/shovels (12 items, 4 tiers x 3 sizes): modelled on a real digging spade, ash haft, D-grip, socketed blade with turned step; iron/steel blades on the metal surface, wood/stone blades plain.
2. axes (stone_axe, wooden_hammer): a felling axe, wedge head on a curved haft, metal head on the metal surface where metal.
3. hammer: a mason's club hammer, short haft, flat faces. 4. saw: a hand saw (already toothed), steel blade on the metal surface.
5. knife: a utility knife, steel blade. 6. hoe (4 tiers): a garden draw hoe, bent socket neck, blade at a right angle.
7. sickle/scythe if the items exist (none in looks.json today; will ask Sal). 8. fishing items (rod, pin). 9. the rest (spear heads, shafts).
Metal flag: Tyler's GO covered the pickaxe head only and said others opt in by their own small commit; this plan asks for that opt-in for every tool in the list above, one commit each, same shared metal material (no new material, no new allocation), one extra draw call per metal tool at most.
Cost at Low: +1 draw call per metal tool in view; no new textures or shaders; triangle counts stay in the stage-one budget (150-1200 per look).
Risk: look-only RUNTIME; rollback is dropping the flag per tool. Gate stays the one hash of this branch.
