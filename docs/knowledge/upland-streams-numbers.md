# Upland streams: density, floods, channel size, waterfalls and deltas

**Last checked:** 2026-11-08 (web research by Jamie). **System owner:** Sonny (watershed rebuild, step R5 and on). **Related:** `docs/water/Dynasty_How_Natural_Watersheds_Work.md` (Dave's document; it governs, and this page only adds numbers), `docs/water/watershed_rebuild_design.md`, [rivers-floodplains.md](rivers-floodplains.md), [water.md](water.md).

Five numbers asked for by R5. Each one says where it came from. "Our sums" means arithmetic done here from a sourced formula. "Judged" means no source was found and the number is a proposal.

## Lessons (read these first)

1. **Stream density: about 2 to 2.5 km of mapped stream per km² in a wet slate upland. The real network in the field is 2 to 5 times longer.**
   - **Plynlimon, mid-Wales** (the UK's main measured upland catchments, on Ordovician and Silurian mudstones, shales and slates, about 2,550 mm of rain a year):
     - Severn headwater: drainage density **2.40 km/km²** over 8.70 km².
     - Wye headwater: **2.04 km/km²** over 10.55 km².
     - Source: Kirchner 2009, table 1.
   - **Mapping scale matters more than climate.** A recent global study found field-mapped drainage density averages **10.5 km/km²** (344 sites). In its own study catchments it ranged from **1.4 to 14.2** (mean 5.1). Global map networks show only about 0.5. Most of the missing length is in headwaters, much of it not flowing all year (Nature Water 2025, "Headwater streams control the non-perennial fraction of the global river network").
   - **Most real stream length is not perennial.** That study put the non-perennial share at about 0.6 of length in Italy and the eastern USA, and 0.78 worldwide. It also notes that coarse maps show cool, very wet sites as almost all perennial, which is where the gap is largest.
   - **What this means for us.**
     - For **perennial streams drawn with water all year**, use about **2 to 2.5 km/km²** on granite or slate in a wet upland. That is the Plynlimon figure, and it is about what a 1:25,000 map shows.
     - For **dry or seasonal channels** (gullies, flushes, runnels that only run after rain), allow another **2 to 3 times that length**.
     - Granite with thin peat behaves like slate here: both are close to watertight. Permeable rock (sandstone, limestone) gives fewer streams. No sourced figure for that was found today.
   - Not found: a measured figure for the Scottish Highlands, the Lake District or western Norway themselves. Plynlimon is the same kind of country (wet, steep, watertight rock).

2. **The bankfull flood is about 15 to 50 times the mean flow in small, wet, watertight UK uplands. The ratio falls as the catchment grows, and permeable rock lowers it.**
   - **Bankfull is close to the median annual flood.**
     - In Irish gravel-bed rivers (about 85 gauged sites), the median bankfull recurrence was **1.64 years** (Bankfull discharge and recurrence intervals in Irish rivers, White Rose eprint 82650).
     - Hey (1975) found the 1.5-year flow ran through the measured bankfull flows of three British gravel-bed rivers. Hey (1994) put 78% of bankfull return periods between 1.01 and 3 years (both quoted in Soar and Thorne 2001, USACE ERDC/CHL CR-01-1).
     - So treat **bankfull ≈ 0.9 × QMED** (the median annual flood, a 2-year flood). The 0.9 is judged from the shape of UK growth curves, not sourced.
   - **The measured case, Plynlimon** (Kirchner 2009, slate, 9 to 11 km²):
     - Severn: mean flow 0.23 mm/h, average annual maximum 5.81 mm/h, a ratio of about **25**.
     - Wye: mean flow 0.24 mm/h, average annual maximum 6.54 mm/h, about **27**.
     - The averages are our sums from the table.
   - **The UK design formula (FEH 2008)**, for catchments from 1.6 to about 10,000 km², with a factorial standard error of 1.43:
     QMED = 8.3062 · AREA^0.8510 · 0.1536^(1000/SAAR) · FARL^3.4451 · 0.0460^(BFIHOST²)
     - QMED is in m³/s, AREA in km², and SAAR is average annual rain in mm.
     - FARL is the lake attenuation factor (1 with no lakes).
     - BFIHOST is the baseflow index from soil type: about 0.3 on peat over granite or slate, 0.6 or more on permeable rock.
     - Sources: UKFE R package documentation; Environment Agency report SC090031 R4 on QMED for small catchments.
   - **Our sums from that formula**, ratio QMED / mean flow, with SAAR 2,000 mm, evaporation 450 mm and no lakes:

     | Catchment | BFIHOST 0.3 (peat on granite or slate) | 0.45 | 0.6 (permeable) |
     |---|---|---|---|
     | 1 km² | 50 | 36 | 22 |
     | 10 km² | 36 | 25 | 16 |
     | 100 km² | 25 | 18 | 11 |

     - The 10 km² watertight cell (36) is a little above Plynlimon's measured 25 to 27, which is within the formula's error. At 2,500 mm of rain the ratios barely change (47, 33, 24 for BFIHOST 0.3).
     - **Lakes on the line cut the peak.** FARL 0.9 multiplies QMED by about 0.7.
     - The catchment-size trend is AREA^0.85 for the flood against AREA^1 for the mean, so the ratio falls as AREA^-0.15.
   - **Rock matters through BFIHOST, not directly.** The Irish study found no clear link between baseflow index and bankfull flow in its own data. It cites Harvey (1969) for return periods rising with bedrock permeability.

3. **Hey and Thorne (1986): the width equations are confirmed. The depth equation was not confirmed from the paper itself.**
   - **Paper:** Hey, R. D. and Thorne, C. R. (1986), "Stable channels with mobile gravel beds", Journal of Hydraulic Engineering 112(8), 671 to 689. It covers 62 British gravel-bed reaches. The paper itself is behind a paywall; the numbers below come from handbooks that quote it.
   - **Units:** SI. W is bankfull width in m, Q is bankfull discharge in m³/s, D50 is the median bed grain size in m, and Qs is bedload in kg/s.
   - **Simple form, width from discharge and bank vegetation only**, W = a · Q^0.50 (USDA NRCS NEH Part 654 chapter 9, table 9-6; Eaton 2010):

     | Bank vegetation type | a |
     |---|---|
     | I: grassy banks, no trees or shrubs | 4.33 |
     | II: 1 to 5% tree and shrub cover | 3.33 |
     | III: 5 to 50% tree and shrub cover | 2.73 |
     | IV: over 50% tree and shrub cover, or incised into the floodplain | 2.34 |

     Eaton 2010 prints 2.43 for type IV. NRCS and USACE EM 1110-2-1418 both give 2.34, so use 2.34.
   - **Full form with bedload**, W = a · Q^b · Qs^-0.01 (River Restoration Centre regime handout, after Soar and Thorne 2001):

     | Type | a | b |
     |---|---|---|
     | All data | 3.67 | 0.45 |
     | I | 3.98 | 0.52 |
     | II | 3.08 | 0.52 |
     | III | 2.52 | 0.52 |
     | IV | 2.17 | 0.51 |

     The handout's column layout makes the -0.01 term slightly unclear. Use the simple form unless bedload is known.
   - **Mean depth.**
     - It depends on Q and D50 but **not** on bank vegetation (Eaton 2010). The Q exponent is about 0.39 (Parker et al. 2007, quoting Hey and Thorne).
     - The form usually quoted is **d = 0.22 · Q^0.37 · D50^-0.11** (d in m). It is given here from memory and was **not found in a checkable source today**, so treat it as unconfirmed until someone reads the paper.
     - A sourced alternative that does not need D50 is Parker et al. 2007's fit to gravel-bed rivers worldwide: **d = 0.382 · Q^0.4 / g^0.2 ≈ 0.24 · Q^0.4**. Parker notes that the British reaches run narrower and deeper than that fit, and that denser bank vegetation gives narrower channels.
   - **Our sums.** At Q = 1, 10 and 50 m³/s on grassy banks (type I): W ≈ 4.3, 13.7 and 30.6 m.
     - With 50 mm gravel, the unconfirmed depth form gives d ≈ 0.31, 0.72 and 1.3 m.
     - Parker's fit gives 0.24, 0.61 and 1.1 m.
   - **Handbook warning** (NRCS): these relations are for first sizing. Depth and slope are less reliable than width.

4. **A real waterfall needs a step the river cannot cut down: hard rock over soft, a glacial hanging valley, or a fault.**
   - **Caprock.** A resistant bed sits over weaker rock. The weak rock below is undercut into a rock shelter, the cap breaks off in blocks, and the blocks grind a deep plunge pool. The fall retreats upstream and leaves a gorge (Wikipedia, Waterfall).
     - Retreat is usually **1 mm to 10 cm a year**. Niagara slowed from about 1 m a year around 1900 to about 10 cm now (Wikipedia, Knickpoint). The highest rate quoted is 1.5 m a year (Wikipedia, Waterfall).
     - The best-known example is Victoria Falls: a hard basalt sill with soft sandstone in its cracks.
   - **Hanging valleys.** The trunk glacier carries more ice and cuts deeper than its tributaries, so the side valleys are left hanging when the ice goes. Falls form where a tributary meets the trough high on its steep wall, as at Yosemite (Britannica, Hanging valleys).
     - The hang height is set by how fast each glacier slid. In 46 hanging valleys in Jasper National Park, catchment area, slope and width explained 55 to 85% of the hang height (Amerson et al. 2008).
     - **Heights.** River-cut hanging valleys run from a few tens of metres up to about 1 km in the Himalaya, and about 500 m in Taiwan (Goode and Burbank 2009). Bridalveil Fall at Yosemite, for scale, drops about 190 m (general knowledge, not checked today).
     - Unlike an ordinary knickpoint, a hanging-valley step stays **pinned at the junction** and does not walk upstream. It is often more than 10 times steeper than the tributary just above it, where knickpoints are 1.2 to 2 times steeper (Goode and Burbank 2009).
   - **Falls can also form with no rock contrast at all.** Scheingross et al. 2019 (Nature) made waterfalls form by themselves in a flume, from feedback between sediment and erosion. They are rare, and a game should not need them.
   - **One fall or a run of cascades.**
     - **No sourced count was found** of how often a step is one fall against a run of cascades.
     - From the type definitions: one thick hard bed gives a single plunge. Several thin hard beds give a tiered fall, roughly equal steps each with its own pool. A broken or jointed face gives a cascade down rock steps. A hanging-valley lip over a glacier-smoothed wall often gives a long horsetail that keeps touching the rock (Wikipedia, Waterfall).
     - **Judged rule for us:** a single fall only where the geology has one hard bed thicker than about half the step. Otherwise a tiered fall or a cascade. Test it on pictures.
   - **Sizes.** A waterfall is usually defined as at least 1.5 m high (some use 6 m). By one definition, the lip-to-pool distance is at most a quarter of the height (Mabin 2000, quoted in Wikipedia, Waterfall). This fits Dave's law: "a waterfall never steps."

5. **Waves stop small-river deltas almost everywhere on an open coast. A small river builds a delta only in sheltered water: a lake, a fjord head, or a bay with a few kilometres of fetch.**
   - **The balance (Nienhuis et al. 2015, Geology 43, 511 to 514; Coastal Wiki):**
     - R = Q_river / Q_wave, where Q_river is the river's sand supply and Q_wave is the waves' power to carry sand away from the mouth, both in kg/s.
     - For waves straight onshore, Q_wave = 90 · Hs^2.4 · Tp^0.2, with Hs the significant wave height (m) and Tp the peak period (s).
     - R above 1 gives a river-dominated delta that pushes out. R toward 0 gives a smooth, wave-dominated coast.
     - Waves at about 45° to the shore move the most sand.
   - **Global survey (Caldwell et al. 2019, Earth Surface Dynamics 7, 773; 5,399 coastal rivers over 50 m wide):**
     - About **40%** of those rivers have deltas.
     - Rivers with a mean significant wave height **below 1 m** form deltas more than half the time. Above that it becomes nearly impossible.
     - Deltas have about ten times the water, sediment and basin area of mouths without one. Small rivers rarely build them, and the survey left out rivers narrower than 50 m.
   - **Wave height from fetch.** The deep-water, fetch-limited JONSWAP growth law gives Hs = 0.0016 · (gF/U²)^0.5 · U²/g and Tp = 0.286 · (gF/U²)^(1/3) · U/g, with F the fetch (m) and U the wind at 10 m (University of Wisconsin CEE 514 coastal engineering notes).
   - **Our sums with those laws:**

     | Fetch | Wind 8 m/s: Hs, Q_wave | 12 m/s: Hs, Q_wave |
     |---|---|---|
     | 0.5 km | 0.09 m, 0.3 kg/s | 0.14 m, 0.8 kg/s |
     | 2 km | 0.18 m, 1.7 kg/s | 0.27 m, 4.5 kg/s |
     | 10 km | 0.41 m, 13 kg/s | 0.61 m, 35 kg/s |
     | 50 km | 0.91 m, 98 kg/s | 1.37 m, 270 kg/s |
     | Open ocean (300 km+) | 2.2 m, 950 kg/s | 3.4 m, 2,600 kg/s |

     - A small upland river carries very little sand. At an assumed (not sourced) 20 to 30 t of bed sand per km² per year, a 10 km² catchment supplies about 0.006 kg/s, 50 km² about 0.03 kg/s, and 200 km² about 0.2 kg/s.
     - Waves only work part of the time, so the time-averaged Q_wave is lower than these single-wind values. Even so, R stays far below 1 on any open coast.
   - **Judged rule for us:**
     - On the open sea (mean Hs over about 0.5 m, fetch over about 20 km), no delta from rivers under about 500 km². The sand goes into the beach and spits next to the mouth.
     - In lakes and at fjord or sea-loch heads with fetch under about 2 to 5 km, small rivers build deltas, as Lake District lake heads show.
     - Gilbert deltas at lake inflows (R3) are the common case for us.

## How ours works today

Not checked in code for this page. These numbers are inputs for Sonny's R5 design: stream density sets the channel-head area, the flood ratio sets bankfull Q from mean Q, Hey and Thorne sets channel width, and the waterfall and delta rules feed C5 and C8. Sonny owns how they are used.

## Open items

- Read the Hey and Thorne (1986) paper itself to confirm the depth equation (and the slope, maximum depth and meander equations, which this search did not reach).
- Find a sourced figure for stream density on permeable rock and in the Highlands or western Norway.
- Find a sourced sand yield for UK upland catchments (Plynlimon's Leeks and Marks 1997 paper was unreadable online today).

## Sources

- Kirchner, J. W. (2009), Catchments as simple dynamical systems, Water Resources Research (Plynlimon table): https://seismo.berkeley.edu/~kirchner/reprints/2009_86_catchment_dynamical_systems.pdf
- Headwater streams control the non-perennial fraction of the global river network, Nature Water (2025): https://www.nature.com/articles/s44221-025-00549-x
- Bankfull discharge and recurrence intervals in Irish rivers (White Rose eprint 82650): https://eprints.whiterose.ac.uk/82650/
- Soar, P. J. and Thorne, C. R. (2001), Channel restoration design for meandering rivers, USACE ERDC/CHL CR-01-1: https://apps.dtic.mil/sti/pdfs/ADA383261.pdf
- UKFE R package, QMED: https://search.r-project.org/CRAN/refmans/UKFE/html/QMED.html
- Environment Agency, Estimating flood peaks and hydrographs for small catchments, R4 (QMED): https://assets.publishing.service.gov.uk/media/65fd8fda65ca2f00117da8f6/Estimating_flood_peaks_and_hydrographs_for_small_catchments_-_R4_-_Estimating_the_median_annual_flood__QMED_.pdf
- USDA NRCS, National Engineering Handbook Part 654, chapter 9: https://irrigationtoolbox.com/NEH/Part%20654/CHAPTERS/Chapter-09.pdf
- Eaton, B. C. (2010), Hydraulic geometry: empirical investigations and theoretical approaches: https://blogs.ubc.ca/beaton/files/2015/02/Eaton-2010-TiFG.pdf
- River Restoration Centre, regime analysis handout: https://www.therrc.co.uk/assets/files/Training/events_archive/RRC_Workshops/Module_1_2010/regime_analysis_handout_pjs.pdf
- Parker, G. et al. (2007), Physical basis for quasi-universal relations describing bankfull hydraulic geometry of single-thread gravel bed rivers: https://planetarygeoscience.uchicago.edu/doc/Parker_et_al_2007.pdf
- USACE EM 1110-2-1418, appendix B: https://webarchive.library.unt.edu/web/20130216143436/http:/publications.usace.army.mil/publications/eng-manuals/EM_1110-2-1418_sec/Sections/a-b.pdf
- Wikipedia, Waterfall: https://en.wikipedia.org/wiki/Waterfall
- Wikipedia, Knickpoint: https://en.wikipedia.org/wiki/Knickpoint
- Britannica, Hanging valleys: https://www.britannica.com/science/glacial-landform/Hanging-valleys
- Amerson, B. E. et al. (2008), Testing a glacial erosion rule using hang heights of hanging valleys, Jasper National Park (abstract): https://openpolar.no/Record/ftunivalaska:oai:scholarworks.alaska.edu:11122%2F11312/Details
- Goode, J. K. and Burbank, D. W. (2009), Numerical study of degradation of fluvial hanging valleys due to climate change: https://burbank.faculty.geol.ucsb.edu/Site/Publications_files/Goode&BurbankKinickpoints09%20copy.pdf
- Scheingross, J. S. et al. (2019), Self-formed waterfalls, Nature (news summary): https://phys.org/news/2019-03-evidence-self-forming-waterfalls.amp
- Nienhuis, J. H. et al. (2015), Geology 43, 511 to 514 (news summary): https://phys.org/news/2015-07-river-deltas.amp
- Coastal Wiki, Wave-dominated river deltas: https://coastalwiki.org/wiki/Wave-dominated_river_deltas
- Caldwell, R. L. et al. (2019), A global delta dataset and the environmental variables that predict delta formation on marine coastlines, Earth Surface Dynamics 7, 773: https://esurf.copernicus.org/articles/7/773/2019/
- University of Wisconsin CEE 514, JONSWAP fetch-limited waves: https://cosefm.cee.wisc.edu/CEE514_Coastal_Engineering/2008_Students_web/Khan_Hoilai/appendix.html
