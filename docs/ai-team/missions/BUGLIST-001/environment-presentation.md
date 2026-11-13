# BUGLIST-001 environment-presentation: BUG-002 (campfire light) and BUG-004 (rain/puddle audio)

Baseline SHA f5d6b54 (origin/dev). Branch `claude/buglist001-envpres`. Nothing here was run in Godot: every new test is NOT RUN and every visual or audio change is **not visually / aurally checked**. No protocol, save-format or item-catalog change.

## BUG-002 Large campfire lights less than a handheld torch

**Reproduction (by reading code, numbers from `/tmp` Python model, not a Godot run).**
Godot's omni light at distance d is `energy x (1 - (d/range)^4)^2 / d^attenuation` (scene shader `get_omni_attenuation`).
- Held torch: `held_item.gd` `_make_torch_model`: energy 2.0 (flicker +-0.4), range `light_m` 12 (items.json torch), attenuation left at Godot's default 1.0, plus a 0.7 / 1.6 m hand light.
- Large fire (tier 3, bonfire): `building_look.gd` `FIRE_LIGHT[3]` = 14 m, energy 4, attenuation 2 (`LIGHT_FALLOFF`).
- Intensity at 1 / 2 / 5 / 8 m: torch 2.0 / 1.0 / 0.38 / 0.16; old large fire 4.0 / 1.0 / 0.15 / 0.05. Beyond about 2 m the "large" fire was dimmer than the torch (an inverse-square falloff against the torch's gentler one), and its emitted flux was 0.5x the torch. That is Dave's observation.

**Root cause (evidence).** The tier table was sized by Dave's 1 Nov "each step twice the radius and brightness" rule with the shared attenuation 2, and the torch got range 12 and attenuation 1. Nobody compared the large fire with the torch in one unit. `data/items/cooking.json` `fire_tiers.log` carried the same 14 / 4; the server does not read them (`server_items.gd` only reads `heat_radius_m`).

**Equivalent-units comparison (defensible, in the test too).** Both are shadowless `OmniLight3D`, so the ratio of any integral of the curve is independent of Godot's global light scale. The torch is counted with its hand light, once at its mean energy 2.0 and once at its flicker peak 2.4 (its best case); the torch range is read from `items.json`. Three measures, all required >= 4x at both torch energies by `test_fire_light_vs_torch.gd` (large fire energy 18, range 20, attenuation 1.5):

| Measure | vs torch mean 2.0 | vs torch peak 2.4 |
|---|---|---|
| Source intensity (energy at 1 m) | 9.0x | 7.5x |
| Emitted flux (intensity integrated over spheres to the range) | 8.5x | 7.1x |
| Light delivered to flat ground under the light (intensity x cos incidence over the ground; torch at 1.3 m, fire at 0.8 m) | 4.9x | 4.1x |

The old fire was 0.52x by flux. The ground measure depends on the lights' heights and is the binding one; the energy rose from a first 16 (3.7x against the torch peak) to 18 so it holds at the peak as well. The product "energy x range" is not an equivalent unit across different attenuation exponents, so it is not used (it would have given 2.3x for the old fire while it was visibly dimmer).

**Change.**
- `building_look.gd` `FIRE_LIGHT[3]` = range 20 m, energy 18, attenuation 1.5 (new third field, tiers 1 and 2 keep 3.5 m / 1 / 2.0 and 7 m / 2 / 2.0). Reach 20 m is 1.67x the torch's 12 m (not a 4x radius). From 1 m out the large fire is brighter than the torch at every distance both reach (model, fire vs torch: 1 m 18 vs 2.0; 2 m 6.4 vs 1.0; 5 m 1.6 vs 0.38; 10 m 0.50 vs 0.05). It reaches exactly 0 at 20 m (darkness beyond) and falls naturally (window x power law).
- No shadows (`shadow_enabled = false`, unchanged): a shadow-casting omni is 6 shadow passes, too dear for three fire lights on a GTX 1050. The number of lit-fire lights is unchanged (`MAX_FIRE_LIGHTS` 3). Range 14 to 20 m adds cluster/overdraw cost only for a log fire; unmeasured (no frame-rate check possible in the cloud).
- Flame-coupled warm flicker, **large fire only** (meta `flame_flicker`, set in `BuildingLook.fire` for tier 3): `BuildingLook.flame_flicker` / `flame_flicker_color`. The light follows the same two beating sines the flame cards use (9 and 11.3 Hz in `FLAME_SHADER`) plus a slow settle, mean 1, +-15% at most, and its green channel follows the swing (brighter = a shade yellower, dimmer = redder). Per-light phase is the instance id, not the rank. Tiers 1 and 2, lanterns, coals and fixtures keep the gentle +-6% flicker and its "Dave 31 Oct" comment as they were. `inventory_view.gd`: the nearest-three ranking still runs every 200 ms (`_update_fire_lights`), but the flame flicker runs every frame (`_flicker_flames`) because a 9 to 11 Hz beat sampled every 200 ms would alias into steps (found in self-review).
- Torch constants moved to `FlameRules.TORCH_LIGHT_*` / `TORCH_HAND_*` (same values) so the test and the torch cannot drift; the torch's attenuation is now set explicitly to 1.0 (Godot's default, no behaviour change).
- `cooking.json` `fire_tiers.log` light_m 20 / light_energy 18 and its note; `test_fire_fuel_tiers.gd` no longer demands the large light double the medium (it requires at least double); `CONTROLS.md`, `PLAYTHROUGH_GUIDE.md` text 3.5 / 7 / 20 m.
- Global ambient untouched (`look_settings.gd`). Smoke, sparks, flames untouched (TEST-011 not regressed: no change to `_campfire_smoke`, `_tall_smoke_plume`, `fire_smoke_wind`).

**Tests added or changed (NOT RUN).**
- New `src/worldgen/tools/test_fire_light_vs_torch.gd`: old fire < 1x torch (the bug); large fire >= 4x by source, flux and ground at the torch's mean and its peak; `cooking.json` `fire_tiers.log` light_m / light_energy equal `FIRE_LIGHT[3]`; reach larger but < 4x radius; brighter at every shared distance; zero at range; tiers 1 and 2 unchanged and tiers step up; built node carries FIRE_LIGHT and no shadows; flame flicker meta on tier 3 only; flicker mean 1, within 15%, moving, phases differ; warm colour shift.
- Changed (disclosed, TEST_GATES: no silent relaxing) `test_lit_fixture.gd` campfire loop: it asserted `range <= 3.5 x 2^(tier-1) + 0.1` and `attenuation >= 2.0` for every tier, which the large fire (20 m, 1.5) deliberately breaks. It now requires each tier's exact `BuildingLook.FIRE_LIGHT` range and attenuation plus `base_energy`, and keeps the old bounds for tiers 1 and 2.
- Changed `test_fire_fuel_tiers.gd`: medium is exactly twice small for every light/heat/protect key; the large fire's light_m and light_energy must be at least twice medium (they are 20 and 18 against 7 and 2); heat and protect still double exactly.

**Regression risks.** (1) Near-field blow-out: intensity 18 at 1 m with a (1,0.54,0.2) light will clip toward yellow-white within about 2 m of a log fire; one constant (`FIRE_LIGHT[3][1]`) tunes it and the test floor (4x) bounds how far down. (2) Fire inside buildings / forges are other builders and are unchanged. (3) FireWeather reach scaling up to 1.8x now gives 36 m on fresh snow for a log fire. (4) The medium (campfire) fire, 7 m / energy 2 / attenuation 2, is still dimmer than a torch beyond about 2 m; Dave's rule names only the large fire, so it is left, see questions.

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
- New pure rules `src/shared/rain_audio.gd` (`RainAudio`): `AUDIBLE_FROM` 0.15 for the rain layers and single drops (world rain; they started at 0.08), `onset` (eased level fades in over 0.03 to 0.10, so the natural approach/fade stays), `leaf_share` (all leaf ticks at the first drops, none by 0.5), `layers()` (the loop mix, moved out of `weather_sounds.update`, Decision 61), `drop_surface()` (pond water answers the first drops, leaf tick, else the ground), `is_mud()`.
- The weather **kind** is as it was: world rain above 0.08 is still a drizzle, so birds, insects and frogs stop for any rain (3 Nov rule, `test_slot_sounds.gd` `calls_for`). Only the rain loops and drops are held: `WeatherSounds.rain_audible` (set from the world rain in `apply_state`, true for a kind set by hand) gates a second eased level `rain_heard`, which `RainAudio.layers` and `rain_splashes.gd` read. The manual `test_splash` block in `terrain_client.gd` sets it too.
- Mud: true mud soil is still mud whether wet or dry (no change across hollows). Only the soaked-loose-dirt/leaves case that used to become "mud" from the sound stage's own `ground_wet` now needs a puddle drawn at the feet: `SoundStage._rain_mud` (used by `rain_ground` and `splash_ground`) reads `Puddles.water_under` only when the ground is dirt/leaves and soaked and a puddle is shown (`puddles.shown`), then `RainAudio.is_mud`. Without puddles (headless) soaked ground counts as standing water as before.
- `puddles.gd` `water_under` (foot_in now uses it) and `weather_look.gd` `wet_sky_share` (the overcast formula, now a function so the test reads the real one).
- Existing puddles respond to the first actual drops; no new fluid simulation, no change to puddle levels.

**Test added (NOT RUN).** `src/worldgen/tools/test_rain_audio.gd`. Which checks guard BUG-004: (a) the dry -> 0.8 -> dry run through `apply_state`, the eased `rain_heard` and `RainAudio.layers`, with `heard_under_clear_sky`: no layer may sound while `WeatherLook.wet_sky_share` of the visual rain is under 0.7 (a 0.08 start fails this: its sky share is 0.26); (b) the kind stays a drizzle at 0.10 with the birds silent while the layers are held; (c) leaves before stone, then stone, fade-in and no layer under the onset; (d) every drop-surface and `is_mud` rule. The "no layer while streaks are not showing" and "heard after seen / stops before the streaks end" checks are ordering sanity checks (streaks emit from 0.04, so they alone would pass the old threshold) and are labelled so.

**Regression risks.** World rain between 0.08 and 0.15 is now a drizzle for the birds but silent for the rain loops and drops (it was quiet); soaked loose dirt/leaves without a drawn puddle sounds as dirt/soft instead of mud. The splash drop rate gate (`RAIN_FROM` 0.12 on the eased level) is unchanged. Rain heard in the open at the start now includes a leaf-patter layer (`LEAF_OPEN` 0.6 of the leaf loop); the `rain_leaves` loop clip must read acceptably in the open (aural check).

**Status: NEEDS PLAYER VERIFICATION.**
**F6 check:** let a front arrive on a clear day (the world clock decides; `--weather=` only overrides the sound), in the open: no rain or plop sound until the first streaks and a clouding sky show; the first sound is a soft leaf/branch tick, soil/stone patter builds as the rain strengthens, mud plops on soaked ground only at a drawn puddle, water plips only at a pond; as it stops the sound ends before the streaks and puddles remain silent in dry air.

## Questions for Dave (answered by recorded decision, nothing blocking)
1. The medium campfire is still dimmer than a torch at range (the rule names the large fire). Recorded decision: not changed; recommend the same treatment as a follow-up if it shows in play.
2. Energy 18 (first 16): needed so the ground measure is 4x against the torch's flicker peak too; one constant, near-field clipping is the cost.
3. Attenuation 1.5 for the large fire instead of the shared 2.0: needed to reach 4x without a blinding near field; recorded, tunable in `FIRE_LIGHT`.

## Self-review (ponytail-review, head before commit)
Found and fixed: flame flicker sampled at the 200 ms fire-light pass (aliasing) moved to a per-frame pass over at most MAX_FIRE_LIGHTS cached lights. Unmeasured risk: per-frame cost of up to 3 light writes (negligible), 20 m log-fire light range (GPU, needs a PC frame-rate check). Not checked: all tests NOT RUN, visuals and audio not checked.

## Gate review round (25138e2 FAIL, items fixed)
Fixed: `test_lit_fixture` per-tier values (disclosed above); flicker tier 3 only; cooking.json equals FIRE_LIGHT[3] test; test_rain_audio guards the sky not the streak threshold; mud gate only for soaked dirt/leaves; energy 18 with torch peak comparison and torch range read from items.json; `firelight_weather_design.md` line updated; puddle shown check before the puddle read; weather kind and bird rule restored with the 0.15 gate on layers and drops only.

## Test evidence (PC run, 13 Nov 2026)

Every GDScript test marked "NOT RUN" above has now run (below); picture lanes and visual or sound checks have still not run. Ran on the David4 test PC (Linux, Godot 4.7.2 voxel build, headless, 2 jobs, fresh import) on `claude/buglist001-integration` at 8e46c4b254ed8061938cecee06a2cbb8665393c9 (dev f5d6b54 + all seven BUGLIST-001 heads). Result: 370 pass, 0 fail, no retries (fast 361/361, timing 8/8, slow 1/1 test_worldgen). validate_items PASS (0 errors), check_look_names PASS, warnings: none new over tools/warning_baseline.txt. Startup smoke: welcome 15.7 s, ground ready 133 s, 0 script errors, exit 134 (known headless exit). Picture lanes (5): NOT RUN; visuals and sound not checked. Logs: David4 /work/lanerun/bl001b_plan, /work/lanerun/bl001b_extra. An earlier run on a0b5365 failed 2 tests (test_hammer_list counts, test_server_items road restart height) plus 3 warnings; those were test-only fixes, reviewed, and are in 8e46c4b. Merged to dev by PRs #1068-#1074; dev add271196 has the identical tree (c6ec74eb). Status stays NEEDS PLAYER VERIFICATION until Dave's F6 check.
