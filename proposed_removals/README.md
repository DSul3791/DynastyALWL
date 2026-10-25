# proposed_removals: nothing is deleted without Dave's approval
Dave's rule (25 Oct 2026, 17:58 UTC): "Nobody deletes any messages, models or images anymore. If somebody decides not to use something, it has to go in a folder for approval."

How it works:
1. If you stop using a model, look, image, sound, art file, design doc, scene, resource or code file, you MOVE it here (keep its original path under this folder: `proposed_removals/<original path>`; scripts, scenes and resources get `.removed` added to the file name so Godot and the checkers do not load them) and add one line to REMOVALS.md: path, who, date, why, what replaces it.
2. Do not delete it from git, do not delete it from disk, do not remove it from the project files copy. Retired items keep their rows in items.json (numbers are never reused).
3. In data files (looks.json, structures.json, recipes) a look or row you stop using is marked retired or moved to a `retired` section, never deleted.
4. tools/merge_check.py fails a merge if a model, image, sound, art, design or look file is gone from the tree and not present here.
5. Dave approves removals in a card. Only after "Yes" does the Technical Director delete the file from this folder (it stays in git history).
