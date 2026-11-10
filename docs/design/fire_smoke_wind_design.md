# Fire smoke and sparks in the wind

**Owner:** Kathleen. **Status:** design, 8 Nov 2026. **Behind:** `--fire-smoke` (off until Dino's pictures).
**Reads:** Jamie's research page `docs/knowledge/fire-outdoors.md` (#668): lessons 5 and 6, "Smoke height downwind", "Wind on a fire", never-see checks 1, 2, 3 and 6. Wind speed in m/s = 20 x wind^1.3 (`wind-over-terrain.md`, #637).

## 1. What is wrong today

Read from `building_look.gd` on main:

- **Campfires have no smoke.** `fire()` builds coals, flame cards, ember sparks and a light. Jamie's never-see check 2: "a fire with no smoke at all".
- **Sparks ignore the wind.** `_ember_sparks` rise straight up (gravity +0.25 up) in a gale (check 3).
- **Forge smoke drifts one fixed way.** `_smoke_plume` has gravity (0.25, 0.1, 0) whatever the wind, so it can blow upwind (check 1).
- **There is no night shape.** On a still, clear night smoke should rise a few tens of metres and spread flat, not climb forever (check 6).

## 2. One shared update

The world wind is one value for the island (`weather.gd` `wind`, `wind_dir`), so every fire shares it.

- **What gets updated:** the particle process materials are already shared statics (`_embers`, `_smoke`), plus a new `_camp_smoke`.
- **How:** once a second, `weather_look.gd` calls `BuildingLook.set_fire_air(wind_ms, heading, still_night)`, which sets the direction, speed and gravity of those few materials.
- **Cost:** a few property writes a second, the same with one fire or fifty, because particles run in world space.
- **Inputs:**
  - `heading`: where the wind blows toward, `wind_dir` as in `wind_cue.gd`;
  - `wind_ms`: 20 x wind^1.3;
  - `still_night`: the same calm, clear night share the sound work uses (`outdoor_air.night_share` x `calm_share`). It is computed here from the sun height, the hour, the cloud and the wind, so this needs no sound code.

## 3. Rules

### 3.1 Campfire smoke (new)

- **A plume on every lit campfire**, sized by tier:

  | | Small (tier 1) | Medium (tier 2) | Large (tier 3) |
  |---|---|---|---|
  | Particles | 14 | 22 | 32 |
  | Life | 16 s | 16 s | 16 s |
  | Rise speed `w` | 0.30 m/s | 0.39 m/s | 0.53 m/s |
  | Starting puff | 0.5 m | 0.7 m | 0.9 m |

  The rise speeds are Jamie's Briggs table: 3.0 / 3.9 / 5.3 m above the flames at 10 m downwind in 1 m/s of wind. Each puff grows 4 times over its life. A plume is already full when it comes into view (preprocess).
- **Speed and direction:** each puff leaves with the wind's speed along the heading, plus its rise speed up. The direction is `normalize(wind_dir x u + up x w)` and the speed is that vector's length. The height at 10 m downwind is then 10 x w / u, which matches the table: 3 m at 1 m/s for a small fire, and about 1.5 m (head height) at 2 m/s.
- **Near calm** (u under 0.5 m/s): a column. The rise speed is at least 0.8 m/s, and the spread is 8 degrees.
- **Still, clear night** (`still_night` > 0): the column rises at 1.5 m/s and slows to a stop at about 12 m as its 16 s life ends (vertical brake -1.5 / 16 m/s²). There it spreads flat as the puffs grow and fade, so it reads as a thin layer.
- **Look:** a lit grey-white smoke (`CAMP_SMOKE_SHADER`). The fire's own light shows on its underside at night, so it never glows on its own in the dark.

### 3.2 Forge smoke

The same rule replaces its fixed drift, using the large fire's rise speed. Its shader and count are unchanged.

### 3.3 Sparks

- **Drift:** sparks drift downwind with a sideways gravity of 0.6 x u m/s². Over their 1.8 s life that carries them about 0.5 x 0.6u x 1.8² ≈ u metres: 2 to 5 m in 2 to 5 m/s of wind, and 12 m at 12 m/s. That is Jamie's 2 to 5 m and 5 to 20 m.
- **Lift:** the upward gravity (+0.25) stays, so in a calm they rise as now.
- **Lean:** in a gale (over 10 m/s) the start direction leans 60 degrees downwind.

## 4. Never-see checks

1. Smoke rising straight up in a strong wind, or blowing upwind (test: the plume direction's sideways part follows the heading, and is over half the speed at 5 m/s).
2. A lit campfire with no smoke (test: `fire(true)` has a "Smoke" child with the switch).
3. Sparks rising straight up in a gale (test: sideways gravity at 15 m/s).
4. Smoke climbing forever on a still, clear night (test: the vertical stop height is about 12 m).

## 5. Pictures (Dino, with the switch on and off)

Light a large campfire at the spawn (`--give log:3`, place it, light it), or use the dev fire.

1. `smoke_calm`: a calm day, side on, 8 m off. Must show a column.
2. `smoke_wind`: forced weather `rain` (wind 0.3, about 4.2 m/s), side on, across the wind. Must show the smoke bent low, at head height by about 10 m downwind.
3. `smoke_night`: a clear night (day 100 at 23:00, live weather). Must show a column flattening at about 12 m, lit from below.
4. `sparks_gale`: forced `storm`, night. Must show sparks streaming downwind, never straight up.

Must never show: smoke upwind, or a bright grey plume glowing in the dark.

## 6. Open points

- **Pre-dawn drainage downhill** (Jamie: the flat layer drifts down the valley at 1 to 3 m/s) needs the slope at the fire. It is left for a later step.
- **Smoke that "follows you"**: not wanted. It reads as a bug in a game.
- **Wet-wood white smoke, and embers that glow for hours after the flames:** these wait on Dave's calls (Jamie's page).


## Dave 10 Nov 2026: drifting, not hovering

Dave, in a playtest: "I assume that is suppose to look like smoke but its hovering around like flies. it should be drifting away with the breeze".

**Cause.** The campfire puffs had turbulence turned on. Godot's turbulence turns each particle's velocity toward a noise direction (influence 0.1 a frame) and keeps only its speed. Within a second every puff had lost its rise and its wind and was wandering at plume speed. Over a 16 s life that scattered puffs at head height up to about 10 m round the fire, which explains the puffs by the stumps. The forge smoke had the same setting. The puff growth curve was also clamped at 1.0, its default top, so puffs only doubled in size instead of growing four times.

**Now** (every number is in `data/look/fire_smoke.json`):
- No turbulence or damping on the smoke. The sparks keep theirs, since they are short-lived and meant to waver.
- Each puff leaves the flames with the world wind (speed and heading from `set_fire_air`) and the tier's rise.
- The rise slows steadily to `rise_end_share` (0.4) of its start by the end of `life_s` (20 s): buoyancy fading with height. In a 2 m/s breeze that is 40 m of drift.
- The puffs grow `grow_to` (4) times and fade out.
- In calm air the plume goes straight up at `calm_rise_m_s` (0.8 m/s) at least.
- On a still clear night it rises at `night_rise_m_s` (1.2 m/s) and stops at about `night_top_m` (12 m) by the end of its 20 s life.
- The visibility box grew to 80 m to hold the longer drift.

`test_fire_smoke.gd` checks each of these.

## One plume, like real fire smoke (Dave, 10 Nov 2026)

Dave: "make fire smoke actually look and act more like fire smoke." The ruling asked for:

- a continuous plume, not separate puffs;
- dark and dense at the fire, thinning and lightening as it rises;
- narrow at the fire, widening upward;
- a slight waver;
- a lean with the wind that grows with height;
- more smoke from a bigger fire, thin wisps from coals.

**Now** (every number is in `data/look/fire_smoke.json`):

- **One plume.** Each fire emits 90, 130 or 190 small overlapping puffs (`amount`). Each puff is only `alpha` (0.2) of full density, so together
  they read as one column. A small fire's puffs leave about 7 cm apart and are 30 cm wide.
- **Narrow, then wide.** Puffs start at `puff_m` (0.3 to 0.5 m) and grow `grow_to` (8) times over their life.
- **Dark and dense low, light and thin high.** The shader moves each puff from `near_grey` (0.3) to `far_grey` (0.74) as it ages (`INSTANCE_CUSTOM.y`).
  `fade` sets the density over its life: thick just above the fire, thinning to nothing.
- **Leans more as it rises.** A fresh puff gets only `wind_start_share` (0.25) of the wind, since its heat lifts it. A steady sideways pull brings it
  up to the full wind by the end of its life. The plume leaves the fire steep and bends over higher up. In a 2 m/s breeze it drifts 25 m.
- **Wavers as one column.** The sway depends on height and time, so puffs at the same height move together. It grows to `waver_m` (0.6 m) by the end
  of a puff's life. This is not per-puff noise, so the "flies" do not come back.
- **Bigger fire, more smoke; coals, a wisp.** Bigger fires get more puffs that rise faster. A bed of glowing coals (state 76) gives a thin wisp
  (`coals`: 30 puffs, 0.15 m, 0.25 m/s, 0.45 density).
