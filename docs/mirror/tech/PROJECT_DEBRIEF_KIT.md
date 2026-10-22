# Post-project debrief and new-project starter kit (BP-T26). Dave's goal (2026-10-22): when this project is "finished", debrief and reuse everything learned and built to jumpstart the next ones.

## 1. Reusable assets (keep this list current; owner: Technical Director; review quarterly or at each milestone)
| Asset | Where | Reuse as |
|---|---|---|
| Best practices (rules, why, owner, Dave vs team) | tech/BEST_PRACTICES.md | starter rulebook; strip [LOCAL] game entries |
| Process (rules 1 to 4, build numbers, pre-push checks) | tech/PROCESS.md | template |
| Team structure, roles, ownership, priority, cross-talk, ideas flow | tech/HOW_WE_WORK.md, TEAM_PROPOSAL.md | team template |
| Question page + answers loop | questions/ (README, qa.html) | reusable owner-question tool |
| Check tools | tools/check_controls.py, items_check.py, check_warnings.sh, conflict-marker grep, bots.sh | adapt per engine |
| Handoff / archive pattern | HANDOFF.md short + docs/archive | template |
| Design doc discipline | DESIGN_IDEAS.md tags, DESIGN_REJECTED.md, DESIGN_PRINCIPLES.md, BIG_PICTURE.md, role map, changelog | template |
| Local-agent split (cloud vs owner's PC) | PROCESS.md RULE 3 | pattern |
| Lessons | tech/LESSONS.md | seed for the next project's pitfalls list |
| Game tech (voxel terrain, water sim, streaming, flora) | repo src/ | library candidates; list per module in the debrief |
| Memory notes about the owner's style | project memory | owner profile (voice, succinct, confidence rule) |

## 2. Debrief checklist (run when Dave declares a milestone or the project finished; Technical Director leads, one thread-day)
1. Freeze: tag the repo, archive HANDOFF.md, DECISIONS.md, BUILD_LOG.md, LESSONS.md.
2. Each thread writes a 1-page retro (<= 40 lines): what worked, what failed, what I would do first next time, reusable code/tools I own. Via the handoff, not chat.
3. Technical Director reads LESSONS.md and the retros and tags every BEST_PRACTICES entry: KEEP general / KEEP with change / LOCAL / DROP. Counts results.
4. Measure: tokens/time per phase if available, rework rate (builds reverted or redone), collision count, test-card pass rate.
5. Review decisions that aged badly (DECISIONS.md) and mark why.
6. Reusable-asset audit: confirm each row in section 1 still works; extract game-independent code into a library folder.
7. Dave's review: three questions on the question page: what to keep, what to change, what to start differently.
8. Produce the starter kit (section 3) and file it in project files under `starter_kit/`.

## 3. New-project starter kit outline (what a fresh project starts with on day one)
- `BEST_PRACTICES.md` seeded from the KEEP entries (general: git/push rules, zero warnings, build numbers, server authority, testing layers, reporting style).
- `PROCESS.md` rules 1 to 4, PRs/branch model, CI workflow files and the check scripts.
- `HOW_WE_WORK.md` template with the role slots (Coordinator, Technical Director + Guru, 3 to 5 area owners, Local runner), priority P0 to P3, cross-talk limits, ideas ledger.
- Doc skeletons: BIG_PICTURE, DESIGN_IDEAS (tags), DESIGN_PRINCIPLES, DESIGN_REJECTED, role map, design changelog, LESSONS, HANDOFF (short), JOBS, DECISIONS, BUILD_LOG, TEST_QUEUE, IDEAS ledger.
- Question page and README.
- Owner profile: how the owner likes to be reported to (succinct, "Test done: X pass, Y fail", "Still waiting on:"), confidence rule.
- Day-one decisions list to ask the owner once: engine/language, scope of first milestone, team size, who bakes/tests where, branch model, CI.
- Start with a SMALL team (coordinator + Technical Director + 2 owners), add threads only when queues justify it (LESSONS 2026-10-22).
