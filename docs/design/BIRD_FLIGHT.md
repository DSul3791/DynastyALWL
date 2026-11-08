# Birds in flight on the client (MikeW, 8 Nov 2026; built on the life layer)

Follows FLIGHT_RIGS.md for the birds we have. The server decides when a bird is in the air (state 15: the duck and gull flocks today; single birds when the server flight states land); the client makes it look like flight.

**Built (row `flight`):**
- **Take-off:** the row's take-off clip plays once as the bird enters the air (goose `TakeOff_RunUp`, pheasant and guineafowl `TakeOf_BounceOff`, crow `FlyUp`).
- **Flap and glide in turns:** `flap_s` seconds of flapping, then `glide_s` of gliding, repeating; the flap clip runs at the species' **wingbeat** (`beat_hz`: pheasant 9, guineafowl 8, duck 5, crow 4, goose 3), the glide at its own rate.
- **Flap-bounce:** small birds (`bob_m` 2 to 4 cm: duck, pheasant, guineafowl, crow) bob with each beat.
- **Landing flare:** the landing clip plays once as the bird comes down (`Landing_Touch`), then the ground clips take over (the perch settle is the end of that clip).
- Rows: duck, goose, pheasant, guineafowl, crow.

**Soar circles** (eagle, raven): a path, so it belongs to the server (FLIGHT_RIGS.md section 2, `soar_m`); the client's part is the long `glide_s` in the eagle's prepared row.

**Prepared rows** for the eagle, raven and owl: `data/animals/pending_models.json` (not read by the game) with every key filled except the clip names, which come from the files when Dave's models arrive.

**Check:** `creature_motion --kinds=goose,pheasant --state=15 --frames=8 --every=0.3` (take-off then flap and glide), and the duck flock taking off in the live game.

## Part 2: single birds in flight (Steve's #653, server design 5b60ee80)

The server will fly single birds by time-based segments (flushers: pheasant, grouse, guineafowl; perchers: crow; soarers: eagle,
raven). The client side, on the life layer:
- **State 17 gliding** is in `AIR_STATES` with 15. A bird sent 17 plays its row's glide clip; once a bird has been sent 17, its 15
  always means flapping (the server decides the glide). Flocks that never send 17 keep the timed flap and glide turns.
- **Take-off and landing** already play once on entering 15 or 17 from the ground and on coming back to 0 (part 1).
- **Perched:** state 0 at a height is a bird on a branch or crag; the position carries the height, nothing more to do.
- **Banking** (flag `flight_bank`, off): the bank comes from the heading's turn rate (0.6 x rad/s, at most 45 degrees), eased, on the
  Rig's roll; level again once down.
- **Raven roll:** `play_roll(id, turns)` plays a half (0.5) or full (1.0) roll over 1 s on top of the bank; a second event inside
  that second (rolls come in pairs) queues behind it. The protocol handler calls it when Steve's roll event arrives (wire format in
  his server_flight step 2).
- Check: run sheet m28 (crow and pheasant turning at 0.8 rad/s, the crow rolling).
