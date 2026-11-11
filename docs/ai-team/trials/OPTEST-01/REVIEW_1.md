> Independent `gate-reviewer` review of `HANDOFF.md` (first version), 11 Nov 2026, read-only agent, base `b03ac553`. Saved verbatim in substance by the coordinator because the reviewer profile cannot write files. Coordinator spot-checked findings 1, 3 and 6 against the code (`grep fill_ground`, `soils.json` id 9, no `design/` in `/mnt/project-files`): confirmed.

# OPTEST-01 review 1 — verdict FAIL (one Must-fix)
Ponytail-review skill text preloaded into the reviewer at start: **YES** (observed by the reviewer).

## Must fix
1. The proposed `_on_filled` hook (`scenes/terrain_client/terrain_client.gd:1730`) fires for every `_fill_ground` caller, not only the spade: `server_items.gd:2507` (spade), `:2706` (hoe smooth), `:2914` (grade), `:3004` (grade), and cave-in rubble `terrain_server.gd:2175`. Hoe strokes would play a scoop to every client on top of the hoe's own click sound (`held_item.gd:2121-2124`), up to ~4 fills per stroke with no merge guard in `placed_sounds.gd:_once` (unlike `dig_sounds.gd` `MERGE_MS`/`MERGE_M`), and every cave-in would scoop. A real fix needs a discriminator on `filled` (PROTOCOL change, `PROTOCOL.md:155`) or the actor's client matching the broadcast to its own fill (other players hear nothing: a design choice to state). Tests must cover the negative cases.

## Should fix
2. Decision level: an RPC argument is level C (breaking RPC); client-side matching is B at best. Not A.
3. Material 9 is `stony_soil` (`data/tables/soils.json:126-128`), reached via `FILL_SOIL` (`server_items.gd:2457`), not "stone"; a client `material == 9` duplicates the server table.
4. `placed_sounds.gd:_once` (214-239) has no dedupe; only the server's `_fill_last` (`terrain_server.gd:2329`) drops an identical repeat.
5. Answer (3) "met in substance" is overstated: there is no reply to `ACT_FILL`, only the shared broadcast.
6. Handoff says `decisions_pending.md` was grepped; it is not in the checkout nor in `/mnt/project-files`. Must say NOT SEARCHED / inaccessible.

## Lean
7. Several line numbers off by 1-4 (`net.filled.rpc` is 2341; `_reject` 2465/2469; pace return 2475; no-material `_say` 2489; `pieces < 1` 2501).
8. Stale comment `placed_sounds.gd:127` ("dragged onto it") from the old load design (`docs/mirror/tech/BUILD_LOG.md:382`).

## Checked OK
Remaining file:line claims; single `shovel_load` caller always `false`; unverified Dave claim handled per DOCUMENT_AUTHORITY (UNVERIFIED RESTRICTION, not blocking, routed for source); NOT RUN / SYNC PENDING labels truthful; freeze respected (only `TASK_BRIEF.md` and `HANDOFF.md` in the trial folder; shortcut still at `held_item.gd:2140`); template followed.

## Not verified by reviewer
Git state (reviewer has no git tool; coordinator verified `git status`: only `docs/ai-team/trials/` untracked, HEAD `b03ac553`); Library; `_once` side effects; audio; Godot (not run).
