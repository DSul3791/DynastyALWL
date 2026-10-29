# Tyler reply (once, 25 Oct 00:30 UTC): Sal campfire pot + twine tests + craft menu + auto-make parts - GO, as three merges
Base: claude/sal-cooking-tripod head after 6e30ab9b / plan commit 0632e238, rebased on the merged thatch shelter (e2986139). No new numbers needed (items 254/255, recipe 165 are reserved).
Split so the pot is not held up by the bigger items (same branch family, three heads, each its own PASS id):
**A. sal-campfire-pot (sections 1 and 2) - merges first in 792, with fire tiers.**
 - Section 1 approved as written. First fix the failing check "an old state 1 fire loads and takes the pot": a failing check is not merged around, and the test is not weakened or skipped.
 - Section 2 (test updates): approved because twine really is recipe 1 now. David3 reviews the DIFF of the four edited tests: every old assertion is either kept or replaced by an equal one; none removed to get green. Print the list of changed assertions in the notes.
 - Gate: the CAMPFIRE POT gate in MERGE_CHECK_NEXT3.md (snap, cap, cook, remove, save/reload all three states, old tripod saves, old state-1 fires), dup sweep, parse_scan, local_check 233.
**B. sal-craft-menu (section 3) - client, RESTART label because of recipes.json categories; next after A.** Search box and category tabs; alphabetical inside each; "category" in recipes.json with a default by kind. Gate: validate that every recipe has a category; filter tests ("tw" shows Twine); no recipe id or number changes.
**C. sal-auto-craft (section 4) - server crafting queue, separate branch, its own plan reply is THIS one; merge after B.** Approved with limits, because it touches a shared path:
 1. Cycle guard: a recipe chain that revisits a recipe stops with "cannot make"; depth cap 4 as written; total planned queue entries capped (50) with a plain message above it (no 5,000-twine queues).
 2. Only consumed ingredients are auto-made; never a missing kept tool (as written), never an item that needs a station the player is away from (as written).
 3. Ambiguity: if more than one known recipe gives the missing item, do NOT guess: show the menu line "Choose how to make X" and make nothing automatically (changes the "first by recipe number" rule; surprises cost Dave materials).
 4. Pack capacity and weight: plan against the pack AND its carry limit; intermediates that do not fit stop the plan with a message.
 5. The all-or-nothing plan is made and checked server side in one step; sub-crafts and target are queued together. Cancel of a sub-craft cancels dependants and refunds exactly (test: refund equals the ingredients taken, no duplication).
 6. Save/reload mid-queue and a server restart with queued sub-crafts: queue is either restored fully or dropped with the ingredients returned. Test both.
 7. Tests as listed (15 fibre axe; 10 fibre nothing queued; cancel twine removes axe and returns fibre; station intermediate away not planned) plus cycle, cap, capacity, ambiguity, save/reload.
 Gate: David3 test_auto_craft.gd, test_server_items, craft tests, dup sweep, local_check. Mike plays it (axe from fibre, cancel, a long chain) when Dave's PC is free. Output text in the menu, "Makes 5 twine first", is part of C, client side.
Order in 792: shelter -> fire tiers -> A -> rough bed -> sound hookup -> B -> C -> no-stack caps + weight audit. Send each head's hash when ready.
