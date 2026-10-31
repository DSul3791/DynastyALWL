# SOUND_AUDIT: cave-in rumble and rain-like sound in clear weather

Written by the guide session, 2026-10-31. I cannot hear anything, so this is read from the code, Dave's saved world and the client's own "sounds heard" lines (three smoke-test clients at spawn, day 100, clear weather, headless). I did **not** log a timed 3-minute list; the three samples below are all I have, and the proposals are untested.

## 1. The cave-in rumble while not digging

How it reaches the ear: `src/stream/tunnel_watch.gd` tick() sends a quake to every player within 40 m (`QUAKE_RANGE_M`) of any "working" cell once that cell is past its quiet part; `placed_sounds.gd quake()` plays `bracing_rumble` at stage 3 and above, then dust, cracks and ticks.

What makes a cell: a dug space (air now, rock when generated; natural caves are filtered out by `_dug`) with at least 1.5 m of ground over its roof and a roof wider than 2 m in soil (6 m in rock). A pit in open ground has no roof, so it never counts; a tunnel into a hillside does.

Timers: Dave's saved server (`tunnel_settings.json`) has the watch ON, collapse ON, cave_in_s 120. data/tunnels.json says quiet_s 600. So **10 minutes after a roofed dig the ground creaks, then rumbles and shakes for about 2 minutes, then it falls and fills with rubble**. That is the design, but it happens while the player is doing something else, which is what Dave calls "not digging".

Dave's world: `digs.dat` holds 30 digs, all radius 1.4, in one line from (53856, 74, 68288) to (53892, 71, 68289), sloping down 3 m, along 36 m. That is a hillside tunnel, about 540 m east and 190 m south of spawn. Any walk within 40 m of it, in a session in which the watch has measured it, would give creak, then rumble.

Two things I found that may make it feel random:
1. **The watch forgets after a server restart.** Nothing calls `mark_dirty` at start, so old tunnels have no timer until someone digs in the same block again. After a restart there is no rumble from the old tunnel, until a new dig touches its blocks; then the whole 10 + 2 minute window restarts. So the rumble appears minutes after a dig, at a place the player may already have left.
2. **No warning in words.** The rumble is the only sign. A message ("the ceiling creaks: brace it or leave") at stage 2 would turn a mystery into a mechanic.

Proposals (Tyler): measure the blocks around digs.dat entries at server start (so state is consistent); send a chat notice at stage 2 with the direction; keep the 40 m range but do not play the rumble when the player is outside the tunnel (surface height above the cell is more than 4 m). Not a bug unless Dave never dug a hillside tunnel: if he says no, check the digs.dat line above.

## 2. Rain-like sound when the weather says rain 0.00

At rain 0.00 the weather module plays nothing: smoke logs show `weather clear rain 0.00 ... loops []`, rain_drip needs rain at least 0.15, rain_water scales with rain. So **it is not the rain beds, the drips or ground_wet**.

What did play in three clear-weather runs at spawn (sounds heard list, source, level, distance):
- `wind_low` here -39 dB, `wind_gust` here -40 dB (generated).
- `treewind_leaves` 5 to 9 m, -40 to -41 dB (generated).
- `treewind_pine` 5 to 7 m, -41 to -42 dB (generated).
- no water loops at spawn (the sea is out of reach there).

Suspect: **`treewind_leaves` and `treewind_pine`.** `assets/audio/make_treewind.py` builds them as steady band-limited noise: leaves is a band at 2.2 kHz (0.5 to 6 kHz), pine a band at 3 kHz above 1.2 kHz. That is the same family of hiss as a rain bed. They are loops (no gaps, no ticks), placed at the middle of the trees (a stand of trees sounds like a rainy area), and they run whenever the wind is above calm: wind was 0.34 to 0.36 in the "clear" runs, which is not calm. In a forest the level goes up to -24 dB (BASE_DB) plus 3 dB under canopy: that is the loudest steady sound on a clear day.

Second suspect: `water_river` (-22 dB at the source, reach 50 m) and `water_brook`: broadband burble that can read as rain from a distance; not heard at spawn, so it applies near streams.

Proposals:
- Sonny/Tyler: gate the tree-wind loops on gusts, not wind strength: silent below wind 0.5 and swelling with `wind_gust`, so a calm day has no leaf hiss.
- Kathleen/Sonny: regenerate leaves with irregular amplitude (slow swells of 3 to 8 s, plus sparse mid-frequency "flutter" ticks) and lower the 2 to 6 kHz band; give pine a narrower, lower band (1 to 2 kHz). Both loops are too even.
- Lower BASE_DB from -24 to about -30 for the leaves loop while the wind is under 0.6.
- Add an in-game name for this: the sounds heard list already shows `treewind_leaves`; ask Dave to open the debug details and read the loudest line the next time he hears "rain".

## 3. Still to do
- A real timed 3-minute log (a windowed client plus a sampler of `heard_text` every 5 s) needs a one-line debug flag in the client; I did not change game code.
- Ask Dave which place he was when he heard each sound (near the east hillside tunnel? in the forest?).
