# Art direction for the mountains (design only, no code)

Kathleen, 8 Nov 2026, for Dave's decision D-10 and the relief plan. Basis: `art/Art_Direction.md` (85 percent realism, 15 percent storybook), `docs/design/GUIDING_DOCUMENT.md` section 5 (islands, archetypes), and the climate rules already in the code. This document **changes no code and no data**. Everything marked **[Proposal]** needs a decision by Dave or the owners of terrain (Sonny) and weather before it is built. I have not seen these mountains in the game yet: the pictures to collect are listed in section 10.

## 1. What Dave asked for

**[Dave, D-10]** Colossal, epic fantasy peaks on the starter island. Realistic, with a light fantasy exaggeration, photorealistic in finish. Relief differs per island:

| Island | Summit range | Personality |
|---|---|---|
| Starter | 1000 to 1450 m | Sea-level peaks: big for their height, the way Lofoten or the Cuillin are |
| Volcano | 1500 to 2300 m | One great cone or caldera wall |
| Three-peak | 2000 to 2700 m | Three named summits, a skyline you recognise at once |
| Giant | up to 3400 m | The one island players travel to see |

Plain-words rule for every decision below: **a mountain should look like it was made by rock, ice and water over a very long time, and then be 15 percent bigger, sharper and more beautiful than that.** The exaggeration goes into scale, steepness, light and colour; never into shapes that rock cannot make (no floating arches, no perfect cones outside the volcano island, no evenly spaced peaks).

## 2. Silhouette and spine shape

The silhouette is what a player sees from the town for hours; it must be recognisable, asymmetric and layered.

1. **Three levels of shape.** Every range has one primary summit (the hero), two or three secondary shoulders at 60 to 85 percent of its height, and many tertiary spurs. Heights never come in steps of equal size.
2. **A spine, not a row of pyramids.** The main ridge runs as a long, wandering line with saddles (cols) dropping 20 to 35 percent of the neighbouring peaks. Spurs leave the spine at 30 to 60 degrees and descend like fingers; valleys sit between them. The ridge line itself changes direction every 1 to 2 km.
3. **Two kinds of top.** Glaciated (young, granite, hard): serrated arêtes and horn summits whose top 100 to 200 m are 55 to 70 degrees. Weathered (old, softer rock): rounded shoulders with a broken cap. Use both on the same range; the highest peak is the glaciated one.
4. **Asymmetry.** One face steep (north or the weather side: cliffs, cirques), the opposite face a long, gentler slope with spurs. A symmetric peak is only allowed on the volcano island.
5. **Exaggeration allowed (the 15 percent):** vertical scale up to about 15 percent more than the real model would give for the same width; summit blocks that overhang slightly; one or two needle-like towers (gendarmes) on the hero's ridge; a notch in the skyline that works as a landmark. Not allowed: spikes thinner than 20 m, arches, anything that breaks the angles in section 5.
6. **Recognisable at 10 km.** Each island's skyline has one signature: a horn, a double summit, a cone with a notched rim, a long serrated wall. A player who has seen it once must know it again at dusk in silhouette.

## 3. Rock, snow and tree bands

What the code already says (not changed here): temperature falls **6.5 °C per km** of height; treeline is set near **half the island summit** (620 m default; 1245 m was noted for island 8); slopes steeper than **38 degrees** are bare rock, slopes over **26 degrees** carry scree; permanent snow starts below **-8 °C** and glacier ice below **-14 °C**.

**Bands from the bottom (starter island, summit 1000 to 1450 m), art rules:**

| Height share | What the eye sees |
|---|---|
| 0 to 35 percent | Forest and meadow, warm green, the town's valleys |
| 35 to 50 percent | Forest thinning; dwarf and wind-bent trees on ledges; heather and bracken, rusty in autumn |
| 50 to 65 percent (the treeline) | A ragged, honest edge: trees climb the sheltered valleys and stop on the windward ribs. Never a straight line |
| 65 to 85 percent | Alpine meadow in pockets, then scree, broken rock, lichen colours |
| 85 to 100 percent | Bare rock and snow patches |

**Snow rules.**
1. Snow lies where the slope is gentle, below about 45 degrees. Cliffs steeper than that stay dark with snow only on ledges and in gullies, which draws white streaks down the dark face. That streaking is what makes a snowy mountain look real.
2. Cornices (overhanging snow lips) hang on the lee side of ridges and make the ridge read as sharp.
3. Shadow faces keep snow lower and longer than sunny faces.
4. Winter pulls the snow line down to the treeline on every island; summer pushes it up to the permanent line.
5. **[Proposal, needs Sonny and weather]** With today's rule (-8 °C and 6.5 °C per km) a starter island with a mild sea-level climate **would show no snow at all** even on a 1450 m summit (snow would begin near 2000 m or more). Dave wants epic peaks, so give each island its own snow line as an art setting: starter about 80 percent of its summit in summer and down to the treeline in winter; volcano a snow cap on the upper 15 percent with bare black ash below; three-peak and giant keep permanent snow and small glaciers. How that is built (a per-island snow height, or a seasonal snow layer) is theirs to decide.

## 4. Glacial features (horns, cirques, tarns)

The starter island is not an ice-age giant, but it should look as if the ice passed once.

1. **Cirques**: armchair bowls cut into the steep side of a summit, with a steep back wall 200 to 400 m high. Two or three per range on the starter island, more on the larger islands.
2. **Tarns**: a still lake in a cirque floor, 40 to 200 m wide, at about 60 to 70 percent of the summit height. Water colour: deep blue-green; milky turquoise only where a living glacier feeds it (giant island). A tarn needs a rim of moraine or rock lip and one small outflow stream; this must agree with the water system, so the lake is always placed by Sonny's water rules and only styled here.
3. **U-shaped valleys**: where ice ran, valley floors are flat and wide with steep, straight sides; river valleys that never had ice stay V-shaped. Use both: the town valley is the broad U, the side valleys are V.
4. **Hanging valleys and waterfalls**: a side valley ending high on the main valley wall, with a single long ribbon fall (no steps).
5. **Moraines and erratics**: low curved ridges of rubble across valley mouths, single house-sized boulders left standing in meadows. These also give the town's surroundings character.
6. **Ice**: only snowfields and small blue-edged glaciers on the giant island and the highest three-peak summits; elsewhere snow only.

## 5. Cliff and talus textures

1. **Strata by geology** (matches the island archetype and its resources):
   - granite: pale warm grey, vertical joints, rounded domes;
   - sedimentary (limestone, sandstone): horizontal bands, ledges every 8 to 15 m, pale cream to ochre to rust;
   - volcanic basalt: near-black, columns, red and brown ash slopes, white sulphur stains near vents;
   - metamorphic: folded, twisted bands, silver-grey.
2. **Cliff dressing:** dark water streaks from top to foot, black and orange lichen patches (orange and yellow-green are the 15 percent colour accent), grass tufts and one stubborn tree on ledges, white bird streaks near eyries, shadowed cracks and chimneys, wet rock darker and glossier.
3. **Talus (scree):** angle of rest 26 to 35 degrees; coarse boulders at the foot and fine gravel at the top (the real sorting), fan shapes spreading from each gully, a few fresh lighter rocks to show recent falls. Moss and heather creep over the older lower edge.
4. **Texture rules:** steep faces use a projection that does not stretch (triplanar). Three scales on every rock surface: 0.5 m grain, about 8 m large patches (bands, stains), about 200 m macro tint, so nothing repeats visibly at 2 km. The ground texture set today has turf, litter, gravel, mud, sand and rock layers; **missing for mountains: scree, snow, wet rock, lichen rock, alpine turf, ice.** [Proposal]
5. **Silhouette comes first, texture second:** a peak that reads from 10 km in flat grey is better than a detailed one that reads as a hill.

## 6. Distance, haze and light

1. **Aerial perspective:** colours get lighter, bluer and less contrasty with distance. Target contrast for the same ridge: about 100 percent at 500 m, 70 percent at 5 km, 45 percent at 10 km, 25 percent at 20 km. Between the player and a peak there are four to six visible ridge planes, each one paler than the one before it.
2. **Haze by weather and hour:** clear cold morning is crisp with deep blue shadows; warm afternoon is hazier and golden; rain hides the tops entirely; after rain the air is clearest of all.
3. **Valley mist** at dawn: a thin white layer filling the valley floors with the ridges standing out of it.
4. **Light on relief:** low sun from the side shows relief best, so the town should see the range side-lit at sunrise and sunset, with **alpenglow** (pink-orange on the snow just after sunset) on the tall summits.
5. **Clouds:** a banner or cap cloud on the tallest peaks in wet weather; never a flat grey lid; shadows of clouds crossing the slopes.
6. **Never a wall of fog that hides the mountains on a clear day.** The distance fog stays thin enough that the hero peak is seen from the town at every clear hour. [Proposal for whoever tunes the fog and sky]

## 7. How valleys read from the town

The town is where players spend most of their time, so the mountains are composed from there.

1. **One hero peak in view from the town square**, 3 to 8 km away, with the river valley leading the eye to it (a leading line). Other peaks flank it at different distances.
2. **Size on screen** (the angle of a peak above the horizon):

| Peak height above the viewer | 2 km away | 4 km | 8 km | 15 km |
|---|---|---|---|---|
| 800 m | 22 degrees | 11 | 6 | 3 |
| 1000 m | 27 | 14 | 7 | 4 |
| 1450 m | 36 | 20 | 10 | 6 |
| 2300 m | 49 | 30 | 16 | 9 |
| 3400 m | 60 | 40 | 23 | 13 |

   Aim: the hero peak fills 15 to 25 degrees of the view from the town (peak 1000 to 1450 m at 3 to 5 km). Higher than that feels like a wall; lower than 8 degrees stops being "colossal".
3. **Valleys as funnels:** the town valley opens toward the peak and narrows into the mountains; side valleys fold behind the spurs so the ridges overlap and create depth; a pass (col) shows as a notch at 55 to 65 percent of the summit height.
4. **Water and smoke as guides:** the river's bright line, one waterfall visible as a white thread on a far cliff, chimney smoke against the dark slope.
5. **Readable for navigation:** two or three landmark features (a horn, a notch, a twin summit) that a player can name and use, and no two the same.
6. **No dead wall behind the town:** some ridge lines must drop low enough for sky and far peaks to appear in the gaps.

## 8. Island by island

| | Silhouette | Rock palette | Snow | Real-world touchstones (to collect pictures from) |
|---|---|---|---|---|
| Starter (1000 to 1450 m) | A serrated spine with a hero horn, rounded shoulders, deep cirques, fjord-like valleys | Warm grey granite, ochre stains, orange lichen; green meadows below | Patches and gullies in summer; deep cover in winter [Proposal, see 3] | Lofoten, the Cuillin, Glencoe, Milford Sound, the Julian Alps foothills |
| Volcano (1500 to 2300 m) | One great cone with a notched, broken rim; long concave flanks | Black basalt, red ash, white sulphur | A cap above the ash line; steam, never cartoon lava | Fuji, Taranaki, Etna, Hekla |
| Three-peak (2000 to 2700 m) | Three distinct summits of different character (a horn, a wall, a dome) rising from one massif | Pale limestone or granite with banded cliffs | Permanent snow, small glaciers on the north faces | The Dolomites' Tre Cime, the Tetons, the Alps near Zermatt |
| Giant (to 3400 m) | A towering, jagged wall range with several great faces, cornices and hanging glaciers | Dark granite, white ice, blue-black shadow | Heavy permanent snow and ice fields | Fitz Roy and the Patagonian spires, Aoraki, the Mont Blanc massif |

## 9. Rules for builders (summary)

1. Start from silhouette: three levels, a wandering spine, one asymmetry.
2. Keep every wall above 38 degrees as bare rock and every talus slope around 26 to 35 degrees (the game's own thresholds).
3. Snow lies on gentle slopes; steep faces stay dark with streaks; shadow faces hold snow lower.
4. A ragged treeline near half the summit height; never a straight line.
5. Put tarns, hanging falls, moraines and erratics where the water system puts lakes and streams; style, never invent water.
6. Rock palette from the island's geology; orange lichen as the one deliberate colour accent.
7. Haze sets depth: pale, blue and low contrast with distance, four to six layers.
8. Compose from the town: hero peak 15 to 25 degrees high, leading valley, landmark notches.
9. Exaggerate scale, light and steepness by at most about 15 percent; never break the rock rules.

## 10. Pictures to collect and questions

**Collect (Dave's own pictures are best, as with the plants):** a Lofoten or Cuillin ridge from sea level, a cirque with a tarn, a talus fan under a gully, a snow-streaked cliff, a layered ridge series in haze, an alpenglow shot, a treeline edge, a volcano cone with notched rim. With pictures I check the generator's output against them the way I did for plants. I cannot judge terrain from numbers alone.

**Questions for Dave** (one decision each, a recommendation follows):
1. Should the starter island's peaks carry snow in summer? Recommend **yes, patches and gullies above about 80 percent of the summit**, because it is the single biggest cue for "colossal" and the present climate rule would give none.
2. Do we want the town to look at one named hero peak? Recommend **yes**, because a landmark players recognise from the town square is worth more than any detail.
3. Is 15 percent exaggeration the right amount for scale? Recommend **keep 15 percent**, as in `art/Art_Direction.md`, and review once a first mountain exists.

**Not decided here, for Sonny and weather:** how the snow line is stored (per island height or a seasonal layer), tarn placement by the water rules, which extra ground layers (scree, snow, wet rock, lichen, alpine turf, ice) the terrain material gets, and how the fog and sky are tuned. This document gives the look; they own the how.
