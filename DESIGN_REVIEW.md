# Design Review (2026-10-14)

A read-through of every design document: `DESIGN_IDEAS.md`, `WORLD_FORMAT_SPEC.md`, `GENERATOR_V2_PLAN.md`, and the four older files. The spec was also checked against the generator code. After the review, the project owner decided how to handle the findings; this file records what was found and what was done. The open items live in `DESIGN_IDEAS.md` Section 15, questions 64 to 85.

Rule applied: when two statements disagree, the newest one from the project owner wins.

## Fixed

**Permanent format (`WORLD_FORMAT_SPEC.md`)**

- The old rule that every tile edge drops to a shared deep-ocean floor is removed from the spec, from the plan, and from the code (`ocean_edge_floor_m` setting). Neighboring tiles agree because they read the same world data. 798 checks still pass.
- Tile IDs: a record's identity is its home tile and local ID. The revision is only a cache marker. IDs are unique per kind of record. Records added by later resource passes use local IDs from pass number × 10,000 (question 82).
- File size: corrected to 14 bytes per sample, about 52 MB per tile before compression. There is no size limit; efficiency is a standing goal.
- New Section 4a: resource passes, a safe way to add ores and resources after tiles are kept. New Section 4b: rivers continue across tile edges, overlap margins, wrap-seamless noise, and a final edge-matching pass. New plan step 13b.
- The 65-line superseded tile matrix block and the old workflow and decisions text are replaced.

**Contradictions (newest wins)**

- One final world size (21 by 21). The center island is a desert everywhere (it is now the "ultimate island"). Flora is runtime everywhere. Receivership is real time. Hostile takeover depends on an established town, not on guards. Heirs: one chosen successor inherits everything.
- The "grow one row at a time" plan is marked superseded by the full world with placeholder ocean tiles.
- Stale or editorial text removed: the "new idea" heading and "Checked" paragraph in 8.12, "(name to be chosen)" for the mail role, and the header and revision history (Version 7 added).

**Duplicates and structure**

- Starter town duplicates, duplicate danger statement, duplicate mail and word rules, duplicate real-money bullets, old subscription ideas (now marked superseded) and duplicate paid-duress mentions.
- Section 8.13 reordered into groups; Section 8.12 split so the sale of server-owned towns is its own Section 8.16; 6.8 and 6.9 swapped into order; question 63 placed in order; the stray business bullet moved to 13.4; the crucible decision moved next to the resource list.
- Open questions that were answered (ore renewal, ruins, failing towns, will and successor, map growth, final height) are marked settled.
- Sections 14 (code status) and 16 (work order) rewritten.
- The four older files carry a note that they describe the old generator.

**New content from the project owner**

- Geology list review (Section 4.9a), the ultimate island (Section 4.13), and remains of the dead (Section 6.1).

## Still open

All in `DESIGN_IDEAS.md` Section 15, questions 64 to 85. The biggest are the aging clock (64), one clock per system (65), the town block and its circle of influence (66 and 67), and what "established" means (68).
