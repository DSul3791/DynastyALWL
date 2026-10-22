# Concerns: Kathleen_ArtisticDirector (art and sound), 2026-10-22
1. SAFETY: collapse is always lethal, and the warning leans on my generated tunnel sounds (build 634), which nobody has heard. Before collapse is switched on, Dave must hear the stages once (admin test call of sound.placed.quake) and a visual/text warning must not depend on sound (muted players, no headset). Gate: listen-check on the test card.
2. Splitting inventory_view.gd (job 2): the piece look mapping (PieceLook per state, one long ternary at ~line 1464) is mine and Radar's. Split should move it to a table (state -> look function) first, or every new piece edits that line.
3. look_sheet scene (my job) needs a headed Godot run by MikeW; headless prints nothing. If MikeW cannot render, art stays blind. Needs a yes from MikeW early.
4. Deterministic asset scripts: fixing make_*.py touches every sound's file names/encoding; do it as one build with a byte-compare of waveforms, or Dave's approved sounds (rock dig, fire crackle, grass, tunnel echo) could change. Keep the approved list as the regression set.
5. "Still waiting on:" only when pending (rv-waiting-line) is fine for me; I already add it only when true.
6. Role digests: art digest must include C60 hold change and C70-C74, else I miss cost-at-Low rules.
7. LFS/tiles and branch-per-thread: no impact on my files, but my oggs are binary; per-thread branches merged late will conflict on BUILD only, fine.
No other concerns.
