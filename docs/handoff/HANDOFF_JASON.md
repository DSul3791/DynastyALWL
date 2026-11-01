# Handoff: Jason "Champ" (audio), 1 Nov 2026

Scope: `SCOPE_JASON.md`. Backlog with owner, next step and reason: `JASON_NEXT_TASKS.md`. Sound map and hook audit: `docs/SOUND_MAP.md`. Findings record: `SOUND_AUDIT.md` (repo root). Branch `claude/jason-audio-8366e4`.

## State
- All ten old Kathleen sound branches and the Steve sound branches are in the daily (checked with `git cherry`); the place sounds (stone, brick, thatch) and the shovel scoop (soil, stone) were ported from `kathleen-materials` and `kathleen-spades` (commits `583e1312`, `9f9db474`). `_fill_here()` in `held_item.gd` now plays the scoop.
- `test_slot_sounds` passes on the voxel build `godot.windows.editor.x86_64.exe` (a fresh worktree needs one `--import` first). `test_sound_log`: first run failed only for missing imports; rerun after the import is in `JASON_NEXT_TASKS.md` row 1 if not reported otherwise.
- Nothing has been heard by anyone: every sound claim in these documents is read from code.

## Remaining hooks (full table in JASON_NEXT_TASKS.md)
Sleep and wake, hurt/death/respawn, bow and arrow, fishing, animal hit/death/eating, clothing, craft action, level-up/goal/hint: the client has no event to hang a sound on yet, so each waits for its owner (Steve, MikeW, Sonny) to expose one; then I place the call. Stone, brick and thatch place sounds wait for Sal's `sound` keys in `structures.json`.

## Risks
Licence record has TODOs (Pixabay page URLs; no rows for the voice files). The tree-wind hiss in clear weather is unconfirmed. The QA page cannot play audio yet.
