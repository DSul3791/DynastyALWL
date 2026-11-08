# Small animals hop, not skate (MikeW, 8 Nov 2026; built on the eye-placement branch: rabbit and kangaroo rows)

**Problem.** The rabbit's walk clip is a slow hop: its feet move 0.31 m/s on the ground (#591). A rabbit grazing forward at 1 to 1.5 m/s plays that clip 3 to 5 times too fast (clamped to 2×), so it looks like it skates between hops, and a fleeing rabbit at 7.5 m/s plays its run at the clamp while the body slides far further per bound than the legs push.

**Proposal: drive a hop arc from the bone layer instead of speeding the clip up.**
1. A rabbit (and hare, rat, kangaroo, frog later) moves in bounds: each bound covers `bound_m` (rabbit walk 0.4 m, run 1.8 m; kangaroo 2 m and 6 m) in `bound_s`.
2. The client splits the server's smooth movement into bounds: the body's root rises on an arc (height `arc_m`, rabbit 0.08 / 0.35 m) and lands, and the body holds still on the ground between bounds if the server's speed is slow. The arc is a vertical offset of the drawn node, not a server change.
3. The clip plays at its own speed, one hop cycle per bound, started at take-off (so the legs push when the body lifts). The bound count per second follows the speed: `speed / bound_m`, capped by the clip's own rate; above that cap `bound_m` stretches instead of the clip speeding up.
4. Data: `"hop": {"walk": {"bound_m": 0.4, "arc_m": 0.08}, "run": {"bound_m": 1.8, "arc_m": 0.35}}` on hopping species.
5. The old code body already bobs the rabbit (`lift` in `_process_body`); this replaces that for model rabbits.

**Check:** moving frames of a rabbit grazing forward and fleeing, from the side: the feet must leave and meet the ground once per bound, with no glide while touching.
