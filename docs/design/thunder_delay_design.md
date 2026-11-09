# Thunder: the real delay and the real range

**Owner:** Kathleen. **Status:** design, 8 Nov 2026.
**Reads:** Jamie's `docs/knowledge/weather-water-sounds.md` (#683), lesson 6 and "Thunder (for `weather_sounds.gd`)", never-hear check 5.

One switch, `--thunder-real`, off until Dave's listen (sound changes wait for him).

## 1. What is wrong today (read from `weather_sounds.gd` on main)

- **The delay is half the real one, capped at 4 s** (`THUNDER_DELAY_SCALE` 0.5, `THUNDER_MAX_DELAY_SEC` 4). Any strike past about 2.7 km waits 4 s, so counting the seconds gives no distance.
- **Strikes land no farther than 2.8 km** (`randf_range(250, 2800)` leaned nearer), and most within 1.8 km. Real thunder is heard to 15 to 20 km.

## 2. The rules (`--thunder-real`)

- **Delay:** distance / 343 m/s, the full travel time. That is 3 s a km: a 1 km strike after 2.9 s, a 5 km one after 14.6 s, a 15 km one after 44 s.
- **Where strikes land** (since 9 Nov 2026): on the shared schedule, `src/shared/thunder.gd` `Thunder.strikes`, the one the server's birds flush at (`birds_and_thunder_server.md`). There is no random roll on the client any more.
  - Every strike within 3 km (`THUNDER_HEARD_ALL_M`) is played: about one every 25 real seconds at storm 1.
  - From 3 to 15 km the schedule has about one strike a real second, far too many to rumble. A fixed share, `THUNDER_FAR_KEEP` 1.5 %, picked by a hash of the strike's place and moment, is played: about one far roll a minute, as before. The hash is the same on every client, so players together hear the same far rolls.
  - The schedule is read each sound tick for the game seconds since the last read. A jump over 120 game seconds either way (a login, a clock jump) starts it fresh, with no backlog of claps. A small step back (a resync with the server) waits until the clock passes the last read, so no strike plays twice.
  - A forced storm (`--weather=storm`, the Esc sound test) reads the schedule with the forced kind's storm and rain, so it still thunders. Those strikes are only this client's; the birds follow the world's weather.
- **Level** (dB on the roll, before the bus):
  - out to 5 km, today's ramp: -4 dB, 1 dB lost per 400 m, +3 dB for a crack under 500 m;
  - past 5 km, spreading (6 dB a doubling) and 0.6 dB a km of air loss on what is left, which is the low end. So 10 km is about -25.5 dB and 15 km about -32 dB, a faint grumble;
  - past 10 km, the wind drowns it: up to -14 dB at wind 1, ramped in over 2 km (Jamie: "a faint grumble on a still evening, unheard in wind").
- **Which clip:** unchanged. `thunder_near` under 500 m, `thunder` to 1.8 km, `thunder_far` past it. The far band bus (`air_bands.gd`, 450 Hz past 1.8 km) already takes the high end off.
- **Where it comes from:** the voice stands 100 m off in the strike's direction, as today. With a delay of up to 44 s the player may have moved, so it is placed again beside the listener when it plays.
- **The flash:** unchanged. `weather_look.gd` dims the flash with distance to a floor of 0.3 and draws no bolt past 3.2 km, so a 15 km strike is a faint glow on the cloud.

## 3. Never-hear check 5

Thunder arriving at once from a strike 5 km off, or a 15 s gap after a strike 1 km away. Test (`test_thunder_real.gd`): delay(1 km) is 2.9 s, delay(5 km) is 14.6 s, every shared strike within 3 km is heard and about 1.5 % past it, the same ones every time, a full storm gives about 24 near strikes and 10 far rolls in 600 real s, a long clock gap plays no backlog, the level falls with distance and a 12 km roll is quieter in wind.

## 4. Listening (for Dave, switch on)

- `storm` from the F-menu sound test, outdoors, for about 5 minutes. Count the seconds from flash to roll: about 3 a km (the F3 line `last_thunder` gives the distance).
- Far rolls should be low and faint. A gale should hide the farthest.

## 5. Left for later

- The rumble length growing with distance (a near crack under 1 s, a far roll 5 to 20 s) needs longer far clips.
- Past 20 km, lightning with no thunder: our strikes stop at 15 km, so it does not arise yet.
