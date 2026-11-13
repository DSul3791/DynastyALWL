# BUGLIST-001 environment-presentation: BUG-002 (campfire light) and BUG-004 (rain/puddle audio)

Baseline SHA f5d6b54 (origin/dev). Branch `claude/buglist001-envpres`. Nothing here was run in Godot: every new test is NOT RUN and every visual or audio change is **not visually / aurally checked**. No protocol, save-format or item-catalog change.

## BUG-002 Large campfire lights less than a handheld torch

**Reproduction (by reading code, numbers from `/tmp` Python model, not a Godot run).**
Godot's omni light at distance d is `energy x (1 - (d/range)^4)^2 / d^attenuation` (scene shader `get_omni_attenuation`).
- Held torch: `held_item.gd` `_make_torch_model`: energy 2.0 (flicker +-0.4), range `light_m` 12 (items.json torch), attenuation left at Godot's default 1.0, plus a 0.7 / 1.6 m hand light.
- Large fire (tier 3, bonfire): `building_look.gd` `FIRE_LIGHT[3]` = 14 m, energy 4, attenuation 2 (`LIGHT_FALLOFF`).
- Intensity at 1 / 2 / 5 / 8 m: torch 2.0 / 1.0 / 0.38 / 0.16; old large fire 4.0 / 1.0 / 0.15 / 0.05. Beyond about 2 m the "large" fire was dimmer than the torch (an inverse-square falloff against the torch's gentler one), and its emitted flux was 0.5x the torch. That is Dave's observation.

**Root cause (evidence).** The tier table was sized by Dave's 1 Nov "each step twice the radius and brightness" rule with the shared attenuation 2, and the torch got range 12 and attenuation 1. Nobody compared the large fire with the torch in one unit. `data/items/cooking.json` `fire_tiers.log` carried the same 14 / 4; the server does not read them (`server_items.gd` only reads `heat_radius_m`).

**Equivalent-units comparison (defensible, in the test too).** Both are shadowless `OmniLight3D`, so the ratio of any integral of the curve is independent of Godot's global light scale. Torch counted at its mean energy 2.0 plus its hand light (its best case). Three measures, all required >= 4x by `test_fire_light_vs_torch.gd`:
1. Source intensity (energy at 1 m): large fire 16 / torch 2.0 = **8.0x**.
2. Emitted flux, the integral of intensity over spheres round the light out to its range: **about 7.6x** (old fire 0.52x).
3. Light delivered to flat ground under the light (intensity x cos incidence integrated over the ground, what lights terrain, trees and bushes): **about 4.4x** (torch at 1.3 m, fire at 0.8 m). Against the torch's flicker peak 2.4 it is about 3.7x, which is why this one sets the energy and why it is a mean-to-mean comparison.
The product "energy x range" is not an equivalent unit across different attenuation exponents, so it is not used (it would have given 2.3x for the old fire while it was visibly dimmer).

**Change.**
- `building_look.gd` `FIRE_LIGHT[3]` = range 20 m, energy 16, attenuation 1.5 (new third field, tiers 1 and 2 keep 3.5 m / 1 / 2.0 and 7 m / 2 / 2.0). Reach 20 m is 1.67x the torch's 12 m (not a 4x radius). From 1 m out the large fire is brighter than the torch at every distance both reach (model, fire vs torch: 1 m 16 vs 2.0; 2 m 5.6 vs 1.0; 5 m 1.4 vs 0.38; 10 m 0.44 vs 0.05). It reaches exactly 0 at 20 m (darkness beyond) and falls naturally (window x power law).
- No shadows (`shadow_enabled = false`, unchanged): a shadow-casting omni is 6 shadow passes, too dear for three fire lights on a GTX 1050. The number of lit-fire lights is unchanged (`MAX_FIRE_LIGHTS` 3). Range 14 to 20 m adds cluster/overdraw cost only for a log fire; unmeasured (no frame-rate check possible in the cloud).
- Flame-coupled warm flicker: `BuildingLook.flame_flicker` / `flame_flicker_color`. The light now follows the same two beating sines the flame cards use (9 and 11.3 Hz in `FLAME_SHADER`) plus a slow settle, mean 1, +-15% at most (it was +-6%, slow), and its green channel follows the swing (brighter = a shade yellower, dimmer = redder). Per-light phase is the instance id, not the rank (rank changed as the nearest-three order changed). Applied to lit fires only (meta `flame_flicker`); lanterns, coals and fixtures keep the gentle flicker. `inventory_view.gd`: the nearest-three ranking still runs every 200 ms (`_update_fire_lights`), but the flame flicker runs every frame (`_flicker_flames`) because a 9 to 11 Hz beat sampled every 200 ms would alias into steps (found in self-review).
- Torch constants moved to `FlameRules.TORCH_LIGHT_*` / `TORCH_HAND_*` (same values) so the test and the torch cannot drift; the torch's attenuation is now set explicitly to 1.0 (Godot's default, no behaviour change).
- `cooking.json` `fire_tiers.log` light_m 20 / light_energy 16 and its note; `test_fire_fuel_tiers.gd` no longer demands the large light double the medium (it requires at least double); `CONTROLS.md`, `PLAYTHROUGH_GUIDE.md` text 3.5 / 7 / 20 m.
- Global ambient untouched (`look_settings.gd`). Smoke, sparks, flames untouched (TEST-011 not regressed: no change to `_campfire_smoke`, `_tall_smoke_plume`, `fire_smoke_wind`).

**Tests added (NOT RUN).** `src/worldgen/tools/test_fire_light_vs_torch.gd`: old fire < 1x torch (the bug); large fire >= 4x by source, flux and ground; reach larger but < 4x radius; brighter at every shared distance; zero at range; tiers 1 and 2 unchanged and tiers step up; built node carries FIRE_LIGHT and no shadows; flicker mean 1, within 15%, moving, phases differ; warm colour shift. Adjusted `test_fire_fuel_tiers.gd`.

**Regression risks.** (1) Near-field blow-out: intensity 16 at 1 m with a (1,0.54,0.2) light will clip toward yellow-white within about 2 m of a log fire; one constant (`FIRE_LIGHT[3][1]`) tunes it and the test floor (4x) bounds how far down. (2) Fire inside buildings / forges are other builders and are unchanged. (3) FireWeather reach scaling up to 1.8x now gives 36 m on fresh snow for a log fire. (4) The medium (campfire) fire, 7 m / energy 2 / attenuation 2, is still dimmer than a torch beyond about 2 m; Dave's rule names only the large fire, so it is left, see questions.

**Status: NEEDS PLAYER VERIFICATION.**
**F6 check:** at night, put a torch in hand and stand 6 m from a log fire (3+ logs) and from the torch alone side by side in view of grass, bushes and a tree: the fire should light the ground, bushes and trunks clearly further out and brighter than the torch, with orange light that pulses with the flames and fades to black past roughly 15 to 20 m; ambient and sky should look no brighter. Check frame rate with three log fires in view.

## BUG-004 Puddle / rain audio before visible rain

**Reproduction.** Not reproduced (no Godot). Traced by reading: world rain (`Weather.state` `rain`, a smoothstep from 0 when a front passes) reaches the sound by `terrain_client.gd:2507` `weather.apply_state` once a second and the sky by `weather_look._target()` from the same dictionary, so there is no forecast/approach value in either path; the two differ in thresholds and in what they add.

**Root cause (evidence, then guesses).**
Evidence:
1. `weather_sounds.gd` `apply_state` started a "drizzle" (and every rain layer) at rain > 0.08. At that level the sky shows almost nothing: `weather_look` overcast `wet_sky = smoothstep(0.02, 0.2, rain)` is about 0.18 (cloud about 0.1), streak count is `amount_ratio = clamp(rain, 0.05, 1)` of faint (alpha 0.10) streaks. Audio therefore started on a clear-looking sky.
2. The rain layer mix had no leaf stage: from the first drop the open-ground bed, the ground bed and the single drops (`rain_splashes.gd`) used the full soil/stone sounds.
3. The puddly sounds were not tied to standing water. `sound_stage.rain_ground` / `splash_ground` called soaked loose soil and mud soil "mud" from `weather.ground_wet` (the sound stage's own real-seconds soak/dry model, soaks from rain >= 0.25, dries in 240 s) with no reference to the pools the ground actually draws (`puddles.gd`, game-hour model). The `rain_mud` loop and the "plop in mud" one-shots are the puddle-like impacts.
Guess (not provable without a run): the reported impacts were the rain_mud bed and mud plops (and water plips) at the first drops, on soil still counted wet from the sound stage's own memory or on mud soil, while the visible sky and puddles had not caught up.

**Change.**
- New pure rules `src/shared/rain_audio.gd` (`RainAudio`): `AUDIBLE_FROM` 0.15 (world rain, replacing 0.08, also above the visual's first faint streaks at 0.04), `onset` (eased level fades in over 0.03 to 0.10, so the natural approach/fade stays), `leaf_share` (all leaf ticks at the first drops, none by 0.5), `layers()` (the loop mix, moved out of `weather_sounds.update`, Decision 61), `drop_surface()` (pond water answers the first drops, leaf tick, else the ground; "mud" only with standing water, otherwise "dirt").
- `weather_sounds.gd`: uses `RainAudio.layers`; apply_state threshold; eases a `_standing` value.
- `sound_stage.gd` `standing_water(body)` and `puddles.gd` `water_under` (foot_in now uses it): water drawn under the feet, 0..1; headless fallback without puddles keeps the old "soaked ground" meaning.
- `rain_splashes.gd`: surfaces from `RainAudio.drop_surface`.
- Existing puddles respond to the first actual drops (the plop needs only water at the feet, no rain-amount other than >= 0.15 world rain); no new fluid simulation, no change to puddle levels.

**Test added (NOT RUN).** `src/worldgen/tools/test_rain_audio.gd`: a dry -> rain -> dry run (0 to 0.8 and back over 280 s) through `apply_state`, the eased sound level and `RainAudio.layers`, against the visual's eased rain (`WeatherLook.EASE_S`, emission > 0.04): no layer while the streaks are not showing, none in the dry spells, sound starts after the rain is first seen and ends before the streaks are gone, mud bed never without standing water; leaves before stone, then stone; onset and fade-in; every drop surface rule.

**Regression risks.** Light rain between state 0.08 and 0.15 is now silent (it was quiet); light rain loops start 0.07 lower on the eased level; rain on mud soil with no pool now sounds as dirt/soft until a puddle forms (puddle layer 3 fills at drizzle). The splash drop rate gate (`RAIN_FROM` 0.12 on the eased level) is unchanged. Rain heard in the open at the start now includes a leaf-patter layer (`LEAF_OPEN` 0.6 of the leaf loop); the `rain_leaves` loop clip must read acceptably in the open (aural check).

**Status: NEEDS PLAYER VERIFICATION.**
**F6 check:** let a front arrive on a clear day (the world clock decides; `--weather=` only overrides the sound), in the open: no rain or plop sound until the first streaks and a clouding sky show; the first sound is a soft leaf/branch tick, soil/stone patter builds as the rain strengthens, plops only if you stand at a drawn puddle or by a pond; as it stops the sound ends before the streaks and puddles remain silent in dry air.

## Questions for Dave (answered by recorded decision, nothing blocking)
1. The medium campfire is still dimmer than a torch at range (the rule names the large fire). Recorded decision: not changed; recommend the same treatment as a follow-up if it shows in play.
2. Attenuation 1.5 for the large fire instead of the shared 2.0: needed to reach 4x without a blinding near field; recorded, tunable in `FIRE_LIGHT`.

## Self-review (ponytail-review, head before commit)
Found and fixed: flame flicker sampled at the 200 ms fire-light pass (aliasing) moved to a per-frame pass over at most MAX_FIRE_LIGHTS cached lights. Unmeasured risk: per-frame cost of up to 3 light writes (negligible), 20 m log-fire light range (GPU, needs a PC frame-rate check). Not checked: all tests NOT RUN, visuals and audio not checked.
