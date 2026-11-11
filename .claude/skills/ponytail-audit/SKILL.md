---
name: ponytail-audit
description: Report-only quality audit of a Dynasty folder, system or the whole repo (bugs, risk, scale, untested risky code, slow paths, what could be cut). Use for /ponytail-audit or when the coordinator or Dave asks for a codebase or system audit.
---
# Ponytail Audit (Dynasty)
**Scope:** audit method, not an authority. Obey `docs/ai-team/CONSTITUTION.md`; engineering method is `docs/PONYTAIL_RULES.md`. Adapted from Ponytail v5.3.3 `skills/ponytail-audit` (commit `7801d061`, MIT). **Auto-discovered by Claude Code from the repo; Cowork needs the account-uploaded copy.** One-shot report; changes nothing. Findings become backlog proposals, not edits.

Audit like the senior developer who just inherited the code. Order: correct, safe, holds under real load, tested, fast, lean.

## 1. Map first
- Audit what is named (folder, system, whole repo). Record the SHA audited.
- Read `docs/START_HERE.md`, the topic docs in `docs/knowledge/` and the approved design for that system, the entry points (scenes, autoloads, server handlers, `tools/`) and the tests.
- Expected load: multiplayer server with many players and NPCs/animals, clients at a frame budget (`ARCHITECTURE_BUDGET.md`). Say which load you assumed.
- Trace the main flows end to end: client input, server authority, state, saves/SQLite, water record and baked tiles, network messages.
- Big area: go deep where a mistake costs most; say what you did not read.

## 2. Look for
Same six kinds as `ponytail-review` (bug, risk, scale, missing test, speed, lean) plus **fit**: code that contradicts an approved design, name or contract. For lean: dead code, two helpers doing one job (name both paths), a Godot built-in or installed addon that already does it, one-implementation abstractions, near-copies, functions mixing jobs.

## 3. Check before you report
- Every finding needs a concrete case. No case, no finding.
- Before calling code unused, grep the whole tree, including tests, scenes (`.tscn`), data JSON, tools, string and dynamic references (`call`, `get_node`, signals by name).
- Something an approved design names is never dead or yagni by itself; mark it `provenance check` instead.
- A `shortcut:` comment naming its limit is a decision unless the expected load crosses it.
- Smallest fix; prefer deletion (replaced code is deleted, documents archived). Never propose cutting an approved feature, realism or a gate.

## 4. Output
Plain short sentences. Start `What this area does:` and the load assumed. Findings numbered across **Must fix**, **Should fix**, **Nice to have**; at most 20, say how many smaller ones were left out. Each finding: title (`path:line`), What this is, Problem, Fix, If we skip it.
End with `Verdict:` (healthy, or what to fix first), `Lean: -<N> lines, -<M> dependencies possible.` when relevant, and `Not checked:`.
