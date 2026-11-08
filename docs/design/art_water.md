# Art direction for water (design only, no code)

Kathleen, 8 Nov 2026, the companion of `docs/design/art_mountains.md`. Basis: `art/Art_Direction.md` (85 percent realism, 15 percent storybook), `docs/water/Dynasty_How_Natural_Watersheds_Work.md` (the natural rules: where water comes from and goes), and the water rebuild in `docs/water/watershed_rebuild_design.md` (Sonny owns how water is built and drawn). This document says **how every kind of water should look, sound and read**, never where it goes: the hydrology decides the water, the art styles it. It changes **no code and no data**. Items marked **[Proposal]** need a decision by Dave or by Sonny and weather. I have not judged water pictures from the game yet; what to collect is in section 11.

## 1. The rule in plain words

Water must look like it belongs to its landscape. A reader who follows a drop from a damp hollow to the sea should see the colour, speed, bed, banks, plants and sound change in step with the water's energy, depth and sediment. **No two kinds of water look alike, and none looks like a blue sheet laid on the ground.** The 15 percent exaggeration goes into light, clarity, colour depth and the drama of falls and mist; never into water that breaks the natural rules (no uphill flow, no steps in a fall, no perched ponds).

## 2. What water is made of (the five looks)

Every water surface is a mix of five things. Art sets each per kind of water:

| Part | What it is | What changes it |
|---|---|---|
| **Body colour** | The colour seen through the water | Depth, bed colour, sediment, tea-brown peat, algae, glacial flour |
| **Surface** | Ripple size, speed and direction, glints | Flow speed, wind, rain |
| **Edge** | The shore line: wet band, foam, stones, plants | Bank type, level changes |
| **Bed** | What lies under the water | Stone size, sand, silt, leaves, moss, weed |
| **Disturbance** | Foam, spray, mist, splash rings | Drops, rocks, falls, rain |

## 3. Kinds of water and their looks

| Water | Body colour | Surface and motion | Bed and edge | Sound cue |
|---|---|---|---|---|
| **Seep or spring** | Almost none: a darkened patch of rock or soil, then a thin glass film | A trickle with tiny glints, never a jet | Dark wet stone, bright green moss, small ferns, a pinch of pale mineral at limestone springs | Faint trickle, drips |
| **Mountain torrent** | Clear, slightly milky white in rapids | Fast, braided, white foam at every drop, plunge pools below | Coarse stones and boulders, scoured bedrock, step-pool shape, rounded cobbles | Loud, bright rush |
| **Forest brook** | Clear tea-gold over leaf litter, green-brown in shade | Gentle riffles, still pools, leaves and sticks caught at obstacles | Gravel and sand patches, root-exposed outer bends, mossy logs | Soft burble |
| **Meadow river** | Slightly cloudy blue-grey-green, deeper = darker | Slow, long smooth runs, small eddies behind bars | Point bars (pale gravel) on inner bends, cut banks (steep, earthy) on outer bends, reeds and willow | Low, steady hush |
| **Lowland and flood river** | Silty brown-tan in flood, olive-green in low flow | Wide, slow, heavy surface with slow boils and swirling debris | Muddy levees, backwater coves, floating foam lines in flood | Deep, muffled |
| **Lake** | Deepens from pale shallows through green to blue-black over about 10 to 15 m | Calm mirror in still air, long ripples in wind, rain rings | Irregular shore, gradual shallows, stone shelf, quiet coves with silt and lilies | Gentle lap |
| **Tarn (mountain lake)** | Dark, clear, deep blue-green; glacial milky turquoise only where a living glacier feeds it | Still, reflects the cliffs above it | Rock lip or moraine rim, bare stone shore, snow patches beside it | Near silence, a drip or a bird |
| **Marsh and swamp** | Dark, tea-brown, near black under trees; reflects sky in gaps | Almost still, drifting surface scum and pollen in spring | Hummocks, reeds, sedge, floating mats, standing dead trees in swamp | Frogs, insects, a soft plop |
| **Fen and bog** | Clear but dark tea-brown (bog: nearly black, acidic) | Still, mirror-like, tiny trickles between pools | Sphagnum moss, cotton grass, sundew, pale peat edges | Hushed |
| **Waterfall** | Clear then white; green-blue where deep and falling over a smooth lip | Ribbon, curtain or cascade of white streaks; mist plume; plunge pool with a standing foam ring | Wet dark rock, ferns, moss, spray-wet trees, a rainbow in low sun | Roar that scales with height |
| **Cave stream** | Very clear and almost black in the dark, sometimes a faint milky blue where limestone-rich | Slow and glassy, with drips making rings; louder over a lip | Smooth wet limestone, flowstone ledges, pale mineral crust, no plants | Drips, echo, soft run |
| **Estuary and river mouth** | Brown river meeting blue-grey sea in a visible swirl line | Slack tidal pools, ripples against the tide | Mudflats at low tide, gravel fans, wading birds, stranded weed | Wash and gulls |

### 3b. How the looks map onto the water record

The water rebuild (`docs/water/watershed_rebuild_design.md`, Stage D, the island water record) already stores, per reach and lake, what the water should look like. The art uses those fields; it does not invent its own labels.

| Record field | Values | Look it drives |
|---|---|---|
| Reach type (from slope) | cascade, step-pool, plane-bed, pool-riffle | Cascade: white chute over boulders, constant foam, loud. Step-pool: a chain of short uneven drops, each into a clear pool, foam at each lip only. Plane-bed: a fast even run over cobbles, small standing ripples, little foam. Pool-riffle: alternating glassy pools and bright riffles, gravel bars, meanders where the valley allows |
| Sediment load | clear, cloudy after rain, silty | Clear: bed visible to about 2 to 3 m. Cloudy: bed visible to about 0.5 m, grey-green. Silty: opaque tan-brown, bed hidden |
| Peat colour (bog fed) | yes or no | Tea-gold in shallows to near black in depth, clear rather than cloudy |
| Turbulence class | calm to violent | Foam amount, surface roughness, spray and sound loudness |
| Bed material | boulders, cobbles, gravel, sand, silt, peat | The bed texture seen through clear water and on exposed bars; also the edge stones |
| Regime | perennial, intermittent, ephemeral | Intermittent and ephemeral beds show dry in the dry season: pale bleached stones, cracked silt, a debris line, no water surface |
| Lake cause | cirque, glacial rock basin, moraine dam, kettle, doline, landslide dam, oxbow, lagoon | Cirque: tarn look (section 3), bare rock and snow. Glacial rock basin: long, deep, steep rocky shores. Moraine dam: rubble rim, outlet cutting through it. Kettle: round, steep-sided, reedy, often no outlet. Doline: round, clear blue-green over pale limestone, may drain underground. Landslide dam: drowned grey trees, raw scar above. Oxbow: crescent, still, weedy, lilies. Lagoon: brackish, shallow, sand bar to the sea |
| Wetland type | marsh, swamp, fen, bog | The palettes in section 8 |

## 4. Reading the water from afar

1. **A river is a bright line.** From the town the river reads as a silver thread in the valley; show it with a lit surface, a pale gravel bar edge and dark trees either side. At 2 km and more the water is mostly sky reflection, so its brightness follows the sky.
2. **Lakes mirror the mountains.** A calm lake reflects the peak and sky at the start and end of the day; this ties the water to `art_mountains.md` (the tarn, the town valley and the hero peak). Wind breaks the reflection into long strips.
3. **Falls are white threads.** A fall seen from 2 to 3 km is a thin vertical white mark on the dark cliff, with mist drifting at its foot. It must be a single unbroken drop (no steps), as the design already says.
4. **Wetlands are texture, not colour.** Seen from above: dark soft ground, reed-tan and green mosaics, small bright pools.
5. **Water never glows blue at night.** At dusk and night water takes the sky colour and the fire or moonlight on it, with darker banks; no flat blue.

## 5. Surface: ripples, flow and glints

1. **Flow direction must be visible.** Flow streaks, floating bits and ripple trains all move the same way, faster at the centre and slower at banks, with eddies and slack water behind obstacles and inside bends.
2. **Three ripple scales:** about 5 cm ripples (wind or fast shallow flow), about 40 cm swells or boils, about 3 m long waves on big water in wind. A surface using one scale looks like a tiled texture.
3. **Reflections:** strongest at low viewing angles (Fresnel), faint when looking straight down at shallow clear water so the bed shows. A pond must reflect the sky colour of the moment.
4. **Foam:** only where there is a real reason: a drop, a rock, a fall, a confluence line. Foam lines in flood follow the current; old foam is cream-brown, fresh foam white.
5. **Rain:** pits the surface with small rings, softens reflections, darkens the body colour slightly.
6. **Transparency:** shallow water shows the bed (with refraction shifting the bed slightly), deep water does not. Clarity falls in flood and after rain (brown) and rises in drought (very clear, green).
7. **No uniform blue.** Depth, sediment, bed material and sky each tint the surface.

## 6. Edges and banks

1. **A wet band:** a darker, shinier strip of ground above the waterline shows where the level has recently been; it widens in drought (exposed mud and cracked silt) and narrows in flood.
2. **Banks by water energy:** steep rocky banks on torrents, root-exposed cut banks on outer bends, gentle gravel bars on inner bends, soft mud and reeds at slow water. Banks are never identical on both sides.
3. **Plants follow water:** moss and ferns by seeps; alder and willow along brooks; reeds, sedges and flag iris at slow edges; lilies in still shallows; no dry-land plants standing in water (the plant choices come from the flora look work).
4. **Debris:** drift logs caught at bends, leaf rafts at obstacles, a pale high-water line of sticks and dead reeds above the current edge.
5. **Footprints:** wet sand and mud take prints; stones are darker where wet.

## 7. Waterfalls, rapids and cascades

1. **A fall exists only where the rock gives a drop:** a bedrock ledge, a hanging valley, a resistant band. The cliff face shows it: a lip of hard rock, darker streaks down the face, a plunge pool and a spray zone.
2. **Three types, used by size:** ribbon (a thin single stream over a smooth lip, 20 to 100 m), curtain (a wide sheet over a broad ledge, 5 to 30 m), cascade (a steep white chute sliding down sloping rock, foam the whole way). Each is one continuous body of falling water: **a waterfall never steps** (Dave's rule), so no staircase of equal drops. A step-pool channel (section 3b) is a stream, not a fall: its small drops are uneven in height and spacing, each with its own pool.
3. **Spray and mist:** a plume that drifts with the wind, wets nearby rock and trees to a darker green, and shows a rainbow in low sun.
4. **Plunge pool:** a deep, darker, slowly turning basin with a ring of foam; the out-flowing stream is white at first and settles into clear water a few metres on.
5. **Sound scales with height:** a 5 m fall is a splash; a 50 m ribbon is a deep roar heard 300 m away in valleys.
6. **Never:** a fall with no cliff, a fall that feeds from nothing, or a fall that forms a row of equally spaced steps.

## 8. Lakes, tarns and wetlands

1. **Shore character from geology.** A glacial tarn has bare rock and moraine; a valley lake has gravel beaches and reeds; a landslide-dammed lake has drowned trees; a beaver pond has a lodge, a low dam and grey stumps; an oxbow lake has a curved, reed-lined shape and floating weed.
2. **Depth reads in colour:** pale and sandy to deep blue-black in a continuous gradient, with weed beds as dark patches and drop-offs visible as sharp colour steps.
3. **The spill point is visible:** if a lake has an outlet, a small rock lip, reeds parting, a stream starting there. Not every lake needs one; a closed lake shows a stained high-water line and no stream.
4. **Wetlands:** marsh (green and tan, standing water gleams between reeds), swamp (dark water, trees with swollen bases and moss), fen (golden sedges, pale peat, clear dark pools), bog (rust, cream and green moss carpet, black pools). Each has its own palette; they are never "a shallow lake with reeds".
5. **Seasonal states:** shallow ponds shrink and show cracked mud in drought; marshes flood in spring with extra open water; frost rims the edges in autumn; ice forms from the shore inwards in winter, thin and clear at first, white-frosted later.

## 9. Cave streams and underground water

1. **The cave stream is the quietest water in the game.** It is very clear, almost black where deep, and slow; drips from the ceiling make slow rings.
2. **Rock tells the story:** pale smooth limestone, flowstone steps, a crust of mineral at the waterline, thin curtains of stalactites over the water. No plants and no daylight colour.
3. **Light:** only torch or magic light reaches it. Surface glints stay small and warm under a torch; far water goes to black. A faint cold-blue glow from the outside only near the cave mouth.
4. **Cave springs:** an arched mouth with clear, cold water pouring from the foot, fern-lined and green, mist on cold mornings. Rare and always at suitable rock (the design's rule).
5. **Underground flow needs sound:** the sound is the first sign of water in a cave, loud before it is seen; echo scales with cave size.

## 10. The same water in different conditions

| Condition | Look |
|---|---|
| **Clear day** | Crisp reflections, bright glints, shallow beds clearly visible |
| **Rain and after** | Rings on the surface, darker body colour; brooks swell, turn tea-brown, foam appears at the edges; falls widen and whiten |
| **Snowmelt** | High, cold, milky water; thick roar in torrents; gravel bars overrun |
| **Flood** | Brown, fast, heavy with debris, spilling into meadows; banks collapse; foam lines |
| **Drought** | Pools shrink and turn green; cobble bars and mud cracks show; small brooks vanish while springs and big rivers continue (design rule) |
| **Winter** | Ice at shores and slow water, steam rising from warm springs, falls freezing into hanging ice at the edges |
| **Dawn and dusk** | Mist on still water, low light strips along the surface, mirror reflections |
| **Night** | Water takes sky or firelight colour and glints under the moon, banks very dark |

## 11. Never and checks

**Never see:** the same colour and ripple everywhere; flat blue water; foam with nothing to make it; a fall that steps; a lake bright blue in all weathers; a bank the same on both sides; water with no bed; marsh vegetation on dry slope, dry-land plants standing in water; a brook with no sound.

**Questions to ask of every water picture (plain version of the watershed tests):** What kind of water is this, and are its colour, surface, edge and bed right for it? Is the flow direction readable? Does the sound match? What season and weather is it, and does the water show it? Does it agree with the ground around it (damp edges, moss, scour)?

**Pictures to collect (Dave's own are best, as for the plants and mountains):** a clear mountain torrent with a plunge pool, a tea-brown forest brook over leaves, a meandering meadow river with a gravel bar and a cut bank, a flood-brown river, a calm lake reflecting hills, a tarn under a cirque, a marsh and a bog, a ribbon waterfall with mist, a cave stream, a river mouth at low tide. With pictures I check the game's water against them as I did for the plants.

**Needs for Sonny and weather (how, not what):** the look fields in section 3b already exist in the water record design, so the art needs only that the water and ground shaders read them (the rebuild design's Stage E readers say they will). Beyond that, three art asks, theirs to decide: a clarity value that follows rain and snowmelt over hours (not only the stored "cloudy after rain" class); foam drawn from the turbulence class and the drops the flow sees, not as a fixed texture; ice and morning mist as seasonal and daily states. Until the readers switch to the record, waterfalls, water sounds and cave streams may still draw in the wrong places (rebuild design, section 7), so pictures taken before that are judged on looks only.
