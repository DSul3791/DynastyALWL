# A character starts where they left (resume spot)

**Asked by Dave, 15 Nov 2026 17:32Z (project thread "Save player location on quit"), verbatim:** "also when a character quits a game their location should be saved and thats where they should start the next time they log in."

## What dev did before this change (base 495baa74)
- The server wrote the spot to `characters.json` row `"last"` (`server_items._note_spot`): every 30 s while playing, and at leave with `left` = `deliberate` (the client sent `logout`: Quit game, window X / Alt+F4) or `disconnect` (anything else: editor Stop, crash, dropped line, kick).
- After `hello` the server sent `start_at` with that spot, but after a disconnect older than 120 s it sent the nearest rest or shelter point instead, else the world spawn (DECISIONS 2026-10-22 collapse-offline, point 3).
- **The bug:** `_load_characters` never read `"last"` (nor `"rests"`) back. Every server restart dropped the spot, and the Play button's own server stops 120 s after the last player leaves, so in practice almost every new session started at the world spawn. Only a rejoin to a server still running kept the spot.
- A server closing with players still in (admin stop, reset, `--quit-after`) did not write their spot; the last 30 s note stood.
- A joining client first reports from the world spawn before it moves to the resume spot; a periodic note in that window could save the world spawn as the spot.

## What it does now
1. `"last"` and `"rests"` are read back at load (malformed entries dropped). No save-format change: the same rows as before.
2. Every way of leaving resumes at the saved spot, with no time limit: Quit game, window closed, editor Stop, crash, dropped line, server stop. A new character (no `"last"`) still starts at the world spawn.
3. The spot is noted every 10 s while playing (was 30 s), at leave, and for every player still in when the server closes (`note_spots_on_close`). A hard kill of the server loses at most about 40 s (10 s note + 30 s save).
4. After the join, the spot is not overwritten until the client reports from within 8 m of the resume spot (or 120 s pass), so the reports still coming from the world spawn never replace it.
5. The server makes the spot safe before sending it (see choices below). The client sets the body down on arrival the way a first arrival does (no fall damage from a spot left in mid-air).
6. The `left` flag (deliberate / disconnect) is still written: the offline tunnel collapse (collapse-offline point 3, not built; tunnels have `"collapse": false`) needs it.

Code: `src/stream/server_items.gd` (`start_position_for`, `_safe_resume`, `note_spots_on_close`, `_clean_last`, `_clean_rests`), `scenes/terrain_server/terrain_server.gd` (`_resume_spot`, `_exit_tree`), `scenes/terrain_client/terrain_client.gd` (`_on_start_at`). Test: `src/worldgen/tools/test_resume_spot.gd`. Wire: `PROTOCOL.md` protocol 69 note (no protocol bump).

## For Dave (assumed on your behalf, values provisional; change any of them)
- **RS-1, disconnects resume in place too.** Your 15 Nov ask replaces the 22 Oct collapse-offline rule that sent a player who dropped for more than 2 minutes to their nearest rest or shelter point. Now a crash, editor Stop or dropped line resumes at the spot like Quit game. The deliberate/disconnect flag is kept for the future tunnel collapse rule.
- **RS-2, built over while away: a foundation.** The player stands on its top.
- **RS-3, built over while away: a wall or heavy station.** The player is moved to the nearest clear point within 6 m. With none, the nearest rest or shelter point; with none, their bed or the world spawn (the respawn rules). A player who stood against a wall (within 0.3 m) is not moved.
- **RS-4, head under water** (they left diving, or the water rose): they come up to the surface, swimming. A cave under a lake is not affected.
- **RS-5, mid-air** (left while falling, on a roof that was taken down, admin fly): set down on whatever is below on arrival with the usual few seconds of arrival protection, so no fall damage.
- **RS-6, inside the ground** (someone dug or filled the ground at the spot): no server change; the client's existing embed rescue lifts the body out, as it does for any player.
- **RS-7, death:** unchanged. A respawn still goes by the bed and shelter rules; the spot saved afterwards is wherever they then stand.

## Known limits
- Movement is client-authoritative in this game: the saved spot is the position the server last accepted from the client, written by the server. The server validates it (finite, made safe above); it does not re-simulate movement.
- An upper storey: if the floor's collider arrives after the ground, the arrival can set the body down to the floor below (the first-arrival rule). Not seen; noted.

## Not run / not played
Written in the cloud; no Godot ran here. Tests and the two-run resume smoke (`--resume-test=drop`, server restart, `--resume-test=check`) go to Dave's machines through the coordinator. Not played.
