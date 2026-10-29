# Review: Kathleen_ArtisticDirector (art and sound), 2026-10-22
Read: HOW_WE_WORK, BIG_PICTURE (art/sound parts), BEST_PRACTICES (C60-C74, POLICY, B), REVIEW_BRIEF. Not read in full: PROCESS, TEAM_PROPOSAL.

## 1 Keep
- TEST_QUEUE lines (RULE 2): I queued 3 builds with zero waiting on Dave.
- Build number = max(origin, BUILD_LOG)+1 (C101): no clashes once followed.
- Data in JSON (C04): sand step fix was one line in step_levels.json.
- LISTEN_CHECKLIST approved list (C61): nothing re-asked.
- Park and move on (T07): keeps me from idling on Dave.

## 2 Change
1. Asset scripts re-encode every ogg on each run (non-deterministic). Fix: only write files whose waveform changed, or fixed seeds/encoder. Saves ~20 noise files per sound build; guess 3-5k tokens each time.
2. I cannot see or hear in the cloud. Fix: MikeW returns 1 screenshot per new piece + F3 sounds-heard line after each look/sound build, in the test card. Saves a fix-ship-wait loop; guess 10-20k tokens per look job.
3. piece_look.gd / placed_sounds.gd edited by me and Radar in minutes (rebase conflict). Fix: Radar owns state ids and data; I own materials/meshes/sounds; each adds in separate functions/blocks. Guess 2k tokens.
4. Sound feedback ambiguous ("beach loud"). Fix: test card sound items name the file from the F3 list and say steps/waves/wind. Saves a wrong guess.
5. Moderator pings "idle" while I wait on eyes. Fix: let idle be fine when TEST_QUEUE holds my items.

## 3 Missing
- Entry for visual checks without a renderer (screenshots by MikeW) and for generated textures/sounds (cost at Low, texture size 128 px).
- Entry for asset licences/credits when Dave records real sounds (assets/audio/CREDITS.md exists, no rule).

## 4 Conflicts
- C60 (sounds on HOLD) vs coordinator jobs to build tunnel/building sounds: I followed the coordinator; make the hold rule say "present-day systems (dig, tunnel, building, fire) allowed".
- C61 says ffmpeg missing on Dave's PC; asset scripts need ffmpeg, so only cloud can regenerate. Fine, but say so.

## 5 My area
- Look/sound is tuned blind. Recommendation: a small `tools/look_sheet` scene MikeW runs headed that renders all pieces/creatures/lighting to PNGs (one command). Dave's decisions untouched.

## 6 Token moves
- Read only my BP sections + handoff; skip BIG_PICTURE outside art/sound/buildings.
- Handoff under 40 lines; patches as files, not prose.
- Reports to Dave 3 lines; details in checklist files.

## 7 Verdict
Process good for now; needs changes 1-2 above.
