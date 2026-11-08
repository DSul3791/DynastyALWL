# Rivers and floodplains: meanders, braids, floodplains, terraces, fans and deltas

**Last checked:** 2026-11-08 (web research by Jamie). **System owner:** Sonny (terrain and watershed rebuild, steps R3 to R5). **Related:** `docs/water/Dynasty_How_Natural_Watersheds_Work.md` (Dave's document; it governs, and this page only adds numbers), `docs/water/watershed_rebuild_design.md` (C5 network, C8 coast outlets), `tools/watershed/evolve.py` and `params.json` (the R2 deposition term), [water.md](water.md), [caves.md](caves.md).

All sizes below are given against the channel's bankfull width W (the width when the channel is just full) and its slope S, so they hold for a 2 m brook and a 40 m river alike.

## Lessons (read these first)

1. **The channel pattern follows slope, flow, bed and banks.**
   - Natural rivers are almost never straight for more than about 10 widths (Leopold and Langbein 1966).
   - **Meandering** reaches (sinuosity 1.5 or more, the USGS working line) sit on gentle slopes. **Braided** reaches, with two or more channels around bars, sit on steeper slopes at the same flow. Leopold and Wolman (1957) drew the dividing line at about S = 0.0125 Q^-0.44, with Q the bankfull discharge in m³/s.
   - Our sums from that line: about 0.0125 at 1 m³/s, 0.006 at 5 m³/s, 0.0034 at 20 m³/s and 0.0017 at 100 m³/s.
   - Slope is not enough on its own. Braiding needs plenty of coarse bedload and weak, unvegetated banks, and flashy floods help it. Cohesive, rooted banks give narrow, deep, meandering channels even on the same slope.
   - Braided rivers belong in glacial outwash, on fans, and in young, fast-eroding mountain valleys (New Zealand's South Island, Alaska).
2. **Meanders scale with width.**
   - Wavelength λ ≈ 11 W (Leopold and Wolman 1960: λ = 11.0 W^1.01, W in metres; Williams 1986: λ = 7.5 W^1.12). Across rivers, λ/W runs from about 7 for small streams to about 15 for large rivers.
   - Amplitude A ≈ 2.7 W^1.1.
   - Radius of curvature Rc ≈ λ / 4.7. Rc/W is most often 2 to 3, and about a third of bends are tighter than 2 (Williams 1986, 194 sites).
   - Sinuosity runs from about 1.3 to 4.
   - Riffles (the shallow, fast steps) are spaced about 5 to 7 widths apart, two per meander.
   - The shape is the "sine-generated curve" (Langbein and Leopold 1966). The channel's heading swings as a sine of distance along it, with the crossing angle θ0 = 125·√((K-1)/K) degrees for sinuosity K. It is the curve with the least total bending, which is why real meanders look smooth rather than circular or zigzag.
   - Our sums: a 4 m brook has λ about 45 m and A about 12 m; a 10 m stream about 113 m and 34 m; a 20 m river about 226 m and 73 m.
3. **Sinuosity is how a river gets the slope it needs.** K = valley slope / channel slope. A river on a valley floor steeper than its stable channel slope lengthens itself by meandering until its own slope fits.
   - Bends migrate outward and fastest at about Rc/W of 3 (Hickin and Nanson 1975, Beatton River), so bends grow, tighten and finally cut off.
   - The cut-off loop becomes an oxbow lake, which then slowly fills with silt and clay.
   - An old floodplain therefore carries meander scars and oxbows, each with a cause.
4. **The river builds the floodplain, and floods it about every year and a half.**
   - Bankfull flow returns on average about once every 1.5 years, so the lowest floodplain floods about twice in three years. Higher parts flood less often.
   - Most of the floodplain is built sideways. Point bars on the inside of bends grow about as fast as the outside bank is eaten.
   - Overbank floods add only a little, and most of it lands next to the channel. In the 1973 Mississippi flood about 53 cm settled on the natural levees against 1.1 cm in the backswamp.
   - Natural levees are low and broad: about 20% of the channel depth high, and about one channel width wide where plants hold them (Albernaz et al. 2020).
   - The backswamp beyond them is the lowest, wettest ground on the floodplain, so it is where floodplain marsh and swamp belong (R4).
   - Channels scour about 1.75 to 2 times the flood depth at bends.
5. **Terraces are old floodplains left high when the river cut down.** Each has a flat tread and a steep riser.
   - Causes:
     - a fall in base level (sea or lake);
     - uplift;
     - a change of climate, water or sediment, such as the end of a glaciation when meltwater and sediment supply collapse.
   - **Fill terraces** are cut into valley fill and can stand 100 m or more above the river. **Strath terraces** are bedrock floors with a thin gravel skin.
   - Terraces are **paired** (same height on both banks) where the cutting was even, and **unpaired** where hard rock on one side stopped the river leaving a bench there.
   - Climate terraces form over about 10³ to 10⁵ years, tectonic ones over 10⁶ years or more.
6. **Fans form where a steep, confined channel loses its walls.** At a mountain front or a tributary junction the flow spreads, slows and soaks in, so it drops its load.
   - Fans slope about 1.5 to 25°, steepest at the apex. Debris-flow fans are steep, small and bare; stream-flow fans are gentler and can be very large.
   - In cross-section a fan is convex up, the opposite of a valley, so it has no floodplain.
   - Its channels jump (avulse) across the fan when they block, taking a steeper path.
   - Fan area grows as a power of the catchment area (Bull 1964: A_fan = c·A_basin^n), and weak or erodible catchment rock makes bigger fans.
   - Fanhead channels can be cut up to tens of metres deep.
7. **A delta needs sediment reaching still water faster than waves and tides remove it.**
   - Galloway's three kinds:
     - **River-dominated** (weak waves and tides): mouth bars split the channel into many distributaries, building a bird's-foot (Mississippi).
     - **Wave-dominated**: a smooth, cuspate shore with beaches, few distributaries, often one, and usually smaller. Oblique waves give an asymmetric delta with a spit (Ebro). If waves can carry off all the sediment, there is no delta.
     - **Tide-dominated**: funnel-shaped, estuary-like, with tidal flats and marsh (Fly River).
   - A steep stream entering a lake builds a **Gilbert delta**: a flat topset, a foreset at the angle of repose, and a fine bottomset on the lake floor. Lake-head deltas fill lakes from the inflow end.
   - River avulsions on deltas happen within the **backwater length** L_b = h / S (bankfull depth over bed slope), and lobe size scales with it (Ganti et al. 2014, Yellow River).
   - Our sums: a river 1 m deep on a slope of 0.001 has L_b of about 1 km; 2 m deep on 0.0005, about 4 km.

## How ours works (main aa74fc22 and the R2 to R4 drafts, 8 Nov 2026)

- **R2 deposition** (`tools/watershed/evolve.py`, drafts #537, #556, #561, #579): implicit stream power with a deposition term (Davy and Lague 2009, in the form Yuan et al. 2019 use).
  - Deposition rate = G × sediment flux / Q, with `G` = 1.0 in `params.json` ("deposition matters, floodplains and fans form").
  - Slides route their debris down the same flow tree, so talus and fans gather at slope feet.
  - Sediment thickness is saved per cell. Sediment flux through each river mouth (`sediment_flux_m3_yr`) is saved so C8 can tell a delta from a rocky outlet.
  - Model cells are 16 m. The final ground is 8 m.
- **R4 groundwater** (`groundwater.py`, #579): marsh and swamp may form within `floodplain_reach_m` (50 m) of a perennial river or lake on alluvium.
- **R5 design** (C5 and C8 in the rebuild design):
  - Width about Q^0.5 and depth about Q^0.4 (Leopold and Maddock 1953).
  - Reach type from slope: pool-riffle below 0.015, plane-bed 0.015 to 0.03, step-pool 0.03 to 0.065, cascade above.
  - Meanders only on pool-riffle reaches with room on the valley floor, with wavelength scaled to width.
  - Low, broad levees only on lowland alluvial reaches.
  - More than one channel only in wetlands, deltas and braided outwash.
  - Coast outlets chosen from slope, sediment load and coast shape.
- **Retired** (design section 4.7): `meander.py`'s random meanders and the rule-carved bank walls. Meanders now need a cause.

## What we tried

| When | What | PR | Result |
|---|---|---|---|
| Oct 2026 | Rule-carved channels, banks and valley guides (`drainage_channels.gd`, `river_network.gd`) | — | Retired by the rebuild design: shapes without causes. |
| Oct 2026 | Random meanders (`meander.py`) | — | Retired: meanders must follow width and slope, not chance. |
| 7-8 Nov 2026 | Deposition in the long river era (G = 1) | #537, #556 | Drafts. Run d9f89615 built sediment mounds hundreds of metres high until a hollow could fill only to its sill. |
| 8 Nov 2026 | Floodplain wetlands within 50 m of perennial water on alluvium | #579 | Draft (R4). |

## What others do (with sources)

- Leopold, L. B. and Wolman, M. G. (1957), "River channel patterns: braided, meandering, and straight", USGS Professional Paper 282-B. Braids defined, sinuosity 1.5, the slope-discharge line, λ/W 7 to 12 in their data. https://pubs.usgs.gov/pp/0282b/report.pdf. The SI form of the line, S·Q^0.44 = 0.0125: https://coastalhydraulicslaboratoryfact.tpub.com/4_010491/4_0104910317.htm
- Leopold, L. B. and Langbein, W. B. (1966), "River meanders", Scientific American. Sine-generated curve, λ/Rc about 4.7, sinuosity 1.3 to 4, riffles 5 to 7 widths apart, rarely straight past 10 widths. https://facultyweb.kennesaw.edu/jdirnber/docs/Leopold%20Riv%20Meand%201966.pdf
- Leopold and Wolman (1960) and Leopold et al. (1964), meander equations λ = 10.9-11.0 W^1.01, A = 2.7 W^1.1, λ = 4.7 Rc^0.98, as gathered by the US Army Corps of Engineers channel rehabilitation guide: https://coastalhydraulicslaboratory.tpub.com/ChannelRehabilitation/ChannelRehabilitation0051.htm
- Williams, G. P. (1986), "River meanders and channel size", Journal of Hydrology 88. 194 sites, Rc/W most often 2 to 3. https://pubs.usgs.gov/publication/70015687. Its λ = 7.5 W^1.12 and the crossing-angle formula, as used by USDA-ARS for meander design: https://www.ars.usda.gov/ARSUserFiles/6112/meanderShapeAndTheDesign.pdf
- Hickin, E. and Nanson, G. (1975), Beatton River migration against Rc/W, peak near 3. Also Howard and Knutson (1984), a curvature-driven meander simulation that grows and cuts off bends. Both as reviewed in https://zsylvester.github.io/post/curvature_migration_rate
- Braided rivers: conditions (coarse bedload, weak banks, flashy flow, steep slope) and settings. Includes Murray and Paola (1994), a cellular braided-river model in Nature. https://en.wikipedia.org/wiki/Braided_river
- Floodplains: bankfull about every 1.5 years, lateral against vertical accretion, levee against backswamp deposits, scour 1.75 to 2 times flood depth. https://www.britannica.com/science/river/Floodplains
- Albernaz, M. B. et al. (2020), "Natural levee evolution in vegetated fluvial-tidal environments", Earth Surface Processes and Landforms 45. Levees about 20% of channel depth high. https://pmc.ncbi.nlm.nih.gov/articles/PMC7780550
- Fluvial terraces: tread and riser, causes, fill and strath, paired and unpaired, timescales. https://en.wikipedia.org/wiki/Fluvial_terrace
- Alluvial fans: slopes 1.5 to 25° (Boggs 2006), sizes, mountain-front setting, avulsion. https://en.wikipedia.org/wiki/Alluvial_fan. Blair and McPherson (1994) on fans against rivers (convex cross-section, unconfined flow, gravity flows): https://archives.datapages.com/data/sepm/journals/v63-66/data/064a/064a003/0450.htm. Bull (1964) fan-area relation: https://people.wou.edu/~taylors/g322/fans.pdf
- Deltas: Galloway's river, wave and tide classes with examples (Bosboom and Stive, Coastal Dynamics): https://geo.libretexts.org/Bookshelves/Oceanography/Coastal_Dynamics_(Bosboom_and_Stive)/02%3A_Large-scale_geographical_variation_of_coasts/2.07%3A_Process-based_classification/2.7.3%3A_Classification_of_deltas. Gilbert deltas and mouth-bar bifurcation: https://en.wikipedia.org/wiki/River_delta
- Ganti, V., Chu, Z., Lamb, M. P., Nittrouer, J. A. and Parker, G. (2014), Geophysical Research Letters 41. Avulsions within the backwater zone, and delta lobe size scales with L_b. https://lamb.caltech.edu/documents/19648/Ganti_et_al_GRL_2014.pdf

## Decided / next

Nothing here is decided. These are proposals for Sonny's R3 to R5 work, for the coordinator to rule on.

1. **[Proposal, R5] Pick each reach's pattern from numbers, not chance.**
   - Braided only where S·Q_bf^0.44 is above about 0.0125, **and** the bed is loose coarse sediment (outwash below the R2b ice, fan surfaces, scree aprons), **and** the banks are unvegetated (above the treeline or on fresh outwash).
   - Meandering on pool-riffle reaches (S below 0.015) where the valley floor is at least the meander amplitude plus one width across.
   - Otherwise a confined, nearly straight channel that still wanders a little (never straight past about 10 W).
2. **[Proposal, R5] Meander planform from the sine-generated curve.**
   - Wavelength about 11 W, varied per river between about 7 W and 15 W, tighter where the banks are cohesive (silt and clay, peat).
   - Sinuosity from K = valley slope / stable channel slope, so it has a cause.
   - Rc kept at 2 W or more, and riffles every 5 to 7 W.
   - Old, wide floodplains get oxbow scars or lakes from cutoffs. Each one is a feature with a cause for the never-see checks.
3. **[Proposal, R5] Floodplain surface.**
   - Floodplain width from the meander belt.
   - The floodplain sits about one bankfull depth above the bed.
   - Levees about 0.2 depth high and about one W wide.
   - The backswamp is the lowest strip, so R4's floodplain marsh and swamp fall there naturally.
4. **[Proposal, R2/R5] Fans where channels leave confinement.**
   - The G = 1 deposition already drops load at slope breaks. Check on Dino's maps that fans appear at mountain-front exits and tributary mouths, with surfaces between about 1.5° and 25°, convex across and steepest at the apex.
   - The live channel's place on the fan is a seed choice among its possible paths.
5. **[Proposal, R2b/R5] Terraces only with a cause.** Our sea level is fixed, so there are no base-level terraces. The natural cause on our islands is the end of the R2b cold stage: outwash fills a trough, then the Holocene river (11,700 years in `params.json`) cuts into it.
   - That gives one fill terrace pair in glaciated valleys, unpaired where one side is hard rock.
   - Its height comes from the evolve output, not from a stamp.
6. **[Proposal, C8] Deltas from supply against wave exposure.**
   - Use `sediment_flux_m3_yr` at each mouth against how open the coast is.
   - Exposed coasts get a small cuspate wave delta or none. A sheltered bay with a high supply can get distributaries split at mouth bars within L_b of the mouth. Tidal creeks and estuaries go where C8 already puts them.
   - Lakes from R3 get **Gilbert deltas** at their inflows: a flat delta top with a steep front into the lake.
7. **[Check] Resolution.** On 8 m cells a 4 m brook's meander (λ about 45 m) is under six cells long. So brook meanders must live on the R7 reach polylines, not in the raster. Only rivers wider than about 8 to 10 m meander visibly in the ground itself.
