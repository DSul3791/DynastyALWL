---
name: ponytail-review
description: Quality review of a Dynasty change (diff, branch, PR or files) that reads the connected systems, not only the changed lines. Use for /ponytail-review, "review this", a self-check before requesting review, or as the gate reviewer's method.
---
# Ponytail Review (Dynasty)
**Scope:** review method, not an authority. Obey `docs/ai-team/CONSTITUTION.md`; engineering method is `docs/PONYTAIL_RULES.md`. Adapted from Ponytail v5.3.3 `skills/ponytail-review` (commit `7801d061`, MIT). **Auto-discovered by Claude Code from the repo; Cowork needs the account-uploaded copy.** Reads and reports; changes no code.

Review like the senior developer who will be paged when it breaks. Order: correct, safe, holds under real load, tested, fast, lean.

## 1. Understand first
- Review what is named; nothing named: uncommitted changes, else the last commit. Record the exact head SHA (the brief's SHA if you cannot run git).
- Read the diff, then what it touches: callers of every changed function, signals and scenes wired to it, data files, the tests, the approved design and decisions for the topic.
- Trace the real flow: client input, server authority, state, save/record, network messages, frame cost.
- When a signature, return value, message or data format changes, grep every caller and check `PROTOCOL.md`, save and record compatibility.
- Expected load: a multiplayer server with many players and NPCs/animals, clients at a frame budget (`ARCHITECTURE_BUDGET.md`). Say which load you assumed.

## 2. Look for
1. **Bug:** wrong result, crash, edge case (empty, zero, last item, chunk or tile edge, day/season rollover, rejoin), a caller broken by the change, a fix applied in one caller while shared code stays broken.
2. **Risk:** trusting client input, data loss (swallowed errors, writes in the wrong order, the water record or baked tiles touched), security.
3. **Scale:** fine for one player, wrong for many: per-frame or per-entity work that grows, lists that only grow, work every peer repeats, O(n^2) on entities, disk reads in a frame, oversized network messages.
4. **Missing test:** risky new logic or a bug fix with no test that fails when it breaks. One good test, not coverage. Note where it must run (PC lane), never run heavy Godot in the cloud.
5. **Speed:** big slowdowns are problems; small hot-loop wins are suggestions.
6. **Lean:** dead code, reuse (name the existing helper path), Godot built-in that already does it, a new dependency for a few lines, an abstraction with one use, near-copies, a function doing unrelated jobs.
7. **Fit:** the change contradicts an approved design, realism requirement, name (e.g. Foundation/Ceiling) or contract. Cite the source.

## 3. Check before you report
- Every finding needs a concrete case: "this input or situation leads to this wrong result". No case, no finding. Re-read the lines and confirm.
- A `shortcut:` (or older `ponytail:`) comment naming its limit is a decision, unless the expected load already crosses it.
- Something an approved design names is never "dead" or "yagni" by itself: say so and route it to `decision-provenance`.
- Propose the smallest fix that works; prefer fixes that delete code. Never propose cutting an approved feature, realism or a gate. No style taste, no vague worries.

## 4. Output
Plain short sentences. Start `What this change does:` in two or three sentences, with the head SHA.
Findings numbered across three groups, skip empty groups: **Must fix** (bug, security, data loss, breaks at expected load or a contract), **Should fix** (untested risky logic, real slowness, duplication, code that should not exist), **Nice to have**. Each finding: title (`path:line`), What this is, Problem, Fix, If we skip it.
End with:
- `Findings:` `none` or `fix <numbers> first`. This is advice to the author and gate; it is never a merge approval or a gate PASS.
- `Lean: -<N> lines possible.` when lean findings exist.
- `Not checked:` what mattered and could not be checked (tests NOT RUN, visuals, PC-only behaviour).
