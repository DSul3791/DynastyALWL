# Rule 6 run: what Dave sees

This page is for the run that should turn the starter island's domed summits into pyramid peaks (design A1 rule 6; the details are in `rule6_build_plan.md`). The glacial stage takes about 70 minutes on your PC. After it, this page says what to type, what each of the 12 lines means for how the peaks will look, and what happens if a line fails.

## 1. What to type

Type these in Dino's `bake_536` worktree (not your own checkout), at the sha the run used. `<new>` is the new run's folder and `<ws580g>` is the last run's folder. Each takes a few seconds.

```
python tools\watershed\peaks.py landform <new>\inputs <ws580g>\inputs
python tools\watershed\peaks.py glacial <new>\inputs <new>\glacial
python tools\watershed\plots.py zoom <new>\glacial 54800 71424
python tools\watershed\plots.py zoom <new>\glacial 66960 79296
```

The two `peaks` commands print lines 1 to 10 and save them as `peaks_landform.md` and `peaks_glacial.md` beside the data. The two zoom pictures are lines 11 and 12.

## 2. The 12 lines, and what PASS looks like

| line | PASS means you will see |
|---|---|
| 1 | Before any erosion, each big summit has 3 or more hollows running up toward its top: places where water gathers and snow drifts. |
| 2 | Those hollows drain downhill. No pits or ponds were made on the slopes. |
| 3 | The hollows took nothing off the tops (within 1 m of the last run). |
| 4 | Each top is still within 25 m of its planned height after a million years of ice (D-10). |
| 5 | After the ice, 3 or more bowls (cirques) sit in those hollows round each top. |
| 6 | The ground near the top (within 300 m) is steeper than before: the top got sharper, not rounder. |
| 7 | There is no flat cap over 300 m across: no dome or plateau on top. |
| 8 | The bowls ate back into the peak at the speed real ones do, 0.1 to 1.3 mm for each year a glacier sat in them. |
| 9 | The shady, snow-loaded north-east bowls cut back 1.5 to 2 times faster than the south-west ones, as on real mountains. |
| 10 | The bowls got most of their depth early, then mostly cut backward. Later deepening is at least 5 times slower. |
| 11 | Dino's zooms show bowls at the hollows, knife-edge ridges (arêtes) between them, and a pyramid top. |
| 12 | There is no ring cliff round a top, no star of straight rays, and no even band of wall. |

If all 12 pass, the starter peaks look like Arran or the Cuillin, up to Matterhorn scale: steep three- or four-sided horns above bowl-shaped corries, with sharp ridges between. If lines 8 to 10 read N/A, the run had no glacial cycles, so it was made at the wrong sha.

## 3. If a line fails

Copy the failing line exactly to the coordinator for Sonny. Don't rerun with a changed setting just to make a line pass.

The numbers in `params.json` `peaks` are measurements of real mountains. Never change them: that would move the goalposts.

Only lines 8 and 9 have a setting that may fix them, and only after Sonny has read the cause. Change one setting at a time, then make one new run (about 70 minutes) and read all 12 lines again.

- **Line 8 too slow (under 0.1) or too fast (over 1.3).**
  - Setting: `glacial.glacial_K_ratio`, now 2.0. It says how much harder ice cuts rock than water does. It is the one model number not measured on ground like ours, so the measured retreat is what calibrates it.
  - Retreat rises roughly in step with this number. The new value is 2.0 × 0.7 ÷ the median the line printed, where 0.7 mm/yr is the middle of real rates under active glaciers.
  - Change it by no more than double or half in one run, because the link is not exactly straight.
- **Line 9 ratio under 1.2 or over 3.**
  - Setting: `glacial.aspect_ela_m`, now 75. That is half the 150 m by which the snowline sits lower on north-east faces.
  - Under 1.2: raise it toward 110, the top of the measured range (a 220 m difference, in British Columbia).
  - Over 3: lower it toward 56, the bottom (113 m, in the Făgăraş).
  - Never go outside 56 to 110. If that range cannot fix it, the model is missing something, such as wind-blown snow or shade, and Sonny adds it.
- **Line 10 (later deepening does not slow).** No setting. Real cirques stop deepening because their floors settle near the snowline. If ours keep sinking, Sonny finds where and why.
- **Lines 1 to 7, 11 and 12.** No setting. Line 4 matters most: a summit that dropped means its bowls met at the top. Sonny then raises the landform for a physical reason, never with a summit guard (D-10).
