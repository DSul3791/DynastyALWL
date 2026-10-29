# Concerns: Tyler_Guru_SenDev (Technical Director + Guru), 2026-10-22 15:15. Triple check before dev restarts.

1. **Code never audited.** BP-C11 (server authority) and save versioning (C90) are written from docs, not read in code. Risk: a cheat or save bug shipped as "best practice". Fix: one read-only code audit job before big new features. 
2. **Branch model needs permissions.** Thread sessions may only push to their assigned branch. Per-thread branches (C107) require the coordinator to assign them, and the Technical Director to merge each cycle; until then the single branch rule stays. Risk: half-adopted = worse collisions.
3. **Docs master vs mirror drift.** Master is /mnt/project-files/tech; MikeW reads docs/mirror. A stale mirror gives MikeW old rules. Fix: mirror after every doc change batch, mirror README states the date.
4. **Local-first = Dave's PC is a single point.** If his PC is off or MikeW is not running, no checks run. Fix: define a minimum cloud check (parse + python checks) as fallback and say so in PROCESS.
5. **Role digests not written yet.** The "read digest daily" rule (rv-bp-digest) starts with nothing to read. Fix: I write 6 digests before the first worker starts.
6. **Open naming.** "Sal_Crafts" appears in a review as Radar's role. Docs use Radar. Needs Dave's confirmation.
7. **Backups (C93) are a rule only.** No script, no first backup. Fix: MikeW takes the first store copy before the next bake.
8. **CI is not built.** C85 approved but gated; until then pre-push checks are by hand. Fix: add after MikeW proves scripts pass.
9. **Collapse safety.** Collapse code exists, switched off (build 646). Gate stays: second approval + Dave test card + 90 s warning. No change proposed; just a reminder it must not be enabled by a refactor.
10. **My own load.** Technical Director + Guru + merges + question page + daily check is a lot in one thread. Fix: priorities P0 to P3; merges every cycle; if backlog >5 items, tell the coordinator to pause new work.
11. **Ideas ledger depends on the coordinator logging every blurt.** If missed, ideas vanish. Fix: Dave can say "log that" explicitly; I check the ledger daily against chat.
12. **Estimates are guesses.** Token savings quoted in reviews are mostly unmeasured. Fix: measure once (tokens per thread start before/after the HANDOFF trim) and record in LESSONS.md.
