# Reply to Kathleen: metal surface (one reply, 25 Oct 03:50 UTC; f4ca1d5a on claude/kathleen-weak-looks)
GO. Look-only, RUNTIME, no protocol, ground or save change.
1. Same branch as the weak looks batch: it is one gate. David3 gates the FINAL hash of claude/kathleen-weak-looks after rebase on the generator-v2 head; name it once (BP-T59).
2. Metal flag only on the pickaxe head for now; others opt in later, each by its own small commit in a later batch.
3. Pickup glow in inventory_view.gd loops all surfaces: confirm it still draws once per surface with no double glow; test_pick_axes reads all surfaces, as you wrote.
4. Material is shared and created once (not per instance); check no extra allocation per held swap.
5. Gate: parse scan, check_look_names, test_pick_axes, local_check 233, no new failure (baseline six), and pictures (held front/behind/right, ground, inventory icon) judged by you. Draw calls: David3 reads the render info once with 20 pickaxes in view; expect +20 calls at most.
6. Rollback is dropping the flag; no migration.
