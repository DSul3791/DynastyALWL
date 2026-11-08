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
