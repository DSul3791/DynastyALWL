# Ice walk feel: creaks and cracks by thickness, breaking skim, cold water, footing

**Owner:** Kathleen. **Status:** design, 8 Nov 2026. **Behind:** `--ice-feel` (client only, off until Dave's listen and Dino's log lines).
**Builds on:** `frozen_water_look.md` (#729, the bands and the look; code #731), `still_water_ice.md` (`Ice.cover`), `ice_sounds.gd` (job 88). **Decided (coordinator, 8 Nov):** the thaw moat refuses a walk, and frozen water needs `_on_ice`.

## 1. What there is today

- **One band.** `ice_sounds.gd` knows one number, `weather.ice_cover` (the 3 m pond cover), and one threshold, `ICE_WALK` 0.5.
  - At or above it, steps on the pond use the "ice" surface (a tap and a hollow tock).
  - A step cracks at 4, 8 or 14 % (walk, jog, run), or 35 % more on a hard landing.
  - The shore groans every 25 to 70 s.
  - Below 0.5 the ice is silent: the player wades through skim as through open water.
- **Nothing for thin ice.** There is no break sound, nothing in the water to push through, no cold shock and no change in footing. Bare ice walks like a meadow.
- **The collider has no moat.** `flora_view._draw_ice` lays one walkable sheet over every calm, flat quad of the pond out to the shore (`water_grid.ice_triangles`). In a thaw you walk over the open moat the look now draws (#731).

## 2. Bands

`c` is the local ice cover (`Ice.cover`, where 1 is 20 cm). Sounds, footing and the collider all use the same number the collider uses today (`ice_now`, the 3 m cover), so what you hear always matches what holds you.

| Band | Cover | Thickness | Bears? | Under the feet | Heard |
|---|---|---|---|---|---|
| Open | under 0.01 | none | no | wading or swimming, as today | as today |
| **Skim** | 0.01 to 0.125 | 0.2 to 2.5 cm | no | wade; each step breaks a plate | `ice_skim`: a glassy tinkle of thin plates, -14 dB |
| **Film** | 0.125 to 0.5 | 2.5 to 10 cm | no | the first step **breaks through** to the bed; each step after it is pushed through | the first step `ice_plunge`, -6 dB; then `ice_film`, a heavy crunch and slosh, -10 dB |
| **Thin sheet** | 0.5 to 0.7 | 10 to 14 cm | yes | slower, shorter steps; slides | tap, creaks often; a crack can run off as a **zing** |
| **Thick sheet** | 0.7 and up | 14 cm and up | yes | the same | tap, cracks rarely, **booms** at dawn and dusk |

The 10 cm walk threshold is today's `WALK_COVER`. The 14 cm line is judged.

## 3. Sounds

**Cracks on a sheet.** The chance per step replaces today's single row:

| Band | Walk | Jog | Run | Hard landing, added |
|---|---|---|---|---|
| Thin sheet | 8 % | 14 % | 22 % | 50 % |
| Thick sheet | 2 % | 4 % | 7 % | 20 % |

**The zing.** A crack in a thin sheet runs off as a falling chirp, heard up to 60 m.
- One crack in three in the thin band, one in eight in the thick band, also sends an `ice_zing`: a falling chirp of 0.6 to 1.2 s, from about 6 kHz down to about 400 Hz, -12 dB.
- It plays 15 to 40 m away, in the direction the player walks.
- The physics: a crack sends a bending wave through the ice. Short waves travel faster than long ones, so the high notes arrive first and the "pew" grows with distance (source 1). Close by it is only a crack, and the existing `ice_crack` already has a short falling zip in it.

**Booms on a thick sheet.** Thick ice cracks by itself as the air warms or cools, most often in the morning and evening.
- `ice_boom` is a low thud and rumble (40 to 90 Hz, 1.5 s), heard from the shore up to 200 m, -14 dB.
- Today's groan timer stays. In the thick band a groan becomes a boom one time in three between 06:00 and 10:00 and between 16:00 and 20:00, and one time in ten at other hours.
- The boom and the morning and evening peak are general knowledge, not checked today.

**Skim and film from the water.**
- Wading steps in the skim band add `ice_skim` to today's water step.
- In the film band they add `ice_film`.
- The step that first takes the player from dry ground (or a sheet) into film plays `ice_plunge` once: a crack, a low thump and a splash.
- Rain, snow and the wind keep their own sounds.

**Cold water.** On entering icy water, a sharp gasp plays once (the existing `respawn_gasp` slot sounds, `breath_gasp_N`). Nothing else is added: Dave ruled out breathing sounds on exertion (21 Oct), so there is no panting.

**New sound files.** Recipes go in `assets/audio/make_ice.py`: `ice_skim`, `ice_film`, `ice_plunge`, `ice_zing` and `ice_boom`, 3 variants each. Recordings in `assets/audio/recorded/ice/` under the same names win.
- The script needs numpy and ffmpeg, so it is run on the PC. It is not run in the cloud.
- Until the files exist, the code plays nothing for these names, as `ice_sounds.play` already does for a missing sound.

## 4. Footing and the eye on a sheet

The changes below apply only while the player stands on bearing ice (the collider) and is not swimming. Snow is `ground_snow`, the lying snow number.

| | Bare ice | Snow on ice (`ground_snow` 0.5 and up) |
|---|---|---|
| Top speed, walk / jog / run | x 1.0 / 0.9 / 0.8 | x 1.0 / 0.95 / 0.9 |
| Grip: how fast the velocity turns toward the input | 5 per s (a stop slides about 0.3 m at a walk and 1.4 m at a run) | 12 per s |
| Step length (`STEP_M`) | x 0.85: shorter, quicker steps | x 0.95 |
| Head bob and sway | x 0.6: a careful, flat walk | x 0.85 |

- **Grip.** The horizontal velocity eases toward the wanted one, `v += (want - v) x (1 - exp(-grip x dt))`. Everywhere else the game sets it at once.
- **Landing.** A hard landing on a sheet adds a small extra dip of 0.02 m through `feel.land`. In the thin band it always plays a crack.
- **Not done.** No falls or slips that take control away: a game that throws you down on ice reads as a punishment.

## 5. Breaking through and cold water

- **Skim (no collider).** The player wades as today. The wading speed is multiplied by 0.9.
  - Each wading step leaves a broken patch in the look: a `FrozenWater` hole of radius 0.4 m at the foot, kept only on the client.
  - A patch refreezes after 3 game hours when the air is below 0 °C, otherwise when the ice melts.
  - At most 8 patches are kept, nearest first, and the oldest goes first. Fishing holes from the server come first.
- **Film (no collider).** The first step plays `ice_plunge`, gives the eye a jolt of 0.06 m (`feel.hurt`-sized) and drops the player to the bed.
  - Wading through film is slower, x 0.7, because you break the ice ahead.
  - Each step leaves a 0.5 m patch.
- **Cold shock.** It starts when the player starts swimming or wades deeper than 0.8 m (swim_sounds `ENTER_M`) into icy water.
  - Water counts as icy when there is any ice on it (`c` 0.01 or more), or when the water temperature is 4 °C or under.
  - The water temperature is the same sum the server's warmth uses: `water_base_c + water_follow x (air - water_base_c)`, never under 1 °C, from `data/items/warmth.json`.
  - For 60 real seconds the swim speed is x 0.75. The gasp plays once at the start. The eye takes one jolt of 0.05 m, plus a small roll.
  - This is the first minute of the 1-10-1 rule (source 2): a gasp reflex and fast breathing for about a minute, then about ten minutes of useful movement.
  - The ten minutes and the hour are the server's warmth, which already uses the water temperature. Nothing changes there.
  - The cold shock fires again only after 5 real minutes out of the water.
- **The moat refuses a walk (coordinator, 8 Nov).** `water_grid.ice_triangles(grid, moat)` leaves out the quads with a corner within `moat` cells of a dry point. `flora_view` passes the moat from the look's thaw:
  - `moat` = 0 below thaw 0.2;
  - `moat` = 1 cell (8 m, the shore ring) from 0.2;
  - `moat` = 2 cells from 0.5.

  The collider is rebuilt when the moat changes. Steve's server `_on_ice` takes the same rule on its side.

## 6. Code

All of this is behind `--ice-feel`. With the switch off, nothing changes.

- **`src/client/ice_feel.gd` (new, pure):**
  - `band_of(cover)`;
  - `crack_chance(band, gait, hard)` and `zing_share(band)`;
  - `boom_share(band, hour)`;
  - `pace_mult(band, gait, snow)`, `grip_rate(band, snow)`, `step_scale(band, snow)` and `bob_scale(band, snow)`;
  - `wade_mult(band)`;
  - `water_c(air, cfg)`, `icy(water_c, cover)`, `moat_cells(thaw)`;
  - the cold shock timer `shock_step(state, delta, entering_icy)`.
- **`ice_sounds.gd`:** cracks by band, the zing and the boom, `skim_step(feet, band, first)` for wading steps, and `gasp()`.
- **`sound_stage.gd`:**
  - a wading step on a pond with skim or film calls `ice.skim_step`;
  - the band comes from `weather.ice_cover`, and the pond from `water.still_near()` as today.
- **`terrain_client.gd`:**
  - pace, grip, step and bob on a sheet;
  - wade x 0.9 or x 0.7;
  - the cold shock on swim entry;
  - the broken patches into `ice_holes` (#731);
  - the thaw passed to `flora_view` for the moat.
  - With `--frozen-force` (#731) and `--ice-feel` both on, the forced cover also drives `ice_now`, the collider and the sounds, for a listen at any season.
- **`water_grid.gd`:** `ice_triangles(grid, moat := 0)`. With 0 it gives exactly today's sheet.
- **`flora_view.gd`:** `set_ice_thaw(thaw)` rebuilds the colliders when the moat changes.
- **`assets/audio/make_ice.py`:** the five new recipes.
- **Test** `src/worldgen/tools/test_ice_feel.gd`: the band edges, the chance tables, footing (the stopping slide of 0.3 m at a walk and 1.4 m at a run), the water temperature against `warmth.json`, the cold shock timer and its 5-minute reset, the moat cells, and `ice_triangles` with moat 0 being the same as today and with moat 1 dropping the shore ring. It has not been run here.

## 7. For Dave's listen and Dino's log

Sound waits for Dave's listen, so there are no pictures this round apart from the moat. Each event prints a log line: `ice feel: band <name>, <event> (<sound>), pace x<n>, grip <n>`.

**The listen.** Pond near spawn (53316, 68476; stand at 53316, 68495, face north). Run four starts with `--client-arg --ice-feel --client-arg --frozen-water`, each with one force:

| Start | Force | Walk onto the pond and listen for |
|---|---|---|
| skim | `--frozen-force=0.08` | a tinkle each wading step and broken patches behind you; no tap; no collider |
| film | `--frozen-force=0.3` | one plunge and an eye jolt at the first step, a heavy crunch after it, slow wading |
| thin | `--frozen-force=0.6` | a tap, frequent cracks, now and then a far zing; a slide when you stop running |
| thick | `--frozen-force=0.9` | rare cracks; booms from the shore at 07:00 (`--hour 7`) |

Then swim in from the film start. Listen for one gasp, a jolt, about a minute of slower swimming, and no second gasp on climbing out and straight back in.

**The moat picture (Dino), ON:**
```
art/playthrough/rig.sh --name iw_moat --client-arg --ice-feel --client-arg --frozen-water --client-arg --frozen-force=0.6,0.4 \
  --at 53316,68495 --agl 2 --yaw 0 --pitch -30 --hour 12 --weather clear --walk -1 --wait 60 --settle 20
```
- **Must show:** the open moat at the shore, and the log line `ice feel: moat 1 cell`.
- **Never:** the body standing on the moat water.

## 8. Sources

1. Live Science, "Pew, Pew: Bizarre Sounds from Frozen Lake Explained" (a crack sends a dispersive bending wave; the high notes outrun the low ones with distance): https://livescience.com/48309-acoustics-of-ice-skipping-rocks.html
2. Appalachian Mountain Club, "If You Fall Through Ice, Remember the Rule of 1-10-1" (a gasp and fast breathing for about a minute, about ten minutes of useful movement, at least an hour to unconsciousness): https://oldprod.outdoors.org/?p=6358
3. Minnesota DNR, "Ice formations and conditions" (clear ice is the strongest, flowing water keeps ice thin, the shore melts first in late season): https://dnr.state.mn.us/safety/ice/ice-formations-conditions.html

The chances, decibels, footing numbers and the 14 cm line are judged, not sourced.
