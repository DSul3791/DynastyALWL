# Water clarity after rain: how fast rivers and lakes go cloudy and clear

**Last checked:** 2026-11-08 (web research by Jamie). **System owner:** Kathleen (water look); Sonny (the record's sediment fields). **Asked by:** Kathleen, `docs/design/art_water.md` (#587) section 11: "a clarity value that follows rain and snowmelt over hours (not only the stored 'cloudy after rain' class)". **Related:** [water.md](water.md), [rivers-floodplains.md](rivers-floodplains.md), `docs/water/watershed_rebuild_design.md` (the record's sediment load per reach: clear, cloudy after rain, silty).

"Our sums" means arithmetic done here from a sourced formula. "Judged" means no source was found today.

## Lessons (read these first)

1. **Mountain streams cloud quickly and clear within about three days.**
   - In mountainous forested catchments, turbidity rises with the flow and peaks slightly before it. It "generally returns to baseline within 72 hours of peak flow" (Oregon DEQ, turbidity technical review).
   - **Measured case,** the South Fork McKenzie, a forested river:
     - the longest spell above 150 FNU lasted about 10 hours;
     - above 55 FNU, about 36 hours;
     - above 20 FNU, about 2 days;
     - above 5 FNU, about 5 days.
   - **Clear baseline:** headwater streams are under about 3 NTU in summer, and mountain forest streams under 2 NTU in the wet season. Even in big storms the 90th percentile is about 10 FNU in such catchments.
2. **Lowland, urban or clay-rich streams stay cloudy far longer.**
   - Urban Beaverton Creek stayed above 20 FNU for about 9 days, often for days to weeks. Clay particles stay up longest (Oregon DEQ).
   - The Upper Tame (urban, West Midlands) reached peaks over 500 FTU, with long turbid tails after the flood had passed (Lawler et al., IAHS).
3. **The cloud comes in with the first flush, but not always.**
   - Clockwise hysteresis is the usual pattern: turbidity peaks before the flow peak because loose sediment near the channel goes first.
   - Some storms lag instead. In June 2001 on the Tame, turbidity peaked slightly after the flow (Lawler et al.).
   - **For us:** start the clouding with the rising water, peak at or a little before the peak flow, then clear on a longer tail.
4. **Settling sets how fast still water clears. Grain size decides it.**
   - Stokes' law: w = (ρs − ρw) g D² / 18 μ. It holds for very fine sand and finer (Geological Digressions, "Fluid flow, Stokes law and particle settling").
   - Our sums at 10 °C (μ = 1.31 mPa·s, quartz):

     | Grain | Settling speed | Through 1 m of water | Through 10 m |
     |---|---|---|---|
     | Fine sand, 100 µm | 25 m/h | 2.4 min | 24 min |
     | Coarse silt, 62 µm | 9.5 m/h | 6 min | 1 h |
     | Medium silt, 30 µm | 2.2 m/h | 27 min | 4.5 h |
     | Fine silt, 10 µm | 6 m/day | 4 h | 1.7 days |
     | Very fine silt, 4 µm | 0.95 m/day | 1 day | 10 days |
     | Clay, 2 µm | 0.24 m/day | 4 days | 6 weeks |

   - Running water stays mixed, so only fine sand and coarse silt drop out while it flows. The cloud a stream carries after rain is mostly silt and clay. It clears as the supply stops, not as the cloud settles.
   - **Lakes do clear by settling.** A shallow pond loses its silt cloud in hours to a day. A deep lake keeps a faint clay haze for weeks, which is the milky look of glacier-fed lakes. Real clay often clumps (flocculates) and falls faster than Stokes predicts, and wind keeps a shallow lake stirred. Both points are general knowledge, not checked today.
5. **Peat water is a colour, not a cloud.**
   - Brown water from bogs and wetlands is high in dissolved organic carbon (Telford and Wrekin Council, foam in rivers and still waters).
   - Dissolved colour does not settle: tea-brown streams stay brown when calm.
   - **Our reading, judged:** in peat country the colour gets stronger after rain, because the rain flushes the bog. It fades over days to weeks, not hours.
6. **Snowmelt is a daily pulse.** Melt peaks in the afternoon, so a snow-fed or glacier-fed river runs higher and cloudier from late afternoon into the evening and clears a little by morning. This is general knowledge, not checked today.

## A model for the game (judged, for Kathleen and Sonny)

Carry one clarity value per reach or lake, from 0 (clear) to 1 (opaque brown).

**Rivers.** Clarity follows the record's sediment class and the weather's rain.
- **Clouding:** rises with `Weather.river_push` (the rain's push on the flow), with a lag of about 1 to 2 hours for small streams.
- **Clearing,** half-life by sediment class:

  | Sediment class | Half-life |
  |---|---|
  | Clear (rock and gravel beds) | 12 h |
  | "Cloudy after rain" | 24 h |
  | Silty | 3 days |

  So a mountain stream is back to clear about 3 days after a storm, as the Oregon data says.
- **Peat colour:** a separate brown term with a 7-day half-life, for reaches fed from bogs.
- **Snowmelt:** a daily term on snow-fed reaches, peaking at about 17:00 (warmest hour plus a lag).

**Lakes and ponds.** A lake takes the clarity of its inflow, then clears by settling.
- Half-life about depth / (3 m/h) for silt, judged from the medium silt row above.
- A deep lake keeps 10% of the cloud as a clay haze for 2 weeks.

**Never-see checks:**
- a clear river right below a brown tributary for more than a few hundred metres. The mix line should show along one bank first, then blend.
- a muddy mountain stream four days after rain.
- a peat stream that runs clear blue after rain.

## How ours works today

- The record design gives each reach a fixed sediment load class (clear, cloudy after rain, silty) and a peat colour flag (`docs/water/watershed_rebuild_design.md`).
- The water shader has no time-varying clarity yet (not checked in code for this page).
- The live weather gives `river_push` (dry 0, heavy rain 0.6, storm 1).

## Sources

- Oregon DEQ, Water quality standards: turbidity technical review: https://www.oregon.gov/deq/FilterDocs/TurbidityTechRev.pdf
- Lawler, D. M. et al., Turbidity dynamics during spring storm events in an urban headwater river system, the Upper Tame (IAHS): https://iahs.info/uploads/dms/13538.16-96-103-45-306-Lawler-et-al-edited.pdf
- Geological Digressions, Fluid flow, Stokes law and particle settling: https://www.geological-digressions.com/fluid-flow-stokes-law-and-particle-settling/
- Telford and Wrekin Council, Foam in rivers and still waters: https://telford.gov.uk/download/downloads/id/28515/foam_in_rivers_and_still_waters.pdf
