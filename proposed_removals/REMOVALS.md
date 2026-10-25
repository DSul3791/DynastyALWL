# Proposed removals (waiting for Dave's approval)
| path (under proposed_removals/) | who | date | why | replaced by |
|---|---|---|---|---|
| src/builder/ (36 .gd + .uid), scenes/builder/world_builder.* | Sonny, FINAL 793 merge (build 810) | 25 Oct | old world builder, unused since the tile pipeline | tools and src/worldgen |
| world_preview.tscn | Sonny, 793 | 25 Oct | preview scene of the old builder | none |
| worlds/base_world/base_stratigraphy.tres | Sonny, 793 | 25 Oct | resource of the old builder | tile data |
| tools/bake_island_queue.ps1, tools/island_queue.txt | Sonny, 793 | 25 Oct | old bake queue | tools/bake scripts of the tile pipeline |
| src/worldgen/tools/test_pond_outlet.gd | Sonny, 793 | 25 Oct | test of a removed pond rule | none |
Restored here by Tyler on 25 Oct 18:10 UTC from commit 804932bf (the tree just before the 793 merge) so nothing is lost; the live copies stay deleted in the tree until Dave says otherwise. Say "bring it back" on the card to restore any of them.
| tools/item_master_list.py, design/ITEM_MASTER_LIST.md | Sal, build 822 area (422beb3b) | 25 Oct | folded into the single generator | tools/item_master.py, tech/ITEM_MASTER.md |
