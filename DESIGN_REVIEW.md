# Design Review (2026-10-14, after cleanup)

The design documents are `DESIGN_IDEAS.md` (the game design), `WORLD_FORMAT_SPEC.md` (the permanent tile format) and `GENERATOR_V2_PLAN.md` (the build steps and progress). The four older files (`README.md`, `GENERATION_GUIDE.md`, `PROJECT_ROADMAP.md`, `CHANGES_THIS_PASS.md`) describe the old generator and are untouched until the new one replaces it.

Rule applied: when two statements disagree, the newest one from the project owner wins.

## What the cleanup did

- Removed every superseded rule and the stale notes about them (old subscription ideas, two clocks, old takeover windows, fixed expansion fees, random choice of successor, transfer tax, and similar).
- Made game time the default for any unlabeled time, and labeled real-time items (Section 7.1).
- Regrouped succession and inheritance into one section with four parts (Section 6.7).
- Made PvP zones lawless (Section 9.0) and spelled out the two roads to an abandoned town (Section 8.13).
- Reduced Section 15 to genuinely open items only, with suggestions where numbers are needed.
- Updated code status (800 checks, 11 rock types including tuff), terminology and revision history.

## Still to do

- Approve the settlement stage names (proposed in the chat).
- Money scale: balance the value of time spent against prices later.
- Step 13: the tile file writer and reader for the starter tile (3,4).
