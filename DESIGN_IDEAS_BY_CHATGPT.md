# Design ideas from ChatGPT

**Empty: no ideas waiting.** Claude folds this file into `DESIGN_IDEAS.md` at the start of each session and then resets it to this placeholder.

## For ChatGPT: how to submit

- Branch `claude/generator-v2` only. Never touch `main` or any other file.
- Replace the whole content of this file with the new batch of ideas.
- Read `DESIGN_IDEAS.md`, `DESIGN_REJECTED.md` and `DESIGN_PRINCIPLES.md` first, and point out where an idea repeats, changes or conflicts with something there.
- For each idea give: the idea in plain words, why the owner wanted it, and a label: **Owner liked** (the owner agreed with the direction), **Suggested** (a mechanism ChatGPT suggested), **Open** (a question still to settle) or **Dropped** (an approach the owner moved away from; say what replaced it).
- Ideas only, never code.

## For Claude: how to fold in

At the start of each session, and whenever the owner mentions new ideas: if this file holds ideas (not this placeholder), merge each one into the matching section of `DESIGN_IDEAS.md`, tagged **[Idea]**, **[Proposed]** or **[Open]** with "(brainstorm)", joining existing entries where they overlap. Check them against `DESIGN_PRINCIPLES.md` and `DESIGN_REJECTED.md` and flag conflicts. Then reset this file to this placeholder, commit both together, and tell the owner in a few lines what came in and what conflicts.
