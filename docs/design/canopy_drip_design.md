# Canopy drip after rain: by rain amount and tree kind, with its sound

**Owner:** Kathleen. **Status:** design, 8 Nov 2026.
**Reads:** Jamie's `docs/knowledge/trees-in-weather.md` (#675), "Canopy drip after rain" and lesson 4 (interception: a crown holds at most about 4 mm, conifers far more than broadleaves). It builds on the drips of rain step 4 (#656, `src/client/rain_drips.gd`, `--rain-look`).

One switch, `--canopy-drip`, on top of `--rain-look`. It stays off until Dino's pictures, and the sound part until Dave's listen.

## 1. What is wrong with #656 alone

- **The crowns fill in 10 game minutes whatever the rain.** A two-minute shower and a day of rain leave the same drip after them. Jamie: "the crown empties its stored 1 to 4 mm", for 15 to 60 minutes.
- **Every tree is the same.** A conifer holds about twice a broadleaf's water. A bare winter broadleaf holds little.
- **No drip sound after the rain.** `weather_sounds.gd` plays leaf drips under cover only while rain is 0.15 or more. Jamie: "in the forest after rain, the patter goes on when the open field is already quiet."

## 2. The rules (`--canopy-drip`)

### The crown store, in mm of water

- **Capacity** by the trees around the player:
  - conifers 3 mm, broadleaves in leaf 1.5 mm, bare winter broadleaves 0.5 mm (Jamie: up to about 4 mm; conifers lose 25 to 45 % of the year's rain to interception against 10 to 25 % for broadleaves);
  - the mix is the share of conifers in `tree_wind.gd`'s nearness-weighted stand densities (the same trees that pick the pine or leaf wind loops);
  - `cap = 3 x conifer + (1.5 or 0.5 in winter) x (1 - conifer)`.
- **Filling, while rain falls (rain over 0.05):** the store gains the rain's own rate (rain 0..1 is 50 x rain^2.5 mm/h, as the puddles use) until it reaches the cap. So a light shower half-fills a broadleaf, and steady rain (17 mm/h) fills a conifer in about 10 game minutes.
- **Emptying, after the rain:**
  - `dS/dt = -(0.04 + 0.01 x S) mm per game minute`, times `(1 + 2 x wind) x (1 + sun)`;
  - a full conifer (3 mm) drips for about 56 game minutes on a still grey day, a full broadleaf (1.5 mm) for about 32 and a light shower's 0.75 mm for about 17. That is Jamie's 15 to 60, longer in calm air;
  - a sunny breeze takes it to a few minutes.
- **The drip strength** the drops and the sound use is `min(S / 1.5, 1)`.

### The drops

#656's `store` (0..1, the drop rate and the drip line) becomes the drip strength above. Nothing else changes: where the drops fall, their look and their cost.

### The sound

- **When:** `weather_sounds.gd` drips play under cover (cover 0.5 or more) while rain is 0.15 or more, as today, **or** while the drip strength after the rain is over 0.05.
- **How often:** the gap uses the larger of the rain and 0.8 x the drip strength. So the drips thin out as the crowns empty.
- **How loud:** after the rain (the rain under 0.15), drips are 2 dB louder and 10 % lower in pitch. Fewer, heavier drops: Jamie says drops over 1.5 mm are drip.
- **How it is fed:** `weather_look.gd` passes the drip strength to the weather sounds once a frame, as `canopy_drip`. The existing `rain_drip` clips are used, so no new sound slots are needed.

## 3. Never-see and never-hear checks (`test_canopy_drip.gd`)

1. A two-minute shower dripping as long as a day of rain: after 2 game minutes of rain 0.3 (about 2.5 mm/h) the store is under 0.15 mm, so it is dry within about 4 minutes.
2. A conifer and a broadleaf dripping the same: full stores drip about 56 and 32 game minutes on a still grey day.
3. Drips on in a sunny breeze an hour later: with sun 1 and wind 0.5 the conifer's store is gone within 15 game minutes.
4. A silent forest just after the rain: a drip strength over 0.05 lets the drip sound play with rain 0.

## 4. Pictures and listen

Run with `--rain-look --canopy-drip --shot-settle=60`, then with `--rain-look` only. The camera is under the broadleaf stand of the trees note (#682):

- **Camera:** x 53296, z 68056, 1.7 m above the ground, yaw 90, pitch 10 (looking west, slightly up into the crowns), hour 12.
- If no crown is overhead in the first frame, run `flora_near.gd -- --at=53296,68080 --species=oak,beech,birch,spruce` and stand 2 m inside the edge of the nearest stand. Send me the numbers.

`--shots="drip_rain:53296,2,68056,90,10,12,rain;drip_after_1:53296,2,68056,90,10,12,clear;drip_after_2:53296,2,68056,90,10,12,clear;drip_after_3:53296,2,68056,90,10,12,clear"`

- Shots are 60 s apart, which is 24 game minutes each.
- With the switch, `drip_after_1` still drips, `drip_after_2` is thinner (under a broadleaf) and `drip_after_3` is dry.
- Without the switch, all three after-rain shots are nearly the same as #656.
- **Listen (Dave, `--sound-log=1`):** drips are heard under the trees for a while after switching to `clear`, thinning out, and none in the open field.
