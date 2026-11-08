# Art direction for weather and light (design only, no code)

Kathleen, 8 Nov 2026. This is the fifth in the set, after `art_mountains.md`, `art_water.md`, `art_caves.md` and `art_animals.md`.

**Basis:**
- `art/Art_Direction.md`: 85 percent realism, 15 percent storybook.
- The root `ART_DIRECTION.md`:
  - section 6: time of day;
  - section 9: weather takes zone, season and town spirit;
  - section 17: the weather look;
  - section 30: rain and storm darkening;
  - section 50: sun, moon and sky follow the clock.
- `DESIGN_IDEAS.md` 7.5. Its line "Night is never pitch black (moonlight and torches)" is marked Proposed.
- `docs/knowledge/torches-fire.md` and `docs/knowledge/warmth-weather.md`.
- The code as it stands on main aa74fc22:
  - `src/shared/game_clock.gd`;
  - `src/shared/weather.gd`;
  - `src/client/day_cycle.gd`;
  - `src/client/weather_look.gd`;
  - `src/client/sky_clouds.gd`;
  - `src/client/look_settings.gd`;
  - the torch in `src/client/held_item.gd` and the fires in `src/client/building_look.gd`.
- The wolves block in `data/animals/animals.json` (`torch_light_m`, `fire_light_m`).

**Scope:**
- This document says **how the sky, the light and the weather should look and feel**, and how night darkness should work so that firelight and goblin eyes matter.
- It changes **no code and no data**.
- Items marked **[Proposal]** need a decision by Dave or the coordinator. The coordinator names the owner of each code item.

**Evidence:** I have not watched a full game day on a real GPU. The pictures to collect are in section 11.

## 1. The rule in plain words

Light is the single biggest reason a picture looks real (ART_DIRECTION 2.1). Every hour, season and weather in Dynasty should look like a photograph someone would want to keep: golden mornings, deep blue dusks, a grey storm that feels wet and cold, and a night dark enough that a torch is a small, warm world of its own.

**The 15 percent goes into:**
- the length and richness of golden hour;
- the drama of storm skies;
- how beautiful mist and snow are;
- making the night just readable enough to play.

**It never goes into:**
- light with no source;
- colours that do not belong to the hour;
- a night so bright that a torch does nothing.

## 2. What is built today (facts)

| Part | Today |
|---|---|
| **Clock** | One game day is one real hour (`RATIO` 24). The year has 365 days, and day 0 is the spring equinox. A new world starts on day 100 at 08:00, close to midsummer. |
| **Sun** | The real path for latitude 52°: it rises in the east, stands in the south at noon and sets in the west. White by day, gold when low, red on the horizon. One directional light and one shadow map. |
| **Moon** | Always full, always opposite the sun. One cold blue light (0.62, 0.72, 1.0) at 0.22 of the sun's energy. |
| **Night ambient** | 0.24 of the day value, with a cold fill colour (0.24, 0.3, 0.44) and a floor so a storm night is not pure black. Stars appear, hidden by cloud and storm. |
| **Day shade** | Warm bounce: a quarter of the day's ambient is warm (0.62, 0.56, 0.44), so shade is not blue-grey. This was my proposal of 3 Nov. |
| **Clouds** | Fair-weather clouds on a layer about 2 km up, drifting with a steady wind and changing shape, with high streaks from Medium up. Coverage follows the weather. |
| **Weather** | A pure function of the seed, the clock, the zone (desert, transition, temperate, arctic), the altitude and town spirit (passed as 0 for now). It gives rain, snow, storm, cloud, sun, wind, wind direction and temperature. Fronts arrive about every 12 game hours. |
| **Rain** | It falls only from cloud, and any rain means heavy overcast. The sun drops to about 5 percent under full cover, exposure falls from 1.1 to 0.95, and saturation from 1.12 to 0.72. The ground goes darker and glossier but stays dry under tree crowns. Water goes murky in storms. Lightning brings a sky flash and, from Medium, a bolt. |
| **Snow** | Flakes fall, flat ground turns white, and grass is buried. There is no snow under trees. |
| **Fog** | One even haze (density 0.0009 in clear air), thicker in rain, snow and storm. It takes the sky colour behind it and goes dark under rock. **There is no height fog, and the world weather has no fog or mist state**: "fog" exists only as a test kind. |
| **Torch** | Held in the off hand. `light_m` 12 and `burn_s` 1800 in items.json. A warm light (1.0, 0.65, 0.3) **with no shadow**, plus a small hand light. It goes out in open rain and under water. |
| **Fires** | Three sizes, lighting 3.5 m, 7 m and 14 m. They go from warm orange to deeper orange as they grow, and rain puts them out. |
| **Wolves** | They keep out of the torch's light (`torch_light_m` 9) and out of a fire's (`fire_light_m` 10). |
| **Caves** | Pitch black without a light (#447). See `art_caves.md` section 4. |

## 3. Time of day

**At latitude 52°:**
- The noon sun stands about 61° high at midsummer, 38° at the equinoxes and only **15° at midwinter**.
- Daylight lasts about 16.5 hours in summer and 7.5 hours in winter.
- In real time, a summer day is about 41 minutes of light and a winter day about 19.

That fact shapes everything below: **winter is golden all day**, and summer has a short, deep night.

| Hour | What it must look like | Notes |
|---|---|---|
| **Before dawn (blue hour)** | The sky deep blue over a pale band in the east. The land in cool silhouette, with no colour on the ground yet. | Mist forms in valleys and over still water on calm, clear nights (section 7). |
| **Sunrise** | A red-gold disc, long shadows across the land, the east faces of hills lit warm, and the west still in blue shade. Dew sparkles on grass. | The 15 percent: let the warm light last a little longer than the sun's height alone would give. |
| **Morning** | Clean, warm-white light and crisp shadows. The valley mist burns off from the edges inward and is gone within 1 to 3 game hours of sunrise. | |
| **Noon** | High, white-warm sun with short, dark shadows and the warm bounce in the shade. Haze is strongest on far hills. | The look Dave already approved (ART_DIRECTION 6). |
| **Afternoon** | Like morning, but warmer, with a little more haze. | |
| **Golden hour** | Deep gold light, every leaf edge and fur rim glowing, long blue shadows. Peaks catch the last light after the valleys go into shade (the "alpenglow" on snow, pink and orange). | This is the moment to make memorable: the hero peak from the town (art_mountains) glows at sunset. |
| **Dusk (blue hour)** | Warm light gone, the sky shading from orange at the horizon to deep blue overhead. The land loses colour. The first stars appear. | The time to light a torch. The game's dusk hint ("Night is dark. Craft a Basic torch") is right. |
| **Night** | See section 6. | |

**Rules:**
1. **One sun, one shadow direction.** Every shadow in the picture agrees with the sun.
2. **Shade is never blue by day** (the warm bounce stays). It goes cool only at dusk and night.
3. **The moon and the sun never light the land together** (today's rule). At dusk the light hands over smoothly and never pops. **[Check]** day_cycle says the light "snaps from sun to moon" in the gap while both are faded. Look for a visible jump in shadows at dusk on a real GPU (section 11).

## 4. Seasons

The year's look follows `weather.gd`'s season phase:

| Season | Light | Land and air |
|---|---|---|
| **Spring** | Clear, cool and bright, with sharp shadows. Showers with sun between: the time for rainbows (see below). | Fresh, pale greens; snow retreating up the peaks; rivers high; morning mist common. |
| **Summer** | High sun, warm, long days and short nights. More haze, and heat shimmer over dry ground in the desert and transition zones. | Deep greens; dust on paths in dry spells; thunderstorms in the afternoon. |
| **Autumn** | Low and golden, with long shadows even at midday. | Autumn colours where flora supports them; the most fog of the year (cold clear nights after warm days); damp, dark ground. |
| **Winter** | The sun stays low all day: golden light, long blue shadows on snow, and short days. | Snow in the arctic zone and on the peaks; bare trees; breath showing in the cold (section 8.4). |

**Rainbows:**
- They appear only with the sun behind the viewer and rain in front.
- They need the sun below 42° and real rain or waterfall spray.
- A rainbow is an arc of fixed angle, centred on the point opposite the sun, at 42° from it.
- **Decided (section 12): rainbows on passing showers**, drawn in the sky with the true geometry.
  - **When:**
    - the sun is up and lower than 42°;
    - rain has fallen within about the last real minute;
    - the sun is breaking through: cloud cover is clearing, so the moment comes as a shower passes, not in a steady downpour;
    - it is not a storm.
    - Snow gives none.
  - **Where:** on the sky opposite the sun.
    - The primary bow runs from violet inside, at 40.6° from the point opposite the sun, to red outside, at 42.4°.
    - A fainter secondary bow, about 40 percent as bright, has its colours reversed and runs from 50.4° to 53.4°.
    - The sky inside the primary is a little brighter, and the band between the two bows (Alexander's dark band) is a little darker.
    - The land in front hides the foot of the bow, as it does in life.
  - **Look:** soft-edged bands of pure spectral colour, faint and never neon, added to the sky. It is dimmed by gloom, eases in and out over a few seconds, and is never in the sky's lighting cubemap.
  - **Later:** the small bow in waterfall spray (`fall_mist.gd`) is still open.

## 5. Sun and moon light

1. **The sun is the key light.**
   - White-warm (1.0, 0.92, 0.80) at noon, gold when low, red on the horizon, as built.
   - It never goes pure white and never turns grey-blue.
2. **The moon is a soft silver-blue light.**
   - It casts real but soft shadows.
   - Under it, colour almost vanishes: the world reads in blue-grey values. This is true to life, because the eye loses colour vision in moonlight.
   - **Decided (section 12):** lower the colour further by night.
     - About half the colour is left under a clear full moon, and about 0.4 on a moonless night. This sits on top of the weather's own storm greying.
     - **Firelight keeps its colour.** The eye sees colour again in the light of a flame, and warm against cold is the night's palette (6.3). So a burning torch or lantern in the hand, or a lit fire within about 6 m (fading out by 14 m), gives back most of the lost colour, about 80 percent, eased over a second or two.
     - **Under rock** there is no moonlight to grey, so caves keep full colour in torchlight.
     - The whole picture shares one saturation, so this is a compromise: with a flame, the dark beyond is a little more colourful than it should be. It is too dark there to notice.
3. **[Proposal: moon phases]**
   - Today the moon is always full, which makes every night equally bright.
   - Give the moon its real cycle of about 29.5 days. Its light scales from full (as now) to almost nothing at new moon.
   - The disc in the sky shows the phase, if a disc is drawn. It stays opposite the sun, a simplification that is fine for brightness.
   - **Why:** dark, moonless nights a few days a month become **"eye nights"**: the nights when a torch matters most, when wolves press close and goblin eyes are seen at the edge of the light. Bright moon nights stay walkable.
   - This is the cheapest way to give the night variety.
4. **Stars:**
   - bright and many on clear moonless nights;
   - fewer near a full moon, which washes out the faint ones;
   - none under cloud (as built).
   **[Proposal]** The Milky Way as a faint band on moonless nights away from town fires.

## 6. Night: how darkness should read

Night is where the game's danger lives: wolves, bears, goblins and later thieves (DESIGN_IDEAS 7.5: "night has to be content"). The darkness must do three things:
- make the torch and the fire feel like safety;
- let a player read shapes and the land so they can still move;
- hide what lives in the dark, until its eyes catch the light.

### 6.1 The rings around a light (the core picture)

| Distance from the player's torch | What the player sees | Why |
|---|---|---|
| **0 to 9 m** | Full warm colour on the ground, plants and faces. Shadows would move with the flame (6.4). | Inside the wolves' `torch_light_m` 9: the safe ring. |
| **9 to 12 m** | Dim, warm, fading light. Shapes read, colours barely. | The edge, inside the torch's 12 m light but outside the wolves' 9 m. **Wolves circle here.** The player must see them as dim shapes moving at the rim. |
| **12 to about 24 m** | Dark. Only **eye shine** (`art_animals.md` section 6) and silhouettes against the sky or snow. | Where goblin eyes appear (decided by the coordinator) and where wolf pairs wait. |
| **Beyond** | The night as section 6.2 sets it. | |

**Rules:**
- **The light must fall off softly**, never as a hard disc. The 9 to 12 m band is the most important in the night picture: never let the light end at 9 m.
- A camp fire gives the same rings at its own sizes (3.5 m, 7 m, 14 m). Wolves keep beyond 10 m (`fire_light_m`), so **only a full fire's light reaches past the wolves' line**. A small fire leaves them in the dark where only their eyes show. That is a good, honest reason to build a big fire.

### 6.2 How dark is dark

These are the target reads with no torch, in the open, after the eye has adjusted:

| Night | Read |
|---|---|
| **Full moon, clear** | The land and every skyline readable far off. Trees as dark masses. A path shows as a paler line. Animals visible as shapes to about 25 m, but the species unclear beyond about 10 m. Almost no colour. |
| **Half moon, or thin cloud** | Skylines readable. The ground near you readable to about 10 to 15 m. Animals are moving shapes only. |
| **New moon, clear** | Starlight: skylines against the stars, the ground only at your feet, paths barely. You can move slowly. |
| **Overcast, storm or rain at night** | The darkest outdoor night: almost nothing but lightning flashes, distant fires and town windows. The floor in `weather_look` keeps it from pure black. |
| **Under forest crowns at night** | Darker than the open by about half: the crowns block the moon. **[Proposal]** Use the existing canopy map (`canopy_map.gd`) to dim the night ambient under crowns. It is cheap and it makes the forest at night frightening, as it should be. |
| **Snow on the ground** | Brighter: snow reflects the moon. A snowy full-moon night is almost bright enough to read colours. **[Proposal]** Raise the night ambient with the snow cover. |
| **Caves** | Pitch black (#447). |

**Rules:**
1. **Outdoors is never pitch black.** Keep DESIGN_IDEAS 7.5 and the ambient floor; I recommend making it decided. The darkest outdoor nights must still show the skyline.
2. **A night is never a dark blue filter over a day picture.** The colour goes, the contrast goes, the sky stays brighter than the land, and lights stay warm.
3. **The torch must make the dark beyond look darker.** That is how eyes work: your eyes are adjusted to the flame. **[Proposal]** While a lit torch is held, lower the exposure by a small step (about 10 to 15 percent) and ease it back over a few seconds when the torch goes out. The ring then reads as a world of its own, and the eyes beyond stand out. It is cheap: one exposure value.
4. **[Check]** I have not seen whether today's night (moon 0.22, ambient 0.24) reads as the full moon row above or brighter. The shadow tint proposal asked for one night shot, `--hour 22`, "to confirm darkness still feels threatening" (section 11).

### 6.3 Firelight colour

1. **Flame light is warm and slightly varied:** torch (1.0, 0.65, 0.3), fires from (1.0, 0.64, 0.34) to (1.0, 0.54, 0.2), as built. Keep every flame inside this orange family. A candle is a little more yellow (`light_m` 4).
2. **Flicker breathes rather than strobes:** slow noise on energy and range (torches-fire.md). Never a flashing light.
3. **Warm against cold is the night's palette:** firelit faces and fur against blue-grey moonlit land. This contrast is the best picture the game has at night; keep both sides of it.

### 6.4 Torch shadows

The held torch casts **no shadow** today. That has two costs:
- **light leaks through rock:** a torch lights the far side of a cave pillar or a thin wall;
- the most atmospheric thing a torch does, shadows swinging as you walk, is missing.

**[Proposal]** Give the held torch an omni shadow from Medium quality up, and leave Low as today. Only the player's own torch, never placed torches (torches-fire.md lesson 6: light count costs frames). This needs a GPU check on Dave's PC before it is built.

## 7. Fog, mist and cloud

Today there is one even haze. That is right for clear air, but **mist is what makes mountains and water look real and old**. These are the kinds to build, in priority order:

| Kind | When and where (real rule) | Look |
|---|---|---|
| **1. Valley fog (radiation fog)** | Calm, clear nights. It forms before dawn in low ground, river valleys and over lakes, and burns off from the edges 1 to 3 hours after sunrise. Most common in autumn. | A flat white sea filling the valleys, with hills and trees standing out of it. Seen from above at sunrise, it is the most beautiful sight on the island. |
| **2. Steam fog over water** | Cold air over warmer water: autumn and winter mornings, and over warm springs. | Thin wisps rising and drifting off the water surface, a metre or two tall. |
| **3. Cap cloud on peaks** | Moist wind over a high summit. A cloud sits on and just downwind of the peak while the sky elsewhere is clear. | A white cap or banner on the hero peak, slowly re-forming. |
| **4. Sea fog** | Warm moist air over cold sea, rolling onto the coast. | A grey bank offshore, sliding over beaches and low headlands. |
| **5. Rain haze** | In rain (as built: fog thickens). | Grey, soft, far hills gone. |
| **6. Waterfall spray and cave-mouth mist** | Built (`fall_mist.gd`) and specified in `art_caves.md` section 3. | |

**Rules:**
1. **Fog has a top.** Valley fog and sea fog lie in a layer with a clear sky above. A fog that is equally thick everywhere and at every height reads as a draw-distance trick. **[Proposal]** Use Godot's height fog (`fog_height` and `fog_height_density`, which are set to 0 today). Give the weather a `mist` value per zone, season and hour, from the rules in the table, the same everywhere for everyone (`weather.gd` is a pure function, so it stays one).
2. **Fog is lit by the sky and the sun:** white at sunrise, gold where the sun hits its top, blue-grey at night, warm around a fire. It is never a flat grey card.
3. **Clouds and peaks.** The cloud layer is about 2 km up.
   - Starter summits (1000 to 1450 m) stay below it.
   - The bigger islands go higher: volcano 1500 to 2300 m, three-peak 2000 to 2700 m, giant up to 3400 m (art_mountains, D-10). The higher ones **reach or rise through the cloud layer**.
   - The sky draws its clouds behind the terrain, so a peak can never be **in** the cloud.
   - **[Check, then Proposal]** On a giant island, look at a summit above 2 km. If the clouds cannot wrap it, add cap-cloud cards (item 3 in the table) at the cloud level around high summits, and let the cloud layer thin near the peak. "Above the clouds" is a great picture if it is drawn honestly.

## 8. Rain, snow, wind and storms

### 8.1 Rain

1. **What is built works:** rain only from cloud, overcast and dimming, wet glossy ground, dry under crowns, and murky storm water. Keep all of it.
2. **What to add, in order:**
   - **Puddles** in hollows on paths and flat ground, with ripple rings (the water rules in `art_water.md`). **Decided (section 12)**, the rules are in 8.1.1.
   - **Wet rock and bark** darker and shinier, the same as the ground.
   - **Drips from leaves** for a minute after the rain stops.
   - Rain streaks **lit by any light near them**: rain sparkling in the firelight is a strong, true look.
3. **Rain at night:** a torch goes out in open rain, so rain nights push the player under trees, overhangs and roofs, where the torch survives (the cover query). Keep this. It is a good reason for shelter and it makes rain nights the darkest (6.2).
4. **After rain:**
   - the air is clearer (less haze for an hour);
   - sun breaks in shafts through gaps in the cloud;
   - a rainbow if the geometry allows (section 4).

### 8.1.1 Puddles

Puddles are the cheapest strong sign that it has rained, and a track that shines with standing water after a storm reads at once. They are a look and a sound only: nothing in the game reads them, they are not saved and the server does not know them.

1. **Where they form:**
   - Only on flat ground: full below about 10° of slope, gone by about 18°. Water does not stand on a hillside.
   - In hollows. The hollows are a fixed pattern on the ground (two sizes of noise, about 3.6 m and 1.1 m), so a puddle is 0.5 to 3 m across, irregular, and always in the same place. The voxel ground is 1 m, too coarse to hold the real dips, so the pattern stands in for them.
   - The ground decides how easily water stands:

     | Ground (shader layer) | Proneness | Why |
     |---|---|---|
     | Mud and clay | 1.0 | water cannot sink in |
     | Worn trails (the game trail map) | + 0.5 on top of the ground | trampled earth is packed hard; tracks are where puddles are |
     | Gravel and stony soil | 0.7 | packed, but drains quickly |
     | Flat bare rock | 0.6 | shallow pools in dips of the stone |
     | Turf (silt, loam, alluvium) | 0.35 | grass roots drink it |
     | Litter (humus, peat) | 0.25 | spongy |
     | Sand and beach | 0 | it sinks in at once |

   - None under closed crowns (the canopy map, the same shelter that keeps the ground dry), none on lying snow, none within 1 m of sea level, none in caves (they fade out with the cave light when the player is under rock).
   - Drawn to about 120 m, gone by 220 m.
2. **Filling:**
   - Each ground type keeps its own level from 0 dry to 1 full.
   - It rises while rain is above 0.15, by 2.5 x (rain - 0.15) per game hour. Steady rain (0.65) fills it in about 50 game minutes (2 real minutes); a storm in about 25.
   - The level sets how much of the hollow pattern is water: a little rain fills only the deepest hollows on the most prone ground; a full level joins them into broad sheets along a muddy track, while turf shows only a few.
3. **Draining after the rain** (game hours; one game hour is 2.5 real minutes):

   | Ground | Dry again in |
   |---|---|
   | Gravel | 1 h |
   | Turf | 1.5 h |
   | Litter | 2 h |
   | Flat rock | 2.5 h (it only dries in the air) |
   | Mud and clay | 3 h |

   Light rain below 0.15 halves the draining. A frozen puddle does not drain until it thaws.
4. **Freezing:** puddles follow the ice rule (`src/shared/ice.gd`, the same number the ponds use) with a 0.1 m depth, so they freeze before the ponds and thaw before them. They look frozen from 2 cm of ice and fully from 5 cm: pale grey-white, glossy, with faint white cracks and trapped bubbles, and no ripples. A frozen puddle does not splash (a thin-ice crunch is a later sound job).
5. **The look:**
   - Clear water over mud: the ground under it darkens to a brown-black, and the surface is a mirror (roughness about 0.03, flat), so it shows the sky and the sun. At night it reflects only the night sky, dimly, and a torch's own light: it never glows.
   - A damp darker rim of about 10 cm around each puddle.
   - **Rain rings:** drops land on a jittered 0.3 m grid, each ring grows to about 12 cm and fades in about 0.6 s, more of them the harder it rains.
   - **Wind ruffle:** fine ripples drifting downwind (`wind_dir`) from wind 0.2 up, stronger with wind. In calm air the puddle is a still mirror.
   - Ripples are drawn within 40 m; beyond, a plain mirror.
6. **Steps splash:**
   - The splash sound (`step_water`) now plays only when the foot is in a drawn puddle, not by chance while the ground is wet. The wet squelch on soaked ground stays as it is.
   - A small visible splash with it: a ring on the water and a few drops thrown 0.2 to 0.4 m up, gone in half a second, bigger at a run. Lit by the scene like the breath puffs.
   - Animals within 25 m splash the same way when a foot lands in a puddle (a bigger splash for a big animal).
   - At most 12 splashes at once from one pool.
7. **Cost:** a few uniforms on the ground material; the puddle work runs only on flat ground within 220 m while any level is above 0, and the ripples only within 40 m. The ice is checked every 10 s.
8. **Limits:** the hollows are a pattern, not the true small dips of the ground; a cave floor seen from outside its mouth can show a puddle; puddles do not feed the water simulation or give drink.

### 8.2 Snow

1. **What is built:** falling flakes, white flat ground, buried grass, none under trees.
2. **What to add:**
   - **Snow on the tops of conifer branches and on rocks and roofs**, not only flat ground. **Branches and crowns are decided (section 12)**:
     - It follows the ground's own snow memory (`ground_snow`: it settles in snowfall and melts slowly), so trees whiten and clear together with the ground.
     - It lies only on the upward-facing parts of a crown (the tops of needle and leaf clusters, bare twigs in winter) and on the upper side of branches, with a patchy edge. The undersides and the trunk stay dark, which is what makes a snowy forest read.
     - Far tree images take the same white on the upper half of their crowns.
     - Snow is a soft, slightly blue-white (about 0.86, 0.88, 0.92), never pure white.
     - Rocks and roofs are still open.
   - **Steep faces stay dark**: snow does not hold above about 50°. This gives mountains their black-and-white striping (art_mountains).
   - **Footprints and trails** in snow, a later gameplay look.
3. **The snow line:** the climate rule (snow below -8 °C, lapse 6.5 °C per km) gives no snow on a 1450 m starter summit. Summer snow patches above about 80 percent of the summit are decided in art_mountains section 10, and the per-island snow line is on Sonny's list after the chain.
4. **Snow at night** brightens the land (6.2). Flakes caught in torchlight glow warm near the flame.
5. **Blizzard:** white-out, the far land gone, wind-driven snow at an angle. The most dangerous, most beautiful weather.

### 8.3 Wind

1. Wind shows in grass and tree sway, drifting snow, rain angle, smoke and fire lean, and cloud speed. **They must all agree on one direction** (`wind_dir` in the weather state).
2. Smoke from fires and chimneys leans and bends downwind. This is the cheapest way to show wind in a still picture.

### 8.4 Cold

**Decided (section 12): breath shows in the cold.** It is the single best cue that a morning is cold, and it ties to the warmth system.

1. **When:**
   - It starts at 5 °C air and is fully visible by -5 °C.
   - The air is the weather's temperature at the player's height plus the warmth system's day and night swing (`warmth.json` `daily_swing_c`): the coldest is just after dawn and the warmest mid-afternoon. So breath shows on cold mornings before it shows at noon.
2. **Who:**
   - the player: a faint cloud just below and ahead of the view in first person, from the head in third person;
   - the nearest animals and goblins within about 15 m, at most 8, from the head bone (or the code body's head);
   - other players later, once their avatars can be reached the same way.
3. **Look:**
   - A soft, round, pale grey puff on a camera-facing card.
   - It grows from about 0.15 m to 0.5 m, rises a little, drifts with the wind and fades in about 1.5 s.
   - **It is lit by the scene, never glowing**, so at night it shows only in torch or firelight. That is true, and it makes a firelit camp in winter beautiful.
   - One puff per breath: every 3 to 4.5 s for a person, every 4 to 6 s for big animals, with a small random lag so a herd does not breathe in step.
   - None under water.
4. **Cost:** a pool of at most 32 small cards with one shared material and nothing else; nothing at all above 5 °C.

### 8.5 Storms and lightning

Built: dark skies, a flash, the bolt from Medium up, and the flash and thunder sharing one event.

1. **Keep the delay:** the flash first, the thunder after, by distance. A strike 1 km away is about 3 s behind its flash.
2. **A lightning flash at night** lights the whole land for an instant, white-blue, with hard shadows.
3. **[Proposal]** The flash briefly shows any animal or goblin standing in the open, as a black silhouette or a lit shape. A true and frightening use of the light.

## 9. Zones and town spirit

ART_DIRECTION 9 already rules that sky, light, fog and rain read three inputs: zone, season and town spirit.

| Zone | Light and air |
|---|---|
| **Desert** | Hard white light, deep short shadows, heat shimmer, dust haze that turns far land ochre, clear star nights. |
| **Transition** | Warm, dry summers with dust in the air; green after rain. |
| **Temperate** | The rules above; the starter islands. |
| **Arctic** | Low sun, long blue shadows, snow glare by day, very clear cold air (far land sharp), long nights. Aurora is a [Proposal] for clear arctic nights. |

**Town spirit**, when it exists:
- **High spirit:** warm light, gentle night rain, clear mornings with valley mist.
- **Low spirit:** heavy skies, colder light, more storms.
- **Rule:** spirit bends the weather the system already makes, never a colour filter over the town.

## 10. Never-see list

1. Light with no source: glowing fog, glowing water at night, ambient light inside caves (art_caves section 4).
2. A night that is a blue tint over a day picture, or a night so bright the torch makes no difference.
3. Pitch black outdoors (caves only).
4. The torch light ending in a hard edge at 9 m, or wolves at the rim that cannot be seen.
5. Sun and moon shadows together, or a visible jump at the dusk handover.
6. Rain from a clear sky, or sun through full overcast (as ruled).
7. Fog equally thick at every height, or fog with no change across the day.
8. A peak drawn in front of a cloud it should be inside.
9. Wind directions that disagree (rain one way, smoke another).
10. Flicker that strobes.
11. A rainbow in the wrong place relative to the sun.
12. A puddle on a slope, a glowing puddle at night, or a splash where no water is drawn.

## 11. Pictures to collect (Dave's PC, after the gate queue; not before)

1. One full day at the spawn (about 53296, 68080), one shot every game hour, facing the hero peak, in summer and in winter.
2. Night at `--hour 22` and `--hour 2`:
   - no torch;
   - torch held;
   - a full fire, with a wolf at 10 m.
   Check the 9 to 12 m ring and that the dark still feels threatening.
3. Dusk at 30-second steps through the sun-to-moon handover: is there a shadow jump?
4. Rain at noon and at night under a tree with a torch, and a blizzard.
5. A summit above 2 km on a giant island seed, with clouds: does the peak sit in front of the cloud?
6. The same forest scene at night in the open and under crowns.

## 12. Decisions (8 Nov 2026, decided by the coordinator from these recommendations; Dave may overrule)

1. **Moon phases (5.3): yes.** Owner: Kathleen.
2. **"Never pitch black outdoors" (6.2.1): a decided rule.** Owner: Kathleen. Caves stay pitch black.
3. **A darker night under crowns using the canopy map (6.2): yes.** Owner: Kathleen. The brighter night with snow is still open.
4. **A small exposure drop while a torch is held (6.2.3): yes.** Owner: Kathleen. It is built as a 15 percent drop of the moon and sky light rather than of the exposure, because exposure would also dim the torch's own pool of light; the picture beyond the flame is the same.
5. **A held torch shadow from Medium up (6.4): only after a GPU check on Dave's PC.** Dino does the check when the PC frees up, not now.
6. **Height fog and a `mist` value in the weather state, valley fog first (7): yes.** Owner: Jamie, after his rivers doc.
7. **Cap cloud cards for summits above the cloud layer (7.3): only after a check picture from Dino.**
8. **Breath in the cold (8.4), rainbows (4), snow on branches (8.2.2), lower colour at night (5.2) and puddles (8.1.2): yes.** Kathleen owns lower colour at night and breath (#605), then snow on branches and rainbows, each on one branch. Puddles: Kathleen, rules in 8.1.1, code stacked on the snow and rainbow branch.
9. Still open: the rest of the rain additions in 8.1.2, the Milky Way (5.4) and the arctic aurora (9).

Kathleen's night-light code is one branch, in this order: moon phases, the never-pitch-black rule, canopy darkening, the torch exposure drop (#601: a 29.53-day moon with a full moon on day 100, `OUTDOOR_FLOOR` 0.18, crowns take up to 45 percent at night, a held flame 15 percent). This document stays the source of truth.
