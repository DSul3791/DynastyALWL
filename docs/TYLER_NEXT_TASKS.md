# Tyler's self-assigned tasks (standing instruction from Dave, 1 Nov 2026)

Round 1 (systems, placement, tests; the moderator's list was finished first: chest/sleep self-tests, join freeze, rig kit placement, lit campfire check)

1. **Join cost of the ground scatter.** The slow-tick log showed `scatter` taking about 0.75 s on the first tick after a join (cells laid out in one go). Cap the work per tick by time (not only by cell count), so a join never costs a visible hitch. Check with the `items tick slow` log line in a rig run.
2. **A regression test for the join stall.** `test_cover_async.gd`: a server `_cover_at` on a chunk not made yet returns at once (under 50 ms) and the chunk is made by a worker; after it is made the answer is right. Stops the 4-8 s freeze from coming back.
3. **Admin energy setter coverage.** `ACT_ADMIN_ENERGY` (56) is new: add it to PROTOCOL.md notes and a server test (admin only; a non-admin peer changes nothing).

Status is kept below as each is done.

- [ ] 1  - [ ] 2  - [ ] 3

## Carried over from the files archived on 1 Nov 2026 (TYLER_NEXT_PLANS.md, TYLER_QUEUED_TESTS.md)
The full list of what is open is `docs/handoff/SCOPE_TYLER.md` sections 3 and 8 (read that first). Items from the archived files not repeated there:
- The Python erosion-model check from the climate plan was never done (the gate Python had no numeric libraries then); do it if numpy is available, else leave out.
- From the queued-tests list: creator-preview lighting look (editor), `tools/mutation_check.sh` for the newest features, lean-to review by reading (done), bot budget 70 (see scope section 8 #10).

## Phase 1 of the closing plan (1 Nov 2026, no Godot): done in code, verified in Phase 2
- Chest error at `inventory_view.gd:4562` (inventory nil on a shared server): `_wait_inventory_ready()` added to the chest, sleep and snare self-tests, chest test guards a closed chest (8aa53e52). Phase 2: `items_check --only chest,sleep` must PASS, and the shared-server run must show no `Invalid access`.
- Ported `steve-shot-lock` (e6016081, mouse look ignored during a --shots run) and `steve-rig-item` (010e5ea7, `look_rig.sh --showroom-per N`, exact showroom row match, ground default 31.25). Phase 2: one `look_rig.sh --showroom Spades --showroom-per 5` run and a `bash -n` (done) check.
- Clean-server reruns: every `items_check` CLIENT step starts its own fresh server, so `items_check --only sleep` is the clean sleep rerun. The SNARE self-test needs a server with `traps.json` `test_chance` above 0 and up to 200 s: run it by hand: `godot ... --snare` against a throwaway server with that knob (owner: me, Phase 2, step 3).
- Dino #11 (camp bench and drink have no automated check): owner me; exact next step: a server test `test_camp_bench_drink.gd` (place a bench near a fire, sit, comfort rises; drink from water lowers thirst) modelled on `test_comfort.gd`; then an `items_check.py` client entry. Written, unrun: `src/worldgen/tools/test_camp_bench_drink.gd` (server level); Phase 2: run it and fix any wrong name or number; the `items_check.py` client entry stays a follow-up (owner me).
- Join stall (scatter first cell blocks 6-8 s on a ground-height read): owner Sonny (terrain); exact next step: a non-blocking `surface_height` for the scatter (use only cached tiles, skip the cell otherwise); why: it is the one remaining hitch right after joining.
