# Documentation cleanup checkpoint

Scope: preserve distinct designs and working records while reducing duplication. This is task state; DOC_MAP remains the design index and the existing rulebooks own process.

## Integrated phases

- Aging: PR #1183, dev bcdee5666bec5f7fadb4d418c9e14a264ea585c2. Preserved 18 passages and consolidated one repeat; review/static CI passed. Approval provenance and runtime aging remain unverified.

- Children/family: PR #1185 integrated at b8130aecd2d6325a772c065b9e73959953f3d64a; 20 passages preserved, independent review and exact-head static CI PASS. Concurrent audio delta leaves reviewed docs identical; final disposition in PR.

- Death/rescue: PR #1186 integrated at dbe793cbcbe04d2207a33e7fd8e2e1edbf266d13; independent review, preservation/link checks and final static CI PASS. Exact merged documentation verified.

- Succession/inheritance: PR #1189 integrated at 61cba95e7f41c0aa2528820835844f637262103b; independent review, preservation/link checks and final static CI PASS. Exact merged documentation verified.

- NPC population/migration: PR #1190 integrated at 7311ee19374bdb5f0d369e92aee25db11f365e42; independent review, preservation/link checks and final static CI PASS. Exact merged documentation verified.

- Property/town management: PR #1191 integrated at 8516664b13661113d5f7bf2bfac481d296d14266; independent review, preservation/link checks and final static CI PASS. Exact merged documentation verified.

- Founding/settlement construction: PR #1192 integrated at c5dcfdc3cf91580aa6bbf8a5870b8ae8ce62769e; independent review, preservation/link checks and final static CI PASS. Exact merged documentation verified.

## Current checkpoint

- Phase: Outposts and settlement decline. Base: c5dcfdc3cf91580aa6bbf8a5870b8ae8ce62769e.
- Scope: Extract §§8.10 and 8.13 with category labels, numeric tables and distinct decline/deletion/claim exceptions.
- Candidate: this commit's diff; exact head, reviewer, check results and final merge receipt are recorded in its linked GitHub PR. Do not infer integration from this draft checkpoint; inspect that PR and current dev.
- Checks: verbatim passage/unchanged-scope assertions, relative links/anchors, whitespace, independent non-author review and repository static CI before integration. Runtime/player verification is not supplied by documentation changes.
- Remaining sequence: death/succession; NPC population; property/town management/outposts/decline/founding; GUIDING_DOCUMENT; remaining-overlap triage; manual retirement eligibility; final consistency pass. Completed phases are listed above.
- Holds: unresolved approval sources stay SOURCE UNVERIFIED; distinct conflicting prescriptions stay visible for source review. No code/gameplay changes, main promotion, new schedules or automatic deletion.
