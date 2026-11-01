# Action plan: feed the four dry river ends (branch claude/steve-spring-feed)

Asked by Sonny via the coordinator: four inland river ends in tile (3,4) (x59968 z63448, x57832 z73384, x53648 z74280, x54624 z74960) are dry only because the spring feed is tiny (0.1 m3/s, catchment 0.0 km2, a film under the 0.12 m draw line), not because of terrain. River continuity today: 50.6 % of painted river cells carry water.
Change (data only, needs a RE-SETTLE of the water, NO re-bake of terrain; label SETTLE, held with the other settles until Dave lifts the bake hold):
1. data/water_settle.json `catchment.min_m3s` 0.1 -> 0.3 (a head with a 0.0 km2 catchment pours the floor; 0.3 m3/s x the game's x10 flow key = 3 m3/s, enough to hold a 1-2 m wide, 0.15 m deep brook across a few hundred metres). max_m3s unchanged.
2. version bump of the settle rules (v9 -> v10) so settle_water prints the change and old settled water is not mistaken for the new rules.
3. Effect check (David3 on the box after the hold lifts, or Mike on the PC): re-settle tile (3,4), then (a) river continuity (the existing basin census / drainage test prints the share): expect up from 50.6 %, never lower; (b) the four named ends carry water at the settle's last tick; (c) no new lake over 5 ha and no head pond overfilling (test_head_pond_fill, test_drainage_flow known-fail list stays empty); (d) total poured m3 reported by the settle: expect a small rise only (only heads below 0.3 m3/s change).
Risk: low for the game (a data number); if the number overshoots, brooks widen or a small pond fills, so the check (c) gates the merge. If 0.3 does not carry the four ends, the second option is a film rule for 0.0 km2 heads (the `film` rule needs min_km2 of drainage; a film_min_km2 of 0 for heads would draw them), which I would build as its own branch.

## Build notes (Tyler GO)
data/water_settle.json: version 10, catchment.min_m3s 0.3 (note extended); water_settler.gd VERSION 10 (test_water_settle_rules checks they match). Merges ONLY together with re-settled tile files as one build.
