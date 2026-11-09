# Rock uplift through the glacial history (design note)

**Chosen (coordinator, 8 Nov 23:00): option 1, at 0.19 mm a year.** Probes L, M and N (`glacial_summit_fix.md`) ruled out the snowline history, creep and the river K as the cause. The main summit is a horn at its rock's threshold slope and falls with its valleys at about 1 mm a year once its plateau is gone. ws580i lost 499 m over its 2.599 Myr, so the uplift at the highest summit is 499 / 2.599 = 0.19 mm a year. The run plan is at the end of this note. The figures below for the loss (about 145 m) came before ws580i measured it and are kept as the first estimate.

Sonny, 8 Nov 2026. This follows `docs/water/glacial_summit_fix.md`. Rule 6 line 4 (each checked summit within 25 m of its landform after the ice; D-10) fails even at measured erosion rates. Probe E, with glacial K set from measured cirque floor rates, still loses about 2.6 m a cycle at the main summit. Over the whole history that comes to about 145 m from the 1,441 m landform. The ws580i run measures it for every checked summit.

## What the measurements say

- **Ice does lower peaks that stand far above the snowline.** In the Cascades, summits rise only about 600 m above the cirque floors (the Quaternary mean snowline), across rock uplift rates of 0.14 to 0.33 mm a year: erosion keeps pace with uplift (Mitchell and Montgomery 2006, Quaternary Research 65:96). Our history's mean snowline, weighted by active years, is about 580 m. The main summit stands about 860 m above it, so the ice is bound to cut it.
- **Horns lose height once their faces meet.** The design's own headwall rates (0.5 to 1 mm a year while active, #654; 0.5 to 1 km over the history) put that meeting about halfway through. After it, every metre a 57-degree face retreats lowers the top by about 1.5 m.
- **Coasts rise.** Last-interglacial shorelines worldwide (890 records) rise on average more than 0.2 mm a year: 0.13 on passive margins and about 0.36 on active ones (Pedoja et al. 2011, Earth-Science Reviews). `glacial.py` uses no uplift (B1's `uplift_share` is 0), so it models a shore that has risen less than almost any measured coast.

## Options

1. **Uplift at a measured rate, highest under the range.** The rate is U(x) = U0 × landform height / summit height. It is zero at the sea, so the coast stays where the landform put it. U0 stays at or below the measured means (0.13 mm a year passive, 0.36 active). Each island takes the U0 at which its highest summit ends on its landform, from a first glacial run (and a second if the uplifted run misses by more than 25 m, since higher ground carries more ice). For the starter island that is about 145 m over 2.6 Myr, or 0.056 mm a year: an island rising more slowly than the average passive margin. This is a fitted rate, and the note says so. But it is a real process at a measured rate, not a clamp. The ice still carves every cirque and trough, and the other summits land where the physics puts them. They are checked against line 4 as they are.
2. **Uplift at the passive-margin mean, 0.13 mm a year, for every island.** No fit. The peaks end up to about 190 m above their landform, and every slope rises in proportion to its height, so relief grows by up to about a fifth, less what the ice takes. That meets D-10's "never below" but not "within 25 m".
3. **No uplift.** Line 4 is changed to allow the measured loss, and the landform stage builds peaks higher if the final height matters. This is the plainest physics. But the landform no longer sets the peak height Dave sees, which is what D-10 asks.

Left out: the island's own rebound as the ice and rivers unload it. It is real (Champagnac et al. 2007 measured it in the western Alps), but it needs a flexure model and would be small under an island this size. It would add to U, not replace it.

## Recommendation

Option 1. It keeps D-10 as Dave set it, the peaks at their landform height, with a process most measured coasts show, at a rate at the slow end of what is measured. The cost is one extra glacial run per island at bake time, to read U0. Code is small and comes after agreement. `glacial.py` already applies an uplift field through the cold phases and the idle years (`h += U × idle`). It needs a `glacial.uplift_m_yr` setting, the landform-shaped field, and the first-run read-out. Rule 6 line 4 then reads: the highest summit within 25 m by construction, the other checked summits judged as they fall.

## Run plan (8 Nov 23:00)

- **Code:** `glacial.rock_uplift_mm_yr` in `tools/watershed/glacial.py`. U(x) = U0 × landform height ÷ highest landform height on land, and 0 at the sea. It acts in the cold phases, the interglacials and the idle years, like the field B1 used. The default is 0, so older runs reproduce. The summary reports it under `rock_uplift`.
- **Run (Dino, Dave's PC, about 70 minutes):** ws580i's full run with one change: `glacial.rock_uplift_mm_yr` 0.19. Params: `/mnt/project-files/water/ws580u_glacial_params.json`. Same inputs, geology and B1 ground as ws580i, no `--start`.
- **Pass:** rule 6 lines 4 to 10. Line 4 needs the main summit within 25 m of 1,441.3 m.
- **If line 4 misses by more than 25 m:** one second run with U0 raised or lowered by the miss over the history (U0 + (1,441.3 − end) ÷ 2,599 mm a year). Higher ground carries more ice, so the first run can fall short. After the second run the rate stays and is noted, even if it is still out, and goes to the coordinator.
- **Honest label:** 0.19 mm a year is a fitted rate. It is above the passive-margin mean (0.13) and below the active-margin mean (0.36) of Pedoja et al. (2011). The other summits land where the physics puts them and are judged as they fall.

## Result (9 Nov; no more runs)

Two runs, both on Dave's PC. ws580u (0.19 mm a year): main summit 1,338.1 m against the landform's 1,441.3 m, −103.2 m (−7.2%). ws580u2 (0.2297 mm a year, the second-run rule's rate, +21%): 1,351.3 m, −90.0 m (−6.2%). The second peak ended at 1,034.2 m (landform 977.3 m) and the third at 1,066.8 m (910.2 m). Lines 5 to 8 and 10 pass, and line 9 fails (shady over sunny 0.99). Dave accepted 1,338 m and the uplift runs stopped (9 Nov, 01:55 UTC: "ok lets call it. done"). The record baked that night is ws580u's ground, at 0.19.

**Why it misses.** The summit is not lost early. In both runs it rises through the first 20 to 25 cycles of the 41 kyr world, to about 1,590 to 1,600 m, because uplift outpaces the young cirques. It is lost in the last 25 cycles, fastest in the ten long 100 kyr glacials, as the cirques' heads meet at the top. From cycle 39 on, the top stands at granite's 57° above the lowest cirque floor 300 m out: floor + 300 m × tan 57° = floor + 462 m, within 2 m in every cycle of both runs (cycle 49: floor 878 m, top 1,338 m; floor 891 m, top 1,351 m). So the top follows the cirque floors, and the ice sets them. Uplift raises the floors, but the ice then cuts deeper and faster where the ground stands higher, so 103 m more uplift lifted the floors and the top by only 13 m. This is the glacial buzzsaw: ice caps a range's height near its snowline plus what a headwall can stand (Brozović et al. 1997, Science 276:571; Egholm et al. 2009, Nature 460:884). The two lower summits have no horn, so they kept their uplift and overshot. A uniform top-up (the second-run rule) assumes the summit moves one for one with uplift, and here it moved about one eighth. Front-loading the uplift would not help, because the loss is late and at the floors. A cap on headwall retreat near the top would be a guard, which D-10 rules out.

**If the height is wanted back later** (not planned): the physical lever is the cirque floors in the last million years, set by how much ice the summit carries. The cold-stage snowline `glacial.ela_m` 487 m (kept for relic cirques, #717 row 21) is low for 34° S. A higher one gives smaller cirques with higher floors. That would be one probe run, and it changes the whole island's glacial look, not just the top.

**For other islands:** the design doc (A1, "What the pipeline delivers") now says to set a glaciated summit's target as what its first glacial run delivers, or to allow for the loss. The loss is not a fixed share: a taller summit with more of its height above the snowline is likely to lose more.

**Reproducing the record's ground:** the 0.19 rate lives in `/mnt/project-files/water/ws580u_glacial_params.json` (`glacial.rock_uplift_mm_yr`). `tools/watershed/params.json` still defaults to 0, so a rerun from the repository alone gives the no-uplift ground.

