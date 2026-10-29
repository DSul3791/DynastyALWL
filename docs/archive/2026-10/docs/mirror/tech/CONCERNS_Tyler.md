# Concerns: Tyler (Systems), 2026-10-22 (triple check)
1. Splitting terrain_client.gd (my job): 5,200 lines, signals and preloads cross-wired. Risk: a silent break only a running client shows. Plan: BUILD const first, then ONE feature per build (rescue, link bars, join window), each checked by MikeW's headless run, not the cloud alone. Never while another thread has a pending client change.
2. next_build.sh race: two threads can print the same number in the same minute. Fix: the script appends a "reserved" line to BUILD_LOG and pushes it first (or the Technical Director numbers at merge, as C107 says).
3. My 621 launcher kills the server by the pid in user://server_run.json. Risk: after a reboot the file survives and the pid can belong to an unrelated program that happens to run while the port is held by something else. Low but real. Safer: the build-id handshake plus a quit request to the old server; keep the kill only if the pid still has the same start time. I propose to replace the kill in the handshake build.
4. Build-id handshake: a refuse on mismatch must treat "no .git / empty id" as a match (exports, Dave's copies), and must show a plain message, never a silent drop.
5. Two rescues exist (Willy's rock rescue 625, my void rescue 644). Same owner needed; plan to merge into src/client/rescue.gd during the split.
6. Under-the-world cause is still unknown (not reproduced). Rescue hides it; the RESCUE telemetry line must stay so we can see how often it fires.
7. Compaction is ON by default (kill switch settled_ground). If slabs or odd collisions return, flip to 0 first; nothing else changes.
8. Cloud headless runs flake on a cold server (three tests fixed, more may exist). Gate decisions must come from MikeW's run, not a single cloud pass.
9. "Questions pickable only": bugs needing free text still have no path; propose a "describe it" option on the card that routes to the thread.
10. Restart discipline: server-side builds (614, 621, 632) need a server restart; the build log says so, but Dave's HUD does not show a server build. Propose showing the server commit on the F3 line.
