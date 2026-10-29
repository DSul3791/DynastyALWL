# Fitness (Items, 2026-10-21, protocol 26)

- What it changes: only how fast exertion RISES during strenuous activity (running, climbing, tool work, heavy loads): rise per second x exp(-fitness x 0.05). Fitness +10 = 61 percent of the normal rise (winded about 1.65x later), -10 = 165 percent. Recovery, thresholds, speeds are untouched. The old exertion.json "fitness" threshold placeholder stays 1.0.
- Range: whole number -10..+10 (same style as luck), 0 = average adult. New characters start at 0; old characters.json entries without it read as 0.
- Fixed or growing: fixed for now. server_items.set_fitness(peer, value) is the training hook (clamped, saved, resent to the client); how work trains it is not designed. All numbers in data/items/fitness.json (strength 0 switches it off).
- Server-owned, saved in characters.json (same atomic/.prev path, still version 1) and sent to the client in vitals() only for the Tab screen. Tests: test_server_items (fitter characters are winded and black out later, ratio matches exp), persistence drills (fitness survives torn files).
- Over-exerted slowdown (Dave): client pace x0.9 in state 1 (exertion.json over_speed_factor), no cap, running allowed; the server does not validate speed against a minimum, so a slower client cannot trip any check.
