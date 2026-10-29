# Kathleen: sound batch 1 (goal 7), only what needs no new recordings
Goal: fill EMPTY slots in art/SOUND_MANIFEST.md that can be built from existing clips and synthesis: species footsteps (reuse and pitch existing step clips: hooves, paws, duck waddle), door open/close by material, ladder climb steps, water wheel loop, woodworking table plane/vice (from crafting clips), cloak rustle.
Files: data/sound/*.json mappings and tools/make_*.py generators (no engine code), assets/audio/ new ogg files under 1 MB each, CREDITS.csv rows.
How: mapping tables first (data), synthesized clips with the existing make_*.py scripts; loudness checked with tools/clip_check.py; all quiet defaults (-12 dB for creatures).
Test: clip_check, validator for the sound manifest, Esc > Settings > sound test entry for each new group; label RUNTIME. Needs Dave: listening check (cards with Tyler recommends).

## Tyler reply (03:30 UTC 24 Oct, once; BP-T52). GO, branch claude/kathleen-sound-1, label RUNTIME.
Best-practice suggestions:
1. **Sources and licences.** Only existing project clips (already in CREDITS.csv) and your own synthesis; no new downloads (a new website needs Dave's permission, BP-T48). Dave's own recordings win where he has made them. Every new file gets a CREDITS.csv row (source, licence/own-made, date).
2. **Loudness by class.** Normalise to the targets in assets/audio/LOUDNESS.md; creatures keep -12 dB; run tools/clip_check.py on every file (peak limit, no clipping, silence trimmed). Put the numbers in the report.
3. **Avoid the machine-gun effect.** 3-5 variants per footstep surface/species and door, random pitch of about +/-5 percent, and never the same variant twice in a row. Mapping tables carry the variant lists.
4. **Loops are seamless.** The water wheel loop must loop without a click: crossfade the ends, start and end at zero crossings, and test by playing it three times back to back. Level scales with wheel speed only if Steve's engine already supports it; otherwise a fixed loop, positional at the wheel.
5. **Register as positional with limits.** New sounds go through Steve's 3D sound path with a max distance and the per-tier voice cap, so they obey the existing mixer; no new engine code in your branch.
6. **Door and ladder rules.** Doors by material (wood, iron, steel), open and close separate; ladder steps follow the climb cadence (one per rung), not a timer. Table plane/vice and cloak rustle are short one-shots with a cooldown so a fast crafter does not machine-gun.
7. **Validator in Python.** Extend the manifest validator: every mapped file exists, under 1 MB, in CREDITS.csv, referenced by a manifest slot; a slot filled today is marked filled so the empty-slot count falls (print "empty slots: N" each run).
8. **One ear test.** Add one entry in Esc > Settings > Sound test that plays every new group in sequence, labelled; one card for Dave with the steps, "Tyler recommends" and Yes/No per group. Not one card per clip.
9. **Budget.** Total loaded audio at Low stays under 150 MB (JOBS.md); report the added size.
