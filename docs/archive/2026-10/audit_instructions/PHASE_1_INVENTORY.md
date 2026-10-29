# Phase 1 — Inventory
**Scope: file discovery only. Do not audit content or begin Phase 2.**

1. Confirm the working directory is the Dynasty project root (verify `project.godot`). Record read-only `git branch --show-current`, `git rev-parse HEAD`, and `git status --short`, when available. Do not change Git.
2. Recursively discover Markdown, `project.godot`, Godot scenes/resources, GDScript, shaders, C++ code, tests, and agent guidance (`AGENTS.md`, `CLAUDE.md`, etc.). Honor normal ignore rules unless needed to diagnose an apparent gap. Ignore `.git/`, imported/cache/build artifacts, `audit_instructions/`, `audit_reports/` for game-document counts.
3. Save exact relative paths in `audit_reports/<agent>/INVENTORY.md`. Categorize docs by purpose, flag huge docs, and mark all initially **Discovered, not read**. Do not count filename discovery as examination.
4. Create/update `audit_reports/<agent>/PROGRESS.md` with discovered counts, method, Git revision, limitations, and Phase 2 as the *pending* next phase.
5. Read back the files you wrote. Report counts, paths, and limitations, then **STOP**.

For Qwen, `<agent>` is `qwen`; for Ministral, `ministral`.
