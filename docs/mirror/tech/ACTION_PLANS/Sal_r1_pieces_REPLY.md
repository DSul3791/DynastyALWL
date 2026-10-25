# Tyler reply (once, 24 Oct 23:25 UTC): Sal thatch shelter 0450dcb1 - GO in 792
Approved: thatch floor (foundation tier 1), wall, roof, doorway kits at the camp bench, open from the start; fire kit 6 sticks + 3 stones. RESTART. Verified on current generator-v2 (build 791, e1fcbdf5): trial merge of 0450dcb1 is clean, parse_scan 0 problems, merge_check clear, items 262 with 0 dup numbers (highest 266, next 267), recipes 166 with 0 dups (highest 169, next 170). Batch 2 (8600df50) is NOT a commit in generator-v2; its content comes in with this branch (wooden hammer is recipe 161, bed kit 160, shore net 163, thatch kits 166-169; 162 and 164 are unused, never reuse them; tripod reserved 165, adze retired).
David3 gate: validate_items, test_server_items, placement tests, full duplicate sweep of items.json and recipes.json, a SAVE ROUND TRIP (place floor, wall, roof, door, save, reload, same pieces), a placed-fire save from before (state 1 unchanged), parse_scan, local_check 233.
Merge order for 792 (each Sal branch is rebased by Sal onto the previous merged head, since weights.json and recipes.json conflict between them; I will not hand-merge those):
 1 sal-thatch-shelter 0450dcb1
 2 sal-fire-tiers-build (rebase) 
 3 sal-cooking-tripod (recipe 165)
 4 sal-no-stack-caps-build + sal-weight-audit (after Dave's four weight cards)
Looks: floor/roof/door reuse foundation meshes until Kathleen's land.
