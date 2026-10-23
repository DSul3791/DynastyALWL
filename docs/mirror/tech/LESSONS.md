# Lessons log (BP-T26). Running record, kept as we go; feeds the post-project debrief and the next project's starter kit.
Format: date | area | what happened | worked / failed | lesson | source. One line each; newest at the bottom. Anyone adds a line when a bug, rework, collision or good surprise teaches something; the Technical Director reviews it in the daily check and tags entries [KEEP] (carry to next project) or [LOCAL] (this game only).

2026-10-20 | git | Conflict markers reached generator-v2 for 5 minutes (d7844db, fixed in bce297f). | failed | Grep for conflict markers before every push; automate in CI. [KEEP] | PROCESS.md
2026-10-20 | builds | Two threads took the same build number from the "next number" line. | failed | One owner of numbers, or a deterministic rule (max of origin+log, +1). [KEEP] | PROCESS.md, BUILD_LOG.md
2026-10-21 | quality | 233 GDScript warnings built up in logs, hiding real problems. | failed | Zero-warning rule from day one, checked by a tool. [KEEP] | PROCESS.md
2026-10-21 | water | Waterfall "cascade steps" advice conflicted with the owner's picture of one clean chute. | failed | Owner's reference image/rule beats generic research; write the owner rule at the top of the research file. [KEEP] | tyler/BEST_PRACTICES.md
2026-10-22 | server | Crash hunt root cause: server main thread stalled by dig/chop spam (builds 592-609). | worked after fix | Never block the server main thread; time-slice or thread heavy work; find causes with logs, not guesses. [KEEP] | DECISIONS.md
2026-10-22 | process | Many threads pushing to one branch caused collisions. | failed | Per-thread branches merged by one owner (BP-C107). [KEEP] | BEST_PRACTICES.md
2026-10-22 | docs | HANDOFF.md grew to 112 KB; every new thread paid ~28k tokens to read it. | failed | Keep the top handoff under 12 KB, archive history. [KEEP] | HANDOFF.md
2026-10-22 | team | Nine always-on specialist threads cost more than they saved at a one-tile scope. | failed | Fewer, broader owners; workers on demand; match team size to scope. [KEEP] | TEAM_PROPOSAL.md
2026-10-22 | tests | Test requests sent to Dave one by one interrupted him. | failed | Queue tests, one grouped test card. [KEEP] | PROCESS.md RULE 2
2026-10-22 | cost | Builds that fit on Dave's PC were run in the cloud, burning tokens. | failed | Run GPU, editor and long runs locally via the local agent. [KEEP] | PROCESS.md RULE 3
2026-10-22 | docs | Design file reached 376 KB; nobody could read it all. | failed | Big-picture page + role map + changelog (BP-T25). [KEEP] | BEST_PRACTICES.md
2026-10-22 | communication | Dave uses voice and finds long reports hard. | failed | Succinct reports, results first, "Still waiting on:" line. [KEEP] | BP-T10

- 2026-10-22 Kathleen: generated-asset scripts (make_*.py) re-encode every ogg differently each run; after running one, git checkout unchanged oggs and add only new ones.
- Sonny: ground/water changes are verified by hand (4 h dry sim, tile maps). Lesson: write the probe as a repo test the first time (head pond fill test) so the next owner and MikeW can rerun it. A cloud bake never matches Dave's tile hash, so compare cloud before/after only.
- Tyler 2026-10-22: three build-number collisions in one day came from every thread editing the one BUILD const in terrain_client.gd; a per-push next-number script or a separate build file removes them.
- Tyler 2026-10-22: a join hang that "a restart fixed" was joining a stale or closing old server; a version handshake beats a launcher workaround.
- Tyler 2026-10-22: a stub change meant to survive a private repo declared globals that collided with the real page's consts, so the page hung on "Loading...". Wrap stubs in a function, test with the real page in a headless browser, and show any load error on screen (BP-T34).
- 2026-10-23 Guru: Dave's open QA tab kept OLD page code (v7) after v8 was pushed; the refresh button only reloads the questions, not the page, so new card types showed "has no choices" errors. Fix: page v9 checks its own version on every load and reloads itself. Rule: after any page code change, tell Dave to close the tab and reopen the link once.
- 2026-10-23 Guru: build 743 pushed with conflict markers because a shell chain used `;` after `git merge` and went on to commit. A merge script must stop on conflict: check `git status` for UU and run merge_check.py BEFORE the commit; if either fails, abort the merge. (Fixed in 744; CI now catches it on generator-v2.)
