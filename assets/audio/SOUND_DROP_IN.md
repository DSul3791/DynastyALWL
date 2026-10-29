# Where Dave's animal recordings go (Kathleen, 2026-10-23)
Folder: assets/audio/recorded/creatures/ (the game plays a file here instead of the generated one with the same name; delete the file to get the generated sound back).
Names (add _0, _1 for variants; more than 2 is fine):
- fox: fox_bark_0.ogg (idle/alert), fox_scream_0.ogg (threat)
- deer: deer_grunt_0.ogg (idle), deer_snort_0.ogg (alert/threat)
- moose: moose_grunt_0.ogg (idle: cow moan or long call), moose_snort_0.ogg (alert), moose_bellow_0.ogg (threat: bull roar)
Format: ogg (vorbis), mono, one clean call per file, 1.5 to 8 s, no background noise (check: python3 tools/clip_check.py file; PASS needs SNR 25+ dB, floor -50 dB or lower, no clipping).
Loudness target: after trimming, peak about -14 dB (the wolf, bear and horse clips sit there; Dave found -2 dB far too loud). Fastest: python3 tools/clip_check.py in.mp3 --out assets/audio/recorded/creatures/NAME.ogg (trims silence, writes ogg at -2 dB peak), then lower 12 dB: ffmpeg -i f.ogg -af volume=-12dB -c:a libvorbis -q:a 5 out.ogg
Add a row to assets/audio/CREDITS.csv (author Dave, source, licence). Test: Esc > Settings > "Sound test: creature calls", F4 shows "last sound: creature ... (recorded)".

Deer reference (Dave, description only, not licensed audio): "Deer Call Sound Only" https://www.youtube.com/watch?v=ioVPkxh2L7k, a buck contact grunt, repeated about every 13 s. A contact grunt is a short, low, soft "unh" (about 0.3-1 s), often in a short series; not a loud bark or snort. Do not use the video audio in the game.
