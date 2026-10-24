# Steve: waterfalls too loud and too far (branch claude/steve-fall-quiet)

Class (CHANGE_LABEL RUNTIME), one file: src/client/water_sounds.gd.

Dave 24 Oct (build 789): water_fall -8 dB heard at 93 m and -11 dB at 149 m, wind -37 to -42 dB; one fall had no drawn water.

Changed defaults (printed per BP-T55):
- KINDS fall db -14 -> -22; reach 260 -> 110 m.
- FALL_MAX_M (player max_distance) 300 -> 110; FALL_UNIT 26 -> 9 (clear within about 60 m, gone by 110 m).
- New: level follows the drawn flow, 6 dB per halving below 1 m3/s (clamped -24..+3 dB); flow under 0.05 m3/s makes no sound. Merged far falls sum their flows.
- Unchanged: width and drop boosts, fall base hiss (BASE_DB -12, BASE_REACH_M).

Test: walk to a fall: audible at 40 m, faint at 90 m, silent past 110 m; a fall with no drawn water silent. Mike or David3 ear check.
