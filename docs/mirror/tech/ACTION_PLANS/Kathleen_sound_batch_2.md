# Kathleen: sound batch 2, ambience (goal 7)
Class: synthesized ambient loops and one-shots for the EMPTY ambience slots in art/SOUND_MANIFEST.md.
1. Forest bird chorus (spring, summer, autumn thin, winter sparse), night owl, frogs at ponds, cricket variety.
2. Surf for beach islands, desert wind, canyon echo tail, volcano rumble and lava hiss, ice crack.
Method: assets/audio/make_batch2.py using make_sounds.py helpers, seamless loops 20-30 s, peak -14 dB (ambience under creature clips), ogg q4; data/sound/batch2_slots.json; tools/validate_sound_slots.py must print 0 empty; CREDITS.csv row batch2/*.
Test: validator passes, tools/clip_check.py loop seam under 1 dB step, size under 1.5 MB total; ear card to Dave after Steve wires slots (Sound test menu "Batch 2").
Branch claude/kathleen-sound-2. Label RUNTIME (data + audio only). Tyler reply: see below (GO)

## Tyler reply (24 Oct 08:25 UTC) GO, branch claude/kathleen-sound-2, label RUNTIME (answered once; batch 1 rules 1-9 apply unchanged)
Plus, specific to ambience:
1. Layers, not one long loop: build each ambience as 2-3 short beds plus random one-shots (bird calls, owl hoot, frog croak) played by a scheduler with a minimum gap, instead of one 30 s loop that the player learns by ear. Game audio practice: a bed loop of 20-30 s hides repeats only when the one-shots on top are randomised with gaps (random interval 4-20 s, pitch +/-5 percent, never the same variant twice in a row).
2. Seamless loop test numeric: loop seam step under 1 dB (your clip_check) AND no click: start and end at zero crossings, 50-200 ms equal-power crossfade; also play 3 times back to back in the Sound test.
3. Time and season by data, not by file name: slots carry tags (season, day/night, biome, near water, altitude) in batch2_slots.json, so the game picks bird chorus by season and owl by night, crickets by warm night, frogs at ponds in spring and summer only. Check with the climate rules of the island types (hot islands: no ice crack; polar: surf is ice-edge, desert wind only on desert and dry scrub); list the tag per slot in the validator output.
4. Distance and voice cap: ambience beds are non-positional and low priority under creature clips (as you wrote, -14 dB peak), but frogs, surf, volcano rumble and canyon echo are positional with a max distance. Volcano rumble must fade with distance by a table, since the crater rim is audible from kilometres. Respect the per-tier voice cap in Steve's mixer; report the number of simultaneous ambience voices at the busiest tile.
5. Size and memory: the 1.5 MB total is a good cap; also report memory loaded at Low (BP: under 150 MB, JOBS.md). Streaming for loops longer than 20 s if the engine supports it; else keep loops short.
6. Safe-place rule: nothing frightening or divisive as default; the volcano rumble and ice crack stay moderate; the night owl is a hoot, not a scream.
7. One ear test in the Sound test menu, "Batch 2": every group in sequence, labelled; ONE card for Dave with Yes/No per group and "Tyler recommends"; Dave's own recordings win where he made them.
Go.
