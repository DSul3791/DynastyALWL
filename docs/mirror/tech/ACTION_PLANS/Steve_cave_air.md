
## Tyler reply (once, 24 Oct 14:30 UTC) — ONE answer for the class: pollen fade + cave air sound
GO on both, build after the devstop ends (Dave says go). Both RUNTIME, client only, each on its own branch. Only Steve edits cave_sounds.gd; the pollen thread only READS rock_enclosure from it (no edit).
Changes (small):
1. Air sound: only the Wind, Weather and Nature buses fade. Foley, UI, Music and voice are never cut. Prove it in test_cave_air.gd.
2. New data/sound/cave_air.json must pass tools/sound_check.py and the json parse; table values live only there. Print changed defaults (BP-T55): the table rows.
3. Depth: walking out must restore the outside air within about 2 s of the mouth (test it); a teleport or login inside rock starts at deep. Houses and built rooms do not count (rock enclosure only): say so in the test.
4. Wet detection stays on the existing protocol 73 message. No new network traffic, no protocol bump. If you find you need one, stop and tell me.
5. Pollen: the check line goes in tools/check_cave_light.gd as planned; open air must stay exactly 1.0 (no change outside caves).
6. Tests: parse_scan, local_check 233, check_controls, sound_check, item_master unaffected. Dave's ear card on QA: "walk 30 m into a cave, then out" (outside air fades with depth, silent deep in, drips only in a wet cave). Mike does the tunnel listen test as stated.
7. I merge the tested ids on Mike's PASS, in one build.

## Tyler 25 Oct 05:10 UTC (re cave air build 719bed5b)
No numeric amendment: the numbers in data/sound/cave_air.json (0/6/25/40 m = 0/-6/-45/-60 dB, low-pass 20000 to 1000 Hz, drips and full reverb only in wet caves, dry caves half reverb) are the ones to ship. My seven points above (only Wind, Weather, Nature buses; json passes sound_check; outside air back within 2 s; no new traffic; pollen 1.0 in open air; tests) are the gate. Queue: RUNTIME, client; David3 gates 719bed5b66b0d03acb152dbb0ed7a52e4eaeded2 (test_cave_air, parse_scan, local_check 233, sound_check) after the spawn-column group; Dave's ear card on QA.
