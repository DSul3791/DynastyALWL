# Ideas inbox

Design ideas from the owner's conversations with ChatGPT land here. Claude folds each file into `DESIGN_IDEAS.md` and then deletes it, so this folder is normally empty except for this README.

## For ChatGPT: how to submit

- Branch `claude/generator-v2` only. Never touch `main` or any other file.
- One new file per batch: `ideas_inbox/YYYY-MM-DD-short-topic.md`.
- Read `DESIGN_IDEAS.md`, `DESIGN_REJECTED.md` and `DESIGN_PRINCIPLES.md` first, and point out where an idea repeats, changes or conflicts with something there.
- For each idea give: the idea in plain words, why the owner wanted it, and a label:
  - **Owner liked:** the owner agreed with the direction.
  - **Suggested:** a mechanism ChatGPT suggested.
  - **Open:** a question still to settle.
  - **Dropped:** an approach the owner moved away from (say what replaced it).
- Ideas only, never code.

## For Claude: how to fold in

At the start of each work session, and whenever the owner mentions new ideas, check this folder. For each file:
- Merge every idea into the matching section of `DESIGN_IDEAS.md`, tagged **[Idea]**, **[Proposed]** or **[Open]** with "(brainstorm)". Join existing entries where they overlap.
- Check it against `DESIGN_PRINCIPLES.md` and `DESIGN_REJECTED.md`, and flag conflicts in the entry and to the owner.
- Delete the inbox file and commit both changes together.
- Tell the owner in a few lines what came in and what conflicts.
