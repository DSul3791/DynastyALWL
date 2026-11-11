# Ponytail v5.3.3 — install record
**Status: INSTALLED in repo on branch `claude/project-thread-utj0t5` (configuration only; game development freeze unchanged). In force once merged under the normal gates.** Authoritative method text: `docs/PONYTAIL_RULES.md`. This file records what was installed, where it works, what was left out and how to undo it.

## Brief (AI paraphrase of Dave's instruction; verbatim in the project thread "Integrate Ponytail into AI team", 11 Nov 2026 17:59 UTC)
Integrate Ponytail v5.3.3 into the AI Team OS; apply its philosophy across the coding team; it must never override approved designs, realism, architecture decisions or engineering standards; review installers and hooks before enabling; no competing rulebook; keep model assignments and workflow; iterate reviews; independent review; separate branch and PR; document rollback; no game development.

## Upstream used
- `https://github.com/DietrichGebert/ponytail`, tag `v5.3.3` = commit `7801d061243d7b753bad0e0b3c057cd250b11755` ("chore: release v5.3.3 (#1307)", 29 Oct 2026). Verified by `git clone` + `git ls-remote` (annotated as a plain commit tag); it was the newest tag on 11 Nov 2026. The release web page and GitHub API were not readable from this session, so release notes were not read.
- License MIT (Copyright 2026 DietrichGebert); adapted text keeps attribution in each file.
- SHA-256 prefixes of the upstream sources adapted: `skills/ponytail/SKILL.md` 9badd22a32e19cb8, `skills/ponytail-review/SKILL.md` 33fe4ebe22a46092, `skills/ponytail-audit/SKILL.md` 2b3223a02c386d12, `skills/ponytail-debt/SKILL.md` b5ec2762f6ba8c4a.

## What upstream ships, and what we did with it
| Upstream part | Decision | Why |
|---|---|---|
| `skills/ponytail` (mode skill, lite/full/ultra) and `AGENTS.md` | **Adapted** into `docs/PONYTAIL_RULES.md` (one master) | Same rules, plus Dynasty precedence, Godot ladder, never-cut list, test restrictions. Levels dropped: "ultra" pushes back on the request itself and could shrink approved designs; "lite" adds nothing we need. `AGENTS.md` stays omitted (`CLAUDE.md`). |
| `skills/ponytail-review` | **Adapted** to `.claude/skills/ponytail-review` | Kept its method (read connected code, concrete cases, smallest fix). Added multiplayer/frame-budget load, contract and design-fit checks, "never call approved design dead", NOT RUN handling; final "Ship" replaced by `Findings:` because only the gate approves. |
| `skills/ponytail-audit` | **Adapted** to `.claude/skills/ponytail-audit` | Same, plus `.tscn`/data/dynamic-reference grep before "unused", provenance check, report-only to backlog. |
| `skills/ponytail-debt` | **Adapted** to `.claude/skills/ponytail-debt` | `shortcut:` already in use (7 code markers at install). Grep simplified to `git grep` (skips ignored water record/worlds). |
| `skills/ponytail-gain`, `ponytail-help` | Not installed | Benchmark display and plugin help; no value in our workflow. |
| Claude Code plugin (`.claude-plugin/`, `/plugin install ponytail@ponytail`) with hooks `SessionStart` (`ponytail-activate.js`), `SubagentStart` (`ponytail-subagent.js`), `UserPromptSubmit` (`ponytail-mode-tracker.js`) and the band module | **Not enabled** | Reviewed source at the pinned commit. No network call except the opt-in band webhook. But: SessionStart injects the stock unadapted ruleset into every session and SubagentStart into **every** subagent (incl. `art-reviewer`, `doc-steward`, `gameplay-designer`), a second rulebook outside our precedence; activation tells the model to "proactively offer" editing `~/.claude/settings.json` for a statusline; band writes a cost ledger under `~/.config/ponytail/` and imports past transcripts; the codebase map does not read `.gd` files (its source regex has no GDScript), so it adds nothing for Godot; plugin auto-update would run new third-party code unreviewed; needs Node on PATH. |
| Adapters for Codex, Cursor, Copilot, Gemini, OpenCode, Kiro, etc.; `benchmarks/`, `tests/`, `scripts/` | Not installed | Not our environments. Nothing from upstream was executed. |

## Where it works
| Environment | How it gets Ponytail | State |
|---|---|---|
| Claude Code project threads (cloud, this project) | `CLAUDE.md` pointer; repo `.claude/skills/ponytail-*`; agent definitions | **OBSERVED**: the three skills appeared live in the installing session as soon as the files were written. Subagent preload of `ponytail-review` in `gate-reviewer`: see validation. |
| Claude Code on Dave's PC (CLI/desktop Code tab) | Same repo files after `git pull` of the merged branch | NOT VERIFIED (no local run from this session). |
| Cowork / Claude chat projects without the repo | Upload `docs/ai-team/package/cowork/skill_uploads/ponytail-*.zip` as account skills; method text via repo or Library copy | NOT VERIFIED; optional. Skills there are invoked by name, and they cite repo paths, so they need repo access to be fully useful. |

Agents: `systems-engineer`, `terrain-water`, `task-investigator`, `item-data` follow `PONYTAIL_RULES.md` and self-review with `ponytail-review`; `gate-reviewer` preloads `ponytail-review` as its method (read-only tools unchanged). `art-reviewer`, `doc-steward`, `gameplay-designer` are unchanged: Ponytail is a coding method, not a limit on design ambition. Models, efforts, roles and branch flow unchanged.

## Changes to the existing OS
`CLAUDE.md` (one sentence), `docs/PONYTAIL_RULES.md` (rewritten, scope water -> all code), `docs/ai-team/WORKFLOW.md` (workday sentence), `EVALUATION_CASES.md` (cases 16-20), `AUDIT_MATRIX.md` (one row), `INSTALL_RECORD.md` (pointer), `docs/START_HERE.md`, `docs/DOC_MAP.md` (index lines), `package/cowork/PROJECT_INSTRUCTIONS.txt` (one sentence), five agent files, three new skills + ZIPs, `tools/check_ai_team_package.py` (10 skills; ZIPs equal repo skills; Ponytail pin/precedence; fails if `.claude/settings.json` gains `hooks`, `enabledPlugins` or `extraKnownMarketplaces` without a reviewed check change).

## Validation and review (11 Nov 2026, cloud project thread; no Godot, nothing from upstream executed)
- PASS: `python3 -I tools/check_ai_team_package.py` (19 core files, 8 agents, 10 skills, ZIPs equal repo skills, Ponytail pin/precedence, no hooks/plugins/MCP in shared settings or frontmatter). Negative checks made it FAIL as intended: stale ZIP, `enabledPlugins` in settings, gate-reviewer without the preload, `hooks:` in an agent's frontmatter. `tools/check_doc_links.py` 0 dead links; `tools/merge_check.py` all clear.
- OBSERVED: the three skills were offered live in the installing session right after the files were written; `/ponytail-debt`'s grep found the 7 existing code markers.
- NOT VERIFIED: `skills:` preload in `gate-reviewer`. Agent definitions are read at session start, so the reviewer spawned in the installing session still ran the old file; the gate-reviewer text now also tells it to read the skill file if the preload is missing. Check in the first session after merge.
- Review iterations: (1) self-review fixed precedence wording ("items 1-5" contradicted Dave's approval), adapted text labelled as not a Dave quote, YAGNI vs approved planned stages, performance measure-first, a checker regex that a body mention could satisfy. (2) Independent `gate-reviewer` (FAIL, 11 findings) and a `systems-engineer` scenario run (water, wildlife, bug fix, performance, gameplay; 9 wording points). Fixed: vague *design* goes to Dave not shrunk (`RULES.md`); "deletion" limited to replaced code, unused files to `proposed_removals/`; shared-code fixes that change designed behaviour become level B/C; new dependency/native code needs Dave; network only via `terrain_net.gd`; untestable fixes name their human/PC check; perf unmeasured cannot pass `main`; reading scaled to change size; `unmeasured risk` findings; only Must-fix or missing evidence fails a gate; frontmatter-scoped checks. Not changed: the PROPOSED banners in older OS files (pre-existing; `INSTALL_RECORD.md` already states what is in force). (3) Independent re-review at `806fdf44` (FAIL, 3 findings): Must-fix list widened to design contradictions, unapproved big changes and required tests so the gate cannot pass them; MCP keys added to the checker; engineer agents given the read-the-file fallback. (4) Final re-review: see PR.

## Rollback
- Nothing runs in the background (no hooks, no plugin), so disabling is just removing the files by the revert below.
- Revert: one reviewed PR that reverts this branch's commits (`git revert <sha>...`, no force push). That restores the 31 Oct `PONYTAIL_RULES.md`, the 7-skill checker and the old agent files. Cowork: remove the three `ponytail-*` account skills if uploaded.
- If someone later installs the upstream plugin anyway: `/plugin uninstall ponytail@ponytail`, `/plugin marketplace remove ponytail`, and remove `~/.claude/.ponytail-*` flags and `~/.config/ponytail/`.

## Upgrading Ponytail later
Clone the new tag, diff its four source skills against the hashes above, port only what fits `PONYTAIL_RULES.md`, update the commit pin in the rules, skills and checker, regenerate ZIPs, and run the same independent review.
