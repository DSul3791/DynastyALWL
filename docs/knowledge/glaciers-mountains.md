# Glaciers and mountains: how ice shapes peaks

**Last checked:** 2026-11-08 (web research by Jamie). **System owner:** Sonny (terrain rebuild, step R2b). **Related:** `docs/water/watershed_rebuild_design.md` (B2 glacial history, R2b), `docs/design/GUIDING_DOCUMENT.md` (D-10 mountains), `worlds/base_world/plan/sketch_rules.json` (`summit_m` per island type), [water.md](water.md), [caves.md](caves.md).

## Lessons (read these first)

1. **Ice carves valleys and hollows, not summits.** Glaciers erode where ice is thick, fast and confined: at valley heads (cirques), along valley floors (troughs) and where valleys meet or narrow (overdeepened basins). The summit itself stands above the ice and is only attacked from the sides. That is why horns like the Matterhorn are sharp, not flat. It also fits D-10: erosion only carves valleys and never lowers summits below the landform.
2. **A horn needs three or more cirques around one summit.** Each cirque's headwall retreats backwards into the mountain. Two cirques back to back leave a knife-edge ridge (an arête). Three or more meeting at a point leave a pyramid peak with three or four faces. Where erosion cuts through an arête, a col (pass) forms. So peak shape comes from where the cirques sit, not from a "horn" stamp.
3. **Cirques have a known size and shape.** Across 1,593 cirques in nine regions, the median was about 625 m long, 656 m wide and 310 m deep. Headwalls are steep (median maximum slope 57°, regional medians 48-68°), and floors are gentle (median minimum slope about 8°). They are roughly as wide as they are long. On our 8 m cells a cirque is about 80 cells across: the grid can carry it, but the arêtes between them are sharper than one cell.
4. **Cirques favour the shady, leeward side.** In the northern hemisphere most face north to east: less sun means less melt, and westerly winds drift snow into east-facing hollows. The bias is real but not absolute (in Antarctica it is weak and comes from wind, not sun). In our world, take the bias from latitude (poleward side) and from the prevailing wind (lee side), so it flips across the equator. **On the starter island (about 34° S) that is south to south-east** (`one-sky.md`).
5. **Cirque floors are overdeepened, so tarns are natural.** The floor is dug below a rock lip at the cirque mouth. When the ice melts, water fills the basin behind the lip: a tarn. Chains of basins down a trough give paternoster lakes. These lakes have a cause, which is what the rebuild's C2 rule asks for.
6. **Glacial valleys are U-shaped, and the shape can be measured.** Fit the cross-section to z = a·y^b. Glacial valleys sit near b = 2 (a parabola); Tian Shan troughs range from about 1.3 to 2.5. Real troughs are about 0.3 times as deep as they are wide at most. Models that let ice only deepen and never widen get this wrong.
7. **Small glaciers leave their valleys hanging.** A tributary glacier with less ice cuts less deeply than the main one, so when the ice goes its valley floor ends high on the trough wall. Its stream falls to the main valley: a hanging valley with a waterfall that has a real cause.
8. **Erosion grows fast with sliding speed.** Models use erosion = C × (sliding speed)^l, with l about 2 (the valley cross-section model below uses 2; Cordonnier et al. use 2.02). Bedrock erosion runs about 1-10 mm a year. In Cordonnier et al., ice thicker than 3 m shields the ground from river and slope erosion.
9. **Real glaciers cap mountain height near the snowline (the "glacial buzzsaw").** Where ice works for long enough, peaks are cut down toward the snowline (equilibrium-line altitude, ELA), so cold regions have lower, flatter-topped ranges. Ranges that escape are those rising fast or made of strong rock. **For us, D-10 overrides this:** Dave wants colossal peaks. To keep them believable, set the ice-stage snowline low, keep the ice working on cirques and valleys, and let the summits stand above it as bare rock walls in strong rock.
10. **Every slope has a limit set by what it is made of.** Use these as hard rules when building peaks (D-10 rule 4):

| Material | Slope it holds | Notes |
|---|---|---|
| Loose scree (talus) | About 31-37° | Measured on the Wasdale Screes; the basal toe can reach about 39° |
| Fractured hillslope rock | About 29-39° | "Threshold" slopes in eastern Tibet, varying by rock type; Cordonnier et al. use about 37° |
| Cirque headwall | About 48-68° | Median of the steepest part, nine regions |
| Strong massive rock (granite, gneiss) | Up to near vertical | Yosemite and Himalayan walls; very steep slopes outlast shallower ones by about ten times |
| Snow | Starts avalanching at 30-45° | Above about 60° avalanches are rarer because snow sheds before it builds up, so steep faces stay dark rock |
| Glacier ice | Flows on gentle slopes | Hanging glaciers sit on steep faces only where frozen to the rock, and break off as ice avalanches |

   Joints matter as much as rock type: joints dipping out of a slope weaken it, and joints dipping into it or across it strengthen it (Selby's rock mass strength gives joint spacing about 30% of the score).

## How ours works (8 Nov 2026)

- **Peak heights are set at the landform and seed stage** (D-10). `sketch_rules.json` gives `summit_m` per island type: starter 1000-1450 m, volcano 1500-2300 m, three-peak ridge 2000-2700 m (three peaks 2.2 km apart), giant peaks up to 3400 m (12% chance).
- **Glacial history is step R2b of Sonny's rebuild** (B2 in `watershed_rebuild_design.md`): an ice stage with a lowered snowline (a parameter), glaciers flowing down the river-cut valleys, erosion rising with ice flux and sliding, cirques at valley heads, U-shaped troughs, overdeepened basins behind rock sills, hanging tributary valleys, then about 11,700 years of post-glacial river and creep work. Where the snowline puts no ice, there is no glacial imprint. The rebuild's doc says the B2 model is still to be researched; this page is that research.
- **The starter island's climate** (rebuild doc): snowy winters, treeline at 620 m, summits near 1,450 m, like western Scotland, Norway or coastal British Columbia.
- **Retired:** `lem.py`'s random "tarn" sink patches. Lakes now need a cause.

## What we tried

| When | What | PR | Result |
|---|---|---|---|
| Before Nov | Random "tarn" sink patches in `lem.py` | | Retired: lakes with no cause |
| 7 Nov | Glacial history planned as rebuild step R2b (cirques, troughs, basins, hanging valleys) | rebuild design | Planned; model to be chosen by research |
| 8 Nov | Mountains decided: per-island relief, summits set at the landform stage, erosion never lowers summits, slopes within the rock's standing angle (D-10) | #583 | Waiting on the gate |

## What others do (with sources)

- **Glacial landforms (cirques, tarns, arêtes, horns, cols, troughs, hanging valleys, fjords, paternoster lakes).** https://en.wikipedia.org/wiki/Glacier_erosion
- **Cirques: formation, aspect, overdeepened floors.** Snow hollows enlarge by freeze-thaw (nivation), then glaciers pluck and abrade the floor; meltwater down the bergschrund helps; headwalls retreat by frost. Most Snowdonia cirques face north or east, from shade and westerly snow drift. https://www.antarcticglaciers.org/glacial-geology/glacial-landforms/glacial-erosional-landforms/cirques/
- **Cirque size, nine regions (Evans and Cox).** Medians of 625 m long, 656 m wide, 310 m deep; headwalls 48-68°, floors 3.5-10°. https://geomorphometry.org/uploads/pdf/pdf2015/EvansCox2015geomorphometry.pdf
- **Antarctic cirques.** A weak aspect bias driven by wind; sizes similar to other regions even after millions of years, so cirques reach a stable shape. https://e-space.mmu.ac.uk/632996/8/1-s2.0-S0169555X23003902-main.pdf
- **Horns.** Three or more cirques converging; three or four faces is most common; faces can become near vertical. https://en.wikipedia.org/wiki/Pyramidal_peak
- **U-shaped cross-sections.** z = a·y^b with b near 2; erosion = C × (sliding speed)²; in a 50,000-year model run a V becomes a U where ice slides faster than about 6 m a year. https://arxiv.org/pdf/0901.1177
- **The glacial buzzsaw (Egholm et al. 2009, Nature).** Glaciers limit how high mountains rise above the snowline; fast-rising ranges escape. https://en.wikipedia.org/wiki/Glacial_buzzsaw · https://www.livescience.com/5634-climate-controls-mountain-heights-study-shows.html
- **Steep slopes and rock strength.** Threshold slopes of 29-39° by rock type; very steep slopes last about ten times longer than shallower ones. https://eos.org/research-spotlights/steep-mountain-slopes-have-surprisingly-long-lifetimes · Selby's rock mass strength weighting: https://sites.geography.unt.edu/~williams/geog_3350/examreviews/strength_of_rock.htm
- **Scree angles.** Active scree 31-37°, toe to about 39°. https://geoguide.scottishgeologytrust.org/page/2138
- **Avalanche slopes.** Start zones 30-45°; fewer avalanches above 60°. https://www.wikiwand.com/en/articles/Avalanche
- **Glacial erosion for terrain generation (Cordonnier et al. 2023, ACM Transactions on Graphics).** A fast ice-flow model (a neural net trained on physics) plus abrasion, quarrying, debris flow, hillslope and river erosion. It produces U-valleys, hanging valleys, cirques with arêtes and horns, passes, lakes and fjords. It runs 10-100-year steps on 32-256 m grids; a 16 x 16 km terrain takes under 5 minutes. It has no moraines and is hard to art-direct. https://www.cs.purdue.edu/homes/bbenes/papers/Cordonnier23ToG.pdf

## Decided / next

1. D-10 stands: colossal peaks set at the landform stage; ice only carves cirques, troughs and basins; slopes within each rock's standing angle; granite under massif tops.
2. For Sonny's R2b, the research points to: cirques sized about 0.5-1 km and 200-400 m deep, placed at valley heads near the ice-stage snowline and biased to the poleward and leeward side; horns where three or more cirques meet; troughs with b near 2 and a depth-to-width ratio up to about 0.3; overdeepened basins behind rock lips (tarns, paternoster lakes); hanging valleys where tributary ice was thin.
3. Open for Sonny: whether to run a full ice-flow model (as Cordonnier et al.) or a cheaper rule-based carve from the same numbers. That is his technical call.

Open questions go to the coordinator.
