# Protocol-only bots (Tyler_002, 2026-10-22)
Run from the repo root: `tools/bots.sh BOTS SECONDS [DIG_EVERY_S]` (set GODOT=path if `godot` is not on PATH).
It starts a headless server on a spare port, then BOTS headless players from `scenes/bot/bot_main.tscn`. Each bot joins (hello + welcome), walks at 3.2 m/s in a random heading, reports its position 5 times a second, asks for the 5 x 3 x 5 blocks around it whenever it enters a new block, and optionally sends a dig action every N seconds. It prints its heartbeat gaps and block waits, and the script prints the server's worst frame gap from telemetry.
Limits: blocks come by RPC (the real client also has the block line on port+1); bots dig without a spade so the server refuses the dig (it still pays the action path); no inventory, crafting, NPCs or water requests yet.
First numbers (4-core test box, bots and server on the same machine, 60 s, dig every 2 s, all bots spawn together at the starter tile):
- 3 bots: server worst frame gap 50 ms, heartbeat gap 273 ms worst.
- 15 bots: server worst frame gap 60 ms over 103 s; every bot got about 1,100 to 1,400 blocks (1.2 to 1.6 MB); block wait median 28 to 55 ms; 14 of 15 bots had p95 under 130 ms once the first joiners had warmed the ground; the first joiners saw 2 to 4 s waits for cold ground; worst heartbeat gaps 490 to 760 ms (some of that is the bots competing for the same 4 cores).
- Verdict: 15 players near each other cost the server no visible stall; cold ground generation is the only wait.
