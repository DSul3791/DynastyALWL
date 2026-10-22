# Process review: Kathleen_ArtisticDirector (art and sound), 2026-10-22

## What works
- Build log + one build number claim per push: no clashes once I recomputed from origin and BUILD_LOG.
- TEST_QUEUE lines instead of asking Dave: I queued 3 looks/sounds with no waiting.
- Dave's sound notes become a running approved list in LISTEN_CHECKLIST.md, so nothing gets re-asked.
- "Data in JSON" (step_levels.json) made the sand fix a one-line change.

## What hurts my area
1. **I cannot see or hear.** Cloud engine is headless: no screenshots, no audio. Every look/sound change ships unseen; Dave is the only eye and ear. This is the biggest quality risk and token waste (fix, ship, wait, fix again).
2. **Generated assets are not reproducible.** Every `make_*.py` run re-encodes all oggs differently; I must `git checkout` the unchanged ones by hand or the diff is noise (about 20 files).
3. **Shared files cause merge pain.** `piece_look.gd` and `placed_sounds.gd` were edited by Radar and me within minutes (one rebase conflict). Building look and building data share a file.
4. **Ambiguous feedback.** "Beach a little loud" could be sand steps or waves; I guessed. No standard way to name the sound (F3 sounds-heard list exists but is not required in reports).
5. **Idle gaps.** I waited with nothing queued several times because art jobs need a visual check I cannot do.

## Changes
- **Screenshot + audio check on Dave's PC by MikeW** after each look/sound build, batched in the test card: MikeW sends me one screenshot per new piece and the F3 sounds-heard line. Cuts rework loops. Cloud only for code.
- **Make asset scripts deterministic** (fixed encoder settings, or write only files whose waveform changed). Small Systems job, saves tokens on every sound build.
- **Split piece look from piece data**: `piece_look.gd` (mine) vs placement/state (Radar); Radar only adds state numbers, I only change materials.
- **Test-card sound items must name the file** (F3 list) so one reply fixes the right sound.
- **Park art that needs eyes** (animals) until MikeW screenshots exist; do sound/data-driven work meanwhile.
- **Token saving for me**: read only BP entries for my section (C60-C74) plus my handoff; skip BIG_PICTURE parts outside art, sound, buildings.
