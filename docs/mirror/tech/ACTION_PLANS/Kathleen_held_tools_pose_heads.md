# Held tools: pose, saw shape, tool heads (Kathleen, 25 Oct)
From Mike's hands10 pictures (results/20261025_hands10). One branch claude/kathleen-held-pose, RUNTIME, three small commits:
1. Third-person pose in held_item.gd (_mount_model_third): tool out to the side and slightly forward, grip on the handle, head forward of the skull (today it slants back behind the neck, handle hidden behind the leg).
2. New "saw" shape in basic_look.gd (long thin toothed blade, pistol grip); looks.json hand_saw switches from "spade" to "saw" (data/items/looks.json one row; Sal owns the file, one-line change).
3. Better tool heads in basic_look.gd: axe/hammer chipped tapered stone with lashing; pickaxe swept head with two points.
Not mine: shore net and torch head (Sal). Tests: check_look_names, headless mesh build, David3 hand pictures again (K-set) and a QA look card.

Update 25 Oct: part 1 = commit 3af62551 (heads, saw, hammer). Part 2 (pose) = its own commit 1c089053 (third-person lean 78 deg, grip choke 0.6), revertable alone.
