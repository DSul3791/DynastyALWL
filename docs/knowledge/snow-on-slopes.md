# Snow on slopes: wind drift, scour, and melt order by aspect

**Last checked:** 2026-11-08 (web research by Jamie). **System owners:** Sonny (the record's `snow_on` and `snow_off` bytes, A4 in `docs/water/watershed_rebuild_design.md`); Kathleen (summit snow look). **Related:** `snow-lines-mountain-climate.md` (#594, snow lines and degree-day melt), `docs/design/one_temperature.md` (#620, the island climate), [warmth-weather.md](warmth-weather.md).

"Our sums" means arithmetic done here from a sourced formula. "Judged" means no source was found today.

## Lessons (read these first)

1. **Wind moves snow from windward slopes onto lee slopes.**
   - **Ben Nevis, Aonach Mòr** (SAIS Lochaber, "Snow redistribution", Feb 2016): an east wind blew snow out of Aonach Mòr's east face and built windslab on the west face. Smooth pillows formed in sheltered spots, while raised footprints showed where soft snow had been scoured away.
   - **Prevailing wind:** in the Scottish hills the prevailing south-westerlies give "the deepest deposits of old snow on North to East aspects" (SAIS Lochaber, "It's all about aspect", March 2025).
   - **Cornices** build out over the lee edge of crests and corrie rims, and their size differs from crag to crag (SAIS, Coire an Lochain).
2. **Wind starts moving snow at about 4 to 5 m/s.**
   - That is the threshold for new or slightly aged cold, dry snow. Wind-packing starts at about 5 m/s. Old, hard, bonded snow needs far more: a threshold friction velocity of about 1.7 m/s, roughly 40 m/s at 10 m, counts as immovable (Liston et al. 2007, SnowTran-3D).
   - **Vegetation holds snow up to its height** before any can blow away (SnowTran-3D). Heather and grass hold a few tens of centimetres, and forest holds its snow almost entirely.
   - **Drift shape:** lee drifts build to an equilibrium surface slope of about 24% in Colorado and Wyoming and 29 to 36% in arctic Alaska, that is about 13 to 20 degrees (SnowTran-3D, citing Tabler).
3. **Sun decides the melt order. Slopes facing away from the noon sun keep their snow.** In Scotland that is the north. On our starter island, at 57° S with the noon sun in the north (`one-sky.md`), it is the **south**.
   - In late winter the east-to-west aspects (through south) lose their soft surface snow to the sun, while "high, steep, shady North-West to North-East aspects" stay wintry (SAIS, "It's all about aspect").
   - **Our sums:** clear-sky direct sun on a 30° slope against flat ground, at 57° S (the starter island, `one-sky.md`), as a daily total:

     | Season | South | South-east | East | North | North-west | South, 45° slope |
     |---|---|---|---|---|---|---|
     | August (late winter) | 0 | 0.24 | 1.17 | 2.62 | 2.14 | 0 |
     | Equinox | 0.10 | 0.52 | 1.07 | 1.64 | 1.48 | 0 |
     | November | 0.72 | 0.78 | 0.98 | 1.07 | 1.07 | 0.50 |
     | December (midsummer) | 0.83 | 0.84 | 0.97 | 0.98 | 1.00 | 0.66 |

     In August a south 30° slope gets no direct sun at all, because the noon sun is only 19.5° high. By December the aspects nearly even out, so the melt-order difference is set in late winter and spring. Steep south walls of 45° stay shaded into November. (The Scottish figures in this lesson are the same physics mirrored: their north is our south.)
4. **The last snow lies in shaded, wind-filled hollows below lee cliffs (north-east in Scotland, south-east on our island), at about 80 to 85% of summit height.**
   - **Ben Nevis:** Observatory Gully, below the north-east cliffs at about 1,130 m (the summit is 1,345 m), holds the mountain's largest patch. It has been snow-free only once since 2006 (2017). Point 5 Gully, a little lower, also survives from one winter to the next.
   - **Braeriach:** Garbh Choire Mòr, at about 1,140 m, holds "Britain's most persistent snow beds". They have been absent only 12 times in a century.
   - **Aonach Beag:** a patch below its north-east ridge cliffs, at about 955 m, was Scotland's largest after the 2007 and 2008 winters.
   - **Other hills:** in Glen Affric and Strathfarrar, the Grey Corries and Ben Wyvis, the last patches usually melt in July or August (Wikipedia, Snow patches in Scotland).
   - **Our reading:** every long-lived patch sits below cliffs, in a hollow or behind a protalus rampart. These are places where the wind dumps snow and the sun does not reach. The page itself does not say why.
   - **This matches Sonny's A4 rule:** summer patches at 80 to 85% of summit height, in lee and shaded gullies. 1,130 / 1,345 is 84%.
   - **On our island** the mirror of Scotland's north-east is the **south-east**: shaded from the northern noon sun, and in the lee of westerly winds.

## Judged numbers for the record's snow window and the look

These are proposals for Sonny's `snow_on` and `snow_off` bytes and for Kathleen's summit snow, to check on pictures.

**Wind exposure index** from the terrain, per cell, relative to the prevailing wind (judged: from the west to north-west on the starter, the southern westerlies at 57° S; the weather has no prevailing direction yet):
- **Lee and filled:** hollows, gullies and the first 50 to 150 m below a crest, downwind. Snow depth is **2 to 5 times** the open-ground mean. The deepest drifts are in gullies below crests.
- **Open slopes:** about the mean.
- **Windward slopes and crests:** **0 to 0.3 times** the mean. Crests are scoured to rock or turf, apart from snow caught in rocks.
- **Cornices:** on lee crest edges steeper than about 35° below. A lip of 1 to 3 m on the starter, to check by eye.
- **Moving snow:** only after a fall, while the weather's wind is strong, about 0.5 or more on our 0 to 1 scale. On the shared mapping in `wind-over-terrain.md` (m/s = 20 × wind^1.3) that is about 8 m/s. Real fresh snow starts moving at 4 to 5 m/s, about 0.35, so 0.5 keeps drifting to clearly windy days (judged; see `CONTRADICTIONS.md` A4). Snow older than about 2 days is treated as set.

**Melt order:** shift each cell's `snow_off` later by aspect and shade, and by drift depth.
- **By aspect and shade** at the same height:

  | Slope faces | snow_off |
  |---|---|
  | North | baseline |
  | East or west | 1 to 2 weeks later |
  | South, gentle | 2 to 4 weeks later |
  | South, steep and shaded (below cliffs) | 4 to 8 weeks later |

- **By drift depth:** a drift 3 times as deep lasts about 3 times as long under the same melt. The snow lines page's degree-day factor of about 5 mm per °C per day applies to each cell's snow.
- **Where summer patches can survive:** only where the lee drift index and south-east shade both apply, above about 80% of summit height.

**Never-see checks:**
- an even white blanket on a windward summit after a windy week;
- the last snow of spring on a north-facing open slope (the sunny side at 57° S);
- deep snow in forest canopy gaps on a windward crest;
- a cornice on the windward side.

## How ours works today

Not checked in code for this page.
- The record design carries two snow bytes per 16 m cell (`snow_on`, `snow_off`) in the R6 record, read at R7.
- The weather has `wind` from 0 to 1 and `wind_dir`, but no prevailing direction per island.
- The ground snow on the client is player-side only (`weather_sounds.gd` `ground_snow`).

## Sources

- SAIS Lochaber, Snow redistribution (Feb 2016): https://lochaberblog.sais.gov.uk/2016/02/snow-redistribution
- SAIS Lochaber, It's all about aspect (March 2025): https://lochaberblog.sais.gov.uk/2025/03/its-all-about-aspect
- Liston, G. E. et al. (2007), Simulating complex snow distributions in windy environments using SnowTran-3D, Journal of Glaciology: https://www.cambridge.org/core/services/aop-cambridge-core/content/view/9D28335437B0D4732991D0137A96EDFD/S0022143000201330a.pdf/simulating_complex_snow_distributions_in_windy_environments_using_snowtran3d.pdf
- Wikipedia, Snow patches in Scotland: https://en.wikipedia.org/wiki/Snow_patches_in_Scotland
- The sun sums use the standard solar geometry (declination, hour angle, slope normal) at 57° S, the starter island's latitude (`one-sky.md`).
