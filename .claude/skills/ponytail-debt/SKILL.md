---
name: ponytail-debt
description: List every `shortcut:` comment (and older `ponytail:` ones) in the Dynasty repo as a debt ledger. Use for /ponytail-debt, "list the shortcuts", or when a handoff or plan needs the deferred limits.
---
# Ponytail Debt (Dynasty)
**Scope:** report method, not an authority. Convention defined in `docs/PONYTAIL_RULES.md`. Adapted from Ponytail v5.3.3 `skills/ponytail-debt` (commit `7801d061`, MIT). **Auto-discovered by Claude Code from the repo; Cowork needs the account-uploaded copy.** Reads and reports; changes nothing.

## Scan
From the repo root: `git grep -nE '(#|//|/[*]) ?(shortcut|ponytail):'` (GDScript and Python use `#`, shaders and C++ in `native/` use `//`). `git grep` already skips ignored files (water record, baked worlds). If a marker word is named (`/ponytail-debt TODO`), grep for that instead. Skip hits that are not deferrals, such as docs that only describe the convention (`docs/PONYTAIL_RULES.md`).

## Output
One row per marker, grouped by file: `<file>:<line>, <what was simplified>. limit: <the limit>. revisit: <the trigger>.` Tag rows with no revisit trigger `no-trigger`. Owner if needed: `git blame -L<line>,<line>`.
End with `<N> markers, <M> with no trigger.` and the SHA scanned. Nothing found: `No shortcut debt.`
To keep it, write the ledger only where the task brief says (for example the task handoff).
