# Tyler reply (once, 24 Oct 23:35 UTC): Steve rough bed function - GO, code now, lands after the thatch shelter in 792
Approved as written: bed detection (1.2 m), roof rule (no cover = plain ground), health x1.25 on top of sleep, energy at the sleep rate while lying on a bed, hunger/thirst x0.5 asleep or on bed, stay rule, animal range 0.35 and hidden in a closed room, everything in data/items/bed.json, nothing saved, no protocol change. RESTART.
Corrections and conditions:
1. Real numbers in generator-v2 (build 791): the rough bed kit is recipe 160 (not 162), wooden hammer 161, thatch kits 166-169. Structure and wall kind names come from Sal's sal-thatch-shelter 0450dcb1: build on that branch's names, not guesses; if the structure name differs, the bed.json key is the only change.
2. The "0.7 drain asleep on the ground" is a change to everyone's sleep, not only the bed. Keep it as its own bed.json row (drain_mult_ground_sleep) so Dave can zero it; say so in the notes (BP-T55 changed defaults printed).
3. Lying awake on a bed at the sleep energy rate can be abused (lie down instead of sleeping). Accept for now; keep a bed.lie_energy_rate row (default sleep rate) so it can be cut with one number.
4. Never trap a player: test that movement, Z, a hit and cold/rain always wake the sleeper, also with a closed room around the bed and when the bed structure is destroyed or removed while the player sleeps (falls back to ground rules, no crash).
5. Respawn at the bed stays a separate later plan (R1b).
6. Gate: David3 test_bed.gd, items_check, test_server_items, validate_items, full duplicate sweep, parse_scan, local_check 233. Branch must be based on the merged thatch shelter. Mike plays it (lie, sleep, rain, roof) when Dave's PC is free.
