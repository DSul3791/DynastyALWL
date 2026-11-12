# PLAYTEST-001 — crafting rows (TEST-001, TEST-005, TEST-012)

Dave's playtest of 12 Nov 2026. Base: `origin/dev` b922cc88a59586dfbd41f806744d9ccedfe2bf26. Branch `claude/project-thread-aluzue`.

| Test | Status | Cause found | Fix |
|---|---|---|---|
| TEST-001 crafting does not stop at quantity 1 | NEEDS PLAYER VERIFICATION | A press on a recipe row held for 0.4 s or more (`CRAFT_HOLD_MS`, decisions row 24 (7), 8 Nov) queued everything the stock allowed, up to 20 (always 20 in Admin mode). The quantity box was ignored on row clicks. A slow click looked like endless production; a quick one made one, hence "intermittent". The server queue itself honours the count (`_queue_craft` clamps to the request). | Hold-to-craft-all and shift-five removed with their helpers (`craft_click`, `click_count`, `max_makeable`). |
| TEST-005 clicking a recipe crafts | NEEDS PLAYER VERIFICATION | Row clicks crafted by design (decisions row 24 (7)). | Click selects and shows the card only; Shift-click makes exactly one; the Craft button makes the box's quantity (`RecipeList.row_clicked`). E over a recipe still makes the box's quantity (unchanged, a deliberate key). The "Make it (makes … first)" helper makes one, as before. Supersedes decisions row 24 (7) for the recipe row. |
| TEST-012 crafting sounds stop early | NEEDS PLAYER VERIFICATION | The work sound was one 4.5 s clip played when the queue started; nothing restarted it. | `ItemSounds.watch` (every 0.1 s, window open or shut) starts the next clip whenever one ends while the head craft runs, switches sound when the recipe changes, and stops when the queue is done or cancelled, or when the craft waits (more than 1.5 s past the server's expected end: away from the station, no room). |

Tests: new `src/worldgen/tools/test_craft_click.gd` (row clicks, Craft button, sound start/repeat/stall/stop). Selector `tools/tests_for_diff.py` picks 61 fast tests (inventory_view and item_sounds are loaded widely) plus `check_look_names.py` and warnings. PC run: see PR.

Review round 1 fixes: the server's time left now includes the craft pace (skill, rest, cold), so the sound, ring and timer last as long as a slowed craft; the craft_start cue (never heard before: wrong folder) plays; stale comments and decisions row 24 (7) note updated.

Residual: a craft paused at a station and resumed keeps silent until the server's next queue update (the next finished craft). Visual and audio results are not passed until Dave hears and sees them in play.
