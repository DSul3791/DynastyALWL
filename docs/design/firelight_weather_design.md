# Firelight in fog, rain and snow

**Owner:** Kathleen. **Status:** design, 8 Nov 2026.
**Reads:** Jamie's `docs/knowledge/firelight-in-weather.md` (#645): lessons 1 to 6, "Judged numbers for the game" and the never-see checks.

One switch, `--firelight-weather`, off until Dino's pictures. Client only.

## 1. What is wrong today (read from the code on main)

- **Fog does not touch firelight.** A torch (`held_item.gd`, `omni_range` = the item's `light_m`) and a campfire (`building_look.gd`, `FIRE_LIGHT` 3.5 / 7 / 14 m by tier when this was written; the large fire is 20 m since 13 Nov 2026, BUGLIST-001 BUG-002, so it is at least 4 times a torch) light just as far in dense valley fog as on a clear night (never-see 1).
- **No halo.** (Since 14 Nov 2026 every registered fire light also lights the volumetric fog on High and Ultra, FireWeather.FIRE_FOG_SHARE; docs/design/FOG_PLAN.md.) Both torch lights set `light_volumetric_fog_energy` to 0, and the environment has no volumetric fog anyway. So a torch through thick fog is a clean point with no glow (never-see 2).
- **Lying snow does not throw the light back.** A campfire on fresh snow lights no wider ring than on grass (never-see 4).
- **Rain is already right.** It does not shorten the reach, and open flames go out (`flame_rules.gd`). Nothing changes for rain.

## 2. The rules (`--firelight-weather`)

### The veil at the eye

`veil = mist x mist_inside`, from `weather_look.gd`: the valley fog's strength times how deep the camera is inside it. It is 0 above the layer or in clear air, and 1 deep in a dense fog. Jamie's four classes sit on it roughly as mist 0.1, fog 0.3, thick 0.6, dense 1.

### Reach (every fire light: the held torch, campfires, forges and hearth fires)

`omni_range = base x reach`, with

`reach = (1 - 0.5 x veil) x (1 - 0.2 x heavy_snow) x (1 + 0.6 x ground_snow)`, held to 0.4 to 1.8.

| Case | reach | Jamie |
|---|---|---|
| Fog (veil 0.3) | 0.85 | about -10 % |
| Thick fog (0.6) | 0.7 | about -30 % |
| Dense fog (1) | 0.5 | about -50 % |
| Heavy falling snow (`snow` from 0.5 to 1, eased) | 0.8 | about -20 % |
| Fresh lying snow (the ground's snow memory 1) | 1.6 | 1.5 to 2 times |
| Rain | 1 | unchanged |

- **Where it is kept:** each fire light keeps its base range as metadata. Nothing else writes `omni_range` after a light is made (checked on main).
- **How often:** `weather_look.gd` sets the reach once a second, on every node in the group `fire_light`.

### Halo (lessons 3 and 4)

- **What:** a soft glow around each flame. It is a camera-facing quad, a child of the fire's light, so it shows and hides with it.
  - The glow is additive and fogged like the scene, with a soft edge where it meets the ground (proximity fade).
  - Its colour is orange-white at the centre (1.0, 0.85, 0.6), orange half way out (1.0, 0.55, 0.25), and red-brown at the edge (0.8, 0.3, 0.1), fading to nothing. That is Jamie's "orange-white, reddening outward".
- **One shared mesh and material:** so one update moves every halo.
  - **Strength:** `max(veil, 0.6 x heavy_snow)`.
  - **Diameter:** `lerp(1.5, 5.0, smoothstep(0.2, 1.0, strength))` m for a torch, which is Jamie's 1 to 2 m sphere in fog and 3 to 5 m in thick fog. A campfire's halo is that times 1.2 for tier 2 and 1.5 for tier 3.
  - **Alpha:** `0.35 x smoothstep(0.1, 0.4, strength) x (1 - 0.8 x daylight)`, so it is a night look, faint by day.
- **Heavy snow:** the same glow stands in for the "sparkling sphere" of lit flakes. Lit flake particles are left for later.
- **Switch off:** no halo nodes are made and the range is never touched.

### Left for later

- Holding the torch lower in fog (a pose).
- Lit rain streaks near a sheltered flame.
- Brightness by firewood.
- The bright core as the first quarter of the range (`omni_attenuation`): the torch's falloff is Sal's torch work.
- The veil is read at the eye: a fire inside the valley fog seen from above it gets no halo. That needs a per-fire fog test and waits for a picture that shows it matters.

## 3. Never-see checks (tests in `test_firelight_weather.gd`)

1. A torch in dense fog lighting the far ground as on a clear night: reach(veil 1) = 0.5.
2. A clean point with no halo through thick fog: the halo alpha at veil 0.6 at night is above 0.3.
3. Rain making the torch's reach shorter: reach with rain only is 1.
4. A campfire on fresh snow lighting no more than on grass: reach(ground snow 1) = 1.6.
5. Over-reach: the reach never goes past 1.8, so a 9 m torch never lights more than about 16 m.

## 4. Pictures (Dino, switch on and off)

Shot format: `name:x,agl,z,yaw_deg,pitch_deg,hour[,weather]` (`src/debug/shot_runner.gd`; yaw 90 faces west). Each run uses `--shot-give=torch --cam left`, so the third-person camera shows the player holding a lit torch.

- **Fog, inside the valley layer at the spawn**, run with `--firelight-weather` and then without:

  `--shots="torch_clear:53296,2,68080,90,-5,23,clear;torch_mist:53296,2,68080,90,-5,23,mist"`

  - `torch_clear`: the torch lights the ground to about 9 m, with no halo.
  - `torch_mist`: inside the dense valley fog. The ground is lit to about half that, and a warm glowing ball 3 to 5 m across surrounds the torch.

- **Snow:** the same spot on game day 320, run with `--firelight-weather --flora-day=320 --shot-settle=90` (the ground has time to whiten), and then without:

  `--shots="torch_snow:53296,2,68080,90,-5,23,snow"`

  - The lit ring on the white ground is clearly wider than in `torch_clear`, with a faint glow round the flame in the falling snow.

- **Campfire**, if one is placed near the spawn: the same shots from 6 m off, facing it. Send me its position and I will give the exact camera.
