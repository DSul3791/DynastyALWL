# Life layer wiring: every server state and signal the client listens for

One row per server state or signal the animal life layer reads. Client code is `src/client/animal_view.gd` unless named;
strips are the lines in PC_SESSION_MIKEW.md step 4 (m1 to m34) or the named test. Written 8 Nov 2026 (MikeW). A gap is a signal
with no client handler or no strip; every gap found is filled below (marked **filled**).

## Server states (the row's state field)

| State | Meaning | Server | Client handler | Flag | Proof |
|---|---|---|---|---|---|
| 6 | wolf stalk | server_wolves.gd (main) | `_stalking`, stalk block in `_animate_model`, `_tail_motion`, `_look_motion` (track) | `stalk_fx` | m15 |
| 7 | wolf or fox attack | server_wolves.gd (main) | pounce block in `_animate_model`, `_pounce`, ears flat in `_ear_motion` | `stalk_fx` | m16 |
| 10 | warn (big game; the dog's bark) | server_big_game.gd (main); dog reactions #659 | clip role 10, ears flat, `_look_motion` (track), rig pitch for code bodies | none | m31 (**filled**: had no strip) |
| 11 | charge | server_big_game.gd (main); #659 charge hits the dog | clip role 11 (else run), ears flat, fast position follow | none | m32 (**filled**: had no strip) |
| 13 | sneak (thief, goblin) | server_thieves.gd, server_goblins.gd (main) | stalk block for rows with 13 in `stalk.states` (fox, raccoon, lynx) | `stalk_fx` | m30 (**filled**: had no strip) |
| 15 | in the air, flapping | server_flocks.gd (main); single birds #653 | flight block in `_animate_model` (take-off once, flap), `_flap_bob`, `_bank` | none; bank `flight_bank` | m18, m28 |
| 16 | jaw-pop warning | server_big_game.gd WARN_POP (main) | clip role 16 (else 10), `state_poses` 16 (black bear), ears flat | none | m10 |
| 17 | gliding | #653 (design; server_flight.gd to come) | `AIR_STATES`, flight block glide clip, `seen_glide` | none | m33 (**filled**: had no strip) |
| 18 | dog sits | dog companion (#651) | clip role 18, tail wag in `_tail_motion` | none | step 3 still (dog), m1 |
| 19 | dog lies | dog companion (#651) | clip role 19, tail wag | none | step 3 still (dog), m1 |
| 20 | hunch against the weather (in rain deer and stock hunch 60% of grazing spells: Steve's #667 on #661) | #646, #667 | `HUNCH`: idle clip (12, 3) under `state_poses` 20 (deer, wolf, fox, elk, moose, horse, donkey; cattle and goats on the idle clip alone), ears 0.7 flat, tail still | none (server state) | m26 |

Single birds (Steve's #661, bird flight step 1, head 6ab02d10): flying and perched birds send their height in the row's position and
their heading follows the flight line; flights keep 3 m over the ground. The client needs no change: the node follows the sent
position in all three axes (nothing snaps a model to the ground except `foot_ik`'s leg reach, and birds have no `feet` rows), a
perched bird is state 0 at that height, and `_bank` reads the heading's turn rate. Proof: m18, m28, m33 with the tool's flat paths;
a real flush is first seen in game.

Weather step 2 (#667): moving under trees in rain, stock facing downwind in a gale and cave cover are positions and headings the client already follows; no client change.

## Signals

| Signal | Server | Client handler | Flag | Proof |
|---|---|---|---|---|
| `footfall(kind, at, ground, speed)` | client signal; sound stage connects it by name (Kathleen #647) | `_emit_steps`, `_ground_kind`, `_puff`, `_splash`, `_print_at` | `footfall_fx`, `prints_fx` (looks); the signal itself always | m11, m12, m14 |
| Footfall to animal sign | same signal (#647 shape) | `_sign_track` (stride gap, walk or run pattern) and `_sign_ground` from `soil_at` (sound stage soil map) | `animal_sign` | m38, m39, m40 |
| Rest states for sign (0 feeding, 19 lying, asleep) | server states, client sleep rule | `_sign_rest`: browse, droppings, beds | `animal_sign` | in game (beds need 30 s) |
| Rain, falling snow, lying snow | weather sounds (main): rain, kind, ground_snow | `terrain_client._animal_conditions` adds rain, snowing, ground_snow; `_fade_signs` washes, covers or melts | `animal_sign` | in game |
| Alarm groups (`alarm_group`, ground birds across species) | #636 | none needed: each bird arrives as flee (2) and is drawn fleeing; the herd glance (`_herd_glance`) is the client's look-up-together | none | Steve's test_alarm_group; m4 for the glance |
| `storm_ahead` (0..1) | #646 shared weather | `terrain_client._animal_conditions` reads it when the weather has it; `_tail_motion` stops the fly swish above 0.5 | none | m29 (**filled**: had no strip) |
| Herd leader and followers | herd groups #666 (Steve's stack), `groups.enabled` | none needed: positions come from the server; the client herd look (`_herd_look`) sits on top | `groups.enabled` (server, off) | test_herd_groups.gd in #666's gate |
| Foe position (the dog a warning, charging or recovering animal faces; sixth row field, Vector3) | #659 (head 4e619847): states 10 to 12 with a dog as foe | `on_rows` keeps row[5] as `foe` (dropped when absent); `_look_motion` turns the head to it in states 10, 11, 12 and 16 | `look_at_foe` | m34 (the tool sends a foe 4 m to the side) |
| Raven roll event | #653 step 2 (wire format to come) | `play_roll(id, turns)`, `_bank` (pairs queued) | `flight_bank` | m28 (the tool sends a roll every 2 s) |
| State change to a voiced state | every state row above | `_voice` with voices.json, `voiced` signal, terrain_client plays a mood or a slot | `voice_fx` | in game only (no sound in the motion tool) |
| Night level, moon phase and direction | client day cycle (weather_look.day: night, moon_light, light_basis) | `night_light` from terrain_client; `_eye_shine_night`, `_retro`; far-off dots from `_add_eyes` | `eye_shine` | m36, m37 |
| Held torch | held_item.gd `held_light` (main) | `torch_light`: eye shine (#596 torch-only when `eye_shine` is off) | none; `eye_shine` for v2 | m8, m36 |
| Weather wind (0..1) | shared weather (main) | `wind_now` from terrain_client: ears, tails, coat ruffle | `coat_ruffle` for the coat | m17, m21 |
| Weather state (temp_c, rain, snow, wind, wind_dir) | shared weather (main), terrain_client.weather | `weather_now`; `_weather_look` (shake-off, tail to wind, cold huddle), `_steam_breath`, snow on backs, `_herd_space` | `weather_looks` | m41 to m44 |
| Hit number (protocol 85: point and damage, to the hunter only) | server_items hit_number (main) | `note_hit(at, amount)`: `_hit_reaction` (zone), `_hunt_motion` (reaction, hip drag, limp) | `hunt_feedback` | m45, m46 |
| Animal leaves the rows after a hit | server rows (main) | `killed_by_hit`, `fell`; `_death_fall` along the slope | `hunt_feedback` (the fall; the sound always) | m47 |
| Wounded health (0 to 1 by 0.1, while hurt; a number after the five fields) | Steve's hunt fields (one protocol bump) | `on_rows` reads extra fields by type: `health`, `wounded` | `hunt_feedback` | waits for the server |
| Hit event (animal id, zone) to players within 60 m | Steve's hunt fields, protocol `HIT_EVENT_PROTOCOL` | `on_hit_event`, connected when `net` has `animal_hit_received` | `hunt_feedback` | waits for the server |
| State 20 in cover | Steve #646 s.11, #701 | `_cover_still`: idle at half speed, slow breath, no glances, `wet_hold` | `cover_still` | m48 |
| Kill switch | command line `--life-layer-off` | `life_layer_all_off`, `_all_flags_off`: every flag off and the always-on looks skipped | the switch itself | gate (PERF_BUDGET.md) |
| Rain cover, conifers, shade, gale drift (Steve #667, #671) | server positions and headings | none needed: drawn as sent; state 20 in rain as the hunch | none | m26 |
| Ground wet, season, hour | weather sounds, ambient conditions (main) | `conditions_now`: sleep, prints, puddle splashes, coat season | per look | m6, m12, m19, m20 |
| Water level | flora.water_level_at (main) | `water_level`: swim clips, wet look, water life | `water_life` | m7, m24, m25 |

## Still open (not gaps in the client)

- The foe field is on the wire in #659; the roll event still needs Steve's wire change. Both client sides wait behind their flags.
- An armed owner making goblins flee waits for the server to know what a player holds (#659 note).
