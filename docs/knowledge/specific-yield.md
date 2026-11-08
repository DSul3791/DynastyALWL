# Specific yield by rock type (for spring stores and baseflow recession)

**Last checked:** 2026-11-08 (web research by Jamie). **System owner:** Sonny (the per-spring store and the watershed rebuild).

**Related:** [Dynasty_How_Natural_Watersheds_Work.md](../water/Dynasty_How_Natural_Watersheds_Work.md) (springs and aquifers), [watershed_rebuild_design.md](../water/watershed_rebuild_design.md) (the aquifer and aquitard list), [upland-streams-numbers.md](upland-streams-numbers.md), `soils-ground-wetness.md` (#657, soak-in rates and perched water).

## Lessons (read these first)

1. **Specific yield (Sy) is the share of a rock's volume that drains by gravity when the water table falls.** It is not the porosity. Clay is 50% pores but gives only 2%, because the rest is held on the grains. This held water is the "specific retention" (Heath 1983).

2. **Laboratory values run high for solid rock.** Johnson's lab averages come from cores, and a core misses the fact that a rock body drains mostly through its cracks.
   - For example, his limestone averages 14% and his siltstone 12%.
   - Field values for limestone and shale are about 1% (Morris and Johnson 1967, via the Minnesota Stormwater Manual).
   - For a whole hillside, use the field values.

3. **Chalk is the classic case of high porosity and low yield.**
   - Its matrix is 30 to 45% pores, but the pore throats are so small that it "is not readily drained" (MacDonald and Allen 2001; Wealthall et al.).
   - Unconfined pumping tests give a median storage of 0.008, with an interquartile range of 0.0028 to 0.017.
   - Recession analysis gives 0.005 to 0.05 for the top 30 m of saturated Chalk (Lewis et al. 1993, cited there).
   - "Less than 1% of the Chalk bulk volume" drains under gravity.

4. **Karst stores little and drains fast.**
   - Well hydrographs in a karst aquifer gave Sy of 0.0001 to 0.0009 for the conduits, 0.001 to 0.0013 for the fractures and 0.003 for the rock matrix (Nevada Bureau of Mines and Geology, ORNL report Y/TS-1263, 1994).
   - Conduits "contribute relatively little to the storage of groundwater". Old, hard (telogenetic) limestones "have little matrix storage" (Kuniansky, Taylor and Paillet 2022, GW-Project book).
   - So a karst spring is flashy: fast flood peaks on top of a small store.

5. **Peat drains a lot near the surface.**
   - Johnson's peat average is 44%.
   - Intact bog peat cores gave 0.16 to 0.62 (Baird et al. 2024).
   - In one peat type, Sy fell 0.018 for every centimetre of depth. In the other it did not change with depth.

6. **Till depends on what it is made of.** Johnson's averages are 6% for silty till and 16% for sandy or gravelly till. The Minnesota manual gives a range of 0.06 to 0.16 with 0.10 typical. Clay-rich lodgement till drains far less (judged, see the table).

## The table (Sy as a fraction)

"Use" is our judged single value for the spring store. Sourced figures are marked with their source. Every number in the "Range" column is sourced unless it says "judged".

| Rock | Range | Use | Notes and sources |
|---|---|---|---|
| Granite and gneiss, fresh | 0.0005 to 0.005 (judged) | 0.002 | Heath gives granite porosity 0.1% and Sy 0.09% (0.0009) for the solid rock. The store sits in cracks near the surface. |
| Granite and gneiss, weathered mantle (saprolite and fissured zone) | 0.01 to 0.05 (judged) | 0.02 | No field source read today (the fetch budget ran out). The hard-rock literature (Dewandel, Maréchal et al.) puts most storage in this weathered layer. |
| Basalt, young (open joints, rubbly flow tops) | 0.05 to 0.10 (judged around Heath) | 0.08 | Heath gives porosity 11% and Sy 8% for young basalt. |
| Basalt, old and dense | 0.005 to 0.02 (judged) | 0.01 | Weathering clays up the joints. |
| Limestone, karst | 0.002 to 0.005 | 0.004 | ORNL 1994 well hydrographs: matrix 0.003 plus fractures 0.001 plus conduits under 0.001. A flashy spring. |
| Limestone, not karst | 0.005 to 0.05 | 0.01 to 0.02 | Morris and Johnson 1967 (Minnesota manual) give 0.005 to 0.05, typical 0.01. Heath's 18% and Johnson's 14% are porous rock or lab values: do not use them for hard limestone. |
| Sandstone | 0.05 to 0.15 | 0.08 | Minnesota manual: 0.05 to 0.15, typical 0.10. Heath: semiconsolidated 6%. Johnson lab: 21% fine, 27% medium (too high for cemented field rock). |
| Shale and mudstone | 0.005 to 0.05 | 0.01 | Minnesota manual: 0.005 to 0.05, typical 0.01. Johnson's siltstone 12% is a lab value. Clay (Heath and Johnson) is 0.02. |
| Chalk | 0.003 to 0.02 (0.005 to 0.05 near the water table) | 0.01 | MacDonald and Allen 2001: median 0.008, IQR 0.0028 to 0.017. Lewis et al. 1993: 0.005 to 0.05 in the top 30 m. |
| Glacial till, clay-rich (lodgement) | 0.01 to 0.05 (judged) | 0.03 | Below Johnson's silty till 6%. Weathered and cracked near the surface. |
| Glacial till, sandy or gravelly | 0.06 to 0.16 | 0.10 | Johnson: silty till 6%, sandy and gravelly till 16%. Minnesota manual: 0.06 to 0.16, typical 0.10. |
| Sand and gravel (outwash, river terraces, fans) | 0.15 to 0.30 | 0.22 | Johnson: fine sand 21%, medium 26%, coarse 27%, gravels 22 to 25%. Heath: sand 22%, gravel 19%. |
| Peat | 0.15 to 0.6 | 0.3 near the surface, 0.15 deeper (judged split) | Johnson: average 44%. Baird et al. 2024: 0.16 to 0.62 in bog cores, in one peat falling 0.018 per cm of depth. |

## What it does to a spring (our sums)

- **The formula:** Rorabaugh's recession time constant is τ = 4 Sy L² / (π² T). It is linear in Sy, so the table above spreads τ across about a hundredfold.
- **Example:** a 500 m flow path (L) with transmissivity (T) 100 m²/day:
  - Sy 0.004 (karst) gives τ ≈ 4 days;
  - Sy 0.01 (chalk, shale, hard limestone) gives τ ≈ 10 days;
  - Sy 0.08 (sandstone, young basalt) gives τ ≈ 81 days;
  - Sy 0.22 (sand and gravel) gives τ ≈ 223 days.
- T differs by rock far more than Sy does, so in practice karst and chalk both get a much higher T and recede faster still. Sonny sets T. This page covers Sy only.

## Never-see checks

1. A granite hillside spring that keeps running strongly through a dry summer, while a gravel terrace spring next to it fails.
2. A karst spring that rises slowly over days after a storm.
3. Chalk given a sand-like Sy of 0.2 because its porosity is 35%.
4. Peat that holds no water at the surface.

## How ours works today (read from the code, 8 Nov, not tested)

- No specific yield or Rorabaugh store is in the code or docs on main yet.
- `watershed_rebuild_design.md` lists the rock behaviour in words only:
  - chalk and sandstone hold and pass water;
  - limestone and marble pass it through karst;
  - basalt passes it through joints and lava tubes;
  - shale, slate, coal measures and most granite hardly at all.
- The table above puts numbers on that list.

## Sources

- Heath, R. C. (1983), Basic ground-water hydrology, USGS Water-Supply Paper 2220, p. 9 table (2004 printing): https://www.nrc.gov/docs/ML1417/ML14171A704.pdf
- Johnson, A. I. (1967), Specific yield: compilation of specific yields for various materials, USGS Water-Supply Paper 1662-D: https://pubs.usgs.gov/publication/wsp1662D (the averages are as tabled in the Wikipedia article on specific storage: https://en.wikipedia.org/wiki/Specific_storage)
- Minnesota Stormwater Manual, Aquifer hydraulic properties (from Morris and Johnson 1967, USGS WSP 1839-D, and Duffield): https://stormwater.pca.state.mn.us/Aquifer_hydraulic_properties
- MacDonald, A. M. and Allen, D. J. (2001), Aquifer properties of the Chalk of England, QJEGH 34: 371 to 384: https://nora.nerc.ac.uk/id/eprint/14088/1/chalk_NORA.pdf
- Wealthall, G. P., Thornton, S. F. and Lerner, D. N., The Chalk aquifer (University of Sheffield, on Solinst): https://www.solinst.com/resources/cmt/ukchalk/ukchalk3.php
- Nevada Bureau of Mines and Geology (1994), Analysis of well hydrographs in a karst aquifer: estimates of specific yields and continuum transmissivities, ORNL Y/TS-1263: https://www.osti.gov/biblio/39787
- Kuniansky, E. L., Taylor, C. J. and Paillet, F. L. (2022), Introduction to karst aquifers, GW-Project, section 3.3: https://books.gw-project.org/introduction-to-karst-aquifers/?p=354
- Baird, A. J., Milner, A. M., Morris, P. J. and Green, S. M. (2024), The effect of wetting history, botanical composition and depth on the specific yield of two common types of bog peat, Hydrological Processes 38(7) e15226: https://eprints.whiterose.ac.uk/id/eprint/214696
