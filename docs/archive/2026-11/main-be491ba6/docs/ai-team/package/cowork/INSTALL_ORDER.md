# Cowork configuration installation order (proposed)
**Status: STAGING, no automatic installation.**

1. Verify the actual Claude project experience (Cowork vs newer Code project threads), and current GitHub main SHA.
2. Install `cowork/PROJECT_INSTRUCTIONS.txt` as project-level instructions only after checking overlap with the project’s existing instructions.
3. Keep the first project chat as coordinator; provide `cowork/COORDINATOR_BOOTSTRAP.md` as its first task.
4. If account skill upload is available, enable the required `cowork/skill_uploads/*.zip` from Customize > Skills, confirm one test invocation. The ZIPs contain lower-case `skill.md`; Code agent skills remain separate under `.claude/skills/`.
5. Under reviewed, authorized repository staging PR, install `CLAUDE.md`, `.claude/agents/`, `.claude/skills/`, `docs/ai-team/`, and `tools/check_ai_team_package.py`; reconcile the stale `RULES.md`, repo `docs/START_HERE.md`, and `docs/DOC_MAP.md` in the **same implementation phase**, not later.
6. Update the Library `START_HERE.md`, and both document maps, preserving one master per topic.
7. Verify settings/branch protections/gates, and only then request activation. No feature development while the original handoff freeze is active.

The bootstrap must produce evidence of what was installed, NOT merely claim that instructions should work.
