# Animals and the wind's direction (MikeW, 8 Nov 2026)

From Jamie's animals-in-weather page (#639, `docs/knowledge/animals-in-weather.md`) and tracks page (#696), and Steve's server
weather rules (#651, #667). Client looks behind `wind_looks` (off). The direction is the shared weather's `wind_dir` (the way the
wind blows toward); Kathleen's prevailing wind (`docs/design/prevailing_wind.md`, a per-group direction in Weather behind `--wind-dir`)
feeds the same field when it lands, so nothing here changes then. The island is a 21 by 21 grid of rows with the equator in the middle, so the client assumes no
direction of its own: with no `wind_dir` (only the motion tool, which passes one) there is no wind turn at all.

## What animals do (knowledge)
- **Rump to the wind in wind and rain.** Stock and deer standing out strong wind with rain turn their backs to it, head down (the
  coat sheds the rain from the back; the face is spared). Cattle drift with a storm; Steve's server already turns stock downwind in a
  gale and drifts them.
- **Grazing into the wind.** Red deer graze moving into a light or moderate wind, so the scent of what is ahead comes to them;
  Steve's `_upwind_angle` sends them that way on the server. In a gale they stop and shelter. (Not downwind: the knowledge page is
  clear that deer face into it; the downwind stand is for strong wind with rain and gales.)
- **To the lee.** Herds drift to the lee of a wood or a slope in bad weather; that is where the server puts them (rain cover, #667),
  not a client look.
- **Fur on the windward side** lifts and parts; the lee side lies flat.
- **Breath and scent downwind.** A visible breath drifts downwind; scent does the same, which is why a hunter must come from
  downwind. The server's senses already carry this (`_sense_factor`: a player upwind of an animal is smelled from farther off, scaled
  by `scent_gain` x wind); the client only shows the breath.
- **Birds take off and land into the wind**, for lift at low speed.

## In the game (flag `wind_looks`)
| Look | Who | When | How |
|---|---|---|---|
| Rump to the wind, head down | the stock and deer kinds (TAIL_TO_WIND) | standing, wind 0.45 with rain or snow 0.3, or any gale (0.6) | `_wind_look`: the Rig turns up to 60 degrees toward downwind, eased; with rain the hunch pose (head low) |
| Grazing into the wind | deer, elk, moose | grazing, wind 0.15 to 0.6 | the Rig turns up to 45 degrees toward upwind |
| Fur on the windward side | rows with `ruffle_cm` (coat_ruffle on) | wind | the ruffle shader's `wind_dir` follows the real wind and the windward side moves most (`windward_share` 0.6) |
| Breath downwind | steam breath (weather_looks on) | below 5 C | the puff drifts downwind at 1.5 x wind m/s |
| Birds into the wind | flight rows | the take-off and landing clips | `_into_wind`: the Rig turns up to 90 degrees toward upwind while the clip plays |
With `wind_looks` on, the gale turn of `weather_looks` steps aside (the same turn, now with the rain rule and the deer's graze).

## For Steve (no new wire fields)
- The scent rule is his already; nothing is asked. If he wants herds to drift to the lee of a slope as well as a wood, that is a
  cover-search candidate on the server (the lowest of his eight samples already does it for deer in a gale).

## Check
Run sheet m51 (deer and horse standing in wind 0.5 with rain 0.6 blowing toward +X: rumps toward +X, heads low) and DINO_SHOTS.md.
