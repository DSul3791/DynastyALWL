# The guiding document: how designs reach the game

**Last checked:** 2026-11-07 (Jamie). **Owner:** the coordinator. **Related:** [`docs/design/GUIDING_DOCUMENT.md`](../design/GUIDING_DOCUMENT.md), `DESIGN_IDEAS.md`, `DESIGN_PRINCIPLES.md`.

## Lessons (read these first)

1. **The guiding document is owned by the coordinator** (Dave, 7 Nov 2026). It sits above `DESIGN_IDEAS.md` and says how every design, old or new, becomes part of the game. Agents implement under it; they don't edit it without the coordinator.
2. **Proposals carry a G-id** (G-00, G-01, ...). Nothing tagged Proposal is built into the game until Dave reacts by ID ("yes G-04", "no G-07", "later G-10"). Docs and data preparation may go ahead.
3. **Decisions carry a D-id** (D-01, ...). They are the coordinator's calls under Dave's intent, applied now so work isn't blocked. Dave can overturn any by ID.
4. **Approved proposals fold into `DESIGN_IDEAS.md` as tagged items**, and the plan gains a task with an owner.
5. **Every design walks the same path:** idea, reaction, design doc, data before code, build, gate (David4), check in play (Dino), merge (Tyler), then the lesson goes here.

## What we tried

| When | What | PR | Result |
|---|---|---|---|
| 7 Nov | A first guiding document and plan from a thread Dave later removed | #539 | Closed, superseded |
| 7 Nov | The coordinator's guiding document, version 1 | #544 | Merged |
