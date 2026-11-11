# Source trail and assumptions (checked 11 Nov 2026)

Official Anthropic (recheck before deployment):
- https://code.claude.com/docs/en/memory — CLAUDE.md precedence and AGENTS.md selection. Root CLAUDE.md means AGENTS.md is not read by default; deliberately avoid AGENTS.md duplication.
- https://code.claude.com/docs/en/sub-agents — Claude Code `.claude/agents/*.md` definitions, independent contexts, model aliases, effort and permissions.
- https://code.claude.com/docs/en/skills — SKILL.md and scope; cloud Cowork loads account-enabled skills, not automatically local `.claude/skills` in repo-based project thread.
- https://code.claude.com/docs/en/best-practices — keep CLAUDE.md concise, use skills for procedures, enforce critical rules with permissions/hooks.
- https://code.claude.com/docs/en/agent-teams — Claude Code agent teams are experimental and distinct from Cowork's worker UI; do not assume cross-platform equivalence.
- https://support.claude.com/en/articles/14116274-organize-your-tasks-with-projects-in-claude-cowork — Cowork project context, instructions and memory; not Claude Code project setting.

User-provided authoritative inputs: 11 Nov 2026 final handoff report, uploaded Library START_HERE index, explicit approval of a nightly fully committed dev branch, main protected, ephemeral task workers, low interruption, morning backups subject to approval, freeze persists. GitHub read-only inspection: `DSul3791/DynastyALWL` files `docs/START_HERE.md`, `RULES.md`, `docs/DOC_MAP.md`, `docs/knowledge/README.md`, `ART_DIRECTION.md`, `DESIGN_REJECTED.md`, `docs/design/progression.md`.

**Unverified until Claude's implementation test:** exact Cowork worker lifecycle and session refresh; whether Cowork skills can be installed by file or require manual UI step; current Code CLI version on server; remote runner controls; full GitHub branch protections and checks; future post-handoff SHA changes; private Library content beyond pasted index; exact current model entitlements and pricing. This package intentionally avoids specifying unknown access, tokens-per-minute or automatic sync machinery.

GitHub main live verification on 11 Nov 2026: `ff650afb811088720ea3f046fbac128588a76821`, merge #1029, via GitHub repository read. No GitHub writes made.

Product-variant note: Claude project experiences were rolling out in November 2026; the exact UI may be older Cowork or newer Claude Code project threads. The package must be validated against the actual project session UI, not presumed. See https://support.claude.com/en/articles/9517075-what-are-projects and https://support.claude.com/en/articles/16761823-claude-cowork-and-chat-are-one-claude .

Skill packaging source: https://support.claude.com/en/articles/12512198-how-to-create-custom-skills (Cowork upload ZIP contains named skill folder with lowercase `skill.md`); https://code.claude.com/docs/en/skills (Claude Code uses uppercase `SKILL.md` in `.claude/skills`).
