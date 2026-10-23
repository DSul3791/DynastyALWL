# Island shape research (Guru, 23 Oct, for Dave's "too flat, then a wall" note)
Dave's screenshot (build 727, x 52361 z 68193): a wide flat lowland, then mountains rising at once at the back. Real mountainous islands almost never look like that.

## What I could verify online (sources fetched today)
- Shield volcanoes (Hawaii): very gentle slopes. Mauna Loa's flank is about 1 in 9, roughly 6 degrees, from the summit to far below sea level; summit about 4 km above sea level, base about 5 km below ([Appalachian State shield volcano page](https://appstate.edu/~abbottrn/vlcns/vlcnos.html)). So even the "flat" shield rises steadily the whole way from the coast.
- Hawaii erosion stages ([UH Hawaii natural environment](https://www2.hawaii.edu/~dennis/GeoBook/chapter11/hawaii.htm)): young islands (Hamakua coast, Big Island) have deep valleys separated by wide, flat slopes; old islands (East Kauai) end up with flat plains near sea level and tall steep cliffs (palis) in the interior. Valley heads widen and merge inland.
- Japan ([Stanford SPICE](https://spice.fsi.stanford.edu/docs/geography_of_japan)): mountains are over 80% of the land; no one lives more than about 70 miles from the coast; rivers are short, fast and small; settlement is in long narrow valleys and a few coastal plains (Kanto about 120 miles long).
- Not found online in numbers: foothill widths, ridge spacing, elevation vs distance. The next list is from standard geomorphology and my own judgement, to be checked by Sonny against a real height map if one can be fetched.

## Shape rules to copy (confidence in brackets)
1. Height rises with distance from the coast as a smooth curve, not a step: gentle at the beach, steeper inland (concave profile). Typical: first 1 km up about 20-60 m, by 3 km about 150-400 m, mountains beyond. A flat plain wider than about 1-2 km is rare on these islands except river deltas and old uplifted terraces [medium].
2. Foothill belt: between the coastal strip and the high peaks sits a belt of rolling hills, ridges and spurs, about 20-30% of the distance coast to peak. This is what our map lacks [high].
3. Ridges and valleys run downhill from the high ground roughly radially (on a volcano) or along the range (Japan). Valleys are V-shaped and deeper inland, with ridge spacing roughly 300-800 m near the coast and more inland [medium, to check].
4. Rivers are short and steep, carve gorges in the hills, and form fans and small flat valley floors at the foot. Flat land comes from rivers (fans, floodplains), not from the island as a whole [high].
5. Sea cliffs and steep headlands where waves cut the slope; beaches only in bays and at river mouths [high].
6. The slope belongs to the rock: young lava = smooth broad slopes; old = deeply cut valleys, narrow ridges, cliffs [high].

## Proposed plan for the generator (to refine with Sonny)
1. Replace the current flat-then-steep height curve with a coast-distance profile (concave curve): small slope at the coast, 8-15 degrees in the foothills, 25+ degrees in the mountains.
2. Add a foothill belt: rolling hills and ridges, using a noise amplitude that grows with height (low noise near sea level, bigger inland).
3. Make big valleys first (from Terrain B rivers), then let ridges follow between them, so valleys and ridges point downhill together.
4. Keep a few real flat areas on purpose: river floodplains, a coastal terrace, the lakes' shores. That is where towns go.
5. Beaches only at bays and river mouths; headlands steeper with sea cliffs.
6. Test on one tile first (1-tile BAKE test by MikeW), compare section views against the profile numbers, then a 9-tile bake with Dave's go.
Recommendation: yes to all six, done in this order, starting with 1 and 2 because they fix what Dave sees.

---
# Part 2: island types by origin (added after Dave's 14:51 note)
Dave: islands differ by how they formed: some low and rounded, some very high and peaked; some have long sweeping beaches, some rocky shores. Source for the type list: [New World Encyclopedia, Islands](https://www.newworldencyclopedia.org/entry/Islands) (it names the origins but gives no heights, so the numbers below are standard geomorphology from my own knowledge, marked [medium] and to be checked by Sonny against real height maps).

| Type (examples) | Height and profile | Slopes | Shoreline | Rivers and valleys |
|---|---|---|---|---|
| **Hotspot shield, young** (Big Island) | Huge, rounded dome, summit 1-4 km, one smooth profile | 3-8 degrees flanks, steeper (20-30) only at coastal cliffs | Black rocky shores, sea cliffs where lava meets sea, few beaches | Few rivers (rain soaks into lava); some deep young valleys on the wet side |
| **Hotspot shield, old, eroded** (Kauai, Oahu, La Reunion) | Eroded dome, peaks and ridges still 1-2 km, huge amphitheatre valleys and spires | 30-60 degrees in the cut valleys and palis, gentle ridgetops | Rocky headlands, beaches in bays and river mouths, a flat coastal plain/terrace | Radial rivers from the wet summit, deep V and U valleys, waterfalls |
| **Volcanic arc, stratovolcano** (Japan volcanoes, Java, Luzon) | Tall steep cone or chain of cones, 1-3.7 km | 25-35 degrees upper cone, concave skirt 5-10 degrees below | Mixed: black sand beaches, cliffs; steep drop offshore | Radial gullies on the cone, rivers build fans on the skirt |
| **Arc / folded mountain island** (Honshu, Taiwan, Corsica, Shikoku) | Long mountain spine 1-4 km, ridges parallel to the coast | 20-45 degrees, narrow valleys | Rocky coast with small bays; plains only at river mouths | Many short steep rivers, gorges, fans |
| **Continental fragment** (Britain, Tasmania, Newfoundland) | Low to moderate, hills and some peaks under about 1.5 km, rounded by glaciers or age | 5-20 degrees | Mixed: long beaches, cliffs, estuaries, sandy spits | Longer meandering rivers, wide valleys, lakes |
| **Glacial / fjord island** (Norway coast, Chile, Hebrides) | Rugged, 500-2000 m, glacier-carved | Cliffs 60+ degrees, U valleys | Fjords, steep rocky coast, skerries | Short torrents, hanging valleys, lakes |
| **Fault-block / tilted** (Sicily parts, Sumba, Sardinia) | One steep side, one gentle side | Steep scarp, long gentle back slope | Cliffs on the steep side, beaches on the gentle side | Rivers flow down the long gentle side |
| **Coral / atoll / low sand** (Maldives, Bahamas, Florida Keys) | 1-5 m above sea, flat | Almost none | Long white beaches, lagoons, reef | No surface rivers, freshwater lens |
| **Delta / barrier** (Mississippi, Outer Banks) | Under 5 m, flat | None | Long sweeping beaches and dunes, spits | Many channels, marsh |

Rules of thumb Dave's notes point to:
- **Height and slope follow rock age and origin**: young volcano = broad and smooth; old = high only where hard rock remains and cut deeply; sediment and coral = flat.
- **Beach vs rocky coast follows slope at the water and wave energy**: gentle slope + sediment from rivers + sheltered = long beach; steep slope or lava or hard rock + exposed = rocky shore.
- **Every real island has a mix on different sides**: windward side wetter and more eroded, leeward drier.

## Proposal: which type is OUR island (for Sonny to confirm or change)
Our centre island already has a crater, lava flows and a 1981 m peak, so by its story it is a **hotspot shield, middle-aged** (Kauai / La Reunion type), not a new type. The other islands in island_list.json can be assigned types by size and peak height.
1. **Centre island = eroded hotspot shield**: high central peak (about 1981 m) with a smooth concave rise from the coast, a foothill belt of radial ridges and spurs, 6-10 big radial valleys (Terrain B rivers), steep headwalls near the summit, flat river fans and a coastal terrace at the foot, rocky headlands with beaches in bays.
2. **Island types by peak height** (so the world varies): peak under 15 m = low sand/coral island (beaches all round); 15-150 m = low rounded continental-style island (hills, long beaches, estuaries); 150-700 m = rounded hilly island with mixed coast; 700+ m = peaked volcanic or mountain island like the centre one. Sonny can set the thresholds.
3. **Per-island "type" in the plan data** (island_list.json gets a type field) that sets the generator's height profile, ridge and valley strength, and the beach vs cliff rule. Beach vs cliff: beach where the slope at the coast is under about 5 degrees and a river or bay supplies sand; otherwise cliffs and rocks.
4. **Windward/leeward**: the wet side gets deeper valleys and more rivers, the dry side smoother.
5. **Order of work**: profile and foothills for the centre island first (what Dave sees), then the type field, then coast rules, then other islands. 1-tile test bake, then a 9-tile bake with Dave's go.
STATUS: Guru draft; waits for Sonny's side (what the current generator can do and the cost of each step) before the 5-10 line plan goes to Dave.
