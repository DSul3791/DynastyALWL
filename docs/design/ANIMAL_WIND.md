# Animals and the wind's direction (MikeW, 8 Nov 2026)

From Jamie's animals-in-weather page (#639, `docs/knowledge/animals-in-weather.md`) and tracks page (#696), and Steve's server
weather rules (#651, #667). Client looks behind `wind_looks` (off). The direction is the shared weather's `wind_dir` (the way the
wind blows toward); Kathleen's prevailing wind (`docs/design/prevailing_wind.md`, a per-group direction in Weather behind `--wind-dir`)
feeds the same field when it lands, so nothing here changes then. Without a direction from the world, the island's prevailing wind (below). Seasons are the game calendar's (the island is at 57 degrees south): the windy season is the local winter, when
the rump-to-the-wind stand and the gale turns will be seen most.

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

## The prevailing wind at 57 S (Jamie's #714, `docs/knowledge/prevailing-wind-57s.md`)
- The wind comes mostly **from the west and north-west**, mean about 300 to 320 degrees, within 45 degrees of WNW 55 to 65 percent of
  the time; a direction holds 1 to 3 days, then a front turns it (veering W to NW to N ahead of a low, backing sharply to SW as the
  cold front passes). The windy season is the local winter.
- **The client reads only `terrain_client.weather`'s `wind_dir`** (the shared weather; Kathleen's prevailing wind, which follows
  this page, will feed that same field). With none (the motion tool without a direction), `PREVAILING_TO` 0.70 rad: blowing toward
  about 130 degrees, the south-east (from 310 degrees).
- Applied to the looks (flag `wind_looks`, off):
  - **Fur and feather ruffle** follow the real direction; the birds now have `ruffle_cm` too (crow 0.3, pheasant 0.4, goose 0.3,
    duck 0.25, guineafowl 0.3, chicken 0.4; the Meshy eagle 0.5, raven 0.4, owl 0.6), so feathers lift on the windward side with
    `coat_ruffle` on.
  - **Birds take off and land into the wind** (as above).
  - **Herds stand tail to the wind in rain** (as above), and **face into it when alert** (state 3, stock and deer, wind 0.15 or more:
    up to 45 degrees toward upwind, to scent what alarmed them).

## For Steve (no new wire fields)
- The scent rule is his already; nothing is asked. If he wants herds to drift to the lee of a slope as well as a wood, that is a
  cover-search candidate on the server (the lowest of his eight samples already does it for deer in a gale).

## Check
Run sheet m51 (deer and horse standing in wind 0.5 with rain 0.6 blowing toward +X: rumps toward +X, heads low) and DINO_SHOTS.md.
