# Action plan: respawn at your own bed (R1b, list "respawn at own bed")

Branch: claude/steve-bed-respawn (cut from claude/steve-rough-bed 6459b079; needs the bed function). Build 792+, CHANGE_LABEL: RESTART (server rule + save field, no protocol change).

## What exists (checked in the code)
Per-player respawn is NOT new state after all: `respawn_for(peer)` (server_items.gd ~4580) already returns "just in front of their last shelter if it still stands, else the world spawn". The shelter is saved per character (`_characters[key]["shelter"]`, set by `_note_shelter` when a player rests near a structure with `"shelter": true`, e.g. the lean-to), and `_record_rest` keeps rest points. The death and cave-in paths already call `respawn_for`, send the point to the client (send_died) and say "You come back at your shelter". So the missing piece is only: a rough bed claims the respawn.

## What I build
1. **Claim.** First time a player is on a good bed (`on_good_bed(peer)`: lying on a placed rough_bed under cover) their character gets `bed: [x, y, z]` (the bed's position), replacing an older bed. One line: "You will wake here when you die." No button, nothing to open: lying down on it IS the claim (Dave: "claim a bed (sets respawn, needs cover)").
2. **Respawn order.** `respawn_for`: own claimed bed if it still stands (the world item exists at that spot, same 0.5 m test the shelter uses) and still has cover, then the shelter rule as today, then the world spawn. The player appears beside the bed (a metre along its yaw, like the shelter landing), not on it.
3. **A bed that is gone.** Removed or destroyed bed: the claim is dropped the next time it is looked up (fall back to shelter or spawn, one line "Your bed is gone"). Nothing can leave a player stuck: the fallback is always the world spawn.
4. **Sharing.** Anyone lying on a bed claims it, so two players can share one bed (no owner check in R1; a lock can come with the ownership plan).
5. **New player switch.** "Play as a new player" clears `bed` and `shelter` (they start from spawn again).
6. **Save.** `bed` goes in characters.json (a 3-number array, like `shelter`); `_load_characters` reads it (default empty, old saves unaffected).
7. **Numbers in data:** data/items/bed.json "respawn": {"landing_m": 1.2, "say_claim": "...", "say_gone": "..."}.

## Tests (test_bed_respawn.gd, in items_check)
No bed: spawn or shelter as today. Lying on a covered bed claims it. Death returns beside the bed. Bed removed: falls back, one line. Uncovered bed does not claim. New-player switch clears it. Save and reload keeps it. Old save without `bed` loads.

## Cost and risk
One saved array and one lookup at respawn. Risk: low. Not run in Godot in the cloud (Mike).

## Build notes (25 Oct, Tyler GO + two safety additions)
Built: `_claim_bed` (on lying down on a covered bed), `respawn_for(peer, dying)` order bed > shelter > spawn, `_bed_landing` (ring 1.2 to 3 m in 0.5 steps, 8 angles, needs ground, not inside a structure, falls back to the bed's own spot, never the void), third respawn inside bed.json respawn.window_s (600 s, max_in_window 2) falls through, claim dropped with one line when the bed is gone, `bed` saved and loaded, cleared by the new-player switch. Numbers in data/items/bed.json "respawn". Test: src/worldgen/tools/test_bed_respawn.gd (in items_check). Branch also merges steve-new-player (for the clear) so merge that first. Not run in Godot in the cloud.
