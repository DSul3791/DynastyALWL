# Documentation cleanup checkpoint

Scope: preserve distinct designs and working records while reducing duplication. This is task state; DOC_MAP remains the design index and the existing rulebooks own process.

## Integrated phases

- Aging: PR #1183, dev bcdee5666bec5f7fadb4d418c9e14a264ea585c2. Preserved 18 passages and consolidated one repeat; review/static CI passed. Approval provenance and runtime aging remain unverified.

- Children/family: PR #1185 integrated at b8130aecd2d6325a772c065b9e73959953f3d64a; 20 passages preserved, independent review and exact-head static CI PASS. Concurrent audio delta leaves reviewed docs identical; final disposition in PR.

- Death/rescue: PR #1186 integrated at dbe793cbcbe04d2207a33e7fd8e2e1edbf266d13; independent review, preservation/link checks and final static CI PASS. Exact merged documentation verified.

- Succession/inheritance: PR #1189 integrated at 61cba95e7f41c0aa2528820835844f637262103b; independent review, preservation/link checks and final static CI PASS. Exact merged documentation verified.

## Current checkpoint

- Phase: NPC population and migration. Base: 61cba95e7f41c0aa2528820835844f637262103b.
- Scope: Extract §§8.2–8.3; retain distinct character/conversation plans and mark technical/roster snapshots as dated.
- Candidate: this commit's diff; exact head, reviewer, check results and final merge receipt are recorded in its linked GitHub PR. Do not infer integration from this draft checkpoint; inspect that PR and current dev.
- Checks: verbatim passage/unchanged-scope assertions, relative links/anchors, whitespace, independent non-author review and repository static CI before integration. Runtime/player verification is not supplied by documentation changes.
- Remaining sequence: death/succession; NPC population; property/town management/outposts/decline/founding; GUIDING_DOCUMENT; remaining-overlap triage; manual retirement eligibility; final consistency pass. Completed phases are listed above.
- Holds: unresolved approval sources stay SOURCE UNVERIFIED; distinct conflicting prescriptions stay visible for source review. No code/gameplay changes, main promotion, new schedules or automatic deletion.
