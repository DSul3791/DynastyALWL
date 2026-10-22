# Crafting queue (Dave 2026-10-20: like Ark; click an entry to cancel)

## What
Crafts line up in a server-side queue per player and run one after another. The crafting screen shows the queue (item name, count, time left for the one in progress). Clicking an entry cancels it. The queue keeps running with the screen closed.

## Rules
- Ingredients are taken when a craft is QUEUED (all of an entry's count at once). Cancelling any entry, the running one included, refunds that entry's unfinished crafts in full (items that do not fit go to the ground at the player's feet). Finished crafts are never refunded.
- Cap: 10 entries per player, 20 crafts per entry. Queueing the same recipe again adds to the last entry if it is the same recipe and not yet running.
- Runs only while the player is connected (like hunger). Progress of the running craft is kept across a restart and a reconnect.
- Craft time per recipe from recipes.json (craft_s); each finished craft is given with the normal give() path (full pack: drops at feet).

## Protocol 21 to 22
- ACT_CRAFT_QUEUE (21): a = recipe number, count = how many (1 to 20). Server checks known recipe, reach of station (none yet), ingredients, cap; takes ingredients; appends or merges; answers with craft_queue().
- ACT_CRAFT_CANCEL (22): a = queue entry index (as last sent). Refund as above; answers with craft_queue().
- RPC craft_queue(entries: Array, left_ms: int), server to client, reliable, sent on every change (queue, cancel, a craft finishing) and at hello. entries = [[recipe number, crafts left], ...] head first; left_ms = time left on the head craft. The client counts down locally; no per-second traffic.
- ACT_CRAFT (4) stays for old callers and tests (instant craft, unchanged); the Craft button uses the queue.

## Save format
craft_queues.json (server store, version 1, atomic write, unusable file kept as .bad): {"version": 1, "players": {player key: {"entries": [[recipe, crafts left], ...], "head_elapsed_s": float}}}. Loaded at start; applied when that player connects; written on every queue change and on the 30 s item save. Unknown recipe numbers in a loaded file are dropped (their ingredients are returned to the player's inventory or the ground).

## Files
src/stream/terrain_net.gd (ACTs, RPC, signal, PROTOCOL_VERSION 22), src/stream/server_items.gd (queue, tick, save), scenes/terrain_server/terrain_server.gd (send_craft_queue), src/client/inventory_view.gd (queue strip, Craft button), PROTOCOL.md, CONTROLS.md, tests (server queue, restart, cancel refund, caps) and a client check in tools/items_check.py.

## Cost at Low
Server: the 4 Hz item tick loops only players that have a non-empty queue; one float add per such player. Client: nothing per frame; the queue strip refreshes on the craft_queue message and a 4 Hz label update while the screen is open. Message size under 100 bytes.
