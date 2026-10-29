# Recipe graph report (Items job 72, 2026-10-21)

Checked by `src/worldgen/tools/validate_items.gd` (runs in tools/items_check.py, step validate_items). Rules now enforced as errors:
- every recipe can be made (all inputs gatherable or craftable);
- no cycles in the "made from" graph (needs and kept tools), reported as `cordage -> spear -> cordage`;
- every core item (items.json) is gatherable, craftable, a placed structure form, a kit, or marked `"future": true` in its row.

Today (29 core items, 174 gathered plain materials, 17 recipes): no errors. 174 gathered materials are gatherable (flora yields); 15 core items are craftable; none marked future.

Reported as warnings (dead ends, for Dave):
- Core materials nothing uses yet: **bark** (from felled trunks) and **tree_roots** (from the root ball). They have a purpose later (bark: tanning, cordage, containers; roots: food and medicine, fuel), but no recipe uses them yet.
- 117 of the 174 gathered materials have no use yet (not eaten, no recipe, fuel or repair): they wait for the herb, food and crafting systems.
Two lumber items (lumber, plank chest kit) are craftable by recipe rows with `"known": false` (need a saw mill); they stay craftable in the graph.
