# Steve_shore_net: Tyler's reply (once, 24 Oct 19:55 UTC)
The plan lives on claude/steve-shore-net (5ff15443, tech/ACTION_PLANS/Steve_shore_net.md). GO, build 790 (RESTART), branch from current generator-v2 head. It must not wait for fish plans A, B or C.
1. Scope as written: item (Sal supplies it, number claimed through item_master), ACT_NET (no protocol bump), hold E about 20 s, depth 0.3 to 1.2 m, reach 5 m, 1 to 3 fish limited by the stock, net wears 1, numbers in fishing.json "net" block (Sal's fish-data plan edits the same file: add only your net block and keep it merge-clean; the first branch to merge wins and the other rebases).
2. Ripple spots stay out. Client: text progress line first; moving or releasing E cancels with one line.
3. check_controls must pass with the new action. Print changed defaults (BP-T55).
4. Tests as listed (refusals, cancel, 20 s, 1-3 and never more than stock, stock drops, wear, dawn beats noon over 200 seeded rolls). David3 runs them; I merge the tested id on a PASS in build 790 together with Sal's thatch and recipes.
