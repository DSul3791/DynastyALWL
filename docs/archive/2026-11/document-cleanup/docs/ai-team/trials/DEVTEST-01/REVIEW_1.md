# DEVTEST-01 — independent gate review 1
- Reviewer: fresh temporary `gate-reviewer` (read-only: Read, Grep, Glob, read-only git), not the author. Ran under the `gate-reviewer.md` profile text with the `ponytail-review` method (spawned as a general-purpose agent with model `sonnet`, effort `high`, because this session loaded its agent list before the branch carrying `.claude/agents/` was checked out; actual serving model not observable).
- Candidate: `1726dc29d10ad073c8de69568c9b66e28fed2fa4` vs base `be491ba638610f23761d43be78787179c48e58fe` (coordinator-supplied `git rev-parse HEAD`; `git status --short` showed only Dave's own uncommitted files).

## VERDICT: PASS (no Must-fix)

## Findings
1. Lean, `src/shared/inventory.gd:159`: the `table != null and table.has_method("spend_order")` guard can only hide a mismatch, since every real table is an `ItemTable`. Matches `fills_of`'s existing pattern; acceptable.
2. Lean, `src/stream/server_items.gd:8200`: the `_gather_site` lambda is a dense one-liner and the `0` "keep my place" sentinel is implicit. Correct; also recorded by the engineer.
3. Should-fix (minor, test), `src/worldgen/tools/test_build_stock.gd:254`: `_start_deferred` and the chest/site deposit branches are covered only indirectly (all go through the shared `remove_fill`). Low risk.
4. Unmeasured risk, `src/shared/item_table.gd:102`: `spend_order` sorts at most 26 members and allocates, once per group ingredient per take; counting paths do not call it. A few sorts per player action, not per frame.

## Verified by the reviewer
- Every pay path found by grep (pack, chests, `recipe_table.craft`, `_start_deferred`, dead kit, `_ground_stock`, `_ground_take` for repair and deposit, `_stock_take`, `_gather_site`) uses the one ranking; trade (`remove`) and `_pull_nearby_logs` (a move, not a pay) unchanged, as disclosed.
- Source priority unchanged (ground stock within 4 m, then pack and 12 m ground, then chests; repair: ground, chests, pack). Count paths still match take paths; insufficient totals still refuse with no partial removal; exact-id and non-group costs unchanged.
- `_refund_number` picks the same member as before for every group (same key, group index only breaks full ties as before).
- Client: only `count_fill`/`fills_of` are called; no prediction mismatch; no protocol or schema change.
- `item_table.gd` edit outside the brief's list is justified (shared code cannot reach `server_items`; `ItemTable` already owns the group lookups) and recorded.
- Test evidence files: 182 `.result` files all PASS, empty `retries.log`; with the fix disabled the new checks fail (8, 7 and 1). `validate_items` 0 errors.

## Not verified by the reviewer
No Godot rerun (read-only); `tests_for_diff.py` selection only spot-checked; no in-game, multiplayer or timing check; Library design files SOURCE UNVERIFIED.
