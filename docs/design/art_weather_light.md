# Environmental design: weather, sky, light and frozen water

**Main design entry point.** Consolidates the 8 Nov weather/sky/ice notes without changing gameplay. Technical mathematics/checks: [sky](one_sky_design.md), [frozen water](frozen_water_look.md). [Dave's 14 Nov fog instruction](FOG_DESIGN_DAVE.md) owns fog appearance/occurrence and supersedes older fog rules here; [FOG_PLAN](FOG_PLAN.md) owns implementation. [DOC_MAP](../DOC_MAP.md) routes other topics.

**Authority/status:** the 85% realism /15% storybook basis comes from `art/Art_Direction.md`; root `ART_DIRECTION.md` §§6/9/17/30/50 covers time, weather and lighting. Coordinator choices from 8 Nov are identified in §12, not presented as Dave quotations. [Overnight decisions](OVERNIGHT_DECISIONS_8NOV.md) rows 25/27/29–31 record Dave enabling completed looks and removing their feature switches; this does not approve every tuning value or proposal. Values below are recorded tuning/visual targets; current code/data and actual PC evidence determine implementation and verification. No fresh visual or performance validation is claimed.

## 1. The rule in plain words
Photographic light with golden mornings, blue dusk, cold wet storms and a small warm world around a torch. Storybook richness belongs in golden-hour duration, dramatic storms, beautiful mist/snow and readable nights. It never justifies sourceless light, wrong-hour colours or nights so bright that firelight makes no difference.

## 2. Implementation reference
Read `game_clock.gd`, `weather.gd`, `climate.gd`, `day_cycle.gd`, `weather_look.gd`, `sky_clouds.gd`, `look_settings.gd`, held-item/fire builders and `animals.json`. The old aa 74 fc 22 snapshot (fixed 52° N, always-full moon, no mist/ice) is superseded; it is not a current checklist.

| Area | Recorded parameters and current routing |
|---|---|
| Clock | RATIO 24: one game day/real hour; 365-day year; day 0 spring equinox; new-world day 100 at 08:00. |
| Sun/sky | Grid latitude, signed hemisphere and local seasons; §3 and sky technical reference. One sun/shadow direction. |
| Moon | Phase/ecliptic position, 29.53-day cycle, full on day 100; recorded colour(0.62, 0.72, 1.0), full energy 0.22 of sun. |
| Ambient | Old night baseline 0.24/day and cold fill(0.24, 0.3, 0.44); adopted outdoor floor 0.18. Day shade retains warm quarter-bounce(0.62, 0.56, 0.44). Inspect current tuning rather than treating baseline numbers as mandates. |
| Clouds/weather | Cloud layer about 2 km, high streaks from Medium. Weather derives from seed/clock/zone/altitude/spirit; old front cadence about 12 game hours, spirit initially 0. Wind and temperature now use their owning records. |
| Rain | Overcast/dimming; recorded full-cover sun~5%, exposure 1.1→0.95, saturation 1.12→0.72; ground wet/glossy but sheltered ground dry, storm water murky. Do not apply the old blanket rain-extinguishes-every-fire assertion over current coal/fire rules. |
| Lights/creatures | Recorded torch range 12 m, burn 1800 s; fires 3.5/7/14 m; wolves' avoidance 9 m torch/10 m fire. These locate the night targets below; current items/animals own actual values. |
| Caves | Pitch black without a source; [cave art](art_caves.md) §4 owns cave-light behavior. |

## 3. Time of day
Latitude comes from the world grid, not fixed 52° N or 57° S. North is-Z. The 21×21 grid/equator row 0 places starter row 4 near 34.3° S; its noon sun is north and shadows south. Recorded starter targets: summer/winter daylight~14.3/9.7 h, noon~79°/56°/32° at summer/equinox/winter. The 57° S numeric examples in the sky reference are pinned math fixtures, not starter expectations. Seasonal light follows the local hemisphere; southern starter shade is south/south-east, not the old north-facing snow bias.

| Hour | What it must look like | Notes |
|---|---|---|
| **Before dawn (blue hour)** | The sky deep blue over a pale band in the east. The land in cool silhouette, with no colour on the ground yet. | Mist forms in valleys and over still water on calm, clear nights (section 7). |
| **Sunrise** | A red-gold disc, long shadows across the land, the east faces of hills lit warm, and the west still in blue shade. Dew sparkles on grass. | The 15 percent: let the warm light last a little longer than the sun's height alone would give. |
| **Morning** | Clean, warm-white light and crisp shadows. The valley mist burns off from the edges inward and is gone as warmth and mixing permit (section 7). | |
| **Noon** | High, white-warm sun with short, dark shadows and the warm bounce in the shade. Haze is strongest on far hills. | The look Dave already approved (ART_DIRECTION 6). |
| **Afternoon** | Like morning, but warmer, with a little more haze. | |
| **Golden hour** | Deep gold light, every leaf edge and fur rim glowing, long blue shadows. Peaks catch the last light after the valleys go into shade (the "alpenglow" on snow, pink and orange). | This is the moment to make memorable: the hero peak from the town (art_mountains) glows at sunset. |
| **Dusk (blue hour)** | Warm light gone, the sky shading from orange at the horizon to deep blue overhead. The land loses colour. The first stars appear. | The time to light a torch. The game's dusk hint ("Night is dark. Craft a Basic torch") is right. |
| **Night** | See section 6. | |

One source defines each shadow direction. Keep warm daytime shade, cooling at dusk/night. Sun and moon lighting hand over smoothly without a visible shadow jump or contradictory simultaneous shadow maps; check on the GPU.

## 4. Seasons
| Season | Light | Land and air |
|---|---|---|
| **Spring** | Clear, cool and bright, with sharp shadows. Showers with sun between: the time for rainbows (see below). | Fresh, pale greens; snow retreating up the peaks; rivers high; morning mist common. |
| **Summer** | High sun, warm, long days and short nights. More haze, and heat shimmer over dry ground in the desert and transition zones. | Deep greens; dust on paths in dry spells; thunderstorms in the afternoon. |
| **Autumn** | Low and golden, with long shadows even at midday. | Autumn colours where flora supports them; the most fog of the year (cold clear nights after warm days); damp, dark ground. |
| **Winter** | The sun stays low all day: golden light, long blue shadows on snow, and short days. | Snow in the arctic zone and on the peaks; bare trees; breath showing in the cold (section 8.4). |

**Rainbows (coordinator-adopted, later enabled):** sun behind viewer, rain/spray ahead, sun above horizon but below 42°. Passing showers: rain within about one real minute, cloud clearing/sun breaking through, no storm or snow. Arc centred opposite sun: primary violet inside 40.6°→red outside 42.4°; secondary 50.4°–53.4°, reversed, about 40% brightness. Brighten inside primary slightly, darken Alexander's band; terrain hides the feet. Soft/faint spectral bands, never neon; ease over seconds, dim with gloom, exclude from lighting cubemap. Waterfall-spray bow remains an idea requiring its own scope.

## 5. Sun and moon light
Sun: white-warm(1.0, 0.92, 0.80) at noon, gold low, red on horizon; never grey-blue. Moon: soft silver-blue with soft shadows; phase and height vary. Retain a visible moon disc showing its phase if a disc is drawn; phase-based lighting alone does not prove that disc appearance is implemented. Full/new-moon colour retention was tuned about 0.5/0.4 atop storm desaturation. A held flame or fire within~6 m (fading by 14 m) restores about 80%, eased over 1–2 s; caves keep full torchlit colour. Global saturation is a compromise: flame restores some colour outside its pool too.

Stars are strongest on clear moonless nights, fainter under full moon, obscured by cloud/fog. Retained proposal: a faint Milky Way away from town fires. Moon phases create darker "eye nights" where silhouettes/eye shine and warm safety rings matter; the former always-full/opposite-sun simplification is superseded by the ecliptic model.

## 6. Night: how darkness should read
Night must make fire feel safe, leave enough land/skyline to move, and conceal creatures until silhouette or eyes reveal them. Danger includes wolves/bears/goblins and the retained future thief idea.

### 6.1 The rings around a light (the core picture)
| Distance from the player's torch | What the player sees | Why |
|---|---|---|
| **0 to 9 m** | Full warm colour on the ground, plants and faces. Shadows would move with the flame (6.4). | Inside the wolves' `torch_light_m` 9: the safe ring. |
| **9 to 12 m** | Dim, warm, fading light. Shapes read, colours barely. | The edge, inside the torch's 12 m light but outside the wolves' 9 m. **Wolves circle here.** The player must see them as dim shapes moving at the rim. |
| **12 to about 24 m** | Dark. Only **eye shine** (`art_animals.md` section 6) and silhouettes against the sky or snow. | Where goblin eyes appear (decided by the coordinator) and where wolf pairs wait. |
| **Beyond** | The night as section 6.2 sets it. | |

Soft falloff is essential, particularly 9–12 m. Fire uses its own size; the original full 14 m fire extends beyond the 10 m wolf line, unlike a small fire. [Firelight/weather](firelight_weather_design.md) owns weather-dependent reach/halos; current creature data owns avoidance.

### 6.2 How dark is dark
| Night | Read |
|---|---|
| **Full moon, clear** | The land and every skyline readable far off. Trees as dark masses. A path shows as a paler line. Animals visible as shapes to about 25 m, but the species unclear beyond about 10 m. Almost no colour. |
| **Half moon, or thin cloud** | Skylines readable. The ground near you readable to about 10 to 15 m. Animals are moving shapes only. |
| **New moon, clear** | Starlight: skylines against the stars, the ground only at your feet, paths barely. You can move slowly. |
| **Overcast, storm or rain at night** | The darkest outdoor night: almost nothing but lightning flashes, distant fires and town windows. The floor in `weather_look` keeps it from pure black. |
| **Under forest crowns at night** | Darker than the open by about half: the crowns block the moon. Canopy dimming was adopted by the coordinator (section 12). |
| **Snow on the ground** | Brighter: snow reflects the moon. A snowy full-moon night is almost bright enough to read colours. **[Proposal]** Raise the night ambient with the snow cover. |
| **Caves** | Pitch black (#447). |

Outdoors retains readable skyline, never pitch black; caves may be black. Night is not a blue-filtered day. Coordinator-adopted torch contrast uses a 15% moon/sky-light reduction (not global exposure, which would dim the torch), easing as flame state changes. Night crowns were tuned to dim up to 45%. Snow brightening remains proposed; do not confuse its natural target with approval of an ambient implementation. Baseline moon/ambient brightness still needs player observation against these targets.

### 6.3 Firelight colour
Torch(1.0, 0.65, 0.3); fires(1.0, 0.64, 0.34)→(1.0, 0.54, 0.2); candle more yellow, recorded range 4 m. Flicker uses slow breathing noise in energy/range, never strobing. Warm faces/fur against cold moonlit land are the palette.

### 6.4 Torch shadows
Retained conditional proposal: one held-torch omni shadow from Medium up, Low unchanged; no blanket placed-torch shadows. It addresses rock/wall leaks and missing moving shadows, but needs an authorized PC GPU check. Do not infer completion or revoke the check from feature-enable history.

## 7. Fog, mist and cloud
Fog authority is [Dave's original instruction](FOG_DESIGN_DAVE.md), not the old always-clear-overhead/fixed-morning-layer rules. Dense-fog examples are adjustable: nearby tasks readable~10 m, noticeable 10–20 m, silhouettes 20–40 m, far land obscured. Deep fog obscures sky/stars/clouds in every direction; shallow ground fog may leave clear sky, and climbing above it reveals the filled valley. No clear bubble or hard wall.

Occurrence follows moisture, cooling, terrain and weather: overnight cooling, suitable during/after-rain conditions, rivers/lakes/wetlands, valley pools and coastal advection. Cold alone or every shower does not trigger fog. Formation, movement and clearing are gradual; sunrise need not end persistent fog. Wind can disperse shallow fog or deliver a bank. Fog belongs to locations; broad subtle drift, no boiling smoke or obvious repetition. Lit naturally; unlit night fog dark, softened flame halos/shafts; enclosed interiors/caves differ from outdoors while doorways show fog beyond. Terrain, water, flora and actors share obscuration; visual creature detection follows it, hearing/other senses remain functional.

Retain distinct looks: valley sea beneath clear hills; low steam wisps 1–2 m over warm water in cold air; summit caps/banners; coastal banks; rain haze; waterfall spray/cave-mouth mist ([cave art](art_caves.md) §3). The former fixed 1–3 h burnoff and universal rain/wind exclusion are superseded tendencies, not rules. Fog implementation and outstanding limits stay in [FOG_PLAN](FOG_PLAN.md)/[F6 checks](FOG_F6.md).

### 7.1 Cap cloud on high summits
Clouds must wrap summits rather than sit behind exposed terrain. Old size references: starter 1000–1450 m; volcano 1500–2300 m; three-peak 2000–2700 m; giant up to 3400 m. Condensing moist wind makes a stationary cap that reforms while air streams through, with downwind banner.

Recorded tuning: caps start at 2000 m; `--cap-cloud=METRES` remains a check knob (1200 m tests starter~1430 m). Nearest 4 from coarse 32 m height search; cloud>0.3→full 0.6 or rain, wind 0.1→full 0.35; storm wraps peaks, clear/dry none; ease~one minute. Lens~250 m across, just below summit to 120 m above; banner 300–1000 m with wind. Eight soft cards/cap, 32 total, shared material; original summit-search estimate~2 million coarse heights on worker thread, not measured performance evidence. Sun/sky-lit top/underside, golden low sun and dark blue-grey night; soft rock intersections, near-eye fade and distance haze. Retain the gaps: sky layer thinning near peaks and fog thickening when inside cap require verification/further work. Bare `--cap-cloud` is no longer an opt-in requirement.

### 7.2 Distance haze and aerial perspective
Cold/dry ridges sharp blue; warm/humid air milky grey-white; post-rain air briefly crisp, later steaming land can turn it milky. Haze uses plain air temperature, cloud/wetness/mist/season, deterministic weather and~one-minute easing. Recorded clear-air tuning relative to the old base:

| Air | Haze thickness | Colour of far land |
|---|---|---|
| Cold and dry (about 0 °C, clear), e.g. a winter morning | about 0.6 x today's | clean blue, sharp ridges |
| Mild, ordinary (about 10 °C, some cloud) | today's (1.0 x) | today's |
| Warm and humid (about 20 °C after rain, sun out) | about 1.8 x | pale, milky white-blue |
| The hour after rain stops | x 0.6 on top of the above | crisp |

Dry shifts toward deep blue, humid toward pale white; aerial perspective recorded 0.7→0.5. Rain/snow/storm add murk. A thicker lowest-kilometre layer with clear peaks remains a shared-height-fog idea; reconcile it with current fog architecture, not a second independent fog. `--haze` is no longer required. Earlier "zero cost" claims were estimates, not benchmarks.

## 8. Rain, snow, wind and storms
### 8.1 Rain
Rain falls from cloud, dims sky, darkens/glosses ground/rock/bark and muddies storm water. Rain streaks should catch nearby lights. Open rain douses a held torch; cover can keep it burning. Large coal-bed fires follow their later survival rule, not the original blanket extinguishing claim. Retain post-rain shafts through cloud breaks, suitable rainbows, clearer air and leaf/eave drips. Current [rain look](rain_look_design.md), [canopy drip](canopy_drip_design.md) and [fire smoke](fire_smoke_wind_design.md) refine those features: the old fixed one-minute leaf-drip idea is not their current storage/lifetime instruction.

### 8.1.1 Puddles
Client look/sound, not drinkable/saved water simulation. Fixed hollow pattern substitutes for sub-metre dips on 1 m voxels: noise scales 3.6/1.1 m, irregular 0.5–3 m pools, full below 10° slope, gone by 18°. Material proneness:

| Ground (shader layer) | Proneness | Why |
|---|---|---|
| Mud and clay | 1.0 | water cannot sink in |
| Worn trails (the game trail map) | + 0.5 on top of the ground | trampled earth is packed hard; tracks are where puddles are |
| Gravel and stony soil | 0.7 | packed, but drains quickly |
| Flat bare rock | 0.6 | shallow pools in dips of the stone |
| Turf (silt, loam, alluvium) | 0.35 | grass roots drink it |
| Litter (humus) | 0.25 | spongy |
| Peat (drawn as litter) | 0.6 | wet to the top; shallow pools stand in it |
| Sand and beach | 0 | it sinks in at once |

None under closed crowns/on lying snow/within 1 m sea level; fade with cave light under rock. Visible to~120 m, gone 220 m. Cave floor viewed from outside can still show a false puddle (recorded limit).

Per-ground level 0–1 fills from excess rain over infiltration: gravel 40, sand 20, loam 7.6, silt 5.1, clay 1.5 mm/h; tracks as clay, peat 1, rock dips 0. Rain rate 50×rain^2.5 mm/h (drizzle 0.15≈0.4; test rain 0.65≈17; downpour 50), judged tuning. Fill excess×3 catchment/30 mm depth per game hour. Deepest/prone hollows fill first; muddy tracks join sheets, turf fewer pools, sand none. Drain schedule (game time, coordinator-adopted soils tuning):

| Ground | Dry again in, high summer | Deep winter |
|---|---|---|
| Gravel | 1 h | 1 h |
| Litter | 2 h | 2 h |
| Turf | 3 h | 3 h |
| Mud and clay, and worn tracks | 3 days | 10 days |
| Dips in flat rock (they only dry in the air) | 2 days | 6 days |
| Peat | never (shallow pools stay) | never |
| Sand | at once | at once |

Interpolate summer/winter with local climate season; original warmest phase 0.375. Ongoing rain halves draining; frozen pools do not drain. Ice uses 0.1 m depth: visible frozen from 2 cm, fully 5 cm, pale grey-white gloss/cracks/bubbles, no rings/splash; thin-ice crunch remains a sound idea.

Liquid puddle: dark brown-black bed, mirror roughness~0.03, 10 cm damp rim, only actual sky/flame reflections at night (no glow). Rain rings on jittered 0.3 m grid grow 12 cm/fade 0.6 s; rate follows rain. Wind ruffles from 0.2, follows `wind_dir`; calm mirror. Ripples within 40 m. `step_water` only when foot hits a drawn pool; soaked-ground squelch remains. Splash ring/drops 0.2–0.4 m high, fade 0.5 s, larger at run; animals within 25 m too, size-scaled. Pool cap 12 splashes. Original work bounds: puddle shading within 220 m only with wet level, ripples 40 m, ice every 10 s; verify actual performance.

### 8.2 Snow
Falling flakes, ground cover and buried grass; dry shelter underneath trees follows canopy/season rules. Branch/crown snow follows `ground_snow` memory: upward needle/leaf clusters, winter twigs and branch tops with patchy edges; undersides/trunks dark; far crown images match. Soft blue-white(0.86, 0.88, 0.92), never pure white. Rock/roof snow and footprints/trails remain separate ideas requiring status checks. Steep faces above~50° stay dark; ledges/gullies may hold streaks. Torchlit flakes warm; snowy nights naturally brighter (ambient implementation still proposed); blizzard is angled wind-driven white-out.

### 8.2.1 Summit snow
A4/R6/R7 plan: per-island climate and baked per-cell snow window, summer lee/shaded gullies at 80–85% summit. Recorded fallback searches highest summit within~10 km using cap-cloud heights; no snow until found. This is a visual fallback, not a claim the planned bake is missing on current dev. Recorded lowest-patch tuning:

| Season | Lowest patches |
|---|---|
| Summer | 82 percent (the A4 window, 80 to 85) |
| Autumn | 70 percent |
| Spring | 62 percent (old winter snow melting back) |
| Winter | 50 percent, the treeline (art_mountains rule 4) |

Use the correct hemisphere's shade and current wind. The old fixed north/north-east shade and south-west wind assumptions are superseded on the southern starter by the grid/prevailing-wind records. **Existing implementation mismatch:** static review at the consolidation base found `src/client/ground_material.gd` still subtracting the north-facing shade term. The intended hemisphere rule here is not a claim that shader behavior has been corrected; a weather/snow implementation owner must reconcile and visually verify it before declaring that work complete. Retain the fallback magnitudes as tuning: shade 7% lower, lee 6% lower, windward 7% higher with at most 30% cover; summer only lee/shaded creases. Research context: lee drifts 2–5×mean; old Scottish 84%-summit example is research, not a starter aspect prescription. Above 45° retain snow only in creases/small ledges. Noise 60/15 m breaks the lower edge; no ruler-straight line. Same snow colour, rougher than ice, no distance fade (readable from town). Cornices need shapes, not paint:1–3 m lip over lee crests steeper 35°, retained for baked window. Recorded gaps: snow patches drawn rather than walked through, rock footsteps, server snow window—verify status in their implementation work.

### 8.3 Wind
Grass/trees, rain angle, drifting snow, smoke/flame lean and cloud motion agree on one `wind_dir`. Smoke bends downwind, not a separate random direction. [Prevailing-wind decision](OVERNIGHT_DECISIONS_8NOV.md) row 31 supersedes the fixed south-westerly assumption: southern summer south-easter~140°, winter westerly~288°, front veer/back and gusts use owning weather implementation.

### 8.4 Cold
Breath starts at 5 °C, full by−5 °C, using plain air at height with daily swing: coldest after dawn/warmest afternoon; never apply snow-only bias to breath. Player first-person puff just below/ahead of view, third-person at head; nearest animals/goblins within 15 m, max 8, bone/code head. Remote-player support remains an idea/status check. Pale grey scene-lit puff 0.15→0.5 m, rises/drifts, fades 1.5 s; person every 3–4.5 s, large animals 4–6 s, random offsets; none underwater. Recorded pool 32 shared-material cards; inactive above 5 °C. Never glowing at night without a light.

### 8.5 Storms and lightning
Dark sky, shared flash/bolt/thunder event; bolt from Medium. White-blue night flash briefly lights land with hard shadows. Keep full distance delay~3 s/km; [thunder design](thunder_delay_design.md) owns later timing. Retained proposal: reveal an exposed creature momentarily as silhouette/lit shape.

### 8.6 Frozen water: skim, sheet, snow, holes and thaw
Default-on frozen-water look was adopted in the 8 Nov enable decision; no `--frozen-water` feature switch is required. The [technical reference](frozen_water_look.md) owns depth/current/spring calculation, integration, baseline fixtures and checks; [still-water ice](still_water_ice.md) owns underlying ice rule, [ice walk feel](ice_walk_feel.md) owns footing/sound. Cover 1 represents 20 cm, with recorded visual bands:

| Ice | Cover | Look |
|---|---|---|
| **Skim (black ice)** | under 0.12 (2.5 cm) | Clear. It reads dark, because you look through it into the water, the "black" ice of calm nights (sources 3, 4). Glossy and flat: the ripples, foam and rain rings stop. A few long straight white cracks. A white frost rim of crystals where it meets the bank. See-through, alpha about 0.6, so the bed shows in the shallows. |
| **Grey film** | 0.12 to 0.5 | Grey with a little blue (0.58, 0.64, 0.68), more opaque. White cracks in it are normal (source 4). A soft milky patchiness, the bubbles. |
| **Solid sheet** | 0.5 and up (10 cm, bears; `_on_ice`) | Grey-white (0.80, 0.85, 0.88), almost opaque. Cracks show darker grey. Little gloss, roughness 0.35. |

Frozen surfaces suppress ripples/foam/rain rings; add white frost-crystal rim at bank and patchy trapped bubbles. Snow only on ice>=5 cm (cover 0.25): wind-stretched patchy drifts/bare scoured areas, matte(0.92, 0.94, 0.96), roughness 0.9. Falling snow on thinner ice makes darker wet slush/top-water patches.

Shallows freeze first in lobes from bank; fast/turbulent reaches stay open and springs keep an open reach. Thaw order: shore moat first, sheet wet/grey, middle breaks into lobes and disappears; same order for daily skim melt and seasonal breakup. Darkening target(0.42, 0.46, 0.48) at 0.7×thaw. Keep player collision/drinking rules aligned with visible openings; old mismatches are tracked in technical §9, not silently assumed fixed.

Hole: round dark open water at half liquid colour, radius 0.3 m (0.6 m across), ragged white chips from 1–1.6 radii and loose chips to 2.2. Only solid cover>=0.5 shows/cuts a hole (`say_no_ice` otherwise). Over final sixth of 18 game-hour life (last 3 h), thin black skin closes it. The game's threshold teaches dark skim vs grey-white bearing sheet; it is game tuning, not a real-world ice-safety claim. No blanket promise that the starter can never bear a player: old test climate/seed is a fixture, not all worlds.

## 9. Zones and town spirit
| Zone | Light and air |
|---|---|
| **Desert** | Hard white light, deep short shadows, heat shimmer, dust haze that turns far land ochre, clear star nights. |
| **Transition** | Warm, dry summers with dust in the air; green after rain. |
| **Temperate** | The rules above; the starter islands. |
| **Arctic** | Low sun, long blue shadows, snow glare by day, very clear cold air (far land sharp), long nights. Aurora is a [Proposal] for clear arctic nights. |

Spirit, when implemented, bends weather rather than placing a colour filter over town: high spirit warm light/gentle night rain/clear misty mornings; low spirit heavier skies/colder light/more storms. Preserve physical fog conditions from Dave's ruling. Aurora on clear arctic nights remains proposed.

## 10. Never-see list
No sourceless glowing fog/water or cave ambient; blue-filter day posing as night; black outdoors; hard torch rim hiding wolves; conflicting sun/moon shadows or dusk pop; rain from clear sky/sun through full overcast; uniform all-height fog or deep fog exposing clear sky; peaks in front of cloud they should inhabit; disagreeing wind; strobing flame; wrong-geometry rainbow; hillside/glowing puddle or splash outside drawn water. Caves can be black, and shallow fog can leave sky clear.

## 11. Pictures and evidence
Authorized PC checks, not cloud renders: summer/winter hourly full day at spawn(~53296, 68080) toward hero peak; 22:00/02:00 without torch/with torch/full fire+wolf 10 m (especially 9–12 m ring); dusk every 30 s for shadow jump; rainy noon/night under tree with torch; blizzard; >2 km summit/cloud intersection; same forest night open/under canopy. Sky reference adds hemisphere/moon checks; frozen reference adds skim/spring/thaw/hole captures; [fog F6](FOG_F6.md) covers daylight/dark, all directions, doorway, bank boundaries and climbing above. No old named-agent queue or absent photo is a completed test.

## 12. Decisions, remaining proposals and provenance
Coordinator 8 Nov adoption: moon phases; never-black outdoors; night canopy dimming; 15% moon/sky reduction with flame; height-fog/mist work; cold breath, rainbows, crown snow, night desaturation, puddles. Conditional then: held-torch shadows after GPU evidence; cap cards after pictures. Later Dave enable decisions remove completed-feature switches; they supersede old opt-in instructions, not the need to validate appearance.

Open ideas retained: snow-driven night ambient, Milky Way, arctic aurora, waterfall rainbow, further rain/wet-surface/drip/light refinements under their later designs, rock/roof snow, footprints, remote breath, baked snow/footstep integration, cap-layer/player-inside improvements and conditional torch shadows. No unresolved issue is declared fixed by consolidation.

Climate split: row-curve plain air (starter fallback 14.16 °C); separate snow/ice bias (starter−5.16 °C, originally approximated−6 °C), intended to retain old 9 °C snow/ice tuning. HUD/breath/warmth/fire/cold water/cave/spring use plain air; snow/ice and precipitation phase use biased air. Do not propagate old 5.5 °C spring or fixed 9 °C air figures into all systems. Sky technical §7 records source/limitations; current `climate.gd` owns actual defaults/record reads.

Sources retained: `art/Art_Direction.md`, `ART_DIRECTION.md`, `DESIGN_IDEAS.md`7.5, [torches/fire](../knowledge/torches-fire.md), [warmth/weather](../knowledge/warmth-weather.md), linked specialist records above; [original 8 Nov weather notes](https://github.com/DSul3791/DynastyALWL/blob/090129ec43942e90a28eb7c4fd0d202df3ee68c3/docs/design/art_weather_light.md) preserve superseded snapshots, rosters, estimates and commands. This consolidation changes documentation structure and resolves superseded instructions; it grants no new creative approval.
