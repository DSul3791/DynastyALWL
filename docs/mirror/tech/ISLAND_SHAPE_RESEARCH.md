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
