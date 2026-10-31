**Status when written (05:05, PARTIAL):** the character select and creator logs are clean (0 errors). The windowed 3-minute walk and the 16 headless self-tests had not finished: the PC is saturated (37 Godot processes), including about 58 stale processes from this session's own earlier picture rigs.

**"Crash report written" x4 are freezes under load, not crashes.** The reports (`crash_reports/2026-10-31_04-18-17_build826.txt` and three more) say "The game is HUNG: the main thread was silent for 15 s", at 1 fps, while the client preloads about 80 audio files on the main thread ("SLOW AUDIO LOAD ... took 30 ms" each, rain, wind, water, tree wind). On a free machine this is a startup stall of a few seconds, not a hang; under saturation it trips the 15 s watchdog. Owner: Sonny / Tyler (audio preload); severity MEDIUM (startup stall), re-check on a quiet PC.

**`ERROR: Error loading voxel block` (83 in 212 lines) is new since the height fix.** Runs made before it (30 Oct 23:00 to 23:40) show no such line; every client log after the merge of d2ba5dfb has it, right after "JOIN: column answer". Terrain still appears in every picture, so it is noise plus probable extra load time. Owner: Sonny (TERRAIN_VERSION 44) with Tyler (block store).

**`Condition "!_is_active()" is true` in ENetMultiplayerPeer::get_peer** once, at client start: the client asked for the peer before the connection was up. Owner: Tyler (net), LOW.

**Creator preview opens on the body's back**: sent to Sonny.

### Felling pictures (art/playthrough/world3/fell*.jpg, stump_*.jpg), 07:40
The felling rig now works: tree falls (creak sound plays), lands, stump can be chopped 6 times (+16 stick, +4 firewood, +8 kindling), stump goes away.
Finding: the falling and resting trunk, the lying log and the stump are all one flat near-black colour with no bark texture (a standing tree has bark). Looks like a missing material on the felled-trunk, log and stump meshes. Rating 2.5/5. Owner: Kathleen (looks) / flora session.

### Rerun 08:00 to 08:10 on the daily head (merge 2be59394)
Select, creator and the 3-minute windowed walk completed (walk3min2.jpg: third person at the spawn clearing, brown hair, green top, brown trousers; feet and hands hidden in the grass; head tilted up at the sky; rating 4). 16 headless self-tests ran, none timed out. Still failing: the chest self-test (inventory_view.gd:4584, chest_inv Nil, "screen open false"). The "crash report" line in rig_client.log is the 04:18 to 07:49 freeze text copied from an older rig folder, not from this run (no new file in crash_reports/). Fire self-test: lit, grows to a bonfire, fire loops play; cook self-test: 1 lit fire, loops present.
Not photographed this run: lit campfire and log cutting close-ups (the picture rig does not support them without Kathleen's --shot-light; the headless self-tests only prove the server and sound side).
