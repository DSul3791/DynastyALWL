# Dynasty Independent Audit — Master Protocol

## Mission
Audit **Dynasty: A Life Well Lived** for documentation accuracy and concision, preservation of creator intent, architecture/code consistency, performance and visual specifications, and AI-agent usability. **Audit only; do not implement changes.**

## Absolute rules
- Treat `[Decided]`, `[Idea]`, `[Proposed]`, `[Open]` as distinct. Explicit creator-approved decisions are authoritative; AI proposals are not approvals. Consult discovered rejected/superseded decisions before proposing changes. Do not infer authority merely from document recency.
- Discover exact paths using `find_files` or equivalent before reading. Never guess a path, claim to read material that was not read, or fabricate line numbers/tests/performance measurements.
- Every significant finding must cite *project-relative path and actual line range*, explain evidence, uncertainty, consequence, suggested remedy, and whether creator approval is needed.
- Distinguish **verified fact**, **documented statement**, **conflict**, **inference**, **recommendation**, and **unknown**.
- Do not modify existing game files, documentation, configuration, scenes, assets, or Git history. Do not commit, switch branches, reset, push, or run game-mutating commands. Only create/update files under your assigned `audit_reports/<agent>/` directory.
- Do not evaluate `audit_instructions/` and `audit_reports/` as game-design documents. Treat their contents as operational instructions and generated outputs, respectively.
- Work in bounded batches; never attempt to load all files at once. For large documents, use headers and line-ranged reads and maintain coverage details. A directory listing is not a completed review.
- Re-read evidence when verification is needed. Do not exaggerate coverage or completion.

## Fixed workflow
Read this file, the assigned phase file, and your own `PROGRESS.md` at the start of each session. Only execute the assigned phase, and never proceed to the next phase without explicit user instruction. For an oversized phase, process one bounded batch and checkpoint before stopping.

## Outputs
Store all outputs under `audit_reports/qwen/` for Qwen, or `audit_reports/ministral/` for Ministral. Each model must not read the other model's results.

- `PROGRESS.md`: phase, completed batches, files *actually read* (with ranges for partial reads), pending work, errors, exact next batch; update after every batch.
- `INVENTORY.md`: discovered files, paths, categories, and coverage status (Phase 1).
- `AUTHORITY.md`: decision/authority map and unresolved ambiguities (Phase 2).
- `FINDINGS.md`: cumulative, uniquely numbered findings from Phases 3–5.
- `QWEN_ARCHITECTURE_AUDIT.md` or `MINISTRAL_ARCHITECTURE_AUDIT.md`: final consolidated report (Phase 6).

## Findings template
- **ID**: `DOC-001`, `ARCH-001`, `PERF-001`, `AGENT-001` (unique, do not reuse)
- **Category / severity**: Critical, High, Medium, Low
- **Status**: Verified / Documented / Conflict / Inference / Recommendation / Unknown
- **Evidence**: exact relative file paths and line numbers; precise excerpt or concise paraphrase
- **Issue / why it matters**
- **Suggested action** and **risk to creator intent**
- **Confidence** and **creator approval needed**: Yes/No

## Completion discipline
If a tool call fails, note the error in `PROGRESS.md`, inspect actual paths/permissions, and retry with a grounded path. Save findings and progress before ending the turn. Verify saved files by reading them back. End with concise counts and next action; never announce full completion when remaining work exists.
