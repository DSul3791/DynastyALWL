# Documentation authority, provenance and synchronization
**Status: IN FORCE (activated by Dave, 12 Nov 2026; `INSTALL_RECORD.md`). Drafted as PROPOSED.**

## Do not confuse documents with approvals
The repo `docs/START_HERE.md` is the engineering entry point; `docs/DOC_MAP.md` is the current topic navigation map (refreshed 13 Nov 2026). Project-file handoffs, when accessible, provide provenance and task context; their availability is not required to resolve current repository authority. Authority is **per topic and decision**, not 'everything in the newest file'. For items, `docs/design/DYNASTY_MASTER_ITEMS.md` and the feature specifications linked in `DOC_MAP.md` define the approved target; `data/items/*.json` and code show actual implementation. Record disagreements without treating old runtime data as authority to cancel newer creator decisions.

**Decision provenance fields** (new entries): ID; topic; verbatim human instruction or permalink/recording if available; AI interpretation separate; selected choice; status (DIRECTOR-APPROVED / DELEGATED / PROPOSED / REJECTED / SUPERSEDED / NEEDS-REVIEW); who decided; date; scope; exceptions; supersedes; affected docs, code and tests. If original source cannot be recovered, mark SOURCE UNVERIFIED. Don't fabricate quotes.

**Change process:** Find source → read the most relevant active spec and decision history → reconcile contracts and rejected ideas → draft minimal change → independent documentation review → update authoritative document and index → sync/copy to second location → verify exact contents/hash and reference the commit or storage receipt. If the Library cannot be written from the current environment, record `SYNC PENDING`; never claim completion.

**One master per topic:** repo is master for version-controlled design, interface and code docs as listed in handoff; Library is master for ephemeral handoffs/status and private artifacts unless explicitly migrated. Avoid editing two masters. Keep historical docs for explanation with an unmistakable banner, not as active instructions. Discard accidental restrictions only after provenance review. Rejected proposals remain accessible.

**Strong words audit:** Always, never, only, forbidden, must, cannot should have traceable basis. Classify as (a) verified human decision; (b) physically necessary technical constraint; (c) security requirement; (d) AI recommendation; (e) unexplained paraphrase. Only (a)-(c) become hard constraints without further approval. The QA page is for real human-facing uncertainties and look checks, not a dumping ground for technical questions agents can answer.

**Resolved branch conflict:** current practice is task branches from `dev` → reviewed nightly `dev` → gated `main` with Dave's explicit approval. The older no-daily-branch and routine-unapproved-main-promotion wording is retired. `KNOWN_CONFLICTS.md` and dated install records explain history, not alternative operating rules.

**13 Nov creator-directed cleanup:** replace obsolete instructions directly in active documents after recording their current replacements. Preserve necessary dated audit/migration evidence and Git history; do not accumulate competing old/new rule blocks. Cleanup status and remaining runtime mismatches: `docs/design/DOCUMENT_CONTRADICTIONS_RECONCILED_2026-11-13.md`.
