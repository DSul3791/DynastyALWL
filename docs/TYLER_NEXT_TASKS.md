# Tyler's self-assigned tasks (standing instruction from Dave, 1 Nov 2026)

Round 1 (systems, placement, tests; the moderator's list was finished first: chest/sleep self-tests, join freeze, rig kit placement, lit campfire check)

1. **Join cost of the ground scatter.** The slow-tick log showed `scatter` taking about 0.75 s on the first tick after a join (cells laid out in one go). Cap the work per tick by time (not only by cell count), so a join never costs a visible hitch. Check with the `items tick slow` log line in a rig run.
2. **A regression test for the join stall.** `test_cover_async.gd`: a server `_cover_at` on a chunk not made yet returns at once (under 50 ms) and the chunk is made by a worker; after it is made the answer is right. Stops the 4-8 s freeze from coming back.
3. **Admin energy setter coverage.** `ACT_ADMIN_ENERGY` (56) is new: add it to PROTOCOL.md notes and a server test (admin only; a non-admin peer changes nothing).

Status is kept below as each is done.

- [ ] 1  - [ ] 2  - [ ] 3
