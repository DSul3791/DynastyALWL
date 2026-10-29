# River flood plan (Sonny_002, 2026-10-22) - PLAN ONLY, for Steve_002 to approve

Dave's answer (questions/ANSWERS.md, river-flood): real floods in storms and spring melt, able to wash out low buildings and crops.

## What already exists (do not rebuild)
- Rain and storm already raise every spring: `Weather.river_push` (steady heavy rain 0.6, storm 1.0) lifts flow from x10 to x20 of the base rate; the server lags it over several real minutes and calls `WaterHub.set_runoff`. `river_dry` shrinks rivers in heat. The sim multiplies every spring by `spring_multiplier` on the water thread, so extra flow costs the same per tick (main thread only copies changed levels in `_poll_water`).
- The sim is real shallow-water flow, so more inflow already overtops banks where the bed is low. No separate "flood" code is needed for the water itself.

## What is missing
1. **Spring melt.** Weather has seasons and temperature but no snow store. Add a pure function `Weather.melt_push(seed, game_s, group, altitude)` (0..1): rises in the spring warm-up when temp_c crosses about 0 to 8 C, 0 in summer and winter, stronger for mountain springs. `runoff = max(rain push, melt push)` per tile group (head ponds above about 300 m melt first). Pure maths, no storage, no worker cost.
2. **Flood size.** Today a storm gives x20. Proposal: a "big storm" or peak melt may reach x35 for a few game hours. Needs a test with the soak script: does x35 leave the river bed in the nine starter tiles at believable places only (low meadows by the river), not the village or spawn hill? If it floods the spawn, cap the multiplier per tile instead of tuning terrain.
3. **Warning to players.** Server-side: when a tile's river runoff passes a threshold, send one text line ("The river is running high.", later "The river has burst its banks.") and play the existing river roar louder through the water-sound slots (Mandy). River colour goes browner (shader uniform, Mandy). Rising water is slow (minutes), so no sudden death; flood warning also appears before arrival because rain falls upstream first.
4. **Damage.** Only when buildings and crops exist: a once-per-minute server check of the water level at each placed item's footprint (data lookup, no sim cost). Wet 0.3 m: crops lose a growth stage; over 0.6 m: crops destroyed; low buildings: contents float away only above 1 m for 2 minutes, structures stay (Dave's principles: safe, kind, generous). Needs Radar's placement API; design numbers go to Dave as a question before building.
5. **Receding.** Flow falls with the lag already in place; water settles back into the bed with the existing drain, leaving mud (cosmetic, later).

## Cost and risk
- Water thread: unchanged per tick; only more wet cells drawn, so chunk_levels costs more during a flood (worker thread, 8 m grid). Measure with test_water_soak at x35.
- Memory: wet-cell count rises; the 4 live tile limit stays.
- Risk: floods reaching spawn or the village. Mitigation above (per-tile cap). No bake needed; runtime only.

## Build order (after approval)
A. melt_push + tests (pure function), B. peak multiplier + soak test at x35, C. server warning line, D. Mandy: sound and colour hooks, E. damage after Radar's placement API and Dave's numbers.
