# Concerns round 2: Tyler (Systems), 2026-10-22
Resolutions accepted for items 1, 2, 4, 5, 6, 7, 8, 9. Two things still do not work as written:
1. "Replace the pid-kill only if the pid's start time matches": GDScript cannot read another process's start time. Fix: drop the kill entirely once the handshake exists; the launcher waits for a closing server (note file) and otherwise shows the plain mismatch message. No kill, no wrong-process risk.
2. "Server is out of date, restarting": the client cannot restart a server it does not own (a friend's host). Wording must be "the server is out of date; close the game and press Play again" for a joined server, and the launcher may restart only the server it started itself.
3. Renumbering at merge means the HUD build in a thread's own test differs from the number later logged; Dave's reports will name the merged number. Fine if the merge line in BUILD_LOG names both ("was 640").
Otherwise: no concerns.
