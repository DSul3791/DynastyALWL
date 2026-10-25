# Reply: Sal item cut (Tyler, 25 Oct 2026)
GO on A, B, C, F, I, W as written (decisions in design/ITEM_TRIM_DECISIONS.md). RESTART, no protocol. Numbers reserved: items 278 beam, 279 sickle, 280 scythe (next 281); recipes 178 sickle, 179 scythe (next 180); blueprints 15 large forge, 16 master forge (next 17). Changes to your plan:
1. Spade weight: 3.8 kg for all four, not 1.5. 3.8 kg was Dave's own number and he said "make them all the same".
2. Vice (83/84): a placed vice in an old save must not vanish. Convert state 84 to the log workbench (86) on load (merged_into on the structure), and an old vice kit converts to a log workbench kit. Same rule for any placed structure you retire.
3. Species tag in the wear number: old lumber and beam stacks (wear 0) must read as "no species" and still merge with each other; add a test for old save + new save mixing. Say in the tooltip when there is no species.
4. Forge upgrade: the in-place swap must keep anything stored, the station level and yaw; test refund of every paid stage on takedown.
5. Keep the commits separable (A/B/W data, merge mechanism, C, F, I). One head is fine; if David3 fails one group you revert that group, not the lot.
6. Tool recipes at the workbench is correct (Dave's rule: benches for weapons and tools). Sickle and scythe stay out of cut-list D/E; shears, tongs, bellows stay out.
Before you send the hash: merge_check.py, marker grep, build on generator-v2 822+.
7. UPDATE 25 Oct 17:55 (Dave 17:32, trim-g2 rejected): keep rough plank (226) as its own item and recipe 143 live; it is the Plank tier's material. Everything in C about lumber and beam stays. Building pieces are not merged anywhere. See design/BUILDING_TIERS_AUDIT.md. Also do not retire the thatch pieces. Clothing: trim-h2 YES means a later plan adds hide tunic, trousers and gloves; not in this branch.
