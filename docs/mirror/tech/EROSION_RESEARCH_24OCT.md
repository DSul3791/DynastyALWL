# Simulating geologic-time water to carve valleys (Tyler, 24 Oct 22:50 UTC)
Asked by Dave. For the erosion thread (via the coordinator). Speed figures marked "?" were NOT found on the pages I could read; do not quote them as fact.

## The answer in plain words
The standard, well-published trick is NOT to pour water on the map. It is the **stream-power law**: each cell erodes in proportion to (water that drains through it) x (slope), while uplift pushes the land up. You solve it with an **implicit** step (Braun and Willett, "FastScape"), which stays stable with huge time steps, so millions of years fit in 50-200 steps, and cost is linear in cell count. Valleys, tributary trees and ridges fall out by themselves.

## The 5 options
| # | Option | Speed for an island at 8 m | Valley/river quality | Licence | Fit with our generator |
|---|---|---|---|---|---|
| 1 | **FastScape implicit stream power** (Braun and Willett; library fastscapelib, also Landlab's FastscapeEroder) | Linear in cells, big time steps; the published best-practice for large grids (exact timings ?) | Very good: dendritic river networks, concave profiles, ridges | fastscapelib **GPL-3** (do not copy code into the game); Landlab **MIT**; the algorithm itself is free to reimplement | Best. Global solve on a coarse grid, then we sample it; needs pits drained first (we already do that) |
| 2 | **Cordonnier 2016** "Large scale terrain generation from tectonic uplift and fluvial erosion" (stream power + uplift map, authored by painting uplift) | Fast on large maps (exact ?) | Excellent, the reference look for mountains with valleys | Paper; no code release found | Same maths as #1; shows the workflow (paint uplift, get mountains) |
| 3 | **Schott et al. 2023** "Large-scale terrain authoring through interactive erosion simulation" (repo H-Schott/StreamPowerErosion, C++/CMake) | Interactive in the paper (repo gives no numbers) | Excellent; stream power with uplift painting | **MIT** (usable as a reference or ported) | Very good reference implementation to port to GDScript/C++ |
| 4 | **Analytical erosion 2024** (Physically-based Analytical Erosion for fast Terrain Generation, Eurographics) | "Fast", time is a dial from light erosion to old mountains; multigrid | Very good, adds landslides/hillslope | Paper only, no code link on its page | Interesting later: erosion of an existing terrain by an age parameter. Not yet usable |
| 5 | **Droplet / grid hydraulic erosion** (particle erosion, Mei GPU shallow-water, Unity Terrain Tools, Godot plugins) | Needs many thousands of passes per map; GPU helps; global cost grows with map size | Good for small gullies and talus; weak at big valley networks; not geologic | Mixed (Unity tools proprietary, many MIT toy repos) | Poor for us: not deterministic by world position, tile seams, cannot run per tile |

## Recommendation
**Option 1 implemented from the papers, using Schott's MIT code and Landlab's MIT code as references** (not fastscapelib code, because GPL-3 in a game).

Action plan (one branch, one class):
1. Run once, offline, for the whole island on a COARSE grid (16 to 32 m; island heights are smooth at this scale). Not per tile: stream power needs the whole drainage basin, which is exactly why per-tile is wrong.
2. Inputs: island mask and uplift map (high inland, zero at the sea; Dave's mountainous style = higher uplift inland), initial noise terrain.
3. Step: priority-flood pit fill (Barnes) -> flow directions -> implicit stream-power update (receivers processed in upstream order, one pass, O(n)). 50-200 steps with dt large. Parameters: K (erodibility), m=0.5, n=1, uplift U. Slope of rivers and relief follow from K/U, so valley-slope limits (England farmland under 8-10 degrees) are set by tuning, and a hillslope diffusion term smooths the farmland.
4. Output: a coarse macro-height raster in git. The existing tile generator **samples** it (bicubic) and adds today's fine detail by world position. This keeps determinism and shared tile edges; only the macro input changes. The existing river/drainage stage runs on the result (pits already drained).
5. Gate: run twice, byte-identical (fixed seed, fixed order, no thread race); island_checks; Sonny reads the result before it feeds a bake. This is a BAKE-class change.
6. Do NOT use droplet erosion for the valleys. It can be a last small-scale polish pass later.

## Links
- Cordonnier et al. 2016: https://diglib.eg.org/handle/10.1111/cgf12820 (PDF https://www.cs.purdue.edu/homes/bbenes/papers/Cordonier16CGF.pdf)
- Schott et al. 2023 and MIT code: https://github.com/H-Schott/StreamPowerErosion
- Analytical erosion 2024: https://diglib.eg.org/handle/10.1111/cgf15033
- fastscapelib (GPL-3): https://github.com/fastscape-lem/fastscapelib
- Landlab FastscapeEroder (MIT): https://landlab.readthedocs.io/en/latest/generated/api/landlab.components.stream_power.fastscape_stream_power.html
- Particle/grid erosion (Stava 2008): https://www.cs.purdue.edu/homes/bbenes/papers/Stava08SCA.pdf
- Unity Terrain Tools hydraulic erosion: https://docs.unity3d.com/Packages/com.unity.terrain-tools@5.3/manual/erosion-hydraulic.html

## Caveats
Method details for Braun and Willett (implicit scheme, O(n)) come from my background knowledge; the pages I opened confirm Schott (MIT), fastscapelib (GPL-3) and the analytical paper (no code). Timing claims were not on those pages.
