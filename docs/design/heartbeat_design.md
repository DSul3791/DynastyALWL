# Heartbeat: the Daggorath pulse and the pulse bar (design, Steve, 10 Nov 2026)

Dave, 9 Nov 2026, 20:22 local: "I want this to become my heartbeat. there should be a little pulse light bar on top of the hotkeys just like a little line of green light that starts in the middle and pulses out both sided a little ways with each heart beat and then slowly comes back in between beats. when your at rest your heart should beat around 55 beats per minute. ... you can always hear it. when it gets into the exercise range it turns yellow and when it gets into the danger zone it should turn orange and red. as it gets faster it gets louder. very proportional."

The sound is `assets/audio/heartbeat/Daggorath_Style_Heartbeat_Pulse.wav`: one electronic pulse, 0.12 s, 44.1 kHz mono. It is played whole on each beat, never generated.

## What exists, and what it keeps

The heartbeat already has one controller, `src/client/breath_sounds.gd` (`sound.breath`). It is the only one, and it stays the only one. It plays on the "Body" bus, which the Effects slider sets and which stays up in a faint.

The rate already comes from the authoritative systems:
- **Awake.** The server's strain (`items.strain`, data/items/exertion.json: over-exerted at 1.0, faint at 1.4), fed by `set_body` each frame.
- **Asleep, fainted or waking.** The server's own heart rate (protocol 59, `body(bpm, eta, phase)`: 44 asleep, 172 in a faint, 140 waking).

The heart rate is eased toward its target at 40 bpm per second, so it never jumps. The character screen's heart reads the same `bpm_now`.

This change only touches the controller. Nothing new decides the heart rate.

## Changes to the controller

- **Always heard.** Before this change the heart was silent below strain 0.55 and under water. Now it beats all the time: 55 bpm at rest, through to the existing faint behaviour. In a faint, the heart fades out over 3 s once the vision is gone, unless the server holds a rate. Under water, the heart is still heard, because it is inside the head.
- **Rate.** A straight line of strain: 55 bpm at strain 0, 175 at the faint threshold (1.4) and 200 at the most over-exerted (2.0). The server's rate wins while it sends one.
  - Walking holds strain at 0, so walking is 55.
  - The over-exerted line (1.0) falls at about 141 bpm.
- **Sound.** The pulse is the Daggorath WAV, with the pitch fixed at 1.0 and no random pitch or volume. Only the time between pulses changes: `interval = 60 / bpm`.
- **Volume.** Volume is proportional to the rate: `rest_db` (-30 dB) at 55 bpm up to `peak_db` (-8 dB) at 200 bpm, in a straight line. The heart is quiet at rest but always there.
- **No wasted playback.** When the Body or Master bus is muted or turned right down, the beat still counts (the bar still pulses), but nothing is played.
- **One signal.** `beat(bpm)` is emitted on each pulse. The pulse bar listens to it, and nothing polls.
- **Retired.**
  - The three generated `heartbeat_N.ogg` lub-dubs move to proposed_removals.
  - `make_body.py` no longer makes them.
  - The old "heartbeat" pack slot goes from the sound manifest.

## The pulse bar (`src/client/heart_pulse.gd`)

- **Where.** A thin line of light just above the hotbar tray, centred on the hotbar (canvas 960, 940, on the 1920 × 1080 HUD). It stays above the inventory window's backdrop with the hotbar.
- **Shape.**
  - On each beat the line shoots out from the centre to both sides, `max_half_px` (80 px) each way, in `rise_s` (0.09 s, or a quarter of the interval when the heart is very fast).
  - It then eases back in, slowly, over the rest of the interval, to `min_half_px` (3 px).
  - So a slow heart breathes and a fast one flickers. It has a soft glow line under a bright core.
- **Colour.** The colour follows the rate, in four zones:

  | Zone | Colour | Rate | Strain |
  |---|---|---|---|
  | Rest and easy work | green | below 100 bpm | under about 0.5 (`rest_effort`, 0.52) |
  | Exercise | yellow | 100 to 140 bpm | |
  | Danger | orange | 140 to 160 bpm | from about over-exerted (1.0) |
  | Near a faint | red | from 160 bpm | |

- **Settings.** The thresholds and colours are configurable.
- **No heart.** When the heart is gone (the end of a faint), the line fades out, and it comes back with the first beat.
- **Cost.** One tiny Control with a few draw_line calls a frame. Nothing is allocated per frame.

## Passing out (Dave 10 Nov 2026, `src/client/hud_fade.gd`)

Dave: "when I over exert myself and I pass out I want the entire hud except the heart beat indicator to fade out. the only reminder you have that you are alive is the heart beat". The hotbar fades too.

- **What fades.** Every direct child of the HUD layer fades through its modulate alpha: the hotbar, the vitals, the compass, the status icons, notices and any open panel. That includes anything that appears during the faint.
- **What stays.** The pulse line and the black picture itself stay. The line keeps its colours, so in a faint it is red at the faint rate.
- **When.** The HUD follows the server's faint blackout (`strain_fade` in states 1, 2 and 3):
  - It is fully gone when the black reaches `faint_hud.gone_at_black` (0.5), which is before the screen is fully black.
  - It comes back as the black lifts on waking.
  - It never moves faster than `faint_hud.fade_s` (0.8 s) for the whole way.
- **Sleep.** Sleep blacks out the same picture, but the HUD stays: Dave asked for the faint only.
- **Rule for HUD nodes.** A node placed straight on the HUD layer fades its own look with `self_modulate`, never `modulate`, so the two do not fight. inventory_view's auto-pickup and comfort labels were changed to follow this.
- **Cost.** Nothing while awake. During a faint it is one alpha write per HUD node per frame.

## Settings: data/sound/heartbeat.json

These are all settings, not flags:
- `rest_bpm`, `faint_bpm`, `peak_bpm`, `ease_bpm_per_s`
- `rest_db`, `peak_db`
- the bar's `centre`, `min_half_px`, `max_half_px`, `rise_s`, `thickness_px`
- `zones`, as [from_bpm, colour]
- `faint_hud.gone_at_black`, `faint_hud.fade_s`

## Tests (src/worldgen/tools/test_heartbeat.gd)

- 55 bpm at rest, and heard: beats come at rest and under water.
- The rate climbs smoothly with strain and returns slowly.
- The interval equals 60 / bpm, and the pitch is always 1.0.
- The volume rises with the rate, with the rest level well under the peak.
- The zone colours at 55, 120, 150 and 170 bpm.
- The bar's spread: full shortly after a beat and back in by the next.
- A muted bus plays nothing but still emits the beat.
- Passing out: the hotbar and the rest of the HUD fade with the blackout, are gone at gone_at_black, and come back on waking; the line and the black stay; sleep keeps the HUD.
