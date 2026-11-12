# Documentation authority, provenance and synchronization
**Status: IN FORCE (activated by Dave, 12 Nov 2026; `INSTALL_RECORD.md`). Drafted as PROPOSED.**

## Do not confuse documents with approvals
The Cowork Library `START_HERE.md` is the navigation map. The repo `docs/START_HERE.md` is the engineering entry point. Authority is **per topic and decision**, not 'everything in the newest file'. Resolve the authoritative topic document using `/mnt/project-files/handoffs/DOC_AUDIT_11Nov.md`, `docs/DOC_MAP.md` when refreshed, and `design/decisions_pending.md` for the 85 historical rulings. For current item mechanics, repo `data/items/*.json` is implementation truth; `docs/design/item_system.md`, `progression.md`, and `buildables_plan.md` state intended design. Code and documents can disagree—log mismatch; do not silently make the code authoritative over creative intent.

**Decision provenance fields** (new entries): ID; topic; verbatim human instruction or permalink/recording if available; AI interpretation separate; selected choice; status (DIRECTOR-APPROVED / DELEGATED / PROPOSED / REJECTED / SUPERSEDED / NEEDS-REVIEW); who decided; date; scope; exceptions; supersedes; affected docs, code and tests. If original source cannot be recovered, mark SOURCE UNVERIFIED. Don't fabricate quotes.

**Change process:** Find source → read the most relevant active spec and decision history → reconcile contracts and rejected ideas → draft minimal change → independent documentation review → update authoritative document and index → sync/copy to second location → verify exact contents/hash and reference the commit or storage receipt. If the Library cannot be written from the current environment, record `SYNC PENDING`; never claim completion.

**One master per topic:** repo is master for version-controlled design, interface and code docs as listed in handoff; Library is master for ephemeral handoffs/status and private artifacts unless explicitly migrated. Avoid editing two masters. Keep historical docs for explanation with an unmistakable banner, not as active instructions. Discard accidental restrictions only after provenance review. Rejected proposals remain accessible.

**Strong words audit:** Always, never, only, forbidden, must, cannot should have traceable basis. Classify as (a) verified human decision; (b) physically necessary technical constraint; (c) security requirement; (d) AI recommendation; (e) unexplained paraphrase. Only (a)-(c) become hard constraints without further approval. The QA page is for real human-facing uncertainties and look checks, not a dumping ground for technical questions agents can answer.

**Existing conflicts must be migrated:** `docs/START_HERE.md` says there is NO daily branch; `RULES.md` mentions legacy daily branches and a different main merge practice; new approved practice is task branches -> `dev` nightly -> gated main. See `KNOWN_CONFLICTS.md` and `MIGRATION_PLAN.md`; don't declare all three authoritative at once.
