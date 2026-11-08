# Fog and visibility: how far you see, when fog comes, what it does to sound, smell, animals and lights, and the dusk curve at 57° S

**Last checked:** 2026-11-08 (Jamie; built mostly from pages already in this library and our sums, with the web fetch budget nearly spent. The fetches to do next are listed at the end). **Owners:**
- Kathleen: the fog look (#608 sea fog, #672 fog from above, valley fog in `weather.gd`).
- MikeW: animals in fog.
- Steve: anything that uses sight range.

**Related:**
- [firelight-in-weather.md](firelight-in-weather.md): fog classes, Koschmieder, torch veil and halos.
- [sound-outdoors.md](sound-outdoors.md) lesson 7: fog and sound.
- [animals-in-weather.md](animals-in-weather.md).
- [moonlight-starlight.md](moonlight-starlight.md): night light levels.
- `one-sky.md` (#706): sun and twilight times.
- [sea-and-shore.md](sea-and-shore.md).
- `prevailing-wind-57s.md` (#714).

## Lessons (read these first)

1. **Fog is named by how far you can see. You can just make out a dark object at that distance, recognise it at half, and see detail at a quarter.**
   - **The classes:**
     - Met Office: fog is visibility under 1,000 m, thick fog under 180 m and dense fog under 50 m ([firelight-in-weather.md](firelight-in-weather.md) lesson 2);
     - mist is the same thing thinner, with visibility of 1 km or more (WMO usage, from memory; to be fetched).
   - **Koschmieder's rule:** the visibility V is where a dark object's contrast against the fog falls to 2%. The contrast left at distance x is e^(−3.912 x ÷ V).
   - **Our sums:** at 0.5 V, 14% of the contrast is left; at 0.25 V, 38%.
   - **Judged rule for the game:**
     - you see something is there at V;
     - you recognise what it is (deer or wolf) at about half V;
     - you see detail (antlers, a face, a track) at about a quarter of V.

2. **Valley fog forms on calm, clear nights, is thickest around dawn, and burns off 1 to 3 hours after sunrise.**
   - This is radiation fog: the ground cools under a clear sky, the air at the bottom cools to its dew point, and cold air drains into the hollows. Wind over a few m/s mixes it away, and cloud stops the cooling. `weather.gd` already does this (gathering from 22:00, full 4 hours later, burning from 1 to 3 hours after sunrise, `MIST_CALM_WIND` 0.3, `MIST_WINDY` 0.5).
   - **It deepens just after sunrise** (judged, common observation): the first sun stirs the layer, and for half an hour to an hour the fog can thicken and rise before it thins.
   - **Season:** most common in autumn and early winter, when nights are long and the ground is still wet (`weather.gd` notes autumn).
   - **At 57° S the winter sun is weak.** The midwinter noon sun is only 9.6° high (`one-sky.md`, #706). So in midwinter a valley fog can last all day in a deep valley (judged). Burn-off also follows sunrise, which is 08:39 at midwinter.
     - `weather.gd` still draws its sunrise for 52° N (`SUN_LATITUDE_DEG` 52.0). So its burn-off hour is wrong for our island, and its seasons fall in the wrong half of the year.

3. **Sea fog comes in on light onshore winds when warm, damp air crosses a cold sea. It lasts day and night and drifts inland.**
   - This is advection fog. On the east coast of Scotland it is the haar, which comes in spring and early summer, when the sea is coldest against the air (Met Office, from memory; to be fetched).
   - **Mirrored for us** (judged): spring and early summer is **October to January**. The warm, damp air comes from the north in the southern hemisphere, so look for sea fog on a light N to NW wind over a cold sea.
   - **How it behaves** (judged):
     - day or night, it does not need clear skies;
     - it lies on the sea and the shore and drifts 1 to 5 km inland up low ground;
     - inland, the afternoon sun burns it back to the coast, and it comes in again at evening;
     - a wind over about 8 m/s (wind 0.5) lifts it into low cloud;
     - a calm lets it sit for days.
   - The west coast of a Hebrides-like island gets less of it than the east, because the westerlies blow off the open ocean (judged).

4. **Fog does not carry sound; calm air does. And damp, calm air holds scent near the ground.**
   - **Sound:** fog damps the high notes, and low sounds carry best. A foggy morning is quiet because it is calm, with a cold layer at the ground ([sound-outdoors.md](sound-outdoors.md) lesson 7). Kathleen's #683 page has the hearing ranges.
   - **Scent** (judged, the usual tracker's rule):
     - cool, damp and calm air is the best for scent;
     - moisture keeps scent from drying out and lifting, and calm keeps it near the ground and close to its source;
     - so in fog, a scent trail lasts longer and is easier to follow. But a scent carried on a breeze reaches less far, because there is no breeze.

5. **Animals in fog lean on hearing and smell, keep together and stay put.**
   - All of this is judged, from field observation in general and not yet sourced:
     - **Herd animals** (sheep, cattle, deer) bunch closer and stay near cover or a known spot. They move less, but feed on. Sheep in fog stand and wait.
     - **Deer:** fog is cover. They may feed later into the morning in fog than on a clear morning, because the dawn light that sends them in does not come.
     - **Birds:** most land and sit out thick fog. Songbirds stay low and quiet. Gulls and waders sit on the water or the shore. Raptors and ravens do not hunt in thick fog, because they hunt by sight.
     - **Bats** fly by echolocation and are not grounded by fog. But there are fewer insects, so less hunting.
     - **Predators:** wolves can use fog to get close, since sight is short and scent is good.
     - **Spook range:** shrinks to what the animal can hear and smell. A careful approach from downwind gets much closer than on a clear day ([animals-in-weather.md](animals-in-weather.md) Fog: sight ranges cut with the fog distance).

6. **In fog, eye shine fades twice as fast as the fog, because the light goes out and back.**
   - Eye shine is your own light reflected straight back from an animal's eye. In fog it crosses the distance twice.
   - **Our sums:** the 2-way contrast is e^(−2 × 3.912 x ÷ V). It falls to 2% at half the visibility, and to 5% at 0.38 V.
   - On top of that, the torch's veil (its light scattered back into your eyes) hides faint points of light.
   - **Judged:** in fog, eye shine shows to about a third of the visibility, and only with the torch held low.
   - A torch in fog makes a glowing ball and a halo, and its reach falls by 10 to 50% with the fog class ([firelight-in-weather.md](firelight-in-weather.md) lessons 2 to 4).

7. **After sunset at 57° S, the light falls over about an hour and a half to two and a half hours. In midsummer it never gets fully dark.**
   - **Twilight times** (`one-sky.md`, #706, from standard solar formulas):

     | Day | Sunset | Civil end (sun 6° down) | Nautical end (12°) | Astronomical end (18°) |
     |---|---|---|---|---|
     | Equinox | 18:06 | 18:44 (+38 min) | 19:30 (+84 min) | 20:18 (+132 min) |
     | Midwinter | 15:21 | 16:11 (+50 min) | 17:02 (+101 min) | 17:49 (+148 min) |
     | Midsummer | 20:56 | about 22:05 (+69 min) | never | never |

   - **Light at each stage** (common reference values, from memory; to be fetched):
     - about 400 lux at sunset under a clear sky;
     - about 3 lux at the end of civil twilight;
     - about 0.01 lux at the end of nautical;
     - under 0.001 lux at the end of astronomical twilight.
     - The full moon gives 0.25 lux ([moonlight-starlight.md](moonlight-starlight.md)).
   - At these latitudes the sun sets at a slant, so twilight is longer than in the tropics. It is longest at midsummer.

## Judged numbers for MikeW and Kathleen

### How far you see

| Weather | Visibility V | See something (V) | Recognise it (½ V) | Detail (¼ V) |
|---|---|---|---|---|
| Clear | 20 km or more | — | a deer at 300 to 500 m (limited by eyesight) | 50 to 100 m |
| Haze or light mist | 2 to 5 km | 2 to 5 km | as clear | as clear |
| Mist | 1 to 2 km | 1 to 2 km | 500 m to 1 km | 250 to 500 m |
| Fog | 180 to 1,000 m | 180 to 1,000 m | 90 to 500 m | 45 to 250 m |
| Thick fog | 50 to 180 m | 50 to 180 m | 25 to 90 m | 12 to 45 m |
| Dense fog | under 50 m | 20 to 50 m | 10 to 25 m | 5 to 12 m |

- **Animals' sight range in fog** = min(their clear sight range, ½ V) for knowing a person; their "something moved" range is V.
- **Hearing and smell ranges** do not shrink in fog. Hearing grows a little in the calm. Smell along a trail grows (judged ×1.25); scent on the wind shrinks with the calm.

### Valley fog

- **Forms:** calm (wind under 0.3), clear sky, in the low ground. Thickest from about an hour before dawn to an hour after.
- **Thickness:**
  - in the valley floor, thick fog (50 to 180 m visibility) at its height;
  - mist on the slopes just above the top (`mist_top_m` 30 to 140 m);
  - clear above, with the fog sea seen from the hills (#672).
- **Burn-off:** 1 to 3 hours after sunrise in spring and autumn. In midwinter in a deep valley it may not burn off at all (judged).
- **Season:** autumn into early winter, March to June for us (judged, mirrored).

### Sea fog (#608)

- **When:** October to January (judged, the mirrored haar season), on a light N to NW onshore wind, wind 0.15 to 0.45. Lifts to low cloud at about 0.5.
- **Visibility:** 50 to 500 m on the shore (judged).
- **Reach:** the sea and the coast, drifting 1 to 5 km up low ground. Burns back to the coast on a sunny afternoon and returns at evening.
- **Days:** it can last 1 to 3 days in a calm (judged).

### Animals

| Animal | In fog | Change |
|---|---|---|
| Sheep, cattle, horses | bunch, stand or graze close to a known spot | herd spread halved (judged) |
| Deer | keep feeding into the morning; stay near the wood edge | dawn retreat delayed 1 to 2 hours (judged) |
| Songbirds | sit low and quiet | calls cut to a few |
| Gulls, waders | sit on water or shore | no flights over land |
| Raptors, ravens | perch and wait | no hunting flights in thick fog |
| Bats | fly as usual | fewer passes (fewer insects) |
| Wolves | hunt closer in | approach unseen to ½ V |

### Lights in fog

- **Eye shine:** shows to about ⅓ V (2-way loss), and only with the light near the viewer's eye or held low. Inside 5 m in dense fog, the torch's own glow hides it.
- **Torch and fire:** use [firelight-in-weather.md](firelight-in-weather.md). The reach falls 10% in fog and 50% in dense fog, with a halo of about 4° and a glowing ball round the flame. A far fire through fog shows as a point with a halo within 1 V, as a glow out to 3 V, and as nothing beyond.

### Dusk at 57° S

| From sunset | Light (clear sky) | What you see (judged) |
|---|---|---|
| 0 | about 400 lux | daylight colours, fading |
| civil end, +40 to +70 min | about 3 lux | colours gone; shapes clear; a deer at 100 m against the sky |
| between civil and nautical | 0.1 to 1 lux | outlines; large animals at 30 to 50 m |
| nautical end, +85 to +100 min | about 0.01 lux | the horizon line only; animals at under 10 m unless against the sky |
| astronomical end, +130 to +150 min | under 0.001 lux | starlight; nothing without a moon or a torch |

- **Cloud** divides the light by 3 to 10 (judged; `moonlight-starlight.md` has overcast). **Fog** adds its own V limit on top.
- **Midsummer:** after civil twilight the light stays around nautical-twilight levels all night, a low pale glow in the south. Never pitch black.

## Never-see checks

- seeing a deer clearly at 200 m in thick fog;
- valley fog on a windy night, or under full cloud;
- a valley fog still lying at noon on a sunny spring day;
- sea fog in a gale;
- birds of prey hunting in dense fog;
- eye shine at the edge of the fog in a dense fog;
- a midsummer midnight as dark as a midwinter one;
- fog that muffles every sound like a blanket.

## How ours works today (read from the code, 8 Nov, not tested)

- **`weather.gd` valley fog:**
  - `mist` (0..1) and `mist_top_m` (30 to 140 m), gathering from 22:00 (`MIST_FROM_HOUR`) over 4 hours;
  - burning off 1 to 3 hours after sunrise, only in calm (`MIST_CALM_WIND` 0.3, none from 0.5) and clear weather;
  - `MIST_BY_ZONE` temperate 1.0.
  - **Finding:** `SUN_LATITUDE_DEG` is 52.0, so the sunrise and seasons it uses are for 52° N, not our 57° S (`one-sky.md`, #706).
- **`weather_look.gd`:** has a "fog" look preset with `mist` 1.0 and `mist_top_m` 90. Its thickness grows by 12 × fog on top of rain and snow.
- **Sea fog** is Kathleen's #608 (open), and fog from above is #672 (open). Neither was read for this page.
- **Animals:** no fog rule found in `server_animals.gd` in this pass (not searched in depth).

## Sources

- Met Office, Fog (classes by visibility), and Koschmieder's rule: both as cited on [firelight-in-weather.md](firelight-in-weather.md).
- University of Wisconsin SSEC, Does sound travel better in fog? (as cited on [sound-outdoors.md](sound-outdoors.md)).
- Twilight times: `one-sky.md` (#706), from standard solar formulas.
- Full-moon light: [moonlight-starlight.md](moonlight-starlight.md).
- Our sums: contrast against distance, eye shine 2-way loss.
- **Judged or from memory, not fetched today:** mist's lower limit, the haar season, light levels at each twilight stage, all the animal behaviour, scent in damp air, sea fog reach and lift.

## Fetches to do next hour (to upgrade the judged lines)

1. Met Office "haar" or sea fog page: the season and the onshore wind that brings it, and how far inland it reaches.
2. WMO or Met Office definition of mist, with its visibility range and humidity.
3. A source for illuminance at sunset and at the civil, nautical and astronomical twilight ends (for example a USNO or IES table).
4. Radiation fog life cycle: the post-sunrise deepening, typical depth, and wind limits (Met Office, or a fog climatology paper).
5. Scent in fog and humidity: a search-dog or tracking source on scent conditions.
6. Bird behaviour in fog: grounded migrants, and raptors not hunting (an ornithology source).
7. Sheep and deer in fog: any farm or deer-stalking source on bunching and feeding times.
8. Sea fog climatology for a Southern Ocean or Hebridean station (fog days by month).
